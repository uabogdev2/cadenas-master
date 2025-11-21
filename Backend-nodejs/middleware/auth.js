const { verifyToken } = require('../config/firebase');

// Middleware pour vérifier l'authentification Firebase
async function authenticateFirebase(req, res, next) {
  try {
    // Récupérer le token depuis le header Authorization
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Non autorisé',
        message: 'Token d\'authentification manquant',
      });
    }

    // Extraire le token
    const token = authHeader.substring(7); // Retirer "Bearer "

    // Vérifier le token avec Firebase Admin SDK
    const decodedToken = await verifyToken(token);
    
    // Ajouter les informations de l'utilisateur à la requête
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      name: decodedToken.name,
      picture: decodedToken.picture,
    };

    next();
  } catch (error) {
    console.error('Erreur d\'authentification:', error);
    return res.status(401).json({
      error: 'Non autorisé',
      message: 'Token invalide ou expiré',
    });
  }
}

// Middleware optionnel pour les routes qui peuvent fonctionner avec ou sans authentification
async function optionalAuthenticate(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      const decodedToken = await verifyToken(token);
      req.user = {
        uid: decodedToken.uid,
        email: decodedToken.email,
        name: decodedToken.name,
        picture: decodedToken.picture,
      };
    }
    
    next();
  } catch (error) {
    // En cas d'erreur, continuer sans authentification
    next();
  }
}

module.exports = {
  authenticateFirebase,
  optionalAuthenticate,
};

