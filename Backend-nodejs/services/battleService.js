const { Battle, Level, User, UserStats, GameConfig } = require('../models');
const { Op } = require('sequelize');
const levelService = require('./levelService');

// Récupérer la configuration du jeu
async function getGameConfig() {
  try {
    const [config] = await GameConfig.findOrCreate({
      where: { id: 1 },
      defaults: {
        trophies_win: 100,
        trophies_loss: 100,
        trophies_draw: 10,
        game_timer: 300,
        question_timer: 30,
        min_version_android: '1.0.0',
        min_version_ios: '1.0.0',
        force_update: false,
        maintenance_mode: false,
      }
    });
    return config;
  } catch (error) {
    console.error('Erreur lors de la récupération de la configuration:', error);
    // Valeurs par défaut en cas d'erreur
    return {
      trophies_win: 100,
      trophies_loss: 100,
      trophies_draw: 10,
      game_timer: 300,
      question_timer: 30,
    };
  }
}

// Générer un ID de salle aléatoire (6 caractères)
function generateRoomId() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let roomId = '';
  for (let i = 0; i < 6; i++) {
    roomId += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return roomId;
}

// Mélanger les questions de manière déterministe basée sur l'ID de la bataille
function shuffleQuestionsDeterministic(questions, battleId) {
  if (questions.length === 0) return questions;
  
  // Créer un seed déterministe basé sur l'ID de la bataille
  let seed = 0;
  for (let i = 0; i < battleId.length; i++) {
    seed = (seed * 31 + battleId.charCodeAt(i)) % 0x7FFFFFFF;
  }
  
  // Utiliser ce seed pour mélanger de manière déterministe
  const shuffled = [...questions];
  const random = (() => {
    let value = seed;
    return () => {
      value = (value * 9301 + 49297) % 233280;
      return value / 233280;
    };
  })();
  
  // Mélange de Fisher-Yates avec seed déterministe
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  
  return shuffled;
}

// Convertir un Level en format JSON simplifié pour le duel
function levelToDuelJson(level) {
  return {
    id: level.id,
    instruction: level.instruction,
    code: level.code,
    codeLength: level.codeLength,
  };
}

// Parser un champ JSON qui peut être une string ou un array
// Force toujours le retour d'un vrai array JavaScript natif
function parseJsonField(field) {
  // Si null ou undefined, retourner un array vide
  if (field === null || field === undefined) {
    return [];
  }
  
  let parsed;
  
  // Si c'est une string, la parser en JSON
  if (typeof field === 'string') {
    try {
      parsed = JSON.parse(field);
    } catch (e) {
      console.warn('[parseJsonField] Erreur lors du parsing JSON string:', e, field);
      return [];
    }
  } else {
    parsed = field;
  }
  
  // Si c'est déjà un array JavaScript natif, créer une copie
  if (Array.isArray(parsed)) {
    try {
      // Utiliser Array.from pour créer un nouveau array natif
      return Array.from(parsed);
    } catch (e) {
      console.warn('[parseJsonField] Erreur lors de la création du array:', e);
      return [];
    }
  }
  
  // Si c'est un objet array-like (a une propriété length), essayer de le convertir
  if (parsed && typeof parsed === 'object' && 'length' in parsed) {
    try {
      const arr = Array.from(parsed);
      // Vérifier que c'est vraiment un array avec toutes les méthodes
      if (Array.isArray(arr) && typeof arr.push === 'function') {
        return arr;
      }
    } catch (e) {
      console.warn('[parseJsonField] Erreur lors de la conversion array-like en array:', e);
    }
  }
  
  // Si c'est un objet avec des propriétés numériques, essayer de le convertir
  if (parsed && typeof parsed === 'object') {
    try {
      const keys = Object.keys(parsed);
      const numericKeys = keys.filter(k => /^\d+$/.test(k)).map(k => parseInt(k));
      if (numericKeys.length > 0) {
        const maxKey = Math.max(...numericKeys);
        const arr = [];
        for (let i = 0; i <= maxKey; i++) {
          if (parsed[i] !== undefined) {
            arr[i] = parsed[i];
          }
        }
        return arr;
      }
    } catch (e) {
      console.warn('[parseJsonField] Erreur lors de la conversion objet en array:', e);
    }
  }
  
  // Sinon, retourner un array vide
  console.warn('[parseJsonField] Impossible de convertir en array:', typeof parsed, parsed);
  return [];
}

