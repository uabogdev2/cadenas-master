const apiClient = require('./apiClient');

module.exports = {
  createBattle(token, payload) {
    return apiClient.post('/api/battles/create', token, payload);
  },
  matchmakingRanked(token) {
    return apiClient.post('/api/battles/matchmaking/ranked', token, {});
  },
  findBattle(token, mode = 'ranked') {
    return apiClient.get('/api/battles/find', token, { mode });
  },
  findFriendlyRoom(token, roomId) {
    return apiClient.get(`/api/battles/find-friendly/${roomId}`, token);
  },
  joinBattle(token, battleId) {
    return apiClient.post(`/api/battles/join/${battleId}`, token, {});
  },
  incrementScore(token, battleId, payload) {
    return apiClient.post(`/api/battles/${battleId}/score`, token, payload);
  },
  nextQuestion(token, battleId) {
    return apiClient.post(`/api/battles/${battleId}/next`, token, {});
  },
  abandonBattle(token, battleId) {
    return apiClient.post(`/api/battles/${battleId}/abandon`, token, {});
  },
  finishBattle(token, battleId) {
    return apiClient.post(`/api/battles/${battleId}/finish`, token, {});
  },
  deleteBattle(token, battleId) {
    return apiClient.delete(`/api/battles/${battleId}`, token);
  },
};

