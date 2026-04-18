const db = require("../services/databaseService");
const viagemModel = require("../models/viagemModel");
const { broadcast } = require("../services/websocketService");
const { haversineKm } = require("../utils/geo");

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

function serializeBlock(row) {
  const desc = row.descricao === "__gerado_sistema_tempo_livre__" ? null : row.descricao;
  return {
    ...row,
    data: formatDateToBr(row.data),
    hora_inicio: formatTimeToHHmm(row.hora_inicio),
    hora_fim: formatTimeToHHmm(row.hora_fim),
    descricao: desc
  };
}

function parseTimeToMinutes(t) {
  if (t == null || t === "") return null;
  const s = String(t).trim();
  const m = s.match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?/);
  if (!m) return null;
  const h = parseInt(m[1], 10);
  const min = parseInt(m[2], 10);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

function windowMinutesFromRow(row) {
  const start = row.hora_inicio != null ? parseTimeToMinutes(row.hora_inicio) : null;
  const end = row.hora_fim != null ? parseTimeToMinutes(row.hora_fim) : null;
  if (start == null || end == null || end <= start) return null;
  return end - start;
}

function estimateDurationMinutes(categoria) {
  switch (categoria) {
    case "Comer":
      return 90;
    case "Visitar":
      return 120;
    case "Comprar":
      return 60;
    case "Outras":
      return 90;
    default:
      return 90;
  }
}

async function tripAnchorLatLng(viagemId) {
  const r = await db.query(
    `SELECT latitude, longitude FROM cidades WHERE viagem_id = $1 AND latitude IS NOT NULL AND longitude IS NOT NULL`,
    [viagemId]
  );
  if (!r.rows.length) return null;
  let sumLat = 0;
  let sumLng = 0;
  let n = 0;
  for (const row of r.rows) {
    const la = Number(row.latitude);
    const ln = Number(row.longitude);
    if (!Number.isFinite(la) || !Number.isFinite(ln)) continue;
    sumLat += la;
    sumLng += ln;
    n += 1;
  }
  if (!n) return null;
  return { latitude: sumLat / n, longitude: sumLng / n };
}

function serializeWishlist(row) {
  return {
    ...row,
    latitude: row.latitude != null ? Number(row.latitude) : null,
    longitude: row.longitude != null ? Number(row.longitude) : null,
    rating: row.rating != null ? Number(row.rating) : null
  };
}

function scoreItem({ item, anchor, prefs }) {
  const preferCats = (prefs?.prefer_categorias || "")
    .split(/[,;]/)
    .map((s) => s.trim())
    .filter(Boolean);

  let distKm = null;
  let distScore = 20;
  if (anchor && item.latitude != null && item.longitude != null) {
    distKm = haversineKm(anchor.latitude, anchor.longitude, item.latitude, item.longitude);
    distScore = 40 * Math.max(0, 1 - Math.min(distKm, 200) / 200);
  }

  let statusScore = 0;
  if (item.status === "nao_visitado") statusScore = 25;
  else if (item.status === "planejado") statusScore = 15;

  const rating = item.rating != null ? Number(item.rating) : null;
  const ratingScore = rating != null && rating >= 0 ? (rating / 5) * 15 : 0;

  let catScore = 8;
  if (preferCats.length) {
    catScore = preferCats.includes(item.categoria) ? 20 : 3;
  }

  const total = Math.round((distScore + statusScore + ratingScore + catScore) * 10) / 10;
  return {
    score: total,
    breakdown: {
      distancia_km: distKm != null ? Math.round(distKm * 100) / 100 : null,
      pontos_proximidade: Math.round(distScore * 10) / 10,
      pontos_status: statusScore,
      pontos_avaliacao: Math.round(ratingScore * 10) / 10,
      pontos_categoria: catScore
    }
  };
}

