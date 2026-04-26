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

function normalizeTrechos(raw, tipo) {
  const parsed = Array.isArray(raw)
    ? raw
    : [
        {
          ponto_a: raw?.ponto_a,
          ponto_b: raw?.ponto_b,
          data_a: raw?.data_a,
          hora_a: raw?.hora_a,
          data_b: raw?.data_b,
          hora_b: raw?.hora_b,
          assentos: raw?.assentos,
        },
      ];

  const trechos = parsed.map((t) => ({
    ponto_a: nullableTrim(t?.ponto_a),
    ponto_b: nullableTrim(t?.ponto_b),
    data_a_raw: t?.data_a,
    hora_a_raw: t?.hora_a,
    data_b_raw: t?.data_b,
    hora_b_raw: t?.hora_b,
    assentos: normalizeAssentos(t?.assentos, tipo),
  }));

  if (tipo === "carro" && trechos.length > 1) {
    return { error: "Carro permite apenas um trecho por reserva." };
  }
  if (trechos.length === 0) {
    return { error: "Informe ao menos um trecho." };
  }

  for (let i = 0; i < trechos.length; i++) {
    const t = trechos[i];
    if (!t.ponto_a || !t.ponto_b) {
      return { error: `Trecho ${i + 1}: preencha origem e destino.` };
    }
    let err = validateDataHoraPair(t.data_a_raw, t.hora_a_raw, `Trecho ${i + 1} (partida/retirada)`);
    if (err) return { error: err };
    err = validateDataHoraPair(t.data_b_raw, t.hora_b_raw, `Trecho ${i + 1} (chegada/devolução)`);
    if (err) return { error: err };

    t.data_a = parseDateInput(t.data_a_raw);
    t.hora_a = parseTimeInput(t.hora_a_raw);
    t.data_b = parseDateInput(t.data_b_raw);
    t.hora_b = parseTimeInput(t.hora_b_raw);

    for (const a of t.assentos) {
      const e = validateAssento(a);
      if (e) return { error: `Trecho ${i + 1}: ${e}` };
    }
  }

  return { trechos };
}

function serializeTrechoRow(row) {
  return {
    ...row,
    data_a: formatDateOut(row.data_a),
    data_b: formatDateOut(row.data_b),
    hora_a: formatTimeOut(row.hora_a),
    hora_b: formatTimeOut(row.hora_b),
  };
}

function toLegacyShape(reserva) {
  const primeiro = reserva.trechos[0] || {};
  return {
    ...reserva,
    ponto_a: primeiro.ponto_a ?? null,
    ponto_b: primeiro.ponto_b ?? null,
    data_a: primeiro.data_a ?? null,
    hora_a: primeiro.hora_a ?? null,
    data_b: primeiro.data_b ?? null,
    hora_b: primeiro.hora_b ?? null,
    assentos: Array.isArray(primeiro.assentos) ? primeiro.assentos : [],
  };
}

async function fetchOneReserva(client, id) {
  const rRes = await client.query(`SELECT * FROM viagem_reservas_transporte WHERE id = $1`, [id]);
  if (rRes.rows.length === 0) return null;
  const reserva = serializeMeioTransporteRow(rRes.rows[0]);

  const tRes = await client.query(
    `SELECT * FROM viagem_reserva_trechos WHERE reserva_id = $1 ORDER BY ordem ASC, id ASC`,
    [id]
  );
  const trechos = tRes.rows.map((r) => ({ ...serializeTrechoRow(r), assentos: [] }));
  const trechoIds = trechos.map((t) => t.id);

  if (trechoIds.length > 0) {
    const aRes = await client.query(
      `SELECT id, trecho_id, numero_assento, nome_passageiro, classe
       FROM viagem_reserva_trecho_assentos
       WHERE trecho_id = ANY($1::int[])
       ORDER BY trecho_id ASC, id ASC`,
      [trechoIds]
    );
    const byTrecho = new Map(trechos.map((t) => [t.id, t]));
    for (const a of aRes.rows) {
      const trecho = byTrecho.get(a.trecho_id);
      if (trecho) {
        trecho.assentos.push({
          id: a.id,
          numero_assento: a.numero_assento,
          nome_passageiro: a.nome_passageiro,
          classe: a.classe,
        });
      }
    }
  }

  return toLegacyShape({ ...reserva, trechos });
}

