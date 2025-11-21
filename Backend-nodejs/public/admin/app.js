// Configuration de l'API
const API_BASE_URL = window.location.origin;
let currentUser = null;
let authToken = null;

// Fonction d'initialisation principale
async function initializeApp() {
    try {
        console.log('Initialisation de l\'application...');
        await checkAdminExists();
        await initAuth();
        setupEventListeners();
    } catch (error) {
        console.error('Erreur lors de l\'initialisation de l\'application:', error);
    }
}

// Attendre que Firebase soit initialisé
function waitForFirebase() {
    return new Promise((resolve, reject) => {
        // Si Firebase est déjà prêt
        if (window.firebaseOnAuthStateChanged && window.firebaseAuth && window.firebaseSignInWithPopup) {
            console.log('Firebase déjà disponible');
            resolve();
            return;
        }

        // Écouter l'événement firebaseReady
        const onFirebaseReady = () => {
            console.log('Firebase prêt (via événement)');
            window.removeEventListener('firebaseReady', onFirebaseReady);
            clearInterval(checkInterval);
            resolve();
        };
        window.addEventListener('firebaseReady', onFirebaseReady);

        // Polling de secours
        let retries = 0;
        const maxRetries = 40; // 20 secondes max (40 * 500ms)
        const checkInterval = setInterval(() => {
            if (window.firebaseOnAuthStateChanged && window.firebaseAuth && window.firebaseSignInWithPopup) {
                console.log('Firebase prêt (via polling)');
                clearInterval(checkInterval);
                window.removeEventListener('firebaseReady', onFirebaseReady);
                resolve();
            } else if (retries++ >= maxRetries) {
                clearInterval(checkInterval);
                window.removeEventListener('firebaseReady', onFirebaseReady);
                console.error('Firebase n\'a pas pu être initialisé dans les délais');
                reject(new Error('Firebase n\'a pas pu être initialisé'));
            }
        }, 500);
    });
}

// Démarrer l'initialisation quand le DOM est prêt
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        waitForFirebase()
            .then(() => initializeApp())
            .catch((error) => {
                console.error('Erreur lors de l\'attente de Firebase:', error);
                const errorDiv = document.getElementById('loginError');
                if (errorDiv) {
                    errorDiv.textContent = 'Erreur: Firebase n\'a pas pu être initialisé. Veuillez rafraîchir la page.';
                    errorDiv.style.display = 'block';
                }
            });
    });
} else {
    // Le DOM est déjà prêt
    waitForFirebase()
        .then(() => initializeApp())
        .catch((error) => {
            console.error('Erreur lors de l\'attente de Firebase:', error);
            const errorDiv = document.getElementById('loginError');
            if (errorDiv) {
                errorDiv.textContent = 'Erreur: Firebase n\'a pas pu être initialisé. Veuillez rafraîchir la page.';
                errorDiv.style.display = 'block';
            }
        });
}

// Vérifier si un admin existe
async function checkAdminExists() {
    try {
        const response = await fetch(`${API_BASE_URL}/admin/setup/check-admin-exists`);
        const data = await response.json();
        
        if (data.success && !data.adminExists) {
            const setupDiv = document.getElementById('setupAdmin');
            if (setupDiv) {
                setupDiv.style.display = 'block';
            }
        }
    } catch (error) {
        console.error('Erreur lors de la vérification des admins:', error);
    }
}

// Initialiser l'authentification Firebase
async function initAuth() {
    try {
        if (!window.firebaseOnAuthStateChanged || !window.firebaseAuth) {
            throw new Error('Firebase Auth non disponible');
        }

        console.log('Initialisation de Firebase Auth...');

        window.firebaseOnAuthStateChanged(window.firebaseAuth, async (user) => {
            if (user) {
                console.log('Utilisateur connecté:', user.email);
                currentUser = user;
                authToken = await user.getIdToken();
                await checkAdminAccess();
            } else {
                console.log('Aucun utilisateur connecté');
                showLoginScreen();
            }
        });
    } catch (error) {
        console.error('Erreur lors de l\'initialisation Firebase:', error);
        const errorDiv = document.getElementById('loginError');
        if (errorDiv) {
            errorDiv.textContent = 'Erreur: Firebase n\'a pas pu être initialisé. Veuillez rafraîchir la page.';
            errorDiv.style.display = 'block';
        }
    }
}

