Okay, here is a detailed description of your Yatzy game project based on the provided file structure and contents.

## Project Overview: Multiplayer Yatzy Game (Flutter & Node.js)

This project implements a multiplayer Yatzy game featuring a Flutter frontend and a Node.js (Express/TypeScript) backend. It leverages WebSockets (Socket.IO) for real-time gameplay and communication, MongoDB for data persistence (game logs, top scores, potentially user auth), and includes unique features like multiple game modes, spectator functionality, and integration with Unity for 3D dice rendering.

**Core Technologies:**

*   **Frontend:** Flutter (Dart)
*   **Backend:** Node.js, Express.js, TypeScript
*   **Real-time Communication:** Socket.IO
*   **Database:** MongoDB
*   **3D Rendering (Optional):** Unity (integrated via `flutter_unity_widget`)

**Key Features:**

*   Real-time multiplayer Yatzy gameplay.
*   Multiple game modes (Ordinary, Mini, Maxi, including variants with Regret/Extra Move rules).
*   Persistent Top Scores leaderboard per game mode.
*   Game logging/history stored in the database.
*   In-game chat functionality.
*   Spectator mode to watch ongoing games.
*   User authentication (Login/Signup routes exist, likely JWT-based).
*   Optional 3D dice rendering via Unity integration.
*   Basic settings configuration (Username, Language, Game Type, Visuals).
*   Localization support (English/Swedish examples shown).

---

## Backend Description (`backend/`)

The backend is a Node.js application built with the Express.js framework and written in TypeScript. It serves as the central authority for game logic, state management, and communication between clients.

**Core Components & Architecture:**

1.  **Server (`server.ts`):**
    *   Initializes an Express application and an HTTP server.
    *   Sets up Socket.IO on top of the HTTP server for real-time communication.
    *   Configures CORS to allow connections from the frontend (including handling development vs. production origins via an `isOnline` flag).
    *   Integrates middleware (like `express.json` for parsing request bodies).
    *   Initializes the MongoDB database connection (`db.ts`).
    *   Instantiates and wires up Controllers and Services.
    *   Registers API routes defined in the `routes/` directory.
    *   Sets up Socket.IO event listeners, delegating handling to controllers.
    *   Includes logic for serving static frontend build files (handling different paths for local dev vs. online deployment).

2.  **Database (`db.ts`):**
    *   Manages the MongoDB connection using the native `mongodb` driver.
    *   Provides functions `initializeDbConnection` and `getDbConnection` to access specific databases (`react-auth-db`, `top-scores`, `yatzy-game-log-db`).
    *   Includes a connection test write operation on startup.

3.  **Networking (Socket.IO in `server.ts`):**
    *   Handles client connections, disconnections, and message routing.
    *   Uses robust Socket.IO configuration supporting both `websocket` and `polling` transports, with ping timeouts for connection stability.
    *   Listens for client events (`sendToServer`, `sendToClients`) and forwards them to the appropriate controllers.
    *   Broadcasts game state updates (`onServerMsg`) and client-specific messages (`onClientMsg`) to players and spectators.

4.  **API Routes (`routes/`):**
    *   Defines RESTful endpoints using Express Router.
    *   `logInRoute.ts`, `signUpRoute.ts`: Handle user authentication (likely using bcrypt for password hashing and JWT for session tokens).
    *   `logRoute.ts`, `getLogRoute.ts`: Potentially for user activity logging (seems related to the auth DB).
    *   `getTopScores.ts`, `updateTopScore.ts`: API for fetching and submitting high scores for different game modes, interacting with the `top-scores` DB.
    *   `spectateGameRoute.ts`: An *HTTP GET* endpoint `/api/spectate/:gameId` used to fetch the initial state and log for a game being spectated.

5.  **Controllers (`controllers/`):**
    *   `ChatController.ts`: Handles receiving chat messages via Socket.IO (`sendToClients`, `sendToServer` with `chatMessage` action) and broadcasts them to relevant players in a specific game using `GameService` to find participants.
    *   `GameController.ts`: Manages core game flow events via Socket.IO (`requestGame`, `requestJoinGame`, `removeGame`, `useRegret`, `useExtraMove`, `spectateGame`). Handles receiving player actions like dice rolls (`sendDices`) and score selections (`sendSelection`), validating turns, interacting with `GameService` and `GameLogService`, and triggering state updates.
    *   `PlayerController.ts`: Primarily handles initial player connection setup (`getId`) and potentially player-specific events (though most game actions are delegated to `GameController`).

