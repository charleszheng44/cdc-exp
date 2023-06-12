#!/usr/bin/env bash

: ${UP_PD_PORT=2379}
: ${UP_PD_PEER_PORT=2380}
: ${UP_KV_PORT=20160}
: ${UP_KV_STATUS_PORT=20180}
: ${UP_DB_PORT=4000}
: ${UP_DB_STATUS_PORT=10080}

: ${DW_MINIO_PORT=9000}
: ${DW_MINIO_DATA_DIR=data}

: ${NUM_CHANGEFEEDS=1}

set -u

# TODO(charelszheng44): specify the log file and the data dir for the upstream 
# and the downstream database.
start_tidb_cluster(){
    local PD_PORT=$1
    local PD_PEER_PORT=$2
    local KV_PORT=$3
    local KV_STATUS_PORT=$4
    local DB_PORT=$5
    local DB_STATUS_PORT=$6
    local WHICH=$7
    local WORK_DIR=${WHICH,,}
    # reset the WORK_DIR 
    rm -rf $WORK_DIR
    mkdir $WORK_DIR

    echo "pd server listening on $PD_PORT"
    $PD --name=pd1 \
        --data-dir=uppd \
        --client-urls="http://127.0.0.1:${PD_PORT}" \
        --peer-urls="http://127.0.0.1:${PD_PEER_PORT}" \
        --initial-cluster="pd1=http://127.0.0.1:${PD_PEER_PORT}" \
        -L "info" \
        --data-dir=$WORK_DIR/pd \
        --log-file=$WORK_DIR/pd.log &
    [ "$WHICH" = "UP" ] && up_pd_pid=$! || down_pd_pid=$! 
    
    echo "tikv server listening on $KV_PORT"
    $TIKV \
        --pd="127.0.0.1:${PD_PORT}" \
        --addr="127.0.0.1:${KV_PORT}" \
        --status-addr="127.0.0.1:${KV_STATUS_PORT}" \
        --data-dir=$WORK_DIR/tikv \
        --log-file=$WORK_DIR/kv.log &
    [ "$WHICH" = "UP" ] && up_kv_pid=$! || down_kv_pid=$! 
    
    echo "tidb server listening on $DB_PORT"
    $TIDB \
        --store=tikv \
        --path="127.0.0.1:${PD_PORT}" \
        --status=$DB_STATUS_PORT \
        -P=${DB_PORT} \
        --temp-dir=$WORK_DIR/tidb \
        --log-slow-query= $WORK_DIR/db-slow.log \
        --log-file=$WORK_DIR/db.log > $WORK_DIR/db_stdout.log &
    [ "$WHICH" = "UP" ] && up_db_pid=$! || down_db_pid=$! 
}

start_minio() {
    local MINIO_PORT=$1
    local MINIO_DATA_DIR=$2
    # remove old log files if exist
    rm -rf $MINIO_DATA_DIR
    minio server $MINIO_DATA_DIR --address ":${MINIO_PORT}" &
    minio_pid=$!
}

create_bucket() {
    mc alias set dw-minio http://localhost:9000 minioadmin minioadmin
    mc mb dw-minio/cdc-test
}


echo "starting upstream TiDB..."
start_tidb_cluster $UP_PD_PORT $UP_PD_PEER_PORT $UP_KV_PORT $UP_KV_STATUS_PORT $UP_DB_PORT $UP_DB_STATUS_PORT "UP" 

echo "starting minio..."
start_minio $DW_MINIO_PORT $DW_MINIO_DATA_DIR

sleep 3

echo "create bucket"
create_bucket

cleanup() {
    echo "stopping the upstream tidb cluster components..."
    echo "stopping the upstream tidb" 
    kill -9 ${up_db_pid}
    echo "stopping the upstream tikv" 
    kill -9 ${up_kv_pid}
    echo "stopping the upstream pd" 
    kill -9 ${up_pd_pid}

    echo "stopping the downstream minio..."
    kill -9 ${minio_pid} 
    
    exit 0
}

# Trap SIGINT(Ctrl+C) signal and call the cleanup function
trap cleanup SIGINT

while true; do
    sleep 1
done
