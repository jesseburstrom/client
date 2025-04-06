// backend/src/models/Player.ts

import { BoardCell } from './BoardCell';
import { GameConfig, getBaseGameType } from '../utils/gameConfig';

export class Player {
  id: string;
  username: string;
  isActive: boolean;
  cells: BoardCell[]; // Player's scorecard cells
  score: number; // Total score
  upperSum: number; // Sum for bonus calculation
  bonusAchieved: boolean;

  // Game type needed for score calculation context
  private gameType: string;

  
  // --- Instance Methods ---

  private _countDice(diceValues: number[]): number[] {
    const counts = [0, 0, 0, 0, 0, 0]; // Counts for 1s to 6s
    for (const value of diceValues) {
        if (value >= 1 && value <= 6) {
            counts[value - 1]++;
        }
    }
    return counts;
}

private _calculateUpperSection(diceValues: number[], faceValue: number): number {
    let score = 0;
    for (const value of diceValues) {
        if (value === faceValue) {
            score += faceValue;
        }
    }
    return score;
}

private _calculatePairScore(diceValues: number[]): number {
    const counts = this._countDice(diceValues);
    for (let i = 5; i >= 0; i--) { // Check from 6s down
        if (counts[i] >= 2) {
            return (i + 1) * 2;
        }
    }
    return 0;
}

 private _calculateTwoPairsScore(diceValues: number[]): number {
    const counts = this._countDice(diceValues);
    let firstPairValue = 0;
    let score = 0;
    let pairsFound = 0;
    for (let i = 5; i >= 0; i--) {
        if (counts[i] >= 2) {
            score += (i + 1) * 2;
            pairsFound++;
             if (pairsFound === 2) return score; // Found two pairs
             // Ensure we don't count four-of-a-kind as two pairs unless it's Maxi 3+3 house
             if (counts[i] < 4 || this.gameType.startsWith("Maxi")) { // Allow 4+ for Maxi potentially
                // Continue searching for second distinct pair
             } else {
                 // Ordinary Yatzy: 4-of-a-kind only counts as one pair here
                 return 0; // Or handle based on specific rules interpretation
             }
        }
    }
    return pairsFound === 2 ? score : 0;
}

 private _calculateThreeOfKindScore(diceValues: number[]): number {
    const counts = this._countDice(diceValues);
    for (let i = 5; i >= 0; i--) {
        if (counts[i] >= 3) {
            return (i + 1) * 3;
        }
    }
    return 0;
}

private _calculateFourOfKindScore(diceValues: number[]): number {
    const counts = this._countDice(diceValues);
    for (let i = 5; i >= 0; i--) {
        if (counts[i] >= 4) {
            return (i + 1) * 4;
        }
    }
    return 0;
}

private _calculateFullHouseScore(diceValues: number[]): number {
    const counts = this._countDice(diceValues);
    let foundThree = false;
    let foundTwo = false;
    let score = 0;
    let threeValue = -1;

    for (let i = 0; i < 6; i++) {
        if (counts[i] === 3) {
            foundThree = true;
            score += (i + 1) * 3;
            threeValue = i;
            break; // Found the three-of-a-kind part
        }
    }
    if (!foundThree) return 0; // No three-of-a-kind found

    for (let i = 0; i < 6; i++) {
         // Make sure the pair is different from the three-of-a-kind
        if (counts[i] === 2 && i !== threeValue) {
            foundTwo = true;
            score += (i + 1) * 2;
            break; // Found the pair part
        }
    }

    return foundThree && foundTwo ? score : 0;
}

private _calculateSmallStraightScore(diceValues: number[]): number {
    const uniqueSorted = [...new Set(diceValues)].sort((a, b) => a - b);
    // Check for 1, 2, 3, 4, 5
    if (uniqueSorted.includes(1) && uniqueSorted.includes(2) && uniqueSorted.includes(3) && uniqueSorted.includes(4) && uniqueSorted.includes(5)) {
         // Maxi Yatzy score for small straight is 15
        // Ordinary Yatzy score for small straight is 15
        return 15;
    }
    return 0;
}

private _calculateLargeStraightScore(diceValues: number[]): number {
    const uniqueSorted = [...new Set(diceValues)].sort((a, b) => a - b);
     // Check for 2, 3, 4, 5, 6
    if (uniqueSorted.includes(2) && uniqueSorted.includes(3) && uniqueSorted.includes(4) && uniqueSorted.includes(5) && uniqueSorted.includes(6)) {
         // Maxi Yatzy score for large straight is 20
        // Ordinary Yatzy score for large straight is 20
        return 20;
    }
    return 0;
}

private _calculateChanceScore(diceValues: number[]): number {
    return diceValues.reduce((sum, val) => sum + val, 0);
}

