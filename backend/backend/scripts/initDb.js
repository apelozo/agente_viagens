const fs = require("fs");
const path = require("path");
require("dotenv").config();
const { pool } = require("../services/databaseService");

async function run() {
  const sqlPath = path.join(__dirname, "..", "models", "schema.sql");
  const sql = fs.readFileSync(sqlPath, "utf8");
  await pool.query(sql);
  console.log("Banco inicializado com sucesso.");
  await pool.end();
}

run().catch((err) => {
  console.error("Erro ao inicializar banco:", err.message);
  process.exit(1);
});
