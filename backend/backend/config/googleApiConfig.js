module.exports = {
  baseUrl: process.env.GOOGLE_API_BASE_URL || "https://maps.googleapis.com/maps/api",
  placesApiKey: process.env.GOOGLE_PLACES_API_KEY || "",
  distanceApiKey: process.env.GOOGLE_DISTANCE_MATRIX_API_KEY || ""
};