 private _calculateYatzyScore(diceValues: number[]): number {
    const counts = this._countDice(diceValues);
    const config = GameConfig[getBaseGameType(this.gameType)];
    const requiredCount = config.diceCount; // 5 for Ordinary, 6 for Maxi

    for (let i = 0; i < 6; i++) {
        if (counts[i] >= requiredCount) {
            return config.cellLabels.includes('Maxi Yatzy') ? 100 : 50; // Maxi Yatzy or Ordinary Yatzy score
        }
    }
    return 0;
}

// *** Add Maxi-specific calculations here ***
private _calculateThreePairsScore(diceValues: number[]): number {
     if (!this.gameType.startsWith('Maxi')) return 0; // Only for Maxi
     const counts = this._countDice(diceValues);
     let pairsFound = 0;
     let score = 0;
     for (let i = 5; i >= 0; i--) {
         if (counts[i] >= 2) {
             score += (i + 1) * 2;
             pairsFound++;
             if (counts[i] >= 4) pairsFound++; // A 4-of-a-kind counts as two pairs
             if (counts[i] >= 6) pairsFound++; // A 6-of-a-kind counts as three pairs
         }
     }
     return pairsFound >= 3 ? score : 0;
 }

 private _calculateFiveOfKindScore(diceValues: number[]): number {
     if (!this.gameType.startsWith('Maxi')) return 0; // Only for Maxi
     const counts = this._countDice(diceValues);
     for (let i = 5; i >= 0; i--) {
         if (counts[i] >= 5) {
             return (i + 1) * 5;
         }
     }
     return 0;
 }

 private _calculateFullStraightScore(diceValues: number[]): number {
     if (!this.gameType.startsWith('Maxi')) return 0; // Only for Maxi
     const uniqueSorted = [...new Set(diceValues)].sort((a, b) => a - b);
     // Check for 1, 2, 3, 4, 5, 6
     if (uniqueSorted.length === 6 && uniqueSorted[0] === 1 && uniqueSorted[5] === 6) {
         return 21; // Or 30 based on rules (1+2+3+4+5+6 or fixed value) - Let's use 30 based on Maxi Yatzy online
         //return 30;
         // Client calc uses 1+2+3+4+5+6 = 21
         return 21;
     }
     return 0;
 }

 private _calculateHouse32Score(diceValues: number[]): number {
      // Same logic as standard Full House
     return this._calculateFullHouseScore(diceValues);
 }

 private _calculateHouse33Score(diceValues: number[]): number {
     if (!this.gameType.startsWith('Maxi')) return 0; // Only for Maxi
     const counts = this._countDice(diceValues);
     let threesFound = 0;
     let score = 0;
     for (let i = 5; i >= 0; i--) {
         if (counts[i] === 3) {
             score += (i + 1) * 3;
             threesFound++;
         }
     }
     return threesFound === 2 ? score : 0;
 }

