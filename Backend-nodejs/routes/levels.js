const express = require('express');
const router = express.Router();
const { optionalAuthenticate } = require('../middleware/auth');
const { Level } = require('../models');
const levelService = require('../services/levelService');
const fs = require('fs');
const path = require('path');

// Obtenir tous les niveaux (depuis la base de données)
router.get('/', optionalAuthenticate, async (req, res) => {
  try {
    const levels = await levelService.getAllLevels();
    
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
      })),
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des niveaux:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des niveaux',
      details: error.message,
    });
  }
});

// Obtenir un niveau par son ID
router.get('/:id', optionalAuthenticate, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    
    // Valider que l'ID est un nombre valide
    if (isNaN(id) || id <= 0) {
      return res.status(400).json({
        success: false,
        error: 'ID de niveau invalide',
      });
    }
    
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
      },
    });
  } catch (error) {
    console.error('Erreur lors de la récupération du niveau:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération du niveau',
      details: error.message,
    });
  }
});

// Initialiser les niveaux depuis le fichier JSON
router.post('/initialize', async (req, res) => {
  try {
    const count = await levelService.syncLevelsFromJson();
    
    res.json({
      success: true,
      message: `${count} niveaux synchronisés avec succès`,
      count: count,
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

// Réinitialiser les niveaux (supprimer et recréer)
router.post('/reset', async (req, res) => {
  try {
    const count = await levelService.resetLevels();
    
    res.json({
      success: true,
      message: `${count} niveaux réinitialisés avec succès`,
      count: count,
    });
  } catch (error) {
    console.error('Erreur lors de la réinitialisation des niveaux:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la réinitialisation des niveaux',
      details: error.message,
    });
  }
});

// Synchroniser les niveaux depuis la base de données vers le fichier JSON
router.post('/sync-to-json', async (req, res) => {
  try {
    const count = await levelService.syncLevelsToJson();
    
    res.json({
      success: true,
      message: `${count} niveaux synchronisés vers le fichier JSON`,
      count: count,
    });
  } catch (error) {
    console.error('Erreur lors de la synchronisation vers JSON:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la synchronisation vers JSON',
      details: error.message,
    });
  }
});

module.exports = router;

