import 'package:flutter/material.dart';

class SpectatorGameBoard extends StatefulWidget {
  final Map<String, dynamic> gameData;

  const SpectatorGameBoard({super.key, required this.gameData});

  @override
  State<SpectatorGameBoard> createState() => _SpectatorGameBoardState();
}

class _SpectatorGameBoardState extends State<SpectatorGameBoard> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(
        '🎲 Building spectator board. Game Finished: ${widget.gameData['gameFinished']}');

    // --- Safely Extract Data ---
    final List<dynamic> playersData =
        widget.gameData['players'] as List<dynamic>? ?? [];
    final List<String> playerNames =
        playersData.map((p) => p?['username']?.toString() ?? 'P?').toList();
    final int numPlayers =
        playerNames.length; // Get actual number of players from data

    final int currentRoll = widget.gameData['rollCount'] ?? 0;
    final List<int> diceValues =
        (widget.gameData['diceValues'] as List<dynamic>?)
                ?.map((d) => d is int ? d : 0) // Ensure integers
                .toList() ??
            [];
    final bool isFinished = widget.gameData['gameFinished'] ?? false;
    final int playerToMove =
        widget.gameData['playerToMove'] ?? -1; // Get whose turn it is

    // Basic check if data seems valid
    if (numPlayers == 0) {
      return const Center(
          child: Text("Waiting for player data...",
              style: TextStyle(color: Colors.orange)));
    }
    // --- End Data Extraction ---

    return Stack(
      children: [
        Column(
          children: [
            // Game status header (Highlight current player?)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50, // Light blue background
                border: Border(
                  bottom: BorderSide(
                      color: Colors.blue.shade200, width: 1.0), // Bottom border
                ),
                // Optional: Add subtle shadow
                // boxShadow: [
                //   BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: Offset(0, 2))
                //],
              ),
              child: Column(
                children: [
                  Text(
                    "Spectating Game #${widget.gameData['gameId'] ?? '?'}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  // Indicate whose turn it is
                  Text(
                    playerToMove >= 0 && playerToMove < playerNames.length
                        ? "${playerNames[playerToMove]}'s Turn (Roll #$currentRoll)"
                        : "Roll #$currentRoll",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue.shade700, // Highlight turn info
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Dice row
            if (diceValues.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                color: Colors.grey.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...List.generate(diceValues.length, (index) {
                      // Get the dice value (1-6)
                      int value = diceValues[index];
                      // Only display valid dice values
                      if (value < 1 || value > 6)
                        return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                spreadRadius: 1,
                                blurRadius: 2,
                                offset: const Offset(1, 1),
                              ),
                            ],
                          ),
                          child: Center(
                            child: getDiceFace(value),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            // Game board content - Use Expanded and Scrolling
            Expanded(
              child: RawScrollbar(
                controller: _verticalScrollController,
                thumbColor: Colors.blue.shade300,
                radius: const Radius.circular(20),
                thickness: 8,
                thumbVisibility: true,
                child: RawScrollbar(
                  controller: _horizontalScrollController,
                  thumbColor: Colors.blue.shade300,
                  radius: const Radius.circular(20),
                  thickness: 8,
                  thumbVisibility: true,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  child: SingleChildScrollView(
                    controller: _verticalScrollController,
                    child: SingleChildScrollView(
                      controller: _horizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      // *** Pass player data to buildScoreTable ***
                      child: buildScoreTable(
                          playerNames, playersData, playerToMove),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // **** Game Finished Overlay ****
        if (isFinished) // Check if the game data indicates the game is finished
          Positioned.fill(
            // Makes the overlay cover the entire parent Stack area
            child: Container(
              // Semi-transparent background to dim the game board underneath
              color: Colors.black.withOpacity(0.6), // Adjust opacity as desired
              child: Center(
                // Center the pop-up message box
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white, // White background for the message box
                    borderRadius: BorderRadius.circular(12), // Rounded corners
                    boxShadow: const [
                      // Subtle shadow for depth
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          spreadRadius: 2)
                    ],
                  ),
                  child: const Column(
                    // Arrange text vertically
                    mainAxisSize: MainAxisSize.min,
                    // Make the box wrap content height
                    children: [
                      Text(
                        'GAME OVER',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors
                                .redAccent // Distinct color for "Game Over"
                            ),
                      ),
                      SizedBox(height: 10), // Spacing
                      Text(
                        "The game has concluded.",
                        // You can customize this message
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      SizedBox(height: 4), // Spacing
                      Text(
                        "(You can stop spectating via the settings menu)",
                        // Optional hint
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // **** End Game Finished Overlay ****
      ],
    );
  }

  // Modify buildScoreTable to accept playersData and playerToMove
  Widget buildScoreTable(
      List<String> playerNames, List<dynamic> playersData, int playerToMove) {
    // Define score categories (adjust indices if gameType changes - need gameType from gameData)
    final String gameType =
        widget.gameData['gameType'] ?? 'Ordinary'; // Get game type
    final List<ScoreCategory> categories =
        _getCategoriesForGameType(gameType); // Helper function below

    // --- ADJUST COLUMN WIDTHS ---
    // Calculate width based on number of players
    final double categoryWidth = 150; // Width for the category names
    final double scoreWidth = 80; // Width for each player's score column
    final Map<int, TableColumnWidth> columnWidths = {
      0: FixedColumnWidth(categoryWidth), // Category column
    };
    for (int i = 0; i < playerNames.length; i++) {
      columnWidths[i + 1] = FixedColumnWidth(scoreWidth); // Player columns
    }
    // ---------------------------

    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: columnWidths, // Use dynamic widths
        border: TableBorder.all(color: Colors.blue.shade200, width: 1),
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(color: Colors.blue.shade100),
            children: [
              _buildHeaderCell('Category'), // Header cell helper below
              // Player name headers - Highlight current player
              ...List.generate(playerNames.length, (index) {
                return _buildHeaderCell(playerNames[index],
                    isHighlighted:
                        index == playerToMove // Highlight if it's their turn
                    );
              }),
            ],
          ),

          // Score rows
          ...categories.map((category) {
            return TableRow(
              decoration: BoxDecoration(
                // Optional: Highlight rows like Sum/Bonus/Total
                color: category.isHighlighted
                    ? Colors.grey.shade200.withOpacity(0.5)
                    : Colors.transparent,
              ),
              children: [
                // Category name cell
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 6.0), // Adjust padding
                    child: Text(
                      category.displayName,
                      style: TextStyle(
                          fontWeight: category.isHighlighted
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13), // Adjust font size
                    ),
                  ),
                ),

                // Player score cells
                ...List.generate(playerNames.length, (playerIndex) {
                  int? score;
                  bool isFixed = false; // Is the score fixed for this player?
                  if (playerIndex < playersData.length &&
                      playersData[playerIndex]?['cells'] is List) {
                    List<dynamic> cells = playersData[playerIndex]['cells'];
                    if (category.index < cells.length &&
                        cells[category.index] != null) {
                      var cellData = cells[category.index];
                      int cellValue = cellData['value'] ?? -1;
                      // Only display positive scores or the Bonus value
                      if (cellValue != -1 || category.index == 7) {
                        // Index 7 is Bonus
                        score = cellValue;
                      }
                      isFixed = cellData['fixed'] ?? false;
                    }
                  }

                  // Determine background color
                  Color bgColor = Colors.transparent;
                  if (isFixed && !category.isHighlighted) {
                    // If score is set and not Sum/Bonus/Total
                    bgColor = Colors.lightGreen
                        .withAlpha(100); // Use a subtle fixed color
                  } else if (playerIndex == playerToMove &&
                      !isFixed &&
                      !category.isHighlighted) {
                    // Optional: Highlight available cells for current player slightly?
                    // bgColor = Colors.yellow.withAlpha(50);
                  }

                  return TableCell(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      alignment: Alignment.center,
                      color: bgColor,
                      child: Text(
                        score?.toString() ?? '',
                        // Display score or empty string
                        style: TextStyle(
                          fontWeight: category.isHighlighted
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13, // Adjust font size
                          // Optional: Dim text if not fixed?
                          color: isFixed || category.isHighlighted
                              ? Colors.black87
                              : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }

  // Helper for header cells
  Widget _buildHeaderCell(String text, {bool isHighlighted = false}) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Container(
        color: isHighlighted ? Colors.green.shade200 : Colors.transparent,
        // Highlight background
        padding: const EdgeInsets.all(8.0),
        child: Text(
          text,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isHighlighted
                  ? Colors.black
                  : Colors.black87 // Highlight text
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Helper to get categories based on game type
  List<ScoreCategory> _getCategoriesForGameType(String gameType) {
    if (gameType.startsWith('Maxi')) {
      return [
        ScoreCategory('Ones', 0, false),
        ScoreCategory('Twos', 1, false),
        ScoreCategory('Threes', 2, false),
        ScoreCategory('Fours', 3, false),
        ScoreCategory('Fives', 4, false),
        ScoreCategory('Sixes', 5, false),
        ScoreCategory('Sum', 6, true),
        ScoreCategory('Bonus (100)', 7, true),
        // Update bonus text
        ScoreCategory('Pair', 8, false),
        ScoreCategory('Two Pairs', 9, false),
        ScoreCategory('Three Pairs', 10, false),
        ScoreCategory('Three of Kind', 11, false),
        ScoreCategory('Four of Kind', 12, false),
        ScoreCategory('Five of Kind', 13, false),
        ScoreCategory('Small Straight', 14, false),
        ScoreCategory('Large Straight', 15, false),
        ScoreCategory('Full Straight', 16, false),
        ScoreCategory('House 3-2', 17, false),
        ScoreCategory('House 3-3', 18, false),
        ScoreCategory('House 2-4', 19, false),
        ScoreCategory('Chance', 20, false),
        ScoreCategory('Maxi Yatzy', 21, false),
        ScoreCategory('Total', 22, true),
      ];
    } else {
      // Ordinary
      return [
        ScoreCategory('Ones', 0, false),
        ScoreCategory('Twos', 1, false),
        ScoreCategory('Threes', 2, false),
        ScoreCategory('Fours', 3, false),
        ScoreCategory('Fives', 4, false),
        ScoreCategory('Sixes', 5, false),
        ScoreCategory('Sum', 6, true),
        ScoreCategory('Bonus (63)', 7, true),
        // Update bonus text
        ScoreCategory('Pair', 8, false),
        ScoreCategory('Two Pairs', 9, false),
        ScoreCategory('Three of Kind', 10, false),
        ScoreCategory('Four of Kind', 11, false),
        ScoreCategory('House', 12, false),
        ScoreCategory('Small Straight', 13, false),
        ScoreCategory('Large Straight', 14, false),
        ScoreCategory('Chance', 15, false),
        ScoreCategory('Yatzy', 16, false),
        ScoreCategory('Total', 17, true),
      ];
    }
  }

  // Helper method to get dice face widget
  Widget getDiceFace(int value) {
    switch (value) {
      case 1:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      case 2:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ],
        );
      case 3:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ],
        );
      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ],
        );
      case 5:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ],
        );
      case 6:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// Helper class to organize score categories
class ScoreCategory {
  final String displayName;
  final int index;
  final bool isHighlighted;

  ScoreCategory(this.displayName, this.index, this.isHighlighted);
}
