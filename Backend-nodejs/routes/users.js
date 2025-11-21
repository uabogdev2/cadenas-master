const express = require('express');
const router = express.Router();
const { authenticateFirebase, optionalAuthenticate } = require('../middleware/auth');
const { User, UserProgress, UserStats, UnlockedHints } = require('../models');
const { Op, fn, col } = require('sequelize');
const { sequelize } = require('../config/database');

const DISPLAY_NAME_REGEX = /^[A-Za-z0-9]{3,10}$/;

const normalizeDisplayName = (value = '') => value.trim();

async function isDisplayNameTaken(displayName, excludeUserId) {
  const whereConditions = [
    sequelize.where(fn('LOWER', col('displayName')), displayName.toLowerCase()),
  ];

  if (excludeUserId) {
    whereConditions.push({ id: { [Op.ne]: excludeUserId } });
  }

  const existing = await User.findOne({
    where: {
      [Op.and]: whereConditions,
    },
  });

  return Boolean(existing);
}

async function validateDisplayNameOrThrow(displayName, excludeUserId) {
  const value = normalizeDisplayName(displayName);
  if (!DISPLAY_NAME_REGEX.test(value)) {
    const error = new Error('DISPLAY_NAME_INVALID');
    error.code = 'DISPLAY_NAME_INVALID';
    error.status = 400;
    throw error;
  }

  const taken = await isDisplayNameTaken(value, excludeUserId);
  if (taken) {
    const error = new Error('DISPLAY_NAME_TAKEN');
    error.code = 'DISPLAY_NAME_TAKEN';
    error.status = 409;
    throw error;
  }

  return value;
}

function handleDisplayNameError(res, error) {
  if (error.code === 'DISPLAY_NAME_INVALID') {
    res.status(error.status || 400).json({
      success: false,
      error: 'Le nom doit contenir 3 à 10 caractères alphanumériques sans espace.',
      errorCode: error.code,
    });
    return true;
  }
  if (error.code === 'DISPLAY_NAME_TAKEN') {
    res.status(error.status || 409).json({
      success: false,
      error: 'Ce nom est déjà utilisé.',
      errorCode: error.code,
    });
    return true;
  }
  return false;
}

// Initialiser les données utilisateur
router.post('/initialize', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;
    
    // Vérifier si l'utilisateur existe déjà
    let user = await User.findByPk(userId);
    
    if (!user) {
      // Utiliser les informations du body si fournies, sinon utiliser celles du token Firebase
      const displayName = req.body.displayName || req.user.name || 'Joueur';
      const email = req.body.email || req.user.email;
      const photoURL = req.body.photoURL || req.user.picture;
      
      // Créer un nouvel utilisateur
      user = await User.create({
        id: userId,
        displayName: displayName,
        email: email,
        photoURL: photoURL,
        points: 500,
        completedLevels: 0,
        trophies: 0,
        isAnonymous: email ? false : true,
      });
      
      // Initialiser les statistiques
      await UserStats.create({
        userId: userId,
        totalAttempts: 0,
        totalPlayTime: 0,
        bestTimes: {},
      });
    } else {
      // Mettre à jour les informations si elles sont fournies dans le body
      if (req.body.displayName !== undefined) {
        user.displayName = req.body.displayName;
      }
      if (req.body.email !== undefined) {
        user.email = req.body.email;
      }
      if (req.body.photoURL !== undefined) {
        user.photoURL = req.body.photoURL;
      }
      await user.save();
    }
    
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
      },
    });
  } catch (error) {
    console.error('Erreur lors de l\'initialisation de l\'utilisateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de l\'initialisation de l\'utilisateur',
      details: error.message,
    });
  }
});

// Obtenir les informations de l'utilisateur
router.get('/me', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;
    const includeStats = req.query.includeStats === 'true';
    const user = await User.findByPk(userId);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'Utilisateur non trouvé',
      });
    }

    let statsPayload;
    if (includeStats) {
      const stats = await UserStats.findByPk(userId);
      statsPayload = stats
        ? {
            totalAttempts: stats.totalAttempts || 0,
            totalPlayTime: stats.totalPlayTime || 0,
            bestTimes: stats.bestTimes || {},
          }
        : {
            totalAttempts: 0,
            totalPlayTime: 0,
            bestTimes: {},
          };
    }
    
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
      },
      ...(includeStats ? { stats: statsPayload } : {}),
    });
  } catch (error) {
    console.error('Erreur lors de la récupération de l\'utilisateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération de l\'utilisateur',
    });
  }
});

