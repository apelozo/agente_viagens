const axios = require("axios");
const { distanceApiKey } = require("../config/googleApiConfig");

async function calculateDistance({ origem, destino }) {
  if (!distanceApiKey) throw new Error("GOOGLE_DISTANCE_MATRIX_API_KEY não configurada.");
  const modes = ["driving", "walking", "transit"];
  const baseParams = {
    origins: `${origem.latitude},${origem.longitude}`,
    destinations: `${destino.latitude},${destino.longitude}`,
    key: distanceApiKey,
    language: "pt-BR"
  };

  const results = {};
  for (const mode of modes) {
    const response = await axios.get("https://maps.googleapis.com/maps/api/distancematrix/json", {
      params: { ...baseParams, mode }
    });
    const element = response.data?.rows?.[0]?.elements?.[0];
    results[mode] = {
      tempo_minutos: element?.duration?.value ? Math.round(element.duration.value / 60) : null,
      distancia_km: element?.distance?.value ? Number((element.distance.value / 1000).toFixed(1)) : null
    };
  }

  return results;
}

module.exports = { calculateDistance };
