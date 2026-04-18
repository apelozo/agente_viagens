const buckets = new Map();
const WINDOW_MS = 60 * 1000;
const LIMIT = 100;

module.exports = function rateLimiter(req, res, next) {
  const key = req.ip || req.socket.remoteAddress || "unknown";
  const now = Date.now();
  const bucket = buckets.get(key) || { count: 0, resetAt: now + WINDOW_MS };

  if (now > bucket.resetAt) {
    bucket.count = 0;
    bucket.resetAt = now + WINDOW_MS;
  }

  bucket.count += 1;
  buckets.set(key, bucket);

  res.setHeader("X-RateLimit-Limit", LIMIT);
  res.setHeader("X-RateLimit-Remaining", Math.max(0, LIMIT - bucket.count));

  if (bucket.count > LIMIT) {
    return res.status(429).json({ message: "Limite de requisições excedido. Tente novamente em 1 minuto." });
  }
  return next();
};
