const express = require('express');
const router = express.Router();
const { checkAdmin } = require('../../middleware/adminAuth');

// Routes admin
const usersRoutes = require('./users');
const levelsRoutes = require('./levels');
const statsRoutes = require('./stats');
const adminsRoutes = require('./admins');
const battlesRoutes = require('./battles');
const setupRoutes = require('./setup');

// Route racine admin (vérifie si l'utilisateur est admin)
router.get('/', checkAdmin, (req, res) => {
  res.json({
    success: true,
    message: 'Panel administrateur',
    endpoints: {
      users: '/admin/users',
      levels: '/admin/levels',
      stats: '/admin/stats',
      admins: '/admin/admins',
      battles: '/admin/battles',
    },
    permissions: req.admin.permissions,
  });
});

// Routes admin
router.use('/users', usersRoutes);
router.use('/levels', levelsRoutes);
router.use('/stats', statsRoutes);
router.use('/admins', adminsRoutes);
router.use('/battles', battlesRoutes);
router.use('/setup', setupRoutes); // Route pour créer le premier admin

module.exports = router;