  private _calculateHouse24Score(diceValues: number[]): number {
     if (!this.gameType.startsWith('Maxi')) return 0; // Only for Maxi
     const counts = this._countDice(diceValues);
     let foundFour = false;
     let foundTwo = false;
     let score = 0;
     let fourValue = -1;

     for (let i = 0; i < 6; i++) {
         if (counts[i] >= 4) { // Allow 4 or more
             foundFour = true;
             score += (i + 1) * 4;
             fourValue = i;
             break;
         }
     }
     if (!foundFour) return 0;

     for (let i = 0; i < 6; i++) {
         if (counts[i] >= 2 && i !== fourValue) { // Allow 2 or more, but different value
             foundTwo = true;
             score += (i + 1) * 2;
             break;
         }
     }
     return foundFour && foundTwo ? score : 0;
 }

  // Map labels to calculation functions
  private _getScoreFunction(label: string): (dice: number[]) => number {
    switch (label) {
        case 'Ones': return (d) => this._calculateUpperSection(d, 1);
        case 'Twos': return (d) => this._calculateUpperSection(d, 2);
        case 'Threes': return (d) => this._calculateUpperSection(d, 3);
        case 'Fours': return (d) => this._calculateUpperSection(d, 4);
        case 'Fives': return (d) => this._calculateUpperSection(d, 5);
        case 'Sixes': return (d) => this._calculateUpperSection(d, 6);
        case 'Pair': return this._calculatePairScore.bind(this);
        case 'Two Pairs': return this._calculateTwoPairsScore.bind(this);
        case 'Three of Kind': return this._calculateThreeOfKindScore.bind(this);
        case 'Four of Kind': return this._calculateFourOfKindScore.bind(this);
        case 'House': return this._calculateFullHouseScore.bind(this); // Ordinary House maps to standard Full House
        case 'Small Straight': return this._calculateSmallStraightScore.bind(this);
        case 'Large Straight': return this._calculateLargeStraightScore.bind(this);
        case 'Chance': return this._calculateChanceScore.bind(this);
        case 'Yatzy': return this._calculateYatzyScore.bind(this);
        // Maxi Specific
        case 'Three Pairs': return this._calculateThreePairsScore.bind(this);
        case 'Five of Kind': return this._calculateFiveOfKindScore.bind(this);
        case 'Full Straight': return this._calculateFullStraightScore.bind(this);
        case 'House 3-2': return this._calculateHouse32Score.bind(this); // Maps to standard Full House
        case 'House 3-3': return this._calculateHouse33Score.bind(this);
        case 'House 2-4': return this._calculateHouse24Score.bind(this);
        case 'Maxi Yatzy': return this._calculateYatzyScore.bind(this); // Uses gameType context
        default: return () => 0; // Default for Sum, Bonus, Total or unknown
    }
}

constructor(
    id: string,
    username: string,
    gameType: string = 'Ordinary',
    isActive: boolean = true,
    cells?: BoardCell[],
    score: number = 0,
    upperSum: number = 0,
    bonusAchieved: boolean = false,
  ) {
    this.id = id;
    this.username = username;
    this.gameType = gameType; // Store gameType
    this.isActive = isActive;

    const config = GameConfig[getBaseGameType(this.gameType)];
    // Initialize cells if not provided
    if (cells) {
      this.cells = cells;
      // --- ADDED: Ensure non-score cells are marked fixed even when loading existing cells ---
      
      this.cells.forEach(cell => {
        if (config.nonNumericCells.includes(cell.label)) {
          cell.fixed = true; // Mark Sum, Bonus, Total as fixed
        }
      });
      // --- END ADDED ---
    } else {
        // Initialize cells
        this.cells = config.cellLabels.map((label, index) => {
            const isNonScore = config.nonNumericCells.includes(label);
            const cell = new BoardCell(index, label, isNonScore);
            if (isNonScore) {
              cell.fixed = true; // Mark Sum, Bonus, Total fixed from start
               // *** Set initial Bonus deficit ***
               if (label === 'Bonus') {
                   cell.value = 0 - config.bonusThreshold; // e.g., -63 or -84
               }
            }
            return cell;
          });
    
     // Initial calculation for Sum, Total (Bonus already has deficit)
     this.calculateScores();
    }

    this.score = score;
    this.upperSum = upperSum;
    this.bonusAchieved = bonusAchieved;
  }

/**
     * Calculates potential scores for the current dice roll for unfixed cells.
     * Stores the result in cell.value for unfixed, non-special cells.
     */
    calculatePotentialScores(diceValues: number[]): void {
        if (!diceValues || diceValues.length === 0 || diceValues.every(d => d === 0)) {
            // If dice are cleared (e.g., [0,0,0,0,0]), clear potential scores instead
            this.clearPotentialScores();
            return;
        }
        // console.log(`[Player ${this.username}] Calculating potential scores for dice: [${diceValues.join(', ')}]`);
        this.cells.forEach(cell => {
            if (cell && !cell.fixed && !cell.isNonScoreCell) {
                const calculateFunc = this._getScoreFunction(cell.label);
                cell.value = calculateFunc(diceValues);
            }
        });
        // DO NOT calculate derived scores here, potential scores shouldn't affect Sum/Total yet
    }
/**
 * Resets the value of non-fixed, non-special cells to -1.
 * Typically called when the turn changes.
 */
clearPotentialScores(): void {
    console.log(`[Player ${this.username}] Clearing potential scores.`);
    this.cells.forEach(cell => {
        if (cell && !cell.fixed && !cell.isNonScoreCell) {
            cell.value = -1;
        }
    });
    // Also recalculate derived scores to ensure Bonus deficit etc. is shown correctly
    this.calculateScores();
}

calculateScores(): void {
    const config = GameConfig[getBaseGameType(this.gameType)];
    let currentUpperSum = 0; // Use a local variable for calculation
    let currentTotalScore = 0; // Use a local variable for calculation
    let isBonusAchieved = false; // Use a local variable

    // Find indices reliably, check for existence
    const sumCellIndex = this.cells.findIndex(c => c?.label === 'Sum');
    const bonusCellIndex = this.cells.findIndex(c => c?.label === 'Bonus');
    const totalCellIndex = this.cells.findIndex(c => c?.label === 'Total');

    // --- STEP 1: Calculate Upper Sum ---
    for (let i = 0; i <= config.upperSectionEndIndex; i++) {
        const cell = this.cells[i];
        // Only add value if the cell is fixed *by player selection* and has a positive value
        if (cell && cell.fixed && !cell.isNonScoreCell && cell.value > 0) {
            currentUpperSum += cell.value;
        }
    }

    // --- STEP 2: Update Sum Cell ---
    if (sumCellIndex !== -1 && this.cells[sumCellIndex]) {
       this.cells[sumCellIndex].value = currentUpperSum;
       this.cells[sumCellIndex].fixed = true; // Ensure fixed
       this.cells[sumCellIndex].isNonScoreCell = true; // Ensure flagged
    }

    // --- STEP 3: Determine and Update Bonus Cell ---
     isBonusAchieved = currentUpperSum >= config.bonusThreshold;
    if (bonusCellIndex !== -1 && this.cells[bonusCellIndex]) {
        let bonusValue = 0;
        if (isBonusAchieved) {
            bonusValue = config.bonusAmount;
        } else {
            // Check if all upper section cells are fixed *by player selection*
            const allUpperFixed = this.cells
                .slice(0, config.upperSectionEndIndex + 1)
                .every(c => c?.fixed && !c.isNonScoreCell); // Exclude Sum cell itself if within range

            bonusValue = allUpperFixed ? 0 : currentUpperSum - config.bonusThreshold; // Show deficit only if not all upper cells are fixed
        }
        this.cells[bonusCellIndex].value = bonusValue;
        this.cells[bonusCellIndex].fixed = true; // Ensure fixed
        this.cells[bonusCellIndex].isNonScoreCell = true; // Ensure flagged
    }

    // --- STEP 4: Calculate Total Score ---
    currentTotalScore = currentUpperSum; // Start with upper sum
    if (isBonusAchieved) {
        currentTotalScore += config.bonusAmount; // Add actual bonus amount if achieved
    }

    // Add lower section scores (cells after bonus up to total)
    const lowerSectionStartIndex = (bonusCellIndex !== -1 ? bonusCellIndex : config.upperSectionEndIndex) + 1;
    const lowerSectionEndIndex = (totalCellIndex !== -1 ? totalCellIndex : this.cells.length) -1;

    for (let i = lowerSectionStartIndex; i <= lowerSectionEndIndex; i++) {
        const cell = this.cells[i];
         // Only add value if fixed *by player selection* and positive
        if (cell && cell.fixed && !cell.isNonScoreCell && cell.value > 0) {
            currentTotalScore += cell.value;
        }
    }

     // --- STEP 5: Update Total Cell ---
     if (totalCellIndex !== -1 && this.cells[totalCellIndex]) {
         this.cells[totalCellIndex].value = currentTotalScore;
         this.cells[totalCellIndex].fixed = true; // Ensure fixed
         this.cells[totalCellIndex].isNonScoreCell = true; // Ensure flagged
     }

    // --- STEP 6: Update Player's overall score properties ---
    this.upperSum = currentUpperSum; // Store calculated upper sum
    this.score = currentTotalScore;   // Store calculated total score
    this.bonusAchieved = isBonusAchieved; // Store bonus status

    // console.log(`-> Recalculated scores for ${this.username}: UpperSum=${this.upperSum}, Bonus=${this.bonusAchieved}, Total=${this.score}`);
}
  hasCompletedGame(): boolean {
      // Check if all selectable cells are fixed
      return this.cells.every(cell => cell.fixed || cell.isNonScoreCell);
  }

