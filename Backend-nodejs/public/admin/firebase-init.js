// Firebase SDK Initialization
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js';
import { getAuth, GoogleAuthProvider, signInWithPopup, onAuthStateChanged } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js';

// Configuration Firebase
const firebaseConfig = {
    apiKey: "AIzaSyDwf79GLzCbSE04k2Mlko9mG6izwP5TU_E",
    authDomain: "lock-game-77697.firebaseapp.com",
    projectId: "lock-game-77697",
    storageBucket: "lock-game-77697.firebasestorage.app",
    messagingSenderId: "1001043163664",
    appId: "1:1001043163664:web:ab726515dcbccbd7b6a895"
};

// Initialiser Firebase
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const provider = new GoogleAuthProvider();

// Fonction pour se connecter avec Google
async function signInWithGoogle() {
    try {
        const result = await signInWithPopup(auth, provider);
        return result;
    } catch (error) {
        console.error('Erreur lors de la connexion:', error);
        throw error;
    }
}

// Exposer les fonctions et objets globalement (une seule fois)
if (!window.firebaseAuth) {
    window.firebaseAuth = auth;
    window.firebaseProvider = provider;
    window.firebaseOnAuthStateChanged = onAuthStateChanged;
    window.firebaseSignInWithPopup = signInWithGoogle;
    
    // Émettre un événement pour indiquer que Firebase est prêt
    window.dispatchEvent(new CustomEvent('firebaseReady'));
    
    console.log('Firebase initialisé et prêt');
} else {
    console.log('Firebase déjà initialisé');
}

