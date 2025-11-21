import 'package:flutter/material.dart';
import '../models/level_model.dart';
import '../services/level_service_nodejs.dart';
import '../theme/app_theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final LevelServiceNodeJs _levelService = LevelServiceNodeJs();
  List<Level> _levels = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadLevels();
  }
  
  Future<void> _loadLevels() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final levels = await _levelService.getAllLevels();
      setState(() {
        _levels = levels;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des niveaux: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _showLevelDialog({Level? level}) async {
    final isEditing = level != null;
    
    // Contrôleurs pour les champs du formulaire
    final idController = TextEditingController(text: isEditing ? level.id.toString() : '');
    final nameController = TextEditingController(text: isEditing ? level.name : '');
    final instructionController = TextEditingController(text: isEditing ? level.instruction : '');
    final codeController = TextEditingController(text: isEditing ? level.code : '');
    final codeLengthController = TextEditingController(text: isEditing ? level.codeLength.toString() : '');
    final pointsRewardController = TextEditingController(text: isEditing ? level.pointsReward.toString() : '');
    final timeLimitController = TextEditingController(text: isEditing ? level.timeLimit.toString() : '60');
    final hintCostController = TextEditingController(text: isEditing ? level.hintCost.toString() : '5');
    
    // Liste des indices supplémentaires
    List<String> hints = isEditing ? List.from(level.additionalHints) : [];
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(isEditing ? 'Modifier le niveau' : 'Ajouter un niveau'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'ID',
                      hintText: 'Entrez l\'ID du niveau',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !isEditing, // Ne peut pas être modifié en mode édition
                  ),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      hintText: 'Entrez le nom du niveau',
                    ),
                  ),
                  TextField(
                    controller: instructionController,
                    decoration: const InputDecoration(
                      labelText: 'Instruction / Énigme',
                      hintText: 'Entrez l\'instruction ou l\'énigme',
                    ),
                    maxLines: 3,
                  ),
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      hintText: 'Entrez le code à deviner',
                    ),
                  ),
                  TextField(
                    controller: codeLengthController,
                    decoration: const InputDecoration(
                      labelText: 'Longueur du code',
                      hintText: 'Entrez la longueur du code',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: pointsRewardController,
                    decoration: const InputDecoration(
                      labelText: 'Points de récompense',
                      hintText: 'Entrez les points de récompense',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: timeLimitController,
                    decoration: const InputDecoration(
                      labelText: 'Limite de temps (secondes)',
                      hintText: 'Entrez la limite de temps en secondes',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: hintCostController,
                    decoration: const InputDecoration(
                      labelText: 'Coût des indices',
                      hintText: 'Entrez le coût en points pour débloquer un indice',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  
                  const SizedBox(height: 16),
                  const Text('Indices supplémentaires', style: TextStyle(fontWeight: FontWeight.bold)),
                  
                  // Liste des indices
                  ...hints.asMap().entries.map((entry) {
                    final index = entry.key;
                    final hint = entry.value;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              setStateDialog(() {
                                hints.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  
                  // Bouton pour ajouter un indice
                  ElevatedButton.icon(
                    onPressed: () async {
                      final hintController = TextEditingController();
                      final result = await showDialog<String>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Ajouter un indice'),
                          content: TextField(
                            controller: hintController,
                            decoration: const InputDecoration(
                              labelText: 'Indice',
                              hintText: 'Entrez un indice supplémentaire',
                            ),
                            maxLines: 3,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Annuler'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, hintController.text),
                              child: const Text('Ajouter'),
                            ),
                          ],
                        ),
                      );
                      
                      if (result != null && result.isNotEmpty) {
                        setStateDialog(() {
                          hints.add(result);
                        });
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un indice'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    // Valider les entrées
                    final id = int.parse(idController.text);
                    final name = nameController.text;
                    final instruction = instructionController.text;
                    final code = codeController.text;
                    final codeLength = int.parse(codeLengthController.text);
                    final pointsReward = int.parse(pointsRewardController.text);
                    final timeLimit = int.parse(timeLimitController.text);
                    final hintCost = int.parse(hintCostController.text);
                    
                    if (name.isEmpty || instruction.isEmpty || code.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tous les champs sont obligatoires')),
                      );
                      return;
                    }
                    
                    final newLevel = Level(
                      id: id,
                      name: name,
                      instruction: instruction,
                      code: code,
                      codeLength: codeLength,
                      pointsReward: pointsReward,
                      isLocked: isEditing ? level!.isLocked : true,
                      timeLimit: timeLimit,
                      additionalHints: hints,
                      hintCost: hintCost,
                    );
                    
                    if (isEditing) {
                      await _levelService.updateLevel(newLevel);
                    } else {
                      await _levelService.addLevel(newLevel);
                    }
                    
                    Navigator.pop(context);
                    _loadLevels();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                },
                child: Text(isEditing ? 'Modifier' : 'Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Future<void> _confirmDeleteLevel(Level level) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le niveau'),
        content: Text('Êtes-vous sûr de vouloir supprimer le niveau "${level.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await _levelService.deleteLevel(level.id);
      _loadLevels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Administration des niveaux'),
          ),
          body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _levels.isEmpty
              ? const Center(child: Text('Aucun niveau disponible'))
              : ListView.builder(
                  itemCount: _levels.length,
                  itemBuilder: (context, index) {
                    final level = _levels[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(level.name),
                        subtitle: Text(
                          'ID: ${level.id} | Code: ${level.code} | Points: ${level.pointsReward}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showLevelDialog(level: level),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDeleteLevel(level),
                            ),
                          ],
                        ),
                        onTap: () {
                          // Afficher plus de détails
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(level.name),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Instruction: ${level.instruction}'),
                                    const SizedBox(height: 8),
                                    Text('Code: ${level.code} (${level.codeLength} chiffres)'),
                                    Text('Récompense: ${level.pointsReward} points'),
                                    Text('Temps limite: ${level.timeLimit} secondes'),
                                    Text('Coût des indices: ${level.hintCost} points'),
                                    Text('Statut: ${level.isLocked ? "Verrouillé" : "Débloqué"}'),
                                    const SizedBox(height: 8),
                                    const Text('Indices supplémentaires:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ...level.additionalHints.map((hint) => Padding(
                                      padding: const EdgeInsets.only(left: 8, top: 4),
                                      child: Text('• $hint'),
                                    )).toList(),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Fermer'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLevelDialog(),
        child: const Icon(Icons.add),
      ),
        ),
      ),
    );
  }
} 