const express = require("express");
const controller = require("../controllers/wishlistController");
const { authRequired } = require("../middleware/auth");

const router = express.Router();

router.use(authRequired);
router.get("/:viagemId", controller.listByViagem);
router.post("/:viagemId/import-place", controller.importPlace);
router.post("/:viagemId", controller.create);
router.put("/item/:id", controller.update);
router.delete("/item/:id", controller.remove);

module.exports = router;