// Vérifier l'accès admin
async function checkAdminAccess() {
    try {
        const response = await fetch(`${API_BASE_URL}/admin`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
            },
        });

        if (response.ok) {
            showDashboard();
            loadUserInfo();
            loadDashboard();
        } else {
            showLoginScreen();
            const errorDiv = document.getElementById('loginError');
            if (errorDiv) {
                errorDiv.textContent = 'Vous n\'avez pas les droits administrateur';
                errorDiv.style.display = 'block';
            }
        }
    } catch (error) {
        console.error('Erreur lors de la vérification de l\'accès admin:', error);
    }
}

// Configuration des écouteurs d'événements
function setupEventListeners() {
    const loginBtn = document.getElementById('loginBtn');
    const createFirstAdminBtn = document.getElementById('createFirstAdminBtn');
    const logoutBtn = document.getElementById('logoutBtn');

    if (loginBtn) {
        loginBtn.addEventListener('click', handleLogin);
    }
    
    if (createFirstAdminBtn) {
        createFirstAdminBtn.addEventListener('click', handleCreateFirstAdmin);
    }
    
    if (logoutBtn) {
        logoutBtn.addEventListener('click', handleLogout);
    }
    
    // Navigation
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const section = item.getAttribute('data-section');
            switchSection(section);
        });
    });
}

// Gérer la connexion
async function handleLogin() {
    try {
        if (!window.firebaseSignInWithPopup) {
            const errorMsg = 'Firebase n\'est pas encore initialisé. Veuillez rafraîchir la page.';
            console.error(errorMsg);
            const errorDiv = document.getElementById('loginError');
            if (errorDiv) {
                errorDiv.textContent = errorMsg;
                errorDiv.style.display = 'block';
            }
            return;
        }

        console.log('Tentative de connexion Firebase...');
        const result = await window.firebaseSignInWithPopup();
        console.log('Connexion réussie:', result.user.email);
        
        currentUser = result.user;
        authToken = await result.user.getIdToken();
        await checkAdminAccess();
    } catch (error) {
        console.error('Erreur lors de la connexion:', error);
        
        let errorMessage = 'Erreur lors de la connexion: ' + (error.message || error);
        
        // Messages d'erreur plus clairs
        if (error.code === 'auth/unauthorized-domain') {
            errorMessage = 'Erreur: Ce domaine n\'est pas autorisé dans Firebase. ' +
                          'Veuillez ajouter "socket.cdn-aboapp.online" dans les domaines autorisés de Firebase Authentication. ' +
                          'Consultez FIREBASE_DOMAINS_SETUP.md pour les instructions.';
        } else if (error.code === 'auth/popup-blocked') {
            errorMessage = 'Erreur: La popup de connexion a été bloquée. ' +
                          'Veuillez autoriser les popups pour ce site et réessayer.';
        } else if (error.code === 'auth/popup-closed-by-user') {
            errorMessage = 'Connexion annulée. Veuillez réessayer.';
        } else if (error.code === 'auth/cancelled-popup-request') {
            errorMessage = 'Une autre demande de connexion est en cours. Veuillez patienter.';
        }
        
        const errorDiv = document.getElementById('loginError');
        if (errorDiv) {
            errorDiv.textContent = errorMessage;
            errorDiv.style.display = 'block';
        } else {
            alert(errorMessage);
        }
    }
}

// Créer le premier admin
async function handleCreateFirstAdmin() {
    try {
        const btn = document.getElementById('createFirstAdminBtn');
        if (btn) {
            btn.disabled = true;
            btn.textContent = 'Création en cours...';
        }

        if (!authToken) {
            // Se connecter d'abord
            await handleLogin();
            if (!authToken) {
                throw new Error('Impossible de se connecter');
            }
        }

        const response = await fetch(`${API_BASE_URL}/admin/setup/create-first-admin`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json',
            },
        });

        const data = await response.json();

        if (data.success) {
            showSuccessMessage('Premier administrateur créé avec succès!');
            setTimeout(() => {
                checkAdminAccess();
            }, 1000);
        } else {
            showErrorMessage(data.error || 'Erreur lors de la création de l\'administrateur');
        }
    } catch (error) {
        console.error('Erreur lors de la création du premier admin:', error);
        showErrorMessage('Erreur lors de la création de l\'administrateur: ' + error.message);
    } finally {
        const btn = document.getElementById('createFirstAdminBtn');
        if (btn) {
            btn.disabled = false;
            btn.textContent = 'Créer le premier administrateur';
        }
    }
}

