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

# copy desired cdc, pdctl binary to the build directory
# Install ticdc
COPY cdc /usr/local/bin
COPY pdctl /usr/local/bin
