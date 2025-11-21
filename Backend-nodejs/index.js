const express = require('express');
const cors = require('cors');
const http = require('http');
const path = require('path');
require('dotenv').config();

// Importer les configurations
const { testConnection, syncDatabase } = require('./config/database');

// Importer les routes
const usersRoutes = require('./routes/users');
const levelsRoutes = require('./routes/levels');
const adminRoutes = require('./routes/admin');
const battlesRoutes = require('./routes/battles');

// Importer les modèles pour les associations
require('./models');

// Créer l'application Express + serveur HTTP
const app = express();
const server = http.createServer(app);

let isShuttingDown = false;
let serverStarted = false;

// Trust proxy (nécessaire si derrière un reverse proxy comme nginx)
app.set('trust proxy', 1);

// Middleware
const corsOrigins = process.env.CORS_ORIGIN 
  ? process.env.CORS_ORIGIN.split(',').map(origin => origin.trim())
  : '*';

app.use(cors({
  origin: corsOrigins,
  credentials: true,
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Initialiser la base de données (appelée une seule fois au démarrage)
let dbInitialized = false;

async function initializeDatabase() {
  if (dbInitialized) return;
  
  try {
    // Tester la connexion à la base de données
    await testConnection();
    
    // Synchroniser la base de données (créer les tables si elles n'existent pas)
    await syncDatabase(false); // false = ne pas forcer la recréation
    
    // Initialiser les niveaux depuis le fichier JSON si la base est vide
    try {
      const levelService = require('./services/levelService');
      const { Level } = require('./models');
      const levelCount = await Level.count();
      
      if (levelCount === 0) {
        console.log('Aucun niveau trouvé dans la base de données, initialisation depuis le fichier JSON...');
        await levelService.syncLevelsFromJson();
        console.log('Niveaux initialisés depuis le fichier JSON');
      } else {
        console.log(`${levelCount} niveaux trouvés dans la base de données`);
      }
    } catch (levelError) {
      console.error('Erreur lors de l\'initialisation des niveaux:', levelError);
      // Ne pas bloquer le démarrage si l'initialisation des niveaux échoue
    }
    
    dbInitialized = true;
    console.log('Base de données initialisée');
  } catch (error) {
    console.error('Erreur lors de l\'initialisation de la base de données:', error);
    // Ne pas bloquer le démarrage si la DB n'est pas disponible immédiatement
  }
}

// Initialiser la base de données au démarrage (de manière asynchrone)
initializeDatabase().catch(err => {
  console.error('Erreur lors de l\'initialisation initiale de la DB:', err);
});

// Middleware pour initialiser la DB si pas encore fait (pour Passenger)
app.use(async (req, res, next) => {
  if (!dbInitialized) {
    await initializeDatabase();
  }
  next();
});

// Routes
app.get('/', (req, res) => {
  const protocol = req.protocol || 'http';
  const host = req.get('host');
  const wsProtocol = protocol === 'https' ? 'wss' : 'ws';
  
  res.json({
    success: true,
    message: 'Serveur Lock Game en cours d\'exécution',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    endpoints: {
      health: '/health',
      users: '/api/users',
      levels: '/api/levels',
      battles: '/api/battles',
      admin: '/admin',
    },
  });
});

app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Serveur en cours d\'exécution',
    timestamp: new Date().toISOString(),
  });
});

// Servir les fichiers statiques de l'admin panel
app.use('/admin-panel', express.static(path.join(__dirname, 'public/admin')));

// Route pour servir l'interface admin
app.get('/admin-panel', (req, res) => {
  res.sendFile(path.join(__dirname, 'public/admin/index.html'));
});

app.use('/api/users', usersRoutes);
app.use('/api/levels', levelsRoutes);
app.use('/api/battles', battlesRoutes);
app.use('/admin', adminRoutes);

// Gestion des erreurs
app.use((err, req, res, next) => {
  console.error('Erreur:', err);
  res.status(err.status || 500).json({
    success: false,
    error: err.message || 'Erreur interne du serveur',
  });
});

// Gestion des routes non trouvées (DOIT être après toutes les routes)
app.use((req, res) => {
  console.log(`Route non trouvée: ${req.method} ${req.path}`);
  res.status(404).json({
    success: false,
    error: 'Route non trouvée',
    path: req.path,
    method: req.method,
  });
});

function resolveRuntimePort() {
  const candidates = [process.env.PORT, process.env.APP_PORT];

  for (const value of candidates) {
    if (!value) continue;
    const parsed = Number(value);
    if (!Number.isNaN(parsed) && parsed > 0) {
      return parsed;
    }
  }

  if (process.env.NODE_ENV !== 'production') {
    console.warn('PORT non défini, utilisation du port 3000 pour le développement local.');
    return 3000;
  }

  return null;
}

async function startServer() {
  if (serverStarted) {
    return server;
  }

  const runtimePort = resolveRuntimePort();
  const runtimeHost = process.env.HOST || '0.0.0.0';

  if (!runtimePort) {
    console.error('Aucun port n\'a été fourni. Définissez la variable d\'environnement PORT (ou APP_PORT).');
    process.exit(1);
  }

  try {
    await initializeDatabase();

    await new Promise((resolve, reject) => {
      const onError = (err) => {
        server.removeListener('listening', onListening);
        reject(err);
      };

      const onListening = () => {
        server.removeListener('error', onError);
        serverStarted = true;
        console.log(`Serveur Node.js démarré sur ${runtimeHost}:${runtimePort}`);
        console.log(`Health check: http://localhost:${runtimePort}/health`);
        console.log(`API Users: http://localhost:${runtimePort}/api/users`);
        console.log(`API Levels: http://localhost:${runtimePort}/api/levels`);
        resolve();
      };

      server.once('error', onError);
      server.listen(runtimePort, runtimeHost, onListening);
    });
  } catch (error) {
    console.error('Erreur lors du demarrage du serveur:', error);
    process.exit(1);
  }
}

function gracefulShutdown(signal) {
  if (isShuttingDown) return;
  isShuttingDown = true;

  console.log(`\n${signal} recu - arret du serveur...`);

  if (!server.listening) {
    console.log('Serveur non demarre, arret immediat.');
    process.exit(0);
    return;
  }

  server.close(() => {
    console.log('Serveur arrete proprement');
    process.exit(0);
  });
}

if (require.main === module) {
  startServer();
}

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

module.exports = app;
module.exports.server = server;
module.exports.startServer = startServer;
