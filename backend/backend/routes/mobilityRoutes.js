const express = require("express");
const { authRequired } = require("../middleware/auth");
const { estimate, compare } = require("../controllers/mobilityController");

const router = express.Router();

router.post("/estimate", authRequired, estimate);
router.post("/compare", authRequired, compare);

module.exports = router;
