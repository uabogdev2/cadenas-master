import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../models/level_model.dart';
import '../services/battle_service_nodejs.dart';
import '../services/socket_duel_service.dart';
import '../services/user_profile_service.dart';
import '../services/trophy_service.dart';
import '../services/game_service.dart';
import '../widgets/code_input.dart';
import '../services/audio_service.dart';
import '../services/ad_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../theme/app_theme.dart';

class DuelScreen extends StatefulWidget {
  final String battleId;
  final bool isCreator;
  final Map<String, dynamic>? initialBattleData;

  const DuelScreen({
    super.key,
    required this.battleId,
    this.isCreator = false,
    this.initialBattleData,
  });

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> with TickerProviderStateMixin {
  final BattleServiceNodeJs _battleService = BattleServiceNodeJs();
  final SocketDuelService _socketService = SocketDuelService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<Map<String, dynamic>>? _battleUpdatedSub;
  StreamSubscription<Map<String, dynamic>>? _battleFinishedSub;
  StreamSubscription<Map<String, dynamic>>? _socketErrorSub;
  final TrophyService _trophyService = TrophyService();
  final GameService _gameService = GameService();
  final AudioService _audioService = AudioService();
  final AdService _adService = AdService();
  bool _hasShownInterstitial = false;

  Map<String, dynamic>? _battleData;
  Map<String, dynamic> _mergeBattleData(Map<String, dynamic> incoming) {
    final current = _battleData != null ? Map<String, dynamic>.from(_battleData!) : <String, dynamic>{};
    incoming.forEach((key, value) {
      if (value != null) {
        current[key] = value;
      }
    });
    return current;
  }
  List<Level> _questions = [];
  int _currentQuestionIndex = 0;
  Level? _currentQuestion;
  Timer? _timer;
  int _timeRemaining = 300; // 5 minutes en secondes
  bool _isAnswered = false;
  bool _isWaitingForOpponent = true;
  bool _isFinished = false;
  bool _hasHandledBattleFinished = false; // Pour éviter d'appeler _handleBattleFinished plusieurs fois
  String? _winner;
  Map<String, int>? _trophyChanges;
  DateTime? _startTime;
  
  // Pour l'animation du score de l'adversaire
  int _previousOpponentScore = 0;
  bool _opponentScoreChanged = false;
  AnimationController? _scoreAnimationController;
  Animation<double>? _scoreAnimation;

  String? get _currentUserId => _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    // Initialiser l'animation pour le score de l'adversaire
    _scoreAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scoreAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 0.5,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 0.5,
      ),
    ]).animate(_scoreAnimationController!);
    
    _subscribeToSocketEvents();
    if (widget.initialBattleData != null) {
      _battleData = Map<String, dynamic>.from(widget.initialBattleData!);
      _updateFromBattleData();
    } else {
      _loadBattle();
    }
  }

  @override
  void dispose() {
    _battleUpdatedSub?.cancel();
    _battleFinishedSub?.cancel();
    _socketErrorSub?.cancel();
    _timer?.cancel();
    _scoreAnimationController?.dispose();
    try {
      _socketService.disconnect();
    } catch (e) {
      debugPrint('Erreur disconnect socket duel: $e');
    }
    super.dispose();
  }

  Future<void> _subscribeToSocketEvents() async {
    try {
      await _socketService.connect();
    } catch (e) {
      debugPrint('Erreur connexion socket duel: $e');
    }

    _battleUpdatedSub ??= _socketService.battleUpdated.listen((payload) {
      final battle = payload['battle'] as Map<String, dynamic>?;
      if (battle == null) return;
      final battleId = battle['id']?.toString();
      if (battleId != widget.battleId) return;
      if (!mounted) return;
      setState(() {
        _battleData = _mergeBattleData(battle);
        _updateFromBattleData();
      });
    });

    _battleFinishedSub ??= _socketService.battleFinished.listen((payload) {
      final battle = payload['battle'] as Map<String, dynamic>?;
      final battleId = battle?['id']?.toString();
      if (battleId != null && battleId == widget.battleId) {
        if (battle == null || !mounted) return;
        setState(() {
          _battleData = _mergeBattleData(battle);
          _isFinished = true;
        });
        _updateFromBattleData();
      } else if (payload['result'] != null) {
        _loadBattle(forceRefresh: true);
      }
    });

    _socketErrorSub ??= _socketService.socketErrors.listen((payload) {
      final message = payload['error'] ?? payload['message'];
      if (message != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.toString())),
        );
      }
    });
  }

  Future<bool> _ensureSocketReady() async {
    if (_socketService.isConnected) return true;
    try {
      await _socketService.connect();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connexion temps réel indisponible')),
        );
      }
      return false;
    }
  }

  Future<void> _loadBattle({bool forceRefresh = false}) async {
    try {
      final battle = await _battleService.getBattle(widget.battleId, forceRefresh: forceRefresh);
      if (battle != null && mounted) {
        setState(() {
          _battleData = battle;
          _updateFromBattleData();
        });
      }
    } catch (e) {
      print('Erreur lors du chargement de la bataille: $e');
    }
  }

  void _updateFromBattleData() {
    if (_battleData == null) return;

    final status = _battleData!['status'] as String? ?? 'waiting';
    final wasFinished = _isFinished;
    final player1 = _battleData!['player1'] as String?;
    final player2 = _battleData!['player2'] as String?;
    
    // Vérifier que les deux joueurs sont présents avant de permettre le jeu
    _isWaitingForOpponent = status == 'waiting' || player2 == null;
    _isFinished = status == 'finished';
    
    // Si la bataille est active et que les deux joueurs sont présents, s'assurer qu'on n'est plus en attente
    if (status == 'active' && player1 != null && player2 != null) {
      _isWaitingForOpponent = false;
    }

    // Si la bataille vient de se terminer, calculer les trophées (une seule fois)
    if (_isFinished && !wasFinished && !_hasHandledBattleFinished) {
      print('_updateFromBattleData: Bataille terminée, statut=$status');
      _hasHandledBattleFinished = true; // Marquer comme traité avant l'appel pour éviter les appels multiples
      
      // Déterminer le gagnant
      final userId = _currentUserId;
      final player1Id = _battleData!['player1'] as String?;
      final player2Id = _battleData!['player2'] as String?;
      final result = _battleData!['result'] as String?;
      final player1Abandoned = _battleData!['player1Abandoned'] as bool? ?? false;
      final player2Abandoned = _battleData!['player2Abandoned'] as bool? ?? false;
      final player1Score = _asInt(_battleData!['player1Score']);
      final player2Score = _asInt(_battleData!['player2Score']);
      
      if (player1Id != null && player2Id != null && userId != null) {
        final isPlayer1 = player1Id == userId;
        _winner = _resolveWinner(
          isPlayer1: isPlayer1,
          result: result,
          player1Abandoned: player1Abandoned,
          player2Abandoned: player2Abandoned,
          player1Score: player1Score,
          player2Score: player2Score,
        );
        
        print('_updateFromBattleData: Gagnant déterminé: $_winner (result=$result, isPlayer1=$isPlayer1, player1Abandoned=$player1Abandoned, player2Abandoned=$player2Abandoned, scores=$player1Score/$player2Score)');
      }
      
      // Appeler _handleBattleFinished dans le prochain frame pour permettre à setState de se terminer
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
      _handleBattleFinished();
        }
      });
    }

    if (status == 'active') {
      // Charger les questions mélangées (format simplifié pour le duel)
      if (_questions.isEmpty) {
        dynamic questionsData = _battleData!['questions'];
        List questionsJson = [];
        
        // Gérer le cas où questions est une String JSON au lieu d'une List
        if (questionsData is String) {
          try {
            questionsJson = jsonDecode(questionsData) as List;
          } catch (e) {
            print('Erreur lors du parsing des questions (String): $e');
            questionsJson = [];
          }
        } else if (questionsData is List) {
          questionsJson = questionsData;
        }
        
        print('_updateFromBattleData: Chargement de ${questionsJson.length} questions depuis le serveur');
        _questions = questionsJson
            .map((q) => Level.fromDuelJson(q as Map<String, dynamic>))
            .toList();
        print('_updateFromBattleData: ${_questions.length} questions chargées dans _questions');
      }
      
      // Mettre à jour l'index de question actuel et les scores
      final userId = _currentUserId;
      if (userId != null && _questions.isNotEmpty) {
        final isPlayer1 = _battleData!['player1'] == userId;
        final indexField = isPlayer1 ? 'player1QuestionIndex' : 'player2QuestionIndex';
        final scoreField = isPlayer1 ? 'player1Score' : 'player2Score';
        
        // Normaliser les valeurs numériques
        int normalizeInt(dynamic value) {
          if (value == null) return 0;
          if (value is int) return value;
          if (value is num) return value.toInt();
          return 0;
        }
        
        // Récupérer les nouvelles valeurs avec normalisation
        final newIndex = normalizeInt(_battleData![indexField]);
        final newScore = normalizeInt(_battleData![scoreField]);
        
        // Récupérer le score de l'adversaire pour détecter les changements
        final opponentScoreField = isPlayer1 ? 'player2Score' : 'player1Score';
        final newOpponentScore = normalizeInt(_battleData![opponentScoreField]);
        
        // Détecter si le score de l'adversaire a changé pour l'animation
        // IMPORTANT: Toujours mettre à jour _previousOpponentScore pour détecter les changements
        if (newOpponentScore != _previousOpponentScore) {
          if (_previousOpponentScore > 0) {
            // Le score a changé et ce n'est pas la première initialisation
            _opponentScoreChanged = true;
            // Lancer l'animation
            _scoreAnimationController?.forward(from: 0.0);
            // Réinitialiser le flag après un délai
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) {
                setState(() {
                  _opponentScoreChanged = false;
                });
              }
            });
          }
          // Toujours mettre à jour _previousOpponentScore pour la prochaine comparaison
          _previousOpponentScore = newOpponentScore;
          print('_updateFromBattleData: Score adversaire mis à jour: $_previousOpponentScore -> $newOpponentScore');
        }
        
        // Vérifier si l'index a changé
        final indexChanged = newIndex != _currentQuestionIndex;
        
        // Toujours mettre à jour la question si l'index a changé ou si la question est null
        if (indexChanged || _currentQuestion == null) {
          _currentQuestionIndex = newIndex;
          
          // Charger la question actuelle en utilisant le modulo pour recycler
          // Les deux joueurs utilisent exactement la même liste dans le même ordre
          final actualIndex = _currentQuestionIndex % _questions.length;
          if (actualIndex < _questions.length) {
            _currentQuestion = _questions[actualIndex];
            _isAnswered = false; // Réinitialiser l'état de réponse pour permettre la saisie
            print('_updateFromBattleData: Question mise à jour: index=$actualIndex, total=${_questions.length}, score=$newScore, opponentScore=$newOpponentScore');
          }
        }
        
        // Mettre à jour les scores même si l'index n'a pas changé
        // Les scores sont mis à jour en temps réel via le polling
        // L'interface se mettra à jour automatiquement via setState dans le callback
        final currentMyScore = newScore;
        final currentOpponentScore = newOpponentScore;
        print('_updateFromBattleData: Scores (isPlayer1=$isPlayer1) -> me=$currentMyScore, opponent=$currentOpponentScore');
      }
      
      // Vérifier si le timer doit démarrer
      final startTime = _battleData!['startTime'];
      if (startTime != null) {
        DateTime? newStartTime;
        if (startTime is String) {
          // Si c'est une chaîne ISO, la convertir en DateTime
          newStartTime = DateTime.tryParse(startTime);
        } else if (startTime is int) {
          // Si c'est un timestamp Unix (millisecondes), le convertir en DateTime
          newStartTime = DateTime.fromMillisecondsSinceEpoch(startTime);
        } else if (startTime is Map) {
          // Si c'est un objet avec _seconds, c'est un Firestore Timestamp (compatibilité)
          final seconds = startTime['_seconds'];
          if (seconds != null) {
            newStartTime = DateTime.fromMillisecondsSinceEpoch((seconds as int) * 1000);
          }
        }
        
        if (newStartTime != null && (_startTime == null || _startTime != newStartTime)) {
          _startTime = newStartTime;
          _startGlobalTimer();
        }
      }
    }
  }

  String _resolveWinner({
    required bool isPlayer1,
    required String? result,
    required bool player1Abandoned,
    required bool player2Abandoned,
    required int player1Score,
    required int player2Score,
  }) {
    if (player1Abandoned != player2Abandoned) {
      final player1Lost = player1Abandoned;
      final didIWin = player1Lost ? !isPlayer1 : isPlayer1;
      return didIWin ? 'you' : 'opponent';
    }

    if (result == 'player1_win') {
      return isPlayer1 ? 'you' : 'opponent';
    }
    if (result == 'player2_win') {
      return isPlayer1 ? 'opponent' : 'you';
    }
    if (result == 'draw') {
      return 'draw';
    }

    if (player1Score > player2Score) {
      return isPlayer1 ? 'you' : 'opponent';
    }
    if (player2Score > player1Score) {
      return isPlayer1 ? 'opponent' : 'you';
    }

    return 'draw';
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  void _startGlobalTimer() {
    _timer?.cancel();
    
    // Récupérer le totalTimeLimit depuis les données de la bataille (par défaut 300 secondes)
    final totalTimeLimit = _battleData?['totalTimeLimit'] as int? ?? 300;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _startTime != null) {
        final elapsed = DateTime.now().difference(_startTime!);
        final remaining = (totalTimeLimit - elapsed.inSeconds).clamp(0, totalTimeLimit);
        
        setState(() {
          _timeRemaining = remaining;
        });
        
        if (remaining <= 0 && !_isFinished && mounted) {
          // Temps écoulé, terminer la bataille
          print('Timer: Temps écoulé, finalisation de la bataille');
          _timer?.cancel();
          
          // Appeler _finishBattle de manière asynchrone pour éviter les problèmes avec setState
          _finishBattle().catchError((e) {
            print('Erreur lors de la finalisation de la bataille depuis le timer: $e');
          });
        }
      }
    });
    
    // Mettre à jour immédiatement
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!);
      final totalTimeLimit = _battleData?['totalTimeLimit'] as int? ?? 300;
      _timeRemaining = (totalTimeLimit - elapsed.inSeconds).clamp(0, totalTimeLimit);
    }
  }


  Future<void> _submitAnswer(String code) async {
    if (_isAnswered || _isFinished || _currentQuestion == null || _timeRemaining <= 0) return;

    final isCorrect = code == _currentQuestion!.code;

    setState(() {
      _isAnswered = true; // Marquer comme répondu pour afficher le message
    });

    if (isCorrect) {
      final actualIndex = _currentQuestionIndex % _questions.length;
      if (await _ensureSocketReady()) {
        _socketService.incrementScore(widget.battleId, actualIndex);
      }
      _audioService.playSucces();
      
      // Attendre un peu pour afficher le feedback
      await Future.delayed(const Duration(milliseconds: 700));
      
      // Réinitialiser l'état pour permettre la saisie de la question suivante
      // La question suivante sera chargée automatiquement via _updateFromBattleData
      if (mounted) {
        setState(() {
          _isAnswered = false;
        });
      }
    } else {
      _audioService.playEchec();
      
      // En cas de mauvaise réponse, permettre de réessayer après un court délai
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() {
          _isAnswered = false;
        });
      }
    }
  }

  Future<void> _skipQuestion() async {
    if (_isAnswered || _isFinished || _timeRemaining <= 0) return;

    // Désactiver temporairement l'état pour éviter les doubles actions
    setState(() {
      _isAnswered = true;
    });

    if (await _ensureSocketReady()) {
      _socketService.nextQuestion(widget.battleId);
    }
    
    // Attendre un peu avant de réinitialiser l'état
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Forcer la mise à jour de la question
    if (mounted) {
    setState(() {
      _isAnswered = false;
    });
    }
    
    // La question suivante sera chargée automatiquement via _updateFromBattleData
  }

  Future<void> _abandonBattle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(
              color: AppTheme.errorColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.errorColor,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Abandonner',
                style: AppTheme.heading2,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Voulez-vous vraiment abandonner cette partie ? Vous perdrez automatiquement.',
                  style: AppTheme.bodyMedium,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        'ANNULER',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text(
                        'ABANDONNER',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && await _ensureSocketReady()) {
      _socketService.abandonBattle(widget.battleId);
    }
  }

  Future<void> _finishBattle() async {
    if (_isFinished) {
      print('_finishBattle: Bataille déjà terminée, arrêt');
      return; // Éviter les appels multiples
    }
    
    _timer?.cancel();
    print('_finishBattle: Appel de finishBattle sur le serveur pour la bataille ${widget.battleId}');
    
    if (await _ensureSocketReady()) {
      _socketService.finishBattle(widget.battleId);
    }
  }

  Future<void> _handleBattleFinished() async {
    _timer?.cancel();

    if (_battleData == null) {
      print('_handleBattleFinished: _battleData est null');
      return;
    }

    final result = _battleData!['result'] as String?;
    final player1Id = _battleData!['player1'] as String?;
    final player2Id = _battleData!['player2'] as String?;
    
    print('_handleBattleFinished: result=$result, player1Id=$player1Id, player2Id=$player2Id, _winner=$_winner');

    if (result != null && player1Id != null && player2Id != null) {
      // Afficher la pub interstitielle avant les résultats (une seule fois)
      if (!_hasShownInterstitial) {
        _hasShownInterstitial = true;
        await _adService.showInterstitialAd();
      }
      
      // Récupérer les changements de trophées depuis le serveur (déjà calculés dans finishBattle)
      final mode = _battleData!['mode'] as String? ?? 'ranked';
      final trophyChangesData = _battleData!['trophyChanges'];
      
      final parsedTrophyChanges = _parseTrophyChanges(trophyChangesData);
      
      print('_handleBattleFinished: mode=$mode, trophyChanges=$parsedTrophyChanges');
      
      if (mode == 'ranked') {
        final serverTrophyChanges = await _ensureTrophyChanges(parsedTrophyChanges);
        if (serverTrophyChanges != null) {
          final player1Change = (serverTrophyChanges[player1Id] as num?)?.toInt() ?? 0;
          final player2Change = (serverTrophyChanges[player2Id] as num?)?.toInt() ?? 0;
          
          _trophyChanges = {
            'player1': 0,
            'player2': 0,
            'player1Change': player1Change,
            'player2Change': player2Change,
          };
          print('_handleBattleFinished: Trophées récupérés depuis le serveur: $_trophyChanges');
        } else {
          print('_handleBattleFinished: Impossible de récupérer les changements de trophées');
          _trophyChanges = {
            'player1': 0,
            'player2': 0,
            'player1Change': 0,
            'player2Change': 0,
          };
        }
      } else {
        // Mode amical : pas de trophées
        print('_handleBattleFinished: Mode amical - pas de trophées');
        _trophyChanges = {
          'player1': 0,
          'player2': 0,
          'player1Change': 0,
          'player2Change': 0,
        };
      }
    } else {
      print('_handleBattleFinished: Données manquantes - result=$result, player1Id=$player1Id, player2Id=$player2Id');
    }

    // Mettre à jour l'interface pour afficher l'écran de résultats
    if (mounted) {
    setState(() {});
    }

    await UserProfileService().refresh(force: true);
  }

  Map<String, dynamic>? _parseTrophyChanges(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (e) {
        debugPrint('Erreur parsing trophyChanges string: $e');
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _ensureTrophyChanges(Map<String, dynamic>? trophyChanges) async {
    if (trophyChanges != null) return trophyChanges;
    try {
      final refreshedBattle = await _battleService.getBattle(widget.battleId, forceRefresh: true);
      if (refreshedBattle != null) {
        setState(() {
          _battleData = _mergeBattleData(refreshedBattle);
        });
        return _parseTrophyChanges(refreshedBattle['trophyChanges']);
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération des trophées depuis le serveur: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isWaitingForOpponent) {
      return _buildWaitingScreen();
    }

    if (_isFinished) {
      return _buildResultScreen();
    }

    if (_currentQuestion == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
          ),
        ),
      );
    }

    return _buildGameScreen();
  }

  Widget _buildWaitingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.backgroundColor,
                AppTheme.surfaceColor,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.4),
                        AppTheme.primaryColor.withOpacity(0.1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      strokeWidth: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'En attente d\'un adversaire...',
                  style: AppTheme.heading3.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recherche en cours',
                  style: AppTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    // S'assurer que les scores sont des nombres - TOUJOURS normaliser
    // Cette fonction est appelée à chaque rebuild, donc les scores seront toujours à jour
    int normalizeScore(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      try {
        return int.parse(value.toString());
      } catch (e) {
        return 0;
      }
    }
    
    final player1ScoreRaw = _battleData?['player1Score'];
    final player2ScoreRaw = _battleData?['player2Score'];
    final player1Score = normalizeScore(player1ScoreRaw);
    final player2Score = normalizeScore(player2ScoreRaw);
    
      final userId = _currentUserId;
    final isPlayer1 = _battleData?['player1'] == userId;
    final myScore = isPlayer1 ? player1Score : player2Score;
    final opponentScore = isPlayer1 ? player2Score : player1Score;
    final mode = _battleData?['mode'] as String? ?? 'ranked';
    final isRanked = mode == 'ranked';

    final minutes = _timeRemaining ~/ 60;
    final seconds = _timeRemaining % 60;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.errorColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textPrimary),
            onPressed: _abandonBattle,
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: isRanked 
                ? AppTheme.secondaryGradient
                : AppTheme.successGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (isRanked ? AppTheme.secondaryColor : AppTheme.accentColor)
                    .withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRanked ? Icons.emoji_events : Icons.people,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                isRanked ? 'CLASSÉ' : 'AMICAL',
                style: AppTheme.bodySmall.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Timer global
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _timeRemaining / (_battleData?['totalTimeLimit'] as int? ?? 300),
                      backgroundColor: AppTheme.cardColor,
                      minHeight: 8,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _timeRemaining > 120
                            ? AppTheme.accentColor
                            : _timeRemaining > 60
                                ? AppTheme.secondaryColor
                                : AppTheme.errorColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer,
                        color: _timeRemaining > 120
                            ? AppTheme.accentColor
                            : _timeRemaining > 60
                                ? AppTheme.secondaryColor
                                : AppTheme.errorColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: AppTheme.heading3.copyWith(
                          fontSize: 22,
                          color: _timeRemaining > 120
                              ? AppTheme.accentColor
                              : _timeRemaining > 60
                                  ? AppTheme.secondaryColor
                                  : AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                  // Scores centrés en bas du timer
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Moi
                      Column(
                        children: [
                          Text(
                            'Moi',
                            style: AppTheme.bodySmall.copyWith(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '$myScore',
                              style: AppTheme.heading3.copyWith(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      // Adversaire avec animation
                      Column(
                        children: [
                          Text(
                            'Adversaire',
                            style: AppTheme.bodySmall.copyWith(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedBuilder(
                            animation: _scoreAnimation ?? const AlwaysStoppedAnimation(1.0),
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scoreAnimation?.value ?? 1.0,
                                child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                                    color: _opponentScoreChanged 
                                        ? AppTheme.accentColor.withOpacity(0.2)
                                        : AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                      color: _opponentScoreChanged
                                          ? AppTheme.accentColor.withOpacity(0.5)
                                          : AppTheme.textTertiary.withOpacity(0.3),
                                      width: _opponentScoreChanged ? 2 : 1,
                              ),
                                    boxShadow: _opponentScoreChanged ? [
                                      BoxShadow(
                                        color: AppTheme.accentColor.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ] : null,
                            ),
                            child: Text(
                              '$opponentScore',
                              style: AppTheme.heading3.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                      color: _opponentScoreChanged 
                                          ? AppTheme.accentColor 
                                          : null,
                              ),
                            ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Question
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.2),
                            AppTheme.primaryColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusL),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Text(
                        _currentQuestion!.instruction,
                        style: AppTheme.bodyLarge.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.visible,
                        softWrap: true,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Input du code
                    if (!_isAnswered)
                      CodeInput(
                        codeLength: _currentQuestion!.codeLength,
                        onCompleted: (code) {
                          _submitAnswer(code);
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Réponse soumise',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Bouton Passer
                    if (!_isAnswered)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          boxShadow: AppTheme.buttonShadow,
                        ),
                        child: ElevatedButton(
                          onPressed: _skipQuestion,
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
                              const Icon(Icons.skip_next, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'PASSER',
                                style: AppTheme.bodyLarge.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                    // Bouton Abandonner (en bas du bouton Passer)
                    if (!_isAnswered) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                        child: ElevatedButton(
                          onPressed: _abandonBattle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.exit_to_app, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'ABANDONNER',
                                style: AppTheme.bodyLarge.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Bannière publicitaire
            const BannerAdWidget(),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    // S'assurer que les scores sont des nombres
    final player1ScoreRaw = _battleData?['player1Score'];
    final player2ScoreRaw = _battleData?['player2Score'];
    final player1Score = (player1ScoreRaw is num) ? player1ScoreRaw.toInt() : (player1ScoreRaw as int?) ?? 0;
    final player2Score = (player2ScoreRaw is num) ? player2ScoreRaw.toInt() : (player2ScoreRaw as int?) ?? 0;
    
    final userId = _currentUserId;
    final isPlayer1 = _battleData?['player1'] == userId;
    final myScore = isPlayer1 ? player1Score : player2Score;
    final opponentScore = isPlayer1 ? player2Score : player1Score;
    final player1Abandoned = _battleData?['player1Abandoned'] ?? false;
    final player2Abandoned = _battleData?['player2Abandoned'] ?? false;
    final iAbandoned = isPlayer1 ? player1Abandoned : player2Abandoned;
    final opponentAbandoned = isPlayer1 ? player2Abandoned : player1Abandoned;
    final mode = _battleData?['mode'] as String? ?? 'ranked';
    final isRanked = mode == 'ranked';

    final myTrophyChange = isPlayer1
        ? (_trophyChanges?['player1Change'] ?? 0)
        : (_trophyChanges?['player2Change'] ?? 0);
    final String? trophyDeltaText = isRanked && myTrophyChange != 0
        ? (myTrophyChange > 0
            ? '+${TrophyService.formatTrophies(myTrophyChange)} trophées'
            : '${TrophyService.formatTrophies(myTrophyChange)} trophées')
        : null;

    String title;
    String message;
    Color titleColor;
    IconData icon;

    if (iAbandoned) {
      title = 'ABANDON';
      message = trophyDeltaText != null
          ? 'Vous avez abandonné la partie ($trophyDeltaText).'
          : 'Vous avez abandonné la partie.';
      titleColor = Colors.red;
      icon = Icons.exit_to_app;
    } else if (opponentAbandoned) {
      title = 'VICTOIRE !';
      message = trophyDeltaText != null
          ? 'Votre adversaire a abandonné la partie ($trophyDeltaText).'
          : 'Votre adversaire a abandonné la partie.';
      titleColor = Colors.green;
      icon = Icons.emoji_events;
    } else if (_winner == 'you') {
      title = 'VICTOIRE !';
      message = 'Félicitations, vous avez gagné !';
      titleColor = Colors.green;
      icon = Icons.emoji_events;
    } else if (_winner == 'opponent') {
      title = 'DÉFAITE';
      message = 'Votre adversaire a gagné.';
      titleColor = Colors.red;
      icon = Icons.sentiment_dissatisfied;
    } else {
      title = 'MATCH NUL';
      message = 'Égalité parfaite !';
      titleColor = Colors.orange;
      icon = Icons.handshake;
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundColor,
              AppTheme.surfaceColor,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Badge du mode
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isRanked 
                        ? AppTheme.secondaryGradient
                        : AppTheme.successGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isRanked ? AppTheme.secondaryColor : AppTheme.accentColor)
                            .withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRanked ? Icons.emoji_events : Icons.people,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isRanked ? 'MODE CLASSÉ' : 'MODE AMICAL',
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        titleColor.withOpacity(0.4),
                        titleColor.withOpacity(0.1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: titleColor.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 50,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: AppTheme.heading1.copyWith(
                    color: titleColor,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: AppTheme.bodyLarge.copyWith(
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    border: Border.all(
                      color: (isRanked ? AppTheme.secondaryColor : AppTheme.accentColor)
                          .withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Vous',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$myScore',
                                style: AppTheme.heading2.copyWith(fontSize: 28),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'VS',
                              style: AppTheme.bodyMedium.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.textTertiary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Adversaire',
                                  style: AppTheme.bodySmall.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$opponentScore',
                                style: AppTheme.heading2.copyWith(fontSize: 28),
                              ),
                            ],
                          ),
                      ],
                    ),
                    // Afficher les trophées uniquement en mode classé
                    if (isRanked) ...[
                      const SizedBox(height: 20),
                      Divider(
                        color: AppTheme.textTertiary.withOpacity(0.3),
                        thickness: 1,
                      ),
                      const SizedBox(height: 12),
                      if (myTrophyChange != 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: (myTrophyChange > 0 ? AppTheme.accentColor : AppTheme.errorColor)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            border: Border.all(
                              color: (myTrophyChange > 0 ? AppTheme.accentColor : AppTheme.errorColor)
                                  .withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                myTrophyChange > 0
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                color: myTrophyChange > 0
                                    ? AppTheme.accentColor
                                    : AppTheme.errorColor,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                myTrophyChange > 0
                                    ? '+${TrophyService.formatTrophies(myTrophyChange)}'
                                    : '${TrophyService.formatTrophies(myTrophyChange)}',
                                style: AppTheme.heading3.copyWith(
                                  color: myTrophyChange > 0
                                      ? AppTheme.accentColor
                                      : AppTheme.errorColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'trophées',
                                style: AppTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Aucun changement de trophées',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ] else if (!isRanked) ...[
                      const SizedBox(height: 20),
                      Divider(
                        color: AppTheme.textTertiary.withOpacity(0.3),
                        thickness: 1,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          border: Border.all(
                            color: AppTheme.accentColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppTheme.accentColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Mode amical - Aucun trophée',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.accentColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                ),
                const SizedBox(height: 30),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    boxShadow: AppTheme.buttonShadow,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (isRanked) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                              ),
                            ),
                          );
                          await _trophyService.getMyTrophies();
                          if (mounted) {
                            Navigator.of(context).pop(); // close loader
                            Navigator.of(context).pop(true);
                          }
                        } else {
                          Navigator.of(context).pop(true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                      ),
                      child: Text(
                        'RETOUR',
                        style: AppTheme.bodyLarge.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          ),
        ),
        ),
      ),
    );
  }
}
