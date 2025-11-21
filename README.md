# 🔐 Cadenas Master

**Cadenas Master** est un jeu de réflexion captivant développé avec Flutter, où chaque cadenas cache une énigme à résoudre. Testez vos compétences en mathématiques, logique et culture générale pour déverrouiller plus de 100 niveaux progressifs !

## 📱 À propos

Cadenas Master est une application mobile multiplateforme (Android & iOS) qui combine réflexion, rapidité et stratégie. Les joueurs doivent résoudre des énigmes variées pour déverrouiller des cadenas et progresser dans le jeu. Le jeu propose également un mode multijoueur avec des duels en temps réel.

## ✨ Fonctionnalités principales

### 🎮 Mode Solo
- **100+ niveaux** avec des énigmes variées (mathématiques, logique, culture générale, suites logiques)
- **Système de points** et récompenses
- **Timer** pour chaque niveau avec limite de temps
- **Système d'indices** pour vous aider en cas de difficulté
- **Progression sauvegardée** localement et synchronisée avec le cloud

### 🏆 Classements et Profil
- **Classement global** des meilleurs joueurs
- **Profil utilisateur** avec statistiques détaillées
- **Trophées et achievements** à débloquer
- **Historique des parties** et meilleurs temps

### ⚔️ Mode Multijoueur
- **Matchmaking** automatique pour trouver un adversaire
- **Duels en temps réel** avec d'autres joueurs
- **Système de combat** basé sur la rapidité et la précision

### 🔐 Authentification
- **Connexion anonyme** pour jouer rapidement
- **Connexion Google** pour sauvegarder votre progression
- **Connexion Apple** (iOS) pour une expérience native

### 🎵 Audio
- **Musique de fond** immersive
- **Effets sonores** pour les actions (succès, échec, clics)
- **Contrôles audio** dans les paramètres

### 📊 Synchronisation Cloud
- **Sauvegarde automatique** de votre progression sur Firebase
- **Synchronisation multi-appareils** pour continuer sur n'importe quel device
- **Système de versioning** optimisé pour réduire la charge serveur

## 🛠️ Technologies utilisées

### Frontend Mobile
- **Flutter** (>=3.16.0) - Framework de développement multiplateforme
- **Dart** (>=3.0.0) - Langage de programmation
- **Google Mobile Ads** - Monétisation via publicités
- **Shared Preferences** - Stockage local des données
- **Audio Players** - Gestion de l'audio

### Backend & Services
- **Firebase** - Backend et services cloud
  - Firebase Authentication - Authentification des utilisateurs
  - Cloud Firestore - Base de données NoSQL
  - Firebase Core - Services de base
- **Node.js** - Backend API et serveur Socket.IO
- **Laravel** - Panel d'administration
- **Socket.IO** - Communication en temps réel pour les duels

## 📦 Installation

### Prérequis

#### Pour l'application Flutter
- Flutter SDK (>=3.16.0)
- Dart SDK (>=3.0.0)
- Android Studio / Xcode (pour le développement mobile)
- Compte Firebase configuré
- Compte Google AdMob (pour les publicités)

#### Pour les composants Backend
- **Node.js** (>=16.0.0) - Pour Backend-NodeJS et Socket.IO-NodeJS
- **PHP** (>=8.0) et **Composer** - Pour Admin-Panel-Laravel
- **Base de données** (MySQL/PostgreSQL) - Pour le panel admin

### Étapes d'installation

1. **Cloner le repository**
```bash
git clone https://github.com/votre-username/cadenas-master.git
cd cadenas-master
```

2. **Installer les dépendances**
```bash
flutter pub get
```