// Mettre à jour l'utilisateur (points, completedLevels, trophies, etc.)
router.put('/me', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;
    const { points, completedLevels, trophies, displayName, photoURL } = req.body;
    
    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'Utilisateur non trouvé',
      });
    }
    
    // Mettre à jour uniquement les champs fournis
    if (points !== undefined) {
      if (typeof points !== 'number') {
        return res.status(400).json({
          success: false,
          error: 'Les points doivent être un nombre',
        });
      }
      user.points = points;
    }
    if (completedLevels !== undefined) {
      if (typeof completedLevels !== 'number') {
        return res.status(400).json({
          success: false,
          error: 'Le nombre de niveaux complétés doit être un nombre',
        });
      }
      user.completedLevels = completedLevels;
    }
    if (trophies !== undefined) {
      if (typeof trophies !== 'number') {
        return res.status(400).json({
          success: false,
          error: 'Les trophées doivent être un nombre',
        });
      }
      user.trophies = trophies;
    }
    if (displayName !== undefined) {
      try {
        user.displayName = await validateDisplayNameOrThrow(displayName, userId);
      } catch (error) {
        if (handleDisplayNameError(res, error)) {
          return;
        }
        throw error;
      }
    }
    if (photoURL !== undefined) {
      user.photoURL = photoURL;
    }
    
    await user.save();
    
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
      },
    });
  } catch (error) {
    console.error('Erreur lors de la mise à jour de l\'utilisateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la mise à jour de l\'utilisateur',
    });
  }
});

// Vérifier la disponibilité d'un nom d'utilisateur
router.get('/display-name/:displayName', authenticateFirebase, async (req, res) => {
  try {
    const rawValue = req.params.displayName || '';
    const normalized = normalizeDisplayName(rawValue);
    const isValid = DISPLAY_NAME_REGEX.test(normalized);

    if (!isValid) {
      return res.json({
        success: true,
        valid: false,
        available: false,
      });
    }

    const available = !(await isDisplayNameTaken(normalized, req.user.uid));
    res.json({
      success: true,
      valid: true,
      available,
    });
  } catch (error) {
    console.error('Erreur lors de la vérification du nom d\'utilisateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la vérification du nom d\'utilisateur',
    });
  }
});

// Mettre à jour le nom d'utilisateur (10 caractères max, sans espace)
router.post('/display-name', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;
    const desiredName = req.body?.displayName;

    const validatedName = await validateDisplayNameOrThrow(desiredName, userId);
    await User.update({ displayName: validatedName }, { where: { id: userId } });

    res.json({
      success: true,
      displayName: validatedName,
    });
  } catch (error) {
    if (handleDisplayNameError(res, error)) {
      return;
    }
    console.error('Erreur lors de la mise à jour du nom d\'utilisateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la mise à jour du nom d\'utilisateur',
    });
  }
});

// Mettre à jour les points
router.put('/points', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;
    const { points } = req.body;
    
    if (typeof points !== 'number') {
      return res.status(400).json({
        success: false,
        error: 'Les points doivent être un nombre',
      });
    }
    
    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'Utilisateur non trouvé',
      });
    }
    
    user.points = points;
    await user.save();
    
    res.json({
      success: true,
      points: user.points,
    });
  } catch (error) {
    console.error('Erreur lors de la mise à jour des points:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la mise à jour des points',
    });
  }
});

// Obtenir les points
router.get('/points', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;
    const user = await User.findByPk(userId);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'Utilisateur non trouvé',
      });
    }
    
    res.json({
      success: true,
      points: user.points,
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des points:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des points',
    });
  }
});

// Ajuster les points (ajout/soustraction sécurisé)
router.post('/me/points/adjust', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;
    const { delta } = req.body;

    if (typeof delta !== 'number' || Number.isNaN(delta)) {
      return res.status(400).json({
        success: false,
        error: 'delta doit être un nombre',
      });
    }

    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'Utilisateur non trouvé',
      });
    }

    const currentPoints = user.points || 0;
    const newPoints = currentPoints + delta;
    if (newPoints < 0) {
      return res.status(400).json({
        success: false,
        error: 'Points insuffisants',
      });
    }

    user.points = newPoints;
    await user.save();

    res.json({
      success: true,
      points: user.points,
    });
  } catch (error) {
    console.error('Erreur lors de l\'ajustement des points:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de l\'ajustement des points',
    });
  }
});

