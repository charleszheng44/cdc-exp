Setting up a kafka consumer for listening

```bash
kubectl exec -it tidb-debug -c kafka-cli -- /bin/bash -c "kafka-console-consumer.sh --bootstrap-server cdc-kafka.default.svc.cluster.local:9092 --topic cdc-test --from-beginning"
```
