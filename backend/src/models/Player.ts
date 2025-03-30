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
  regretsLeft?: number;
  extraMovesLeft?: number;

  // Game type needed for score calculation context
  private gameType: string;

  constructor(
    id: string,
    username: string,
    gameType: string = 'Ordinary',
    isActive: boolean = true,
    cells?: BoardCell[],
    score: number = 0,
    upperSum: number = 0,
    bonusAchieved: boolean = false,
    regretsLeft?: number,
    extraMovesLeft?: number
  ) {
    this.id = id;
    this.username = username;
    this.gameType = gameType; // Store gameType
    this.isActive = isActive;

    // Initialize regrets/extra moves based on gameType if not provided
    if (regretsLeft === undefined) {
        if (gameType === 'MaxiR3' || gameType === 'MaxiRE3') this.regretsLeft = 3;
    } else {
        this.regretsLeft = regretsLeft;
    }
    if (extraMovesLeft === undefined) {
        if (gameType === 'MaxiE3' || gameType === 'MaxiRE3') this.extraMovesLeft = 3;
    } else {
        this.extraMovesLeft = extraMovesLeft;
    }


    // Initialize cells if not provided
    if (cells) {
      this.cells = cells;
    } else {
      const config = GameConfig[getBaseGameType(gameType)];
      this.cells = config.cellLabels.map((label, index) =>
        new BoardCell(index, label, config.nonNumericCells.includes(label))
      );
    }

    this.score = score;
    this.upperSum = upperSum;
    this.bonusAchieved = bonusAchieved;
  }

  // --- Instance Methods ---

  calculateScores(): void {
      const config = GameConfig[getBaseGameType(this.gameType)];
      let upperSum = 0;
      let totalScore = 0;
      let bonusAchieved = false;

      // Calculate upper sum
      for (let i = 0; i <= config.upperSectionEndIndex; i++) {
          if (this.cells[i]?.fixed) {
              upperSum += this.cells[i].value;
          }
      }

      // Apply bonus
      const bonusCellIndex = this.cells.findIndex(c => c.label.toLowerCase().includes('bonus'));
      if (upperSum >= config.bonusThreshold) {
          totalScore += config.bonusAmount;
          bonusAchieved = true;
          if (bonusCellIndex !== -1) {
              this.cells[bonusCellIndex].value = config.bonusAmount;
          }
      } else {
             if (bonusCellIndex !== -1) {
                 const allUpperFixed = this.cells.slice(0, config.upperSectionEndIndex + 1).every(c => c?.fixed);
                 this.cells[bonusCellIndex].value = allUpperFixed ? 0 : upperSum - config.bonusThreshold;
             }
      }

      // Update sum cell
      const sumCellIndex = this.cells.findIndex(c => c.label.toLowerCase() === 'sum');
       if (sumCellIndex !== -1) {
           this.cells[sumCellIndex].value = upperSum;
       }

      // Calculate total score
      totalScore += upperSum;
      for (let i = config.upperSectionEndIndex + 1; i < this.cells.length; i++) {
            const cell = this.cells[i];
            if (cell) {
                const labelLower = cell.label.toLowerCase();
                if (labelLower !== 'sum' && !labelLower.includes('bonus') && labelLower !== 'total') {
                    if (cell.fixed) {
                        totalScore += cell.value;
                    }
                }
            }
      }

      // Update player state
      this.upperSum = upperSum;
      this.score = totalScore;
      this.bonusAchieved = bonusAchieved;

      // Update the total score cell
      const totalCellIndex = this.cells.findIndex(c => c.label.toLowerCase() === 'total');
      if (totalCellIndex !== -1) {
          this.cells[totalCellIndex].value = totalScore;
      }

      console.log(`-> Recalculated scores for ${this.username}: UpperSum=${upperSum}, Bonus=${bonusAchieved}, Total=${totalScore}`);
  }

  hasCompletedGame(): boolean {
      // Check if all selectable cells are fixed
      return this.cells.every(cell => cell.fixed || cell.isNonScoreCell);
  }

  getScore(): number {
      // Score is updated by calculateScores, return the current value
      return this.score;
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
           regretsLeft: this.regretsLeft,
           extraMovesLeft: this.extraMovesLeft,
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
            data.regretsLeft,
            data.extraMovesLeft
        );
    }
}


// Factory remains useful for creating standard instances easily
export class PlayerFactory {
  static createPlayer(id: string, username: string, gameType: string = 'Ordinary'): Player {
    return new Player(id, username, gameType);
  }

  static createEmptyPlayer(gameType: string = 'Ordinary'): Player {
    // Create an inactive player instance
    const config = GameConfig[getBaseGameType(gameType)];
    const cells = config.cellLabels.map((label, index) =>
        new BoardCell(index, label, config.nonNumericCells.includes(label))
    );
    return new Player("", "", gameType, false, cells);
  }
}