6.  **Services (`services/`):**
    *   `GameService.ts`: The core logic hub. Manages the state of active games (`Map<gameId, Game>`). Handles game creation, finding available games, player joining/leaving/disconnecting (including turn management and game finishing logic), adding/removing spectators, processing dice rolls and selections, broadcasting game state updates and game lists to clients via Socket.IO (`io.emit`, `io.to`). Interacts with `GameLogService` to record game events and `TopScoreService` to update scores when a game finishes.
    *   `GameLogService.ts`: Responsible for interacting with the `yatzy-game-log-db` MongoDB database (`game_moves` collection). Logs game start, individual moves (roll, select, regret, extra move, disconnect, spectate), and game end (with final scores). Provides a method to retrieve the full log for a game (used by spectator mode).
    *   `TopScoreService.ts`: Handles interactions with the `top-scores` MongoDB database. Provides methods to fetch top scores for different game types and to insert new scores.

7.  **Models (`models/`):**
    *   `BoardCell.ts`: Represents a single cell on the Yatzy scorecard (index, label, value, fixed status).
    *   `Dice.ts`: Encapsulates dice logic (rolling, keeping specific dice). *Note: The backend `GameService` seems to rely on client dice rolls, using this model mainly for internal state perhaps.*
    *   `Game.ts`: Represents the state of a single Yatzy game instance (ID, type, players, status flags, current player, dice values, roll count, turn number, etc.). Includes methods for adding/removing players, managing turns, applying selections, checking finish conditions, and serialization (`toJSON`, `fromJSON`).
    *   `Player.ts`: Represents a player (ID, username, active status, scorecard `cells`, calculated scores, special move counts like `regretsLeft`). Includes methods for score calculation and serialization.

8.  **Utilities (`utils/`):**
    *   `gameConfig.ts`: Defines constants and structures for different game types (cell labels, bonus rules, dice count, max rolls).
    *   `yatzyMapping.ts`: Provides utility functions (`getSelectionLabel`, `getSelectionIndex`) to map between the numerical index of a scorecard cell and its string label (e.g., 0 -> "Ones", 8 -> "Pair"), essential for processing selections received from the client.
    *   `index.ts`: General utility functions (currently includes `randomInt`, `delay`, etc., might not be heavily used by core game logic).

---

## Frontend Description (`lib/`)

The frontend is a Flutter application providing the user interface for playing Yatzy, managing settings, and viewing top scores. It communicates with the backend via Socket.IO for real-time updates and HTTP for less frequent data retrieval/submission.

**Core Components & Architecture:**

1.  **Initialization (`main.dart`, `startup.dart`):**
    *   Sets up the Flutter application (`runApp`).
    *   Initializes shared preferences (`SharedPrefProvider`) for storing settings.
    *   Configures dependency injection (`getIt`, `injectable`).
    *   Sets up global state management using Flutter Bloc (`LanguageBloc`, `SetStateCubit`).
    *   Initializes global variables/configuration in `startup.dart` (like `isOnline`, `localhost` URL, default language, instances of core classes like `app`, `dices`, `chat`).
    *   Wraps the application in `ServiceProvider` (`app_widget.dart`) to make services accessible.
    *   Crucially, `app_widget.dart`'s `builder` initializes the connection via `SocketService.connect()` after the first frame.

2.  **Routing (`router/`):**
    *   Uses the `auto_route` package for declarative navigation.
    *   Defines routes for the main views: `SettingsView` (initial) and `ApplicationView` (game screen).

3.  **State Management (`states/`):**
    *   Uses `flutter_bloc`.
    *   `LanguageBloc`: Manages the application's current language.
    *   `SetStateCubit`: A simple cubit used extensively for triggering general UI rebuilds (`context.read<SetStateCubit>().setState()`). This suggests a mix of Bloc for specific features and a more basic "setState" approach for broader UI updates managed within the `Application` class.

