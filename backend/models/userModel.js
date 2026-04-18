const db = require("../services/databaseService");

async function createUser({ nome, tipo, email, senha, status = "Ativa" }) {
  const result = await db.query(
    "INSERT INTO usuarios (nome, tipo, email, senha, status) VALUES ($1,$2,$3,$4,$5) RETURNING id,nome,tipo,email,status",
    [nome, tipo, email, senha, status]
  );
  return result.rows[0];
}

async function findByEmail(email) {
  const result = await db.query("SELECT * FROM usuarios WHERE email = $1", [email]);
  return result.rows[0] || null;
}

async function updatePasswordById(userId, passwordHash) {
  await db.query("UPDATE usuarios SET senha = $1 WHERE id = $2", [passwordHash, userId]);
}

module.exports = { createUser, findByEmail, updatePasswordById };
