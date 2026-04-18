const express = require("express");
const controller = require("../controllers/timelineController");
const { authRequired } = require("../middleware/auth");

const router = express.Router();

router.use(authRequired);
// POST gerar-tempo-livre-dias registrado em server.js (rota explicita no app)
router.get("/:viagemId", controller.listByViagem);
router.post("/:viagemId", controller.create);
router.put("/item/:id", controller.update);
router.delete("/item/:id", controller.remove);

module.exports = router;
