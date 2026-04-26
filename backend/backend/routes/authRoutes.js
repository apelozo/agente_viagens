const express = require("express");
const { register, login, forgotPassword, changePassword } = require("../controllers/authController");

const router = express.Router();
router.post("/register", register);
router.post("/login", login);
router.post("/forgot-password", forgotPassword);
router.post("/change-password", changePassword);

module.exports = router;
