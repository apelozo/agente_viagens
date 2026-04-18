const db = require("../services/databaseService");
const { broadcast } = require("../services/websocketService");

function normalizeDate(value) {
  if (value == null || value === "") return null;
  if (value instanceof Date) {
    const y = value.getUTCFullYear();
    const m = String(value.getUTCMonth() + 1).padStart(2, "0");
    const d = String(value.getUTCDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
  }
  if (typeof value !== "string") return null;
  const br = /^(\d{2})\/(\d{2})\/(\d{4})$/;
  const matchBr = value.match(br);
  if (matchBr) {
    const [, dd, mm, yyyy] = matchBr;
    return `${yyyy}-${mm}-${dd}`;
  }
  const iso = value.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (iso) return `${iso[1]}-${iso[2]}-${iso[3]}`;
  return null;
}

function normalizeTime(value) {
  if (value == null || value === "") return null;
  const trimmed = String(value).trim();
  if (!trimmed) return null;
  const withSec = trimmed.match(/^([01]?\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?$/);
  if (!withSec) return null;
  const hh = withSec[1].padStart(2, "0");
  const mm = withSec[2];
  return `${hh}:${mm}:00`;
}

function formatDateToBr(value) {
  if (value == null || value === "") return value;
  if (value instanceof Date) {
    const y = value.getUTCFullYear();
    const m = String(value.getUTCMonth() + 1).padStart(2, "0");
    const d = String(value.getUTCDate()).padStart(2, "0");
    return `${d}/${m}/${y}`;
  }
  const s = String(value);
  const iso = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (iso) return `${iso[3]}/${iso[2]}/${iso[1]}`;
  const br = /^(\d{2})\/(\d{2})\/(\d{4})$/;
  if (br.test(s)) return s;
  return s;
}

function formatTimeToHHmm(value) {
  if (value == null || value === "") return null;
  const text = String(value);
  const match = text.match(/^(\d{1,2}):(\d{2})(?::\d{2})?/);
  if (!match) return text.length >= 5 ? text.substring(0, 5) : text;
  const hh = match[1].padStart(2, "0");
  return `${hh}:${match[2]}`;
}

/** Minutos desde meia-noite; null se invalido */
function timeToMinutes(value) {
  if (value == null || value === "") return null;
  const text = String(value).trim();
  const m = text.match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/);
  if (!m) return null;
  const h = parseInt(m[1], 10);
  const min = parseInt(m[2], 10);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

function validatePayload({ titulo, tipo, data, hora_inicio, hora_fim }) {
  if (!titulo || typeof titulo !== "string" || !titulo.trim()) return "Titulo e obrigatorio.";
  if (!["Evento Fixo", "Tempo Livre"].includes(tipo)) return "Tipo invalido.";
  const normalizedDate = normalizeDate(data);
  if (!normalizedDate) return "Data invalida. Use DD/MM/AAAA.";
  const start = normalizeTime(hora_inicio);
  const end = normalizeTime(hora_fim);
  if (hora_inicio && !start) return "Hora inicio invalida. Use HH:mm.";
  if (hora_fim && !end) return "Hora fim invalida. Use HH:mm.";
  const startMin = timeToMinutes(start);
  const endMin = timeToMinutes(end);
  if (startMin != null && endMin != null && endMin <= startMin) {
    return "Hora fim deve ser maior que hora inicio.";
  }
  return null;
}

function serialize(row) {
  const desc =
    row.descricao === "__gerado_sistema_tempo_livre__" ? null : row.descricao;
  return {
    ...row,
    data: formatDateToBr(row.data),
    hora_inicio: formatTimeToHHmm(row.hora_inicio),
    hora_fim: formatTimeToHHmm(row.hora_fim),
    descricao: desc
  };
}

async function listByViagem(req, res, next) {
  try {
    const { viagemId } = req.params;
    const result = await db.query(
      `SELECT id, viagem_id, titulo, tipo, data, hora_inicio, hora_fim, local, link_url, descricao, created_by, created_at
       FROM roteiro_blocos
       WHERE viagem_id = $1
       ORDER BY data ASC, hora_inicio ASC NULLS LAST, id ASC`,
      [viagemId]
    );
    return res.json(result.rows.map(serialize));
  } catch (error) {
    return next(error);
  }
}

async function create(req, res, next) {
  try {
    const { viagemId } = req.params;
    const {
      titulo,
      tipo,
      data,
      hora_inicio = null,
      hora_fim = null,
      local = null,
      link_url = null,
      descricao = null
    } = req.body;
    const validationError = validatePayload({ titulo, tipo, data, hora_inicio, hora_fim });
    if (validationError) return res.status(400).json({ message: validationError });

    const result = await db.query(
      `INSERT INTO roteiro_blocos (viagem_id, titulo, tipo, data, hora_inicio, hora_fim, local, link_url, descricao, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
      [
        viagemId,
        titulo,
        tipo,
        normalizeDate(data),
        normalizeTime(hora_inicio),
        normalizeTime(hora_fim),
        local,
        link_url,
        descricao,
        req.user.id
      ]
    );
    const payload = serialize(result.rows[0]);
    broadcast("timeline_block_created", payload);
    return res.status(201).json(payload);
  } catch (error) {
    return next(error);
  }
}

async function update(req, res, next) {
  try {
    const { id } = req.params;
    const { titulo, tipo, data, hora_inicio, hora_fim, local, link_url, descricao } = req.body;
    const validationError = validatePayload({ titulo, tipo, data, hora_inicio, hora_fim });
    if (validationError) return res.status(400).json({ message: validationError });
    const result = await db.query(
      `UPDATE roteiro_blocos
       SET titulo = $1,
           tipo = $2,
           data = $3,
           hora_inicio = $4,
           hora_fim = $5,
           local = $6,
           link_url = $7,
           descricao = $8
       WHERE id = $9
       RETURNING *`,
      [titulo, tipo, normalizeDate(data), normalizeTime(hora_inicio), normalizeTime(hora_fim), local, link_url, descricao, id]
    );
    const payload = serialize(result.rows[0]);
    broadcast("timeline_block_updated", payload);
    return res.json(payload);
  } catch (error) {
    return next(error);
  }
}

async function remove(req, res, next) {
  try {
    const existing = await db.query("SELECT viagem_id FROM roteiro_blocos WHERE id = $1", [req.params.id]);
    if (!existing.rows.length) {
      return res.status(404).json({ message: "Bloco nao encontrado." });
    }
    const viagemId = existing.rows[0].viagem_id;
    await db.query("DELETE FROM roteiro_blocos WHERE id = $1", [req.params.id]);
    broadcast("timeline_block_deleted", { id: Number(req.params.id), viagem_id: viagemId });
    return res.status(204).send();
  } catch (error) {
    return next(error);
  }
}

function parsePgDateOnly(value) {
  if (value instanceof Date) {
    return new Date(Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()));
  }
  const s = String(value).slice(0, 10);
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!m) return null;
  return new Date(Date.UTC(parseInt(m[1], 10), parseInt(m[2], 10) - 1, parseInt(m[3], 10)));
}

/** Cria um bloco Tempo Livre por dia entre data_inicial e data_final da viagem (idempotente por dia). */
async function gerarTempoLivrePorDia(req, res, next) {
  try {
    const { viagemId } = req.params;
    const trip = await db.query("SELECT id, data_inicial, data_final FROM viagens WHERE id = $1", [viagemId]);
    if (!trip.rows.length) return res.status(404).json({ message: "Viagem nao encontrada." });

    const start = parsePgDateOnly(trip.rows[0].data_inicial);
    const end = parsePgDateOnly(trip.rows[0].data_final);
    if (!start || !end || start > end) {
      return res.status(400).json({ message: "Datas da viagem invalidas." });
    }

    const criados = [];
    const cur = new Date(start.getTime());
    const endT = end.getTime();

    while (cur.getTime() <= endT) {
      const y = cur.getUTCFullYear();
      const mo = String(cur.getUTCMonth() + 1).padStart(2, "0");
      const d = String(cur.getUTCDate()).padStart(2, "0");
      const iso = `${y}-${mo}-${d}`;

      const dup = await db.query(
        `SELECT id FROM roteiro_blocos
         WHERE viagem_id = $1 AND data = $2::date AND descricao = '__gerado_sistema_tempo_livre__'
         LIMIT 1`,
        [viagemId, iso]
      );
      if (!dup.rows.length) {
        const titulo = `Tempo livre — ${d}/${mo}/${y}`;
        const ins = await db.query(
          `INSERT INTO roteiro_blocos (viagem_id, titulo, tipo, data, hora_inicio, hora_fim, local, link_url, descricao, created_by)
           VALUES ($1, $2, 'Tempo Livre', $3::date, NULL, NULL, NULL, NULL, '__gerado_sistema_tempo_livre__', $4)
           RETURNING *`,
          [viagemId, titulo, iso, req.user.id]
        );
        const payload = serialize(ins.rows[0]);
        broadcast("timeline_block_created", payload);
        criados.push(payload);
      }
      cur.setUTCDate(cur.getUTCDate() + 1);
    }

    return res.status(201).json({ message: "Blocos gerados.", criados: criados.length, blocos: criados });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  listByViagem,
  create,
  update,
  remove,
  gerarTempoLivrePorDia
};