function sanitizeDisplayName(name) {
  if (!name || typeof name !== 'string') return null;
  const cleaned = name.replace(/\s+/g, '').substring(0, 10);
  return cleaned || null;
}

async function ensurePlayerProfile(userId, profile = {}) {
  if (!userId) return null;
  const displayName =
    sanitizeDisplayName(profile.name) || `Joueur_${userId.slice(0, 5)}`;

  const defaults = {
    id: userId,
    displayName,
    email: profile.email || null,
    photoURL: profile.picture || null,
    isAnonymous: profile.email ? false : true,
    points: 500,
    completedLevels: 0,
    trophies: 0,
  };

  const [user, created] = await User.findOrCreate({
    where: { id: userId },
    defaults,
  });

  if (!created) {
    let changed = false;
    if ((!user.displayName || user.displayName === 'Joueur') && displayName) {
      user.displayName = displayName;
      changed = true;
    }
    if (!user.photoURL && defaults.photoURL) {
      user.photoURL = defaults.photoURL;
      changed = true;
    }
    if (changed) {
      await user.save();
    }
  }

  await UserStats.findOrCreate({
    where: { userId },
    defaults: {
      userId,
      totalAttempts: 0,
      totalPlayTime: 0,
      bestTimes: {},
    },
  });

  return user;
}

class BattleService {
  // Créer une nouvelle bataille
  async createBattle(userId, mode = 'ranked', roomId = null, userProfile = {}) {
    try {
      await ensurePlayerProfile(userId, userProfile);
      let finalRoomId = roomId;
      if (mode === 'friendly' && !finalRoomId) {
        finalRoomId = generateRoomId();
      }
      
      const config = await getGameConfig();

      const battle = await Battle.create({
        player1: userId,
        player2: null,
        status: 'waiting',
        mode: mode,
        roomId: finalRoomId,
        player1Score: 0,
        player2Score: 0,
        player1Abandoned: false,
        player2Abandoned: false,
        startTime: null,
        endTime: null,
        totalTimeLimit: config.game_timer,
      });
      
      return battle;
    } catch (error) {
      console.error('Erreur lors de la création de la bataille:', error);
      throw error;
    }
  }
  
  // Trouver une bataille en attente (mode classé ou amical)
  async findWaitingBattle(userId, mode = 'ranked') {
    try {
      const battles = await Battle.findAll({
        where: {
          mode: mode,
          status: 'waiting',
          player2: null,
          player1: { [Op.ne]: userId },
        },
        limit: 10,
      });
      
      if (battles.length > 0) {
        return battles[0];
      }
      
      return null;
    } catch (error) {
      console.error('Erreur lors de la recherche d\'une bataille:', error);
      throw error;
    }
  }
  
  // Trouver une salle amicale par son ID
  async findFriendlyRoom(roomId, userId) {
    try {
      const battle = await Battle.findOne({
        where: {
          mode: 'friendly',
          roomId: roomId,
          status: 'waiting',
          player2: null,
          player1: { [Op.ne]: userId },
        },
      });
      
      return battle;
    } catch (error) {
      console.error('Erreur lors de la recherche de la salle amicale:', error);
      throw error;
    }
  }
  
