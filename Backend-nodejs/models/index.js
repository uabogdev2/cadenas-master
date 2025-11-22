const User = require('./User');
const Level = require('./Level');
const UserProgress = require('./UserProgress');
const UserStats = require('./UserStats');
const UnlockedHints = require('./UnlockedHints');
const Battle = require('./Battle');
const Admin = require('./Admin');
const GameConfig = require('./GameConfig');

// Définir toutes les associations
User.hasMany(UserProgress, { foreignKey: 'userId', as: 'progress' });
User.hasOne(UserStats, { foreignKey: 'userId', as: 'stats' });
User.hasMany(UnlockedHints, { foreignKey: 'userId', as: 'unlockedHints' });
User.hasMany(Battle, { foreignKey: 'player1', as: 'battlesAsPlayer1' });
User.hasMany(Battle, { foreignKey: 'player2', as: 'battlesAsPlayer2' });
User.hasOne(Admin, { foreignKey: 'userId', as: 'admin' });

module.exports = {
  User,
  Level,
  UserProgress,
  UserStats,
  UnlockedHints,
  Battle,
  Admin,
  GameConfig,
};

