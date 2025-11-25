# catalog-api

Minimal Express service that exposes `/healthz` and a root message so the platform has something to deploy during Phase 0.

## Local development

```bash
npm install
npm run dev
```

Service listens on port `4101` by default. Use `PORT` env var to override.

## Docker

```bash
docker build -t catalog-api:dev .
docker run --rm -p 4101:4101 catalog-api:dev
```

Container entrypoint runs `npm start`.
