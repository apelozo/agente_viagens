const db = require("../services/databaseService");
const viagemModel = require("../models/viagemModel");
const { broadcast } = require("../services/websocketService");

const TIPOS = new Set(["voo", "carro", "trem"]);
const CLASSES = new Set(["economica", "economica_premium", "executiva", "primeira"]);

async function assertCanEdit(req, viagemId) {
  const ok = await viagemModel.userCanAccessViagem(req.user, viagemId);
  if (!ok) return { error: 404, message: "Viagem não encontrada." };
  const role = await viagemModel.userRoleInViagem(req.user.id, viagemId);
  if (!role || role === "viewer") return { error: 403, message: "Sem permissão para editar." };
  return { ok: true };
}

function normalizeAssentos(raw, tipo) {
  if (tipo === "carro") return [];
  if (!Array.isArray(raw)) return [];
  return raw.map((a) => ({
    numero_assento: (a?.numero_assento ?? "").toString().trim(),
    nome_passageiro: (a?.nome_passageiro ?? "").toString().trim(),
    classe: (a?.classe ?? "").toString().trim(),
  }));
}

function validateAssento(a) {
  if (!a.numero_assento || !a.nome_passageiro) return "Cada assento precisa de número e nome do passageiro.";
  if (!CLASSES.has(a.classe)) {
    return "Classe inválida. Use: economica, economica_premium, executiva ou primeira.";
  }
  return null;
}

function nullableTrim(value) {
  if (value == null) return null;
  const t = String(value).trim();
  return t.length === 0 ? null : t;
}

/** Aceita YYYY-MM-DD ou DD/MM/YYYY → retorna YYYY-MM-DD para o PostgreSQL. */
function parseDateInput(value) {
  const s = nullableTrim(value);
  if (s == null) return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
  const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(s);
  if (!m) return null;
  const y = Number(m[3]);
  const mo = Number(m[2]);
  const d = Number(m[1]);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  const dt = new Date(Date.UTC(y, mo - 1, d));
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== mo - 1 || dt.getUTCDate() !== d) return null;
  return `${m[3]}-${m[2]}-${m[1]}`;
}

/** Aceita HH:mm (24 h) → retorna string para TIME. */
function parseTimeInput(value) {
  const s = nullableTrim(value);
  if (s == null) return null;
  const m = /^(\d{2}):(\d{2})$/.exec(s);
  if (!m) return null;
  const hh = Number(m[1]);
  const mm = Number(m[2]);
  if (hh > 23 || mm > 59) return null;
  return `${m[1]}:${m[2]}:00`;
}

function validateDataHoraPair(rawD, rawH, label) {
  const rd = rawD == null ? "" : String(rawD).trim();
  const rt = rawH == null ? "" : String(rawH).trim();
  const hasD = rd.length > 0;
  const hasH = rt.length > 0;
  if (hasD !== hasH) {
    return `${label}: informe data e hora juntos ou deixe os dois vazios.`;
  }
  if (!hasD) return null;
  const pd = parseDateInput(rd);
  const pt = parseTimeInput(rt);
  if (!pd) return `${label}: data inválida. Use aaaa-mm-dd ou dd/mm/aaaa.`;
  if (!pt) return `${label}: hora inválida. Use hh:mm (24 h).`;
  return null;
}

