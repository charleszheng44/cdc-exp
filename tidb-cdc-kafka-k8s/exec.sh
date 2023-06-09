#!/usr/bin/env bash
echo "creating kafka topic"
kubectl exec -it tidb-debug -c kafka-cli -- /bin/bash -c "kafka-topics.sh --create --topic cdc-test --bootstrap-server cdc-kafka:9092"
sleep 2

echo "creating the changefeed"
kubectl exec -it tidb-debug -- /bin/bash -c "cdc cli changefeed create --server=upstream-tidb-ticdc-peer.upstream:8301 --changefeed-id=\"cdc-test\" --sort-engine=\"unified\" --sink-uri=\"kafka://cdc-kafka.default.svc.cluster.local:9092/cdc-test?protocol=canal-json\""
sleep 2

echo "using sysbench to insert some sample data"
# kubectl exec -it tidb-debug -- /bin/bash -c "sysbench --mysql-host=upstream-tidb-tidb.upstream --mysql-user=root --mysql-port=4000 --mysql-db=test oltp_insert --tables=5 --threads=8 --time=60 --report-interval=10 --table-size=1000 prepare"

kubectl exec -it tidb-debug -- /bin/bash -c "sysbench --db-driver=mysql --mysql-host=localhost --mysql-port=4000 --mysql-user=root --mysql-db=test --table-size=1000 --tables=5 --threads=5 --time=300 --report-interval=10 oltp_write_only run"
