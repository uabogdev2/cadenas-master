const { Level } = require('../models');
const fs = require('fs');
const path = require('path');

class LevelService {
  constructor() {
    this.levelsJsonPath = path.join(__dirname, '../data/levels.json');
  }

  // Charger les niveaux depuis le fichier JSON
  loadLevelsFromJson() {
    try {
      if (!fs.existsSync(this.levelsJsonPath)) {
        console.error('Fichier levels.json non trouvé:', this.levelsJsonPath);
        return [];
      }
      const jsonData = fs.readFileSync(this.levelsJsonPath, 'utf8');
      return JSON.parse(jsonData);
    } catch (error) {
      console.error('Erreur lors du chargement des niveaux depuis JSON:', error);
      return [];
    }
  }

  // Sauvegarder les niveaux dans le fichier JSON
  saveLevelsToJson(levels) {
    try {
      // Créer le dossier data s'il n'existe pas
      const dataDir = path.dirname(this.levelsJsonPath);
      if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
      }
      fs.writeFileSync(this.levelsJsonPath, JSON.stringify(levels, null, 2), 'utf8');
      return true;
    } catch (error) {
      console.error('Erreur lors de la sauvegarde des niveaux dans JSON:', error);
      return false;
    }
  }

  // Synchroniser les niveaux depuis le fichier JSON vers la base de données
  async syncLevelsFromJson() {
    try {
      const levelsData = this.loadLevelsFromJson();
      if (levelsData.length === 0) {
        throw new Error('Aucun niveau trouvé dans le fichier JSON');
      }

      // Vérifier si les niveaux existent déjà
      const existingLevels = await Level.count();
      
      if (existingLevels === 0) {
        // Créer tous les niveaux
        await Level.bulkCreate(levelsData);
        console.log(`${levelsData.length} niveaux créés depuis le fichier JSON`);
      } else {
        // Mettre à jour les niveaux existants et créer les nouveaux
        for (const levelData of levelsData) {
          const [level, created] = await Level.upsert(levelData, {
            returning: true,
          });
          if (created) {
            console.log(`Niveau ${levelData.id} créé`);
          } else {
            console.log(`Niveau ${levelData.id} mis à jour`);
          }
        }
      }

      return levelsData.length;
    } catch (error) {
      console.error('Erreur lors de la synchronisation des niveaux:', error);
      throw error;
    }
  }

  // Synchroniser les niveaux depuis la base de données vers le fichier JSON
  async syncLevelsToJson() {
    try {
      const levels = await Level.findAll({
        order: [['id', 'ASC']],
      });

      const levelsData = levels.map(level => ({
        id: level.id,
        name: level.name,
        instruction: level.instruction,
        code: level.code,
        codeLength: level.codeLength,
        pointsReward: level.pointsReward,
        isLocked: level.isLocked,
        timeLimit: level.timeLimit,
        additionalHints: level.additionalHints,
        hintCost: level.hintCost,
      }));

      this.saveLevelsToJson(levelsData);
      console.log(`${levelsData.length} niveaux sauvegardés dans le fichier JSON`);
      return levelsData.length;
    } catch (error) {
      console.error('Erreur lors de la synchronisation des niveaux vers JSON:', error);
      throw error;
    }
  }

  // Obtenir tous les niveaux depuis la base de données
  async getAllLevels() {
    try {
      const levels = await Level.findAll({
        order: [['id', 'ASC']],
      });
      return levels;
    } catch (error) {
      console.error('Erreur lors de la récupération des niveaux:', error);
      throw error;
    }
  }

  // Obtenir un niveau par son ID
  async getLevelById(id) {
    try {
      const level = await Level.findByPk(id);
      return level;
    } catch (error) {
      console.error('Erreur lors de la récupération du niveau:', error);
      throw error;
    }
  }

  // Créer ou mettre à jour un niveau
  async upsertLevel(levelData) {
    try {
      const [level, created] = await Level.upsert(levelData, {
        returning: true,
      });
      return { level, created };
    } catch (error) {
      console.error('Erreur lors de la création/mise à jour du niveau:', error);
      throw error;
    }
  }

  // Supprimer un niveau
  async deleteLevel(id) {
    try {
      const deleted = await Level.destroy({
        where: { id },
      });
      return deleted > 0;
    } catch (error) {
      console.error('Erreur lors de la suppression du niveau:', error);
      throw error;
    }
  }

  // Réinitialiser les niveaux (supprimer tous et recréer depuis JSON)
  async resetLevels() {
    try {
      // Supprimer tous les niveaux
      await Level.destroy({ where: {} });
      
      // Recréer depuis le fichier JSON
      return await this.syncLevelsFromJson();
    } catch (error) {
      console.error('Erreur lors de la réinitialisation des niveaux:', error);
      throw error;
    }
  }
}

module.exports = new LevelService();