// Gérer la déconnexion
async function handleLogout() {
    try {
        if (window.firebaseAuth) {
            await window.firebaseAuth.signOut();
        }
        currentUser = null;
        authToken = null;
        showLoginScreen();
    } catch (error) {
        console.error('Erreur lors de la déconnexion:', error);
    }
}

// Afficher l'écran de connexion
function showLoginScreen() {
    const loginScreen = document.getElementById('loginScreen');
    const dashboardScreen = document.getElementById('dashboardScreen');
    if (loginScreen) loginScreen.style.display = 'block';
    if (dashboardScreen) dashboardScreen.style.display = 'none';
}

// Afficher le tableau de bord
function showDashboard() {
    const loginScreen = document.getElementById('loginScreen');
    const dashboardScreen = document.getElementById('dashboardScreen');
    if (loginScreen) loginScreen.style.display = 'none';
    if (dashboardScreen) dashboardScreen.style.display = 'flex';
}

// Charger les informations utilisateur
function loadUserInfo() {
    if (currentUser) {
        const userNameEl = document.getElementById('userName');
        const userEmailEl = document.getElementById('userEmail');
        const userAvatarEl = document.getElementById('userAvatar');
        
        if (userNameEl) userNameEl.textContent = currentUser.displayName || 'Admin';
        if (userEmailEl) userEmailEl.textContent = currentUser.email || '';
        if (userAvatarEl) userAvatarEl.src = currentUser.photoURL || 'https://via.placeholder.com/40';
    }
}

// Changer de section
function switchSection(section) {
    // Mettre à jour la navigation
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
    });
    const activeNav = document.querySelector(`[data-section="${section}"]`);
    if (activeNav) activeNav.classList.add('active');

    // Afficher la section correspondante
    document.querySelectorAll('.content-section').forEach(sec => {
        sec.classList.remove('active');
    });
    const activeSection = document.getElementById(section);
    if (activeSection) activeSection.classList.add('active');

    // Mettre à jour le titre
    const titles = {
        dashboard: 'Dashboard',
        users: 'Utilisateurs',
        levels: 'Niveaux',
        battles: 'Batailles',
        admins: 'Administrateurs',
        stats: 'Statistiques',
    };
    const pageTitle = document.getElementById('pageTitle');
    if (pageTitle) {
        pageTitle.textContent = titles[section] || 'Admin';
    }

    // Charger les données de la section
    switch (section) {
        case 'dashboard':
            loadDashboard();
            break;
        case 'users':
            loadUsers();
            break;
        case 'levels':
            loadLevels();
            break;
        case 'battles':
            loadBattles();
            break;
        case 'admins':
            loadAdmins();
            break;
        case 'stats':
            loadStats();
            break;
    }
}

// Charger le dashboard
async function loadDashboard() {
    try {
        const response = await fetch(`${API_BASE_URL}/admin/stats`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
            },
        });

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ error: 'Erreur inconnue' }));
            throw new Error(errorData.error || `Erreur HTTP ${response.status}`);
        }

        const data = await response.json();

        if (data.success && data.stats) {
            const statUsersEl = document.getElementById('statUsers');
            const statLevelsEl = document.getElementById('statLevels');
            const statBattlesEl = document.getElementById('statBattles');
            const statPointsEl = document.getElementById('statPoints');
            
            if (statUsersEl) statUsersEl.textContent = data.stats.users?.total || 0;
            if (statLevelsEl) statLevelsEl.textContent = data.stats.levels?.total || 0;
            if (statBattlesEl) statBattlesEl.textContent = data.stats.battles?.total || 0;
            if (statPointsEl) statPointsEl.textContent = data.stats.points?.total || 0;
        } else {
            console.error('Réponse invalide:', data);
            throw new Error(data.error || 'Réponse invalide du serveur');
        }
    } catch (error) {
        console.error('Erreur lors du chargement du dashboard:', error);
        const statUsersEl = document.getElementById('statUsers');
        const statLevelsEl = document.getElementById('statLevels');
        const statBattlesEl = document.getElementById('statBattles');
        const statPointsEl = document.getElementById('statPoints');
        
        if (statUsersEl) statUsersEl.textContent = 'Erreur';
        if (statLevelsEl) statLevelsEl.textContent = 'Erreur';
        if (statBattlesEl) statBattlesEl.textContent = 'Erreur';
        if (statPointsEl) statPointsEl.textContent = 'Erreur';
    }
}

