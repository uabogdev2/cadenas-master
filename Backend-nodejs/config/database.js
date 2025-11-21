const { Sequelize } = require('sequelize');
require('dotenv').config();

const requiredEnvVars = ['DB_NAME', 'DB_USER', 'DB_PASSWORD', 'DB_HOST'];
const missingVars = requiredEnvVars.filter((key) => !process.env[key]);

if (missingVars.length > 0) {
  throw new Error(
    `Variables d'environnement manquantes pour la base de données: ${missingVars.join(
      ', '
    )}. Ajoutez-les dans .env ou via votre gestionnaire d'hébergement.`
  );
}

const sequelizeOptions = {
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3306),
  dialect: 'mysql',
  logging:
    process.env.DB_LOGGING === 'true' || process.env.NODE_ENV === 'development'
      ? console.log
      : false,
  pool: {
    max: 5,
    min: 0,
    acquire: 30000,
    idle: 10000,
  },
  define: {
    timestamps: true,
    underscored: false,
    freezeTableName: true,
  },
};

if (process.env.DB_SSL === 'true') {
  sequelizeOptions.dialectOptions = {
    ssl: {
      require: true,
      rejectUnauthorized: process.env.DB_SSL_REJECT_UNAUTHORIZED !== 'false',
    },
  };
}

// Configuration de la base de données MySQL
const sequelize = new Sequelize(
  process.env.DB_NAME,
  process.env.DB_USER,
  process.env.DB_PASSWORD,
  sequelizeOptions
);

// Tester la connexion
async function testConnection() {
  try {
    await sequelize.authenticate();
    console.log('Connexion à MySQL réussie');
  } catch (error) {
    console.error('Erreur de connexion à MySQL:', error);
    process.exit(1);
  }
}

// Synchroniser les modèles avec la base de données
async function syncDatabase(force = false) {
  try {
    // Utiliser alter: false pour éviter les erreurs de contraintes manquantes
    // Si alter est nécessaire, on le fait manuellement pour chaque modèle
    await sequelize.sync({ force, alter: false });
    console.log('Base de données synchronisée');
  } catch (error) {
    // Si c'est une erreur de contrainte manquante, on peut l'ignorer
    if (error.name === 'SequelizeUnknownConstraintError') {
      console.warn('Avertissement: Contrainte manquante ignorée:', error.constraint);
      // Essayer de synchroniser sans alter
      try {
        await sequelize.sync({ force: false, alter: false });
        console.log('Base de données synchronisée (sans alter)');
      } catch (retryError) {
        console.error('Erreur lors de la synchronisation de la base de données:', retryError);
        throw retryError;
      }
    } else {
      console.error('Erreur lors de la synchronisation de la base de données:', error);
      throw error;
    }
  }
}

module.exports = {
  sequelize,
  testConnection,
  syncDatabase,
};