  // Rejoindre une bataille
  async joinBattle(battleId, userId, userProfile = {}, allQuestions = null) {
    try {
      await ensurePlayerProfile(userId, userProfile);
      const battle = await Battle.findByPk(battleId);
      
      if (!battle) {
        throw new Error('Bataille non trouvée');
      }
      
      if (battle.status !== 'waiting') {
        throw new Error('La bataille n\'est pas en attente');
      }
      
      if (battle.player2 !== null) {
        throw new Error('La bataille a déjà un joueur 2');
      }
      
      if (battle.player1 === userId) {
        throw new Error('Vous ne pouvez pas rejoindre votre propre bataille');
      }
      
      // Charger les questions depuis la base de données si non fournies
      if (!allQuestions || allQuestions.length === 0) {
        allQuestions = await levelService.getAllLevels();
      }
      
      if (!allQuestions || allQuestions.length === 0) {
        throw new Error('Aucune question disponible dans la base de données');
      }
      
      // Mélanger les questions de manière déterministe
      const shuffledQuestions = shuffleQuestionsDeterministic(allQuestions, battleId.toString());
      
      if (shuffledQuestions.length === 0) {
        throw new Error('Aucune question après mélange');
      }
      
      // Convertir les questions en format JSON simplifié
      const questionsJson = shuffledQuestions.map(level => levelToDuelJson(level));
      
      // Mettre à jour la bataille
      battle.player2 = userId;
      battle.status = 'active';
      battle.questions = questionsJson;
      battle.player1QuestionIndex = 0;
      battle.player2QuestionIndex = 0;
      battle.player1AnsweredQuestions = [];
      battle.player2AnsweredQuestions = [];
      battle.player1PassedQuestions = [];
      battle.player2PassedQuestions = [];
      battle.startTime = new Date();
      await battle.save();
      
      return battle;
    } catch (error) {
      console.error('Erreur lors de la jonction à la bataille:', error);
      throw error;
    }
  }
  