// Charger les utilisateurs
async function loadUsers() {
    const tbody = document.getElementById('usersTableBody');
    if (!tbody) return;
    
    tbody.innerHTML = '<tr><td colspan="7" class="loading">Chargement...</td></tr>';

    try {
        const response = await fetch(`${API_BASE_URL}/admin/users`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
            },
        });

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ error: 'Erreur inconnue' }));
            console.error('Erreur HTTP:', response.status, errorData);
            throw new Error(errorData.error || `Erreur HTTP ${response.status}: ${response.statusText}`);
        }

        const data = await response.json();

        if (data.success) {
            if (!data.users || data.users.length === 0) {
                tbody.innerHTML = '<tr><td colspan="7" class="loading">Aucun utilisateur</td></tr>';
            } else {
                tbody.innerHTML = data.users.map(user => `
                    <tr>
                        <td>${user.id || '-'}</td>
                        <td>${user.displayName || '-'}</td>
                        <td>${user.email || '-'}</td>
                        <td>${user.points || 0}</td>
                        <td>${user.completedLevels || 0}</td>
                        <td>${user.trophies || 0}</td>
                        <td>
                            <button class="btn btn-danger" onclick="deleteUser('${user.id}')">Supprimer</button>
                        </td>
                    </tr>
                `).join('');
            }
        } else {
            throw new Error(data.error || 'Réponse invalide du serveur');
        }
    } catch (error) {
        console.error('Erreur lors du chargement des utilisateurs:', error);
        tbody.innerHTML = `<tr><td colspan="7" class="loading" style="color: red;">Erreur: ${error.message}</td></tr>`;
    }
}

// Charger les niveaux
async function loadLevels() {
    const tbody = document.getElementById('levelsTableBody');
    if (!tbody) return;
    
    tbody.innerHTML = '<tr><td colspan="6" class="loading">Chargement...</td></tr>';

    try {
        const response = await fetch(`${API_BASE_URL}/admin/levels`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
            },
        });

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ error: 'Erreur inconnue' }));
            console.error('Erreur HTTP:', response.status, errorData);
            throw new Error(errorData.error || `Erreur HTTP ${response.status}: ${response.statusText}`);
        }

        const data = await response.json();

        if (data.success) {
            if (!data.levels || data.levels.length === 0) {
                tbody.innerHTML = '<tr><td colspan="6" class="loading">Aucun niveau. Cliquez sur "Initialiser les niveaux" pour commencer.</td></tr>';
            } else {
                tbody.innerHTML = data.levels.map(level => `
                    <tr>
                        <td>${level.id || '-'}</td>
                        <td>${level.name || '-'}</td>
                        <td>${level.pointsReward || 0}</td>
                        <td>${level.timeLimit || '-'}</td>
                        <td>${level.isLocked ? '🔒' : '🔓'}</td>
                        <td>
                            <button class="btn btn-primary" onclick="editLevel(${level.id})">Modifier</button>
                            <button class="btn btn-danger" onclick="deleteLevel(${level.id})">Supprimer</button>
                        </td>
                    </tr>
                `).join('');
            }
        } else {
            throw new Error(data.error || 'Réponse invalide du serveur');
        }
    } catch (error) {
        console.error('Erreur lors du chargement des niveaux:', error);
        tbody.innerHTML = `<tr><td colspan="6" class="loading" style="color: red;">Erreur: ${error.message}</td></tr>`;
    }
}