4.  **Core Application Logic (`application/`):**
    *   `Application.dart`: A central class holding much of the frontend game state and UI logic. It's instantiated globally in `startup.dart`. Contains game state variables (`gameType`, `nrPlayers`, `gameData`, `myPlayerId`, `playerToMove`, board state arrays like `cellValue`, `fixedCell`, `appText`, `appColors`). Manages interactions with the `Dices` component and handles UI updates via callbacks and the `SetStateCubit`.
    *   `CommunicationApplication.dart`: An extension containing the crucial `callbackOnServerMsg` and `callbackOnClientMsg` methods. These methods parse messages received from the `SocketService` and update the `Application` state accordingly (handling game start, updates, aborts, finish, chat messages, dice/selection updates from other players). Also handles sending chat messages.
    *   `WidgetApplicationScaffold.dart`: Extension defining the main scaffold/layout for the `ApplicationView`, arranging different widgets (game board, dice, chat, top scores, scroll text) based on screen orientation. Includes logic for floating action buttons (Settings, New Game, Regret, Extra Move).
    *   `WidgetApplication.dart`: Contains the `WidgetSetupGameBoard` (builds the Yatzy scorecard UI based on `Application` state) and `WidgetDisplayGameStatus` widgets.
    *   `WidgetApplicationSettings.dart`: Extension defining the UI for the `SettingsView`, including game type selection, player count, username input, available game list (with join buttons), spectator buttons, and general settings tabs (language, animations, Unity options). Includes the `SpectatorGameBoard` when spectating.
    *   `LanguagesApplication.dart`: Mixin holding localized strings for the application UI elements.
    *   `ApplicationFunctionsInternal*.dart`: Extensions containing helper functions for cell clicks, local UI updates after selection, board coloring, and dice score calculations.

5.  **Networking (`services/`):**
    *   `SocketService.dart`: The *modern* implementation for handling Socket.IO communication. Manages connection state, sends/receives events (`sendToServer`, `sendToClients`, `onClientMsg`, `onServerMsg`), and interacts with the `Application` class via callbacks (`app.callbackOnClientMsg`, `app.callbackOnServerMsg`). It's provided via `ServiceProvider`.
    *   `HttpService.dart`: The *modern* implementation for making HTTP requests (GET, POST, PUT, DELETE) to the backend API using the `http` package. Used for fetching/updating top scores, potentially login/signup. It's provided via `ServiceProvider`.
    *   `GameService.dart`: A frontend service that likely acts as an intermediary between UI components and the `SocketService` for game-specific actions. It holds a reference to the `SocketService`.
    *   `ServiceProvider.dart`: Uses `InheritedWidget` to make `SocketService` and `GameService` instances available throughout the widget tree via `ServiceProvider.of(context)`.

6.  **Dice Component (`dices/`):**
    *   `Dices.dart`: Manages the state of the dice (values, held status, rolls left). Includes logic for rolling dice locally (for single-player or visual feedback).
    *   `UnityCommunication.dart`: Handles the communication *to* and *from* the embedded Unity widget using `flutter_unity_widget`. Defines methods to send messages (reset, start, update dice, update colors, toggle features) and callbacks (`onUnityMessage`, `onUnityCreated`) to handle messages received *from* Unity (like dice roll results).
    *   `WidgetDices.dart`: The UI widget that either displays the 2D dice images or embeds the `UnityWidget` based on the `unityDices` setting.

7.  **Other Features (`chat/`, `top_score/`, `scroll/`, `tutorial/`):**
    *   `chat/`: Contains the `Chat` logic class and `WidgetChat` UI for the in-game chatbox.
    *   `top_score/`: Contains the `TopScore` logic class (fetching/updating scores via `HttpService`) and `WidgetTopScore` UI.
    *   `scroll/`: Implements an animated scrolling text widget (`WidgetAnimationsScroll`).
    *   `tutorial/`: Contains logic and widgets for displaying tutorial arrows/hints (`WidgetArrow`).

8.  **Models (`models/`):**
    *   Defines frontend representations of `Game`, `Player`, and `BoardCell`, used to structure data received from the backend and manage UI state.

9.  **Utilities (`utils/`):**
    *   `yatzy_mapping_client.dart`: Provides client-side mapping between cell indices and string labels, ensuring consistency with the backend when sending/interpreting selections.

