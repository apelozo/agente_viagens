const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const userModel = require("../models/userModel");
const { sendMail } = require("../services/emailService");

function generateTemporaryPassword(length = 10) {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#$%";
  let value = "";
  for (let i = 0; i < length; i += 1) {
    value += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return value;
}

async function register(req, res, next) {
  try {
    const { nome, tipo, email, senha, status = "Ativa" } = req.body;
    if (!nome || !tipo || !email || !senha) {
      return res.status(400).json({ message: "Nome, tipo, e-mail e senha são obrigatórios." });
    }
    const existing = await userModel.findByEmail(email);
    if (existing) return res.status(409).json({ message: "E-mail já cadastrado." });

    const hash = await bcrypt.hash(senha, 10);
    const user = await userModel.createUser({ nome, tipo, email, senha: hash, status });

    await sendMail({
      to: email,
      subject: "Bem-vindo ao Agente Pessoal da Viagem",
      text: `Olá ${nome},\n\nSeu perfil foi criado com sucesso no Agente Pessoal da Viagem.\n\nSe não reconhece este cadastro, entre em contato com o suporte.`,
      html: `<p>Olá <strong>${nome}</strong>,</p><p>Seu perfil foi criado com sucesso no <strong>Agente Pessoal da Viagem</strong>.</p><p>Se não reconhece este cadastro, entre em contato com o suporte.</p>`,
    });

    return res.status(201).json(user);
  } catch (error) {
    return next(error);
  }
}

async function login(req, res, next) {
  try {
    const { email, senha } = req.body;
    const user = await userModel.findByEmail(email);
    if (!user) return res.status(401).json({ message: "Credenciais inválidas." });

    const valid = await bcrypt.compare(senha, user.senha);
    if (!valid) return res.status(401).json({ message: "Credenciais inválidas." });

    const token = jwt.sign(
      { id: user.id, nome: user.nome, tipo: user.tipo, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: "12h" }
    );
    return res.json({ token, user: { id: user.id, nome: user.nome, tipo: user.tipo, email: user.email } });
  } catch (error) {
    return next(error);
  }
}

async function forgotPassword(req, res, next) {
  try {
    const email = (req.body?.email || "").toString().trim().toLowerCase();
    if (!email) return res.status(400).json({ message: "Informe um e-mail válido." });

    const user = await userModel.findByEmail(email);
    // Resposta genérica para não revelar se o e-mail existe.
    if (!user) return res.json({ ok: true, message: "Se o e-mail existir, enviaremos instruções." });

    const temporaryPassword = generateTemporaryPassword();
    const hash = await bcrypt.hash(temporaryPassword, 10);
    await userModel.updatePasswordById(user.id, hash);

    await sendMail({
      to: email,
      subject: "Recuperação de senha - Agente Pessoal da Viagem",
      text: `Olá ${user.nome},\n\nRecebemos seu pedido de recuperação de senha.\nSua senha temporária é: ${temporaryPassword}\n\nEntre no app e altere sua senha assim que possível.`,
      html: `<p>Olá <strong>${user.nome}</strong>,</p><p>Recebemos seu pedido de recuperação de senha.</p><p>Sua senha temporária é: <strong>${temporaryPassword}</strong></p><p>Entre no app e altere sua senha assim que possível.</p>`,
    });

    return res.json({ ok: true, message: "Se o e-mail existir, enviaremos instruções." });
  } catch (error) {
    return next(error);
  }
}

async function changePassword(req, res, next) {
  try {
    const email = (req.body?.email || "").toString().trim().toLowerCase();
    const senhaAtual = (req.body?.senhaAtual || "").toString();
    const novaSenha = (req.body?.novaSenha || "").toString();

    if (!email || !senhaAtual || !novaSenha) {
      return res.status(400).json({ message: "E-mail, senha atual e nova senha são obrigatórios." });
    }
    if (novaSenha.length < 6) {
      return res.status(400).json({ message: "A nova senha deve ter pelo menos 6 caracteres." });
    }

    const user = await userModel.findByEmail(email);
    if (!user) return res.status(401).json({ message: "Credenciais inválidas." });

    const valid = await bcrypt.compare(senhaAtual, user.senha);
    if (!valid) return res.status(401).json({ message: "Credenciais inválidas." });

    const newHash = await bcrypt.hash(novaSenha, 10);
    await userModel.updatePasswordById(user.id, newHash);

    await sendMail({
      to: email,
      subject: "Senha alterada - Agente Pessoal da Viagem",
      text: `Olá ${user.nome},\n\nSua senha foi alterada com sucesso no Agente Pessoal da Viagem.`,
      html: `<p>Olá <strong>${user.nome}</strong>,</p><p>Sua senha foi alterada com sucesso no <strong>Agente Pessoal da Viagem</strong>.</p>`,
    });

    return res.json({ ok: true, message: "Senha alterada com sucesso." });
  } catch (error) {
    return next(error);
  }
}

module.exports = { register, login, forgotPassword, changePassword };
