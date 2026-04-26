const nodemailer = require("nodemailer");

function buildTransporter() {
  const host = process.env.SMTP_HOST;
  const port = Number(process.env.SMTP_PORT || 587);
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  if (!host || !user || !pass) {
    return nodemailer.createTransport({ jsonTransport: true });
  }

  return nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
  });
}

function senderAddress() {
  return process.env.MAIL_FROM || process.env.SMTP_USER || "no-reply@app-viagens.local";
}

async function sendMail({ to, subject, text, html }) {
  const transporter = buildTransporter();
  const info = await transporter.sendMail({
    from: senderAddress(),
    to,
    subject,
    text,
    html,
  });

  if (info.message) {
    console.log("[emailService] E-mail gerado (jsonTransport):", info.message.toString());
  }
}

module.exports = { sendMail };
