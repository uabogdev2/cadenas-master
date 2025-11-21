import 'dart:convert';

class Level {
  final int id;
  final String name;
  final String instruction;
  final String code;
  final int codeLength;
  final int pointsReward;
  final bool isLocked;
  final int timeLimit; // Temps limite en secondes
  final List<String> additionalHints; // Liste d'indices supplémentaires
  final int hintCost; // Coût en points pour débloquer un indice

  Level({
    required this.id,
    required this.name,
    required this.instruction,
    required this.code,
    required this.codeLength,
    required this.pointsReward,
    this.isLocked = true,
    this.timeLimit = 60, // Par défaut 60 secondes
    this.additionalHints = const [],
    this.hintCost = 100, // Par défaut 100 points
  });

  static List<String> _parseHints(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        // Ignored, we'll fall back to wrapping the raw string
      }
      return value.isEmpty ? [] : [value];
    }
    return [];
  }

  // Constructeur à partir d'un JSON
  factory Level.fromJson(Map<String, dynamic> json) {
    return Level(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      instruction: json['instruction'] as String,
      code: json['code'] as String,
      codeLength: json['codeLength'] as int,
      pointsReward: json['pointsReward'] as int? ?? 0,
      isLocked: json['isLocked'] as bool? ?? true,
      timeLimit: json['timeLimit'] as int? ?? 60,
      additionalHints: _parseHints(json['additionalHints']),
      hintCost: json['hintCost'] as int? ?? 100,
    );
  }

  // Constructeur à partir d'un JSON simplifié (pour le duel)
  // Ne contient que : id, instruction, code, codeLength
  factory Level.fromDuelJson(Map<String, dynamic> json) {
    return Level(
      id: json['id'] as int,
      name: '', // Non utilisé en duel
      instruction: json['instruction'] as String,
      code: json['code'] as String,
      codeLength: json['codeLength'] as int,
      pointsReward: 0, // Non utilisé en duel
      isLocked: false, // Non utilisé en duel
      timeLimit: 60, // Non utilisé en duel (timer global)
      additionalHints: [], // Non utilisé en duel
      hintCost: 0, // Non utilisé en duel
    );
  }

  // Conversion en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'instruction': instruction,
      'code': code,
      'codeLength': codeLength,
      'pointsReward': pointsReward,
      'isLocked': isLocked,
      'timeLimit': timeLimit,
      'additionalHints': additionalHints,
      'hintCost': hintCost,
    };
  }

  Level copyWith({
    int? id,
    String? name,
    String? instruction,
    String? code,
    int? codeLength,
    int? pointsReward,
    bool? isLocked,
    int? timeLimit,
    List<String>? additionalHints,
    int? hintCost,
  }) {
    return Level(
      id: id ?? this.id,
      name: name ?? this.name,
      instruction: instruction ?? this.instruction,
      code: code ?? this.code,
      codeLength: codeLength ?? this.codeLength,
      pointsReward: pointsReward ?? this.pointsReward,
      isLocked: isLocked ?? this.isLocked,
      timeLimit: timeLimit ?? this.timeLimit,
      additionalHints: additionalHints ?? this.additionalHints,
      hintCost: hintCost ?? this.hintCost,
    );
  }

  // Cette méthode reste pour la compatibilité, mais utilisera le fichier JSON à l'avenir
  static List<Level> getSampleLevels() {
    return [
      Level(
        id: 1,
        name: 'Niveau 1',
        instruction: 'En quelle année a eu lieu la première Coupe du Monde de la FIFA et ajoute le nombre de buts marqués lors de la finale',
        code: '19306',
        codeLength: 5,
        pointsReward: 10,
        isLocked: false,
        timeLimit: 60,
        additionalHints: ['Finale Uruguay – Argentine', 'Score : 4 – 2'],
        hintCost: 100,
      ),
      Level(
        id: 2,
        name: 'Niveau 2',
        instruction: 'En quelle année la mission Apollo 11 a-t-elle aluni et ajoute le nombre d\'astronautes à bord',
        code: '19693',
        codeLength: 5,
        pointsReward: 10,
        timeLimit: 60,
        additionalHints: ['Armstrong, Collins, Aldrin', 'Premier pas sur la Lune le 21 juillet 1969'],
        hintCost: 100,
      ),
    ];
  }
} 