  // Incrémenter le score et passer à la question suivante
  async incrementScoreAndNext(battleId, userId, questionIndex) {
    try {
      const battle = await Battle.findByPk(battleId);
      
      if (!battle) {
        throw new Error('Bataille non trouvée');
      }
      
      const isPlayer1 = battle.player1 === userId;
      const isPlayer2 = battle.player2 === userId;
      
      if (!isPlayer1 && !isPlayer2) {
        throw new Error('Vous n\'êtes pas un joueur de cette bataille');
      }
      
      const scoreField = isPlayer1 ? 'player1Score' : 'player2Score';
      const indexField = isPlayer1 ? 'player1QuestionIndex' : 'player2QuestionIndex';
      const answeredField = isPlayer1 ? 'player1AnsweredQuestions' : 'player2AnsweredQuestions';
      
      // Parser les questions répondues (peuvent être une string JSON)
      // Récupérer la valeur brute depuis Sequelize avec plusieurs méthodes de fallback
      let rawAnsweredField = battle.getDataValue(answeredField);
      if (rawAnsweredField === undefined) {
        rawAnsweredField = battle[answeredField];
      }
      if (rawAnsweredField === undefined) {
        rawAnsweredField = battle.dataValues?.[answeredField];
      }
      
      // Parser avec notre fonction utilitaire qui garantit un array
      let answeredQuestions = parseJsonField(rawAnsweredField);
      
      // Double vérification : s'assurer que c'est vraiment un array JavaScript natif
      // Si parseJsonField a échoué, créer un nouveau array vide
      if (!Array.isArray(answeredQuestions)) {
        console.error(`[incrementScoreAndNext] answeredQuestions n'est pas un array après parseJsonField!`, {
          type: typeof answeredQuestions,
          value: answeredQuestions,
          rawField: rawAnsweredField
        });
        answeredQuestions = [];
      }
      
      // Créer un nouveau array natif pour éviter tout problème de référence
      answeredQuestions = Array.from(answeredQuestions);
      
      // Vérification finale : s'assurer que .push() fonctionne
      if (typeof answeredQuestions.push !== 'function') {
        console.error(`[incrementScoreAndNext] answeredQuestions.push n'est pas une fonction!`, answeredQuestions);
        // Créer un nouveau array vide
        answeredQuestions = [];
      }
      
      // S'assurer que questionIndex n'est pas déjà dans la liste
      if (!answeredQuestions.includes(questionIndex)) {
        answeredQuestions.push(questionIndex);
      }
      
      // Parser les questions (peuvent être une string JSON)
      // Récupérer la valeur brute depuis Sequelize avec plusieurs méthodes de fallback
      let rawQuestions = battle.getDataValue('questions');
      if (rawQuestions === undefined) rawQuestions = battle.questions;
      if (rawQuestions === undefined) rawQuestions = battle.dataValues?.questions;
      
      // Parser avec notre fonction utilitaire qui garantit un array
      let questions = parseJsonField(rawQuestions);
      
      // Double vérification : s'assurer que c'est vraiment un array JavaScript natif
      if (!Array.isArray(questions)) {
        console.error(`[incrementScoreAndNext] questions n'est pas un array après parseJsonField!`, questions);
        questions = [];
      } else {
        questions = Array.from(questions);
      }
      
      if (questions.length === 0) {
        console.error(`[incrementScoreAndNext] questions est vide!`, questions);
        throw new Error('Aucune question disponible');
      }
      
      const allQuestionsAnswered = answeredQuestions.length >= questions.length;
      
      let nextIndex;
      if (allQuestionsAnswered) {
        // Si toutes les questions ont été répondues correctement, on peut revenir aux questions passées
        // Filtrer les questions passées pour exclure celles qui sont dans les questions répondues
        const passedField = isPlayer1 ? 'player1PassedQuestions' : 'player2PassedQuestions';
        
        // Récupérer la valeur brute depuis Sequelize avec plusieurs méthodes de fallback
        let rawPassedField = battle.getDataValue(passedField);
        if (rawPassedField === undefined) rawPassedField = battle[passedField];
        if (rawPassedField === undefined) rawPassedField = battle.dataValues?.[passedField];
        
        let passedQuestions = parseJsonField(rawPassedField);
        
        // Double vérification : s'assurer que c'est vraiment un array JavaScript natif
        if (!Array.isArray(passedQuestions)) {
          console.error(`[incrementScoreAndNext] passedQuestions n'est pas un array après parseJsonField!`, passedQuestions);
          passedQuestions = [];
        } else {
          passedQuestions = Array.from(passedQuestions);
        }
        
        const availablePassedQuestions = passedQuestions.filter(idx => !answeredQuestions.includes(idx));
        
        if (availablePassedQuestions.length > 0) {
          // Prendre la première question passée qui n'a pas encore été répondue correctement
          nextIndex = availablePassedQuestions[0];
        } else {
          // Toutes les questions passées ont été répondues, prendre la prochaine question non répondue
          nextIndex = (questionIndex + 1) % questions.length;
          let attempts = 0;
          while (answeredQuestions.includes(nextIndex) && attempts < questions.length) {
            nextIndex = (nextIndex + 1) % questions.length;
            attempts++;
          }
        }
      } else {
        // Il reste des questions non répondues, trouver la prochaine question non répondue
        nextIndex = (questionIndex + 1) % questions.length;
        let attempts = 0;
        while (answeredQuestions.includes(nextIndex) && attempts < questions.length) {
          nextIndex = (nextIndex + 1) % questions.length;
          attempts++;
        }
      }
      
      // Mettre à jour le score et l'index
      battle[scoreField] = (battle[scoreField] || 0) + 1;
      battle[indexField] = nextIndex;
      // S'assurer que answeredQuestions est bien un array avant de sauvegarder
      if (!Array.isArray(answeredQuestions)) {
        console.error(`[incrementScoreAndNext] answeredQuestions n'est pas un array avant sauvegarde!`, answeredQuestions);
        answeredQuestions = [];
      }
      battle[answeredField] = answeredQuestions;
      await battle.save();
      
      console.log(`[incrementScoreAndNext] Bataille sauvegardée: score=${battle[scoreField]}, index=${battle[indexField]}, answeredQuestions=${JSON.stringify(answeredQuestions)}`);
      
      // Recharger la bataille depuis la base de données pour s'assurer que les données sont à jour
      await battle.reload();
      
      return battle;
    } catch (error) {
      console.error('Erreur lors de la mise à jour du score:', error);
      throw error;
    }
  }
  
