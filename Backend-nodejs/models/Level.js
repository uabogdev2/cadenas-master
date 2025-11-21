const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Level = sequelize.define('Level', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    allowNull: false,
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  instruction: {
    type: DataTypes.TEXT,
    allowNull: false,
  },
  code: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  codeLength: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },
  pointsReward: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 10,
  },
  isLocked: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: true,
  },
  timeLimit: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 60,
  },
  additionalHints: {
    type: DataTypes.JSON,
    allowNull: false,
    defaultValue: [],
  },
  hintCost: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 100,
  },
}, {
  tableName: 'levels',
  timestamps: true,
  createdAt: 'createdAt',
  updatedAt: 'updatedAt',
});

module.exports = Level;