  getScore(): number {
      // Score is updated by calculateScores, return the current value
      return this.score;
  }

  calculateDerivedScores(): void {
    const config = GameConfig[getBaseGameType(this.gameType)];
    let currentUpperSum = 0;
    let currentTotalScore = 0;
    let isBonusAchieved = false;

    const sumCellIndex = this.cells.findIndex(c => c?.label === 'Sum');
    const bonusCellIndex = this.cells.findIndex(c => c?.label === 'Bonus');
    const totalCellIndex = this.cells.findIndex(c => c?.label === 'Total');

    // --- Calculate Upper Sum from player-fixed cells ---
    for (let i = 0; i <= config.upperSectionEndIndex; i++) {
        const cell = this.cells[i];
        // Include only positive values from cells fixed by the player
        if (cell && cell.fixed && !cell.isNonScoreCell && cell.value > 0) {
            currentUpperSum += cell.value;
        }
    }

    // --- Update Sum Cell (value only) ---
    if (sumCellIndex !== -1 && this.cells[sumCellIndex]) {
       this.cells[sumCellIndex].value = currentUpperSum;
       this.cells[sumCellIndex].fixed = true; // Ensure fixed
    }

    // --- Update Bonus Cell (value only) ---
    isBonusAchieved = currentUpperSum >= config.bonusThreshold;
    if (bonusCellIndex !== -1 && this.cells[bonusCellIndex]) {
        let bonusValue = 0;
        if (isBonusAchieved) {
            bonusValue = config.bonusAmount;
        } else {
            const allUpperSelectableFixed = this.cells
                .slice(0, config.upperSectionEndIndex + 1)
                .every(c => !c || c.isNonScoreCell || c.fixed); // Check only player-selectable fixed status
            bonusValue = allUpperSelectableFixed ? 0 : currentUpperSum - config.bonusThreshold;
        }
        this.cells[bonusCellIndex].value = bonusValue;
        this.cells[bonusCellIndex].fixed = true; // Ensure fixed
    }

    // --- Calculate Total Score from player-fixed cells + bonus ---
    currentTotalScore = currentUpperSum;
    if (isBonusAchieved) {
        currentTotalScore += config.bonusAmount;
    }
    const lowerSectionStartIndex = (bonusCellIndex !== -1 ? bonusCellIndex : config.upperSectionEndIndex) + 1;
    const lowerSectionEndIndex = (totalCellIndex !== -1 ? totalCellIndex : this.cells.length) -1;
    for (let i = lowerSectionStartIndex; i <= lowerSectionEndIndex; i++) {
        const cell = this.cells[i];
         // Include only positive values from cells fixed by the player
        if (cell && cell.fixed && !cell.isNonScoreCell && cell.value > 0) {
            currentTotalScore += cell.value;
        }
    }

   // --- Update Total Cell (value only) ---
   if (totalCellIndex !== -1 && this.cells[totalCellIndex]) {
       this.cells[totalCellIndex].value = currentTotalScore;
       this.cells[totalCellIndex].fixed = true; // Ensure fixed
   }

  // --- Update Player aggregate scores ---
  this.upperSum = currentUpperSum;
  this.score = currentTotalScore;
  this.bonusAchieved = isBonusAchieved;
}

