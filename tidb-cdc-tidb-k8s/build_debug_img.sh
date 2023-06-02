#!/usr/bin/bash

local_cdc=false
remote_version="v7.0.0"

# Parse command line arguments
while [ $# -gt 0 ]; do
    key="$1"

    case $key in
        --local-cdc)
        local_cdc=true
        shift
        ;;
        --remote-ver)
        remote_version=$2
        shift
        shift
        ;;
        *)
        echo "Unknown option: $1"
        shift
        ;;
    esac
done


dockerfile=$(cat <<EOF
# Use Alpine Linux as the base image
FROM alpine:latest

# Install necessary dependencies
RUN apk update && \
    apk add --no-cache curl && \
    apk add --no-cache bash

# Install sysbench
RUN apk add --no-cache sysbench


# Install etcdctl
RUN curl -L https://github.com/etcd-io/etcd/releases/download/v3.5.0/etcd-v3.5.0-linux-amd64.tar.gz | tar xzvf - && \
    mv etcd-v3.5.0-linux-amd64/etcdctl /usr/local/bin/ && \
    rm -rf etcd-v3.5.0-linux-amd64
EOF
)


if [ "$local_cdc" = true ]; 
then
    dockerfile+="\nRUN curl -L https://download.pingcap.org/tidb-community-server-${remote_version}-linux-amd64.tar.gz | tar xzvf - && mv bin/pd-ctl /usr/local/bin && rm -rf tidb-community-server-${remote_version}-linux-amd64" 
    dockerfile+="\nCOPY cdc /usr/local/bin"
else
    dockerfile+="\nRUN curl -L https://download.pingcap.org/tidb-community-server-${remote_version}-linux-amd64.tar.gz | tar xzvf - && mv bin/pd-ctl /usr/local/bin && mv bin/cdc /usr/local/bin && rm -rf tidb-community-server-${remote_version}-linux-amd64"
fi


temp_dkfile=$(mktemp)
echo "$dockerfile" > "$temp_dkfile"
# Build the Docker image using the temporary Dockerfile
docker build -t myimage -f "$temp_dkfile" .
# Remove the temporary Dockerfile
rm "$temp_dkfile"
