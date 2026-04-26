const express = require("express");
const { search } = require("../controllers/placesController");
const { authRequired } = require("../middleware/auth");

const router = express.Router();
router.post("/search", authRequired, search);

module.exports = router;
