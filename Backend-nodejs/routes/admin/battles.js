const express = require('express');
const router = express.Router();
const { checkAdmin, requirePermission } = require('../../middleware/adminAuth');
const { Battle, User } = require('../../models');
const { Op } = require('sequelize');

// Toutes les routes nécessitent d'être admin
router.use(checkAdmin);

// Obtenir toutes les batailles avec pagination
router.get('/', requirePermission('manageBattles'), async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const status = req.query.status;
    const mode = req.query.mode;

    const where = {};
    if (status) {
      where.status = status;
    }
    if (mode) {
      where.mode = mode;
    }

    const { count, rows: battles } = await Battle.findAndCountAll({
      where,
      limit,
      offset,
      order: [['createdAt', 'DESC']],
      include: [
        {
          model: User,
          as: 'player1User',
          attributes: ['id', 'displayName', 'email'],
          required: false,
        },
        {
          model: User,
          as: 'player2User',
          attributes: ['id', 'displayName', 'email'],
          required: false,
        },
      ],
    });

    res.json({
      success: true,
      battles: battles.map(battle => ({
        id: battle.id,
        player1: battle.player1,
        player2: battle.player2,
        player1User: battle.player1User,
        player2User: battle.player2User,
        status: battle.status,
        mode: battle.mode,
        roomId: battle.roomId,
        player1Score: battle.player1Score,
        player2Score: battle.player2Score,
        player1QuestionIndex: battle.player1QuestionIndex,
        player2QuestionIndex: battle.player2QuestionIndex,
        winner: battle.winner,
        result: battle.result,
        startTime: battle.startTime,
        endTime: battle.endTime,
        createdAt: battle.createdAt,
        updatedAt: battle.updatedAt,
      })),
      pagination: {
        page,
        limit,
        total: count,
        totalPages: Math.ceil(count / limit),
      },
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des batailles:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des batailles',
      details: error.message,
    });
  }
});

// Obtenir les détails d'une bataille
router.get('/:battleId', requirePermission('manageBattles'), async (req, res) => {
  try {
    const battleId = parseInt(req.params.battleId);

    const battle = await Battle.findByPk(battleId, {
      include: [
        {
          model: User,
          as: 'player1User',
          attributes: ['id', 'displayName', 'email', 'photoURL'],
          required: false,
        },
        {
          model: User,
          as: 'player2User',
          attributes: ['id', 'displayName', 'email', 'photoURL'],
          required: false,
        },
      ],
    });

    if (!battle) {
      return res.status(404).json({
        success: false,
        error: 'Bataille non trouvée',
      });
    }

    res.json({
      success: true,
      battle: {
        id: battle.id,
        player1: battle.player1,
        player2: battle.player2,
        player1User: battle.player1User,
        player2User: battle.player2User,
        status: battle.status,
        mode: battle.mode,
        roomId: battle.roomId,
        player1Score: battle.player1Score,
        player2Score: battle.player2Score,
        player1QuestionIndex: battle.player1QuestionIndex,
        player2QuestionIndex: battle.player2QuestionIndex,
        player1AnsweredQuestions: battle.player1AnsweredQuestions,
        player2AnsweredQuestions: battle.player2AnsweredQuestions,
        questions: battle.questions,
        startTime: battle.startTime,
        endTime: battle.endTime,
        totalTimeLimit: battle.totalTimeLimit,
        winner: battle.winner,
        result: battle.result,
        player1Abandoned: battle.player1Abandoned,
        player2Abandoned: battle.player2Abandoned,
        createdAt: battle.createdAt,
        updatedAt: battle.updatedAt,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la récupération de la bataille:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération de la bataille',
      details: error.message,
    });
  }
});

// Supprimer une bataille
router.delete('/:battleId', requirePermission('manageBattles'), async (req, res) => {
  try {
    const battleId = parseInt(req.params.battleId);

    const battle = await Battle.findByPk(battleId);
    if (!battle) {
      return res.status(404).json({
        success: false,
        error: 'Bataille non trouvée',
      });
    }

    await battle.destroy();

    res.json({
      success: true,
      message: 'Bataille supprimée avec succès',
    });
  } catch (error) {
    console.error('Erreur lors de la suppression de la bataille:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la suppression de la bataille',
      details: error.message,
    });
  }
});

// Nettoyer les anciennes batailles
router.post('/cleanup', requirePermission('manageBattles'), async (req, res) => {
  try {
    const battleService = require('../../services/battleService');
    await battleService.cleanupOldBattles();

    res.json({
      success: true,
      message: 'Nettoyage des anciennes batailles terminé',
    });
  } catch (error) {
    console.error('Erreur lors du nettoyage des batailles:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors du nettoyage des batailles',
      details: error.message,
    });
  }
});

module.exports = router;

