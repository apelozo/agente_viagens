const { getOAuthStartUrl, handleOAuthCallback } = require("../services/googleDriveService");

async function oauthStart(req, res, next) {
  try {
    const url = getOAuthStartUrl();
    return res.redirect(url);
  } catch (error) {
    return next(error);
  }
}

async function oauthCallback(req, res, next) {
  try {
    const code = (req.query?.code || "").toString().trim();
    if (!code) return res.status(400).send("Código OAuth ausente.");
    await handleOAuthCallback(code);
    return res.status(200).send("Autorização do Google Drive concluída com sucesso.");
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  oauthStart,
  oauthCallback,
};

