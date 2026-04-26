const db = require("../services/databaseService");
const viagemModel = require("../models/viagemModel");
const { broadcast } = require("../services/websocketService");

const CATEGORIAS = ["Comer", "Visitar", "Comprar", "Outras"];
const STATUS = ["nao_visitado", "planejado", "concluido", "descartado"];

function serialize(row) {
  return {
    ...row,
    latitude: row.latitude != null ? Number(row.latitude) : null,
    longitude: row.longitude != null ? Number(row.longitude) : null,
    rating: row.rating != null ? Number(row.rating) : null
  };
}

async function assertViagem(req, viagemId) {
  const ok = await viagemModel.userCanAccessViagem(req.user, Number(viagemId));
  if (!ok) {
    const err = new Error("Viagem nao encontrada.");
    err.status = 404;
    throw err;
  }
}

async function listByViagem(req, res, next) {
  try {
    const { viagemId } = req.params;
    await assertViagem(req, viagemId);
    const categoria = req.query.categoria;
    const status = req.query.status;
    const memberIdRaw = req.query.member_id;
    const memberId = memberIdRaw != null ? Number(memberIdRaw) : null;
    const params = [viagemId];
    let where = "WHERE w.viagem_id = $1";
    if (categoria && CATEGORIAS.includes(categoria)) {
      params.push(categoria);
      where += ` AND w.categoria = $${params.length}`;
    }
    if (status && STATUS.includes(status)) {
      params.push(status);
      where += ` AND w.status = $${params.length}`;
    }
    if (memberIdRaw != null) {
      if (!Number.isInteger(memberId) || memberId <= 0) {
        return res.status(400).json({ message: "member_id inválido." });
      }
      params.push(memberId);
      where += ` AND w.user_id = $${params.length}`;
    }
    const result = await db.query(
      `SELECT
         w.*,
         u.nome AS membro_nome,
         u.email AS membro_email
       FROM wishlist_itens w
       JOIN usuarios u ON u.id = w.user_id
       ${where}
       ORDER BY w.created_at DESC`,
      params
    );
    return res.json(result.rows.map(serialize));
  } catch (error) {
    if (error.status === 404) return res.status(404).json({ message: error.message });
    return next(error);
  }
}

function validateBody(body, partial) {
  const {
    categoria,
    nome,
    endereco = null,
    latitude = null,
    longitude = null,
    fonte = null,
    nota = null,
    link_url = null,
    rating = null,
    foto_url = null,
    status = "nao_visitado"
  } = body;
  if (!partial && (!nome || typeof nome !== "string" || !nome.trim())) return "Nome e obrigatorio.";
  if (!partial && (!categoria || !CATEGORIAS.includes(categoria))) return "Categoria invalida.";
  if (body.status != null && !STATUS.includes(body.status)) return "Status invalido.";
  if (latitude != null && longitude != null && (Number.isNaN(Number(latitude)) || Number.isNaN(Number(longitude)))) {
    return "Coordenadas invalidas.";
  }
  if (link_url != null && typeof link_url !== "string") return "Link invalido.";
  return null;
}

async function create(req, res, next) {
  try {
    const { viagemId } = req.params;
    await assertViagem(req, viagemId);
    const err = validateBody(req.body, false);
    if (err) return res.status(400).json({ message: err });
    const {
      categoria,
      nome,
      endereco = null,
      latitude = null,
      longitude = null,
      fonte = null,
      nota = null,
      link_url = null,
      rating = null,
      foto_url = null,
      status = "nao_visitado"
    } = req.body;
    const result = await db.query(
      `INSERT INTO wishlist_itens (
        viagem_id, user_id, categoria, nome, endereco, latitude, longitude, fonte, nota, link_url, rating, foto_url, status
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING *`,
      [
        viagemId,
        req.user.id,
        categoria,
        nome.trim(),
        endereco,
        latitude,
        longitude,
        fonte,
        nota,
        link_url,
        rating,
        foto_url,
        status
      ]
    );
    const payload = serialize(result.rows[0]);
    broadcast("wishlist_created", payload);
    return res.status(201).json(payload);
  } catch (error) {
    if (error.status === 404) return res.status(404).json({ message: error.message });
    return next(error);
  }
}

