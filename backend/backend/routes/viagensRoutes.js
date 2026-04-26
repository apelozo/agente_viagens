const express = require("express");
const controller = require("../controllers/viagensController");
const meiosTransporteController = require("../controllers/meiosTransporteController");
const { authRequired } = require("../middleware/auth");

const router = express.Router();
const validEntities = ["cidades", "hoteis", "restaurantes", "passeios"];

router.use(authRequired);
router.get("/", controller.listViagens);
router.post("/", controller.createViagem);
router.put("/:id", controller.updateViagem);
router.delete("/:id", controller.deleteViagem);
router.get("/:id/members", controller.listMembers);
router.post("/:id/members/invite", controller.inviteMember);
router.patch("/:id/members/:memberId", controller.updateMember);
router.get("/invites/pending", controller.listMyPendingInvites);
router.post("/invites/accept", controller.acceptInvite);
router.post("/invites/decline", controller.declineInvite);

router.get("/:viagemId/meios-transporte", meiosTransporteController.listMeiosTransporte);
router.post("/:viagemId/meios-transporte", meiosTransporteController.createMeioTransporte);
router.put("/:viagemId/meios-transporte/:mtId", meiosTransporteController.updateMeioTransporte);
router.delete("/:viagemId/meios-transporte/:mtId", meiosTransporteController.deleteMeioTransporte);

router.get("/:entity/:parentId", (req, res, next) => {
  if (!validEntities.includes(req.params.entity)) return res.status(400).json({ message: "Entidade inválida." });
  return controller.listByParent(req, res, next);
});
router.post("/:entity/:parentId", (req, res, next) => {
  if (!validEntities.includes(req.params.entity)) return res.status(400).json({ message: "Entidade inválida." });
  return controller.createByEntity(req, res, next);
});
router.put("/:entity/item/:id", (req, res, next) => {
  if (!validEntities.includes(req.params.entity)) return res.status(400).json({ message: "Entidade inválida." });
  return controller.updateEntity(req, res, next);
});
router.delete("/:entity/item/:id", (req, res, next) => {
  if (!validEntities.includes(req.params.entity)) return res.status(400).json({ message: "Entidade inválida." });
  return controller.deleteEntity(req, res, next);
});

module.exports = router;
