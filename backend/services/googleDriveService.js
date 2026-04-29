const fs = require("fs");
const path = require("path");
const { Readable } = require("stream");
const { google } = require("googleapis");

const DRIVE_SCOPE = ["https://www.googleapis.com/auth/drive"];
const FOLDER_MIME_TYPE = "application/vnd.google-apps.folder";
const TOKEN_PATH = process.env.GOOGLE_OAUTH_TOKEN_PATH || path.join(process.cwd(), ".drive-oauth-token.json");

function getDriveParentFolderId() {
  const folderId = (process.env.DRIVE_PARENT_FOLDER_ID || "").trim();
  if (!folderId) {
    throw new Error("DRIVE_PARENT_FOLDER_ID não configurado.");
  }
  return folderId;
}

function getGoogleCredentials() {
  const rawJson = (process.env.GOOGLE_SERVICE_ACCOUNT_JSON || "").trim();
  if (rawJson) {
    return JSON.parse(rawJson);
  }

  const keyPath = (process.env.GOOGLE_SERVICE_ACCOUNT_KEY_PATH || "").trim();
  if (!keyPath) {
    throw new Error("Configure GOOGLE_SERVICE_ACCOUNT_JSON ou GOOGLE_SERVICE_ACCOUNT_KEY_PATH.");
  }
  const fileContent = fs.readFileSync(keyPath, "utf8");
  return JSON.parse(fileContent);
}

function isOAuthConfigured() {
  return Boolean(
    (process.env.GOOGLE_OAUTH_CLIENT_ID || "").trim() &&
      (process.env.GOOGLE_OAUTH_CLIENT_SECRET || "").trim() &&
      (process.env.GOOGLE_OAUTH_REDIRECT_URI || "").trim()
  );
}

function createOAuthClient() {
  return new google.auth.OAuth2(
    (process.env.GOOGLE_OAUTH_CLIENT_ID || "").trim(),
    (process.env.GOOGLE_OAUTH_CLIENT_SECRET || "").trim(),
    (process.env.GOOGLE_OAUTH_REDIRECT_URI || "").trim()
  );
}

function readOAuthToken() {
  if (!fs.existsSync(TOKEN_PATH)) return null;
  const raw = fs.readFileSync(TOKEN_PATH, "utf8");
  return JSON.parse(raw);
}

function writeOAuthToken(token) {
  fs.writeFileSync(TOKEN_PATH, JSON.stringify(token, null, 2), "utf8");
}

function getOAuthStartUrl() {
  if (!isOAuthConfigured()) {
    throw new Error("OAuth do Google Drive não configurado no .env.");
  }
  const oauth2Client = createOAuthClient();
  return oauth2Client.generateAuthUrl({
    access_type: "offline",
    prompt: "consent",
    scope: DRIVE_SCOPE,
  });
}

async function handleOAuthCallback(code) {
  if (!isOAuthConfigured()) {
    throw new Error("OAuth do Google Drive não configurado no .env.");
  }
  const oauth2Client = createOAuthClient();
  const { tokens } = await oauth2Client.getToken(code);
  const existing = readOAuthToken() || {};
  const merged = {
    ...existing,
    ...tokens,
    refresh_token: tokens.refresh_token || existing.refresh_token || null,
  };
  if (!merged.refresh_token) {
    throw new Error("Não foi recebido refresh_token. Refaça consentimento OAuth.");
  }
  writeOAuthToken(merged);
  return merged;
}

async function getDriveClient() {
  if (isOAuthConfigured()) {
    const oauth2Client = createOAuthClient();
    const token = readOAuthToken();
    if (!token) {
      throw new Error("OAuth não autorizado. Acesse /api/drive/oauth/start primeiro.");
    }
    oauth2Client.setCredentials(token);
    return google.drive({ version: "v3", auth: oauth2Client });
  }

  const credentials = getGoogleCredentials();
  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: DRIVE_SCOPE,
  });
  const authClient = await auth.getClient();
  return google.drive({ version: "v3", auth: authClient });
}

async function getOrCreateTripFolder({ drive, viagemId }) {
  const parentFolderId = getDriveParentFolderId();
  const folderName = `viagem_${viagemId}`;
  const escapedName = folderName.replace(/'/g, "\\'");

  const search = await drive.files.list({
    q: `mimeType='${FOLDER_MIME_TYPE}' and name='${escapedName}' and '${parentFolderId}' in parents and trashed=false`,
    fields: "files(id,name)",
    pageSize: 1,
    supportsAllDrives: true,
    includeItemsFromAllDrives: true,
  });

  if (search.data.files?.length) {
    return search.data.files[0].id;
  }

  const created = await drive.files.create({
    requestBody: {
      name: folderName,
      mimeType: FOLDER_MIME_TYPE,
      parents: [parentFolderId],
    },
    fields: "id",
    supportsAllDrives: true,
  });
  return created.data.id;
}

async function uploadPdfToTripFolder({ viagemId, originalName, mimeType, buffer }) {
  const drive = await getDriveClient();
  const folderId = await getOrCreateTripFolder({ drive, viagemId });

  const uploaded = await drive.files.create({
    requestBody: {
      name: originalName,
      parents: [folderId],
    },
    media: {
      mimeType,
      body: Readable.from(buffer),
    },
    fields: "id,name,mimeType,size,webViewLink,webContentLink",
    supportsAllDrives: true,
  });

  // Torna o arquivo público por link (sem descoberta em buscas).
  await drive.permissions.create({
    fileId: uploaded.data.id,
    requestBody: {
      role: "reader",
      type: "anyone",
      allowFileDiscovery: false,
    },
    supportsAllDrives: true,
  });

  const publicFile = await drive.files.get({
    fileId: uploaded.data.id,
    fields: "id,name,mimeType,size,webViewLink,webContentLink",
    supportsAllDrives: true,
  });

  return {
    driveFileId: publicFile.data.id,
    driveFolderId: folderId,
    mimeType: publicFile.data.mimeType || mimeType,
    sizeBytes: Number(publicFile.data.size || buffer.length),
    originalFileName: publicFile.data.name || originalName,
    webViewLink: publicFile.data.webViewLink || null,
    webContentLink: publicFile.data.webContentLink || null,
  };
}

async function deleteDriveFile(driveFileId) {
  if (!driveFileId) return;
  const drive = await getDriveClient();
  await drive.files.delete({
    fileId: driveFileId,
    supportsAllDrives: true,
  });
}

module.exports = {
  getOAuthStartUrl,
  handleOAuthCallback,
  uploadPdfToTripFolder,
  deleteDriveFile,
};