---

## Key Interactions & Workflow

1.  **App Start:** Flutter app initializes, `ServiceProvider` creates `SocketService` and `GameService`. `AppWidget` triggers `SocketService.connect()`.
2.  **Connection:** `SocketService` connects to the backend Socket.IO server, receives a unique `socketId`.
3.  **Settings:** User configures game settings (type, players, username) in `SettingsView`.
4.  **Create/Join Game:**
    *   User clicks "Create Game".
    *   `Application` -> `onStartGameButton` -> `SocketService.sendToServer` (action: `requestGame`).
    *   Backend `GameController` -> `GameService.createOrJoinGame`.
    *   Backend broadcasts updated game list (`onRequestGames`) via `onServerMsg`.
    *   *Or* User clicks an available game to join.
    *   `Application` -> `onAttemptJoinGame` -> `SocketService.sendToServer` (action: `requestJoinGame`).
    *   Backend `GameController` -> `GameService.joinGame`.
    *   Backend broadcasts updated game list.
5.  **Game Start:** When a game is full, backend `GameService` marks it as started and broadcasts `onGameStart` via `onServerMsg`.
6.  **Navigation:** Frontend receives `onGameStart`, `CommunicationApplication.callbackOnServerMsg` processes it, updates `Application` state, and navigates to `ApplicationView`.
7.  **Gameplay Turn:**
    *   Backend determines `playerToMove` and includes it in `onServerMsg` updates.
    *   Frontend `Application` updates UI based on `isMyTurn`.
    *   **Dice Roll:**
        *   If `unityDices` is true: User interacts with Unity, Unity performs roll, sends result via `onUnityMessage` -> `UnityCommunication.onUnityMessage` -> `Dices.callbackUpdateDiceValues`.
        *   If `unityDices` is false: User clicks "Roll" button (`WidgetDices`), `Dices.rollDices` calculates locally, calls `Dices.callbackUpdateDiceValues`.
        *   `Dices.callbackUpdateDiceValues` calls `Application.callbackUpdateDiceValues` which sends dice values (`sendDices`) to backend via `SocketService.sendToClients`.
        *   Backend `GameController.handleSendDices` -> `GameService.processDiceRoll` (logs roll) -> broadcasts `sendDices` via `onClientMsg` to *other* players and spectators, and sends full state update (`onServerMsg`) to *all*.
    *   **Score Selection:**
        *   User clicks a cell (`WidgetSetupGameBoard`).
        *   `Application.cellClick` calculates local score, creates message with `selectionLabel`, sends (`sendSelection`) via `SocketService.sendToClients`. Updates UI *optimistically* via `applyLocalSelection`.
        *   Backend `GameController.handleSendSelection` -> `GameService.processSelection` (validates turn, logs selection, updates game state, advances turn).
        *   Backend sends full state update (`onGameUpdate`) via `onServerMsg` to all players/spectators. Frontend `callbackOnServerMsg` receives this authoritative state.
8.  **Chat:** User types message, `Chat.onSubmitted` -> `Application.chatCallbackOnSubmitted` -> `SocketService.sendToClients` (action: `chatMessage`). Backend `ChatController` relays message via `onClientMsg` to other players. Frontend `callbackOnClientMsg` -> `Application.updateChat` updates UI.
9.  **Spectating:**
    *   User clicks "Spectate" button in `SettingsView`.
    *   `Application.onSpectateGame` -> `SocketService.sendToServer` (action: `spectateGame`).
    *   Backend `GameController.handleSpectateGame` -> fetches game state/log, sends initial state (`onGameStart` with `spectator: true`) via `onServerMsg`. Adds spectator to `GameService`.
    *   Frontend `callbackOnServerMsg` receives spectator data, sets `isSpectating` flag, updates UI to show `SpectatorGameBoard`.
    *   Subsequent `onGameUpdate` messages are received and displayed by `SpectatorGameBoard`.
10. **Game End:** Backend `GameService` detects game end, logs final scores, updates top scores via `TopScoreService`, broadcasts `onGameFinished` via `onServerMsg`. Frontend `callbackOnServerMsg` handles this, shows dialog, navigates back to `SettingsView`.

