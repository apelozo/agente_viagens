const express = require("express");
const { calculate } = require("../controllers/distanceController");
const { authRequired } = require("../middleware/auth");

const router = express.Router();
router.post("/calculate", authRequired, calculate);

module.exports = router;
