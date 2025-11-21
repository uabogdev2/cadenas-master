const express = require('express');
const router = express.Router();
const { checkAdmin, requirePermission } = require('../../middleware/adminAuth');
const { Admin, User } = require('../../models');

// Toutes les routes nécessitent d'être admin
router.use(checkAdmin);

// Obtenir la liste des administrateurs (tous les admins peuvent voir la liste)
router.get('/', async (req, res) => {
  try {
    const admins = await Admin.findAll({
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'displayName', 'email', 'photoURL'],
        },
      ],
      order: [['createdAt', 'DESC']],
    });

    res.json({
      success: true,
      admins: admins.map(admin => ({
        userId: admin.userId,
        isAdmin: admin.isAdmin,
        permissions: admin.permissions,
        user: admin.user,
        createdAt: admin.createdAt,
      })),
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des administrateurs:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des administrateurs',
      details: error.message,
    });
  }
});

// Obtenir les permissions de l'admin actuel
router.get('/me', async (req, res) => {
  try {
    const userId = req.admin.userId;
    const admin = await Admin.findByPk(userId, {
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'displayName', 'email', 'photoURL'],
        },
      ],
    });

    if (!admin) {
      return res.status(404).json({
        success: false,
        error: 'Administrateur non trouvé',
      });
    }

    res.json({
      success: true,
      admin: {
        userId: admin.userId,
        isAdmin: admin.isAdmin,
        permissions: admin.permissions,
        user: admin.user,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la récupération de l\'administrateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération de l\'administrateur',
      details: error.message,
    });
  }
});

// Ajouter un administrateur (nécessite manageAdmins)
router.post('/', requirePermission('manageAdmins'), async (req, res) => {
  try {
    const { userId, permissions } = req.body;

    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'userId est requis',
      });
    }

    // Vérifier si l'utilisateur existe
    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'Utilisateur non trouvé',
      });
    }

    // Vérifier si l'utilisateur est déjà admin
    const existingAdmin = await Admin.findByPk(userId);
    if (existingAdmin) {
      return res.status(400).json({
        success: false,
        error: 'Cet utilisateur est déjà administrateur',
      });
    }

    // Créer l'administrateur
    const admin = await Admin.create({
      userId: userId,
      isAdmin: true,
      permissions: permissions || {
        manageUsers: true,
        manageLevels: true,
        viewStats: true,
        manageAdmins: false,
        manageBattles: true,
      },
    });

    res.json({
      success: true,
      admin: {
        userId: admin.userId,
        isAdmin: admin.isAdmin,
        permissions: admin.permissions,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la création de l\'administrateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la création de l\'administrateur',
      details: error.message,
    });
  }
});

// Mettre à jour les permissions d'un administrateur (nécessite manageAdmins)
router.put('/:userId', requirePermission('manageAdmins'), async (req, res) => {
  try {
    const userId = req.params.userId;
    const { permissions } = req.body;

    const admin = await Admin.findByPk(userId);
    if (!admin) {
      return res.status(404).json({
        success: false,
        error: 'Administrateur non trouvé',
      });
    }

    // Empêcher un admin de modifier ses propres permissions manageAdmins
    if (userId === req.admin.userId && permissions && permissions.manageAdmins === false) {
      return res.status(400).json({
        success: false,
        error: 'Vous ne pouvez pas retirer vos propres permissions manageAdmins',
      });
    }

    if (permissions) {
      admin.permissions = { ...admin.permissions, ...permissions };
      await admin.save();
    }

    res.json({
      success: true,
      admin: {
        userId: admin.userId,
        isAdmin: admin.isAdmin,
        permissions: admin.permissions,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la mise à jour de l\'administrateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la mise à jour de l\'administrateur',
      details: error.message,
    });
  }
});

// Route spéciale pour que le premier admin puisse s'attribuer manageAdmins
router.post('/grant-manage-admins', async (req, res) => {
  try {
    const userId = req.admin.userId;
    const adminRecord = await Admin.findByPk(userId);
    
    if (!adminRecord) {
      return res.status(404).json({
        success: false,
        error: 'Administrateur non trouvé',
      });
    }

    // Vérifier si c'est le seul admin
    const adminCount = await Admin.count();
    if (adminCount === 1) {
      adminRecord.permissions.manageAdmins = true;
      await adminRecord.save();
      
      // Mettre à jour les permissions dans la requête
      req.admin.permissions.manageAdmins = true;
      
      return res.json({
        success: true,
        message: 'Permission manageAdmins accordée (vous êtes le seul admin)',
        admin: {
          userId: adminRecord.userId,
          isAdmin: adminRecord.isAdmin,
          permissions: adminRecord.permissions,
        },
      });
    }

    // Si ce n'est pas le seul admin, vérifier s'il a déjà manageAdmins
    if (adminRecord.permissions.manageAdmins) {
      return res.json({
        success: true,
        message: 'Vous avez déjà la permission manageAdmins',
        admin: {
          userId: adminRecord.userId,
          isAdmin: adminRecord.isAdmin,
          permissions: adminRecord.permissions,
        },
      });
    }

    // Sinon, refuser
    return res.status(403).json({
      success: false,
      error: 'Vous ne pouvez pas obtenir cette permission automatiquement. Contactez un autre administrateur.',
    });
  } catch (error) {
    console.error('Erreur lors de l\'attribution de la permission:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de l\'attribution de la permission',
      details: error.message,
    });
  }
});

// Supprimer un administrateur (nécessite manageAdmins)
router.delete('/:userId', requirePermission('manageAdmins'), async (req, res) => {
  try {
    const userId = req.params.userId;

    // Ne pas permettre de supprimer soi-même
    if (userId === req.admin.userId) {
      return res.status(400).json({
        success: false,
        error: 'Vous ne pouvez pas supprimer vos propres droits administrateur',
      });
    }

    const admin = await Admin.findByPk(userId);
    if (!admin) {
      return res.status(404).json({
        success: false,
        error: 'Administrateur non trouvé',
      });
    }

    await admin.destroy();

    res.json({
      success: true,
      message: 'Administrateur supprimé avec succès',
    });
  } catch (error) {
    console.error('Erreur lors de la suppression de l\'administrateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la suppression de l\'administrateur',
      details: error.message,
    });
  }
});

module.exports = router;
