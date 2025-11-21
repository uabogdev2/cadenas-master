require('dotenv').config();
const { sequelize } = require('../config/database');
const { Admin } = require('../models');

async function fixAdminPermissions() {
  try {
    await sequelize.authenticate();
    console.log('Connexion à la base de données réussie');

    // Récupérer tous les admins
    const admins = await Admin.findAll();

    if (admins.length === 0) {
      console.log('Aucun admin trouvé dans la base de données');
      return;
    }

    console.log(`Trouvé ${admins.length} admin(s)`);

    // Trouver le premier admin (le plus ancien)
    const firstAdmin = await Admin.findOne({
      order: [['createdAt', 'ASC']],
      limit: 1,
    });

    const firstAdminId = firstAdmin ? firstAdmin.userId : null;
    const isOnlyAdmin = admins.length === 1;

    // Permissions de base qui doivent TOUJOURS être true pour tous les admins
    const requiredPermissions = {
      manageUsers: true,
      manageLevels: true,
      viewStats: true,
      manageBattles: true,
    };

    // Corriger les permissions de chaque admin
    for (const admin of admins) {
      const isFirstAdmin = isOnlyAdmin || admin.userId === firstAdminId;
      let needsUpdate = false;

      console.log(`\nTraitement de l'admin ${admin.userId}...`);

      // Vérifier et corriger les permissions
      if (!admin.permissions || typeof admin.permissions !== 'object') {
        console.log(`  - Permissions manquantes, initialisation complète`);
        admin.permissions = {
          ...requiredPermissions,
          manageAdmins: isFirstAdmin,
        };
        needsUpdate = true;
      } else {
        // Corriger les permissions de base
        for (const [key, requiredValue] of Object.entries(requiredPermissions)) {
          if (admin.permissions[key] !== true) {
            console.log(`  - Permission ${key}: ${admin.permissions[key]} -> true`);
            admin.permissions[key] = true;
            needsUpdate = true;
          }
        }

        // Gestion de manageAdmins
        if (isFirstAdmin) {
          if (!admin.permissions.manageAdmins) {
            console.log(`  - Premier admin: manageAdmins -> true`);
            admin.permissions.manageAdmins = true;
            needsUpdate = true;
          }
        } else {
          if (admin.permissions.manageAdmins === undefined) {
            console.log(`  - manageAdmins non défini -> false`);
            admin.permissions.manageAdmins = false;
            needsUpdate = true;
          }
        }
      }

      // Sauvegarder si nécessaire
      if (needsUpdate) {
        await admin.save();
        console.log(`  ✓ Permissions mises à jour:`, JSON.stringify(admin.permissions, null, 2));
      } else {
        console.log(`  ✓ Permissions déjà correctes`);
      }
    }

    console.log('\n✓ Correction des permissions terminée');
  } catch (error) {
    console.error('Erreur lors de la correction des permissions:', error);
    process.exit(1);
  } finally {
    await sequelize.close();
  }
}

fixAdminPermissions();

