const pool = require("../config/db");

async function query(text, params = []) {
  return pool.query(text, params);
}

module.exports = {
  query,
  pool
};
