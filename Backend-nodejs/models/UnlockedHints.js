const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const User = require('./User');

const UnlockedHints = sequelize.define('UnlockedHints', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
  },
  userId: {
    type: DataTypes.STRING,
    allowNull: false,
    references: {
      model: User,
      key: 'id',
    },
  },
  levelId: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },
  indices: {
    type: DataTypes.JSON,
    allowNull: false,
    defaultValue: [],
  },
}, {
  tableName: 'unlocked_hints',
  timestamps: true,
  createdAt: 'createdAt',
  updatedAt: 'updatedAt',
  indexes: [
    {
      unique: true,
      fields: ['userId', 'levelId'],
    },
  ],
});

// Définir les associations
UnlockedHints.belongsTo(User, { foreignKey: 'userId', as: 'user' });

module.exports = UnlockedHints;

