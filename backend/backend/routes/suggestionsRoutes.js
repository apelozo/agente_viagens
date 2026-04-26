const express = require("express");
const controller = require("../controllers/suggestionsController");
const { authRequired } = require("../middleware/auth");

const router = express.Router();

router.use(authRequired);
router.get("/for-bloco/:blocoId", controller.listForBloco);
router.post("/accept", controller.accept);
router.post("/reject", controller.reject);
router.get("/preferences/:viagemId", controller.getPreferences);
router.put("/preferences/:viagemId", controller.upsertPreferences);

module.exports = router;
