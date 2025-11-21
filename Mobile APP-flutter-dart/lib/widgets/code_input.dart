import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeInput extends StatefulWidget {
  final int codeLength;
  final Function(String) onCompleted;

  const CodeInput({
    super.key,
    required this.codeLength,
    required this.onCompleted,
  });

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  // Liste des chiffres du code
  List<String> _digits = [];
  // Contrôleurs pour chaque chiffre
  List<TextEditingController> _controllers = [];
  // Nœuds de focus pour chaque chiffre
  List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    
    // Initialiser les listes avec la taille appropriée
    _digits = List.filled(widget.codeLength, '');
    _controllers = List.generate(widget.codeLength, (_) => TextEditingController());
    _focusNodes = List.generate(widget.codeLength, (_) => FocusNode());
    
    // Donner le focus au premier champ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  void _reinitializeControllers() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }

    _digits = List.filled(widget.codeLength, '');
    _controllers = List.generate(widget.codeLength, (_) => TextEditingController());
    _focusNodes = List.generate(widget.codeLength, (_) => FocusNode());
  }

  @override
  void didUpdateWidget(covariant CodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.codeLength != widget.codeLength) {
      _reinitializeControllers();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_focusNodes.isNotEmpty) {
          _focusNodes[0].requestFocus();
        }
      });
      setState(() {});
    }
  }

  @override
  void dispose() {
    // Libérer les ressources
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Gérer la saisie d'un chiffre
  void _onDigitChanged(String value, int index) {
    if (value.isEmpty) {
      setState(() {
        _digits[index] = '';
      });
      return;
    }
    
    // Prendre seulement le dernier caractère si plusieurs sont entrés
    final lastChar = value[value.length - 1];
    
    if (RegExp(r'[0-9]').hasMatch(lastChar)) {
      setState(() {
        _digits[index] = lastChar;
        _controllers[index].text = lastChar;
      });
      
      // Passer au champ suivant si ce n'est pas le dernier
      if (index < widget.codeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Si c'est le dernier chiffre, soumettre le code
        _submitCode();
      }
    }
  }
  
  // Soumettre le code complet
  void _submitCode() {
    final code = _digits.join();
    if (code.length == widget.codeLength) {
      widget.onCompleted(code);
    }
  }
  
  // Effacer le dernier chiffre saisi
  void _deleteLastDigit() {
    // Trouver le dernier chiffre non vide
    int lastIndex = -1;
    for (int i = widget.codeLength - 1; i >= 0; i--) {
      if (_digits[i].isNotEmpty) {
        lastIndex = i;
        break;
      }
    }
    
    if (lastIndex >= 0) {
      setState(() {
        _digits[lastIndex] = '';
        _controllers[lastIndex].clear();
        // Forcer la mise à jour du contrôleur
        _controllers[lastIndex].value = TextEditingValue.empty;
      });
      
      // Donner le focus au champ qui vient d'être effacé
      _focusNodes[lastIndex].requestFocus();
    } else if (_digits.isNotEmpty) {
      // Si tous les champs sont vides, donner le focus au premier champ
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Déterminer si nous avons besoin de deux lignes
    final needsTwoRows = widget.codeLength > 5;
    final firstRowCount = needsTwoRows ? 5 : widget.codeLength;
    final secondRowCount = needsTwoRows ? widget.codeLength - 5 : 0;
    
    // Calculer la taille optimale des cases en fonction de la largeur de l'écran
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 48; // Tenir compte du padding
    final boxWidth = (availableWidth / 5) - 10; // 5 cases max par ligne avec marge
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Première ligne de cases (maximum 5)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            firstRowCount,
            (index) => _buildDigitBox(index, boxWidth),
          ),
        ),
        
        // Deuxième ligne de cases si nécessaire
        if (needsTwoRows) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              secondRowCount,
              (index) => _buildDigitBox(index + 5, boxWidth),
            ),
          ),
        ],
        
        const SizedBox(height: 20),
        // Bouton Effacer
        SizedBox(
          width: 120,
          child: ElevatedButton.icon(
            onPressed: _deleteLastDigit,
            icon: const Icon(Icons.backspace, color: Colors.white),
            label: const Text('Effacer', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // Construire une case pour un chiffre
  Widget _buildDigitBox(int index, double width) {
    return Container(
      width: width,
      height: width * 1.2, // Hauteur proportionnelle à la largeur
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _focusNodes[index].hasFocus ? Colors.blue : Colors.grey,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        showCursor: false,
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: TextStyle(
          color: Colors.white,
          fontSize: width * 0.5, // Taille de police proportionnelle à la largeur
          fontWeight: FontWeight.bold,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (value) => _onDigitChanged(value, index),
      ),
    );
  }
} 