const { searchPlaces } = require("../services/googlePlacesService");

async function search(req, res, next) {
  try {
    const data = await searchPlaces(req.body);
    return res.json(data);
  } catch (error) {
    return next(error);
  }
}

module.exports = { search };
