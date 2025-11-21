const express = require('express');
const router = express.Router();
const { authenticateFirebase } = require('../middleware/auth');
const battleService = require('../services/battleService');

// Toutes les routes nécessitent l'authentification
router.use(authenticateFirebase);

// Créer une nouvelle bataille
router.post('/create', async (req, res) => {
  try {
    const userId = req.user.uid;
    const { mode, roomId } = req.body;

    const battle = await battleService.createBattle(
      userId,
      mode || 'ranked',
      roomId || null,
      req.user || {}
    );

    res.json({
      success: true,
      battle: {
        id: battle.id,
        player1: battle.player1,
        player2: battle.player2,
        status: battle.status,
        mode: battle.mode,
        roomId: battle.roomId,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la création de la bataille:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la création de la bataille',
      details: error.message,
    });
  }
});

// Matchmaking classé : chercher une bataille et la rejoindre automatiquement, ou créer une nouvelle bataille
router.post('/matchmaking/ranked', async (req, res) => {
  try {
    const userId = req.user.uid;
    
    const waitingBattle = await battleService.findWaitingBattle(userId, 'ranked');

    if (waitingBattle) {
      try {
        const joinedBattle = await battleService.joinBattle(
          waitingBattle.id,
          userId,
          req.user || {}
        );

        return res.json({
          success: true,
          battle: {
            id: joinedBattle.id,
            player1: joinedBattle.player1,
            player2: joinedBattle.player2,
            status: joinedBattle.status,
            mode: joinedBattle.mode,
            questions: joinedBattle.questions,
            startTime: joinedBattle.startTime ? joinedBattle.startTime.toISOString() : null,
            totalTimeLimit: joinedBattle.totalTimeLimit,
          },
          joined: true,
        });
      } catch (joinError) {
        console.log('Erreur lors de la jonction, création d\'une nouvelle bataille:', joinError.message);
      }
    }

    const newBattle = await battleService.createBattle(userId, 'ranked', null, req.user || {});
    
    res.json({
       success: true,
       battle: {
         id: newBattle.id,
         player1: newBattle.player1,
         player2: newBattle.player2,
         status: newBattle.status,
         mode: newBattle.mode,
         roomId: newBattle.roomId,
       },
       joined: false,
    });
  } catch (error) {
    console.error('Erreur lors du matchmaking classé:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors du matchmaking classé',
      details: error.message,
    });
  }
});

// Trouver une bataille en attente (avec polling optimisé) - DEPRECATED, utiliser /matchmaking/ranked
router.get('/find', async (req, res) => {
  try {
    const userId = req.user.uid;
    const mode = req.query.mode || 'ranked';

    const battle = await battleService.findWaitingBattle(userId, mode);

    if (battle) {
      return res.json({
        success: true,
        battle: {
          id: battle.id,
          player1: battle.player1,
          mode: battle.mode,
          roomId: battle.roomId,
          status: battle.status,
        },
      });
    }

    res.json({
      success: false,
      message: 'Aucune bataille disponible',
    });
  } catch (error) {
    console.error('Erreur lors de la recherche d\'une bataille:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la recherche d\'une bataille',
      details: error.message,
    });
  }
});

// Trouver une salle amicale
router.get('/find-friendly/:roomId', async (req, res) => {
  try {
    const userId = req.user.uid;
    const roomId = req.params.roomId;

    const battle = await battleService.findFriendlyRoom(roomId, userId);

    if (battle) {
      res.json({
        success: true,
        battle: {
          id: battle.id,
          player1: battle.player1,
          mode: battle.mode,
          roomId: battle.roomId,
          status: battle.status,
        },
      });
    } else {
      res.json({
        success: false,
        message: 'Salle non trouvée',
      });
    }
  } catch (error) {
    console.error('Erreur lors de la recherche de la salle amicale:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la recherche de la salle amicale',
      details: error.message,
    });
  }
});

