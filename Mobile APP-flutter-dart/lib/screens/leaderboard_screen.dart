import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/leaderboard_service_nodejs.dart';
import '../services/trophy_service.dart';
import '../theme/app_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final LeaderboardServiceNodeJs _leaderboardService = LeaderboardServiceNodeJs();
  final TrophyService _trophyService = TrophyService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<LeaderboardPlayer> _topPlayers = [];
  LeaderboardPlayer? _myPlayer;
  bool _isLoading = true;
  
  String? get _currentUserId => _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final topPlayers = await _leaderboardService.getTopPlayers();
    final myPlayer = await _leaderboardService.getMyPlayerInfo();

    if (mounted) {
      setState(() {
        _topPlayers = topPlayers;
        _myPlayer = myPlayer;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final listOffset = _topPlayers.length >= 3 ? 3 : 0;
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
            title: Text(
          'CLASSEMENT',
              style: AppTheme.heading2.copyWith(fontSize: 20),
            ),
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
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
          ),
          body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.blue,
              child: CustomScrollView(
                slivers: [
                  // Top 100
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.secondaryGradient,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.emoji_events,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Top 100',
                                style: AppTheme.heading1.copyWith(fontSize: 26),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_myPlayer != null) _buildPlayerHighlight(_myPlayer!),
                          if (_topPlayers.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(20),
                              child: Text(
                                'Aucun joueur n\'a encore gagné de trophées.',
                                  style: AppTheme.bodyLarge,
                                  textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Liste des joueurs
                  if (_topPlayers.length > listOffset)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final player = _topPlayers[index + listOffset];
                          final isTopThree = player.rank <= 3;
                          final isMe = player.userId == _currentUserId;

                          return _buildPlayerTile(
                            player,
                            isTopThree,
                            isMe: isMe,
                            tileIndex: index,
                          );
                        },
                        childCount: _topPlayers.length - listOffset,
                      ),
                    ),

                  // Position personnelle (si pas dans le top 100)
                  if (_myPlayer != null && _myPlayer!.rank > 100)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 20),
                            Text(
                              'Votre position',
                              style: AppTheme.heading2.copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 10),
                            _buildPlayerTile(_myPlayer!, false, isMe: true),
                          ],
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),
                ],
              ),
            ),
        ),
      ),
    );
  }

  Widget _buildPlayerHighlight(LeaderboardPlayer player) {
    final hasTrophies = player.trophies > 0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          _buildAvatar(player, size: 64, isMe: true, showCrown: false),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ton classement',
                  style: AppTheme.bodyLarge.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  '#${player.rank}',
                  style: AppTheme.heading1.copyWith(color: Colors.white, fontSize: 28),
                ),
                const SizedBox(height: 4),
                Text(
                  hasTrophies
                      ? '${TrophyService.formatTrophies(player.trophies)} trophées'
                      : 'Gagne des trophées pour entrer dans le classement',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerTile(
    LeaderboardPlayer player,
    bool isTopThree, {
    bool isMe = false,
    int tileIndex = 0,
  }) {
    final cardGradients = [
      [const Color(0xFFFFF5B7), const Color(0xFFFED46B)],
      [const Color(0xFFC7F0FF), const Color(0xFF7DD3FF)],
      [const Color(0xFFFFC4DD), const Color(0xFFFF7DAA)],
      [const Color(0xFFFFE0BF), const Color(0xFFFFB48F)],
      [const Color(0xFFD9D7FF), const Color(0xFFB5A9FF)],
    ];
    final gradientColors =
        cardGradients[(player.rank - 1) % cardGradients.length];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildRankChip(player.rank, isTopThree),
          const SizedBox(width: 12),
          _buildAvatar(player, size: 44, isMe: isMe),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDisplayName(player.displayName),
                  style: AppTheme.bodyLarge.copyWith(
                    color: Colors.black.withOpacity(0.85),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rang #${player.rank}',
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  color: AppTheme.secondaryColor,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  TrophyService.formatTrophies(player.trophies),
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.secondaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankChip(int rank, bool isTopThree) {
    final colors = [
      [const Color(0xFFFFE29F), const Color(0xFFFFC851)],
      [const Color(0xFFB5FFFC), const Color(0xFF68D8FF)],
      [const Color(0xFFFFB5D8), const Color(0xFFFF7AB6)],
    ];
    final gradient = isTopThree
        ? LinearGradient(colors: colors[(rank - 1).clamp(0, colors.length - 1)])
        : LinearGradient(colors: [Colors.white, Colors.white.withOpacity(0.85)]);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: [
          if (isTopThree)
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: AppTheme.heading3.copyWith(
          color: isTopThree ? Colors.white : AppTheme.textPrimary,
          fontSize: 18,
        ),
      ),
    );
  }

  String _formatDisplayName(String name) {
    final trimmed = name.trim().toUpperCase();
    if (trimmed.length <= 10) return trimmed;
    return trimmed.substring(0, 10);
  }

  Widget _buildAvatar(LeaderboardPlayer player, {double size = 48, bool isMe = false, bool showCrown = true}) {
    final hasPhoto = player.photoUrl != null && player.photoUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isMe ? AppTheme.primaryGradient : null,
        border: isMe
            ? null
            : Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
                width: 1,
              ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: Colors.transparent,
            backgroundImage: hasPhoto ? NetworkImage(player.photoUrl!) : null,
            child: hasPhoto
                ? null
                : Text(
                    player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?',
                    style: AppTheme.heading3.copyWith(
                      color: Colors.white,
                      fontSize: size * 0.4,
                    ),
                  ),
          ),
          if (showCrown && player.rank == 1)
            Positioned(
              top: -8,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber,
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

