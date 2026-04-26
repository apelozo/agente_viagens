const db = require("../services/databaseService");

function canManageClause(user) {
  if (user.tipo === "Agente de Viagem") {
    return `v.user_id = $1
      OR v.user_id IN (SELECT cliente_id FROM agente_clientes WHERE agente_id = $1)
      OR EXISTS (
        SELECT 1
        FROM viagem_membros vm
        WHERE vm.viagem_id = v.id
          AND vm.user_id = $1
          AND vm.status = 'accepted'
      )`;
  }
  return `v.user_id = $1
    OR EXISTS (
      SELECT 1
      FROM viagem_membros vm
      WHERE vm.viagem_id = v.id
        AND vm.user_id = $1
        AND vm.status = 'accepted'
    )`;
}

async function listViagens(user, page = 1, pageSize = 20) {
  const offset = (page - 1) * pageSize;
  const where = canManageClause(user);
  const result = await db.query(
    `SELECT v.* FROM viagens v
     WHERE ${where}
     ORDER BY v.data_inicial DESC
     LIMIT $2 OFFSET $3`,
    [user.id, pageSize, offset]
  );
  return result.rows;
}

async function createViagem(data) {
  const { descricao, data_inicial, data_final, situacao, user_id } = data;
  const client = await db.pool.connect();
  try {
    await client.query("BEGIN");
    const viagemResult = await client.query(
      "INSERT INTO viagens (descricao, data_inicial, data_final, situacao, user_id) VALUES ($1,$2,$3,$4,$5) RETURNING *",
      [descricao, data_inicial, data_final, situacao, user_id]
    );
    const viagem = viagemResult.rows[0];
    await client.query(
      "INSERT INTO viagem_membros (viagem_id, user_id, role, status, invited_by) VALUES ($1,$2,'owner','accepted',$2) ON CONFLICT (viagem_id, user_id) DO NOTHING",
      [viagem.id, user_id]
    );
    await client.query("COMMIT");
    return viagem;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

/** Retorna true se o usuario pode acessar a viagem (dono ou agente vinculado). */
async function userCanAccessViagem(user, viagemId) {
  const where = canManageClause(user);
  const result = await db.query(`SELECT v.id FROM viagens v WHERE v.id = $2 AND (${where})`, [user.id, viagemId]);
  return result.rows.length > 0;
}

async function userRoleInViagem(userId, viagemId) {
  const result = await db.query(
    `SELECT
      CASE
        WHEN v.user_id = $1 THEN 'owner'
        ELSE vm.role
      END AS role
    FROM viagens v
    LEFT JOIN viagem_membros vm
      ON vm.viagem_id = v.id
      AND vm.user_id = $1
      AND vm.status = 'accepted'
    WHERE v.id = $2
      AND (
        v.user_id = $1
        OR vm.id IS NOT NULL
      )
    LIMIT 1`,
    [userId, viagemId]
  );
  return result.rows[0]?.role || null;
}

module.exports = { listViagens, createViagem, userCanAccessViagem, userRoleInViagem };
