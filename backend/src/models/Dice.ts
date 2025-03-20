/**
 * Model for dice operations in Yatzy
 */
export class Dice {
  private values: number[] = [];
  private readonly diceCount: number = 5;
  
  constructor(diceCount: number = 5) {
    this.diceCount = diceCount;
    this.reset();
  }
  
  /**
   * Roll all dice
   * @returns Array of dice values
   */
  roll(): number[] {
    for (let i = 0; i < this.diceCount; i++) {
      this.values[i] = Math.floor(Math.random() * 6) + 1;
    }
    return this.getValues();
  }
  
  /**
   * Roll specific dice (the ones not kept)
   * @param keptDice Array of indices of dice to keep
   * @returns Array of dice values
   */
  rollSelected(keptDice: boolean[]): number[] {
    for (let i = 0; i < this.diceCount; i++) {
      if (!keptDice[i]) {
        this.values[i] = Math.floor(Math.random() * 6) + 1;
      }
    }
    return this.getValues();
  }
  
  /**
   * Get current dice values
   * @returns Array of dice values
   */
  getValues(): number[] {
    return [...this.values];
  }
  
  /**
   * Set dice to specific values
   * @param values Array of dice values
   */
  setValues(values: number[]): void {
    this.values = [...values];
  }
  
  /**
   * Reset all dice to 0
   */
  reset(): void {
    this.values = new Array(this.diceCount).fill(0);
  }
}
