const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const User = require('./User');

const UserStats = sequelize.define('UserStats', {
  userId: {
    type: DataTypes.STRING,
    primaryKey: true,
    allowNull: false,
    references: {
      model: User,
      key: 'id',
    },
  },
  totalAttempts: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },
  totalPlayTime: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },
  bestTimes: {
    type: DataTypes.JSON,
    allowNull: false,
    defaultValue: {},
  },
}, {
  tableName: 'user_stats',
  timestamps: true,
  createdAt: 'createdAt',
  updatedAt: 'updatedAt',
});

// Définir les associations
UserStats.belongsTo(User, { foreignKey: 'userId', as: 'user' });

module.exports = UserStats;

