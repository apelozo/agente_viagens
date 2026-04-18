const db = require("../services/databaseService");
const viagemModel = require("../models/viagemModel");
const { broadcast } = require("../services/websocketService");
const { sendMail } = require("../services/emailService");
const crypto = require("crypto");

const TABLES = {
  cidades: { table: "cidades", parent: "viagem_id" },
  hoteis: { table: "hoteis", parent: "cidade_id" },
  restaurantes: { table: "restaurantes", parent: "cidade_id" },
  passeios: { table: "passeios", parent: "cidade_id" }
};

function normalizeDateForDb(value) {
  if (!value || typeof value !== "string") return value;
  const br = /^(\d{2})\/(\d{2})\/(\d{4})$/;
  const iso = /^(\d{4})-(\d{2})-(\d{2})$/;
  if (br.test(value)) {
    const [, dd, mm, yyyy] = value.match(br);
    return `${yyyy}-${mm}-${dd}`;
  }
  if (iso.test(value)) return value;
  return value;
}

function formatDateToBr(value) {
  if (!value) return value;
  const raw = String(value).slice(0, 10);
  const iso = /^(\d{4})-(\d{2})-(\d{2})$/;
  if (!iso.test(raw)) return value;
  const [, yyyy, mm, dd] = raw.match(iso);
  return `${dd}/${mm}/${yyyy}`;
}

function normalizeDateFields(payload) {
  const data = { ...payload };
  Object.keys(data).forEach((key) => {
    if (key.startsWith("data_")) {
      data[key] = normalizeDateForDb(data[key]);
    }
  });
  return data;
}

function serializeDates(row) {
  if (!row || typeof row !== "object") return row;
  const data = { ...row };
  Object.keys(data).forEach((key) => {
    if (key.startsWith("data_")) {
      data[key] = formatDateToBr(data[key]);
    }
  });
  return data;
}

async function listViagens(req, res, next) {
  try {
    const page = Number(req.query.page || 1);
    const pageSize = Number(req.query.pageSize || 20);
    const viagens = await viagemModel.listViagens(req.user, page, pageSize);
    return res.json(viagens.map(serializeDates));
  } catch (error) {
    return next(error);
  }
}

async function createViagem(req, res, next) {
  try {
    const payload = normalizeDateFields({ ...req.body });
    payload.user_id = payload.user_id || req.user.id;
    const viagem = await viagemModel.createViagem(payload);
    const serialized = serializeDates(viagem);
    broadcast("viagem_created", serialized);
    return res.status(201).json(serialized);
  } catch (error) {
    return next(error);
  }
}

async function updateViagem(req, res, next) {
  try {
    const { id } = req.params;
    const canAccess = await viagemModel.userCanAccessViagem(req.user, Number(id));
    if (!canAccess) return res.status(404).json({ message: "Viagem não encontrada." });
    const role = await viagemModel.userRoleInViagem(req.user.id, Number(id));
    if (!role || role === "viewer") return res.status(403).json({ message: "Sem permissão para editar esta viagem." });
    const { descricao, data_inicial, data_final, situacao } = normalizeDateFields(req.body);
    const result = await db.query(
      "UPDATE viagens SET descricao=$1,data_inicial=$2,data_final=$3,situacao=$4 WHERE id=$5 RETURNING *",
      [descricao, data_inicial, data_final, situacao, id]
    );
    const serialized = serializeDates(result.rows[0]);
    broadcast("viagem_updated", serialized);
    return res.json(serialized);
  } catch (error) {
    return next(error);
  }
}

async function deleteViagem(req, res, next) {
  try {
    const id = Number(req.params.id);
    const role = await viagemModel.userRoleInViagem(req.user.id, id);
    if (role !== "owner") return res.status(403).json({ message: "Apenas o dono pode excluir a viagem." });
    await db.query("DELETE FROM viagens WHERE id = $1", [req.params.id]);
    broadcast("viagem_deleted", { id: req.params.id });
    return res.status(204).send();
  } catch (error) {
    return next(error);
  }
}

async function listMembers(req, res, next) {
  try {
    const viagemId = Number(req.params.id);
    const ok = await viagemModel.userCanAccessViagem(req.user, viagemId);
    if (!ok) return res.status(404).json({ message: "Viagem não encontrada." });

    const result = await db.query(
      `SELECT * FROM (
         SELECT
           0 AS id,
           v.user_id,
           'owner'::text AS role,
           'accepted'::text AS status,
           v.data_inicial::timestamp AS created_at,
           u.nome,
           u.email
         FROM viagens v
         JOIN usuarios u ON u.id = v.user_id
         WHERE v.id = $1

         UNION ALL

         SELECT
           vm.id,
           vm.user_id,
           vm.role,
           vm.status,
           vm.created_at,
           u.nome,
           u.email
         FROM viagem_membros vm
         JOIN usuarios u ON u.id = vm.user_id
         WHERE vm.viagem_id = $1
           AND vm.status = 'accepted'
           AND vm.user_id <> (SELECT user_id FROM viagens WHERE id = $1)
       ) members
       ORDER BY
         CASE members.role WHEN 'owner' THEN 0 WHEN 'editor' THEN 1 ELSE 2 END,
         members.nome ASC`,
      [viagemId]
    );
    return res.json(result.rows);
  } catch (error) {
    return next(error);
  }
}

