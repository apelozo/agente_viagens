const axios = require("axios");
const { baseUrl, placesApiKey } = require("../config/googleApiConfig");

async function searchPlaces({ latitude, longitude, tipo_lugar, query }) {
  if (!placesApiKey) throw new Error("GOOGLE_PLACES_API_KEY não configurada.");
  const url = `${baseUrl}/place/textsearch/json`;
  const locationBias = latitude && longitude ? ` location:${latitude},${longitude}` : "";
  const params = {
    query: `${query}${locationBias}`.trim(),
    key: placesApiKey,
    language: "pt-BR"
  };
  // Text Search: omitir `type` quando nao pedido — evita filtrar demais (ex.: shopping so com "store").
  if (tipo_lugar) params.type = tipo_lugar;

  const response = await axios.get(url, { params });

  return (response.data.results || []).map((item) => ({
    nome: item.name,
    endereco: item.formatted_address,
    rating: item.rating || null,
    foto_url: item.photos?.length
      ? `${baseUrl}/place/photo?maxwidth=400&photo_reference=${item.photos[0].photo_reference}&key=${placesApiKey}`
      : null,
    horario_funcionamento: item.opening_hours?.open_now,
    latitude: item.geometry?.location?.lat || null,
    longitude: item.geometry?.location?.lng || null
  }));
}

module.exports = { searchPlaces };
