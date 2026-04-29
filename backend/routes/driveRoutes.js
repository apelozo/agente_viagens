const express = require("express");
const controller = require("../controllers/driveController");

const router = express.Router();

router.get("/oauth/start", controller.oauthStart);
router.get("/oauth/callback", controller.oauthCallback);

module.exports = router;

