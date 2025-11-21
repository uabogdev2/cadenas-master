const express = require('express');
const router = express.Router();
const { checkAdmin, requirePermission } = require('../../middleware/adminAuth');
const { User, UserStats, UserProgress, Battle, Level } = require('../../models');
const { Op } = require('sequelize');
const sequelize = require('../../config/database').sequelize;

// Toutes les routes nécessitent d'être admin
router.use(checkAdmin);

// Obtenir les statistiques globales (route principale)
router.get('/', requirePermission('viewStats'), async (req, res) => {
  try {
    // Nombre total d'utilisateurs
    const totalUsers = await User.count();

    // Nombre d'utilisateurs actifs (qui ont complété au moins un niveau)
    const activeUsers = await User.count({
      where: {
        completedLevels: {
          [Op.gt]: 0,
        },
      },
    });

    // Nombre total de niveaux
    const totalLevels = await Level.count();

    // Nombre total de batailles
    const totalBattles = await Battle.count();

    // Nombre de batailles actives
    const activeBattles = await Battle.count({
      where: {
        status: 'active',
      },
    });

    // Statistiques des points
    const pointsStats = await User.findAll({
      attributes: [
        [sequelize.fn('SUM', sequelize.col('points')), 'totalPoints'],
        [sequelize.fn('AVG', sequelize.col('points')), 'avgPoints'],
        [sequelize.fn('MAX', sequelize.col('points')), 'maxPoints'],
        [sequelize.fn('MIN', sequelize.col('points')), 'minPoints'],
      ],
      raw: true,
    }).catch(err => {
      console.error('Erreur lors du calcul des statistiques des points:', err);
      return [{ totalPoints: 0, avgPoints: 0, maxPoints: 0, minPoints: 0 }];
    });

    // Statistiques des niveaux complétés
    const levelsStats = await User.findAll({
      attributes: [
        [sequelize.fn('SUM', sequelize.col('completedLevels')), 'totalCompleted'],
        [sequelize.fn('AVG', sequelize.col('completedLevels')), 'avgCompleted'],
        [sequelize.fn('MAX', sequelize.col('completedLevels')), 'maxCompleted'],
      ],
      raw: true,
    }).catch(err => {
      console.error('Erreur lors du calcul des statistiques des niveaux:', err);
      return [{ totalCompleted: 0, avgCompleted: 0, maxCompleted: 0 }];
    });

    // Top 10 utilisateurs par points
    const topUsersByPoints = await User.findAll({
      order: [['points', 'DESC']],
      limit: 10,
      attributes: ['id', 'displayName', 'points', 'completedLevels', 'trophies'],
    });

    // Top 10 utilisateurs par niveaux complétés
    const topUsersByLevels = await User.findAll({
      order: [['completedLevels', 'DESC']],
      limit: 10,
      attributes: ['id', 'displayName', 'points', 'completedLevels', 'trophies'],
    });

    // Statistiques des batailles
    const battlesStats = await Battle.findAll({
      attributes: [
        'status',
        [sequelize.fn('COUNT', sequelize.col('id')), 'count'],
      ],
      group: ['status'],
      raw: true,
    });

    res.json({
      success: true,
      stats: {
        users: {
          total: totalUsers,
          active: activeUsers,
          inactive: totalUsers - activeUsers,
        },
        levels: {
          total: totalLevels,
        },
        battles: {
          total: totalBattles || 0,
          active: activeBattles || 0,
          byStatus: (battlesStats || []).reduce((acc, stat) => {
            if (stat && stat.status) {
              acc[stat.status] = parseInt(stat.count || 0);
            }
            return acc;
          }, {}),
        },
        points: {
          total: parseInt(pointsStats[0]?.totalPoints || 0) || 0,
          average: (parseFloat(pointsStats[0]?.avgPoints || 0) || 0).toFixed(2),
          max: parseInt(pointsStats[0]?.maxPoints || 0) || 0,
          min: parseInt(pointsStats[0]?.minPoints || 0) || 0,
        },
        completedLevels: {
          totalCompleted: parseInt(levelsStats[0]?.totalCompleted || 0) || 0,
          averageCompleted: (parseFloat(levelsStats[0]?.avgCompleted || 0) || 0).toFixed(2),
          maxCompleted: parseInt(levelsStats[0]?.maxCompleted || 0) || 0,
        },
        topUsers: {
          byPoints: topUsersByPoints || [],
          byLevels: topUsersByLevels || [],
        },
      },
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des statistiques:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des statistiques',
      details: error.message,
    });
  }
});

// Obtenir les statistiques détaillées d'un niveau
router.get('/level/:levelId', requirePermission('viewStats'), async (req, res) => {
  try {
    const levelId = parseInt(req.params.levelId);

    // Nombre d'utilisateurs qui ont complété ce niveau
    const completedCount = await UserProgress.count({
      where: {
        levelId,
        isCompleted: true,
      },
    });

    // Nombre total de tentatives pour ce niveau
    const totalAttempts = await UserProgress.sum('attempts', {
      where: {
        levelId,
      },
    }) || 0;

    // Meilleur temps pour ce niveau
    const bestTime = await UserProgress.min('bestTime', {
      where: {
        levelId,
        bestTime: {
          [Op.ne]: null,
        },
      },
    });

    // Temps moyen pour ce niveau
    const avgTime = await UserProgress.findAll({
      attributes: [
        [sequelize.fn('AVG', sequelize.col('bestTime')), 'avgTime'],
      ],
      where: {
        levelId,
        bestTime: {
          [Op.ne]: null,
        },
      },
      raw: true,
    });

    res.json({
      success: true,
      stats: {
        levelId,
        completedCount,
        totalAttempts,
        bestTime: bestTime || null,
        avgTime: avgTime[0]?.avgTime ? parseFloat(avgTime[0].avgTime).toFixed(2) : null,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des statistiques du niveau:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des statistiques du niveau',
    });
  }
});

module.exports = router;