// Charger les batailles
async function loadBattles() {
    const tbody = document.getElementById('battlesTableBody');
    if (!tbody) return;
    
    tbody.innerHTML = '<tr><td colspan="7" class="loading">Chargement...</td></tr>';

    try {
        const response = await fetch(`${API_BASE_URL}/admin/battles`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
            },
        });

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ error: 'Erreur inconnue' }));
            console.error('Erreur HTTP:', response.status, errorData);
            throw new Error(errorData.error || `Erreur HTTP ${response.status}: ${response.statusText}`);
        }

        const data = await response.json();

        if (data.success) {
            if (!data.battles || data.battles.length === 0) {
                tbody.innerHTML = '<tr><td colspan="7" class="loading">Aucune bataille</td></tr>';
            } else {
                tbody.innerHTML = data.battles.map(battle => {
                    const player1Name = battle.player1User?.displayName || battle.player1 || '-';
                    const player2Name = battle.player2User?.displayName || battle.player2 || '-';
                    return `
                    <tr>
                        <td>${battle.id || '-'}</td>
                        <td>${player1Name}</td>
                        <td>${player2Name}</td>
                        <td>${battle.status || '-'}</td>
                        <td>${battle.mode || '-'}</td>
                        <td>${battle.player1Score || 0} - ${battle.player2Score || 0}</td>
                        <td>
                            <button class="btn btn-danger" onclick="deleteBattle(${battle.id})">Supprimer</button>
                        </td>
                    </tr>
                `;
                }).join('');
            }
        } else {
            throw new Error(data.error || 'Réponse invalide du serveur');
        }
    } catch (error) {
        console.error('Erreur lors du chargement des batailles:', error);
        tbody.innerHTML = `<tr><td colspan="7" class="loading" style="color: red;">Erreur: ${error.message}</td></tr>`;
    }
}

// Charger les administrateurs
async function loadAdmins() {
    const tbody = document.getElementById('adminsTableBody');
    if (!tbody) return;
    
    tbody.innerHTML = '<tr><td colspan="6" class="loading">Chargement...</td></tr>';

    try {
        // Récupérer la liste des admins
        const response = await fetch(`${API_BASE_URL}/admin/admins`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
            },
        });

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ error: 'Erreur inconnue' }));
            console.error('Erreur HTTP:', response.status, errorData);
            throw new Error(errorData.error || `Erreur HTTP ${response.status}: ${response.statusText}`);
        }

        const data = await response.json();

        // Récupérer les permissions de l'admin actuel
        let currentAdminPermissions = {};
        try {
            const meResponse = await fetch(`${API_BASE_URL}/admin/admins/me`, {
                headers: {
                    'Authorization': `Bearer ${authToken}`,
                },
            });
            if (meResponse.ok) {
                const meData = await meResponse.json();
                if (meData.success) {
                    currentAdminPermissions = meData.admin.permissions || {};
                }
            }
        } catch (e) {
            console.error('Erreur lors de la récupération des permissions:', e);
        }

        const hasManageAdmins = currentAdminPermissions.manageAdmins === true;

        if (data.success) {
            if (!data.admins || data.admins.length === 0) {
                tbody.innerHTML = '<tr><td colspan="6" class="loading">Aucun administrateur</td></tr>';
            } else {
                tbody.innerHTML = data.admins.map(admin => {
                    const permissionsList = Object.keys(admin.permissions || {}).filter(k => admin.permissions[k]).join(', ') || '-';
                    const isCurrentUser = admin.userId === currentUser?.uid;
                    
                    return `
                    <tr>
                        <td>${admin.userId || '-'}</td>
                        <td>${admin.user?.displayName || '-'}</td>
                        <td>${admin.user?.email || '-'}</td>
                        <td>${permissionsList}</td>
                        <td>
                            ${hasManageAdmins && !isCurrentUser ? `<button class="btn btn-danger" onclick="deleteAdmin('${admin.userId}')">Supprimer</button>` : '<span style="color: #999;">Action non disponible</span>'}
                        </td>
                        <td>
                            ${!hasManageAdmins && isCurrentUser ? `<button class="btn btn-success" onclick="grantManageAdmins()">Obtenir manageAdmins</button>` : ''}
                        </td>
                    </tr>
                `;
                }).join('');
            }
        } else {
            throw new Error(data.error || 'Réponse invalide du serveur');
        }
    } catch (error) {
        console.error('Erreur lors du chargement des administrateurs:', error);
        tbody.innerHTML = `<tr><td colspan="6" class="loading" style="color: red;">Erreur: ${error.message}</td></tr>`;
    }
}

