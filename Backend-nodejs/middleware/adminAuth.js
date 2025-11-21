const { authenticateFirebase } = require('./auth');
const { Admin } = require('../models');

// Middleware pour vérifier si l'utilisateur est administrateur
async function checkAdmin(req, res, next) {
  try {
    // D'abord vérifier l'authentification Firebase
    // authenticateFirebase est un middleware async, on l'appelle directement
    await new Promise((resolve, reject) => {
      authenticateFirebase(req, res, (err) => {
        if (err) {
          reject(err);
        } else {
          resolve();
        }
      });
    });

    // Vérifier si l'utilisateur est admin
    const userId = req.user.uid;
    const admin = await Admin.findByPk(userId);

    if (!admin || !admin.isAdmin) {
      console.log(`Accès refusé pour l'utilisateur ${userId}:`, { admin: admin ? 'existe mais isAdmin=false' : 'non trouvé' });
      return res.status(403).json({
        success: false,
        error: 'Accès refusé. Droits administrateur requis.',
      });
    }

    // Vérifier et corriger les permissions
    const adminCount = await Admin.count();
    const firstAdmin = await Admin.findOne({
      order: [['createdAt', 'ASC']],
      limit: 1,
    });
    const isFirstAdmin = adminCount === 1 || (firstAdmin && firstAdmin.userId === userId);
    
    // Permissions de base qui doivent TOUJOURS être true pour tous les admins
    // (sauf manageAdmins qui dépend si c'est le premier admin)
    const requiredPermissions = {
      manageUsers: true,
      manageLevels: true,
      viewStats: true,
      manageBattles: true,
    };
    
    // Si les permissions n'existent pas ou sont invalides, les initialiser
    let needsUpdate = false;
    if (!admin.permissions || typeof admin.permissions !== 'object') {
      console.log(`Permissions manquantes ou invalides pour l'admin ${userId}, initialisation complète`);
      admin.permissions = {
        ...requiredPermissions,
        manageAdmins: isFirstAdmin,
      };
      needsUpdate = true;
    } else {
      // Corriger les permissions de base : elles doivent TOUJOURS être true
      for (const [key, requiredValue] of Object.entries(requiredPermissions)) {
        if (admin.permissions[key] !== true) {
          console.log(`Permission ${key} incorrecte pour l'admin ${userId} (actuel: ${admin.permissions[key]}), correction à true`);
          admin.permissions[key] = true;
          needsUpdate = true;
        }
      }
      
      // Gestion spéciale pour manageAdmins
      if (isFirstAdmin) {
        // Le premier admin doit avoir manageAdmins
        if (!admin.permissions.manageAdmins) {
          console.log(`Premier admin ${userId} n'a pas manageAdmins, attribution automatique`);
          admin.permissions.manageAdmins = true;
          needsUpdate = true;
        }
      } else {
        // Pour les autres admins, manageAdmins reste comme il est (peut être false)
        if (admin.permissions.manageAdmins === undefined) {
          admin.permissions.manageAdmins = false;
          needsUpdate = true;
        }
      }
    }
    
    // Sauvegarder si des modifications ont été faites
    if (needsUpdate) {
      await admin.save();
      console.log(`Permissions mises à jour pour l'admin ${userId}:`, JSON.stringify(admin.permissions, null, 2));
    }
    
    // Vérification finale et garantie : s'assurer que les permissions sont TOUJOURS correctes
    // Même si la sauvegarde a échoué, on force les permissions correctes dans req.admin
    const guaranteedPermissions = {
      manageUsers: true,  // TOUJOURS true pour tous les admins
      manageLevels: true, // TOUJOURS true pour tous les admins
      viewStats: true,    // TOUJOURS true pour tous les admins
      manageBattles: true, // TOUJOURS true pour tous les admins
      manageAdmins: isFirstAdmin, // true seulement pour le premier admin
    };

    // Ajouter les permissions garanties à la requête (pas celles de la DB qui peuvent être incorrectes)
    req.admin = {
      userId: userId,
      permissions: guaranteedPermissions,
    };
    
    console.log(`Admin authentifié: ${userId}, permissions garanties:`, guaranteedPermissions);
    
    // Log si les permissions DB étaient incorrectes
    const dbPermissions = admin.permissions || {};
    if (!dbPermissions.viewStats || !dbPermissions.manageUsers || !dbPermissions.manageLevels || !dbPermissions.manageBattles) {
      console.warn(`ATTENTION: Permissions DB incorrectes pour l'admin ${userId}, utilisation des permissions garanties`);
      console.warn(`Permissions DB:`, dbPermissions);
      console.warn(`Permissions garanties:`, guaranteedPermissions);
    }

    next();
  } catch (error) {
    console.error('Erreur lors de la vérification admin:', error);
    if (error.message === 'Non autorisé' || error.message === 'Token invalide ou expiré') {
      return res.status(401).json({
        success: false,
        error: 'Authentification requise',
      });
    }
    return res.status(500).json({
      success: false,
      error: 'Erreur lors de la vérification des droits administrateur',
    });
  }
}

// Middleware pour vérifier une permission spécifique
function requirePermission(permission) {
  return (req, res, next) => {
    // Vérifier que req.admin existe
    if (!req.admin) {
      console.error(`requirePermission(${permission}): req.admin n'existe pas`);
      return res.status(403).json({
        success: false,
        error: 'Accès refusé. Droits administrateur requis.',
      });
    }

    // Vérifier que req.admin.permissions existe
    if (!req.admin.permissions) {
      console.error(`requirePermission(${permission}): req.admin.permissions n'existe pas`);
      return res.status(403).json({
        success: false,
        error: 'Accès refusé. Permissions non définies.',
      });
    }

    // Log pour débogage
    console.log(`Vérification permission ${permission} pour l'admin ${req.admin.userId}:`, {
      permission,
      value: req.admin.permissions[permission],
      allPermissions: req.admin.permissions,
    });

    // Vérifier la permission
    if (req.admin.permissions[permission] !== true) {
      console.error(`Permission ${permission} refusée pour l'admin ${req.admin.userId}`);
      console.error(`Permissions disponibles:`, req.admin.permissions);
      return res.status(403).json({
        success: false,
        error: `Permission requise: ${permission}`,
        availablePermissions: req.admin.permissions,
      });
    }

    next();
  };
}

module.exports = {
  checkAdmin,
  requirePermission,
};

