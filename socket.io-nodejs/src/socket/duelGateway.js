const { Server } = require('socket.io');
const { verifyToken, getFirebaseProjectInfo } = require('../config/firebase');
const battleGateway = require('../services/battleGateway');
const logger = require('../config/logger');

const userSockets = new Map(); // userId -> socket
const battleRooms = new Map(); // battleId -> Set<userId>

function getToken(socket) {
  return (
    socket.handshake?.auth?.token ||
    socket.handshake?.headers?.authorization?.replace('Bearer ', '') ||
    null
  );
}

function joinBattleRoom(socket, battleId) {
  const room = `battle:${battleId}`;
  socket.join(room);

  if (!battleRooms.has(battleId)) {
    battleRooms.set(battleId, new Set());
  }
  battleRooms.get(battleId).add(socket.data.user.id);
  return room;
}

function leaveAllBattles(socket) {
  const rooms = Array.from(socket.rooms);
  rooms.forEach((room) => {
    if (room.startsWith('battle:')) {
      socket.leave(room);
      const battleId = room.replace('battle:', '');
      const set = battleRooms.get(battleId);
      if (set) {
        set.delete(socket.data.user.id);
        if (set.size === 0) {
          battleRooms.delete(battleId);
        }
      }
    }
  });
}

function emitError(socket, action, error) {
  const payload = {
    success: false,
    action,
    error: error.message || 'Erreur interne',
  };
  if (error.details) {
    payload.details = error.details;
  }
  socket.emit('error', payload);
}

function safeExecute(socket, action, handler) {
  handler().catch((error) => {
    logger.error(`[socket] ${action} échoue`, {
      userId: socket.data.user.id,
      error: error.message,
    });
    emitError(socket, action, error);
  });
}

function initSocketServer(server, options = {}) {
  const io = new Server(server, {
    transports: ['websocket', 'polling'],
    cors: options.cors || { origin: '*' },
    allowEIO3: true,
  });

  io.use(async (socket, next) => {
    try {
      const token = getToken(socket);
      if (!token) {
        throw new Error('Token manquant dans auth.token');
      }

      const decoded = await verifyToken(token);
      socket.data.user = {
        id: decoded.uid,
        email: decoded.email,
        name: decoded.name,
      };
      socket.data.token = token;
      logger.info('[socket] auth OK', {
        userId: decoded.uid,
        project: getFirebaseProjectInfo(),
      });
      next();
    } catch (error) {
      logger.error('[socket] échec authentification', {
        reason: error.message,
        stack: error.stack,
        project: getFirebaseProjectInfo(),
      });
      const authError = new Error('Authentification Firebase requise');
      authError.data = {
        reason: error.message,
        project: getFirebaseProjectInfo(),
      };
      next(authError);
    }
  });

  io.on('connection', (socket) => {
    const { id: userId } = socket.data.user;
    logger.info('[socket] utilisateur connecté', { userId, socketId: socket.id });

    userSockets.set(userId, socket);
    socket.join(`user:${userId}`);
    socket.emit('ready', { success: true, userId });

    socket.on('disconnect', (reason) => {
      logger.info('[socket] utilisateur déconnecté', { userId, reason });
      userSockets.delete(userId);
      leaveAllBattles(socket);
    });

    socket.on('ping', (payload) => {
      socket.emit('pong', payload || 'pong');
    });

    socket.on('createBattle', (payload = {}) => {
      safeExecute(socket, 'createBattle', async () => {
        const response = await battleGateway.createBattle(socket.data.token, payload);
        if (response?.success && response.battle?.id) {
          joinBattleRoom(socket, response.battle.id);
        }
        socket.emit('battleCreated', response);
      });
    });

    socket.on('matchmakingRanked', () => {
      safeExecute(socket, 'matchmakingRanked', async () => {
        const response = await battleGateway.matchmakingRanked(socket.data.token);
        if (!response?.success || !response?.battle?.id) {
          socket.emit('battleCreated', response);
          return;
        }

        const battleId = response.battle.id;
        joinBattleRoom(socket, battleId);

        if (response.joined) {
          io.to(`battle:${battleId}`).emit('battleStarted', response);
        } else {
          socket.emit('battleCreated', response);
        }
      });
    });

    socket.on('findBattle', (mode = 'ranked') => {
      safeExecute(socket, 'findBattle', async () => {
        const response = await battleGateway.findBattle(socket.data.token, mode);
        socket.emit('battleFound', response);
      });
    });

    socket.on('findFriendlyRoom', (payload = {}) => {
      safeExecute(socket, 'findFriendlyRoom', async () => {
        const response = await battleGateway.findFriendlyRoom(
          socket.data.token,
          payload.roomId
        );
        socket.emit('friendlyRoomFound', response);
      });
    });

    socket.on('joinBattle', (payload = {}) => {
      safeExecute(socket, 'joinBattle', async () => {
        const { battleId } = payload;
        if (!battleId) throw new Error('battleId requis');
        const response = await battleGateway.joinBattle(socket.data.token, battleId);
        joinBattleRoom(socket, battleId);
        io.to(`battle:${battleId}`).emit('battleStarted', response);
      });
    });

    socket.on('incrementScoreAndNext', (payload = {}) => {
      safeExecute(socket, 'incrementScoreAndNext', async () => {
        const { battleId, questionIndex } = payload;
        if (!battleId) throw new Error('battleId requis');
        const response = await battleGateway.incrementScore(
          socket.data.token,
          battleId,
          { questionIndex }
        );
        io.to(`battle:${battleId}`).emit('battleUpdated', response);
      });
    });

    socket.on('nextQuestion', (payload = {}) => {
      safeExecute(socket, 'nextQuestion', async () => {
        const { battleId } = payload;
        if (!battleId) throw new Error('battleId requis');
        const response = await battleGateway.nextQuestion(socket.data.token, battleId);
        io.to(`battle:${battleId}`).emit('battleUpdated', response);
      });
    });

    socket.on('abandonBattle', (payload = {}) => {
      safeExecute(socket, 'abandonBattle', async () => {
        const { battleId } = payload;
        if (!battleId) throw new Error('battleId requis');
        const response = await battleGateway.abandonBattle(socket.data.token, battleId);
        io.to(`battle:${battleId}`).emit('battleFinished', response);
      });
    });

    socket.on('finishBattle', (payload = {}) => {
      safeExecute(socket, 'finishBattle', async () => {
        const { battleId } = payload;
        if (!battleId) throw new Error('battleId requis');
        const response = await battleGateway.finishBattle(socket.data.token, battleId);
        io.to(`battle:${battleId}`).emit('battleFinished', response);
      });
    });

    socket.on('deleteBattle', (payload = {}) => {
      safeExecute(socket, 'deleteBattle', async () => {
        const { battleId } = payload;
        if (!battleId) throw new Error('battleId requis');
        const response = await battleGateway.deleteBattle(socket.data.token, battleId);
        socket.emit('battleDeleted', response);
      });
    });
  });

  return io;
}

module.exports = {
  initSocketServer,
  userSockets,
  battleRooms,
};