// Rejoindre une bataille
router.post('/join/:battleId', async (req, res) => {
  try {
    const userId = req.user.uid;
    const battleId = parseInt(req.params.battleId);

    const battle = await battleService.joinBattle(battleId, userId, req.user || {});

    res.json({
      success: true,
      battle: {
        id: battle.id,
        player1: battle.player1,
        player2: battle.player2,
        status: battle.status,
        mode: battle.mode,
        questions: battle.questions,
        startTime: battle.startTime ? battle.startTime.toISOString() : null,
        totalTimeLimit: battle.totalTimeLimit,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la jonction à la bataille:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la jonction à la bataille',
      details: error.message,
    });
  }
});

// Obtenir l'état d'une bataille (avec polling optimisé)
router.get('/:battleId', async (req, res) => {
  try {
    const userId = req.user.uid;
    const battleId = parseInt(req.params.battleId);

    const battle = await battleService.getBattle(battleId);

    if (!battle) {
      return res.status(404).json({
        success: false,
        error: 'Bataille non trouvée',
      });
    }

    if (battle.player1 !== userId && battle.player2 !== userId) {
      return res.status(403).json({
        success: false,
        error: 'Vous n\'êtes pas un joueur de cette bataille',
      });
    }

    const parseJsonField = (field) => {
      if (field === null || field === undefined) return field;
      if (typeof field === 'string') {
        try {
          return JSON.parse(field);
        } catch (e) {
          console.warn('Erreur lors du parsing JSON:', e);
          return field;
        }
      }
      return field;
    };

    res.json({
      success: true,
      battle: {
        id: battle.id,
        player1: battle.player1,
        player2: battle.player2,
        status: battle.status,
        mode: battle.mode,
        player1Score: battle.player1Score,
        player2Score: battle.player2Score,
        player1QuestionIndex: battle.player1QuestionIndex,
        player2QuestionIndex: battle.player2QuestionIndex,
        player1AnsweredQuestions: parseJsonField(battle.player1AnsweredQuestions),
        player2AnsweredQuestions: parseJsonField(battle.player2AnsweredQuestions),
        questions: parseJsonField(battle.questions),
        startTime: battle.startTime ? battle.startTime.toISOString() : null,
        endTime: battle.endTime ? battle.endTime.toISOString() : null,
        totalTimeLimit: battle.totalTimeLimit,
        winner: battle.winner,
        result: battle.result,
        player1Abandoned: battle.player1Abandoned,
        player2Abandoned: battle.player2Abandoned,
        roomId: battle.roomId,
        trophyChanges: parseJsonField(battle.trophyChanges) || {},
      },
      cached: false,
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

// Incrémenter le score et passer à la question suivante
router.post('/:battleId/score', async (req, res) => {
  try {
    const userId = req.user.uid;
    const battleId = parseInt(req.params.battleId);
    const { questionIndex } = req.body;

    if (typeof questionIndex !== 'number') {
      return res.status(400).json({
        success: false,
        error: 'questionIndex doit être un nombre',
      });
    }

    const battle = await battleService.incrementScoreAndNext(battleId, userId, questionIndex);

    res.json({
      success: true,
      battle: {
        id: battle.id,
        player1Score: battle.player1Score,
        player2Score: battle.player2Score,
        player1QuestionIndex: battle.player1QuestionIndex,
        player2QuestionIndex: battle.player2QuestionIndex,
        player1AnsweredQuestions: battle.player1AnsweredQuestions,
        player2AnsweredQuestions: battle.player2AnsweredQuestions,
      },
    });
  } catch (error) {
    console.error('Erreur lors de la mise à jour du score:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la mise à jour du score',
      details: error.message,
    });
  }
});

// Passer à la question suivante
router.post('/:battleId/next', async (req, res) => {
  try {
    const userId = req.user.uid;
    const battleId = parseInt(req.params.battleId);

    const battle = await battleService.nextQuestion(battleId, userId);

    res.json({
      success: true,
      battle: {
        id: battle.id,
        player1QuestionIndex: battle.player1QuestionIndex,
        player2QuestionIndex: battle.player2QuestionIndex,
      },
    });
  } catch (error) {
    console.error('Erreur lors du passage à la question suivante:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors du passage à la question suivante',
      details: error.message,
    });
  }
});

// Abandonner une bataille
router.post('/:battleId/abandon', async (req, res) => {
  try {
    const userId = req.user.uid;
    const battleId = parseInt(req.params.battleId);

    const battle = await battleService.abandonBattle(battleId, userId);

    res.json({
      success: true,
      battle: {
        id: battle.id,
        player1: battle.player1,
        player2: battle.player2,
        status: battle.status,
        winner: battle.winner,
        result: battle.result,
        player1Score: battle.player1Score,
        player2Score: battle.player2Score,
        mode: battle.mode,
        player1Abandoned: battle.player1Abandoned,
        player2Abandoned: battle.player2Abandoned,
        trophyChanges: battle.trophyChanges || {},
      },
    });
  } catch (error) {
    console.error('Erreur lors de l\'abandon de la bataille:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de l\'abandon de la bataille',
      details: error.message,
    });
  }
});

// Terminer une bataille
router.post('/:battleId/finish', async (req, res) => {
  try {
    const battleId = parseInt(req.params.battleId);

    const result = await battleService.finishBattle(battleId);

    res.json({
      success: true,
      result: result,
      trophyChanges: result.trophyChanges || {},
    });
  } catch (error) {
    console.error('Erreur lors de la finalisation de la bataille:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la finalisation de la bataille',
      details: error.message,
    });
  }
});

// Supprimer une bataille (seulement si elle est en attente et que l'utilisateur est le créateur)
router.delete('/:battleId', async (req, res) => {
  try {
    const userId = req.user.uid;
    const battleId = parseInt(req.params.battleId);

    const result = await battleService.deleteBattle(battleId, userId);

    if (result.status === 'deleted') {
      return res.json({
        success: true,
        message: 'Bataille supprimée avec succès',
      });
    }

    if (result.status === 'not_found') {
      return res.json({
        success: true,
        message: 'Bataille déjà supprimée',
      });
    }

    return res.status(403).json({
      success: false,
      error: 'Impossible de supprimer cette bataille',
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

module.exports = router;

