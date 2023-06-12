# TiCDC <-> Kafka Local Testing Env
Ensure the kafka is installed locally and accessible through the $PATH

1. Set up the upstream TiDB cluster and the downstream kafka server
```bash
./deploy.sh
```

2. Start the cdc server
```bash
path/to/cdc server
```

3. Create the kafka topic
```bash
kafka-topics.sh --create --topic cdc-test --bootstrap-server localhost:9092
```

4. Create the changefeed
```bash
path/to/cdc cli changefeed create --server=localhost:8300 --sink-uri="kafka://localhost:9092/cdc-test?protocol=canal-json&enable-tidb-extension=true" --changefeed-id="cdc-test" --sort-engine=unified
```

5. Start the consumer 
```bash
kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic cdc-test --from-beginning
```
