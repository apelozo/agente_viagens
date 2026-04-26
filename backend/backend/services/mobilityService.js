const axios = require("axios");
const { distanceApiKey } = require("../config/googleApiConfig");

const SUPPORTED_MODES = ["driving", "walking", "transit"];

function normalizeMode(mode) {
  const value = (mode || "").toString().trim().toLowerCase();
  return SUPPORTED_MODES.includes(value) ? value : "driving";
}

async function fetchDistanceMatrix({ origem, destino, mode, departureTime }) {
  if (!distanceApiKey) throw new Error("GOOGLE_DISTANCE_MATRIX_API_KEY não configurada.");
  const params = {
    origins: `${origem.latitude},${origem.longitude}`,
    destinations: `${destino.latitude},${destino.longitude}`,
    key: distanceApiKey,
    language: "pt-BR",
    mode
  };
  if (departureTime) params.departure_time = departureTime;
  const response = await axios.get("https://maps.googleapis.com/maps/api/distancematrix/json", { params });
  const element = response.data?.rows?.[0]?.elements?.[0];
  return {
    tempo_minutos: element?.duration?.value ? Math.round(element.duration.value / 60) : null,
    distancia_km: element?.distance?.value ? Number((element.distance.value / 1000).toFixed(1)) : null,
    status: element?.status || null
  };
}

async function estimateMobility({ origem, destino, mode, departure_time }) {
  const resolvedMode = normalizeMode(mode);
  const estimate = await fetchDistanceMatrix({
    origem,
    destino,
    mode: resolvedMode,
    departureTime: departure_time || "now"
  });
  return {
    mode: resolvedMode,
    ...estimate
  };
}

async function compareMobility({ origem, destino, modes, departure_time }) {
  const requestedModes = Array.isArray(modes) && modes.length
    ? modes.map(normalizeMode)
    : SUPPORTED_MODES;
  const uniqueModes = [...new Set(requestedModes)];

  const comparison = {};
  for (const mode of uniqueModes) {
    comparison[mode] = await fetchDistanceMatrix({
      origem,
      destino,
      mode,
      departureTime: departure_time || "now"
    });
  }

  const ranked = uniqueModes
    .map((mode) => ({ mode, tempo_minutos: comparison[mode]?.tempo_minutos }))
    .filter((item) => item.tempo_minutos != null)
    .sort((a, b) => a.tempo_minutos - b.tempo_minutos);

  return {
    comparison,
    recommended_mode: ranked[0]?.mode || null,
    generated_at: new Date().toISOString()
  };
}

module.exports = {
  estimateMobility,
  compareMobility,
  SUPPORTED_MODES
};
