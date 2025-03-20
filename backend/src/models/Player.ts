/**
 * Player model for Yatzy game
 */
export interface Player {
  id: string;
  username: string;
  isActive: boolean;
  // Additional player properties can be added here as needed
}

export class PlayerFactory {
  /**
   * Create a new player
   * @param id Player's socket id
   * @param username Player's username
   * @returns New Player object
   */
  static createPlayer(id: string, username: string): Player {
    return {
      id,
      username,
      isActive: true
    };
  }

  /**
   * Create an empty player placeholder
   * @returns Empty player with default values
   */
  static createEmptyPlayer(): Player {
    return {
      id: "",
      username: "",
      isActive: false
    };
  }
}