async function listForBloco(req, res, next) {
  try {
    const blocoId = Number(req.params.blocoId);
    const br = await db.query(`SELECT * FROM roteiro_blocos WHERE id = $1`, [blocoId]);
    if (!br.rows.length) return res.status(404).json({ message: "Bloco nao encontrado." });
    const bloco = br.rows[0];
    if (bloco.tipo !== "Tempo Livre") {
      return res.status(400).json({ message: "Sugestoes so para blocos Tempo Livre." });
    }
    const ok = await viagemModel.userCanAccessViagem(req.user, bloco.viagem_id);
    if (!ok) return res.status(404).json({ message: "Viagem nao encontrada." });

    const anchor = await tripAnchorLatLng(bloco.viagem_id);
    const pr = await db.query(`SELECT * FROM travel_preferences WHERE viagem_id = $1`, [bloco.viagem_id]);
    const prefs = pr.rows[0] || null;

    const memberIdRaw = req.query.member_id;
    const memberId = memberIdRaw != null ? Number(memberIdRaw) : null;
    if (memberIdRaw != null && (!Number.isInteger(memberId) || memberId <= 0)) {
      return res.status(400).json({ message: "member_id invalido." });
    }

    const wrParams = [bloco.viagem_id];
    let wrWhere = "WHERE w.viagem_id = $1 AND w.status IN ('nao_visitado', 'planejado')";
    if (memberIdRaw != null) {
      wrParams.push(memberId);
      wrWhere += ` AND w.user_id = $${wrParams.length}`;
    }

    const wr = await db.query(
      `SELECT
         w.*,
         u.nome AS membro_nome,
         u.email AS membro_email
       FROM wishlist_itens w
       JOIN usuarios u ON u.id = w.user_id
       ${wrWhere}
       ORDER BY w.id DESC`,
      wrParams
    );

    const win = windowMinutesFromRow(bloco);
    const out = [];
    for (const row of wr.rows) {
      const item = serializeWishlist(row);
      const need = estimateDurationMinutes(item.categoria);
      if (win != null && need > win) {
        continue;
      }
      const { score, breakdown } = scoreItem({ item, anchor, prefs });
      out.push({ wishlist_item: item, score, breakdown });
    }
    out.sort((a, b) => b.score - a.score);

    const membersRes = await db.query(
      `SELECT * FROM (
         SELECT
           v.user_id,
           u.nome,
           u.email,
           'owner'::text AS role
         FROM viagens v
         JOIN usuarios u ON u.id = v.user_id
         WHERE v.id = $1
         UNION ALL
         SELECT
           vm.user_id,
           u.nome,
           u.email,
           vm.role
         FROM viagem_membros vm
         JOIN usuarios u ON u.id = vm.user_id
         WHERE vm.viagem_id = $1
           AND vm.status = 'accepted'
           AND vm.user_id <> (SELECT user_id FROM viagens WHERE id = $1)
       ) m
       ORDER BY
         CASE m.role WHEN 'owner' THEN 0 WHEN 'editor' THEN 1 ELSE 2 END,
         m.nome ASC`,
      [bloco.viagem_id]
    );

    return res.json({
      bloco_id: bloco.id,
      viagem_id: bloco.viagem_id,
      janela_minutos: win,
      anchor,
      members: membersRes.rows,
      suggestions: out
    });
  } catch (e) {
    return next(e);
  }
}

