const INTERVAL_MS = Number(process.env.WORKER_INTERVAL_MS || 5000);

function tick() {
  const timestamp = new Date().toISOString();
  console.log(`[order-worker] heartbeat ${timestamp}`);
}

console.log('order-worker started');
setInterval(tick, INTERVAL_MS);
