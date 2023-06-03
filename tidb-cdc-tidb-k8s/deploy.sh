#!/usr/bin/env bash

set -eu

MONITOR=false
IMAGE=pingcap/ticdc:latest
CONTEXT=cdc-test

while getopts "mi:" opt; do
  case $opt in
    m)
        MONITOR=true
        echo "will enable TiDB monitor"
        ;;
    i)
        IMAGE=$OPTARG
        echo "will use cdc image $IMAGE"
        shift
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        ;;
  esac
done


# 1. deploy the kind cluster
kind create cluster -n $CONTEXT

# wait for the cluster to be ready
while ! kubectl cluster-info > /dev/null 2>&1
do 
    echo "kind cluster is not ready, will retry in 2 seconds"
    sleep 2
done

# load required image to the kind if exist
images=("pingcap/tidb" "pingcap/pd" "pingcap/tikv" "prom/prometheus:v2.27.1" "grafana/grafana:7.5.11" "pingcap/tidb-monitor-initializer:v6.5.0" "pingcap/tidb-monitor-reloader:v1.0.1" "quay.io/prometheus-operator/prometheus-config-reloader:v0.49.0 tidb-debug:latest" "pingcap/tidb-operator:v1.5.0-beta.1" "pingcap/tidb-backup-manager:v1.5.0-beta.1")

set +e
for image in "${images[@]}";
do
    kind load docker-image $image -n $CONTEXT > /dev/null 2>&1 \
        && echo "successfully load $image to kind" \
        || echo "fail to load $image to kind" 
done
set -e

# 2. setup the tidb operator
kubectl create -f \https://raw.githubusercontent.com/pingcap/tidb-operator/master/manifests/crd.yaml
helm repo add pingcap https://charts.pingcap.org/
kubectl create ns tidb-admin
helm install --namespace tidb-admin tidb-operator pingcap/tidb-operator --version v1.5.0-beta.1 --set scheduler.create=false

tidb_template="apiVersion: pingcap.com/v1alpha1
kind: TidbCluster
metadata:
  name: NAME 
  namespace: NAMESPACE 

spec:
  version: \"v7.1.0-pre\"
  timezone: UTC
  configUpdateStrategy: RollingUpdate
  helper:
    image: alpine:3.16.0
  pvReclaimPolicy: Retain
  enableDynamicConfiguration: true

  pd:
    baseImage: pingcap/pd
    config: |
      [dashboard]
        internal-proxy = true
    replicas: 1
    maxFailoverCount: 0
    requests:
      storage: 1Gi
    mountClusterClientSecret: true

  tidb:
    baseImage: pingcap/tidb
    config: |
      [performance]
        tcp-keep-alive = true
    replicas: 1
    maxFailoverCount: 0
    service:
      type: NodePort
      externalTrafficPolicy: Local

  tikv:
    baseImage: pingcap/tikv
    config: |
      log-level = \"info\"
    replicas: 1
    maxFailoverCount: 0
    requests:
      storage: 1Gi
    mountClusterClientSecret: true
  TICDC"

# 4. setup the upstream tidb cluster
upstream_template="${tidb_template//NAMESPACE/upstream}"
upstream_template="${upstream_template//NAME/upstream-tidb}"
ticdc_template="
  ticdc:
    baseImage: pingcap/ticdc
    replicas: 1
    terminationGracePeriodSeconds: 30
    config: |
      gc-ttl = 86400
      log-level = \"info\"
      log-file = \"\""
upstream_template="${upstream_template//TICDC/$ticdc_template}"
kubectl create ns upstream
kubectl apply -f-<<EOF
$upstream_template
EOF


# 5. setup the downstream tidb cluster
dwstream_template="${tidb_template//NAMESPACE/dwstream}"
dwstream_template="${dwstream_template//NAME/dwstream-tidb}"
dwstream_template="${dwstream_template//TICDC/}"
kubectl create ns dwstream
kubectl apply -f-<<EOF
$dwstream_template
EOF

# 6. deploy the debug pod
kubectl create -f-<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: tidb-debug
spec:
  containers:
  - name: tidb-debug 
    image: tidb-debug
    imagePullPolicy: IfNotPresent
    command: ["tail"]
    args: ["-f", "/dev/null"]
EOF

# 7. deploy the monitor if required
[ ! $MONITOR ] && return

kubectl apply -f-<<EOF
apiVersion: pingcap.com/v1alpha1
kind: TidbMonitor
metadata:
  name: basic 
spec:
  clusterScoped: true
  clusters:
  - name: upstream-tidb
    namespace: upstream
  - name: dwstream-tidb
    namespace: dwstream
  storage: 5G
  prometheus:
    baseImage: prom/prometheus
    version: v2.27.1
    service:
      type: NodePort
  grafana:
    baseImage: grafana/grafana
    version: 7.5.11
    service:
      type: NodePort
  initializer:
    baseImage: pingcap/tidb-monitor-initializer
    version: v6.5.0
  reloader:
    baseImage: pingcap/tidb-monitor-reloader
    version: v1.0.1
  prometheusReloader:
    baseImage: quay.io/prometheus-operator/prometheus-config-reloader
    version: v0.49.0
  imagePullPolicy: IfNotPresent
EOF
