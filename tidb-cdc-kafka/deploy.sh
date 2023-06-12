#!/usr/bin/env bash

: ${UP_PD_PORT=2379}
: ${UP_PD_PEER_PORT=2380}
: ${UP_KV_PORT=20160}
: ${UP_KV_STATUS_PORT=20180}
: ${UP_DB_PORT=4000}
: ${UP_DB_STATUS_PORT=10080}

: ${DW_KAFKA_PORT=9092}

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

start_kafka() {
    # remove old log files if exist
    rm -rf /tmp/kraft-combined-logs
    KAFKA_CLUSTER_ID=$(kafka-storage.sh random-uuid) 
    kafka-storage.sh format \
        -t $KAFKA_CLUSTER_ID \
        -c ~/.kafka/config/kraft/server.properties
    kafka-server-start.sh ~/.kafka/config/kraft/server.properties &
    kafka_pid=$!
}

# start_cdc() {
#     local PD_PORT=$1
#     local DW_DB_PORT=$2
#     local WORK_DIR=cdc
#     rm -rf $WORK_DIR
#     mkdir $WORK_DIR
#     $CDC server \
#         --pd "http://127.0.0.1:$PD_PORT" \
#         --data-dir=$WORK_DIR \
#         --log-file=$WORK_DIR/cdc.log &
#     cdc_pid=$!
#     sleep 10
#     # create a sample changefeed monitoring all dbs and tables
#     for i in $(seq 1 $NUM_CHANGEFEEDS);
#     do
#         $CDC cli changefeed create \
#             --server=http://127.0.0.1:8300 \
#             --sink-uri="mysql://root@127.0.0.1:${DW_DB_PORT}/" \
#             --changefeed-id="default-changefeed-$i"
#     done
# }

echo "starting upstream TiDB..."
start_tidb_cluster $UP_PD_PORT $UP_PD_PEER_PORT $UP_KV_PORT $UP_KV_STATUS_PORT $UP_DB_PORT $UP_DB_STATUS_PORT "UP" 

echo "starting kafka..."
start_kafka $DW_KAFKA_PORT

# sleep 10

# echo "starting CDC server..."
# start_cdc $UP_PD_PORT $DW_DB_PORT

cleanup() {
    echo "stopping the upstream tidb cluster components..."
    echo "stopping the upstream tidb" 
    kill -9 ${up_db_pid}
    echo "stopping the upstream tikv" 
    kill -9 ${up_kv_pid}
    echo "stopping the upstream pd" 
    kill -9 ${up_pd_pid}

    echo "stopping the downstream kafka..."
    kill -9 ${kafka_pid} 
    
    # echo "stopping the cdc server"
    # kill -9 ${cdc_pid}

    exit 0
}

# Trap SIGINT(Ctrl+C) signal and call the cleanup function
trap cleanup SIGINT

while true; do
    sleep 1
done
