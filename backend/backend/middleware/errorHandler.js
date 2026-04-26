module.exports = function errorHandler(error, req, res, next) {
  if (res.headersSent) return next(error);
  console.error(error);
  return res.status(error.status || 500).json({
    message: error.message || "Erro interno no servidor."
  });
};
