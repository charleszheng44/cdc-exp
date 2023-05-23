#!/usr/bin/env bash

: ${UP_PD_PORT=2379}
: ${UP_PD_PEER_PORT=2380}
: ${UP_KV_PORT=20160}
: ${UP_KV_STATUS_PORT=20180}
: ${UP_DB_PORT=4000}

: ${DW_PD_PORT=2479}
: ${DW_PD_PEER_PORT=2480}
: ${DW_KV_PORT=20260}
: ${DW_KV_STATUS_PORT=20280}
: ${DW_DB_PORT=5000}

set -u

# TODO(charelszheng44): specify the log file and the data dir for the upstream 
# and the downstream database.
start_tidb_cluster(){
    local PD_PORT=$1
    local PD_PEER_PORT=$2
    local KV_PORT=$3
    local KV_STATUS_PORT=$4
    local DB_PORT=$5
    local WHICH=$6
    echo "pd server listening on $PD_PORT"
    $PD --name=pd1 \
        --data-dir=uppd \
        --client-urls="http://127.0.0.1:${PD_PORT}" \
        --peer-urls="http://127.0.0.1:${PD_PEER_PORT}" \
        --initial-cluster="pd1=http://127.0.0.1:${PD_PEER_PORT}" \
        -L "info" \
        --log-file=uppd.log &
    [ "$WHICH" = "UP" ] && up_pd_pid=$! || down_pd_pid=$! 
    
    echo "tikv server listening on $KV_PORT"
    $TIKV \
        --pd="127.0.0.1:${PD_PORT}" \
        --addr="127.0.0.1:${KV_PORT}" \
        --status-addr="127.0.0.1:${KV_STATUS_PORT}" \
        --data-dir=tikv \
        --log-file=upkv.log &
    [ "$WHICH" = "UP" ] && up_kv_pid=$! || down_kv_pid=$! 
    
    echo "tidb server listening on $DB_PORT"
    $TIDB \
        --store=tikv \
        --path="127.0.0.1:${PD_PORT}" \
        -P=${DB_PORT} \
        --log-file=updb.log &
    [ "$WHICH" = "UP" ] && up_db_pid=$! || down_db_pid=$! 
}

echo "starting upstream TiDB..."
start_tidb_cluster $UP_PD_PORT $UP_PD_PEER_PORT $UP_KV_PORT $UP_KV_STATUS_PORT $UP_DB_PORT "UP" 

echo "starting downstream TiDB..."
start_tidb_cluster $DW_PD_PORT $DW_PD_PEER_PORT $DW_KV_PORT $DW_KV_STATUS_PORT $DW_DB_PORT "DW"

cleanup() {
    echo "stopping the upstream tidb cluster components..."
    echo "stopping the upstream tidb" 
    kill -9 ${up_db_pid}
    echo "stopping the upstream tikv" 
    kill -9 ${up_kv_pid}
    echo "stopping the upstream pd" 
    kill -9 ${up_pd_pid}

    echo "stopping the downstream tidb cluster components..."
    echo "stopping the downstream tidb" 
    kill -9 ${down_db_pid}
    echo "stopping the downstream tikv" 
    kill -9 ${down_kv_pid}
    echo "stopping the downstream pd" 
    kill -9 ${down_pd_pid}

    exit 0
}

# Trap SIGINT(Ctrl+C) signal and call the cleanup function
trap cleanup SIGINT

while true; do
    sleep 1
done
