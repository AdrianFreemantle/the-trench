# order-worker

Minimal heartbeat worker that simulates background processing for The Trench lab.

## Local development

```bash
npm install
npm run dev
```

Set `WORKER_INTERVAL_MS` to adjust the heartbeat interval (default 5000ms).

## Docker

```bash
docker build -t order-worker:dev .
docker run --rm order-worker:dev
```