function formatDateOut(v) {
  if (v == null || v === undefined) return null;
  if (v instanceof Date) {
    const y = v.getFullYear();
    const m = String(v.getMonth() + 1).padStart(2, "0");
    const d = String(v.getDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
  }
  const s = String(v);
  if (s.length >= 10 && /^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10);
  return s;
}

function formatTimeOut(v) {
  if (v == null || v === undefined) return null;
  if (typeof v === "string") {
    const parts = v.split(":");
    if (parts.length >= 2) {
      return `${parts[0].padStart(2, "0")}:${parts[1].padStart(2, "0")}`;
    }
  }
  if (v instanceof Date) {
    const hh = String(v.getUTCHours()).padStart(2, "0");
    const mm = String(v.getUTCMinutes()).padStart(2, "0");
    return `${hh}:${mm}`;
  }
  const s = String(v);
  return s.length >= 5 ? s.slice(0, 5) : s;
}

function serializeMeioTransporteRow(row) {
  if (!row) return row;
  return {
    ...row,
    data_a: formatDateOut(row.data_a),
    data_b: formatDateOut(row.data_b),
    hora_a: formatTimeOut(row.hora_a),
    hora_b: formatTimeOut(row.hora_b),
  };
}

async function fetchOneWithAssentos(client, id) {
  const mRes = await client.query(`SELECT * FROM viagem_meios_transporte WHERE id = $1`, [id]);
  if (mRes.rows.length === 0) return null;
  const row = serializeMeioTransporteRow(mRes.rows[0]);
  const aRes = await client.query(
    `SELECT id, numero_assento, nome_passageiro, classe
     FROM viagem_meio_transporte_assentos
     WHERE meio_transporte_id = $1
     ORDER BY id ASC`,
    [id]
  );
  return { ...row, assentos: aRes.rows };
}

async function listMeiosTransporte(req, res, next) {
  try {
    const viagemId = Number(req.params.viagemId);
    if (!viagemId) return res.status(400).json({ message: "viagemId inválido." });
    const ok = await viagemModel.userCanAccessViagem(req.user, viagemId);
    if (!ok) return res.status(404).json({ message: "Viagem não encontrada." });

    const mRes = await db.query(
      `SELECT * FROM viagem_meios_transporte WHERE viagem_id = $1 ORDER BY id ASC`,
      [viagemId]
    );
    const ids = mRes.rows.map((r) => r.id);
    if (ids.length === 0) return res.json([]);

    const aRes = await db.query(
      `SELECT id, meio_transporte_id, numero_assento, nome_passageiro, classe
       FROM viagem_meio_transporte_assentos
       WHERE meio_transporte_id = ANY($1::int[])
       ORDER BY meio_transporte_id ASC, id ASC`,
      [ids]
    );
    const byMeio = new Map();
    for (const r of mRes.rows) {
      byMeio.set(r.id, { ...serializeMeioTransporteRow(r), assentos: [] });
    }
    for (const a of aRes.rows) {
      const list = byMeio.get(a.meio_transporte_id);
      if (list) {
        list.assentos.push({
          id: a.id,
          numero_assento: a.numero_assento,
          nome_passageiro: a.nome_passageiro,
          classe: a.classe,
        });
      }
    }
    return res.json([...byMeio.values()]);
  } catch (error) {
    return next(error);
  }
}

async function createMeioTransporte(req, res, next) {
  try {
    const viagemId = Number(req.params.viagemId);
    if (!viagemId) return res.status(400).json({ message: "viagemId inválido." });
    const gate = await assertCanEdit(req, viagemId);
    if (gate.error) return res.status(gate.error).json({ message: gate.message });

    const tipo = (req.body?.tipo || "").toString().trim();
    if (!TIPOS.has(tipo)) return res.status(400).json({ message: "tipo deve ser voo, carro ou trem." });

    const companhia = nullableTrim(req.body?.companhia);
    const codigo_localizador = nullableTrim(req.body?.codigo_localizador);
    const ponto_a = nullableTrim(req.body?.ponto_a);
    const ponto_b = nullableTrim(req.body?.ponto_b);

    let err = validateDataHoraPair(req.body?.data_a, req.body?.hora_a, "Partida / retirada");
    if (err) return res.status(400).json({ message: err });
    err = validateDataHoraPair(req.body?.data_b, req.body?.hora_b, "Chegada / devolução");
    if (err) return res.status(400).json({ message: err });

    const data_a = parseDateInput(req.body?.data_a);
    const hora_a = parseTimeInput(req.body?.hora_a);
    const data_b = parseDateInput(req.body?.data_b);
    const hora_b = parseTimeInput(req.body?.hora_b);

    const assentos = normalizeAssentos(req.body?.assentos, tipo);
    for (const a of assentos) {
      const e = validateAssento(a);
      if (e) return res.status(400).json({ message: e });
    }

    const client = await db.pool.connect();
    try {
      await client.query("BEGIN");
      const ins = await client.query(
        `INSERT INTO viagem_meios_transporte
         (viagem_id, tipo, companhia, codigo_localizador, ponto_a, ponto_b, data_a, hora_a, data_b, hora_b)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
        [viagemId, tipo, companhia, codigo_localizador, ponto_a, ponto_b, data_a, hora_a, data_b, hora_b]
      );
      const created = ins.rows[0];
      for (const a of assentos) {
        await client.query(
          `INSERT INTO viagem_meio_transporte_assentos (meio_transporte_id, numero_assento, nome_passageiro, classe)
           VALUES ($1,$2,$3,$4)`,
          [created.id, a.numero_assento, a.nome_passageiro, a.classe]
        );
      }
      await client.query("COMMIT");
      const full = await fetchOneWithAssentos(db.pool, created.id);
      broadcast("viagem_meios_transporte_created", { viagem_id: viagemId, ...full });
      return res.status(201).json(full);
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  } catch (error) {
    return next(error);
  }
}

async function updateMeioTransporte(req, res, next) {
  try {
    const viagemId = Number(req.params.viagemId);
    const mtId = Number(req.params.mtId);
    if (!viagemId || !mtId) return res.status(400).json({ message: "Parâmetros inválidos." });
    const gate = await assertCanEdit(req, viagemId);
    if (gate.error) return res.status(gate.error).json({ message: gate.message });

    const tipo = (req.body?.tipo || "").toString().trim();
    if (!TIPOS.has(tipo)) return res.status(400).json({ message: "tipo deve ser voo, carro ou trem." });

    const companhia = nullableTrim(req.body?.companhia);
    const codigo_localizador = nullableTrim(req.body?.codigo_localizador);
    const ponto_a = nullableTrim(req.body?.ponto_a);
    const ponto_b = nullableTrim(req.body?.ponto_b);

    let err = validateDataHoraPair(req.body?.data_a, req.body?.hora_a, "Partida / retirada");
    if (err) return res.status(400).json({ message: err });
    err = validateDataHoraPair(req.body?.data_b, req.body?.hora_b, "Chegada / devolução");
    if (err) return res.status(400).json({ message: err });

    const data_a = parseDateInput(req.body?.data_a);
    const hora_a = parseTimeInput(req.body?.hora_a);
    const data_b = parseDateInput(req.body?.data_b);
    const hora_b = parseTimeInput(req.body?.hora_b);

    const assentos = normalizeAssentos(req.body?.assentos, tipo);
    for (const a of assentos) {
      const e = validateAssento(a);
      if (e) return res.status(400).json({ message: e });
    }

    const client = await db.pool.connect();
    try {
      await client.query("BEGIN");
      const cur = await client.query(
        `SELECT id FROM viagem_meios_transporte WHERE id = $1 AND viagem_id = $2`,
        [mtId, viagemId]
      );
      if (cur.rows.length === 0) {
        await client.query("ROLLBACK");
        return res.status(404).json({ message: "Registro não encontrado." });
      }

      await client.query(
        `UPDATE viagem_meios_transporte
         SET tipo=$1, companhia=$2, codigo_localizador=$3, ponto_a=$4, ponto_b=$5,
             data_a=$6, hora_a=$7, data_b=$8, hora_b=$9
         WHERE id=$10 AND viagem_id=$11`,
        [tipo, companhia, codigo_localizador, ponto_a, ponto_b, data_a, hora_a, data_b, hora_b, mtId, viagemId]
      );

      await client.query(`DELETE FROM viagem_meio_transporte_assentos WHERE meio_transporte_id = $1`, [mtId]);
      for (const a of assentos) {
        await client.query(
          `INSERT INTO viagem_meio_transporte_assentos (meio_transporte_id, numero_assento, nome_passageiro, classe)
           VALUES ($1,$2,$3,$4)`,
          [mtId, a.numero_assento, a.nome_passageiro, a.classe]
        );
      }
      await client.query("COMMIT");
      const full = await fetchOneWithAssentos(db.pool, mtId);
      broadcast("viagem_meios_transporte_updated", { viagem_id: viagemId, ...full });
      return res.json(full);
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  } catch (error) {
    return next(error);
  }
}

async function deleteMeioTransporte(req, res, next) {
  try {
    const viagemId = Number(req.params.viagemId);
    const mtId = Number(req.params.mtId);
    if (!viagemId || !mtId) return res.status(400).json({ message: "Parâmetros inválidos." });
    const gate = await assertCanEdit(req, viagemId);
    if (gate.error) return res.status(gate.error).json({ message: gate.message });

    const result = await db.query(
      `DELETE FROM viagem_meios_transporte WHERE id = $1 AND viagem_id = $2 RETURNING id`,
      [mtId, viagemId]
    );
    if (result.rows.length === 0) return res.status(404).json({ message: "Registro não encontrado." });
    broadcast("viagem_meios_transporte_deleted", { viagem_id: viagemId, id: mtId });
    return res.status(204).send();
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  listMeiosTransporte,
  createMeioTransporte,
  updateMeioTransporte,
  deleteMeioTransporte,
};