async function inviteMember(req, res, next) {
  try {
    const viagemId = Number(req.params.id);
    const role = (req.body?.role || "").toString().trim();
    const invitedEmail = (req.body?.email || "").toString().trim().toLowerCase();
    if (!invitedEmail) return res.status(400).json({ message: "E-mail é obrigatório." });
    if (role !== "editor" && role !== "viewer") {
      return res.status(400).json({ message: "Papel inválido. Use editor ou viewer." });
    }

    const userRole = await viagemModel.userRoleInViagem(req.user.id, viagemId);
    if (userRole !== "owner" && userRole !== "editor") {
      return res.status(403).json({ message: "Sem permissão para convidar membros." });
    }

    const viagemRes = await db.query("SELECT id, descricao FROM viagens WHERE id = $1", [viagemId]);
    if (viagemRes.rows.length === 0) return res.status(404).json({ message: "Viagem não encontrada." });
    const viagem = viagemRes.rows[0];

    const token = crypto.randomBytes(24).toString("hex");
    const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 7); // 7 dias

    await db.query(
      `INSERT INTO convites_viagem (viagem_id, invited_email, role, token, status, invited_by, expires_at)
       VALUES ($1,$2,$3,$4,'pending',$5,$6)`,
      [viagemId, invitedEmail, role, token, req.user.id, expiresAt]
    );

    const acceptUrl = `${process.env.APP_BASE_URL || "http://localhost:5000"}/invite/${token}`;
    await sendMail({
      to: invitedEmail,
      subject: `Convite para viagem: ${viagem.descricao}`,
      text: `Você recebeu um convite para participar da viagem "${viagem.descricao}" no Agente Pessoal da Viagem.\n\nPapel: ${role}\nToken: ${token}\nLink de aceite: ${acceptUrl}\n\nO convite expira em 7 dias.`,
      html: `<p>Você recebeu um convite para participar da viagem <strong>${viagem.descricao}</strong> no <strong>Agente Pessoal da Viagem</strong>.</p><p><strong>Papel:</strong> ${role}</p><p><strong>Token:</strong> ${token}</p><p><a href="${acceptUrl}">Aceitar convite</a></p><p>O convite expira em 7 dias.</p>`,
    });

    broadcast("viagem_member_invited", { viagem_id: viagemId, invited_email: invitedEmail, role });
    return res.status(201).json({ ok: true, token, expires_at: expiresAt.toISOString() });
  } catch (error) {
    return next(error);
  }
}

async function acceptInvite(req, res, next) {
  try {
    const token = (req.body?.token || "").toString().trim();
    if (!token) return res.status(400).json({ message: "Token é obrigatório." });

    const inviteRes = await db.query(
      `SELECT * FROM convites_viagem WHERE token = $1 AND status = 'pending' LIMIT 1`,
      [token]
    );
    if (inviteRes.rows.length === 0) return res.status(404).json({ message: "Convite inválido ou já utilizado." });
    const invite = inviteRes.rows[0];

    if (new Date(invite.expires_at).getTime() < Date.now()) {
      await db.query("UPDATE convites_viagem SET status = 'expired' WHERE id = $1", [invite.id]);
      return res.status(410).json({ message: "Convite expirado." });
    }

    if ((req.user.email || "").toLowerCase() !== (invite.invited_email || "").toLowerCase()) {
      return res.status(403).json({ message: "Este convite pertence a outro e-mail." });
    }

    await db.query(
      `INSERT INTO viagem_membros (viagem_id, user_id, role, status, invited_by)
       VALUES ($1,$2,$3,'accepted',$4)
       ON CONFLICT (viagem_id, user_id)
       DO UPDATE SET role = EXCLUDED.role, status = 'accepted'`,
      [invite.viagem_id, req.user.id, invite.role, invite.invited_by]
    );
    await db.query("UPDATE convites_viagem SET status = 'accepted' WHERE id = $1", [invite.id]);

    broadcast("viagem_member_joined", { viagem_id: invite.viagem_id, user_id: req.user.id, role: invite.role });
    return res.json({ ok: true, viagem_id: invite.viagem_id, role: invite.role });
  } catch (error) {
    return next(error);
  }
}

