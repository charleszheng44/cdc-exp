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


dockerfile="# Use Alpine Linux as the base image
FROM alpine:latest

# Install necessary dependencies
RUN apk update && \\
    apk add --no-cache curl && \\
    apk add --no-cache bash

# Install sysbench
RUN apk add --no-cache sysbench

# Install all required ctl
RUN curl -L https://download.pingcap.org/tidb-community-server-${remote_version}-linux-amd64.tar.gz | tar xzvf - && \\
    tar -xzf tidb-community-server-${remote_version}-linux-amd64/ctl-${remote_version}-linux-amd64.tar.gz && \\
    mv cdc *ctl /usr/local/bin && \\
    rm -rf tidb-community-server-${remote_version}-linux-amd64
"

[ "$local_cdc" = true ] && dockerfile+="COPY cdc /usr/local/bin"

echo "$dockerfile" > Dockerfile
# Build the Docker image using the temporary Dockerfile
docker build -t tidb-debug .
# Remove the temporary Dockerfile
rm Dockerfile