  toJSON(): any {
       return {
           id: this.id,
           username: this.username,
           isActive: this.isActive,
           cells: this.cells.map(cell => cell.toJSON()),
           score: this.score,
           upperSum: this.upperSum,
           bonusAchieved: this.bonusAchieved,
           // Include gameType if needed for deserialization context, though fromJson handles it
           // gameType: this.gameType
       };
   }

   // --- Static Methods ---

   static fromJSON(data: any, gameType: string = 'Ordinary'): Player {
        const config = GameConfig[getBaseGameType(gameType)];
        const cells = data.cells ? data.cells.map((cellData: any, index: number) =>
            BoardCell.fromJson(cellData, config.cellLabels[index])
        ) : undefined; // Let constructor initialize if not present

        return new Player(
            data.id,
            data.username,
            gameType, // Pass gameType to constructor
            data.isActive,
            cells,
            data.score ?? 0,
            data.upperSum ?? 0,
            data.bonusAchieved ?? false,
        );
    }
}


// Factory remains useful for creating standard instances easily
export class PlayerFactory {
  static createPlayer(id: string, username: string, gameType: string = 'Ordinary'): Player {
      // --- Simplification: Ensure only allowed types are created ---
  const baseType = getBaseGameType(gameType);
  const allowedTypes = ['Ordinary', 'Mini', 'Maxi'];
  if (!allowedTypes.includes(baseType as string)) {
       console.warn(`[PlayerFactory] Attempting to create player for invalid base type derived from ${gameType}. Using Ordinary.`);
       gameType = 'Ordinary'; // Default to Ordinary if invalid type provided
  }
  // --- End Simplification ---
    return new Player(id, username, gameType);
  }

  static createEmptyPlayer(gameType: string = 'Ordinary'): Player {
    // Create an inactive player instance
     // --- Simplification: Ensure only allowed types are created ---
    const baseType = getBaseGameType(gameType);
    const allowedTypes = ['Ordinary', 'Mini', 'Maxi'];
    if (!allowedTypes.includes(baseType as string)) {
         console.warn(`[PlayerFactory] Attempting to create empty player for invalid base type derived from ${gameType}. Using Ordinary.`);
         gameType = 'Ordinary'; // Default to Ordinary if invalid type provided
    }
    // --- End Simplification ---
    const config = GameConfig[getBaseGameType(gameType)];
    const cells = config.cellLabels.map((label, index) =>
        new BoardCell(index, label, config.nonNumericCells.includes(label))
    );
    return new Player("", "", gameType, false, cells);
  }
}
