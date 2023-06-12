# TiCDC <-> MinIO Local Testing Env Setup
Ensure to install MinIO locally.

1. Setup TiDB and MinIO
```bash
./deploy.sh
```

2. Start the CDC server
```bash
path/to/cdc server
```

3. Create the changefeed
```bash
cdc cli changefeed create --server=http://localhost:8300 --sink-uri="s3://cdc-test?endpoint=http://localhost:9000&protocol=canal-json&access-key=minioadmin&secret-access-key=minioadmin&enable-tidb-extension=true" --changefeed-id="cdc-test"
```
