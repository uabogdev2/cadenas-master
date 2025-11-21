import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/socket_duel_service.dart';
import 'duel_screen.dart';
import '../theme/app_theme.dart';

class MatchmakingScreen extends StatefulWidget {
  final bool shouldRefreshOnExit;
  const MatchmakingScreen({super.key, this.shouldRefreshOnExit = false});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> with SingleTickerProviderStateMixin {
  final SocketDuelService _socketService = SocketDuelService();
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<Map<String, dynamic>>? _battleCreatedSub;
  StreamSubscription<Map<String, dynamic>>? _battleStartedSub;
  StreamSubscription<Map<String, dynamic>>? _battleFoundSub;
  StreamSubscription<Map<String, dynamic>>? _friendlyRoomFoundSub;
  StreamSubscription<Map<String, dynamic>>? _socketErrorSub;

  late TabController _tabController;
  bool _isSearching = false;
  bool _isLeaving = false;
  String? _battleId;
  bool _socketConnected = false;
  bool _hasNavigatedToDuel = false;
  String? _lastSocketError;
  String? _pendingFriendlyRoomId;
  
  // Mode amical
  final TextEditingController _roomIdController = TextEditingController();
  String? _createdRoomId;
  bool _shouldRefreshOnExit = false;
  void _log(String message, [dynamic data]) {
    if (data != null) {
      debugPrint('[Matchmaking] $message -> $data');
    } else {
      debugPrint('[Matchmaking] $message');
    }
  }

  @override
  void initState() {
    super.initState();
    _shouldRefreshOnExit = widget.shouldRefreshOnExit;
    _tabController = TabController(length: 2, vsync: this);
    _initializeSocket();
  }

  @override
  void dispose() {
    _disposeSocketListeners();
    _tabController.dispose();
    _roomIdController.dispose();
    super.dispose();
  }

  Future<void> _initializeSocket() async {
    if (_socketService.isConnected) {
      _socketConnected = true;
      _log('Socket déjà connectée');
    }
    try {
      await _socketService.connect();
      setState(() => _socketConnected = true);
      _log('Connexion socket réussie');
    } catch (e) {
      _log('Erreur connexion socket', e);
      setState(() {
        _socketConnected = false;
        _lastSocketError = 'Impossible de se connecter au serveur temps réel';
        _isSearching = false;
      });
      _showSnack(_lastSocketError!);
      return;
    }

    _connectionSub ??= _socketService.connectionChanges.listen((connected) {
      if (!mounted) return;
      setState(() {
        _socketConnected = connected;
        if (!connected) {
          _isSearching = false;
          _battleId = null;
          _createdRoomId = null;
        }
      });
      _log('connectionChanges', connected);
    });
    _battleCreatedSub ??= _socketService.battleCreated.listen(_handleBattleCreated);
    _battleStartedSub ??= _socketService.battleStarted.listen(_handleBattleStarted);
    _battleFoundSub ??= _socketService.battleFound.listen(_handleBattleFound);
    _friendlyRoomFoundSub ??= _socketService.friendlyRoomFound.listen(_handleFriendlyRoomFound);
    _socketErrorSub ??= _socketService.socketErrors.listen(_handleSocketError);
  }

  Future<bool> _ensureSocketConnected() async {
    if (_socketService.isConnected) return true;
    try {
      await _socketService.connect();
      setState(() => _socketConnected = true);
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _socketConnected = false;
          _lastSocketError = 'Serveur temps réel indisponible';
          _isSearching = false;
        });
        _showSnack(_lastSocketError!);
      }
      return false;
    }
  }

  Future<bool> _prepareFreshSocketForAction() async {
    if (_socketService.isConnected) {
      _log('Connexion socket existante détectée, on la réinitialise');
      try {
        await _socketService.disconnect();
      } catch (e) {
        _log('Erreur lors de la déconnexion forcée', e);
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }
    return _ensureSocketConnected();
  }

  void _disposeSocketListeners() {
    _connectionSub?.cancel();
    _battleCreatedSub?.cancel();
    _battleStartedSub?.cancel();
    _battleFoundSub?.cancel();
    _friendlyRoomFoundSub?.cancel();
    _socketErrorSub?.cancel();
    _connectionSub = null;
    _battleCreatedSub = null;
    _battleStartedSub = null;
    _battleFoundSub = null;
    _friendlyRoomFoundSub = null;
    _socketErrorSub = null;
  }

  void _handleBattleCreated(Map<String, dynamic> payload) {
    _log('battleCreated', payload);
    if (!mounted) return;
    if (payload['success'] != true) {
      setState(() => _isSearching = false);
      final message = payload['message'] ?? 'Impossible de créer la bataille';
      _showSnack(message.toString());
      return;
    }

    final battle = payload['battle'] as Map<String, dynamic>?;
    if (battle == null) return;
    final battleId = battle['id']?.toString();
    setState(() {
      _battleId = battleId;
      _isSearching = true;
      _createdRoomId = battle['mode'] == 'friendly' ? battle['roomId'] as String? : null;
      _lastSocketError = null;
    });
  }

  void _handleBattleStarted(Map<String, dynamic> payload) {
    _log('battleStarted', payload);
    if (!mounted) return;
    final battle = payload['battle'] as Map<String, dynamic>?;
    if (battle == null) return;
    final battleId = battle['id']?.toString();
    if (battleId == null) return;

    _pendingFriendlyRoomId = null;
    setState(() {
      _battleId = battleId;
      _isSearching = false;
      _createdRoomId = null;
    });
    _navigateToDuel(battle);
  }

  void _handleBattleFound(Map<String, dynamic> payload) {
    _log('battleFound', payload);
    if (!mounted) return;
    if (payload['success'] == true) {
      final battle = payload['battle'] as Map<String, dynamic>?;
      final battleId = battle?['id']?.toString();
      if (battleId != null) {
        _socketService.joinBattle(battleId);
      }
    } else {
      setState(() => _isSearching = false);
      final message = payload['message'] ?? 'Aucune bataille disponible';
      _showSnack(message.toString());
    }
  }

  void _handleFriendlyRoomFound(Map<String, dynamic> payload) {
    _log('friendlyRoomFound', payload);
    if (!mounted || _pendingFriendlyRoomId == null) return;
    if (payload['success'] == true) {
      final battle = payload['battle'] as Map<String, dynamic>?;
      final battleId = battle?['id']?.toString();
      if (battleId != null) {
        _socketService.joinBattle(battleId);
      }
    } else {
      setState(() {
        _isSearching = false;
        _pendingFriendlyRoomId = null;
      });
      final message = payload['message'] ?? 'Salle introuvable';
      _showSnack(message.toString());
    }
  }

  void _handleSocketError(Map<String, dynamic> payload) {
    _log('socket error', payload);
    if (!mounted) return;
    final message = payload['error'] ?? payload['message'] ?? payload.toString();
    setState(() {
      _lastSocketError = message.toString();
      _isSearching = false;
    });
    _showSnack(message.toString());
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _navigateToDuel(Map<String, dynamic> battle) async {
    if (_hasNavigatedToDuel || !mounted) return;
    _hasNavigatedToDuel = true;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final battleId = battle['id']?.toString() ?? '';
    final isCreator = userId != null && battle['player1'] == userId;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => DuelScreen(
          battleId: battleId,
          isCreator: isCreator,
          initialBattleData: battle,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _hasNavigatedToDuel = false;
      _isSearching = false;
      _battleId = null;
      _createdRoomId = null;
      _pendingFriendlyRoomId = null;
      _lastSocketError = null;
      if (result == true) {
        _shouldRefreshOnExit = true;
      }
    });
  }

  Future<void> _cancelSearch() async {
    final shouldDeleteBattle = _isSearching && _battleId != null;
    _log('Annulation en cours', {'battleId': _battleId, 'delete': shouldDeleteBattle});
    if (shouldDeleteBattle && _socketService.isConnected) {
      try {
        _socketService.deleteBattle(_battleId!);
      } catch (e) {
        _log('Erreur deleteBattle', e);
      }
    }
    setState(() {
      _isSearching = false;
      _battleId = null;
      _createdRoomId = null;
      _pendingFriendlyRoomId = null;
      _hasNavigatedToDuel = false;
      _isLeaving = false;
      _lastSocketError = null;
    });
  }

  Future<void> _exitMatchmaking() async {
    if (_isLeaving) return;
    setState(() {
      _isLeaving = true;
    });
    await _cancelSearch();
    if (mounted) {
      Navigator.of(context).pop(_shouldRefreshOnExit);
    }
  }

  // Mode classé : chercher ou créer une salle
  Future<void> _startRankedMatchmaking() async {
    if (_isSearching) return;
    if (!await _prepareFreshSocketForAction()) return;
    _log('startRankedMatchmaking');

    setState(() {
      _isSearching = true;
      _battleId = null;
      _createdRoomId = null;
      _pendingFriendlyRoomId = null;
      _hasNavigatedToDuel = false;
      _lastSocketError = null;
    });

    _socketService.matchmakingRanked();
  }

  // Mode amical : créer une salle
  Future<void> _createFriendlyRoom() async {
    if (_isSearching) return;
    if (!await _prepareFreshSocketForAction()) return;
    _log('createFriendlyRoom');

    setState(() {
      _isSearching = true;
      _createdRoomId = null;
      _battleId = null;
      _pendingFriendlyRoomId = null;
    });

    _socketService.createBattle(mode: 'friendly');
  }

  // Mode amical : rejoindre une salle par ID
  Future<void> _joinFriendlyRoom() async {
    if (_isSearching || _roomIdController.text.trim().isEmpty) return;
    if (!await _prepareFreshSocketForAction()) return;

    final roomId = _roomIdController.text.trim().toUpperCase();
    _log('joinFriendlyRoom', roomId);
    
    setState(() {
      _isSearching = true;
      _pendingFriendlyRoomId = roomId;
      _lastSocketError = null;
    });

    _socketService.findFriendlyRoom(roomId);
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLeaving,
      onPopInvoked: (didPop) async {
        if (!didPop && !_isLeaving) {
          await _exitMatchmaking();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () async {
              await _exitMatchmaking();
            },
          ),
        ),
            title: Text(
              'DUEL',
              style: AppTheme.heading2.copyWith(fontSize: 20),
            ),
            bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          labelStyle: AppTheme.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: 'CLASSÉ'),
            Tab(text: 'AMICAL'),
          ],
        ),
          ),
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRankedTab(),
                    _buildFriendlyTab(),
                  ],
                ),
              ),
              if (_isLeaving)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Retour en cours...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankedTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.secondaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
              Icons.emoji_events,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: (bounds) => AppTheme.secondaryGradient.createShader(bounds),
              child: Text(
              'Mode Classé',
                style: AppTheme.heading1.copyWith(fontSize: 28),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Affrontez un adversaire et gagnez des trophées',
              style: AppTheme.bodyMedium.copyWith(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (!_isSearching)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.secondaryColor.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startRankedMatchmaking,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search, size: 24),
                        const SizedBox(width: 12),
                        Text(
                    'CHERCHER UN ADVERSAIRE',
                          style: AppTheme.bodyLarge.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondaryColor),
                      strokeWidth: 4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Recherche en cours...',
                    style: AppTheme.bodyLarge.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _cancelSearch,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'ANNULER',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(
                  color: AppTheme.secondaryColor.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Règles',
                    style: AppTheme.heading3.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  _buildRuleItem('Questions illimitées • 5 minutes'),
                  _buildRuleItem('Pas d\'indices • Pas de pause'),
                  _buildRuleItem('Trophées: +100 victoire, +10 nul'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendlyTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.successGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentColor.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
              Icons.people,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: (bounds) => AppTheme.successGradient.createShader(bounds),
              child: Text(
              'Mode Amical',
                style: AppTheme.heading1.copyWith(fontSize: 28),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Jouez avec vos amis sans affecter vos trophées',
              style: AppTheme.bodyMedium.copyWith(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (!_isSearching)
              Column(
                children: [
                  // Créer une salle
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentColor.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createFriendlyRoom,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_circle_outline, size: 24),
                            const SizedBox(width: 12),
                            Text(
                        'CRÉER UNE SALLE',
                              style: AppTheme.bodyLarge.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppTheme.textTertiary.withOpacity(0.3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                    'OU',
                          style: AppTheme.bodyMedium.copyWith(
                      fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ),
                      Expanded(child: Divider(color: AppTheme.textTertiary.withOpacity(0.3))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Rejoindre une salle
                  TextField(
                    controller: _roomIdController,
                    style: AppTheme.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'ID de la salle',
                      labelStyle: AppTheme.bodyMedium,
                      hintText: 'Ex: ABC123',
                      hintStyle: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        borderSide: const BorderSide(color: AppTheme.accentColor, width: 2),
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      boxShadow: AppTheme.buttonShadow,
                    ),
                    child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _joinFriendlyRoom,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.login, size: 24),
                            const SizedBox(width: 12),
                            Text(
                        'REJOINDRE LA SALLE',
                              style: AppTheme.bodyLarge.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  if (_createdRoomId != null) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: AppTheme.successGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusL),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentColor.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'ID de votre salle',
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            ),
                            child: Text(
                            _createdRoomId!,
                              style: AppTheme.heading1.copyWith(
                              color: Colors.white,
                                fontSize: 36,
                                letterSpacing: 6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Partagez cet ID avec votre ami',
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Container(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                      strokeWidth: 4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _createdRoomId != null
                        ? 'En attente d\'un adversaire...'
                        : 'Recherche en cours...',
                    style: AppTheme.bodyLarge.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _cancelSearch,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'ANNULER',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(
                  color: AppTheme.accentColor.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Règles',
                    style: AppTheme.heading3.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  _buildRuleItem('Questions illimitées • 5 minutes'),
                  _buildRuleItem('Pas d\'indices • Pas de pause'),
                  _buildRuleItem('Aucun trophée en jeu'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
            Icons.check,
              color: AppTheme.accentColor,
            size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyMedium.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
