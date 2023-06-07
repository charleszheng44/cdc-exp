# How to setup the environment

1. create kafka topic
```bash
kubectl exec -it tidb-debug -c kafka-cli -- /bin/bash
kafka-topics.sh --create --topic cdc-test --bootstrap-server cdc-kafka:9092
```

2. create the changefeed
```bash
kubectl exec -it tidb-debug -- /bin/bash
cdc cli changefeed create --server=upstream-tidb-ticdc-peer.upstream:8301 --changefeed-id="cdc-test" --sort-engine="unified" --sink-uri="kafka://cdc-kafka.default.svc.cluster.local:9092/cdc-test?protocol=canal-json"
```

3. set up a kafka consumer for listening
```bash
kubectl exec -it tidb-debug -c kafka-cli -- /bin/bash
kafka-console-consumer.sh \
            --bootstrap-server cdc-kafka.default.svc.cluster.local:9092 \
            --topic cdc-test \
            --from-beginning
```

4. use sysbench to generate some sample data
```bash
kubectl exec -it tidb-debug -- /bin/bash
sysbench --mysql-host=upstream-tidb-tidb.upstream --mysql-user=root --mysql-port=4000 --mysql-db=test2 oltp_insert --tables=5 --threads=8 --time=60 --report-interval=10 --table-size=1000 prepare
```
