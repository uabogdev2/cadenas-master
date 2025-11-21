const levelService = require('../services/levelService');
const { sequelize } = require('../config/database');

async function initializeLevels() {
  try {
    console.log('Initialisation des niveaux...');
    
    // Tester la connexion à la base de données
    await sequelize.authenticate();
    console.log('Connexion à la base de données réussie');
    
    // Synchroniser les niveaux depuis le fichier JSON
    const count = await levelService.syncLevelsFromJson();
    console.log(`${count} niveaux initialisés avec succès`);
    
    process.exit(0);
  } catch (error) {
    console.error('Erreur lors de l\'initialisation des niveaux:', error);
    process.exit(1);
  }
}

// Exécuter le script
initializeLevels();

