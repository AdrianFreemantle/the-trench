FROM python:3.12-slim

ENV UV_PROJECT_ENVIRONMENT=/app/.venv \
    PORT=4102

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir uv && \
    adduser --disabled-password --gecos "" appuser

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-install-project && \
    chown -R appuser:appuser /app

COPY app ./app

EXPOSE 4102

USER appuser

CMD ["uv", "run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "4102"]
