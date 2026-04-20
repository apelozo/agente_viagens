const { estimateMobility, compareMobility, SUPPORTED_MODES } = require("../services/mobilityService");

function validatePoint(point) {
  if (!point || typeof point !== "object") return false;
  const lat = Number(point.latitude);
  const lng = Number(point.longitude);
  return Number.isFinite(lat) && Number.isFinite(lng);
}

async function estimate(req, res, next) {
  try {
    const { origem, destino, mode, departure_time } = req.body || {};
    if (!validatePoint(origem) || !validatePoint(destino)) {
      return res.status(400).json({ message: "Origem e destino devem conter latitude e longitude válidas." });
    }
    const data = await estimateMobility({ origem, destino, mode, departure_time });
    return res.json(data);
  } catch (error) {
    return next(error);
  }
}

async function compare(req, res, next) {
  try {
    const { origem, destino, modes, departure_time } = req.body || {};
    if (!validatePoint(origem) || !validatePoint(destino)) {
      return res.status(400).json({ message: "Origem e destino devem conter latitude e longitude válidas." });
    }
    const requested = Array.isArray(modes) && modes.length ? modes : SUPPORTED_MODES;
    const data = await compareMobility({ origem, destino, modes: requested, departure_time });
    return res.json(data);
  } catch (error) {
    return next(error);
  }
}

module.exports = { estimate, compare };