  // Passer à la question suivante (sans incrémenter le score)
  async nextQuestion(battleId, userId) {
    try {
      const battle = await Battle.findByPk(battleId);
      
      if (!battle) {
        throw new Error('Bataille non trouvée');
      }
      
      const isPlayer1 = battle.player1 === userId;
      const isPlayer2 = battle.player2 === userId;
      
      if (!isPlayer1 && !isPlayer2) {
        throw new Error('Vous n\'êtes pas un joueur de cette bataille');
      }
      
      const indexField = isPlayer1 ? 'player1QuestionIndex' : 'player2QuestionIndex';
      const answeredField = isPlayer1 ? 'player1AnsweredQuestions' : 'player2AnsweredQuestions';
      const passedField = isPlayer1 ? 'player1PassedQuestions' : 'player2PassedQuestions';
      const currentIndex = battle[indexField] || 0;
      
      // Parser les champs JSON (peuvent être des strings JSON)
      // Récupérer les valeurs brutes depuis Sequelize avec plusieurs méthodes de fallback
      let rawAnsweredField = battle.getDataValue(answeredField);
      if (rawAnsweredField === undefined) rawAnsweredField = battle[answeredField];
      if (rawAnsweredField === undefined) rawAnsweredField = battle.dataValues?.[answeredField];
      
      let rawPassedField = battle.getDataValue(passedField);
      if (rawPassedField === undefined) rawPassedField = battle[passedField];
      if (rawPassedField === undefined) rawPassedField = battle.dataValues?.[passedField];
      
      let rawQuestions = battle.getDataValue('questions');
      if (rawQuestions === undefined) rawQuestions = battle.questions;
      if (rawQuestions === undefined) rawQuestions = battle.dataValues?.questions;
      
      // Parser avec notre fonction utilitaire qui garantit des arrays
      let answeredQuestions = parseJsonField(rawAnsweredField);
      let passedQuestions = parseJsonField(rawPassedField);
      let questions = parseJsonField(rawQuestions);
      
      // Double vérification : s'assurer que ce sont vraiment des arrays JavaScript natifs
      if (!Array.isArray(answeredQuestions)) {
        console.error(`[nextQuestion] answeredQuestions n'est pas un array après parseJsonField!`, answeredQuestions);
        answeredQuestions = [];
      } else {
        answeredQuestions = Array.from(answeredQuestions);
      }
      
      if (!Array.isArray(passedQuestions)) {
        console.error(`[nextQuestion] passedQuestions n'est pas un array après parseJsonField!`, passedQuestions);
        passedQuestions = [];
      } else {
        passedQuestions = Array.from(passedQuestions);
      }
      
      if (!Array.isArray(questions)) {
        console.error(`[nextQuestion] questions n'est pas un array après parseJsonField!`, questions);
        questions = [];
      } else {
        questions = Array.from(questions);
      }
      
      // Vérification finale : s'assurer que .push() fonctionne
      if (typeof passedQuestions.push !== 'function') {
        console.error(`[nextQuestion] passedQuestions.push n'est pas une fonction!`, passedQuestions);
        passedQuestions = [];
      }
      
      if (questions.length === 0) {
        console.error(`[nextQuestion] questions est vide!`, questions);
        throw new Error('Aucune question disponible');
      }
      
      // Ajouter la question actuelle à la liste des questions passées
      if (!passedQuestions.includes(currentIndex)) {
        passedQuestions.push(currentIndex);
      }
      
      // Vérifier si toutes les questions ont été répondues correctement
      const allQuestionsAnswered = answeredQuestions.length >= questions.length;
      
      // Trouver la prochaine question
      let nextIndex;
      
      if (allQuestionsAnswered) {
        // Si toutes les questions ont été répondues correctement, on peut revenir aux questions passées
        // Filtrer les questions passées pour exclure celles qui sont dans les questions répondues
        const availablePassedQuestions = passedQuestions.filter(idx => !answeredQuestions.includes(idx));
        
        if (availablePassedQuestions.length > 0) {
          // Prendre la première question passée qui n'a pas encore été répondue correctement
          nextIndex = availablePassedQuestions[0];
        } else {
          // Toutes les questions passées ont été répondues, prendre la prochaine question non répondue
          nextIndex = (currentIndex + 1) % questions.length;
          let attempts = 0;
          while (answeredQuestions.includes(nextIndex) && attempts < questions.length) {
            nextIndex = (nextIndex + 1) % questions.length;
            attempts++;
          }
        }
      } else {
        // Il reste des questions non répondues, trouver la prochaine question non répondue
        nextIndex = (currentIndex + 1) % questions.length;
        let attempts = 0;
        
        while (answeredQuestions.includes(nextIndex) && attempts < questions.length) {
          nextIndex = (nextIndex + 1) % questions.length;
          attempts++;
        }
      }
      
      // Mettre à jour l'index et la liste des questions passées
      battle[indexField] = nextIndex;
      // S'assurer que passedQuestions est bien un array avant de sauvegarder
      if (!Array.isArray(passedQuestions)) {
        console.error(`[nextQuestion] passedQuestions n'est pas un array avant sauvegarde!`, passedQuestions);
        passedQuestions = [];
      }
      battle[passedField] = passedQuestions;
      await battle.save();
      
      console.log(`[nextQuestion] Bataille sauvegardée: index=${battle[indexField]}, passedQuestions=${JSON.stringify(passedQuestions)}`);
      
      // Recharger la bataille depuis la base de données pour s'assurer que les données sont à jour
      await battle.reload();
      
      return battle;
    } catch (error) {
      console.error('Erreur lors du passage à la question suivante:', error);
      throw error;
    }
  }
  