/** Importa item a partir de resultado Google Places (ou payload equivalente). */
async function importPlace(req, res, next) {
  try {
    const { viagemId } = req.params;
    await assertViagem(req, viagemId);
    const {
      categoria = "Visitar",
      nome,
      endereco = null,
      latitude = null,
      longitude = null,
      rating = null,
      foto_url = null
    } = req.body;
    if (!nome || typeof nome !== "string" || !nome.trim()) return res.status(400).json({ message: "Nome e obrigatorio." });
    if (!CATEGORIAS.includes(categoria)) return res.status(400).json({ message: "Categoria invalida." });
    const result = await db.query(
      `INSERT INTO wishlist_itens (
        viagem_id, user_id, categoria, nome, endereco, latitude, longitude, fonte, nota, rating, foto_url, status
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
      [
        viagemId,
        req.user.id,
        categoria,
        nome.trim(),
        endereco,
        latitude,
        longitude,
        "Google Places",
        null,
        rating,
        foto_url,
        "nao_visitado"
      ]
    );
    const payload = serialize(result.rows[0]);
    broadcast("wishlist_created", payload);
    return res.status(201).json(payload);
  } catch (error) {
    if (error.status === 404) return res.status(404).json({ message: error.message });
    return next(error);
  }
}

async function update(req, res, next) {
  try {
    const { id } = req.params;
    const row = await db.query("SELECT viagem_id FROM wishlist_itens WHERE id = $1", [id]);
    if (!row.rows.length) return res.status(404).json({ message: "Item nao encontrado." });
    await assertViagem(req, row.rows[0].viagem_id);

    const err = validateBody(req.body, true);
    if (err) return res.status(400).json({ message: err });

    const prev = await db.query("SELECT * FROM wishlist_itens WHERE id = $1", [id]);
    const cur = prev.rows[0];
    const merged = {
      nome: req.body.nome != null ? req.body.nome : cur.nome,
      categoria: req.body.categoria != null ? req.body.categoria : cur.categoria,
      endereco: req.body.endereco !== undefined ? req.body.endereco : cur.endereco,
      latitude: req.body.latitude !== undefined ? req.body.latitude : cur.latitude,
      longitude: req.body.longitude !== undefined ? req.body.longitude : cur.longitude,
      fonte: req.body.fonte !== undefined ? req.body.fonte : cur.fonte,
      nota: req.body.nota !== undefined ? req.body.nota : cur.nota,
      link_url: req.body.link_url !== undefined ? req.body.link_url : cur.link_url,
      rating: req.body.rating !== undefined ? req.body.rating : cur.rating,
      foto_url: req.body.foto_url !== undefined ? req.body.foto_url : cur.foto_url,
      status: req.body.status != null ? req.body.status : cur.status
    };
    if (!CATEGORIAS.includes(merged.categoria)) return res.status(400).json({ message: "Categoria invalida." });
    if (!STATUS.includes(merged.status)) return res.status(400).json({ message: "Status invalido." });

    const result = await db.query(
      `UPDATE wishlist_itens SET
        nome = $1, categoria = $2, endereco = $3, latitude = $4, longitude = $5,
        fonte = $6, nota = $7, link_url = $8, rating = $9, foto_url = $10, status = $11
       WHERE id = $12 RETURNING *`,
      [
        String(merged.nome).trim(),
        merged.categoria,
        merged.endereco,
        merged.latitude,
        merged.longitude,
        merged.fonte,
        merged.nota,
        merged.link_url,
        merged.rating,
        merged.foto_url,
        merged.status,
        id
      ]
    );
    const payload = serialize(result.rows[0]);
    broadcast("wishlist_updated", payload);
    return res.json(payload);
  } catch (error) {
    if (error.status === 404) return res.status(404).json({ message: error.message });
    return next(error);
  }
}

async function remove(req, res, next) {
  try {
    const { id } = req.params;
    const row = await db.query("SELECT viagem_id FROM wishlist_itens WHERE id = $1", [id]);
    if (!row.rows.length) return res.status(404).json({ message: "Item nao encontrado." });
    const viagemId = row.rows[0].viagem_id;
    await assertViagem(req, viagemId);
    await db.query("DELETE FROM wishlist_itens WHERE id = $1", [id]);
    broadcast("wishlist_deleted", { id: Number(id), viagem_id: viagemId });
    return res.status(204).send();
  } catch (error) {
    if (error.status === 404) return res.status(404).json({ message: error.message });
    return next(error);
  }
}

module.exports = {
  listByViagem,
  create,
  importPlace,
  update,
  remove
};
