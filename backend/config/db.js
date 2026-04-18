const { Pool } = require("pg");

const connectionString = process.env.DATABASE_URL;

// PostgreSQL gerido (Render, Railway, etc.) exige SSL; localhost em dev normalmente não.
const isLocal =
  !connectionString ||
  /localhost|127\.0\.0\.1/i.test(connectionString);

const pool = new Pool({
  connectionString,
  ssl: isLocal ? undefined : { rejectUnauthorized: false },
});

module.exports = pool;
