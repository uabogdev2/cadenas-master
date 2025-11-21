// Script pour créer un administrateur
// Usage: node scripts/createAdmin.js <userId> [permissions]

const { Admin, User } = require('../models');
const { sequelize } = require('../config/database');
require('dotenv').config();

async function createAdmin() {
  try {
    // Récupérer l'userId depuis les arguments de la ligne de commande
    const userId = process.argv[2];
    const permissionsArg = process.argv[3];

    if (!userId) {
      console.error('Usage: node scripts/createAdmin.js <userId> [permissions]');
      console.error('Exemple: node scripts/createAdmin.js abc123');
      console.error('Exemple avec permissions: node scripts/createAdmin.js abc123 "{\\"manageUsers\\":true,\\"manageLevels\\":true}"');
      process.exit(1);
    }

    // Tester la connexion à la base de données
    await sequelize.authenticate();
    console.log('Connexion à la base de données réussie');

    // Synchroniser les modèles
    await sequelize.sync({ alter: true });
    console.log('Modèles synchronisés');

    // Vérifier si l'utilisateur existe
    const user = await User.findByPk(userId);
    if (!user) {
      console.error(`Erreur: L'utilisateur avec l'ID "${userId}" n'existe pas dans la base de données`);
      console.error('Créez d\'abord l\'utilisateur via l\'API /api/users/initialize');
      process.exit(1);
    }

    // Vérifier si l'utilisateur est déjà admin
    const existingAdmin = await Admin.findByPk(userId);
    if (existingAdmin) {
      console.log(`L'utilisateur "${userId}" est déjà administrateur`);
      console.log('Permissions actuelles:', existingAdmin.permissions);
      
      // Mettre à jour les permissions si fournies
      if (permissionsArg) {
        try {
          const newPermissions = JSON.parse(permissionsArg);
          existingAdmin.permissions = { ...existingAdmin.permissions, ...newPermissions };
          await existingAdmin.save();
          console.log('Permissions mises à jour:', existingAdmin.permissions);
        } catch (error) {
          console.error('Erreur lors du parsing des permissions:', error);
        }
      }
      
      process.exit(0);
    }

    // Parser les permissions si fournies
    let permissions = {
      manageUsers: true,
      manageLevels: true,
      viewStats: true,
      manageBattles: true,
    };

    if (permissionsArg) {
      try {
        const customPermissions = JSON.parse(permissionsArg);
        permissions = { ...permissions, ...customPermissions };
      } catch (error) {
        console.error('Erreur lors du parsing des permissions, utilisation des permissions par défaut:', error);
      }
    }

    // Créer l'administrateur
    const admin = await Admin.create({
      userId: userId,
      isAdmin: true,
      permissions: permissions,
    });

    console.log('✅ Administrateur créé avec succès !');
    console.log('User ID:', admin.userId);
    console.log('Permissions:', admin.permissions);
    console.log('\nL\'utilisateur peut maintenant accéder aux routes admin avec son token Firebase');

    process.exit(0);
  } catch (error) {
    console.error('Erreur lors de la création de l\'administrateur:', error);
    process.exit(1);
  }
}

createAdmin();