// Ajuster les trophées (ajout/soustraction sécurisé)
router.post('/me/trophies/adjust', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;
    const { delta } = req.body;

    if (typeof delta !== 'number' || Number.isNaN(delta)) {
      return res.status(400).json({
        success: false,
        error: 'delta doit être un nombre',
      });
    }

    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'Utilisateur non trouvé',
      });
    }

    const currentTrophies = user.trophies || 0;
    const newTrophies = currentTrophies + delta;
    if (newTrophies < 0) {
      return res.status(400).json({
        success: false,
        error: 'Trophées insuffisants',
      });
    }

    user.trophies = newTrophies;
    await user.save();

    res.json({
      success: true,
      trophies: user.trophies,
    });
  } catch (error) {
    console.error('Erreur lors de l\'ajustement des trophées:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de l\'ajustement des trophées',
    });
  }
});

// Sauvegarder la progression d'un niveau
router.post('/progress/:levelId', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;
    const levelId = parseInt(req.params.levelId);
    const { isCompleted, bestTime, attempts } = req.body;
    
    if (typeof isCompleted !== 'boolean') {
      return res.status(400).json({
        success: false,
        error: 'isCompleted doit être un booléen',
      });
    }
    
    // Créer ou mettre à jour la progression
    const [progress, created] = await UserProgress.findOrCreate({
      where: { userId, levelId },
      defaults: {
        userId,
        levelId,
        isCompleted: isCompleted || false,
        bestTime: bestTime || null,
        attempts: attempts || 0,
        lastPlayed: new Date(),
      },
    });
    
    if (!created) {
      progress.isCompleted = isCompleted || progress.isCompleted;
      progress.bestTime = bestTime !== undefined ? bestTime : progress.bestTime;
      progress.attempts = attempts !== undefined ? attempts : progress.attempts;
      progress.lastPlayed = new Date();
      await progress.save();
    }
    
    // Si le niveau est complété, mettre à jour le compteur global
    if (isCompleted && created) {
      const user = await User.findByPk(userId);
      if (user) {
        user.completedLevels += 1;
        await user.save();
      }
    }
    
    // Mettre à jour les statistiques
    const stats = await UserStats.findByPk(userId);
    if (stats) {
      stats.totalAttempts += attempts || 0;
      if (bestTime) {
        const bestTimes = stats.bestTimes || {};
        bestTimes[levelId] = bestTime;
        stats.bestTimes = bestTimes;
      }
      await stats.save();
    }
    
    res.json({
      success: true,
      progress: {
        levelId: progress.levelId,
        isCompleted: progress.isCompleted,
        bestTime: progress.bestTime,
        attempts: progress.attempts,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la sauvegarde de la progression:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la sauvegarde de la progression',
    });
  }
});

// Obtenir la progression d'un niveau
router.get('/progress/:levelId', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;
    const levelId = parseInt(req.params.levelId);
    
    const progress = await UserProgress.findOne({
      where: { userId, levelId },
    });
    
    if (!progress) {
      return res.json({
        success: true,
        progress: {
          isCompleted: false,
          bestTime: null,
          attempts: 0,
        },
      });
    }
    
    res.json({
      success: true,
      progress: {
        isCompleted: progress.isCompleted,
        bestTime: progress.bestTime,
        attempts: progress.attempts,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la récupération de la progression:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération de la progression',
    });
  }
});

// Sauvegarder les indices débloqués
router.post('/hints/:levelId', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;
    const levelId = parseInt(req.params.levelId);
    const { indices } = req.body;
    
    if (!Array.isArray(indices)) {
      return res.status(400).json({
        success: false,
        error: 'Les indices doivent être un tableau',
      });
    }
    
    const [unlockedHints, created] = await UnlockedHints.findOrCreate({
      where: { userId, levelId },
      defaults: {
        userId,
        levelId,
        indices,
      },
    });
    
    if (!created) {
      unlockedHints.indices = indices;
      await unlockedHints.save();
    }
    
    res.json({
      success: true,
      indices: unlockedHints.indices,
    });
  } catch (error) {
    console.error('Erreur lors de la sauvegarde des indices:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la sauvegarde des indices',
    });
  }
});