  // Abandonner une bataille
  async abandonBattle(battleId, userId) {
    try {
      const battle = await Battle.findByPk(battleId);
      
      if (!battle) {
        throw new Error('Bataille non trouvée');
      }
      
      if (battle.status === 'finished') {
        return battle;
      }
      
      const isPlayer1 = battle.player1 === userId;
      const isPlayer2 = battle.player2 === userId;
      
      if (!isPlayer1 && !isPlayer2) {
        throw new Error('Vous n\'êtes pas un joueur de cette bataille');
      }
      
      // Marquer l'abandon
      if (isPlayer1) {
        battle.player1Abandoned = true;
      } else {
        battle.player2Abandoned = true;
      }
      
      await battle.save();
      
      // Appeler finishBattle pour calculer les trophées
      // finishBattle gère automatiquement les abandons et applique les trophées
      await this.finishBattle(battleId);
      
      // Récupérer la bataille mise à jour
      const updatedBattle = await Battle.findByPk(battleId);
      return updatedBattle;
    } catch (error) {
      console.error('Erreur lors de l\'abandon de la bataille:', error);
      throw error;
    }
  }
  
  // Terminer une bataille et calculer le résultat
  async finishBattle(battleId) {
    try {
      const battle = await Battle.findByPk(battleId);
      const { User } = require('../models');
      
      if (!battle) {
        throw new Error('Bataille non trouvée');
      }
      
      if (battle.status === 'finished') {
        return {
          winner: battle.winner,
          result: battle.result,
          player1Score: battle.player1Score,
          player2Score: battle.player2Score,
          mode: battle.mode,
          trophyChanges: battle.trophyChanges || {},
        };
      }
      
      const player1Score = battle.player1Score || 0;
      const player2Score = battle.player2Score || 0;
      const player1Abandoned = battle.player1Abandoned || false;
      const player2Abandoned = battle.player2Abandoned || false;
      
      let winner;
      let result;
      
      // Gérer les abandons
      if (player1Abandoned && !player2Abandoned) {
        winner = battle.player2;
        result = 'player2_win';
      } else if (player2Abandoned && !player1Abandoned) {
        winner = battle.player1;
        result = 'player1_win';
      } else if (player1Abandoned && player2Abandoned) {
        winner = 'draw';
        result = 'draw';
      } else {
        // Pas d'abandon, comparer les scores
        if (player1Score > player2Score) {
          winner = battle.player1;
          result = 'player1_win';
        } else if (player2Score > player1Score) {
          winner = battle.player2;
          result = 'player2_win';
        } else {
          winner = 'draw';
          result = 'draw';
        }
      }
      
      // Calculer les changements de trophées selon le mode
      const trophyChanges = {};
      
      if (battle.mode === 'ranked') {
        const config = await getGameConfig();

        // Mode classé : trophées selon le résultat
        if (result === 'draw') {
          // Match null
          trophyChanges[battle.player1] = config.trophies_draw;
          trophyChanges[battle.player2] = config.trophies_draw;
        } else {
          // Il y a un gagnant et un perdant
          const winnerId = winner;
          const loserId = winner === battle.player1 ? battle.player2 : battle.player1;
          
          // Gagnant
          trophyChanges[winnerId] = config.trophies_win;
          
          // Perdant
          // Récupérer les trophées actuels du perdant
          const loser = await User.findByPk(loserId);
          if (loser) {
            const currentTrophies = loser.trophies || 0;
            let newTrophies = currentTrophies - config.trophies_loss;
            
            // Règle spéciale : si le joueur a moins de trophies_loss mais plus de 10, il tombe à 0
            if (currentTrophies > 0 && currentTrophies < config.trophies_loss) {
              newTrophies = 0;
            } else {
              // Sinon, minimum 0
              newTrophies = Math.max(0, newTrophies);
            }
            
            trophyChanges[loserId] = newTrophies - currentTrophies; // Changement (négatif)
          } else {
            // Si l'utilisateur n'existe pas, pas de changement
            trophyChanges[loserId] = 0;
          }
        }
      } else {
        // Mode amical : pas de trophées
        trophyChanges[battle.player1] = 0;
        trophyChanges[battle.player2] = 0;
      }
      
      // Appliquer les changements de trophées
      for (const [userId, change] of Object.entries(trophyChanges)) {
        if (change !== 0) {
          const user = await User.findByPk(userId);
          if (user) {
            const currentTrophies = user.trophies || 0;
            let newTrophies = currentTrophies + change;
            
            // S'assurer que les trophées ne sont jamais négatifs
            newTrophies = Math.max(0, newTrophies);
            
            user.trophies = newTrophies;
            await user.save();
            
            console.log(`Trophées mis à jour pour ${userId}: ${currentTrophies} -> ${newTrophies} (changement: ${change > 0 ? '+' : ''}${change})`);
          }
        }
      }
      
      // Mettre à jour la bataille
      battle.status = 'finished';
      battle.winner = winner;
      battle.result = result;
      battle.endTime = new Date();
      battle.trophyChanges = trophyChanges;
      await battle.save();
      
      return {
        winner: winner,
        result: result,
        player1Score: player1Score,
        player2Score: player2Score,
        mode: battle.mode,
        trophyChanges: trophyChanges,
      };
    } catch (error) {
      console.error('Erreur lors de la finalisation de la bataille:', error);
      throw error;
    }
  }
  
