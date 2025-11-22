const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const GameConfig = sequelize.define('GameConfig', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
  },
  trophies_win: {
    type: DataTypes.INTEGER,
    defaultValue: 100,
    allowNull: false,
  },
  trophies_loss: {
    type: DataTypes.INTEGER,
    defaultValue: 100,
    allowNull: false,
  },
  trophies_draw: {
    type: DataTypes.INTEGER,
    defaultValue: 10,
    allowNull: false,
  },
  game_timer: {
    type: DataTypes.INTEGER,
    defaultValue: 300, // seconds
    allowNull: false,
  },
  question_timer: {
    type: DataTypes.INTEGER,
    defaultValue: 30, // seconds
    allowNull: false,
  },
  min_version_android: {
    type: DataTypes.STRING,
    defaultValue: '1.0.0',
    allowNull: false,
  },
  min_version_ios: {
    type: DataTypes.STRING,
    defaultValue: '1.0.0',
    allowNull: false,
  },
  force_update: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    allowNull: false,
  },
  maintenance_mode: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    allowNull: false,
  }
}, {
  tableName: 'game_configs',
  timestamps: true,
});

module.exports = GameConfig;