// Obtenir les indices débloqués
router.get('/hints/:levelId', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;
    const levelId = parseInt(req.params.levelId);
    
    const unlockedHints = await UnlockedHints.findOne({
      where: { userId, levelId },
    });
    
    res.json({
      success: true,
      indices: unlockedHints ? unlockedHints.indices : [],
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des indices:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des indices',
    });
  }
});

// Obtenir les statistiques globales
router.get('/stats', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;
    const stats = await UserStats.findByPk(userId);
    
    if (!stats) {
      return res.json({
        success: true,
        stats: {
          totalAttempts: 0,
          totalPlayTime: 0,
          bestTimes: {},
        },
      });
    }
    
    res.json({
      success: true,
      stats: {
        totalAttempts: stats.totalAttempts,
        totalPlayTime: stats.totalPlayTime,
        bestTimes: stats.bestTimes || {},
      },
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des statistiques:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des statistiques',
    });
  }
});

// Synchroniser toutes les données
router.post('/sync', authenticateFirebase, async (req, res) => {
  try {
    const userId = req.user.uid;
    const { points, trophies, completedLevels, displayName, photoURL, stats } = req.body;
    
    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'Utilisateur non trouvé',
      });
    }
    
    // Mettre à jour les données utilisateur
    if (points !== undefined) user.points = points;
    if (trophies !== undefined) user.trophies = trophies;
    if (completedLevels !== undefined) user.completedLevels = completedLevels;
    if (displayName !== undefined) user.displayName = displayName;
    if (photoURL !== undefined) user.photoURL = photoURL;
    await user.save();
    
    // Mettre à jour les statistiques
    if (stats) {
      const userStats = await UserStats.findByPk(userId);
      if (userStats) {
        userStats.totalAttempts = stats.totalAttempts || userStats.totalAttempts;
        userStats.totalPlayTime = stats.totalPlayTime || userStats.totalPlayTime;
        userStats.bestTimes = stats.bestTimes || userStats.bestTimes;
        await userStats.save();
      }
    }
    
    res.json({
      success: true,
      message: 'Données synchronisées avec succès',
    });
  } catch (error) {
    console.error('Erreur lors de la synchronisation:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la synchronisation',
    });
  }
});

// Obtenir le classement des joueurs (top par trophées)
// IMPORTANT: Cette route DOIT être définie AVANT /:userId/rank pour éviter les conflits
router.get('/leaderboard', optionalAuthenticate, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 100;

    // Récupérer tous les utilisateurs avec trophées > 0, triés par trophées décroissants
    const users = await User.findAll({
      where: {
        trophies: {
          [Op.gt]: 0,
        },
      },
      order: [['trophies', 'DESC'], ['id', 'ASC']],
      limit: limit,
      attributes: ['id', 'displayName', 'trophies', 'points', 'completedLevels', 'photoURL'],
    });

    res.json({
      success: true,
      players: users.map(user => ({
        id: user.id,
        displayName: user.displayName || 'Joueur',
        trophies: user.trophies || 0,
        points: user.points || 0,
        completedLevels: user.completedLevels || 0,
        photoURL: user.photoURL || null,
      })),
    });
  } catch (error) {
    console.error('Erreur lors de la récupération du classement:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération du classement',
      details: error.message,
    });
  }
});

// Obtenir le rang d'un joueur dans le classement
// IMPORTANT: Cette route DOIT être définie APRÈS /leaderboard
router.get('/:userId/rank', optionalAuthenticate, async (req, res) => {
  try {
    const userId = req.params.userId;

    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'Utilisateur non trouvé',
      });
    }

    const userTrophies = user.trophies || 0;

    // Compter combien de joueurs ont plus de trophées
    const usersAbove = await User.count({
      where: {
        trophies: {
          [Op.gt]: userTrophies,
        },
      },
    });

    const rank = usersAbove + 1;

    res.json({
      success: true,
      rank: rank,
    });
  } catch (error) {
    console.error('Erreur lors de la récupération du rang du joueur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération du rang du joueur',
    });
  }
});

module.exports = router;

