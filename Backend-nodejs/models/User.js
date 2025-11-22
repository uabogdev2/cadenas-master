const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const User = sequelize.define('User', {
  id: {
    type: DataTypes.STRING,
    primaryKey: true,
    allowNull: false,
  },
  displayName: {
    type: DataTypes.STRING,
    allowNull: false,
    defaultValue: 'Joueur',
  },
  email: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  photoURL: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  isAnonymous: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: false,
  },
  points: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 500,
  },
  completedLevels: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },
  fcmToken: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  trophies: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },
}, {
  tableName: 'users',
  timestamps: true,
  createdAt: 'createdAt',
  updatedAt: 'updatedAt',
});

module.exports = User;

