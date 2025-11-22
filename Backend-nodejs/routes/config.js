const express = require('express');
const router = express.Router();
const { GameConfig } = require('../models');

// Get global game configuration
router.get('/', async (req, res) => {
  try {
    // Fetch the first config or create default
    const [config, created] = await GameConfig.findOrCreate({
      where: { id: 1 },
      defaults: {
        trophies_win: 100,
        trophies_loss: 100,
        trophies_draw: 10,
        game_timer: 300,
        question_timer: 30,
        min_version_android: '1.0.0',
        min_version_ios: '1.0.0',
        force_update: false,
        maintenance_mode: false,
      }
    });

    res.json({
      success: true,
      config: config
    });
  } catch (error) {
    console.error('Error fetching game config:', error);
    res.status(500).json({
      success: false,
      error: 'Error fetching configuration'
    });
  }
});

module.exports = router;