3. **Configurer Firebase**
   - Créer un projet Firebase sur [Firebase Console](https://console.firebase.google.com/)
   - Télécharger `google-services.json` (Android) et `GoogleService-Info.plist` (iOS)
   - Les placer dans les dossiers respectifs :
     - `android/app/google-services.json`
     - `ios/Runner/GoogleService-Info.plist`
   - Le fichier `firebase_options.dart` devrait être généré automatiquement

4. **Configurer AdMob** (optionnel)
   - Créer un compte AdMob
   - Obtenir les IDs des unités publicitaires
   - Les configurer dans `lib/services/ad_service.dart`

5. **Configurer les composants Backend** (optionnel, pour le développement complet)
   
   **Backend-NodeJS :**
   ```bash
   cd Backend-NodeJS
   npm install
   # Configurer les variables d'environnement (.env)
   npm start
   ```
   
   **Socket.IO-NodeJS :**
   ```bash
   cd Socket.IO-NodeJS
   npm install
   # Configurer les variables d'environnement (.env)
   npm start
   ```
   
   **Admin-Panel-Laravel :**
   ```bash
   cd Admin-Panel-Laravel
   composer install
   # Configurer le fichier .env avec les informations de la base de données
   php artisan migrate
   php artisan serve
   ```

6. **Lancer l'application Flutter**
```bash
# Pour Android
flutter run

# Pour iOS
flutter run -d ios
```

## 🏗️ Architecture du projet

Le projet est composé de **4 composants principaux** :

1. **Application Flutter** (ce repository) - Application mobile multiplateforme
2. **Backend-NodeJS** - API REST pour la gestion des données et la synchronisation
3. **Socket.IO-NodeJS** - Serveur WebSocket pour gérer les duels en temps réel
4. **Admin-Panel-Laravel** - Tableau de bord d'administration avec accès direct à la base de données

### Structure du projet Flutter

```
lib/
├── config/              # Configuration API et Socket
├── models/              # Modèles de données (Level, etc.)
├── screens/             # Écrans de l'application
│   ├── home_screen.dart
│   ├── game_screen.dart
│   ├── level_select_screen.dart
│   ├── auth_screen.dart
│   ├── profile_screen.dart
│   ├── leaderboard_screen.dart
│   ├── duel_screen.dart
│   └── ...
├── services/            # Services métier
│   ├── game_service.dart
│   ├── firebase_service.dart
│   ├── ad_service.dart
│   ├── audio_service.dart
│   └── ...
├── widgets/             # Widgets réutilisables
├── theme/               # Thème de l'application
└── main.dart            # Point d'entrée

assets/
├── data/
│   └── levels.json      # Données des niveaux
└── sound/               # Fichiers audio
    ├── game-music.mp3
    ├── succes.wav
    ├── echec.wav
    └── game-clic.wav
```

### Composants Backend

```
Admin-Panel-Laravel/     # Panel d'administration
├── Accès direct à la base de données (sans API)
├── Gestion des utilisateurs
├── Gestion des niveaux
├── Statistiques et analytics
└── Configuration du jeu

Backend-NodeJS/          # API REST
├── Endpoints pour la synchronisation des données
├── Gestion des utilisateurs
├── Gestion des classements
├── Gestion des niveaux
└── Intégration avec Firebase

Socket.IO-NodeJS/        # Serveur WebSocket
├── Gestion des duels en temps réel
├── Matchmaking des joueurs
├── Synchronisation des parties multijoueur
└── Communication bidirectionnelle avec les clients
```

## 🎯 Fonctionnalités techniques

### Architecture

#### Application Flutter
- **Services modulaires** pour une séparation claire des responsabilités
- **Singleton pattern** pour les services principaux
- **Local Storage** pour les performances et l'offline-first
- **Synchronisation intelligente** avec le cloud via l'API Node.js

#### Backend-NodeJS
- **API REST** pour la gestion des données utilisateurs
- **Synchronisation** des niveaux et progression
- **Gestion des classements** et statistiques
- **Intégration Firebase** pour l'authentification

#### Socket.IO-NodeJS
- **Communication temps réel** pour les duels
- **Matchmaking automatique** des joueurs
- **Gestion des salles** de jeu multijoueur
- **Synchronisation des états** de partie en temps réel

#### Admin-Panel-Laravel
- **Accès direct à la base de données** (sans couche API)
- **Interface d'administration** complète
- **Gestion des utilisateurs** et modération
- **Gestion des niveaux** et contenu du jeu
- **Statistiques et analytics** détaillées

### Optimisations
- **Polling adaptatif** pour réduire la charge serveur
- **Cache en mémoire** pour les données fréquemment utilisées
- **Préchargement des assets** au démarrage
- **Gestion du cycle de vie** de l'application pour l'audio

### Sécurité
- **Règles Firestore** configurées pour protéger les données
- **Authentification sécurisée** via Firebase Auth
- **Validation côté client et serveur**

## 📝 Configuration

### Variables d'environnement

#### Application Flutter
Le projet utilise Firebase qui nécessite une configuration spécifique. Assurez-vous d'avoir :
- Un projet Firebase actif
- Les fichiers de configuration Firebase en place
- Les règles Firestore configurées (voir `firestore.rules`)
- Configuration de l'URL de l'API dans `lib/config/api_config.dart`
- Configuration de l'URL Socket.IO dans `lib/config/socket_config.dart`

#### Backend-NodeJS
- Variables d'environnement dans `.env` :
  - URL de la base de données
  - Clés API Firebase
  - Port du serveur
  - Configuration CORS

#### Socket.IO-NodeJS
- Variables d'environnement dans `.env` :
  - Port du serveur Socket.IO
  - Configuration CORS
  - Clés de sécurité

#### Admin-Panel-Laravel
- Configuration dans `.env` :
  - Connexion à la base de données
  - Clés d'application Laravel
  - Configuration de l'environnement

## 🚀 Build et Déploiement

### Android
```bash
flutter build apk --release
# ou
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## 🤝 Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1. Fork le projet
2. Créer une branche pour votre fonctionnalité (`git checkout -b feature/AmazingFeature`)
3. Commit vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## 📄 Licence

Ce projet est sous licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

### Pourquoi MIT ?
- ✅ Permet l'utilisation commerciale
- ✅ Permet la modification et la distribution
- ✅ Simple et largement acceptée
- ✅ Encourage les contributions tout en protégeant l'auteur

## 👨‍💻 Auteur Abognon Ulrich

Développé avec ❤️ en utilisant Flutter

## 📞 Support +2250777365437 / uabognon.95@gmail.com

Pour toute question ou problème, veuillez ouvrir une issue sur GitHub.

---

**Bon jeu et bonne chance pour déverrouiller tous les cadenas ! 🔓**

