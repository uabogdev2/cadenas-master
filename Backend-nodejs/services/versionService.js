// Service de gestion de version optimisé pour 10 000 joueurs
// Utilise un système de version globale et un snapshot en RAM
// Tick global toutes les 100-200 ms pour mettre à jour uniquement les batailles modifiées

const { Battle } = require('../models');
const { Op } = require('sequelize');

class VersionService {
  constructor() {
    // Version globale qui s'incrémente à chaque mise à jour
    this.globalVersion = 0;

    // Snapshot en RAM pour chaque bataille
    this.battleSnapshots = new Map();

    // Version individuelle par bataille
    this.battleVersions = new Map();

    // Batailles en attente d'une mise à jour (invalidées)
    this.pendingUpdates = new Set();

    // Intervalle du tick global (en millisecondes)
    this.tickInterval = 150;

    // Flag pour éviter les ticks simultanés
    this.isTicking = false;

    // Intervalle de cleanup (5 minutes)
    this.cleanupInterval = 5 * 60 * 1000;
    this.lastCleanupAt = Date.now();

    // Démarrer le tick global
    this._startGlobalTick();

    console.log('[VersionService] Service initialisé (tick:', this.tickInterval, 'ms)');
  }

  _startGlobalTick() {
    setInterval(async () => {
      if (this.isTicking) {
        return;
      }

      this.isTicking = true;

      try {
        await this._processPendingUpdates();

        if (Date.now() - this.lastCleanupAt > this.cleanupInterval) {
          this.cleanup();
          this.lastCleanupAt = Date.now();
        }
      } catch (error) {
        console.error('[VersionService] Erreur lors du tick:', error);
      } finally {
        this.isTicking = false;
      }
    }, this.tickInterval);
  }

  async _processPendingUpdates() {
    if (this.pendingUpdates.size === 0) {
      return;
    }

    const battleIds = Array.from(this.pendingUpdates);
    this.pendingUpdates.clear();

    try {
      const battles = await Battle.findAll({
        where: {
          id: {
            [Op.in]: battleIds,
          },
        },
      });

      const foundIds = new Set();

      for (const battle of battles) {
        foundIds.add(battle.id);
        this._storeSnapshot(battle);
      }

      // Nettoyer les batailles qui n'existent plus
      for (const battleId of battleIds) {
        if (!foundIds.has(battleId)) {
          this.battleSnapshots.delete(battleId);
          this.battleVersions.delete(battleId);
        }
      }
    } catch (error) {
      console.error('[VersionService] Erreur lors de la mise à jour des snapshots:', error);
    }
  }

  _normalizeBattleData(battle) {
    const plain = typeof battle.get === 'function' ? battle.get({ plain: true }) : { ...battle };

    const toIso = (value) => {
      if (!value) return null;
      const date = value instanceof Date ? value : new Date(value);
      if (Number.isNaN(date.getTime())) return null;
      return date.toISOString();
    };

    return {
      ...plain,
      startTime: toIso(plain.startTime),
      endTime: toIso(plain.endTime),
      createdAt: toIso(plain.createdAt),
      updatedAt: toIso(plain.updatedAt),
      _updatedAtMs: plain.updatedAt ? new Date(plain.updatedAt).getTime() : Date.now(),
    };
  }

  _storeSnapshot(battle) {
    if (!battle) return null;

    const normalized = this._normalizeBattleData(battle);
    const battleId = normalized.id;

    if (!battleId) {
      return null;
    }

    const previousSnapshot = this.battleSnapshots.get(battleId);
    const previousVersion = this.battleVersions.get(battleId) || 0;
    const previousHash = previousSnapshot ? previousSnapshot._updatedAtMs : null;
    const currentHash = normalized._updatedAtMs;

    let versionToStore = previousVersion;

    if (!previousSnapshot || previousHash !== currentHash) {
      versionToStore = previousVersion + 1;
      this.globalVersion += 1;
    }

    this.battleVersions.set(battleId, versionToStore);
    this.battleSnapshots.set(battleId, normalized);

    return versionToStore;
  }

  updateSnapshotFromBattle(battle) {
    return this._storeSnapshot(battle);
  }

  // Obtenir la version globale actuelle
  getGlobalVersion() {
    return this.globalVersion;
  }

  // Obtenir la version d'une bataille
  getBattleVersion(battleId) {
    return this.battleVersions.get(battleId) || 0;
  }

  // Cloner un snapshot pour éviter les mutations externes
  _cloneSnapshot(snapshot) {
    if (!snapshot) return null;
    return JSON.parse(JSON.stringify(snapshot));
  }

  // Obtenir le snapshot d'une bataille
  getBattleSnapshot(battleId) {
    return this._cloneSnapshot(this.battleSnapshots.get(battleId));
  }

  // Vérifier si une bataille a été mise à jour
  checkBattleUpdate(battleId, clientVersion) {
    const serverVersion = this.getBattleVersion(battleId);
    const snapshot = this.getBattleSnapshot(battleId);

    if (snapshot && clientVersion === serverVersion) {
      return {
        updated: false,
        version: serverVersion,
      };
    }

    return {
      updated: true,
      version: serverVersion,
      data: snapshot || null,
    };
  }

  // Invalider une bataille (marquer pour mise à jour via le tick)
  invalidateBattle(battleId) {
    if (!battleId) return;

    this.battleSnapshots.delete(battleId);
    this.pendingUpdates.add(battleId);
  }

  // Nettoyer les snapshots trop anciens (actuellement garde tout)
  cleanup() {
    // Placeholder pour un nettoyage plus agressif si nécessaire
  }

  // Statistiques du service
  getStats() {
    return {
      globalVersion: this.globalVersion,
      battleSnapshotsCount: this.battleSnapshots.size,
      battleVersionsCount: this.battleVersions.size,
      pendingUpdates: this.pendingUpdates.size,
      tickInterval: this.tickInterval,
    };
  }
}

module.exports = new VersionService();

