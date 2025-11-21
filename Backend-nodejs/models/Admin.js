const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const User = require('./User');

const Admin = sequelize.define('Admin', {
  userId: {
    type: DataTypes.STRING,
    primaryKey: true,
    allowNull: false,
    references: {
      model: User,
      key: 'id',
    },
  },
  isAdmin: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: true,
  },
  permissions: {
    type: DataTypes.JSON,
    allowNull: false,
      defaultValue: {
        manageUsers: true,
        manageLevels: true,
        viewStats: true,
        manageAdmins: false,
        manageBattles: true,
      },
  },
  createdAt: {
    type: DataTypes.DATE,
    allowNull: false,
    defaultValue: DataTypes.NOW,
  },
  updatedAt: {
    type: DataTypes.DATE,
    allowNull: false,
    defaultValue: DataTypes.NOW,
  },
}, {
  tableName: 'admins',
  timestamps: true,
});

// Définir les associations
Admin.belongsTo(User, { foreignKey: 'userId', as: 'user' });

module.exports = Admin;