// Fonction pour obtenir la permission manageAdmins (si seul admin)
async function grantManageAdmins() {
    if (!confirm('Voulez-vous obtenir la permission manageAdmins? (Seulement si vous êtes le seul admin)')) {
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/admin/admins/grant-manage-admins`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json',
            },
        });

        const data = await response.json();

        if (data.success) {
            showSuccessMessage(data.message || 'Permission manageAdmins accordée avec succès');
            loadAdmins();
        } else {
            showErrorMessage(data.error || 'Erreur lors de l\'attribution de la permission');
        }
    } catch (error) {
        console.error('Erreur lors de l\'attribution de la permission:', error);
        showErrorMessage('Erreur lors de l\'attribution de la permission: ' + error.message);
    }
}

// Charger les statistiques
async function loadStats() {
    const content = document.getElementById('statsContent');
    if (!content) return;
    
    content.innerHTML = '<div class="loading">Chargement...</div>';

    try {
        const response = await fetch(`${API_BASE_URL}/admin/stats`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
            },
        });

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ error: 'Erreur inconnue' }));
            console.error('Erreur HTTP:', response.status, errorData);
            throw new Error(errorData.error || `Erreur HTTP ${response.status}: ${response.statusText}`);
        }

        const data = await response.json();

        if (data.success && data.stats) {
            const stats = data.stats;
            content.innerHTML = `
                <h3>Statistiques des utilisateurs</h3>
                <p>Total: ${stats.users?.total || 0}</p>
                <p>Actifs: ${stats.users?.active || 0}</p>
                <p>Inactifs: ${stats.users?.inactive || 0}</p>
                
                <h3 style="margin-top: 24px;">Statistiques des niveaux</h3>
                <p>Total: ${stats.levels?.total || 0}</p>
                
                <h3 style="margin-top: 24px;">Statistiques des points</h3>
                <p>Total: ${stats.points?.total || 0}</p>
                <p>Moyenne: ${stats.points?.average || 0}</p>
                <p>Maximum: ${stats.points?.max || 0}</p>
                <p>Minimum: ${stats.points?.min || 0}</p>
                
                <h3 style="margin-top: 24px;">Statistiques des batailles</h3>
                <p>Total: ${stats.battles?.total || 0}</p>
                <p>Actives: ${stats.battles?.active || 0}</p>
                ${stats.battles?.byStatus ? `<p>Par statut: ${JSON.stringify(stats.battles.byStatus)}</p>` : ''}
                
                <h3 style="margin-top: 24px;">Top utilisateurs</h3>
                <h4>Par points:</h4>
                <ul>
                    ${(stats.topUsers?.byPoints || []).slice(0, 5).map(u => `<li>${u.displayName || u.id}: ${u.points} points</li>`).join('') || '<li>Aucun</li>'}
                </ul>
                <h4>Par niveaux complétés:</h4>
                <ul>
                    ${(stats.topUsers?.byLevels || []).slice(0, 5).map(u => `<li>${u.displayName || u.id}: ${u.completedLevels} niveaux</li>`).join('') || '<li>Aucun</li>'}
                </ul>
            `;
        } else {
            throw new Error(data.error || 'Réponse invalide du serveur');
        }
    } catch (error) {
        console.error('Erreur lors du chargement des statistiques:', error);
        content.innerHTML = `<div class="loading" style="color: red;">Erreur: ${error.message}</div>`;
    }
}

// Fonctions utilitaires
function refreshUsers() {
    loadUsers();
}

function refreshLevels() {
    loadLevels();
}

function refreshBattles() {
    loadBattles();
}

function refreshAdmins() {
    loadAdmins();
}

function refreshStats() {
    loadStats();
}

async function initializeLevels() {
    if (!confirm('Voulez-vous initialiser les niveaux depuis le fichier JSON? Cette action va créer tous les niveaux.')) {
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/api/levels/initialize`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json',
            },
        });

        const data = await response.json();

        if (data.success) {
            showSuccessMessage(`Niveaux initialisés avec succès! ${data.count} niveaux créés.`);
            loadLevels();
        } else {
            showErrorMessage(data.error || 'Erreur lors de l\'initialisation des niveaux');
        }
    } catch (error) {
        console.error('Erreur lors de l\'initialisation des niveaux:', error);
        showErrorMessage('Erreur lors de l\'initialisation des niveaux: ' + error.message);
    }
}