  // Obtenir une bataille
  async getBattle(battleId) {
    try {
      const battle = await Battle.findByPk(battleId);
      return battle;
    } catch (error) {
      console.error('Erreur lors de la récupération de la bataille:', error);
      throw error;
    }
  }
  
  // Supprimer une bataille
  async deleteBattle(battleId, userId) {
    try {
      const battle = await Battle.findByPk(battleId);
      
      if (!battle) {
        return { status: 'not_found' };
      }
      
      // Vérifier que la bataille est en attente et que l'utilisateur est le créateur
      if (battle.status === 'waiting' && battle.player1 === userId && battle.player2 === null) {
        await battle.destroy();
        return { status: 'deleted' };
      }
      
      return { status: 'forbidden' };
    } catch (error) {
      console.error('Erreur lors de la suppression de la bataille:', error);
      throw error;
    }
  }
  
}

// Nettoyer les anciennes batailles
async function cleanupOldBattles() {
  try {
    const now = new Date();
    const fiveMinutesAgo = new Date(now.getTime() - 5 * 60 * 1000);
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    
    // Supprimer les batailles en attente vides de plus de 5 minutes
    await Battle.destroy({
      where: {
        status: 'waiting',
        player2: null,
        createdAt: { [Op.lt]: fiveMinutesAgo },
      },
    });
    
    // Supprimer les batailles terminées de plus de 1 heure
    await Battle.destroy({
      where: {
        status: 'finished',
        endTime: { [Op.lt]: oneHourAgo },
      },
    });
    
    console.log('Nettoyage des anciennes batailles terminé');
  } catch (error) {
    console.error('Erreur lors du nettoyage des anciennes batailles:', error);
  }
}

const battleService = new BattleService();
battleService.cleanupOldBattles = cleanupOldBattles;

module.exports = battleService;

