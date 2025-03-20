import 'board_cell.dart';

/// Player model for Yatzy game
class Player {
  /// Unique identifier for the player (socket ID)
  final String id;
  
  /// Player's username
  final String username;
  
  /// Whether the player is active in the game
  bool isActive;
  
  /// Board cells for this player
  final List<BoardCell> cells;
  
  /// Total score for the player
  int _totalScore = 0;
  
  /// Sum of upper section (ones through sixes)
  int _upperSectionSum = 0;
  
  Player({
    required this.id,
    required this.username,
    this.isActive = true,
    required this.cells,
  });
  
  /// Get the total score for the player
  int get totalScore => _totalScore;
  
  /// Get the upper section sum (for bonus calculation)
  int get upperSectionSum => _upperSectionSum;
  
  /// Calculate scores based on cell values
  void calculateScores({
    required int bonusThreshold, 
    required int bonusAmount, 
    required int upperSectionEnd
  }) {
    // Calculate upper section sum (for bonus)
    _upperSectionSum = 0;
    for (int i = 0; i <= upperSectionEnd; i++) {
      if (cells[i].fixed && cells[i].value > 0) {
        _upperSectionSum += cells[i].value;
      }
    }
    
    // Calculate total score
    _totalScore = 0;
    for (final cell in cells) {
      if (cell.fixed && cell.value > 0) {
        _totalScore += cell.value;
      }
    }
    
    // Add bonus if applicable
    if (_upperSectionSum >= bonusThreshold) {
      _totalScore += bonusAmount;
    }
  }
  
  /// Clear all unfixed cells
  void clearUnfixedCells() {
    for (var cell in cells) {
      if (!cell.fixed) {
        cell.clear();
      }
    }
  }
  
  /// Check if player has completed all cells
  bool get hasCompletedGame {
    return cells.every((cell) => cell.fixed || cell.index == cells.length - 1); // Skip total sum cell
  }
  
  /// Create a player from JSON data
  factory Player.fromJson(Map<String, dynamic> json, List<String> cellLabels) {
    List<BoardCell> cells = List.generate(
      cellLabels.length,
      (index) => BoardCell(
        index: index,
        label: cellLabels[index],
        value: json['cellValues'] != null && json['cellValues'][index] != null 
            ? json['cellValues'][index]
            : -1,
        fixed: json['fixedCells'] != null && json['fixedCells'][index] != null
            ? json['fixedCells'][index]
            : false,
      ),
    );
    
    return Player(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      isActive: json['isActive'] ?? true,
      cells: cells,
    );
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'isActive': isActive,
      'cellValues': cells.map((cell) => cell.value).toList(),
      'fixedCells': cells.map((cell) => cell.fixed).toList(),
    };
  }
}
