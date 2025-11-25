# orders-api

FastAPI skeleton that exposes `/healthz` and `/` so the platform can deploy a Python service during Phase 0.

## Local development

This service uses [uv](https://docs.astral.sh/uv/) for dependency management.

```bash
uv sync --frozen
uv run uvicorn app.main:app --reload --port 4102
```

## Docker

```bash
docker build -t orders-api:dev .
docker run --rm -p 4102:4102 orders-api:dev
```

Container entrypoint launches `uvicorn app.main:app` on port `4102`.
