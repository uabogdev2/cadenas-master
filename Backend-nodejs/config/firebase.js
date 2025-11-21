const admin = require('firebase-admin');
require('dotenv').config();

// Initialiser Firebase Admin SDK
// Option 1: Utiliser les variables d'environnement (recommandé)
if (process.env.FIREBASE_PRIVATE_KEY) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
      }),
    });
    console.log('Firebase Admin SDK initialisé avec les variables d\'environnement');
  } catch (error) {
    console.error('Erreur lors de l\'initialisation de Firebase Admin SDK:', error);
    process.exit(1);
  }
} else {
  // Option 2: Utiliser un fichier de clé de service (pour le développement local)
  try {
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log('Firebase Admin SDK initialisé avec le fichier serviceAccountKey.json');
  } catch (error) {
    console.error('Erreur: Impossible de charger le fichier serviceAccountKey.json');
    console.error('Veuillez configurer les variables d\'environnement FIREBASE_* dans le fichier .env');
    process.exit(1);
  }
}

// Fonction pour vérifier et décoder un token Firebase
async function verifyToken(token) {
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    return decodedToken;
  } catch (error) {
    console.error('Erreur lors de la vérification du token:', error);
    throw error;
  }
}

// Fonction pour obtenir les informations d'un utilisateur
async function getUserInfo(uid) {
  try {
    const user = await admin.auth().getUser(uid);
    return user;
  } catch (error) {
    console.error('Erreur lors de la récupération des informations utilisateur:', error);
    throw error;
  }
}

module.exports = {
  admin,
  verifyToken,
  getUserInfo,
};

