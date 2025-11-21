const express = require('express');
const router = express.Router();
const { checkAdmin, requirePermission } = require('../../middleware/adminAuth');
const { Level } = require('../../models');
const fs = require('fs');
const path = require('path');

// Toutes les routes nécessitent d'être admin
router.use(checkAdmin);

// Obtenir tous les niveaux
router.get('/', requirePermission('manageLevels'), async (req, res) => {
  try {
    const levels = await Level.findAll({
      order: [['id', 'ASC']],
    });

    res.json({
      success: true,
      levels: levels.map(level => ({
        id: level.id,
        name: level.name,
        instruction: level.instruction,
        code: level.code,
        codeLength: level.codeLength,
        pointsReward: level.pointsReward,
        isLocked: level.isLocked,
        timeLimit: level.timeLimit,
        additionalHints: level.additionalHints,
        hintCost: level.hintCost,
        createdAt: level.createdAt,
        updatedAt: level.updatedAt,
      })),
      count: levels.length,
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des niveaux:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des niveaux',
    });
  }
});

// Obtenir un niveau par son ID
router.get('/:id', requirePermission('manageLevels'), async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const level = await Level.findByPk(id);

    if (!level) {
      return res.status(404).json({
        success: false,
        error: 'Niveau non trouvé',
      });
    }

    res.json({
      success: true,
      level: {
        id: level.id,
        name: level.name,
        instruction: level.instruction,
        code: level.code,
        codeLength: level.codeLength,
        pointsReward: level.pointsReward,
        isLocked: level.isLocked,
        timeLimit: level.timeLimit,
        additionalHints: level.additionalHints,
        hintCost: level.hintCost,
        createdAt: level.createdAt,
        updatedAt: level.updatedAt,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la récupération du niveau:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération du niveau',
    });
  }
});

// Créer un nouveau niveau
router.post('/', requirePermission('manageLevels'), async (req, res) => {
  try {
    const {
      id,
      name,
      instruction,
      code,
      codeLength,
      pointsReward,
      isLocked,
      timeLimit,
      additionalHints,
      hintCost,
    } = req.body;

    // Vérifier si le niveau existe déjà
    const existingLevel = await Level.findByPk(id);
    if (existingLevel) {
      return res.status(400).json({
        success: false,
        error: 'Un niveau avec cet ID existe déjà',
      });
    }

    const level = await Level.create({
      id,
      name,
      instruction,
      code,
      codeLength,
      pointsReward: pointsReward || 10,
      isLocked: isLocked !== undefined ? isLocked : true,
      timeLimit: timeLimit || 60,
      additionalHints: additionalHints || [],
      hintCost: hintCost || 100,
    });

    res.json({
      success: true,
      level,
    });
  } catch (error) {
    console.error('Erreur lors de la création du niveau:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la création du niveau',
      details: error.message,
    });
  }
});

// Mettre à jour un niveau
router.put('/:id', requirePermission('manageLevels'), async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const level = await Level.findByPk(id);

    if (!level) {
      return res.status(404).json({
        success: false,
        error: 'Niveau non trouvé',
      });
    }

    const {
      name,
      instruction,
      code,
      codeLength,
      pointsReward,
      isLocked,
      timeLimit,
      additionalHints,
      hintCost,
    } = req.body;

    if (name !== undefined) level.name = name;
    if (instruction !== undefined) level.instruction = instruction;
    if (code !== undefined) level.code = code;
    if (codeLength !== undefined) level.codeLength = codeLength;
    if (pointsReward !== undefined) level.pointsReward = pointsReward;
    if (isLocked !== undefined) level.isLocked = isLocked;
    if (timeLimit !== undefined) level.timeLimit = timeLimit;
    if (additionalHints !== undefined) level.additionalHints = additionalHints;
    if (hintCost !== undefined) level.hintCost = hintCost;

    await level.save();

    res.json({
      success: true,
      level,
    });
  } catch (error) {
    console.error('Erreur lors de la mise à jour du niveau:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la mise à jour du niveau',
      details: error.message,
    });
  }
});