async function listMeiosTransporte(req, res, next) {
  try {
    const viagemId = Number(req.params.viagemId);
    if (!viagemId) return res.status(400).json({ message: "viagemId inválido." });
    const ok = await viagemModel.userCanAccessViagem(req.user, viagemId);
    if (!ok) return res.status(404).json({ message: "Viagem não encontrada." });

    const mRes = await db.query(
      `SELECT * FROM viagem_reservas_transporte WHERE viagem_id = $1 ORDER BY id ASC`,
      [viagemId]
    );
    const ids = mRes.rows.map((r) => r.id);

    const aRes =
      ids.length === 0
        ? { rows: [] }
        : await db.query(
            `SELECT * FROM viagem_reserva_trechos
             WHERE reserva_id = ANY($1::int[])
             ORDER BY reserva_id ASC, ordem ASC, id ASC`,
            [ids]
          );
    const byMeio = new Map();
    for (const r of mRes.rows) {
      byMeio.set(r.id, { ...serializeMeioTransporteRow(r), trechos: [] });
    }
    for (const t of aRes.rows) {
      const reserva = byMeio.get(t.reserva_id);
      if (reserva) {
        reserva.trechos.push({ ...serializeTrechoRow(t), assentos: [] });
      }
    }

    const trechoIds = aRes.rows.map((t) => t.id);
    if (trechoIds.length > 0) {
      const sRes = await db.query(
        `SELECT id, trecho_id, numero_assento, nome_passageiro, classe
         FROM viagem_reserva_trecho_assentos
         WHERE trecho_id = ANY($1::int[])
         ORDER BY trecho_id ASC, id ASC`,
        [trechoIds]
      );
      const byTrecho = new Map();
      for (const r of byMeio.values()) {
        for (const t of r.trechos) byTrecho.set(t.id, t);
      }
      for (const a of sRes.rows) {
        const trecho = byTrecho.get(a.trecho_id);
        if (trecho) {
          trecho.assentos.push({
            id: a.id,
            numero_assento: a.numero_assento,
            nome_passageiro: a.nome_passageiro,
            classe: a.classe,
          });
        }
      }
    }

    // Fallback para registros legados ainda não migrados para o modelo v2.
    const legacyRes = await db.query(
      `SELECT *
       FROM viagem_meios_transporte
       WHERE viagem_id = $1
       ORDER BY id ASC`,
      [viagemId]
    );
    const legacyIds = legacyRes.rows.map((r) => r.id);
    const legacyAssentosRes =
      legacyIds.length === 0
        ? { rows: [] }
        : await db.query(
            `SELECT id, meio_transporte_id, numero_assento, nome_passageiro, classe
             FROM viagem_meio_transporte_assentos
             WHERE meio_transporte_id = ANY($1::int[])
             ORDER BY meio_transporte_id ASC, id ASC`,
            [legacyIds]
          );
    const assentosPorLegacy = new Map();
    for (const a of legacyAssentosRes.rows) {
      if (!assentosPorLegacy.has(a.meio_transporte_id)) {
        assentosPorLegacy.set(a.meio_transporte_id, []);
      }
      assentosPorLegacy.get(a.meio_transporte_id).push({
        id: a.id,
        numero_assento: a.numero_assento,
        nome_passageiro: a.nome_passageiro,
        classe: a.classe,
      });
    }
    for (const legacy of legacyRes.rows) {
      if (byMeio.has(legacy.id)) continue; // já existe no modelo novo (mesmo id)
      byMeio.set(legacy.id, {
        ...serializeMeioTransporteRow(legacy),
        trechos: [
          {
            id: null,
            reserva_id: legacy.id,
            ordem: 1,
            ponto_a: legacy.ponto_a,
            ponto_b: legacy.ponto_b,
            data_a: formatDateOut(legacy.data_a),
            hora_a: formatTimeOut(legacy.hora_a),
            data_b: formatDateOut(legacy.data_b),
            hora_b: formatTimeOut(legacy.hora_b),
            assentos: assentosPorLegacy.get(legacy.id) ?? [],
          },
        ],
      });
    }

    return res.json([...byMeio.values()].map(toLegacyShape));
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
    const observacoes = nullableTrim(req.body?.observacoes);
    const normalized = normalizeTrechos(req.body?.trechos ?? req.body, tipo);
    if (normalized.error) return res.status(400).json({ message: normalized.error });
    const { trechos } = normalized;

    const client = await db.pool.connect();
    try {
      await client.query("BEGIN");
      const ins = await client.query(
        `INSERT INTO viagem_reservas_transporte
         (viagem_id, tipo, companhia, codigo_localizador, observacoes)
         VALUES ($1,$2,$3,$4,$5) RETURNING *`,
        [viagemId, tipo, companhia, codigo_localizador, observacoes]
      );
      const created = ins.rows[0];
      for (let i = 0; i < trechos.length; i++) {
        const t = trechos[i];
        const tIns = await client.query(
          `INSERT INTO viagem_reserva_trechos
           (reserva_id, ordem, ponto_a, ponto_b, data_a, hora_a, data_b, hora_b)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
           RETURNING id`,
          [created.id, i + 1, t.ponto_a, t.ponto_b, t.data_a, t.hora_a, t.data_b, t.hora_b]
        );
        const trechoId = tIns.rows[0].id;
        for (const a of t.assentos) {
          await client.query(
            `INSERT INTO viagem_reserva_trecho_assentos (trecho_id, numero_assento, nome_passageiro, classe)
             VALUES ($1,$2,$3,$4)`,
            [trechoId, a.numero_assento, a.nome_passageiro, a.classe]
          );
        }
      }
      await client.query("COMMIT");
      const full = await fetchOneReserva(db.pool, created.id);
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
    const observacoes = nullableTrim(req.body?.observacoes);
    const normalized = normalizeTrechos(req.body?.trechos ?? req.body, tipo);
    if (normalized.error) return res.status(400).json({ message: normalized.error });
    const { trechos } = normalized;

    const client = await db.pool.connect();
    try {
      await client.query("BEGIN");
      const cur = await client.query(
        `SELECT id FROM viagem_reservas_transporte WHERE id = $1 AND viagem_id = $2`,
        [mtId, viagemId]
      );
      if (cur.rows.length === 0) {
        await client.query("ROLLBACK");
        return res.status(404).json({ message: "Registro não encontrado." });
      }

      await client.query(
        `UPDATE viagem_reservas_transporte
         SET tipo=$1, companhia=$2, codigo_localizador=$3, observacoes=$4
         WHERE id=$5 AND viagem_id=$6`,
        [tipo, companhia, codigo_localizador, observacoes, mtId, viagemId]
      );

      await client.query(
        `DELETE FROM viagem_reserva_trecho_assentos
         WHERE trecho_id IN (SELECT id FROM viagem_reserva_trechos WHERE reserva_id = $1)`,
        [mtId]
      );
      await client.query(`DELETE FROM viagem_reserva_trechos WHERE reserva_id = $1`, [mtId]);

      for (let i = 0; i < trechos.length; i++) {
        const t = trechos[i];
        const tIns = await client.query(
          `INSERT INTO viagem_reserva_trechos
           (reserva_id, ordem, ponto_a, ponto_b, data_a, hora_a, data_b, hora_b)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
           RETURNING id`,
          [mtId, i + 1, t.ponto_a, t.ponto_b, t.data_a, t.hora_a, t.data_b, t.hora_b]
        );
        const trechoId = tIns.rows[0].id;
        for (const a of t.assentos) {
          await client.query(
            `INSERT INTO viagem_reserva_trecho_assentos (trecho_id, numero_assento, nome_passageiro, classe)
             VALUES ($1,$2,$3,$4)`,
            [trechoId, a.numero_assento, a.nome_passageiro, a.classe]
          );
        }
      }
      await client.query("COMMIT");
      const full = await fetchOneReserva(db.pool, mtId);
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
      `DELETE FROM viagem_reservas_transporte WHERE id = $1 AND viagem_id = $2 RETURNING id`,
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
