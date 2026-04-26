const { calculateDistance } = require("../services/googleDistanceService");

async function calculate(req, res, next) {
  try {
    const data = await calculateDistance(req.body);
    return res.json(data);
  } catch (error) {
    return next(error);
  }
}

module.exports = { calculate };
