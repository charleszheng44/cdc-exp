#!/usr/bin/env bash

set -eu

MONITOR=false
REPLICAS=1

while getopts "mr:" opt; do
  case $opt in
    m)
        MONITOR=true
        echo "will enable TiDB monitor"
        ;;
    r)
        REPLICAS=$OPTARG
        echo "will start $REPLICAS cdc nodes in $REPLICAS zones"
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        ;;
  esac
done


# 1. deploy the kind cluster
template="kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane"

for i in $(seq 1 $REPLICAS) 
do 
    template=$(printf "%s\n%s" "$template" "- role: worker")
done

echo "$template"

kind create cluster --config=- <<EOF
$template
EOF

# wait for the cluster to be ready
while ! kubectl cluster-info > /dev/null 2>&1
do 
    echo "kind cluster is not ready, will retry in 2 seconds"
    sleep 2
done

# 2. annoate the node to create the zone toplogy
for i in $(seq 1 $REPLICAS)
do
    if [ "$i" = 1 ] 
    then
        kubectl label node kind-worker topology.kubernetes.io/zone=zone1
    else
        kubectl label node kind-worker$i topology.kubernetes.io/zone=zone$i
    fi
done

# setup the tidb operator
kubectl create -f \https://raw.githubusercontent.com/pingcap/tidb-operator/master/manifests/crd.yaml
helm repo add pingcap https://charts.pingcap.org/
kubectl create ns tidb-admin
helm install --namespace tidb-admin tidb-operator pingcap/tidb-operator --version v1.5.0-beta.1

# setup the tidb cluster
kubectl create ns tidb-cluster
kubectl apply -n tidb-cluster -f-<<EOF
apiVersion: pingcap.com/v1alpha1
kind: TidbCluster
metadata:
  name: advanced-tidb
  namespace: tidb-cluster

spec:
  version: "v7.1.0-pre"
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
      log-level = "info"
    replicas: 1
    maxFailoverCount: 0
    requests:
      storage: 1Gi
    mountClusterClientSecret: true

  ticdc:
    baseImage: pingcap/ticdc
    replicas: 3
    terminationGracePeriodSeconds: 30
    config: |
      gc-ttl = 86400
      log-level = "info"
      log-file = ""
    topologySpreadConstraints:
    - topologyKey: topology.kubernetes.io/zone
EOF

[ ! $MONITOR ] && return

# deploy the monitor
kubectl apply -f-<<EOF
apiVersion: pingcap.com/v1alpha1
kind: TidbMonitor
metadata:
  name: basic 
spec:
  clusters:
  - name: advanced-tidb
    namespace: tidb-cluster
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
