const express = require('express');
const router = express.Router();
const { authenticateFirebase } = require('../../middleware/auth');
const { Admin, User } = require('../../models');
const { getUserInfo } = require('../../config/firebase');

// Route pour créer automatiquement le premier admin (pas de vérification admin requise)
// Cette route vérifie d'abord si un admin existe, sinon elle crée le premier admin avec l'utilisateur authentifié
router.post('/create-first-admin', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;

    // Vérifier si un admin existe déjà
    const existingAdminCount = await Admin.count();

    if (existingAdminCount > 0) {
      return res.status(400).json({
        success: false,
        error: 'Un administrateur existe déjà. Utilisez un compte admin existant pour créer de nouveaux admins.',
      });
    }

    // Récupérer les infos de l'utilisateur depuis Firebase Auth
    const firebaseUser = await getUserInfo(userId);
    console.log(`Création du premier admin avec l'utilisateur Firebase: ${firebaseUser.email}`);

    // Créer ou trouver l'utilisateur dans notre DB
    const [user, createdUser] = await User.findOrCreate({
      where: { id: userId },
      defaults: {
        id: userId,
        displayName: firebaseUser.displayName || 'Admin User',
        email: firebaseUser.email,
        photoURL: firebaseUser.photoURL,
        points: 0,
        completedLevels: 0,
        trophies: 0,
        isAnonymous: false,
      },
    });

    if (createdUser) {
      console.log(`Utilisateur DB créé pour l'admin: ${user.displayName}`);
    } else {
      console.log(`Utilisateur DB existant pour l'admin: ${user.displayName}`);
    }

    // Créer l'entrée Admin avec toutes les permissions
    const adminEntry = await Admin.create({
      userId: userId,
      isAdmin: true,
      permissions: {
        manageUsers: true,
        manageLevels: true,
        viewStats: true,
        manageAdmins: true, // Le premier admin peut gérer les autres admins
        manageBattles: true,
      },
    });

    console.log(`Premier admin créé avec succès pour l'UID: ${userId}`);

    res.json({
      success: true,
      message: 'Premier administrateur créé avec succès',
      admin: {
        userId: adminEntry.userId,
        isAdmin: adminEntry.isAdmin,
        permissions: adminEntry.permissions,
        user: {
          id: user.id,
          displayName: user.displayName,
          email: user.email,
          photoURL: user.photoURL,
        },
      },
    });
  } catch (error) {
    console.error('Erreur lors de la création du premier admin:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la création du premier admin',
      details: error.message,
    });
  }
});

// Route pour vérifier si un admin existe (sans authentification)
router.get('/check-admin-exists', async (req, res) => {
  try {
    const adminCount = await Admin.count();
    res.json({
      success: true,
      adminExists: adminCount > 0,
      count: adminCount,
    });
  } catch (error) {
    console.error('Erreur lors de la vérification des admins:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la vérification des admins',
      details: error.message,
    });
  }
});

module.exports = router;

