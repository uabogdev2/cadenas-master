import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../models/level_model.dart';
import 'user_data_service_nodejs.dart';
import 'level_service_nodejs.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Configurer GoogleSignIn avec serverClientId pour iOS
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: kIsWeb 
        ? null 
        : (Platform.isIOS 
            ? DefaultFirebaseOptions.ios.iosClientId 
            : null),
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserDataServiceNodeJs _userDataService = UserDataServiceNodeJs();
  final LevelServiceNodeJs _levelService = LevelServiceNodeJs();

  // Singleton pattern
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Initialiser Firebase
  Future<void> initializeFirebase() async {
    try {
      // Firebase est déjà initialisé dans main.dart, donc pas besoin de le réinitialiser ici

      // Initialiser les niveaux depuis le serveur Node.js
      await _levelService.initialize();
    } catch (e) {
      print('Erreur lors de l\'initialisation de Firebase: $e');
    }
  }

  // Vérifier si l'utilisateur est connecté
  bool get isUserLoggedIn => _auth.currentUser != null;

  // Obtenir l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Inscription avec email et mot de passe
  Future<UserCredential?> registerWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Initialiser les données utilisateur
      await _userDataService.initializeUserData();

      return credential;
    } catch (e) {
      print('Erreur lors de l\'inscription: $e');
      rethrow;
    }
  }

  // Connexion avec email et mot de passe
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return credential;
    } catch (e) {
      print('Erreur lors de la connexion: $e');
      rethrow;
    }
  }

  // Connexion avec Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Initialiser les données utilisateur
      await _userDataService.initializeUserData();

      return userCredential;
    } catch (e) {
      print('Erreur lors de la connexion avec Google: $e');
      return null;
    }
  }

  // Connexion anonyme
  Future<UserCredential?> signInAnonymously() async {
    try {
      print('Début de la connexion anonyme...');

      // Vérifier si l'utilisateur est déjà connecté
      if (_auth.currentUser != null) {
        print('Utilisateur déjà connecté: ${_auth.currentUser!.uid}');
        return null;
      }

      final credential = await _auth.signInAnonymously();
      print('Connexion anonyme réussie avec ID: ${credential.user?.uid}');

      // Initialiser les données utilisateur après connexion anonyme
      try {
        await _userDataService.initializeUserData();
        print('Données utilisateur initialisées avec succès');
      } catch (dataError) {
        print('Erreur lors de l\'initialisation des données: $dataError');
        // Continuer malgré l'erreur d'initialisation des données
      }

      return credential;
    } catch (e) {
      print('Erreur lors de la connexion anonyme: $e');
      // Ne pas propager l'erreur, mais retourner null pour indiquer l'échec
      return null;
    }
  }

  // Connexion anonyme simplifiée sans utiliser UserDataService
  Future<UserCredential?> signInAnonymouslySimple() async {
    try {
      print('Début de la connexion anonyme simplifiée...');

      // Vérifier si l'utilisateur est déjà connecté
      if (_auth.currentUser != null) {
        print('Utilisateur déjà connecté: ${_auth.currentUser!.uid}');
        return null;
      }

      final credential = await _auth.signInAnonymously();
      print('Connexion anonyme simplifiée réussie avec ID: ${credential.user?.uid}');

      // Créer manuellement les données utilisateur dans Firestore
      try {
        final userId = credential.user?.uid;
        if (userId != null) {
          // Vérifier si l'utilisateur existe déjà
          final userDoc = await _firestore.collection('users').doc(userId).get();

          if (!userDoc.exists) {
            // Créer un nouveau document utilisateur
            await _firestore.collection('users').doc(userId).set({
              'createdAt': FieldValue.serverTimestamp(),
              'displayName': 'Joueur Anonyme',
              'isAnonymous': true,
              'points': 500,
              'completedLevels': 0,
            });

            // Initialiser les statistiques
            await _firestore.collection('users').doc(userId).collection('stats').doc('global').set({
              'totalAttempts': 0,
              'totalPlayTime': 0,
              'bestTimes': {},
            });

            print('Profil utilisateur anonyme créé manuellement');
          } else {
            print('Profil utilisateur anonyme existant trouvé');
          }
        }
      } catch (dataError) {
        print('Erreur non bloquante lors de la création des données: $dataError');
        // Continuer malgré l'erreur
      }

      return credential;
    } catch (e) {
      print('Erreur lors de la connexion anonyme simplifiée: $e');
      return null;
    }
  }

  // Connexion avec Google simplifiée
  Future<UserCredential?> signInWithGoogleSimple() async {
    try {
      print('Début de la connexion Google simplifiée...');

      // Vérifier si l'utilisateur est déjà connecté et se déconnecter si nécessaire
      if (_auth.currentUser != null) {
        print('Utilisateur déjà connecté, déconnexion en cours...');
        try {
          await _googleSignIn.signOut();
          await _auth.signOut();
        } catch (e) {
          print('Erreur lors de la déconnexion: $e');
        }
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('Sélection de compte Google annulée par l\'utilisateur');
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Vérifier que les tokens sont valides
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Erreur: Tokens Google invalides');
        throw Exception('Les tokens d\'authentification Google sont invalides');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      print('Connexion Google réussie avec ID: ${userCredential.user?.uid}');

      // Initialiser les données utilisateur via le serveur Node.js
      try {
        await _userDataService.initializeUserData();
        print('Profil utilisateur Google créé avec succès');
      } catch (dataError) {
        print('Erreur non bloquante lors de la création des données: $dataError');
        // Continuer malgré l'erreur
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException lors de la connexion Google: ${e.code} - ${e.message}');
      rethrow;
    } on PlatformException catch (e) {
      print('PlatformException lors de la connexion Google: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      print('Erreur lors de la connexion avec Google simplifiée: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Connexion avec Apple simplifiée
  Future<UserCredential?> signInWithAppleSimple() async {
    if (!Platform.isIOS && !Platform.isMacOS && !kIsWeb) {
      print('Apple Sign In is only available on iOS, macOS, and Web');
      throw PlatformException(
        code: 'PLATFORM_NOT_SUPPORTED',
        message: 'Apple Sign In n\'est disponible que sur iOS, macOS et Web',
      );
    }

    try {
      print('Début de la connexion Apple simplifiée...');

      // Vérifier si l'utilisateur est déjà connecté et se déconnecter si nécessaire
      if (_auth.currentUser != null) {
        print('Utilisateur déjà connecté, déconnexion en cours...');
        try {
          await _auth.signOut();
        } catch (e) {
          print('Erreur lors de la déconnexion: $e');
        }
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Vérifier que le token d'identité est présent
      if (credential.identityToken == null) {
        print('Erreur: Token d\'identité Apple invalide');
        throw Exception('Le token d\'authentification Apple est invalide');
      }

      final oAuthProvider = OAuthProvider('apple.com');
      final firebaseCredential = oAuthProvider.credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(firebaseCredential);
      print('Connexion Apple réussie avec ID: ${userCredential.user?.uid}');

      // Initialiser les données utilisateur via le serveur Node.js
      try {
        await _userDataService.initializeUserData();
        print('Profil utilisateur Apple créé avec succès');
      } catch (dataError) {
        print('Erreur non bloquante lors de la création des données: $dataError');
        // Continuer malgré l'erreur
      }

      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      print('SignInWithAppleAuthorizationException: ${e.code} - ${e.message}');
      if (e.code == AuthorizationErrorCode.canceled) {
        print('L\'utilisateur a annulé la connexion Apple');
        return null;
      }
      rethrow;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException lors de la connexion Apple: ${e.code} - ${e.message}');
      rethrow;
    } on PlatformException catch (e) {
      print('PlatformException lors de la connexion Apple: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      print('Erreur lors de la connexion avec Apple simplifiée: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      rethrow;
    }
  }

  // Supprimer le compte
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;

      if (user != null) {
        // Supprimer le compte Firebase Auth
        // Note: La suppression des données utilisateur dans MySQL se fera via le serveur Node.js
        // Il faudrait ajouter une route DELETE /api/users/me dans le serveur
        await user.delete();
      }
    } catch (e) {
      print('Erreur lors de la suppression du compte: $e');
      rethrow;
    }
  }

  // Réinitialiser le mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Erreur lors de la réinitialisation du mot de passe: $e');
      rethrow;
    }
  }

  // Mettre à jour le profil utilisateur
  // photoURL peut être null (ne pas mettre à jour), une chaîne vide (supprimer), ou une URL (mettre à jour)
  Future<void> updateUserProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _auth.currentUser;

      if (user != null) {
        // Mettre à jour uniquement les champs fournis
        if (displayName != null) {
          await user.updateDisplayName(displayName);
        }
        
        // photoURL peut être:
        // - null : ne pas mettre à jour
        // - chaîne vide : supprimer la photo
        // - URL : mettre à jour avec la nouvelle URL
        if (photoURL != null) {
          if (photoURL.isEmpty) {
            // Supprimer la photo
            await user.updatePhotoURL(null);
          } else {
            // Mettre à jour avec la nouvelle URL
            await user.updatePhotoURL(photoURL);
          }
        }

        // Mettre à jour les données utilisateur via le serveur Node.js
        final updateData = <String, dynamic>{};
        if (displayName != null) {
          updateData['displayName'] = displayName;
        }
        if (photoURL != null) {
          if (photoURL.isEmpty) {
            // Supprimer la photo URL
            updateData['photoURL'] = null;
          } else {
            // Mettre à jour avec la nouvelle URL
            updateData['photoURL'] = photoURL;
          }
        }

        if (updateData.isNotEmpty) {
          // Utiliser UserDataServiceNodeJs pour mettre à jour via le serveur
          await _userDataService.updateUserProfile(
            displayName: displayName,
            photoURL: photoURL,
          );
        }
      }
    } catch (e) {
      print('Erreur lors de la mise à jour du profil: $e');
      rethrow;
    }
  }

  // Vérifier si l'utilisateur est un administrateur
  Future<bool> isUserAdmin() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return false;
      }

      // Vérifier via l'API du serveur Node.js
      // Note: Il faudrait ajouter une route /api/users/me/admin dans le serveur
      // Pour l'instant, on retourne false
      // TODO: Implémenter la vérification admin via l'API
      return false;
    } catch (e) {
      print('Erreur lors de la vérification des droits d\'administrateur: $e');
      return false;
    }
  }

  // Sign in with Apple
  Future<UserCredential?> signInWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS && !kIsWeb) {
      print('Apple Sign In is only available on iOS, macOS, and Web');
      return null;
    }

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final firebaseCredential = oAuthProvider.credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      return await _auth.signInWithCredential(firebaseCredential);
    } catch (e) {
      print('Error signing in with Apple: $e');
      return null;
    }
  }
}