const fs = require('fs');
const path = require('path');

// Chemin du fichier client (relatif depuis le serveur)
const clientLevelsPath = path.join(__dirname, '../../assets/data/levels.json');
// Chemin du fichier serveur
const serverLevelsPath = path.join(__dirname, '../data/levels.json');

try {
  // Lire le fichier client
  console.log('Lecture du fichier client:', clientLevelsPath);
  if (!fs.existsSync(clientLevelsPath)) {
    console.error('Fichier client non trouvé:', clientLevelsPath);
    process.exit(1);
  }
  
  const clientLevels = fs.readFileSync(clientLevelsPath, 'utf8');
  console.log('Fichier client lu avec succès');
  
  // Créer le dossier data s'il n'existe pas
  const dataDir = path.dirname(serverLevelsPath);
  if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
    console.log('Dossier data créé:', dataDir);
  }
  
  // Écrire le fichier serveur
  console.log('Écriture du fichier serveur:', serverLevelsPath);
  fs.writeFileSync(serverLevelsPath, clientLevels, 'utf8');
  console.log('Fichier serveur créé avec succès');
  
  // Vérifier le nombre de niveaux
  const levels = JSON.parse(clientLevels);
  console.log(`${levels.length} niveaux copiés depuis le client vers le serveur`);
  
  process.exit(0);
} catch (error) {
  console.error('Erreur lors de la copie des niveaux:', error);
  process.exit(1);
}

