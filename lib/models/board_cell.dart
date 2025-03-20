import 'package:flutter/material.dart';

/// Board cell for Yatzy game
class BoardCell {
  /// Index of the cell
  final int index;
  
  /// Label for the cell (e.g., "Ones", "Pair", etc.)
  final String label;
  
  /// Current value of the cell (-1 if not set)
  int value;
  
  /// Whether the cell is fixed (already selected)
  bool fixed;
  
  /// Position and size info
  double xPos = 0;
  double yPos = 0;
  double width = 0;
  double height = 0;
  
  /// Text color for the cell
  Color textColor = Colors.black;
  
  /// Background color for the cell
  Color backgroundColor = Colors.white;
  
  /// Whether the cell has focus
  bool hasFocus = false;
  
  BoardCell({
    required this.index, 
    required this.label,
    this.value = -1,
    this.fixed = false,
  });
  
  /// Set the position and size of the cell
  void setPosition(double x, double y, double w, double h) {
    xPos = x;
    yPos = y;
    width = w;
    height = h;
  }
  
  /// Convert cell value to display text
  String get displayText => value >= 0 ? value.toString() : "";
  
  /// Check if cell is empty (not set)
  bool get isEmpty => value < 0;
  
  /// Clear the cell value
  void clear() {
    if (!fixed) {
      value = -1;
      hasFocus = false;
    }
  }
  
  /// Set the value of the cell
  void setValue(int newValue) {
    if (!fixed) {
      value = newValue;
    }
  }
  
  /// Mark the cell as fixed
  void fix() {
    fixed = true;
    hasFocus = false;
  }
  
  /// Set focus state
  void setFocus(bool focused) {
    if (!fixed) {
      hasFocus = focused;
    }
  }
  
  /// Create a copy of the cell
  BoardCell copyWith({
    int? index,
    String? label,
    int? value,
    bool? fixed,
  }) {
    return BoardCell(
      index: index ?? this.index,
      label: label ?? this.label,
      value: value ?? this.value,
      fixed: fixed ?? this.fixed,
    )
      ..xPos = xPos
      ..yPos = yPos
      ..width = width
      ..height = height
      ..textColor = textColor
      ..backgroundColor = backgroundColor
      ..hasFocus = hasFocus;
  }
}
