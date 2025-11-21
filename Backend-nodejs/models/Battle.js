const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const User = require('./User');

const Battle = sequelize.define('Battle', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
  },
  player1: {
    type: DataTypes.STRING,
    allowNull: false,
    references: {
      model: User,
      key: 'id',
    },
  },
  player2: {
    type: DataTypes.STRING,
    allowNull: true,
    references: {
      model: User,
      key: 'id',
    },
  },
  status: {
    type: DataTypes.ENUM('waiting', 'active', 'finished'),
    allowNull: false,
    defaultValue: 'waiting',
  },
  mode: {
    type: DataTypes.ENUM('ranked', 'friendly'),
    allowNull: false,
    defaultValue: 'ranked',
  },
  roomId: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  player1Score: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },
  player2Score: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },
  player1Abandoned: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: false,
  },
  player2Abandoned: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: false,
  },
  player1QuestionIndex: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },
  player2QuestionIndex: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },
  player1AnsweredQuestions: {
    type: DataTypes.JSON,
    allowNull: false,
    defaultValue: [],
  },
  player2AnsweredQuestions: {
    type: DataTypes.JSON,
    allowNull: false,
    defaultValue: [],
  },
  questions: {
    type: DataTypes.JSON,
    allowNull: false,
    defaultValue: [],
  },
  startTime: {
    type: DataTypes.DATE,
    allowNull: true,
  },
  endTime: {
    type: DataTypes.DATE,
    allowNull: true,
  },
  totalTimeLimit: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 300, // 5 minutes en secondes
  },
  winner: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  result: {
    type: DataTypes.ENUM('player1_win', 'player2_win', 'draw'),
    allowNull: true,
  },
  trophyChanges: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: {},
  },
  player1PassedQuestions: {
    type: DataTypes.JSON,
    allowNull: false,
    defaultValue: [],
  },
  player2PassedQuestions: {
    type: DataTypes.JSON,
    allowNull: false,
    defaultValue: [],
  },
}, {
  tableName: 'battles',
  timestamps: true,
  createdAt: 'createdAt',
  updatedAt: 'updatedAt',
  indexes: [
    {
      fields: ['status', 'mode', 'player2'],
    },
    {
      fields: ['roomId', 'status'],
    },
    {
      fields: ['player1', 'status'],
    },
    {
      fields: ['player2', 'status'],
    },
    {
      fields: ['createdAt'],
    },
  ],
});

// Définir les associations
Battle.belongsTo(User, { foreignKey: 'player1', as: 'player1User' });
Battle.belongsTo(User, { foreignKey: 'player2', as: 'player2User' });

module.exports = Battle;