async function listMyPendingInvites(req, res, next) {
  try {
    const email = (req.user?.email || "").toString().trim().toLowerCase();
    if (!email) return res.json([]);

    const result = await db.query(
      `SELECT
         cv.id,
         cv.viagem_id,
         cv.invited_email,
         cv.role,
         cv.token,
         cv.status,
         cv.expires_at,
         cv.created_at,
         v.descricao AS viagem_descricao,
         u.nome AS invited_by_nome,
         u.email AS invited_by_email
       FROM convites_viagem cv
       JOIN viagens v ON v.id = cv.viagem_id
       JOIN usuarios u ON u.id = cv.invited_by
       WHERE LOWER(cv.invited_email) = $1
         AND cv.status = 'pending'
         AND cv.expires_at > NOW()
       ORDER BY cv.created_at DESC`,
      [email]
    );
    return res.json(result.rows);
  } catch (error) {
    return next(error);
  }
}

async function declineInvite(req, res, next) {
  try {
    const inviteId = Number(req.body?.invite_id);
    if (!inviteId) return res.status(400).json({ message: "invite_id é obrigatório." });

    const email = (req.user?.email || "").toString().trim().toLowerCase();
    const inviteRes = await db.query(
      `SELECT * FROM convites_viagem
       WHERE id = $1
         AND status = 'pending'
       LIMIT 1`,
      [inviteId]
    );
    if (inviteRes.rows.length === 0) {
      return res.status(404).json({ message: "Convite não encontrado ou já processado." });
    }
    const invite = inviteRes.rows[0];
    if ((invite.invited_email || "").toLowerCase() !== email) {
      return res.status(403).json({ message: "Este convite pertence a outro e-mail." });
    }

    await db.query("UPDATE convites_viagem SET status = 'cancelled' WHERE id = $1", [inviteId]);
    return res.json({ ok: true });
  } catch (error) {
    return next(error);
  }
}

async function updateMember(req, res, next) {
  try {
    const viagemId = Number(req.params.id);
    const memberId = Number(req.params.memberId);
    const nextRole = (req.body?.role || "").toString().trim();
    if (!["editor", "viewer"].includes(nextRole)) {
      return res.status(400).json({ message: "Papel inválido. Use editor ou viewer." });
    }

    const currentUserRole = await viagemModel.userRoleInViagem(req.user.id, viagemId);
    if (currentUserRole !== "owner") {
      return res.status(403).json({ message: "Somente o dono pode alterar papel de membros." });
    }

    const result = await db.query(
      `UPDATE viagem_membros
       SET role = $1
       WHERE viagem_id = $2 AND id = $3 AND role <> 'owner'
       RETURNING *`,
      [nextRole, viagemId, memberId]
    );
    if (result.rows.length === 0) return res.status(404).json({ message: "Membro não encontrado." });

    broadcast("viagem_member_updated", { viagem_id: viagemId, member_id: memberId, role: nextRole });
    return res.json(result.rows[0]);
  } catch (error) {
    return next(error);
  }
}

async function listByParent(req, res, next) {
  try {
    const entity = TABLES[req.params.entity];
    const result = await db.query(`SELECT * FROM ${entity.table} WHERE ${entity.parent} = $1 ORDER BY id DESC`, [
      req.params.parentId
    ]);
    return res.json(result.rows.map(serializeDates));
  } catch (error) {
    return next(error);
  }
}

async function createByEntity(req, res, next) {
  try {
    const entity = TABLES[req.params.entity];
    const data = normalizeDateFields({ ...req.body, [entity.parent]: req.params.parentId });
    const fields = Object.keys(data);
    const values = Object.values(data);
    const params = fields.map((_, i) => `$${i + 1}`);
    const result = await db.query(
      `INSERT INTO ${entity.table} (${fields.join(",")}) VALUES (${params.join(",")}) RETURNING *`,
      values
    );
    const serialized = serializeDates(result.rows[0]);
    broadcast(`${entity.table}_created`, serialized);
    return res.status(201).json(serialized);
  } catch (error) {
    return next(error);
  }
}

async function updateEntity(req, res, next) {
  try {
    const entity = TABLES[req.params.entity];
    const normalizedBody = normalizeDateFields(req.body);
    const fields = Object.keys(normalizedBody);
    const values = Object.values(normalizedBody);
    const sets = fields.map((f, i) => `${f}=$${i + 1}`);
    const result = await db.query(
      `UPDATE ${entity.table} SET ${sets.join(",")} WHERE id=$${fields.length + 1} RETURNING *`,
      [...values, req.params.id]
    );
    const serialized = serializeDates(result.rows[0]);
    broadcast(`${entity.table}_updated`, serialized);
    return res.json(serialized);
  } catch (error) {
    return next(error);
  }
}

async function deleteEntity(req, res, next) {
  try {
    const entity = TABLES[req.params.entity];
    await db.query(`DELETE FROM ${entity.table} WHERE id = $1`, [req.params.id]);
    broadcast(`${entity.table}_deleted`, { id: req.params.id });
    return res.status(204).send();
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  listViagens,
  createViagem,
  updateViagem,
  deleteViagem,
  listMembers,
  inviteMember,
  listMyPendingInvites,
  acceptInvite,
  declineInvite,
  updateMember,
  listByParent,
  createByEntity,
  updateEntity,
  deleteEntity
};