// Supprimer un niveau
router.delete('/:id', requirePermission('manageLevels'), async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const level = await Level.findByPk(id);

    if (!level) {
      return res.status(404).json({
        success: false,
        error: 'Niveau non trouvé',
      });
    }

    await level.destroy();

    res.json({
      success: true,
      message: 'Niveau supprimé avec succès',
    });
  } catch (error) {
    console.error('Erreur lors de la suppression du niveau:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la suppression du niveau',
    });
  }
});

// Initialiser les niveaux depuis le fichier JSON
router.post('/initialize', requirePermission('manageLevels'), async (req, res) => {
  try {
    // Lire le fichier levels.json
    const levelsPath = path.join(__dirname, '../../../assets/data/levels.json');

    if (!fs.existsSync(levelsPath)) {
      return res.status(404).json({
        success: false,
        error: 'Fichier levels.json non trouvé',
      });
    }

    const levelsData = JSON.parse(fs.readFileSync(levelsPath, 'utf8'));

    // Vérifier si les niveaux existent déjà
    const existingLevels = await Level.count();

    if (existingLevels > 0 && !req.query.force) {
      return res.status(400).json({
        success: false,
        error: 'Les niveaux sont déjà initialisés. Utilisez ?force=true pour forcer la réinitialisation',
      });
    }

    // Supprimer les niveaux existants si force=true
    if (req.query.force === 'true') {
      await Level.destroy({ where: {} });
    }

    // Créer les niveaux
    const levels = await Level.bulkCreate(levelsData, {
      ignoreDuplicates: true,
    });

    res.json({
      success: true,
      message: `${levels.length} niveaux créés avec succès`,
      count: levels.length,
    });
  } catch (error) {
    console.error('Erreur lors de l\'initialisation des niveaux:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de l\'initialisation des niveaux',
      details: error.message,
    });
  }
});

// Exporter les niveaux vers JSON
router.get('/export/json', requirePermission('manageLevels'), async (req, res) => {
  try {
    const levels = await Level.findAll({
      order: [['id', 'ASC']],
    });

    const levelsJson = levels.map(level => ({
      id: level.id,
      name: level.name,
      instruction: level.instruction,
      code: level.code,
      codeLength: level.codeLength,
      pointsReward: level.pointsReward,
      isLocked: level.isLocked,
      timeLimit: level.timeLimit,
      additionalHints: level.additionalHints,
      hintCost: level.hintCost,
    }));

    res.json({
      success: true,
      levels: levelsJson,
    });
  } catch (error) {
    console.error('Erreur lors de l\'export des niveaux:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de l\'export des niveaux',
    });
  }
});

// Importer les niveaux depuis JSON
router.post('/import/json', requirePermission('manageLevels'), async (req, res) => {
  try {
    const { levels } = req.body;

    if (!Array.isArray(levels)) {
      return res.status(400).json({
        success: false,
        error: 'Les niveaux doivent être un tableau',
      });
    }

    // Valider les niveaux
    for (const level of levels) {
      if (!level.id || !level.name || !level.instruction || !level.code) {
        return res.status(400).json({
          success: false,
          error: 'Chaque niveau doit avoir id, name, instruction et code',
        });
      }
    }

    // Supprimer les niveaux existants si force=true
    if (req.query.force === 'true') {
      await Level.destroy({ where: {} });
    }

    // Créer les niveaux
    const createdLevels = await Level.bulkCreate(levels, {
      ignoreDuplicates: !req.query.force,
      updateOnDuplicate: ['name', 'instruction', 'code', 'codeLength', 'pointsReward', 'isLocked', 'timeLimit', 'additionalHints', 'hintCost'],
    });

    res.json({
      success: true,
      message: `${createdLevels.length} niveaux importés avec succès`,
      count: createdLevels.length,
    });
  } catch (error) {
    console.error('Erreur lors de l\'import des niveaux:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de l\'import des niveaux',
      details: error.message,
    });
  }
});

module.exports = router;

