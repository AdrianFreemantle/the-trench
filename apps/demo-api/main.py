from fastapi import FastAPI

app = FastAPI()


@app.get("/")
async def read_root():
  return {"message": "demo-api ok"}


@app.get("/health")
async def health():
  return {"status": "healthy"}