async function deleteUser(userId) {
    if (!confirm(`Voulez-vous vraiment supprimer l'utilisateur ${userId}?`)) {
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/admin/users/${userId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${authToken}`,
            },
        });

        const data = await response.json();

        if (data.success) {
            showSuccessMessage('Utilisateur supprimé avec succès');
            loadUsers();
        } else {
            showErrorMessage(data.error || 'Erreur lors de la suppression de l\'utilisateur');
        }
    } catch (error) {
        console.error('Erreur lors de la suppression de l\'utilisateur:', error);
        showErrorMessage('Erreur lors de la suppression de l\'utilisateur: ' + error.message);
    }
}

async function deleteLevel(levelId) {
    if (!confirm(`Voulez-vous vraiment supprimer le niveau ${levelId}?`)) {
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/admin/levels/${levelId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${authToken}`,
            },
        });

        const data = await response.json();

        if (data.success) {
            showSuccessMessage('Niveau supprimé avec succès');
            loadLevels();
        } else {
            showErrorMessage(data.error || 'Erreur lors de la suppression du niveau');
        }
    } catch (error) {
        console.error('Erreur lors de la suppression du niveau:', error);
        showErrorMessage('Erreur lors de la suppression du niveau: ' + error.message);
    }
}

async function deleteBattle(battleId) {
    if (!confirm(`Voulez-vous vraiment supprimer la bataille ${battleId}?`)) {
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/admin/battles/${battleId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${authToken}`,
            },
        });

        const data = await response.json();

        if (data.success) {
            showSuccessMessage('Bataille supprimée avec succès');
            loadBattles();
        } else {
            showErrorMessage(data.error || 'Erreur lors de la suppression de la bataille');
        }
    } catch (error) {
        console.error('Erreur lors de la suppression de la bataille:', error);
        showErrorMessage('Erreur lors de la suppression de la bataille: ' + error.message);
    }
}

async function deleteAdmin(userId) {
    if (!confirm(`Voulez-vous vraiment supprimer l'administrateur ${userId}?`)) {
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/admin/admins/${userId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${authToken}`,
            },
        });

        const data = await response.json();

        if (data.success) {
            showSuccessMessage('Administrateur supprimé avec succès');
            loadAdmins();
        } else {
            showErrorMessage(data.error || 'Erreur lors de la suppression de l\'administrateur');
        }
    } catch (error) {
        console.error('Erreur lors de la suppression de l\'administrateur:', error);
        showErrorMessage('Erreur lors de la suppression de l\'administrateur: ' + error.message);
    }
}

function editLevel(levelId) {
    alert('Fonction de modification à implémenter');
}

function showSuccessMessage(message) {
    const errorDiv = document.getElementById('loginError');
    if (errorDiv) {
        errorDiv.className = 'success-message';
        errorDiv.textContent = message;
        errorDiv.style.display = 'block';
        setTimeout(() => {
            errorDiv.style.display = 'none';
        }, 5000);
    } else {
        alert(message);
    }
}

function showErrorMessage(message) {
    const errorDiv = document.getElementById('loginError');
    if (errorDiv) {
        errorDiv.className = 'error-message';
        errorDiv.textContent = message;
        errorDiv.style.display = 'block';
        setTimeout(() => {
            errorDiv.style.display = 'none';
        }, 5000);
    } else {
        alert(message);
    }
}

// Exposer les fonctions globalement
window.refreshUsers = refreshUsers;
window.refreshLevels = refreshLevels;
window.refreshBattles = refreshBattles;
window.refreshAdmins = refreshAdmins;
window.refreshStats = refreshStats;
window.initializeLevels = initializeLevels;
window.deleteUser = deleteUser;
window.deleteLevel = deleteLevel;
window.deleteBattle = deleteBattle;
window.deleteAdmin = deleteAdmin;
window.editLevel = editLevel;
window.grantManageAdmins = grantManageAdmins;
