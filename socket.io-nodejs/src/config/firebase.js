const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

let isInitialized = false;

function sanitizeSingleLine(value) {
  return value ? value.replace(/\\n/g, '\n') : value;
}

function sanitizeServiceAccount(account) {
  if (!account) return account;
  const sanitized = { ...account };

  if (sanitized.privateKey) {
    sanitized.privateKey = sanitizeSingleLine(sanitized.privateKey);
  }
  if (sanitized.private_key) {
    sanitized.private_key = sanitizeSingleLine(sanitized.private_key);
  }

  return sanitized;
}

function loadServiceAccountFromEnv() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    try {
      const parsed = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
      return sanitizeServiceAccount(parsed);
    } catch (error) {
      throw new Error(`[firebase] FIREBASE_SERVICE_ACCOUNT_JSON invalide: ${error.message}`);
    }
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
    try {
      const decoded = Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, 'base64').toString(
        'utf8'
      );
      const parsed = JSON.parse(decoded);
      return sanitizeServiceAccount(parsed);
    } catch (error) {
      throw new Error(`[firebase] FIREBASE_SERVICE_ACCOUNT_BASE64 invalide: ${error.message}`);
    }
  }

  if (
    process.env.FIREBASE_PROJECT_ID &&
    process.env.FIREBASE_CLIENT_EMAIL &&
    process.env.FIREBASE_PRIVATE_KEY
  ) {
    return sanitizeServiceAccount({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY,
    });
  }

  return null;
}

function loadServiceAccountFromFile() {
  const explicitPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  const fallbackPath = path.join(__dirname, '../../config/serviceAccountKey.json');
  const keyPath = explicitPath || fallbackPath;

  if (!fs.existsSync(keyPath)) {
    return null;
  }

  const raw = fs.readFileSync(keyPath, 'utf8');
  return sanitizeServiceAccount(JSON.parse(raw));
}

function initFirebase() {
  if (isInitialized) return;

  try {
    const serviceAccount =
      loadServiceAccountFromEnv() ||
      loadServiceAccountFromFile();

    if (!serviceAccount) {
      throw new Error(
        'Aucun identifiant Firebase trouvé. Fournissez FIREBASE_* ou config/serviceAccountKey.json.'
      );
    }

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    const source = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
      ? 'FIREBASE_SERVICE_ACCOUNT_JSON'
      : process.env.FIREBASE_SERVICE_ACCOUNT_BASE64
      ? 'FIREBASE_SERVICE_ACCOUNT_BASE64'
      : process.env.FIREBASE_PRIVATE_KEY
      ? 'variables FIREBASE_PROJECT_ID/FIREBASE_CLIENT_EMAIL/FIREBASE_PRIVATE_KEY'
      : 'config/serviceAccountKey.json';

    console.log(`[firebase] Initialisé via ${source}`);
  } catch (error) {
    console.error('[firebase] Impossible d’initialiser Firebase Admin.', error.message);
    throw error;
  }

  isInitialized = true;
}

async function verifyToken(token) {
  initFirebase();
  return admin.auth().verifyIdToken(token);
}

function getFirebaseProjectInfo() {
  const app = admin.apps.length ? admin.app() : null;
  return {
    projectId: app?.options?.projectId,
    clientEmail: app?.options?.credential?.clientEmail,
    envProject: process.env.FIREBASE_PROJECT_ID,
  };
}

module.exports = {
  verifyToken,
  getFirebaseProjectInfo,
};

