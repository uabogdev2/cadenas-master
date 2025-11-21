const express = require('express');
const router = express.Router();
const { checkAdmin, requirePermission } = require('../../middleware/adminAuth');
const { User, UserStats, UserProgress, UnlockedHints, Battle } = require('../../models');
const { Op } = require('sequelize');

// Toutes les routes nécessitent d'être admin
router.use(checkAdmin);

// Obtenir la liste des utilisateurs avec pagination
router.get('/', requirePermission('manageUsers'), async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const search = req.query.search || '';

    const where = {};
    if (search) {
      where[Op.or] = [
        { displayName: { [Op.like]: `%${search}%` } },
        { email: { [Op.like]: `%${search}%` } },
        { id: { [Op.like]: `%${search}%` } },
      ];
    }

    const { count, rows: users } = await User.findAndCountAll({
      where,
      limit,
      offset,
      order: [['createdAt', 'DESC']],
      include: [
        {
          model: UserStats,
          as: 'stats',
          required: false,
        },
      ],
    });

    res.json({
      success: true,
      users: users.map(user => ({
        id: user.id,
        displayName: user.displayName,
        email: user.email,
        photoURL: user.photoURL,
        points: user.points,
        completedLevels: user.completedLevels,
        trophies: user.trophies,
        isAnonymous: user.isAnonymous,
        createdAt: user.createdAt,
        stats: user.stats ? {
          totalAttempts: user.stats.totalAttempts,
          totalPlayTime: user.stats.totalPlayTime,
        } : null,
      })),
      pagination: {
        page,
        limit,
        total: count,
        totalPages: Math.ceil(count / limit),
      },
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des utilisateurs:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des utilisateurs',
    });
  }
});

// Obtenir les détails d'un utilisateur
router.get('/:userId', requirePermission('manageUsers'), async (req, res) => {
  try {
    const userId = req.params.userId;

    const user = await User.findByPk(userId, {
      include: [
        {
          model: UserStats,
          as: 'stats',
          required: false,
        },
        {
          model: UserProgress,
          as: 'progress',
          required: false,
        },
      ],
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'Utilisateur non trouvé',
      });
    }

    // Compter les batailles
    const battlesCount = await Battle.count({
      where: {
        [Op.or]: [
          { player1: userId },
          { player2: userId },
        ],
      },
    });

    res.json({
      success: true,
      user: {
        id: user.id,
        displayName: user.displayName,
        email: user.email,
        photoURL: user.photoURL,
        points: user.points,
        completedLevels: user.completedLevels,
        trophies: user.trophies,
        isAnonymous: user.isAnonymous,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
        stats: user.stats,
        progress: user.progress,
        battlesCount,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la récupération de l\'utilisateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération de l\'utilisateur',
    });
  }
});

// Modifier un utilisateur
router.put('/:userId', requirePermission('manageUsers'), async (req, res) => {
  try {
    const userId = req.params.userId;
    const { displayName, points, completedLevels, trophies } = req.body;

    const user = await User.findByPk(userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'Utilisateur non trouvé',
      });
    }

    if (displayName !== undefined) user.displayName = displayName;
    if (points !== undefined) user.points = points;
    if (completedLevels !== undefined) user.completedLevels = completedLevels;
    if (trophies !== undefined) user.trophies = trophies;

    await user.save();

    res.json({
      success: true,
      user: {
        id: user.id,
        displayName: user.displayName,
        points: user.points,
        completedLevels: user.completedLevels,
        trophies: user.trophies,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la modification de l\'utilisateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la modification de l\'utilisateur',
    });
  }
});

// Supprimer un utilisateur
router.delete('/:userId', requirePermission('manageUsers'), async (req, res) => {
  try {
    const userId = req.params.userId;

    // Supprimer toutes les données associées
    await UserProgress.destroy({ where: { userId } });
    await UserStats.destroy({ where: { userId } });
    await UnlockedHints.destroy({ where: { userId } });
    
    // Supprimer les batailles où l'utilisateur est joueur
    await Battle.destroy({
      where: {
        [Op.or]: [
          { player1: userId },
          { player2: userId },
        ],
      },
    });

    // Supprimer l'utilisateur
    await User.destroy({ where: { id: userId } });

    res.json({
      success: true,
      message: 'Utilisateur supprimé avec succès',
    });
  } catch (error) {
    console.error('Erreur lors de la suppression de l\'utilisateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la suppression de l\'utilisateur',
    });
  }
});

// Réinitialiser les données d'un utilisateur
router.post('/:userId/reset', requirePermission('manageUsers'), async (req, res) => {
  try {
    const userId = req.params.userId;

    // Réinitialiser la progression
    await UserProgress.destroy({ where: { userId } });
    
    // Réinitialiser les indices
    await UnlockedHints.destroy({ where: { userId } });
    
    // Réinitialiser les statistiques
    const stats = await UserStats.findByPk(userId);
    if (stats) {
      stats.totalAttempts = 0;
      stats.totalPlayTime = 0;
      stats.bestTimes = {};
      await stats.save();
    }

    // Réinitialiser l'utilisateur
    const user = await User.findByPk(userId);
    if (user) {
      user.points = 500;
      user.completedLevels = 0;
      user.trophies = 0;
      await user.save();
    }

    res.json({
      success: true,
      message: 'Données utilisateur réinitialisées avec succès',
    });
  } catch (error) {
    console.error('Erreur lors de la réinitialisation:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la réinitialisation',
    });
  }
});

module.exports = router;