async function accept(req, res, next) {
  try {
    const { bloco_id: blocoIdRaw, wishlist_item_id: wishIdRaw } = req.body || {};
    const blocoId = Number(blocoIdRaw);
    const wishId = Number(wishIdRaw);
    if (!Number.isFinite(blocoId) || !Number.isFinite(wishId)) {
      return res.status(400).json({ message: "bloco_id e wishlist_item_id sao obrigatorios." });
    }

    const br = await db.query(`SELECT * FROM roteiro_blocos WHERE id = $1`, [blocoId]);
    if (!br.rows.length) return res.status(404).json({ message: "Bloco nao encontrado." });
    const bloco = br.rows[0];
    if (bloco.tipo !== "Tempo Livre") {
      return res.status(400).json({ message: "Aceitar so em bloco Tempo Livre." });
    }
    const ok = await viagemModel.userCanAccessViagem(req.user, bloco.viagem_id);
    if (!ok) return res.status(404).json({ message: "Viagem nao encontrada." });

    const wr = await db.query(`SELECT * FROM wishlist_itens WHERE id = $1`, [wishId]);
    if (!wr.rows.length) return res.status(404).json({ message: "Item wishlist nao encontrado." });
    const wish = wr.rows[0];
    if (wish.viagem_id !== bloco.viagem_id) {
      return res.status(400).json({ message: "Item nao pertence a esta viagem." });
    }

    const titulo = wish.nome;
    const local = wish.endereco || null;
    const linkUrl = wish.link_url || null;
    const descricao = wish.nota ? String(wish.nota) : null;

    const ins = await db.query(
      `INSERT INTO roteiro_blocos (viagem_id, titulo, tipo, data, hora_inicio, hora_fim, local, link_url, descricao, created_by)
       VALUES ($1, $2, 'Evento Fixo', $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [bloco.viagem_id, titulo, bloco.data, bloco.hora_inicio, bloco.hora_fim, local, linkUrl, descricao, req.user.id]
    );

    await db.query(`UPDATE wishlist_itens SET status = 'planejado' WHERE id = $1`, [wishId]);

    const row = ins.rows[0];
    const payload = serializeBlock(row);
    broadcast("timeline_block_created", payload);
    broadcast("wishlist_updated", { id: wishId, status: "planejado" });

    return res.status(201).json({
      message: "Evento fixo criado a partir da sugestao.",
      evento: payload,
      wishlist_item_id: wishId
    });
  } catch (e) {
    return next(e);
  }
}

async function reject(req, res) {
  return res.status(204).send();
}

async function getPreferences(req, res, next) {
  try {
    const viagemId = Number(req.params.viagemId);
    const ok = await viagemModel.userCanAccessViagem(req.user, viagemId);
    if (!ok) return res.status(404).json({ message: "Viagem nao encontrada." });
    const r = await db.query(`SELECT * FROM travel_preferences WHERE viagem_id = $1`, [viagemId]);
    return res.json(r.rows[0] || null);
  } catch (e) {
    return next(e);
  }
}

async function upsertPreferences(req, res, next) {
  try {
    const viagemId = Number(req.params.viagemId);
    const ok = await viagemModel.userCanAccessViagem(req.user, viagemId);
    if (!ok) return res.status(404).json({ message: "Viagem nao encontrada." });

    const {
      prefer_categorias = null,
      dietary = null,
      budget_level = null,
      pace = null,
      touristic_level = null,
      mobility_pref = null
    } = req.body || {};

    const r = await db.query(
      `INSERT INTO travel_preferences (viagem_id, user_id, prefer_categorias, dietary, budget_level, pace, touristic_level, mobility_pref)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (viagem_id) DO UPDATE SET
         prefer_categorias = EXCLUDED.prefer_categorias,
         dietary = EXCLUDED.dietary,
         budget_level = EXCLUDED.budget_level,
         pace = EXCLUDED.pace,
         touristic_level = EXCLUDED.touristic_level,
         mobility_pref = EXCLUDED.mobility_pref,
         user_id = EXCLUDED.user_id,
         updated_at = NOW()
       RETURNING *`,
      [
        viagemId,
        req.user.id,
        prefer_categorias,
        dietary,
        budget_level,
        pace,
        touristic_level,
        mobility_pref
      ]
    );
    return res.json(r.rows[0]);
  } catch (e) {
    return next(e);
  }
}

module.exports = {
  listForBloco,
  accept,
  reject,
  getPreferences,
  upsertPreferences
};
