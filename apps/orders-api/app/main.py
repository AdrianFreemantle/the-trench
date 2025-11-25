from fastapi import FastAPI

app = FastAPI(title="orders-api", version="0.1.0")


@app.get("/healthz")
def healthz():
  return {"status": "ok", "service": "orders-api"}


@app.get("/")
def root():
  return {"message": "orders-api running"}
