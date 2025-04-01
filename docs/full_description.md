Okay, here is a detailed technical description of the `jesseburstrom-client` project, covering both the Flutter frontend (`lib/`) and the Express backend (`backend/`).

**Project Overview**

This project implements a client-server system for playing various versions of the Yatzy dice game (Ordinary, Mini, Maxi). It features:

1.  **Real-time Multiplayer:** Players can create or join games, see opponent actions (dice rolls, score selections) in real-time.
2.  **Multiple Game Types:** Supports different rule sets and board layouts for Yatzy.
3.  **Spectator Mode:** Allows users to watch ongoing games without participating.
4.  **User Authentication:** Basic email/password signup and login using JWT.
5.  **Top Scores:** Tracks and displays high scores per game type.
6.  **Chat:** In-game chat functionality between players.
7.  **Unity Integration (Optional):** Leverages Unity via `flutter_unity_widget` for potentially rendering 3D dice.
8.  **Game Logging:** Persists game moves and events to a database.

**Technology Stack**

*   **Backend:**
    *   Runtime: Node.js
    *   Framework: Express.js
    *   Language: TypeScript
    *   Database: MongoDB
    *   Real-time Communication: Socket.IO
    *   Authentication: JSON Web Tokens (JWT), bcrypt (for password hashing)
    *   Other: CORS, dotenv
*   **Frontend:**
    *   Framework: Flutter
    *   Language: Dart
    *   State Management: flutter_bloc (Bloc, Cubit) - Primarily `LanguageBloc` and `SetStateCubit`. Significant state also appears managed directly within the `Application` class.
    *   Navigation: auto_route
    *   Networking: http package (via `HttpService`), socket_io_client (via `SocketService`)
    *   Dependency Injection: get_it, injectable
    *   Local Storage: shared_preferences
    *   Unity Integration: flutter_unity_widget
    *   UI: Material Design widgets, AutoSizeText

---

**Backend Description (`backend/`)**

The backend is a Node.js application built with Express and TypeScript, responsible for managing game state, user authentication, real-time communication, and data persistence.

1.  **Architecture:**
    *   Follows a layered approach: Routes -> Controllers -> Services -> Models/DB.
    *   **Routes (`routes/`):** Define HTTP API endpoints. Files like `logInRoute.ts`, `signUpRoute.ts`, `getTopScores.ts`, `spectateGameRoute.ts` map paths and HTTP methods to handler functions. `index.ts` aggregates these routes.
    *   **Controllers (`controllers/`):** Handle incoming requests (both HTTP via routes and Socket.IO events). They parse requests, call appropriate services, and format responses. `GameController`, `PlayerController`, and `ChatController` manage specific domains of functionality, particularly Socket.IO interactions.
    *   **Services (`services/`):** Contain the core business logic.
        *   `GameService`: Manages the lifecycle and state of active games (creating, joining, player actions, disconnections, spectator management). Interacts heavily with Socket.IO to broadcast updates.
        *   `GameLogService`: Handles interaction with the MongoDB `yatzy-game-log-db` database to store game starts, moves (rolls, selections, disconnects), spectating actions, and final scores.
        *   `TopScoreService`: Manages reading and writing high scores to the `top-scores` MongoDB database. Uses Socket.IO to broadcast score updates.
    *   **Models (`models/`):** Define the data structures for core entities like `Game`, `Player`, `BoardCell`, and `Dice`. These classes often include logic related to their state (e.g., `Player.calculateScores`, `Game.advanceToNextActivePlayer`).
    *   **Database (`db.ts`):** Manages the MongoDB connection using the official `mongodb` driver. It initializes the connection and provides a function (`getDbConnection`) to access specific databases (`react-auth-db`, `yatzy-game-log-db`, `top-scores`). Includes a basic connection test.
    *   **Utils (`utils/`):** Contains helper constants and functions, like `gameConfig.ts` (defining rules/layouts for different Yatzy types) and `yatzyMapping.ts` (mapping between cell indices and labels, crucial for client-server consistency).

2.  **Real-time Communication (Socket.IO):**
    *   Initialized in `server.ts` and attached to the HTTP server.
    *   Configured with CORS settings to allow connections from the Flutter frontend.
    *   Uses both WebSocket and polling transports for robustness.
    *   The `GameService`, `ChatController`, and `TopScoreService` leverage the `io` instance passed from `server.ts` to emit events to specific clients (`io.to(socketId).emit(...)`) or broadcast to all connected clients (`io.emit(...)`).
    *   Controllers register event handlers (`socket.on(...)`) for messages like `sendToServer` (client actions), `sendToClients` (client-to-client forwarding, mainly chat), `connect`, and `disconnect`.
    *   `GameService` plays a key role in managing game rooms/state and broadcasting updates (`onGameUpdate`, `onGameStart`, `onGameFinished`) to relevant players and spectators.

3.  **API Routes & Authentication:**
    *   Provides RESTful endpoints for signup (`/api/signup`) and login (`/api/login`).
    *   Uses bcrypt to hash passwords during signup and compare during login.
    *   Issues JWT tokens upon successful login, which are then expected in the `Authorization` header for protected routes (like `/api/log/:userId`, `/api/getLog/:userId`).
    *   Other routes like `/GetTopScores`, `/UpdateTopScore`, and `/api/spectate/:gameId` handle data retrieval and updates, some potentially without strict JWT auth depending on implementation details not fully shown.

4.  **Data Persistence (MongoDB):**
    *   `react-auth-db`: Stores user credentials (`email`, `passwordHash`) and potentially basic profile info (`users` collection) and activity logs (`logs` collection).
    *   `yatzy-game-log-db`: Stores detailed game logs (`game_moves` collection), including game setup, player moves (rolls, selections), disconnects, spectating, and final scores. `GameLogService` interacts with this.
    *   `top-scores`: Stores high scores, likely in separate collections per game type (`ordinary`, `mini`, `maxi`). `TopScoreService` interacts with this.

5.  **Server Entry Point (`server.ts`):**
    *   Sets up the Express app, CORS middleware, and JSON body parsing.
    *   Creates an HTTP server and attaches Socket.IO to it.
    *   Includes an `isOnline` flag to switch between serving build artifacts for deployment and local development directories.
    *   Initializes the database connection (`initializeDbConnection`).
    *   Instantiates controllers and services, injecting dependencies (like `io`, `GameLogService`, `TopScoreService`).
    *   Registers all HTTP routes and Socket.IO event handlers.
    *   Starts the HTTP server, listening on the specified port (8000).

---

**Frontend Description (`lib/`)**

The frontend is a Flutter application providing the user interface for interacting with the Yatzy game server.

1.  **Architecture & Structure:**
    *   **Modular Design:** Code is organized into feature-based folders (`application`, `chat`, `dices`, `top_score`, `scroll`, `tutorial`, `views`, `widgets`), promoting separation of concerns.
    *   **Core (`core/`):** Contains the main application widget (`AppWidget`) and dependency injection setup (`injectable_modules.dart`).
    *   **Application (`application/`):** Seems to be the central hub. The `Application` class holds a significant amount of game state and UI logic. It interacts with other components like `Dices`, `Chat`, `TopScore`. Uses mixins for languages (`LanguagesApplication`). Contains internal functions (`application_functions_internal.dart`, `..._calc_dice_values.dart`) and specific UI building logic (`widget_application.dart`, `widget_application_scaffold.dart`, `widget_application_settings.dart`).
    *   **State Management (`states/`):** Uses `flutter_bloc`.
        *   `LanguageBloc`: Manages language selection, persisting the choice to `SharedPreferences`.
        *   `SetStateCubit`: A simple Cubit used to trigger UI updates across potentially large parts of the application by incrementing a counter state. This suggests that much of the state might be managed directly in classes like `Application`, and this Cubit forces rebuilds when that state changes.
    *   **Services (`services/`):**
        *   `SocketService`: Manages the `socket_io_client` connection, event handling (`onConnect`, `onDisconnect`, `onClientMsg`, `onServerMsg`), and provides methods to send events to the server (`sendToServer`, `sendToClients`). It interacts heavily with the `Application` class via callbacks (`app.callbackOnClientMsg`, `app.callbackOnServerMsg`).
        *   `HttpService`: Handles standard HTTP requests for actions like fetching top scores or potentially authentication (though auth flow isn't fully detailed here).
        *   `GameService` (Client-side): Likely a wrapper or state manager for game-related data received from the server, although its exact role seems less defined than the backend `GameService`.
        *   `ServiceProvider`: An `InheritedWidget` used to make services (`SocketService`, `GameService`) available down the widget tree. Initialized in `AppWidget`.
    *   **Navigation (`router/`):** Uses the `auto_route` package for defining routes (`SettingsView`, `ApplicationView`) and handling navigation declaratively.
    *   **Models (`models/`):** Defines client-side representations of data structures like `Game`, `Player`, `BoardCell`, mirroring the backend models.
    *   **Views (`views/`):** Top-level screens/pages managed by the router (`ApplicationView`, `SettingsView`).
    *   **Widgets (`widgets/`):** Contains potentially reusable or specific UI components, like `SpectatorGameBoard`.
    *   **Feature Widgets:** Each feature folder (`chat`, `dices`, `top_score`, `scroll`) contains its main widget (e.g., `WidgetChat`, `WidgetDices`) responsible for rendering that part of the UI.
    *   **Startup (`startup.dart`):** Contains global variables for configuration (like `localhost` URL, `isOnline` flag) and initializes instances of major classes like `Application`, `Chat`, `Dices`, `TopScore`. *The heavy reliance on globals is a potential architectural weakness.*

2.  **State Management Details:**
    *   The `Application` class appears to be a central state holder, managed via direct variable updates.
    *   `SetStateCubit` is used broadly (`context.read<SetStateCubit>().setState()`) to trigger UI rebuilds when state within `Application` or other classes changes. This is less granular than typical Bloc/Cubit patterns where specific states trigger specific UI updates.
    *   `LanguageBloc` manages language state specifically.

3.  **Real-time Integration:**
    *   `SocketService` connects to the backend Socket.IO server.
    *   It listens for server events (`onServerMsg`, `onClientMsg`) and calls corresponding methods in the `Application` class (`callbackOnServerMsg`, `callbackOnClientMsg`).
    *   These callbacks in `Application` parse the incoming data (`action` key) and update the local game state (variables within `Application`), then trigger a UI refresh using `SetStateCubit`.
    *   Client actions (rolling dice, selecting scores, sending chat) are sent back to the server via `SocketService.sendToServer` or `SocketService.sendToClients`.

4.  **Unity Integration (`dices/`):**
    *   Uses `flutter_unity_widget` to embed a Unity view.
    *   `Dices` class manages the Unity controller (`UnityWidgetController`).
    *   `UnityCommunication` extension provides methods to send formatted messages (JSON strings via `postMessage`) to the Unity scene (`GameManager` GameObject) for actions like resetting dice, starting rolls, updating colors, etc.
    *   Handles messages received *from* Unity via `onUnityMessage`, parsing JSON to update Flutter state (e.g., dice results).

5.  **UI Composition:**
    *   `AppWidget` sets up the `MaterialApp.router` and the `ServiceProvider`.
    *   `ApplicationView` displays the main game screen. Its state (`_ApplicationViewState`) builds the UI using `Application.widgetScaffold`.
    *   `WidgetApplicationScaffold` arranges the main UI components (game board, dice area, chat, top scores, status display) based on screen orientation (portrait/landscape).
    *   `WidgetSetupGameBoard` renders the Yatzy scoreboard dynamically based on game state (`app.cellValue`, `app.fixedCell`, `app.appColors`).
    *   `WidgetDices` renders either the 2D dice images or the `UnityWidget` based on the `unityDices` setting.
    *   Other widgets (`WidgetChat`, `WidgetTopScore`, `WidgetScroll`) render their respective parts.

---

**Key Functionalities Flow (Client <-> Server)**

1.  **Connect & Get ID:** Client connects (`SocketService.connect`) -> Server sends `welcome` -> Client requests ID (`sendToServer` with `action: 'getId'`) -> Server responds (`onServerMsg` with `action: 'getId'`) -> Client stores `socketId`.
2.  **Create/Join Game:** Client UI (Settings) -> `onStartGameButton` -> `SocketService.sendToServer` (`action: 'requestGame'` or `'requestJoinGame'`) -> Backend `GameController` -> `GameService.createOrJoinGame` -> Backend updates game state -> Backend `GameService` broadcasts `onGameStart` or `onGameUpdate` via `io.emit('onServerMsg', ...)` -> Client receives `onServerMsg` -> `app.callbackOnServerMsg` -> Parses data, updates `Application` state, navigates to `ApplicationView`.
3.  **Roll Dice:**
    *   *2D Dices:* Client UI (`WidgetDices`) -> `rollDices` function -> Calculates random dice -> Updates local state -> Calls `app.callbackUpdateDiceValues`.
    *   *3D Dices:* Client UI/Unity -> `onUnityMessage` (with results) -> `app.callbackUpdateDiceValues`.
    *   `app.callbackUpdateDiceValues` -> Calls `app.updateDiceValues` (updates score previews) -> Sends dice data (`sendToClients` with `action: 'sendDices'`) via `SocketService`.
    *   Backend receives `sendDices` -> `GameController` -> `GameService.processDiceRoll` -> Logs roll -> Broadcasts dice update (`onClientMsg` and `onServerMsg`).
    *   Other clients receive `onClientMsg` (`action: 'sendDices'`) -> Update their dice display.
    *   All clients (including sender) receive `onServerMsg` (`action: 'onGameUpdate'`) -> Update full game state (roll count, dice).
4.  **Select Score:** Client UI (`WidgetSetupGameBoard`) -> `app.cellClick` -> Calculates label -> Sends selection data (`sendToClients` with `action: 'sendSelection'`) via `SocketService` -> *Optimistically updates local UI (`applyLocalSelection`)*.
    *   Backend receives `sendSelection` -> `GameController` -> `GameService.processSelection` -> Updates game state (fixes cell, calculates score, advances turn) -> Logs selection -> Broadcasts `onGameUpdate` (`onServerMsg`).
    *   Client receives `onServerMsg` (`action: 'onGameUpdate'`) -> `app.callbackOnServerMsg` -> Updates local state to match server (confirms selection, updates player turn, clears dice).
5.  **Chat:** Client UI (`WidgetChat`) -> `chat.onSubmitted` -> Calls `app.chatCallbackOnSubmitted` -> `SocketService.sendToClients` (`action: 'chatMessage'`) -> Backend `ChatController` receives -> Broadcasts `onClientMsg` (`action: 'chatMessage'`) to other players -> Other clients receive -> `app.callbackOnClientMsg` -> `app.updateChat` -> Updates chat UI.
6.  **Spectate:** Client UI (Settings) -> `onSpectateGame` -> Sets `isSpectating` flag -> `SocketService.sendToServer` (`action: 'spectateGame'`) -> Backend `GameController` -> Fetches game state/log -> Sends data back (`onServerMsg` with `action: 'onGameStart'`, `spectator: true`) -> Client receives -> `app.callbackOnServerMsg` -> Updates `gameData` -> UI renders `SpectatorGameBoard`. Subsequent `onGameUpdate` messages are received and update the spectator view.

---

**Potential Improvements / Observations**

*   **State Management (Flutter):** The reliance on a central `Application` class and a global `SetStateCubit` could become difficult to manage and debug as the application grows. A more structured approach using Bloc/Cubit per feature or a different state management solution (like Riverpod) might be beneficial.
*   **Global Variables (Flutter):** The `startup.dart` file uses many global variables. This makes state tracking harder and increases the risk of side effects. Encapsulating configuration and state within appropriate classes/providers is recommended.
*   **Client-Side Validation:** The client calculates potential scores (`app.updateDiceValues`) before the user selects a cell. The server should ideally recalculate/validate the score upon receiving the `sendSelection` event to prevent cheating.
*   **Error Handling:** Error handling appears basic. More robust handling on both client and server (e.g., specific error messages, UI feedback, logging) would improve usability and debugging.
*   **Code Duplication:** The Yatzy mapping logic (`yatzyMapping.ts` and `yatzy_mapping_client.dart`) seems duplicated. Consider a shared definition or code generation.
*   **Backend DI:** Explicit Dependency Injection could improve testability and organization in the backend compared to manual instantiation in `server.ts`.
*   **Testing:** No test files are visible in the structure. Adding unit, integration, and widget tests is crucial for stability.
*   **Spectator Data:** The spectator implementation fetches both in-memory state and database logs. Ensuring these are correctly merged and presented consistently requires careful handling. The `SpectatorGameBoard` widget directly uses `gameData` which might need refinement based on the combined state.

---

**Conclusion**

This project is a comprehensive client-server implementation of a multiplayer Yatzy game. It effectively uses Socket.IO for real-time features, MongoDB for persistence, and JWT for basic authentication. The Flutter frontend provides the UI, integrates potentially with Unity for visuals, and manages client-side state, albeit with some architectural patterns (globals, `SetStateCubit`) that could be refined. The separation into controllers, services, and models on the backend, and a modular feature-based structure on the frontend, provides a reasonable foundation. Key areas for potential focus include enhancing state management on the client, adding robust server-side validation, and implementing comprehensive testing.

Okay, here's a detailed analysis of the `jesseburstrom-client` codebase, focusing on function/class dependencies and relationships in a compact, AI-parseable format.

---

**ANALYSIS START**

**Project:** jesseburstrom-client
**Root Directory:** `jesseburstrom-client/`

**Overall Structure:**
*   **Backend:** Node.js/TypeScript application using Express, MongoDB, and Socket.IO. Handles game logic, user authentication, data persistence.
*   **Frontend:** Flutter application (`lib/`) using Bloc/Cubit for state management, GetIt/Injectable for dependency injection, AutoRoute for navigation, and potentially `flutter_unity_widget` for dice rendering.

---

**I. Backend Analysis (`backend/`)**

**Entry Point:** `backend/src/server.ts`

1.  **`backend/src/server.ts`**
    *   **Imports:** `express`, `cors`, `http`, `socket.io`, `path`, `db.ts`, `routes/index.ts`, `services/*`, `controllers/*`, `routes/spectateGameRoute.ts`.
    *   **Initialization:**
        *   Creates Express app (`app`).
        *   Sets up CORS.
        *   Creates HTTP server (`httpServer`) wrapping Express app.
        *   Initializes Socket.IO Server (`io`) attached to `httpServer` with CORS and transport settings.
        *   Configures static file serving (`express.static`) based on `isOnline` flag.
        *   Uses `express.json()` middleware.
    *   **Routing:**
        *   Calls `routes()` from `routes/index.ts` to get route definitions.
        *   Dynamically registers routes (GET, POST, etc.) onto the Express `app`.
        *   Explicitly registers `/api/spectate/:gameId` GET route.
    *   **Services & Controllers Instantiation:**
        *   Creates `GameLogService`, `TopScoreService` (passes `io`), `GameService` (passes `io`, `gameLogService`, `topScoreService`).
        *   Creates `GameController`, `PlayerController`, `ChatController` (passes `io` and/or `gameService`, `gameLogService`).
        *   Calls `initializeSpectateRoute()` passing services.
    *   **Socket.IO Handling:**
        *   Sets up `io.on("connect", ...)` handler.
        *   Inside `connect` handler:
            *   Logs connection (`socket.id`).
            *   Emits `welcome`.
            *   Registers handlers from `gameController`, `playerController`, `chatController`.
            *   Listens for `sendToServer`: Routes specific actions (`requestTopScores`) or logs others.
            *   Listens for `sendToClients`: Logs.
            *   Listens for `disconnect`: Calls `gameService.handlePlayerDisconnect()`.
    *   **Startup:**
        *   Calls `initializeDbConnection()` from `db.ts`.
        *   Starts `httpServer.listen()`.

2.  **`backend/src/db.ts`**
    *   **Imports:** `mongodb`.
    *   **Exports:** `initializeDbConnection`, `getDbConnection`.
    *   **`initializeDbConnection`:** Connects `MongoClient` to MongoDB (`mongodb://127.0.0.1:27017`). Performs a test write.
    *   **`getDbConnection`:** Returns a `Db` instance for a given database name using the established client.

3.  **`backend/src/routes/index.ts`**
    *   **Imports:** All route definition files (`logInRoute.ts`, `signUpRoute.ts`, etc.).
    *   **Exports:** `routes()` function which returns an array of route objects `{ path, method, handler }`. (Does *not* include `spectateGameRoute` which is registered separately in `server.ts`).

4.  **`backend/src/routes/*.ts` (Individual Route Files)**
    *   **General Pattern:** Define an object `{ path, method, handler }`.
    *   **Imports:** `express` (implicitly via handler signature), `jsonwebtoken`, `bcrypt`, `db.ts`.
    *   **Handlers:** Asynchronous functions (`async (req, res) => ...`).
        *   `getLogRoute.ts`: Handles GET `/api/getLog/:userId`. Verifies JWT, finds logs in `react-auth-db.logs`.
        *   `getTopScores.ts`: Handles GET `/GetTopScores`. Connects to `top-scores` DB, queries specific collection (`ordinary`, `mini`, `maxi`) based on `req.query.type`, sorts by score.
        *   `logInRoute.ts`: Handles POST `/api/login`. Finds user in `react-auth-db.users`, compares password with `bcrypt`, generates JWT.
        *   `logRoute.ts`: Handles POST `/api/log/:userId`. Verifies JWT, pushes activity log to `react-auth-db.logs`.
        *   `signUpRoute.ts`: Handles POST `/api/signup`. Checks for existing user, hashes password with `bcrypt`, inserts user into `react-auth-db.users`, creates log entry, generates JWT.
        *   `spectateGameRoute.ts`: Handles GET `/api/spectate/:gameId`. **Uses services directly** (`gameServiceInstance`, `gameLogServiceInstance`). Gets game state from memory (`gameService`) and logs (`gameLogService`), returns combined JSON. Exports `initializeSpectateRoute` for service injection.
        *   `updateTopScore.ts`: Handles POST `/UpdateTopScore`. Connects to `top-scores` DB, inserts score into specific collection based on `req.body.type`. Does *not* explicitly call `TopScoreService.broadcastTopScores`.

5.  **`backend/src/services/GameService.ts`**
    *   **Imports:** `models/Game.ts`, `models/Player.ts`, `socket.io`, `GameLogService.ts`, `TopScoreService.ts`, `utils/yatzyMapping.ts`.
    *   **Class:** `GameService`
        *   **State:** `games: Map<number, Game>`, `spectators: Map<number, Set<string>>`, `gameIdCounter`.
        *   **Dependencies:** `io: Server`, `gameLogService: GameLogService`, `topScoreService: TopScoreService`.
        *   **Methods:**
            *   `addSpectator`: Adds spectator ID to set, emits game state.
            *   `removeSpectator`: Removes spectator ID.
            *   `createGame`: Creates `Game` instance, stores in `games`, calls `gameLogService.logGameStart`.
            *   `findAvailableGame`: Iterates `games` to find joinable game.
            *   `getGame`, `getAllGames`, `removeGame`: Standard map operations. `removeGame` calls `gameLogService.logGameEnd` if finished.
            *   `joinGame`: Adds `Player` to `Game`. If full, updates `gameStarted` and calls `gameLogService.logGameStart` again (to update player list/status).
            *   `handlePlayerDisconnect`: Finds player across games, calls `game.markPlayerAborted`, logs disconnect move via `gameLogService.logMove`, calls `handleGameFinished` if needed, calls `broadcastGameList`, calls `removeSpectator`.
            *   `broadcastGameList`, `broadcastGameListToPlayer`: Emit `onRequestGames` via `io`.
            *   `notifyGameUpdate`: Emits `onGameUpdate` via `io` to players and spectators.
            *   `handlePlayerStartingNewGame`, `handlePlayerAbort`: Calls `handlePlayerDisconnect`.
            *   `handleGameFinished`: Calls `gameLogService.logGameEnd`, calls `topScoreService.updateTopScore` for each player, calls `notifyGameFinished`, removes game from map, cleans spectators, calls `broadcastGameList`.
            *   `notifyGameFinished`: Emits `onGameFinished` via `io` to players and spectators.
            *   `processDiceRoll`: Validates turn, calls `gameLogService.logMove`, updates `game` state, emits `sendDices` (`onClientMsg`) to others, calls `notifyGameUpdate`.
            *   `processSelection`: Validates turn, calls `gameLogService.logMove`, calls `game.applySelection`, calls `handleGameFinished` or advances turn (`game.advanceToNextActivePlayer`), calls `notifyGameUpdate`.
            *   `forwardSelectionToPlayers`: Emits `sendSelection` (`onClientMsg`) to other players.
            *   `createOrJoinGame`: Orchestrates finding/creating game, adding player, logging, notifying, broadcasting.

6.  **`backend/src/services/GameLogService.ts`**
    *   **Imports:** `mongodb`, `db.ts`, `models/Game.ts`.
    *   **Interfaces:** `GameMove`, `GameLog`.
    *   **Class:** `GameLogService`
        *   **Methods:**
            *   `getCollection`: Gets MongoDB collection `yatzy-game-log-db.game_moves`.
            *   `logGameStart`: Upserts initial `GameLog` document.
            *   `logMove`: Pushes a `GameMove` object onto the `moves` array of a `GameLog`. Creates placeholder log if game doesn't exist.
            *   `logGameEnd`: Updates `GameLog` with `endTime` and `finalScores`.
            *   `getGameLog`: Finds and returns a `GameLog` document by `gameId`.
            *   `logSpectate`: Logs a 'spectate' action as a `GameMove`.

7.  **`backend/src/services/TopScoreService.ts`**
    *   **Imports:** `mongodb`, `db.ts`, `socket.io`.
    *   **Class:** `TopScoreService`
        *   **Dependencies:** `io: Server`.
        *   **Methods:**
            *   `getCollection`: Gets MongoDB collection `top-scores.<gameType>`. Validates `gameType`.
            *   `getTopScores`: Finds scores for a specific type, sorts, optionally limits.
            *   `getAllTopScores`: Calls `getTopScores` for all supported types.
            *   `broadcastTopScores`: Emits `onTopScoresUpdate` via `io` with all scores.
            *   `updateTopScore`: Inserts a new score entry. Does *not* currently check if it's a "top" score, just inserts. Implicitly relies on `GameService.handleGameFinished` to call this.

8.  **`backend/src/controllers/GameController.ts`**
    *   **Imports:** `socket.io`, `services/GameService.ts`, `models/Player.ts`, `services/GameLogService.ts`, `utils/yatzyMapping.ts`, `models/Game.ts`.
    *   **Class:** `GameController`
        *   **Dependencies:** `gameService: GameService`, `gameLogService: GameLogService`.
        *   **Methods:**
            *   `registerSocketHandlers`: Listens for `sendToServer` (`requestGame`, `requestJoinGame`, `removeGame`, `spectateGame`) and `sendToClients` (`sendDices`, `sendSelection`).
            *   `handleRequestGame`: Calls `gameService.createOrJoinGame`.
            *   `handleRequestJoinGame`: Calls `gameService.joinGame`, `gameService.notifyGameUpdate`.
            *   `handleRemoveGame`: Calls `gameService.removeGame`.
            *   `handleSendDices`: Calls `gameService.processDiceRoll`.
            *   `handleSendSelection`: Calls `gameService.processSelection`, `gameService.forwardSelectionToPlayers`.
            *   `handleSpectateGame`: Calls `gameService.getGame`, `gameLogService.getGameLog`, `game.applySelection` (to rebuild state from log), emits `onGameStart` / `onGameUpdate`, calls `gameLogService.logSpectate`, calls `gameService.addSpectator`.

9.  **`backend/src/controllers/PlayerController.ts`**
    *   **Imports:** `socket.io`, `services/GameService.ts`, `models/Player.ts`, `services/GameLogService.ts`.
    *   **Class:** `PlayerController`
        *   **Dependencies:** `gameService: GameService`, `gameLogService: GameLogService`.
        *   **Methods:**
            *   `registerSocketHandlers`: Listens for `sendToServer` (`getId`). Logs unknown actions.
            *   `handleGetId`: Emits `getId` (`onServerMsg`), `userId`. (Note: `broadcastGameList` is now handled within `GameService` actions).

10. **`backend/src/controllers/ChatController.ts`**
    *   **Imports:** `socket.io`, `services/GameService.ts`.
    *   **Class:** `ChatController`
        *   **Dependencies:** `io: Server`, `gameService: GameService`.
        *   **Methods:**
            *   `registerSocketHandlers`: Listens for `sendToClients` (`chatMessage`) and `sendToServer` (`chatMessage`).
            *   `handleChatMessage`, `handleServerChatMessage`: Extracts message data, finds players in the game via `gameService`, emits `chatMessage` (`onClientMsg`) to recipients (excluding sender).

11. **`backend/src/models/*.ts`**
    *   **`BoardCell.ts`:** Class `BoardCell` (index, label, value, fixed, isNonScoreCell). Includes `toJSON`, `fromJson`.
    *   **`Dice.ts`:** Class `Dice` (logic for rolling, keeping dice - likely *not used* by server logic currently, as server trusts client rolls).
    *   **`Game.ts`:** Class `Game` (core game state: id, type, players, status flags, turn info, dice, rolls). Methods: `addPlayer`, `removePlayer`, `markPlayerAborted`, `findPlayerIndex`, `isGameFull`, `getCurrentTurnNumber`, `incrementRollCount`, `advanceToNextActivePlayer`, `applySelection` (uses `yatzyMapping.getSelectionIndex`), `isGameFinished`, `setDiceValues`, `toJSON`, `fromJSON`.
    *   **`Player.ts`:** Class `Player` (id, username, isActive, cells, score state). Methods: `calculateScores` (uses `gameConfig`), `hasCompletedGame`, `getScore`, `toJSON`, `fromJSON`. Factory `PlayerFactory`.

12. **`backend/src/utils/*.ts`**
    *   **`gameConfig.ts`:** Exports `GameConfig` object mapping game types ('Ordinary', 'Mini', 'Maxi') to `GameTypeConfig` (cellLabels, bonus info, dice/rolls). Exports `getBaseGameType`.
    *   **`index.ts`:** Basic utility functions (`randomInt`, `delay`, etc.).
    *   **`yatzyMapping.ts`:** Exports `getSelectionLabel`, `getSelectionIndex`. Maps between cell index and string label based on game type (using hardcoded arrays and `getBaseGameType`). Crucial for interpreting client selections.

---

**II. Frontend Analysis (`lib/`)**

**Entry Point:** `lib/main.dart`

1.  **`lib/main.dart`**
    *   **Imports:** `flutter`, `flutter_bloc`, `states/*`, `injectable`, `core/app_widget.dart`, `injection.dart`, `shared_preferences.dart`.
    *   **Initialization:** `WidgetsFlutterBinding.ensureInitialized()`, `SharedPrefProvider.loadPrefs()`, `configureInjection()`, sets up `MultiBlocProvider` (`LanguageBloc`, `SetStateCubit`), runs `AppWidget`.

2.  **`lib/core/app_widget.dart`**
    *   **Imports:** `flutter`, `flutter_bloc`, `application/*`, `dices/dices.dart`, `services/service_provider.dart`, `chat/chat.dart`, `injection.dart`, `router/router.dart`, `scroll/animations_scroll.dart`, `startup.dart`, `states/*`, `top_score/top_score.dart`, `tutorial/tutorial.dart`.
    *   **Class:** `AppWidget`
        *   **Initialization:** Creates instances of `TopScore`, `AnimationsScroll`, `Tutorial`, `Dices`, `Application`, `Chat`. **Crucially, these seem to be global/singleton-like instances accessed via `startup.dart` variables.**
        *   **Build:** Returns `ServiceProvider.initialize` wrapping `MaterialApp.router`. Uses `_appRouter` from `GetIt`.
        *   **`ServiceProvider.initialize`:** Creates `SocketService`, `GameService`.
        *   **`MaterialApp.builder`:** After frame callback, gets `SocketService` from `ServiceProvider`, calls `socketService.connect()`, and `app.setSocketService()`.

3.  **`lib/services/service_provider.dart`**
    *   **Imports:** `flutter`, `services/socket_service.dart`, `services/game_service.dart`.
    *   **Class:** `ServiceProvider` (InheritedWidget)
        *   Holds `SocketService` and `GameService`.
        *   `initialize` static method creates the services.
        *   `of` static method retrieves the provider from context.

4.  **`lib/services/socket_service.dart`**
    *   **Imports:** `flutter`, `socket_io_client`, `flutter_bloc`, `application/communication_application.dart`, `models/game.dart`, `states/*`, `startup.dart`.
    *   **Class:** `SocketService`
        *   **State:** `socket: io.Socket`, `socketId`, `isConnected`, `game: Game?`, connection/handler flags.
        *   **Dependencies:** `context: BuildContext` (used for Bloc lookup).
        *   **Methods:**
            *   `connect`: Initializes `io.Socket`, sets up event handlers (`_setupEventHandlers`), calls `socket.connect()`. Includes logic to prevent multiple concurrent connection attempts.
            *   `_clearEventHandlers`, `_setupEventHandlers`: Manages socket event listeners (`connect`, `disconnect`, `connect_error`, `welcome`, `echo_response`, `onClientMsg`, `onServerMsg`, `userId`, `gameUpdate`, `chatMessage`).
            *   `_sendEcho`, `_requestId`: Emit initial events on connect.
            *   `_handle*` methods: Process incoming socket events. **Crucially, `_handleClientMessage` and `_handleServerMessage` call `app.callbackOnClientMsg` and `app.callbackOnServerMsg` respectively.** `_handleGameUpdate` calls `_processGameUpdate` which creates `Game.fromJson` and calls `onGameUpdate` callback (passed by `GameService`).
            *   `createGame`, `joinGame`, `rollDice`, `selectCell`, `sendChatMessage`: Emit specific actions (`sendToServer`).
            *   `sendToClients`, `sendToServer`: Generic emit methods.
            *   `disconnect`: Disconnects socket.
            *   `_updateState`: Calls `context.read<SetStateCubit>().setState()` to trigger UI rebuilds.

5.  **`lib/services/game_service.dart`**
    *   **Imports:** `models/game.dart`, `models/board_cell.dart`, `services/socket_service.dart`.
    *   **Class:** `GameService`
        *   **State:** `_game: Game?`.
        *   **Dependencies:** `socketService: SocketService`, `onGameUpdated`, `onError` callbacks.
        *   **Initialization:** Registers `_handleGameUpdate` with `socketService.onGameUpdate`.
        *   **Methods:**
            *   `createGame`, `joinGame`: Call corresponding `socketService` methods.
            *   `rollDice`: Checks `_game` state (`isMyTurn`, `canRoll`), calls `socketService.rollDice`.
            *   `calculateScoreForCell`: Contains Yatzy scoring logic based on dice and cell label. Uses private `_calculate*Score` helpers.
            *   `selectCell`: Checks `_game` state (`isMyTurn`), calculates score using `calculateScoreForCell`, calls `socketService.selectCell`.

6.  **`lib/services/http_service.dart`**
    *   **Imports:** `dart:convert`, `http`.
    *   **Class:** `HttpService`
        *   **Methods:** Wrappers around `http.get`, `http.post`, `http.delete` for interacting with the backend REST API (primarily auth and initial top score loading).

7.  **`lib/application/application.dart`** (and Extensions)
    *   **Imports:** `flutter`, `flutter_bloc`, `dices/*`, `services/*`, `models/*`, `states/*`, `utils/*`, `startup.dart`, etc.
    *   **Class:** `Application` (Central UI logic/state holder, accessed via `startup.app`)
        *   **Dependencies:** `context`, `gameDices: Dices`, `inputItems: InputItems`. **Holds a `socketService: SocketService?` reference set via `setSocketService`.**
        *   **State:** `gameType`, `nrPlayers`, `gameData`, `gameId`, `playerIds`, `myPlayerId`, `playerToMove`, `gameStarted`, `gameFinished`, board state arrays (`cellValue`, `fixedCell`, `appText`, `appColors`, etc.), `isSpectating`.
        *   **Initialization:** Sets callbacks on `gameDices`. Calls `languagesSetup`.
        *   **`lib/application/communication_application.dart` (Extension):**
            *   `callbackOnServerMsg`: **Core message handler.** Switches on `data['action']`. Handles `onGetId`, `onGameStart` (sets up game state, navigates via router), `onRequestGames` (updates `games` list), `onGameUpdate` (calls `_processGameUpdate`), `onGameAborted` (resets state, navigates), `onGameFinished` (sets flag, requests top scores), `onTopScoresUpdate` (calls `topScore.updateScoresFromData`).
            *   `_processGameUpdate`: Updates `gameData` and local state (`playerToMove`, `playerActive`), triggers UI rebuild. Handles spectator updates.
            *   `_checkIfPlayerAborted`: Compares `gameData` player list with `games` list to detect disconnects, calls `handlePlayerAbort`.
            *   `handlePlayerAbort`, `advanceToNextActivePlayer`: Manages UI state for inactive/aborted players and turn advancement.
            *   `chatCallbackOnSubmitted`: Formats chat message, calls `socketService.sendToClients`.
            *   `updateChat`: Adds received message to `chat.messages`.
            *   `callbackOnClientMsg`: Handles `sendSelection`, `sendDices`, `chatMessage` coming from *other* clients (forwarded by server). Updates local UI state (`appColors`, `fixedCell`, `cellValue`, dice state).
        *   **`lib/application/application_functions_internal.dart` (Extension):**
            *   `cellClick`: Handles user tapping a cell. Validates turn/cell state. Creates `sendSelection` message (using `utils/yatzy_mapping_client.getSelectionLabel`). Calls `socketService.sendToClients`. Calls `applyLocalSelection` (Optimistic UI).
            *   `applyLocalSelection`: Updates local UI state (`fixedCell`, `cellValue`, `appText`, scores) immediately after selection. Calls `colorBoard`, `gameDices.clearDices`. **Does NOT advance turn (waits for server).**
            *   `colorBoard`: Updates `appColors` array based on `playerToMove`, `playerActive`, `fixedCell`.
        *   **`lib/application/application_functions_internal_calc_dice_values.dart` (Extension):**
            *   Contains pure functions (`calcOnes`, `calcPair`, `calcYatzy`, etc.) for calculating potential cell scores based on `gameDices.diceValue`. Used by `updateDiceValues`.
        *   **`lib/application/widget_application.dart` (Contains Widgets):**
            *   `WidgetSetupGameBoard`: Builds the main game board UI using `Positioned` widgets based on `app` state arrays (`boardXPos`, `cellValue`, `appText`, etc.). Uses `AnimatedBuilder` with `app.animation`. Includes `GestureDetector` for cell taps (`cellClick`) and drag focus.
            *   `WidgetDisplayGameStatus`: Shows current player turn or game finished message.
        *   **`lib/application/widget_application_scaffold.dart` (Extension):**
            *   `widgetScaffold`: Builds the main `Scaffold` for the `ApplicationView`. Arranges core widgets (`WidgetDices`, `WidgetTopScore`, `WidgetSetupGameBoard`, `WidgetChat`, etc.) using `Positioned`. Handles layout logic (portrait/landscape). Includes floating action button for settings. Manages tutorial overlays.
        *   **`lib/application/widget_application_settings.dart` (Extension):**
            *   `widgetScaffoldSettings`: Builds the `Scaffold` for the `SettingsView`. Uses `TabBar` and `TabBarView`.
            *   Includes UI elements for game type, player count, username, language, Unity settings.
            *   `widgetWaitingGame`: Builds the list of available games and spectate buttons. Calls `onAttemptJoinGame` or `onSpectateGame`.
            *   `_buildGameTypeSelection`, `onStartGameButton`, `onChangeUserName`. `onStartGameButton` sends `requestGame` via `socketService` or starts offline game.
            *   `_buildTopScoresWidget`: Renders top scores using data from `topScore` instance.
            *   `onSpectateGame`: Sends `spectateGame` message via `socketService`, sets `isSpectating` flag. Renders `SpectatorGameBoard`.

8.  **`lib/dices/dices.dart`** (and Extensions)
    *   **Imports:** `flutter`, `input_items`, `flutter_unity_widget`.
    *   **Class:** `Dices` (extends `LanguagesDices`)
        *   **State:** Dice values (`diceValue`), hold status (`holdDices`), roll count (`nrRolls`), Unity controller (`unityWidgetController`), Unity state flags (`unityDices`, `unityCreated`, etc.).
        *   **Dependencies:** `setState` callback, `inputItems`. Callbacks `callbackUpdateDiceValues`, `callbackUnityCreated`, `callbackCheckPlayerToMove` (set externally by `Application`).
        *   **Methods:** `clearDices`, `initDices`, `holdDice`, `updateDiceImages`, `rollDices` (updates state, calls `callbackUpdateDiceValues`).
        *   **`lib/dices/unity_communication.dart` (Extension):**
            *   `send*ToUnity`: Methods to post JSON messages (`UnityMessage`) to the Unity widget (`unityWidgetController.postMessage`).
            *   `onUnityMessage`: Handles messages *from* Unity (e.g., dice roll results, Unity identifier). Parses JSON, updates dice state, calls `callbackUpdateDiceValues`.
            *   `onUnityCreated`: Callback when Unity widget is ready. Stores controller, sets `unityCreated` flag, sends initial messages, calls `callbackUnityCreated`.
        *   **`lib/dices/widget_dices.dart` (Widget):**
            *   Builds either the `UnityWidget` or the 2D dice UI based on `app.gameDices.unityDices`.
            *   2D UI uses `Positioned` images and `GestureDetector` for holding dice (`holdDice`), `Listener` for rolling (`rollDices`). Uses `AnimatedBuilder` for roll animation.

9.  **`lib/views/*.dart`**
    *   **`application_view.dart`:** `@RoutePage`. Builds the main game screen. Uses `BlocBuilder<SetStateCubit, int>` to rebuild. Calls `app.widgetScaffold`. Includes logic to show "Game Finished" dialog based on `app.gameFinished`. Sets `mainPageLoaded`. Initializes `Tutorial`, `AnimationsApplication`.
    *   **`settings_view.dart`:** `@RoutePage`. Builds the settings screen. Uses `BlocBuilder<SetStateCubit, int>`. Calls `app.widgetScaffoldSettings`. Initializes `TabController`.

10. **Other Modules:**
    *   **`lib/chat/*`:** UI (`WidgetChat`) and logic (`Chat`, `LanguagesChat`) for the chat component. `WidgetChat` uses `ListView.builder`. `Chat` handles messages and calls `app.chatCallbackOnSubmitted`.
    *   **`lib/top_score/*`:** UI (`WidgetTopScore`) and logic (`TopScore`, `LanguagesTopScore`). `WidgetTopScore` displays scores from `topScore.topScores` using `ListView.builder`. `TopScore` fetches/updates scores via `HttpService` and potentially updates via WebSocket callback (`updateScoresFromData`).
    *   **`lib/scroll/*`:** UI (`WidgetAnimationsScroll`) and logic for the scrolling text animation.
    *   **`lib/tutorial/*`:** Logic (`Tutorial`) and potentially widgets for the tutorial arrows/hints overlay.
    *   **`lib/states/*`:** Bloc/Cubit definitions (`LanguageBloc`, `SetStateCubit`) for managing language and triggering general UI updates.
    *   **`lib/router/*`:** AutoRoute setup (`AppRouter`, `router.gr.dart`).
    *   **`lib/models/*`:** Client-side data models (`BoardCell`, `Game`, `Player`). `Game.fromJson` is important for parsing server updates.
    *   **`lib/widgets/spectator_game_board.dart`:** Renders a table-based view of the game state, designed for spectators. Reads data directly from the `gameData` map passed to it.
    *   **`lib/utils/yatzy_mapping_client.dart`:** Client-side version of index-to-label mapping, crucial for `cellClick`. **Must match server version.**
    *   **`lib/shared_preferences.dart`:** Wrapper for `shared_preferences` plugin.
    *   **`lib/input_items/input_items.dart`:** Contains helper functions to create common UI widgets (buttons, text fields, checkboxes, etc.).
    *   **`lib/startup.dart`:** Defines global variables/flags (`isOnline`, `localhost`, `app`, `dices`, `chat`, etc.) used across the application. **This acts like a global state container/service locator, tightly coupling components.**

---

**Key Observations & Potential Areas for Tasks:**

1.  **Global State (`startup.dart`):** The heavy reliance on global variables in `startup.dart` (like `app`, `dices`, `chat`) makes dependencies less explicit and testing harder. Refactoring might involve using `ServiceProvider` or `GetIt` more extensively.
2.  **Backend/Frontend Sync:** The `yatzyMapping` utils must be kept identical. Game state synchronization relies heavily on the `onGameUpdate`, `onServerMsg`, and `onClientMsg` Socket.IO events.
3.  **State Management:** Frontend uses `SetStateCubit` for general UI refreshes, often triggered after processing socket messages or user interactions in the `Application` class extensions. `LanguageBloc` handles language state. The core game state seems managed within the `Application` instance (`app`).
4.  **Socket Communication:** `SocketService` is the central hub for client-server communication. It receives raw messages and delegates processing primarily to `app` (via `callbackOnServerMsg` / `callbackOnClientMsg`).
5.  **Unity Integration:** `Dices` class and its extensions (`UnityCommunication`, `WidgetDices`) manage the `flutter_unity_widget`, sending/receiving messages for 3D dice rendering and interactions.
6.  **Spectator Mode:** Implemented in both backend (`GameService`, `GameController`, `spectateGameRoute`) and frontend (`widget_application_settings`, `SpectatorGameBoard`). Relies on sending full game state and log data.
7.  **Optimistic UI:** `applyLocalSelection` in the frontend updates the UI immediately after a cell click, before server confirmation, for responsiveness. Server state (`onGameUpdate`) eventually overwrites/confirms this.
8.  **Top Scores:** Fetched via HTTP initially (`TopScore.loadTopScoreFromServer`) and potentially updated via WebSocket (`onTopScoresUpdate` -> `TopScore.updateScoresFromData`). Backend update via HTTP (`updateTopScore` route) doesn't directly trigger WebSocket broadcast (relies on `GameService.handleGameFinished` -> `TopScoreService.updateTopScore` which *does* broadcast internally).

---

**ANALYSIS END**

Code Base

Directory structure:
└── jesseburstrom-client/
    ├── backend/
    │   ├── README.md
    │   ├── package-lock.json
    │   ├── package.json
    │   ├── tsconfig.json
    │   ├── .gitignore
    │   └── src/
    │       ├── db.ts
    │       ├── license.txt
    │       ├── server.ts
    │       ├── controllers/
    │       │   ├── ChatController.ts
    │       │   ├── GameController.ts
    │       │   └── PlayerController.ts
    │       ├── models/
    │       │   ├── BoardCell.ts
    │       │   ├── Dice.ts
    │       │   ├── Game.ts
    │       │   └── Player.ts
    │       ├── routes/
    │       │   ├── getLogRoute.ts
    │       │   ├── getTopScores.ts
    │       │   ├── index.ts
    │       │   ├── logInRoute.ts
    │       │   ├── logRoute.ts
    │       │   ├── signUpRoute.ts
    │       │   ├── spectateGameRoute.ts
    │       │   └── updateTopScore.ts
    │       ├── services/
    │       │   ├── GameLogService.ts
    │       │   ├── GameService.ts
    │       │   └── TopScoreService.ts
    │       └── utils/
    │           ├── gameConfig.ts
    │           ├── index.ts
    │           └── yatzyMapping.ts
    └── lib/
        ├── injection.config.dart
        ├── injection.dart
        ├── main.dart
        ├── shared_preferences.dart
        ├── startup.dart
        ├── application/
        │   ├── animations_application.dart
        │   ├── application.dart
        │   ├── application_functions_internal.dart
        │   ├── application_functions_internal_calc_dice_values.dart
        │   ├── communication_application.dart
        │   ├── languages_application.dart
        │   ├── widget_application.dart
        │   ├── widget_application_scaffold.dart
        │   └── widget_application_settings.dart
        ├── chat/
        │   ├── chat.dart
        │   ├── languages_chat.dart
        │   └── widget_chat.dart
        ├── core/
        │   ├── app_widget.dart
        │   └── injectable_modules.dart
        ├── dices/
        │   ├── dices.dart
        │   ├── languages_dices.dart
        │   ├── unity_communication.dart
        │   ├── unity_message.dart
        │   └── widget_dices.dart
        ├── input_items/
        │   └── input_items.dart
        ├── models/
        │   ├── board_cell.dart
        │   ├── game.dart
        │   └── player.dart
        ├── router/
        │   ├── router.dart
        │   └── router.gr.dart
        ├── scroll/
        │   ├── animations_scroll.dart
        │   ├── languages_animations_scroll.dart
        │   └── widget_scroll.dart
        ├── services/
        │   ├── game_service.dart
        │   ├── http_service.dart
        │   ├── service_provider.dart
        │   └── socket_service.dart
        ├── states/
        │   ├── bloc/
        │   │   └── language/
        │   │       ├── language_bloc.dart
        │   │       └── language_event.dart
        │   └── cubit/
        │       └── state/
        │           └── state_cubit.dart
        ├── top_score/
        │   ├── languages_top_score.dart
        │   ├── top_score.dart
        │   └── widget_top_scores.dart
        ├── tutorial/
        │   └── tutorial.dart
        ├── utils/
        │   └── yatzy_mapping_client.dart
        ├── views/
        │   ├── application_view.dart
        │   └── settings_view.dart
        └── widgets/
            └── spectator_game_board.dart

================================================
File: backend/README.md
================================================
# react-demo

Server implementation of client system and my online portfolio 

[Link To Client](https://github.com/jesseburstrom/proj/)

[Link To Flutter Client](https://github.com/jesseburstrom/client_system/)



================================================
File: backend/package-lock.json
================================================
{
	"name": "back-end",
	"version": "1.0.0",
	"lockfileVersion": 2,
	"requires": true,
	"packages": {
		"": {
			"name": "back-end",
			"version": "1.0.0",
			"dependencies": {
				"bcrypt": "^5.0.1",
				"cors": "^2.8.5",
				"dotenv": "^16.0.1",
				"express": "^4.18.1",
				"jsonwebtoken": "^9.0.2",
				"mongodb": "^4.6.0",
				"socket.io": "^4.5.1",
				"uuid": "^8.3.2"
			},
			"devDependencies": {
				"@types/bcrypt": "^5.0.0",
				"@types/body-parser": "^1.19.2",
				"@types/cors": "^2.8.12",
				"@types/express": "^4.17.13",
				"@types/jsonwebtoken": "^8.5.8",
				"@types/node": "^17.0.38",
				"@types/nodemon": "^1.19.1",
				"@types/uuid": "^8.3.4",
				"nodemon": "^3.1.9"
			}
		},
		"node_modules/@aws-crypto/sha256-browser": {
			"version": "5.2.0",
			"resolved": "https://registry.npmjs.org/@aws-crypto/sha256-browser/-/sha256-browser-5.2.0.tgz",
			"integrity": "sha512-AXfN/lGotSQwu6HNcEsIASo7kWXZ5HYWvfOmSNKDsEqC4OashTp8alTmaz+F7TC2L083SFv5RdB+qU3Vs1kZqw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-crypto/sha256-js": "^5.2.0",
				"@aws-crypto/supports-web-crypto": "^5.2.0",
				"@aws-crypto/util": "^5.2.0",
				"@aws-sdk/types": "^3.222.0",
				"@aws-sdk/util-locate-window": "^3.0.0",
				"@smithy/util-utf8": "^2.0.0",
				"tslib": "^2.6.2"
			}
		},
		"node_modules/@aws-crypto/sha256-browser/node_modules/@smithy/is-array-buffer": {
			"version": "2.2.0",
			"resolved": "https://registry.npmjs.org/@smithy/is-array-buffer/-/is-array-buffer-2.2.0.tgz",
			"integrity": "sha512-GGP3O9QFD24uGeAXYUjwSTXARoqpZykHadOmA8G5vfJPK0/DC67qa//0qvqrJzL1xc8WQWX7/yc7fwudjPHPhA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=14.0.0"
			}
		},
		"node_modules/@aws-crypto/sha256-browser/node_modules/@smithy/util-buffer-from": {
			"version": "2.2.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-buffer-from/-/util-buffer-from-2.2.0.tgz",
			"integrity": "sha512-IJdWBbTcMQ6DA0gdNhh/BwrLkDR+ADW5Kr1aZmd4k3DIF6ezMV4R2NIAmT08wQJ3yUK82thHWmC/TnK/wpMMIA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/is-array-buffer": "^2.2.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=14.0.0"
			}
		},
		"node_modules/@aws-crypto/sha256-browser/node_modules/@smithy/util-utf8": {
			"version": "2.3.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-utf8/-/util-utf8-2.3.0.tgz",
			"integrity": "sha512-R8Rdn8Hy72KKcebgLiv8jQcQkXoLMOGGv5uI1/k0l+snqkOzQ1R0ChUBCxWMlBsFMekWjq0wRudIweFs7sKT5A==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/util-buffer-from": "^2.2.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=14.0.0"
			}
		},
		"node_modules/@aws-crypto/sha256-js": {
			"version": "5.2.0",
			"resolved": "https://registry.npmjs.org/@aws-crypto/sha256-js/-/sha256-js-5.2.0.tgz",
			"integrity": "sha512-FFQQyu7edu4ufvIZ+OadFpHHOt+eSTBaYaki44c+akjg7qZg9oOQeLlk77F6tSYqjDAFClrHJk9tMf0HdVyOvA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-crypto/util": "^5.2.0",
				"@aws-sdk/types": "^3.222.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=16.0.0"
			}
		},
		"node_modules/@aws-crypto/supports-web-crypto": {
			"version": "5.2.0",
			"resolved": "https://registry.npmjs.org/@aws-crypto/supports-web-crypto/-/supports-web-crypto-5.2.0.tgz",
			"integrity": "sha512-iAvUotm021kM33eCdNfwIN//F77/IADDSs58i+MDaOqFrVjZo9bAal0NK7HurRuWLLpF1iLX7gbWrjHjeo+YFg==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"tslib": "^2.6.2"
			}
		},
		"node_modules/@aws-crypto/util": {
			"version": "5.2.0",
			"resolved": "https://registry.npmjs.org/@aws-crypto/util/-/util-5.2.0.tgz",
			"integrity": "sha512-4RkU9EsI6ZpBve5fseQlGNUWKMa1RLPQ1dnjnQoe07ldfIzcsGb5hC5W0Dm7u423KWzawlrpbjXBrXCEv9zazQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/types": "^3.222.0",
				"@smithy/util-utf8": "^2.0.0",
				"tslib": "^2.6.2"
			}
		},
		"node_modules/@aws-crypto/util/node_modules/@smithy/is-array-buffer": {
			"version": "2.2.0",
			"resolved": "https://registry.npmjs.org/@smithy/is-array-buffer/-/is-array-buffer-2.2.0.tgz",
			"integrity": "sha512-GGP3O9QFD24uGeAXYUjwSTXARoqpZykHadOmA8G5vfJPK0/DC67qa//0qvqrJzL1xc8WQWX7/yc7fwudjPHPhA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=14.0.0"
			}
		},
		"node_modules/@aws-crypto/util/node_modules/@smithy/util-buffer-from": {
			"version": "2.2.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-buffer-from/-/util-buffer-from-2.2.0.tgz",
			"integrity": "sha512-IJdWBbTcMQ6DA0gdNhh/BwrLkDR+ADW5Kr1aZmd4k3DIF6ezMV4R2NIAmT08wQJ3yUK82thHWmC/TnK/wpMMIA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/is-array-buffer": "^2.2.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=14.0.0"
			}
		},
		"node_modules/@aws-crypto/util/node_modules/@smithy/util-utf8": {
			"version": "2.3.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-utf8/-/util-utf8-2.3.0.tgz",
			"integrity": "sha512-R8Rdn8Hy72KKcebgLiv8jQcQkXoLMOGGv5uI1/k0l+snqkOzQ1R0ChUBCxWMlBsFMekWjq0wRudIweFs7sKT5A==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/util-buffer-from": "^2.2.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=14.0.0"
			}
		},
		"node_modules/@aws-sdk/client-cognito-identity": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/client-cognito-identity/-/client-cognito-identity-3.758.0.tgz",
			"integrity": "sha512-8bOXVYtf/0OUN0jXTIHLv3V0TAS6kvvCRAy7nmiL/fDde0O+ChW1WZU7CVPAOtFEpFCdKskDcxFspM7m1k6qyg==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-crypto/sha256-browser": "5.2.0",
				"@aws-crypto/sha256-js": "5.2.0",
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/credential-provider-node": "3.758.0",
				"@aws-sdk/middleware-host-header": "3.734.0",
				"@aws-sdk/middleware-logger": "3.734.0",
				"@aws-sdk/middleware-recursion-detection": "3.734.0",
				"@aws-sdk/middleware-user-agent": "3.758.0",
				"@aws-sdk/region-config-resolver": "3.734.0",
				"@aws-sdk/types": "3.734.0",
				"@aws-sdk/util-endpoints": "3.743.0",
				"@aws-sdk/util-user-agent-browser": "3.734.0",
				"@aws-sdk/util-user-agent-node": "3.758.0",
				"@smithy/config-resolver": "^4.0.1",
				"@smithy/core": "^3.1.5",
				"@smithy/fetch-http-handler": "^5.0.1",
				"@smithy/hash-node": "^4.0.1",
				"@smithy/invalid-dependency": "^4.0.1",
				"@smithy/middleware-content-length": "^4.0.1",
				"@smithy/middleware-endpoint": "^4.0.6",
				"@smithy/middleware-retry": "^4.0.7",
				"@smithy/middleware-serde": "^4.0.2",
				"@smithy/middleware-stack": "^4.0.1",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/node-http-handler": "^4.0.3",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"@smithy/url-parser": "^4.0.1",
				"@smithy/util-base64": "^4.0.0",
				"@smithy/util-body-length-browser": "^4.0.0",
				"@smithy/util-body-length-node": "^4.0.0",
				"@smithy/util-defaults-mode-browser": "^4.0.7",
				"@smithy/util-defaults-mode-node": "^4.0.7",
				"@smithy/util-endpoints": "^3.0.1",
				"@smithy/util-middleware": "^4.0.1",
				"@smithy/util-retry": "^4.0.1",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/client-sso": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/client-sso/-/client-sso-3.758.0.tgz",
			"integrity": "sha512-BoGO6IIWrLyLxQG6txJw6RT2urmbtlwfggapNCrNPyYjlXpzTSJhBYjndg7TpDATFd0SXL0zm8y/tXsUXNkdYQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-crypto/sha256-browser": "5.2.0",
				"@aws-crypto/sha256-js": "5.2.0",
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/middleware-host-header": "3.734.0",
				"@aws-sdk/middleware-logger": "3.734.0",
				"@aws-sdk/middleware-recursion-detection": "3.734.0",
				"@aws-sdk/middleware-user-agent": "3.758.0",
				"@aws-sdk/region-config-resolver": "3.734.0",
				"@aws-sdk/types": "3.734.0",
				"@aws-sdk/util-endpoints": "3.743.0",
				"@aws-sdk/util-user-agent-browser": "3.734.0",
				"@aws-sdk/util-user-agent-node": "3.758.0",
				"@smithy/config-resolver": "^4.0.1",
				"@smithy/core": "^3.1.5",
				"@smithy/fetch-http-handler": "^5.0.1",
				"@smithy/hash-node": "^4.0.1",
				"@smithy/invalid-dependency": "^4.0.1",
				"@smithy/middleware-content-length": "^4.0.1",
				"@smithy/middleware-endpoint": "^4.0.6",
				"@smithy/middleware-retry": "^4.0.7",
				"@smithy/middleware-serde": "^4.0.2",
				"@smithy/middleware-stack": "^4.0.1",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/node-http-handler": "^4.0.3",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"@smithy/url-parser": "^4.0.1",
				"@smithy/util-base64": "^4.0.0",
				"@smithy/util-body-length-browser": "^4.0.0",
				"@smithy/util-body-length-node": "^4.0.0",
				"@smithy/util-defaults-mode-browser": "^4.0.7",
				"@smithy/util-defaults-mode-node": "^4.0.7",
				"@smithy/util-endpoints": "^3.0.1",
				"@smithy/util-middleware": "^4.0.1",
				"@smithy/util-retry": "^4.0.1",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/core": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/core/-/core-3.758.0.tgz",
			"integrity": "sha512-0RswbdR9jt/XKemaLNuxi2gGr4xGlHyGxkTdhSQzCyUe9A9OPCoLl3rIESRguQEech+oJnbHk/wuiwHqTuP9sg==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/types": "3.734.0",
				"@smithy/core": "^3.1.5",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/signature-v4": "^5.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"@smithy/util-middleware": "^4.0.1",
				"fast-xml-parser": "4.4.1",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/credential-provider-cognito-identity": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-cognito-identity/-/credential-provider-cognito-identity-3.758.0.tgz",
			"integrity": "sha512-y/rHZqyChlEkNRr59gn4hv0gjhJwGmdCdW0JI1K9p3P9p7EurWGjr2M6+goTn3ilOlcAwrl5oFKR5jLt27TkOA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/client-cognito-identity": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/credential-provider-env": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-env/-/credential-provider-env-3.758.0.tgz",
			"integrity": "sha512-N27eFoRrO6MeUNumtNHDW9WOiwfd59LPXPqDrIa3kWL/s+fOKFHb9xIcF++bAwtcZnAxKkgpDCUP+INNZskE+w==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/credential-provider-http": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-http/-/credential-provider-http-3.758.0.tgz",
			"integrity": "sha512-Xt9/U8qUCiw1hihztWkNeIR+arg6P+yda10OuCHX6kFVx3auTlU7+hCqs3UxqniGU4dguHuftf3mRpi5/GJ33Q==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/fetch-http-handler": "^5.0.1",
				"@smithy/node-http-handler": "^4.0.3",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"@smithy/util-stream": "^4.1.2",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/credential-provider-ini": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-ini/-/credential-provider-ini-3.758.0.tgz",
			"integrity": "sha512-cymSKMcP5d+OsgetoIZ5QCe1wnp2Q/tq+uIxVdh9MbfdBBEnl9Ecq6dH6VlYS89sp4QKuxHxkWXVnbXU3Q19Aw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/credential-provider-env": "3.758.0",
				"@aws-sdk/credential-provider-http": "3.758.0",
				"@aws-sdk/credential-provider-process": "3.758.0",
				"@aws-sdk/credential-provider-sso": "3.758.0",
				"@aws-sdk/credential-provider-web-identity": "3.758.0",
				"@aws-sdk/nested-clients": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/credential-provider-imds": "^4.0.1",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/shared-ini-file-loader": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/credential-provider-node": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-node/-/credential-provider-node-3.758.0.tgz",
			"integrity": "sha512-+DaMv63wiq7pJrhIQzZYMn4hSarKiizDoJRvyR7WGhnn0oQ/getX9Z0VNCV3i7lIFoLNTb7WMmQ9k7+z/uD5EQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/credential-provider-env": "3.758.0",
				"@aws-sdk/credential-provider-http": "3.758.0",
				"@aws-sdk/credential-provider-ini": "3.758.0",
				"@aws-sdk/credential-provider-process": "3.758.0",
				"@aws-sdk/credential-provider-sso": "3.758.0",
				"@aws-sdk/credential-provider-web-identity": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/credential-provider-imds": "^4.0.1",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/shared-ini-file-loader": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/credential-provider-process": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-process/-/credential-provider-process-3.758.0.tgz",
			"integrity": "sha512-AzcY74QTPqcbXWVgjpPZ3HOmxQZYPROIBz2YINF0OQk0MhezDWV/O7Xec+K1+MPGQO3qS6EDrUUlnPLjsqieHA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/shared-ini-file-loader": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/credential-provider-sso": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-sso/-/credential-provider-sso-3.758.0.tgz",
			"integrity": "sha512-x0FYJqcOLUCv8GLLFDYMXRAQKGjoM+L0BG4BiHYZRDf24yQWFCAZsCQAYKo6XZYh2qznbsW6f//qpyJ5b0QVKQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/client-sso": "3.758.0",
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/token-providers": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/shared-ini-file-loader": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/credential-provider-web-identity": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-web-identity/-/credential-provider-web-identity-3.758.0.tgz",
			"integrity": "sha512-XGguXhBqiCXMXRxcfCAVPlMbm3VyJTou79r/3mxWddHWF0XbhaQiBIbUz6vobVTD25YQRbWSmSch7VA8kI5Lrw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/nested-clients": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/credential-providers": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-providers/-/credential-providers-3.758.0.tgz",
			"integrity": "sha512-BaGVBdm9ynsErIc/mLuUwJ1OQcL/pkhCuAm24jpsif3evZ5wgyZnEAZB2yRin+mQnQaQT3L+KvTbdKGfjL8+fQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/client-cognito-identity": "3.758.0",
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/credential-provider-cognito-identity": "3.758.0",
				"@aws-sdk/credential-provider-env": "3.758.0",
				"@aws-sdk/credential-provider-http": "3.758.0",
				"@aws-sdk/credential-provider-ini": "3.758.0",
				"@aws-sdk/credential-provider-node": "3.758.0",
				"@aws-sdk/credential-provider-process": "3.758.0",
				"@aws-sdk/credential-provider-sso": "3.758.0",
				"@aws-sdk/credential-provider-web-identity": "3.758.0",
				"@aws-sdk/nested-clients": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/core": "^3.1.5",
				"@smithy/credential-provider-imds": "^4.0.1",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/middleware-host-header": {
			"version": "3.734.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/middleware-host-header/-/middleware-host-header-3.734.0.tgz",
			"integrity": "sha512-LW7RRgSOHHBzWZnigNsDIzu3AiwtjeI2X66v+Wn1P1u+eXssy1+up4ZY/h+t2sU4LU36UvEf+jrZti9c6vRnFw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/types": "3.734.0",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/middleware-logger": {
			"version": "3.734.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/middleware-logger/-/middleware-logger-3.734.0.tgz",
			"integrity": "sha512-mUMFITpJUW3LcKvFok176eI5zXAUomVtahb9IQBwLzkqFYOrMJvWAvoV4yuxrJ8TlQBG8gyEnkb9SnhZvjg67w==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/types": "3.734.0",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/middleware-recursion-detection": {
			"version": "3.734.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/middleware-recursion-detection/-/middleware-recursion-detection-3.734.0.tgz",
			"integrity": "sha512-CUat2d9ITsFc2XsmeiRQO96iWpxSKYFjxvj27Hc7vo87YUHRnfMfnc8jw1EpxEwMcvBD7LsRa6vDNky6AjcrFA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/types": "3.734.0",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/middleware-user-agent": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/middleware-user-agent/-/middleware-user-agent-3.758.0.tgz",
			"integrity": "sha512-iNyehQXtQlj69JCgfaOssgZD4HeYGOwxcaKeG6F+40cwBjTAi0+Ph1yfDwqk2qiBPIRWJ/9l2LodZbxiBqgrwg==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@aws-sdk/util-endpoints": "3.743.0",
				"@smithy/core": "^3.1.5",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/nested-clients": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/nested-clients/-/nested-clients-3.758.0.tgz",
			"integrity": "sha512-YZ5s7PSvyF3Mt2h1EQulCG93uybprNGbBkPmVuy/HMMfbFTt4iL3SbKjxqvOZelm86epFfj7pvK7FliI2WOEcg==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-crypto/sha256-browser": "5.2.0",
				"@aws-crypto/sha256-js": "5.2.0",
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/middleware-host-header": "3.734.0",
				"@aws-sdk/middleware-logger": "3.734.0",
				"@aws-sdk/middleware-recursion-detection": "3.734.0",
				"@aws-sdk/middleware-user-agent": "3.758.0",
				"@aws-sdk/region-config-resolver": "3.734.0",
				"@aws-sdk/types": "3.734.0",
				"@aws-sdk/util-endpoints": "3.743.0",
				"@aws-sdk/util-user-agent-browser": "3.734.0",
				"@aws-sdk/util-user-agent-node": "3.758.0",
				"@smithy/config-resolver": "^4.0.1",
				"@smithy/core": "^3.1.5",
				"@smithy/fetch-http-handler": "^5.0.1",
				"@smithy/hash-node": "^4.0.1",
				"@smithy/invalid-dependency": "^4.0.1",
				"@smithy/middleware-content-length": "^4.0.1",
				"@smithy/middleware-endpoint": "^4.0.6",
				"@smithy/middleware-retry": "^4.0.7",
				"@smithy/middleware-serde": "^4.0.2",
				"@smithy/middleware-stack": "^4.0.1",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/node-http-handler": "^4.0.3",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"@smithy/url-parser": "^4.0.1",
				"@smithy/util-base64": "^4.0.0",
				"@smithy/util-body-length-browser": "^4.0.0",
				"@smithy/util-body-length-node": "^4.0.0",
				"@smithy/util-defaults-mode-browser": "^4.0.7",
				"@smithy/util-defaults-mode-node": "^4.0.7",
				"@smithy/util-endpoints": "^3.0.1",
				"@smithy/util-middleware": "^4.0.1",
				"@smithy/util-retry": "^4.0.1",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/region-config-resolver": {
			"version": "3.734.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/region-config-resolver/-/region-config-resolver-3.734.0.tgz",
			"integrity": "sha512-Lvj1kPRC5IuJBr9DyJ9T9/plkh+EfKLy+12s/mykOy1JaKHDpvj+XGy2YO6YgYVOb8JFtaqloid+5COtje4JTQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/types": "3.734.0",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/util-config-provider": "^4.0.0",
				"@smithy/util-middleware": "^4.0.1",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/token-providers": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/token-providers/-/token-providers-3.758.0.tgz",
			"integrity": "sha512-ckptN1tNrIfQUaGWm/ayW1ddG+imbKN7HHhjFdS4VfItsP0QQOB0+Ov+tpgb4MoNR4JaUghMIVStjIeHN2ks1w==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/nested-clients": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/shared-ini-file-loader": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/types": {
			"version": "3.734.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/types/-/types-3.734.0.tgz",
			"integrity": "sha512-o11tSPTT70nAkGV1fN9wm/hAIiLPyWX6SuGf+9JyTp7S/rC2cFWhR26MvA69nplcjNaXVzB0f+QFrLXXjOqCrg==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/util-endpoints": {
			"version": "3.743.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/util-endpoints/-/util-endpoints-3.743.0.tgz",
			"integrity": "sha512-sN1l559zrixeh5x+pttrnd0A3+r34r0tmPkJ/eaaMaAzXqsmKU/xYre9K3FNnsSS1J1k4PEfk/nHDTVUgFYjnw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/types": "3.734.0",
				"@smithy/types": "^4.1.0",
				"@smithy/util-endpoints": "^3.0.1",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/util-locate-window": {
			"version": "3.723.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/util-locate-window/-/util-locate-window-3.723.0.tgz",
			"integrity": "sha512-Yf2CS10BqK688DRsrKI/EO6B8ff5J86NXe4C+VCysK7UOgN0l1zOTeTukZ3H8Q9tYYX3oaF1961o8vRkFm7Nmw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@aws-sdk/util-user-agent-browser": {
			"version": "3.734.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/util-user-agent-browser/-/util-user-agent-browser-3.734.0.tgz",
			"integrity": "sha512-xQTCus6Q9LwUuALW+S76OL0jcWtMOVu14q+GoLnWPUM7QeUw963oQcLhF7oq0CtaLLKyl4GOUfcwc773Zmwwng==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/types": "3.734.0",
				"@smithy/types": "^4.1.0",
				"bowser": "^2.11.0",
				"tslib": "^2.6.2"
			}
		},
		"node_modules/@aws-sdk/util-user-agent-node": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/util-user-agent-node/-/util-user-agent-node-3.758.0.tgz",
			"integrity": "sha512-A5EZw85V6WhoKMV2hbuFRvb9NPlxEErb4HPO6/SPXYY4QrjprIzScHxikqcWv1w4J3apB1wto9LPU3IMsYtfrw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@aws-sdk/middleware-user-agent": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			},
			"peerDependencies": {
				"aws-crt": ">=1.0.0"
			},
			"peerDependenciesMeta": {
				"aws-crt": {
					"optional": true
				}
			}
		},
		"node_modules/@mapbox/node-pre-gyp": {
			"version": "1.0.9",
			"resolved": "https://registry.npmjs.org/@mapbox/node-pre-gyp/-/node-pre-gyp-1.0.9.tgz",
			"integrity": "sha512-aDF3S3rK9Q2gey/WAttUlISduDItz5BU3306M9Eyv6/oS40aMprnopshtlKTykxRNIBEZuRMaZAnbrQ4QtKGyw==",
			"dependencies": {
				"detect-libc": "^2.0.0",
				"https-proxy-agent": "^5.0.0",
				"make-dir": "^3.1.0",
				"node-fetch": "^2.6.7",
				"nopt": "^5.0.0",
				"npmlog": "^5.0.1",
				"rimraf": "^3.0.2",
				"semver": "^7.3.5",
				"tar": "^6.1.11"
			},
			"bin": {
				"node-pre-gyp": "bin/node-pre-gyp"
			}
		},
		"node_modules/@mongodb-js/saslprep": {
			"version": "1.2.0",
			"resolved": "https://registry.npmjs.org/@mongodb-js/saslprep/-/saslprep-1.2.0.tgz",
			"integrity": "sha512-+ywrb0AqkfaYuhHs6LxKWgqbh3I72EpEgESCw37o+9qPx9WTCkgDm2B+eMrwehGtHBWHFU4GXvnSCNiFhhausg==",
			"license": "MIT",
			"optional": true,
			"dependencies": {
				"sparse-bitfield": "^3.0.3"
			}
		},
		"node_modules/@smithy/abort-controller": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/abort-controller/-/abort-controller-4.0.1.tgz",
			"integrity": "sha512-fiUIYgIgRjMWznk6iLJz35K2YxSLHzLBA/RC6lBrKfQ8fHbPfvk7Pk9UvpKoHgJjI18MnbPuEju53zcVy6KF1g==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/config-resolver": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/config-resolver/-/config-resolver-4.0.1.tgz",
			"integrity": "sha512-Igfg8lKu3dRVkTSEm98QpZUvKEOa71jDX4vKRcvJVyRc3UgN3j7vFMf0s7xLQhYmKa8kyJGQgUJDOV5V3neVlQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/util-config-provider": "^4.0.0",
				"@smithy/util-middleware": "^4.0.1",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/core": {
			"version": "3.1.5",
			"resolved": "https://registry.npmjs.org/@smithy/core/-/core-3.1.5.tgz",
			"integrity": "sha512-HLclGWPkCsekQgsyzxLhCQLa8THWXtB5PxyYN+2O6nkyLt550KQKTlbV2D1/j5dNIQapAZM1+qFnpBFxZQkgCA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/middleware-serde": "^4.0.2",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/util-body-length-browser": "^4.0.0",
				"@smithy/util-middleware": "^4.0.1",
				"@smithy/util-stream": "^4.1.2",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/credential-provider-imds": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/credential-provider-imds/-/credential-provider-imds-4.0.1.tgz",
			"integrity": "sha512-l/qdInaDq1Zpznpmev/+52QomsJNZ3JkTl5yrTl02V6NBgJOQ4LY0SFw/8zsMwj3tLe8vqiIuwF6nxaEwgf6mg==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/url-parser": "^4.0.1",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/fetch-http-handler": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/fetch-http-handler/-/fetch-http-handler-5.0.1.tgz",
			"integrity": "sha512-3aS+fP28urrMW2KTjb6z9iFow6jO8n3MFfineGbndvzGZit3taZhKWtTorf+Gp5RpFDDafeHlhfsGlDCXvUnJA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/querystring-builder": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/util-base64": "^4.0.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/hash-node": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/hash-node/-/hash-node-4.0.1.tgz",
			"integrity": "sha512-TJ6oZS+3r2Xu4emVse1YPB3Dq3d8RkZDKcPr71Nj/lJsdAP1c7oFzYqEn1IBc915TsgLl2xIJNuxCz+gLbLE0w==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/types": "^4.1.0",
				"@smithy/util-buffer-from": "^4.0.0",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/invalid-dependency": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/invalid-dependency/-/invalid-dependency-4.0.1.tgz",
			"integrity": "sha512-gdudFPf4QRQ5pzj7HEnu6FhKRi61BfH/Gk5Yf6O0KiSbr1LlVhgjThcvjdu658VE6Nve8vaIWB8/fodmS1rBPQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/is-array-buffer": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/is-array-buffer/-/is-array-buffer-4.0.0.tgz",
			"integrity": "sha512-saYhF8ZZNoJDTvJBEWgeBccCg+yvp1CX+ed12yORU3NilJScfc6gfch2oVb4QgxZrGUx3/ZJlb+c/dJbyupxlw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/middleware-content-length": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/middleware-content-length/-/middleware-content-length-4.0.1.tgz",
			"integrity": "sha512-OGXo7w5EkB5pPiac7KNzVtfCW2vKBTZNuCctn++TTSOMpe6RZO/n6WEC1AxJINn3+vWLKW49uad3lo/u0WJ9oQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/middleware-endpoint": {
			"version": "4.0.6",
			"resolved": "https://registry.npmjs.org/@smithy/middleware-endpoint/-/middleware-endpoint-4.0.6.tgz",
			"integrity": "sha512-ftpmkTHIFqgaFugcjzLZv3kzPEFsBFSnq1JsIkr2mwFzCraZVhQk2gqN51OOeRxqhbPTkRFj39Qd2V91E/mQxg==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/core": "^3.1.5",
				"@smithy/middleware-serde": "^4.0.2",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/shared-ini-file-loader": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/url-parser": "^4.0.1",
				"@smithy/util-middleware": "^4.0.1",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/middleware-retry": {
			"version": "4.0.7",
			"resolved": "https://registry.npmjs.org/@smithy/middleware-retry/-/middleware-retry-4.0.7.tgz",
			"integrity": "sha512-58j9XbUPLkqAcV1kHzVX/kAR16GT+j7DUZJqwzsxh1jtz7G82caZiGyyFgUvogVfNTg3TeAOIJepGc8TXF4AVQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/service-error-classification": "^4.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"@smithy/util-middleware": "^4.0.1",
				"@smithy/util-retry": "^4.0.1",
				"tslib": "^2.6.2",
				"uuid": "^9.0.1"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/middleware-retry/node_modules/uuid": {
			"version": "9.0.1",
			"resolved": "https://registry.npmjs.org/uuid/-/uuid-9.0.1.tgz",
			"integrity": "sha512-b+1eJOlsR9K8HJpow9Ok3fiWOWSIcIzXodvv0rQjVoOVNpWMpxf1wZNpt4y9h10odCNrqnYp1OBzRktckBe3sA==",
			"funding": [
				"https://github.com/sponsors/broofa",
				"https://github.com/sponsors/ctavan"
			],
			"license": "MIT",
			"optional": true,
			"bin": {
				"uuid": "dist/bin/uuid"
			}
		},
		"node_modules/@smithy/middleware-serde": {
			"version": "4.0.2",
			"resolved": "https://registry.npmjs.org/@smithy/middleware-serde/-/middleware-serde-4.0.2.tgz",
			"integrity": "sha512-Sdr5lOagCn5tt+zKsaW+U2/iwr6bI9p08wOkCp6/eL6iMbgdtc2R5Ety66rf87PeohR0ExI84Txz9GYv5ou3iQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/middleware-stack": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/middleware-stack/-/middleware-stack-4.0.1.tgz",
			"integrity": "sha512-dHwDmrtR/ln8UTHpaIavRSzeIk5+YZTBtLnKwDW3G2t6nAupCiQUvNzNoHBpik63fwUaJPtlnMzXbQrNFWssIA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/node-config-provider": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/node-config-provider/-/node-config-provider-4.0.1.tgz",
			"integrity": "sha512-8mRTjvCtVET8+rxvmzRNRR0hH2JjV0DFOmwXPrISmTIJEfnCBugpYYGAsCj8t41qd+RB5gbheSQ/6aKZCQvFLQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/property-provider": "^4.0.1",
				"@smithy/shared-ini-file-loader": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/node-http-handler": {
			"version": "4.0.3",
			"resolved": "https://registry.npmjs.org/@smithy/node-http-handler/-/node-http-handler-4.0.3.tgz",
			"integrity": "sha512-dYCLeINNbYdvmMLtW0VdhW1biXt+PPCGazzT5ZjKw46mOtdgToQEwjqZSS9/EN8+tNs/RO0cEWG044+YZs97aA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/abort-controller": "^4.0.1",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/querystring-builder": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/property-provider": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/property-provider/-/property-provider-4.0.1.tgz",
			"integrity": "sha512-o+VRiwC2cgmk/WFV0jaETGOtX16VNPp2bSQEzu0whbReqE1BMqsP2ami2Vi3cbGVdKu1kq9gQkDAGKbt0WOHAQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/protocol-http": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/protocol-http/-/protocol-http-5.0.1.tgz",
			"integrity": "sha512-TE4cpj49jJNB/oHyh/cRVEgNZaoPaxd4vteJNB0yGidOCVR0jCw/hjPVsT8Q8FRmj8Bd3bFZt8Dh7xGCT+xMBQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/querystring-builder": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/querystring-builder/-/querystring-builder-4.0.1.tgz",
			"integrity": "sha512-wU87iWZoCbcqrwszsOewEIuq+SU2mSoBE2CcsLwE0I19m0B2gOJr1MVjxWcDQYOzHbR1xCk7AcOBbGFUYOKvdg==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/types": "^4.1.0",
				"@smithy/util-uri-escape": "^4.0.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/querystring-parser": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/querystring-parser/-/querystring-parser-4.0.1.tgz",
			"integrity": "sha512-Ma2XC7VS9aV77+clSFylVUnPZRindhB7BbmYiNOdr+CHt/kZNJoPP0cd3QxCnCFyPXC4eybmyE98phEHkqZ5Jw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/service-error-classification": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/service-error-classification/-/service-error-classification-4.0.1.tgz",
			"integrity": "sha512-3JNjBfOWpj/mYfjXJHB4Txc/7E4LVq32bwzE7m28GN79+M1f76XHflUaSUkhOriprPDzev9cX/M+dEB80DNDKA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/types": "^4.1.0"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/shared-ini-file-loader": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/shared-ini-file-loader/-/shared-ini-file-loader-4.0.1.tgz",
			"integrity": "sha512-hC8F6qTBbuHRI/uqDgqqi6J0R4GtEZcgrZPhFQnMhfJs3MnUTGSnR1NSJCJs5VWlMydu0kJz15M640fJlRsIOw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/signature-v4": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/signature-v4/-/signature-v4-5.0.1.tgz",
			"integrity": "sha512-nCe6fQ+ppm1bQuw5iKoeJ0MJfz2os7Ic3GBjOkLOPtavbD1ONoyE3ygjBfz2ythFWm4YnRm6OxW+8p/m9uCoIA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/is-array-buffer": "^4.0.0",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/util-hex-encoding": "^4.0.0",
				"@smithy/util-middleware": "^4.0.1",
				"@smithy/util-uri-escape": "^4.0.0",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/smithy-client": {
			"version": "4.1.6",
			"resolved": "https://registry.npmjs.org/@smithy/smithy-client/-/smithy-client-4.1.6.tgz",
			"integrity": "sha512-UYDolNg6h2O0L+cJjtgSyKKvEKCOa/8FHYJnBobyeoeWDmNpXjwOAtw16ezyeu1ETuuLEOZbrynK0ZY1Lx9Jbw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/core": "^3.1.5",
				"@smithy/middleware-endpoint": "^4.0.6",
				"@smithy/middleware-stack": "^4.0.1",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/util-stream": "^4.1.2",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/types": {
			"version": "4.1.0",
			"resolved": "https://registry.npmjs.org/@smithy/types/-/types-4.1.0.tgz",
			"integrity": "sha512-enhjdwp4D7CXmwLtD6zbcDMbo6/T6WtuuKCY49Xxc6OMOmUWlBEBDREsxxgV2LIdeQPW756+f97GzcgAwp3iLw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/url-parser": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/url-parser/-/url-parser-4.0.1.tgz",
			"integrity": "sha512-gPXcIEUtw7VlK8f/QcruNXm7q+T5hhvGu9tl63LsJPZ27exB6dtNwvh2HIi0v7JcXJ5emBxB+CJxwaLEdJfA+g==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/querystring-parser": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/util-base64": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-base64/-/util-base64-4.0.0.tgz",
			"integrity": "sha512-CvHfCmO2mchox9kjrtzoHkWHxjHZzaFojLc8quxXY7WAAMAg43nuxwv95tATVgQFNDwd4M9S1qFzj40Ul41Kmg==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/util-buffer-from": "^4.0.0",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/util-body-length-browser": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-body-length-browser/-/util-body-length-browser-4.0.0.tgz",
			"integrity": "sha512-sNi3DL0/k64/LO3A256M+m3CDdG6V7WKWHdAiBBMUN8S3hK3aMPhwnPik2A/a2ONN+9doY9UxaLfgqsIRg69QA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/util-body-length-node": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-body-length-node/-/util-body-length-node-4.0.0.tgz",
			"integrity": "sha512-q0iDP3VsZzqJyje8xJWEJCNIu3lktUGVoSy1KB0UWym2CL1siV3artm+u1DFYTLejpsrdGyCSWBdGNjJzfDPjg==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/util-buffer-from": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-buffer-from/-/util-buffer-from-4.0.0.tgz",
			"integrity": "sha512-9TOQ7781sZvddgO8nxueKi3+yGvkY35kotA0Y6BWRajAv8jjmigQ1sBwz0UX47pQMYXJPahSKEKYFgt+rXdcug==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/is-array-buffer": "^4.0.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/util-config-provider": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-config-provider/-/util-config-provider-4.0.0.tgz",
			"integrity": "sha512-L1RBVzLyfE8OXH+1hsJ8p+acNUSirQnWQ6/EgpchV88G6zGBTDPdXiiExei6Z1wR2RxYvxY/XLw6AMNCCt8H3w==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/util-defaults-mode-browser": {
			"version": "4.0.7",
			"resolved": "https://registry.npmjs.org/@smithy/util-defaults-mode-browser/-/util-defaults-mode-browser-4.0.7.tgz",
			"integrity": "sha512-CZgDDrYHLv0RUElOsmZtAnp1pIjwDVCSuZWOPhIOBvG36RDfX1Q9+6lS61xBf+qqvHoqRjHxgINeQz47cYFC2Q==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/property-provider": "^4.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"bowser": "^2.11.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/util-defaults-mode-node": {
			"version": "4.0.7",
			"resolved": "https://registry.npmjs.org/@smithy/util-defaults-mode-node/-/util-defaults-mode-node-4.0.7.tgz",
			"integrity": "sha512-79fQW3hnfCdrfIi1soPbK3zmooRFnLpSx3Vxi6nUlqaaQeC5dm8plt4OTNDNqEEEDkvKghZSaoti684dQFVrGQ==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/config-resolver": "^4.0.1",
				"@smithy/credential-provider-imds": "^4.0.1",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/util-endpoints": {
			"version": "3.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/util-endpoints/-/util-endpoints-3.0.1.tgz",
			"integrity": "sha512-zVdUENQpdtn9jbpD9SCFK4+aSiavRb9BxEtw9ZGUR1TYo6bBHbIoi7VkrFQ0/RwZlzx0wRBaRmPclj8iAoJCLA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/util-hex-encoding": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-hex-encoding/-/util-hex-encoding-4.0.0.tgz",
			"integrity": "sha512-Yk5mLhHtfIgW2W2WQZWSg5kuMZCVbvhFmC7rV4IO2QqnZdbEFPmQnCcGMAX2z/8Qj3B9hYYNjZOhWym+RwhePw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/util-middleware": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/util-middleware/-/util-middleware-4.0.1.tgz",
			"integrity": "sha512-HiLAvlcqhbzhuiOa0Lyct5IIlyIz0PQO5dnMlmQ/ubYM46dPInB+3yQGkfxsk6Q24Y0n3/JmcA1v5iEhmOF5mA==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/util-retry": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/util-retry/-/util-retry-4.0.1.tgz",
			"integrity": "sha512-WmRHqNVwn3kI3rKk1LsKcVgPBG6iLTBGC1iYOV3GQegwJ3E8yjzHytPt26VNzOWr1qu0xE03nK0Ug8S7T7oufw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/service-error-classification": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/util-stream": {
			"version": "4.1.2",
			"resolved": "https://registry.npmjs.org/@smithy/util-stream/-/util-stream-4.1.2.tgz",
			"integrity": "sha512-44PKEqQ303d3rlQuiDpcCcu//hV8sn+u2JBo84dWCE0rvgeiVl0IlLMagbU++o0jCWhYCsHaAt9wZuZqNe05Hw==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/fetch-http-handler": "^5.0.1",
				"@smithy/node-http-handler": "^4.0.3",
				"@smithy/types": "^4.1.0",
				"@smithy/util-base64": "^4.0.0",
				"@smithy/util-buffer-from": "^4.0.0",
				"@smithy/util-hex-encoding": "^4.0.0",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/util-uri-escape": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-uri-escape/-/util-uri-escape-4.0.0.tgz",
			"integrity": "sha512-77yfbCbQMtgtTylO9itEAdpPXSog3ZxMe09AEhm0dU0NLTalV70ghDZFR+Nfi1C60jnJoh/Re4090/DuZh2Omg==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@smithy/util-utf8": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-utf8/-/util-utf8-4.0.0.tgz",
			"integrity": "sha512-b+zebfKCfRdgNJDknHCob3O7FpeYQN6ZG6YLExMcasDHsCXlsXCEuiPZeLnJLpwa5dvPetGlnGCiMHuLwGvFow==",
			"license": "Apache-2.0",
			"optional": true,
			"dependencies": {
				"@smithy/util-buffer-from": "^4.0.0",
				"tslib": "^2.6.2"
			},
			"engines": {
				"node": ">=18.0.0"
			}
		},
		"node_modules/@socket.io/component-emitter": {
			"version": "3.1.2",
			"resolved": "https://registry.npmjs.org/@socket.io/component-emitter/-/component-emitter-3.1.2.tgz",
			"integrity": "sha512-9BCxFwvbGg/RsZK9tjXd8s4UcwR0MWeFQ1XEKIQVVvAGJyINdrqKMcTRyLoK8Rse1GjzLV9cwjWV1olXRWEXVA==",
			"license": "MIT"
		},
		"node_modules/@types/bcrypt": {
			"version": "5.0.0",
			"resolved": "https://registry.npmjs.org/@types/bcrypt/-/bcrypt-5.0.0.tgz",
			"integrity": "sha512-agtcFKaruL8TmcvqbndlqHPSJgsolhf/qPWchFlgnW1gECTN/nKbFcoFnvKAQRFfKbh+BO6A3SWdJu9t+xF3Lw==",
			"dev": true,
			"dependencies": {
				"@types/node": "*"
			}
		},
		"node_modules/@types/body-parser": {
			"version": "1.19.2",
			"resolved": "https://registry.npmjs.org/@types/body-parser/-/body-parser-1.19.2.tgz",
			"integrity": "sha512-ALYone6pm6QmwZoAgeyNksccT9Q4AWZQ6PvfwR37GT6r6FWUPguq6sUmNGSMV2Wr761oQoBxwGGa6DR5o1DC9g==",
			"dev": true,
			"dependencies": {
				"@types/connect": "*",
				"@types/node": "*"
			}
		},
		"node_modules/@types/connect": {
			"version": "3.4.35",
			"resolved": "https://registry.npmjs.org/@types/connect/-/connect-3.4.35.tgz",
			"integrity": "sha512-cdeYyv4KWoEgpBISTxWvqYsVy444DOqehiF3fM3ne10AmJ62RSyNkUnxMJXHQWRQQX2eR94m5y1IZyDwBjV9FQ==",
			"dev": true,
			"dependencies": {
				"@types/node": "*"
			}
		},
		"node_modules/@types/cors": {
			"version": "2.8.17",
			"resolved": "https://registry.npmjs.org/@types/cors/-/cors-2.8.17.tgz",
			"integrity": "sha512-8CGDvrBj1zgo2qE+oS3pOCyYNqCPryMWY2bGfwA0dcfopWGgxs+78df0Rs3rc9THP4JkOhLsAa+15VdpAqkcUA==",
			"license": "MIT",
			"dependencies": {
				"@types/node": "*"
			}
		},
		"node_modules/@types/express": {
			"version": "4.17.13",
			"resolved": "https://registry.npmjs.org/@types/express/-/express-4.17.13.tgz",
			"integrity": "sha512-6bSZTPaTIACxn48l50SR+axgrqm6qXFIxrdAKaG6PaJk3+zuUr35hBlgT7vOmJcum+OEaIBLtHV/qloEAFITeA==",
			"dev": true,
			"dependencies": {
				"@types/body-parser": "*",
				"@types/express-serve-static-core": "^4.17.18",
				"@types/qs": "*",
				"@types/serve-static": "*"
			}
		},
		"node_modules/@types/express-serve-static-core": {
			"version": "4.17.28",
			"resolved": "https://registry.npmjs.org/@types/express-serve-static-core/-/express-serve-static-core-4.17.28.tgz",
			"integrity": "sha512-P1BJAEAW3E2DJUlkgq4tOL3RyMunoWXqbSCygWo5ZIWTjUgN1YnaXWW4VWl/oc8vs/XoYibEGBKP0uZyF4AHig==",
			"dev": true,
			"dependencies": {
				"@types/node": "*",
				"@types/qs": "*",
				"@types/range-parser": "*"
			}
		},
		"node_modules/@types/jsonwebtoken": {
			"version": "8.5.8",
			"resolved": "https://registry.npmjs.org/@types/jsonwebtoken/-/jsonwebtoken-8.5.8.tgz",
			"integrity": "sha512-zm6xBQpFDIDM6o9r6HSgDeIcLy82TKWctCXEPbJJcXb5AKmi5BNNdLXneixK4lplX3PqIVcwLBCGE/kAGnlD4A==",
			"dev": true,
			"dependencies": {
				"@types/node": "*"
			}
		},
		"node_modules/@types/mime": {
			"version": "1.3.2",
			"resolved": "https://registry.npmjs.org/@types/mime/-/mime-1.3.2.tgz",
			"integrity": "sha512-YATxVxgRqNH6nHEIsvg6k2Boc1JHI9ZbH5iWFFv/MTkchz3b1ieGDa5T0a9RznNdI0KhVbdbWSN+KWWrQZRxTw==",
			"dev": true
		},
		"node_modules/@types/node": {
			"version": "17.0.38",
			"resolved": "https://registry.npmjs.org/@types/node/-/node-17.0.38.tgz",
			"integrity": "sha512-5jY9RhV7c0Z4Jy09G+NIDTsCZ5G0L5n+Z+p+Y7t5VJHM30bgwzSjVtlcBxqAj+6L/swIlvtOSzr8rBk/aNyV2g=="
		},
		"node_modules/@types/nodemon": {
			"version": "1.19.1",
			"resolved": "https://registry.npmjs.org/@types/nodemon/-/nodemon-1.19.1.tgz",
			"integrity": "sha512-3teAFqCFba3W9zk4dAGUZ+rW/nrQBrSGXWyK9HfJuWxmITk2z2d3u/5cy7oFqNG2fZxPwSAWkP+a8q/QC6UU5Q==",
			"dev": true,
			"dependencies": {
				"@types/node": "*"
			}
		},
		"node_modules/@types/qs": {
			"version": "6.9.7",
			"resolved": "https://registry.npmjs.org/@types/qs/-/qs-6.9.7.tgz",
			"integrity": "sha512-FGa1F62FT09qcrueBA6qYTrJPVDzah9a+493+o2PCXsesWHIn27G98TsSMs3WPNbZIEj4+VJf6saSFpvD+3Zsw==",
			"dev": true
		},
		"node_modules/@types/range-parser": {
			"version": "1.2.4",
			"resolved": "https://registry.npmjs.org/@types/range-parser/-/range-parser-1.2.4.tgz",
			"integrity": "sha512-EEhsLsD6UsDM1yFhAvy0Cjr6VwmpMWqFBCb9w07wVugF7w9nfajxLuVmngTIpgS6svCnm6Vaw+MZhoDCKnOfsw==",
			"dev": true
		},
		"node_modules/@types/serve-static": {
			"version": "1.13.10",
			"resolved": "https://registry.npmjs.org/@types/serve-static/-/serve-static-1.13.10.tgz",
			"integrity": "sha512-nCkHGI4w7ZgAdNkrEu0bv+4xNV/XDqW+DydknebMOQwkpDGx8G+HTlj7R7ABI8i8nKxVw0wtKPi1D+lPOkh4YQ==",
			"dev": true,
			"dependencies": {
				"@types/mime": "^1",
				"@types/node": "*"
			}
		},
		"node_modules/@types/uuid": {
			"version": "8.3.4",
			"resolved": "https://registry.npmjs.org/@types/uuid/-/uuid-8.3.4.tgz",
			"integrity": "sha512-c/I8ZRb51j+pYGAu5CrFMRxqZ2ke4y2grEBO5AUjgSkSk+qT2Ea+OdWElz/OiMf5MNpn2b17kuVBwZLQJXzihw==",
			"dev": true
		},
		"node_modules/@types/webidl-conversions": {
			"version": "7.0.3",
			"resolved": "https://registry.npmjs.org/@types/webidl-conversions/-/webidl-conversions-7.0.3.tgz",
			"integrity": "sha512-CiJJvcRtIgzadHCYXw7dqEnMNRjhGZlYK05Mj9OyktqV8uVT8fD2BFOB7S1uwBE3Kj2Z+4UyPmFw/Ixgw/LAlA==",
			"license": "MIT"
		},
		"node_modules/@types/whatwg-url": {
			"version": "8.2.2",
			"resolved": "https://registry.npmjs.org/@types/whatwg-url/-/whatwg-url-8.2.2.tgz",
			"integrity": "sha512-FtQu10RWgn3D9U4aazdwIE2yzphmTJREDqNdODHrbrZmmMqI0vMheC/6NE/J1Yveaj8H+ela+YwWTjq5PGmuhA==",
			"license": "MIT",
			"dependencies": {
				"@types/node": "*",
				"@types/webidl-conversions": "*"
			}
		},
		"node_modules/abbrev": {
			"version": "1.1.1",
			"resolved": "https://registry.npmjs.org/abbrev/-/abbrev-1.1.1.tgz",
			"integrity": "sha512-nne9/IiQ/hzIhY6pdDnbBtz7DjPTKrY00P/zvPSm5pOFkl6xuGrGnXn/VtTNNfNtAfZ9/1RtehkszU9qcTii0Q=="
		},
		"node_modules/accepts": {
			"version": "1.3.8",
			"resolved": "https://registry.npmjs.org/accepts/-/accepts-1.3.8.tgz",
			"integrity": "sha512-PYAthTa2m2VKxuvSD3DPC/Gy+U+sOA1LAuT8mkmRuvw+NACSaeXEQ+NHcVF7rONl6qcaxV3Uuemwawk+7+SJLw==",
			"dependencies": {
				"mime-types": "~2.1.34",
				"negotiator": "0.6.3"
			},
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/agent-base": {
			"version": "6.0.2",
			"resolved": "https://registry.npmjs.org/agent-base/-/agent-base-6.0.2.tgz",
			"integrity": "sha512-RZNwNclF7+MS/8bDg70amg32dyeZGZxiDuQmZxKLAlQjr3jGyLx+4Kkk58UO7D2QdgFIQCovuSuZESne6RG6XQ==",
			"dependencies": {
				"debug": "4"
			},
			"engines": {
				"node": ">= 6.0.0"
			}
		},
		"node_modules/agent-base/node_modules/debug": {
			"version": "4.3.4",
			"resolved": "https://registry.npmjs.org/debug/-/debug-4.3.4.tgz",
			"integrity": "sha512-PRWFHuSU3eDtQJPvnNY7Jcket1j0t5OuOsFzPPzsekD52Zl8qUfFIPEiswXqIvHWGVHOgX+7G/vCNNhehwxfkQ==",
			"dependencies": {
				"ms": "2.1.2"
			},
			"engines": {
				"node": ">=6.0"
			},
			"peerDependenciesMeta": {
				"supports-color": {
					"optional": true
				}
			}
		},
		"node_modules/agent-base/node_modules/ms": {
			"version": "2.1.2",
			"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.2.tgz",
			"integrity": "sha512-sGkPx+VjMtmA6MX27oA4FBFELFCZZ4S4XqeGOXCv68tT+jb3vk/RyaKWP0PTKyWtmLSM0b+adUTEvbs1PEaH2w=="
		},
		"node_modules/ansi-regex": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/ansi-regex/-/ansi-regex-5.0.1.tgz",
			"integrity": "sha512-quJQXlTSUGL2LH9SUXo8VwsY4soanhgo6LNSm84E1LBcE8s3O0wpdiRzyR9z/ZZJMlMWv37qOOb9pdJlMUEKFQ==",
			"engines": {
				"node": ">=8"
			}
		},
		"node_modules/anymatch": {
			"version": "3.1.2",
			"resolved": "https://registry.npmjs.org/anymatch/-/anymatch-3.1.2.tgz",
			"integrity": "sha512-P43ePfOAIupkguHUycrc4qJ9kz8ZiuOUijaETwX7THt0Y/GNK7v0aa8rY816xWjZ7rJdA5XdMcpVFTKMq+RvWg==",
			"dev": true,
			"dependencies": {
				"normalize-path": "^3.0.0",
				"picomatch": "^2.0.4"
			},
			"engines": {
				"node": ">= 8"
			}
		},
		"node_modules/aproba": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/aproba/-/aproba-2.0.0.tgz",
			"integrity": "sha512-lYe4Gx7QT+MKGbDsA+Z+he/Wtef0BiwDOlK/XkBrdfsh9J/jPPXbX0tE9x9cl27Tmu5gg3QUbUrQYa/y+KOHPQ=="
		},
		"node_modules/are-we-there-yet": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/are-we-there-yet/-/are-we-there-yet-2.0.0.tgz",
			"integrity": "sha512-Ci/qENmwHnsYo9xKIcUJN5LeDKdJ6R1Z1j9V/J5wyq8nh/mYPEpIKJbBZXtZjG04HiK7zV/p6Vs9952MrMeUIw==",
			"dependencies": {
				"delegates": "^1.0.0",
				"readable-stream": "^3.6.0"
			},
			"engines": {
				"node": ">=10"
			}
		},
		"node_modules/array-flatten": {
			"version": "1.1.1",
			"resolved": "https://registry.npmjs.org/array-flatten/-/array-flatten-1.1.1.tgz",
			"integrity": "sha512-PCVAQswWemu6UdxsDFFX/+gVeYqKAod3D3UVm91jHwynguOwAvYPhx8nNlM++NqRcK6CxxpUafjmhIdKiHibqg=="
		},
		"node_modules/balanced-match": {
			"version": "1.0.2",
			"resolved": "https://registry.npmjs.org/balanced-match/-/balanced-match-1.0.2.tgz",
			"integrity": "sha512-3oSeUO0TMV67hN1AmbXsK4yaqU7tjiHlbxRDZOpH0KW9+CeX4bRAaX0Anxt0tx2MrpRpWwQaPwIlISEJhYU5Pw=="
		},
		"node_modules/base64-js": {
			"version": "1.5.1",
			"resolved": "https://registry.npmjs.org/base64-js/-/base64-js-1.5.1.tgz",
			"integrity": "sha512-AKpaYlHn8t4SVbOHCy+b5+KKgvR4vrsD8vbvrbiQJps7fKDTkjkDry6ji0rUJjC0kzbNePLwzxq8iypo41qeWA==",
			"funding": [
				{
					"type": "github",
					"url": "https://github.com/sponsors/feross"
				},
				{
					"type": "patreon",
					"url": "https://www.patreon.com/feross"
				},
				{
					"type": "consulting",
					"url": "https://feross.org/support"
				}
			],
			"license": "MIT"
		},
		"node_modules/base64id": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/base64id/-/base64id-2.0.0.tgz",
			"integrity": "sha512-lGe34o6EHj9y3Kts9R4ZYs/Gr+6N7MCaMlIFA3F1R2O5/m7K06AxfSeO5530PEERE6/WyEg3lsuyw4GHlPZHog==",
			"license": "MIT",
			"engines": {
				"node": "^4.5.0 || >= 5.9"
			}
		},
		"node_modules/bcrypt": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/bcrypt/-/bcrypt-5.0.1.tgz",
			"integrity": "sha512-9BTgmrhZM2t1bNuDtrtIMVSmmxZBrJ71n8Wg+YgdjHuIWYF7SjjmCPZFB+/5i/o/PIeRpwVJR3P+NrpIItUjqw==",
			"hasInstallScript": true,
			"dependencies": {
				"@mapbox/node-pre-gyp": "^1.0.0",
				"node-addon-api": "^3.1.0"
			},
			"engines": {
				"node": ">= 10.0.0"
			}
		},
		"node_modules/binary-extensions": {
			"version": "2.2.0",
			"resolved": "https://registry.npmjs.org/binary-extensions/-/binary-extensions-2.2.0.tgz",
			"integrity": "sha512-jDctJ/IVQbZoJykoeHbhXpOlNBqGNcwXJKJog42E5HDPUwQTSdjCHdihjj0DlnheQ7blbT6dHOafNAiS8ooQKA==",
			"dev": true,
			"engines": {
				"node": ">=8"
			}
		},
		"node_modules/body-parser": {
			"version": "1.20.3",
			"resolved": "https://registry.npmjs.org/body-parser/-/body-parser-1.20.3.tgz",
			"integrity": "sha512-7rAxByjUMqQ3/bHJy7D6OGXvx/MMc4IqBn/X0fcM1QUcAItpZrBEYhWGem+tzXH90c+G01ypMcYJBO9Y30203g==",
			"license": "MIT",
			"dependencies": {
				"bytes": "3.1.2",
				"content-type": "~1.0.5",
				"debug": "2.6.9",
				"depd": "2.0.0",
				"destroy": "1.2.0",
				"http-errors": "2.0.0",
				"iconv-lite": "0.4.24",
				"on-finished": "2.4.1",
				"qs": "6.13.0",
				"raw-body": "2.5.2",
				"type-is": "~1.6.18",
				"unpipe": "1.0.0"
			},
			"engines": {
				"node": ">= 0.8",
				"npm": "1.2.8000 || >= 1.4.16"
			}
		},
		"node_modules/bowser": {
			"version": "2.11.0",
			"resolved": "https://registry.npmjs.org/bowser/-/bowser-2.11.0.tgz",
			"integrity": "sha512-AlcaJBi/pqqJBIQ8U9Mcpc9i8Aqxn88Skv5d+xBX006BY5u8N3mGLHa5Lgppa7L/HfwgwLgZ6NYs+Ag6uUmJRA==",
			"license": "MIT",
			"optional": true
		},
		"node_modules/brace-expansion": {
			"version": "1.1.11",
			"resolved": "https://registry.npmjs.org/brace-expansion/-/brace-expansion-1.1.11.tgz",
			"integrity": "sha512-iCuPHDFgrHX7H2vEI/5xpz07zSHB00TpugqhmYtVmMO6518mCuRMoOYFldEBl0g187ufozdaHgWKcYFb61qGiA==",
			"dependencies": {
				"balanced-match": "^1.0.0",
				"concat-map": "0.0.1"
			}
		},
		"node_modules/braces": {
			"version": "3.0.3",
			"resolved": "https://registry.npmjs.org/braces/-/braces-3.0.3.tgz",
			"integrity": "sha512-yQbXgO/OSZVD2IsiLlro+7Hf6Q18EJrKSEsdoMzKePKXct3gvD8oLcOQdIzGupr5Fj+EDe8gO/lxc1BzfMpxvA==",
			"dev": true,
			"license": "MIT",
			"dependencies": {
				"fill-range": "^7.1.1"
			},
			"engines": {
				"node": ">=8"
			}
		},
		"node_modules/bson": {
			"version": "4.7.2",
			"resolved": "https://registry.npmjs.org/bson/-/bson-4.7.2.tgz",
			"integrity": "sha512-Ry9wCtIZ5kGqkJoi6aD8KjxFZEx78guTQDnpXWiNthsxzrxAK/i8E6pCHAIZTbaEFWcOCvbecMukfK7XUvyLpQ==",
			"license": "Apache-2.0",
			"dependencies": {
				"buffer": "^5.6.0"
			},
			"engines": {
				"node": ">=6.9.0"
			}
		},
		"node_modules/buffer": {
			"version": "5.7.1",
			"resolved": "https://registry.npmjs.org/buffer/-/buffer-5.7.1.tgz",
			"integrity": "sha512-EHcyIPBQ4BSGlvjB16k5KgAJ27CIsHY/2JBmCRReo48y9rQ3MaUzWX3KVlBa4U7MyX02HdVj0K7C3WaB3ju7FQ==",
			"funding": [
				{
					"type": "github",
					"url": "https://github.com/sponsors/feross"
				},
				{
					"type": "patreon",
					"url": "https://www.patreon.com/feross"
				},
				{
					"type": "consulting",
					"url": "https://feross.org/support"
				}
			],
			"license": "MIT",
			"dependencies": {
				"base64-js": "^1.3.1",
				"ieee754": "^1.1.13"
			}
		},
		"node_modules/buffer-equal-constant-time": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/buffer-equal-constant-time/-/buffer-equal-constant-time-1.0.1.tgz",
			"integrity": "sha512-zRpUiDwd/xk6ADqPMATG8vc9VPrkck7T07OIx0gnjmJAnHnTVXNQG3vfvWNuiZIkwu9KrKdA1iJKfsfTVxE6NA=="
		},
		"node_modules/bytes": {
			"version": "3.1.2",
			"resolved": "https://registry.npmjs.org/bytes/-/bytes-3.1.2.tgz",
			"integrity": "sha512-/Nf7TyzTx6S3yRJObOAV7956r8cr2+Oj8AC5dt8wSP3BQAoeX58NoHyCU8P8zGkNXStjTSi6fzO6F0pBdcYbEg==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.8"
			}
		},
		"node_modules/call-bind-apply-helpers": {
			"version": "1.0.2",
			"resolved": "https://registry.npmjs.org/call-bind-apply-helpers/-/call-bind-apply-helpers-1.0.2.tgz",
			"integrity": "sha512-Sp1ablJ0ivDkSzjcaJdxEunN5/XvksFJ2sMBFfq6x0ryhQV/2b/KwFe21cMpmHtPOSij8K99/wSfoEuTObmuMQ==",
			"license": "MIT",
			"dependencies": {
				"es-errors": "^1.3.0",
				"function-bind": "^1.1.2"
			},
			"engines": {
				"node": ">= 0.4"
			}
		},
		"node_modules/call-bound": {
			"version": "1.0.4",
			"resolved": "https://registry.npmjs.org/call-bound/-/call-bound-1.0.4.tgz",
			"integrity": "sha512-+ys997U96po4Kx/ABpBCqhA9EuxJaQWDQg7295H4hBphv3IZg0boBKuwYpt4YXp6MZ5AmZQnU/tyMTlRpaSejg==",
			"license": "MIT",
			"dependencies": {
				"call-bind-apply-helpers": "^1.0.2",
				"get-intrinsic": "^1.3.0"
			},
			"engines": {
				"node": ">= 0.4"
			},
			"funding": {
				"url": "https://github.com/sponsors/ljharb"
			}
		},
		"node_modules/chokidar": {
			"version": "3.5.3",
			"resolved": "https://registry.npmjs.org/chokidar/-/chokidar-3.5.3.tgz",
			"integrity": "sha512-Dr3sfKRP6oTcjf2JmUmFJfeVMvXBdegxB0iVQ5eb2V10uFJUCAS8OByZdVAyVb8xXNz3GjjTgj9kLWsZTqE6kw==",
			"dev": true,
			"funding": [
				{
					"type": "individual",
					"url": "https://paulmillr.com/funding/"
				}
			],
			"dependencies": {
				"anymatch": "~3.1.2",
				"braces": "~3.0.2",
				"glob-parent": "~5.1.2",
				"is-binary-path": "~2.1.0",
				"is-glob": "~4.0.1",
				"normalize-path": "~3.0.0",
				"readdirp": "~3.6.0"
			},
			"engines": {
				"node": ">= 8.10.0"
			},
			"optionalDependencies": {
				"fsevents": "~2.3.2"
			}
		},
		"node_modules/chownr": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/chownr/-/chownr-2.0.0.tgz",
			"integrity": "sha512-bIomtDF5KGpdogkLd9VspvFzk9KfpyyGlS8YFVZl7TGPBHL5snIOnxeshwVgPteQ9b4Eydl+pVbIyE1DcvCWgQ==",
			"engines": {
				"node": ">=10"
			}
		},
		"node_modules/color-support": {
			"version": "1.1.3",
			"resolved": "https://registry.npmjs.org/color-support/-/color-support-1.1.3.tgz",
			"integrity": "sha512-qiBjkpbMLO/HL68y+lh4q0/O1MZFj2RX6X/KmMa3+gJD3z+WwI1ZzDHysvqHGS3mP6mznPckpXmw1nI9cJjyRg==",
			"bin": {
				"color-support": "bin.js"
			}
		},
		"node_modules/concat-map": {
			"version": "0.0.1",
			"resolved": "https://registry.npmjs.org/concat-map/-/concat-map-0.0.1.tgz",
			"integrity": "sha512-/Srv4dswyQNBfohGpz9o6Yb3Gz3SrUDqBH5rTuhGR7ahtlbYKnVxw2bCFMRljaA7EXHaXZ8wsHdodFvbkhKmqg=="
		},
		"node_modules/console-control-strings": {
			"version": "1.1.0",
			"resolved": "https://registry.npmjs.org/console-control-strings/-/console-control-strings-1.1.0.tgz",
			"integrity": "sha512-ty/fTekppD2fIwRvnZAVdeOiGd1c7YXEixbgJTNzqcxJWKQnjJ/V1bNEEE6hygpM3WjwHFUVK6HTjWSzV4a8sQ=="
		},
		"node_modules/content-disposition": {
			"version": "0.5.4",
			"resolved": "https://registry.npmjs.org/content-disposition/-/content-disposition-0.5.4.tgz",
			"integrity": "sha512-FveZTNuGw04cxlAiWbzi6zTAL/lhehaWbTtgluJh4/E95DqMwTmha3KZN1aAWA8cFIhHzMZUvLevkw5Rqk+tSQ==",
			"dependencies": {
				"safe-buffer": "5.2.1"
			},
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/content-type": {
			"version": "1.0.5",
			"resolved": "https://registry.npmjs.org/content-type/-/content-type-1.0.5.tgz",
			"integrity": "sha512-nTjqfcBFEipKdXCv4YDQWCfmcLZKm81ldF0pAopTvyrFGVbcR6P/VAAd5G7N+0tTr8QqiU0tFadD6FK4NtJwOA==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/cookie": {
			"version": "0.7.1",
			"resolved": "https://registry.npmjs.org/cookie/-/cookie-0.7.1.tgz",
			"integrity": "sha512-6DnInpx7SJ2AK3+CTUE/ZM0vWTUboZCegxhC2xiIydHR9jNuTAASBrfEpHhiGOZw/nX51bHt6YQl8jsGo4y/0w==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/cookie-signature": {
			"version": "1.0.6",
			"resolved": "https://registry.npmjs.org/cookie-signature/-/cookie-signature-1.0.6.tgz",
			"integrity": "sha512-QADzlaHc8icV8I7vbaJXJwod9HWYp8uCqf1xa4OfNu1T7JVxQIrUgOWtHdNDtPiywmFbiS12VjotIXLrKM3orQ=="
		},
		"node_modules/cors": {
			"version": "2.8.5",
			"resolved": "https://registry.npmjs.org/cors/-/cors-2.8.5.tgz",
			"integrity": "sha512-KIHbLJqu73RGr/hnbrO9uBeixNGuvSQjul/jdFvS/KFSIH1hWVd1ng7zOHx+YrEfInLG7q4n6GHQ9cDtxv/P6g==",
			"license": "MIT",
			"dependencies": {
				"object-assign": "^4",
				"vary": "^1"
			},
			"engines": {
				"node": ">= 0.10"
			}
		},
		"node_modules/debug": {
			"version": "2.6.9",
			"resolved": "https://registry.npmjs.org/debug/-/debug-2.6.9.tgz",
			"integrity": "sha512-bC7ElrdJaJnPbAP+1EotYvqZsb3ecl5wi6Bfi6BJTUcNowp6cvspg0jXznRTKDjm/E7AdgFBVeAPVMNcKGsHMA==",
			"license": "MIT",
			"dependencies": {
				"ms": "2.0.0"
			}
		},
		"node_modules/delegates": {
			"version": "1.0.0",
			"resolved": "https://registry.npmjs.org/delegates/-/delegates-1.0.0.tgz",
			"integrity": "sha512-bd2L678uiWATM6m5Z1VzNCErI3jiGzt6HGY8OVICs40JQq/HALfbyNJmp0UDakEY4pMMaN0Ly5om/B1VI/+xfQ=="
		},
		"node_modules/depd": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/depd/-/depd-2.0.0.tgz",
			"integrity": "sha512-g7nH6P6dyDioJogAAGprGpCtVImJhpPk/roCzdb3fIh61/s/nPsfR6onyMwkCAR/OlC3yBC0lESvUoQEAssIrw==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.8"
			}
		},
		"node_modules/destroy": {
			"version": "1.2.0",
			"resolved": "https://registry.npmjs.org/destroy/-/destroy-1.2.0.tgz",
			"integrity": "sha512-2sJGJTaXIIaR1w4iJSNoN0hnMY7Gpc/n8D4qSCJw8QqFWXf7cuAgnEHxBpweaVcPevC2l3KpjYCx3NypQQgaJg==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.8",
				"npm": "1.2.8000 || >= 1.4.16"
			}
		},
		"node_modules/detect-libc": {
			"version": "2.0.1",
			"resolved": "https://registry.npmjs.org/detect-libc/-/detect-libc-2.0.1.tgz",
			"integrity": "sha512-463v3ZeIrcWtdgIg6vI6XUncguvr2TnGl4SzDXinkt9mSLpBJKXT3mW6xT3VQdDN11+WVs29pgvivTc4Lp8v+w==",
			"engines": {
				"node": ">=8"
			}
		},
		"node_modules/dotenv": {
			"version": "16.0.1",
			"resolved": "https://registry.npmjs.org/dotenv/-/dotenv-16.0.1.tgz",
			"integrity": "sha512-1K6hR6wtk2FviQ4kEiSjFiH5rpzEVi8WW0x96aztHVMhEspNpc4DVOUTEHtEva5VThQ8IaBX1Pe4gSzpVVUsKQ==",
			"engines": {
				"node": ">=12"
			}
		},
		"node_modules/dunder-proto": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/dunder-proto/-/dunder-proto-1.0.1.tgz",
			"integrity": "sha512-KIN/nDJBQRcXw0MLVhZE9iQHmG68qAVIBg9CqmUYjmQIhgij9U5MFvrqkUL5FbtyyzZuOeOt0zdeRe4UY7ct+A==",
			"license": "MIT",
			"dependencies": {
				"call-bind-apply-helpers": "^1.0.1",
				"es-errors": "^1.3.0",
				"gopd": "^1.2.0"
			},
			"engines": {
				"node": ">= 0.4"
			}
		},
		"node_modules/ecdsa-sig-formatter": {
			"version": "1.0.11",
			"resolved": "https://registry.npmjs.org/ecdsa-sig-formatter/-/ecdsa-sig-formatter-1.0.11.tgz",
			"integrity": "sha512-nagl3RYrbNv6kQkeJIpt6NJZy8twLB/2vtz6yN9Z4vRKHN4/QZJIEbqohALSgwKdnksuY3k5Addp5lg8sVoVcQ==",
			"dependencies": {
				"safe-buffer": "^5.0.1"
			}
		},
		"node_modules/ee-first": {
			"version": "1.1.1",
			"resolved": "https://registry.npmjs.org/ee-first/-/ee-first-1.1.1.tgz",
			"integrity": "sha512-WMwm9LhRUo+WUaRN+vRuETqG89IgZphVSNkdFgeb6sS/E4OrDIN7t48CAewSHXc6C8lefD8KKfr5vY61brQlow==",
			"license": "MIT"
		},
		"node_modules/emoji-regex": {
			"version": "8.0.0",
			"resolved": "https://registry.npmjs.org/emoji-regex/-/emoji-regex-8.0.0.tgz",
			"integrity": "sha512-MSjYzcWNOA0ewAHpz0MxpYFvwg6yjy1NG3xteoqz644VCo/RPgnr1/GGt+ic3iJTzQ8Eu3TdM14SawnVUmGE6A=="
		},
		"node_modules/encodeurl": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/encodeurl/-/encodeurl-2.0.0.tgz",
			"integrity": "sha512-Q0n9HRi4m6JuGIV1eFlmvJB7ZEVxu93IrMyiMsGC0lrMJMWzRgx6WGquyfQgZVb31vhGgXnfmPNNXmxnOkRBrg==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.8"
			}
		},
		"node_modules/engine.io": {
			"version": "6.6.4",
			"resolved": "https://registry.npmjs.org/engine.io/-/engine.io-6.6.4.tgz",
			"integrity": "sha512-ZCkIjSYNDyGn0R6ewHDtXgns/Zre/NT6Agvq1/WobF7JXgFff4SeDroKiCO3fNJreU9YG429Sc81o4w5ok/W5g==",
			"license": "MIT",
			"dependencies": {
				"@types/cors": "^2.8.12",
				"@types/node": ">=10.0.0",
				"accepts": "~1.3.4",
				"base64id": "2.0.0",
				"cookie": "~0.7.2",
				"cors": "~2.8.5",
				"debug": "~4.3.1",
				"engine.io-parser": "~5.2.1",
				"ws": "~8.17.1"
			},
			"engines": {
				"node": ">=10.2.0"
			}
		},
		"node_modules/engine.io-parser": {
			"version": "5.2.3",
			"resolved": "https://registry.npmjs.org/engine.io-parser/-/engine.io-parser-5.2.3.tgz",
			"integrity": "sha512-HqD3yTBfnBxIrbnM1DoD6Pcq8NECnh8d4As1Qgh0z5Gg3jRRIqijury0CL3ghu/edArpUYiYqQiDUQBIs4np3Q==",
			"license": "MIT",
			"engines": {
				"node": ">=10.0.0"
			}
		},
		"node_modules/engine.io/node_modules/cookie": {
			"version": "0.7.2",
			"resolved": "https://registry.npmjs.org/cookie/-/cookie-0.7.2.tgz",
			"integrity": "sha512-yki5XnKuf750l50uGTllt6kKILY4nQ1eNIQatoXEByZ5dWgnKqbnqmTrBE5B4N7lrMJKQ2ytWMiTO2o0v6Ew/w==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/engine.io/node_modules/debug": {
			"version": "4.3.7",
			"resolved": "https://registry.npmjs.org/debug/-/debug-4.3.7.tgz",
			"integrity": "sha512-Er2nc/H7RrMXZBFCEim6TCmMk02Z8vLC2Rbi1KEBggpo0fS6l0S1nnapwmIi3yW/+GOJap1Krg4w0Hg80oCqgQ==",
			"license": "MIT",
			"dependencies": {
				"ms": "^2.1.3"
			},
			"engines": {
				"node": ">=6.0"
			},
			"peerDependenciesMeta": {
				"supports-color": {
					"optional": true
				}
			}
		},
		"node_modules/engine.io/node_modules/ms": {
			"version": "2.1.3",
			"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
			"integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA==",
			"license": "MIT"
		},
		"node_modules/es-define-property": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/es-define-property/-/es-define-property-1.0.1.tgz",
			"integrity": "sha512-e3nRfgfUZ4rNGL232gUgX06QNyyez04KdjFrF+LTRoOXmrOgFKDg4BCdsjW8EnT69eqdYGmRpJwiPVYNrCaW3g==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.4"
			}
		},
		"node_modules/es-errors": {
			"version": "1.3.0",
			"resolved": "https://registry.npmjs.org/es-errors/-/es-errors-1.3.0.tgz",
			"integrity": "sha512-Zf5H2Kxt2xjTvbJvP2ZWLEICxA6j+hAmMzIlypy4xcBg1vKVnx89Wy0GbS+kf5cwCVFFzdCFh2XSCFNULS6csw==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.4"
			}
		},
		"node_modules/es-object-atoms": {
			"version": "1.1.1",
			"resolved": "https://registry.npmjs.org/es-object-atoms/-/es-object-atoms-1.1.1.tgz",
			"integrity": "sha512-FGgH2h8zKNim9ljj7dankFPcICIK9Cp5bm+c2gQSYePhpaG5+esrLODihIorn+Pe6FGJzWhXQotPv73jTaldXA==",
			"license": "MIT",
			"dependencies": {
				"es-errors": "^1.3.0"
			},
			"engines": {
				"node": ">= 0.4"
			}
		},
		"node_modules/escape-html": {
			"version": "1.0.3",
			"resolved": "https://registry.npmjs.org/escape-html/-/escape-html-1.0.3.tgz",
			"integrity": "sha512-NiSupZ4OeuGwr68lGIeym/ksIZMJodUGOSCZ/FSnTxcrekbvqrgdUxlJOMpijaKZVjAJrWrGs/6Jy8OMuyj9ow==",
			"license": "MIT"
		},
		"node_modules/etag": {
			"version": "1.8.1",
			"resolved": "https://registry.npmjs.org/etag/-/etag-1.8.1.tgz",
			"integrity": "sha512-aIL5Fx7mawVa300al2BnEE4iNvo1qETxLrPI/o05L7z6go7fCw1J6EQmbK4FmJ2AS7kgVF/KEZWufBfdClMcPg==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/express": {
			"version": "4.21.2",
			"resolved": "https://registry.npmjs.org/express/-/express-4.21.2.tgz",
			"integrity": "sha512-28HqgMZAmih1Czt9ny7qr6ek2qddF4FclbMzwhCREB6OFfH+rXAnuNCwo1/wFvrtbgsQDb4kSbX9de9lFbrXnA==",
			"license": "MIT",
			"dependencies": {
				"accepts": "~1.3.8",
				"array-flatten": "1.1.1",
				"body-parser": "1.20.3",
				"content-disposition": "0.5.4",
				"content-type": "~1.0.4",
				"cookie": "0.7.1",
				"cookie-signature": "1.0.6",
				"debug": "2.6.9",
				"depd": "2.0.0",
				"encodeurl": "~2.0.0",
				"escape-html": "~1.0.3",
				"etag": "~1.8.1",
				"finalhandler": "1.3.1",
				"fresh": "0.5.2",
				"http-errors": "2.0.0",
				"merge-descriptors": "1.0.3",
				"methods": "~1.1.2",
				"on-finished": "2.4.1",
				"parseurl": "~1.3.3",
				"path-to-regexp": "0.1.12",
				"proxy-addr": "~2.0.7",
				"qs": "6.13.0",
				"range-parser": "~1.2.1",
				"safe-buffer": "5.2.1",
				"send": "0.19.0",
				"serve-static": "1.16.2",
				"setprototypeof": "1.2.0",
				"statuses": "2.0.1",
				"type-is": "~1.6.18",
				"utils-merge": "1.0.1",
				"vary": "~1.1.2"
			},
			"engines": {
				"node": ">= 0.10.0"
			},
			"funding": {
				"type": "opencollective",
				"url": "https://opencollective.com/express"
			}
		},
		"node_modules/fast-xml-parser": {
			"version": "4.4.1",
			"resolved": "https://registry.npmjs.org/fast-xml-parser/-/fast-xml-parser-4.4.1.tgz",
			"integrity": "sha512-xkjOecfnKGkSsOwtZ5Pz7Us/T6mrbPQrq0nh+aCO5V9nk5NLWmasAHumTKjiPJPWANe+kAZ84Jc8ooJkzZ88Sw==",
			"funding": [
				{
					"type": "github",
					"url": "https://github.com/sponsors/NaturalIntelligence"
				},
				{
					"type": "paypal",
					"url": "https://paypal.me/naturalintelligence"
				}
			],
			"license": "MIT",
			"optional": true,
			"dependencies": {
				"strnum": "^1.0.5"
			},
			"bin": {
				"fxparser": "src/cli/cli.js"
			}
		},
		"node_modules/fill-range": {
			"version": "7.1.1",
			"resolved": "https://registry.npmjs.org/fill-range/-/fill-range-7.1.1.tgz",
			"integrity": "sha512-YsGpe3WHLK8ZYi4tWDg2Jy3ebRz2rXowDxnld4bkQB00cc/1Zw9AWnC0i9ztDJitivtQvaI9KaLyKrc+hBW0yg==",
			"dev": true,
			"license": "MIT",
			"dependencies": {
				"to-regex-range": "^5.0.1"
			},
			"engines": {
				"node": ">=8"
			}
		},
		"node_modules/finalhandler": {
			"version": "1.3.1",
			"resolved": "https://registry.npmjs.org/finalhandler/-/finalhandler-1.3.1.tgz",
			"integrity": "sha512-6BN9trH7bp3qvnrRyzsBz+g3lZxTNZTbVO2EV1CS0WIcDbawYVdYvGflME/9QP0h0pYlCDBCTjYa9nZzMDpyxQ==",
			"license": "MIT",
			"dependencies": {
				"debug": "2.6.9",
				"encodeurl": "~2.0.0",
				"escape-html": "~1.0.3",
				"on-finished": "2.4.1",
				"parseurl": "~1.3.3",
				"statuses": "2.0.1",
				"unpipe": "~1.0.0"
			},
			"engines": {
				"node": ">= 0.8"
			}
		},
		"node_modules/forwarded": {
			"version": "0.2.0",
			"resolved": "https://registry.npmjs.org/forwarded/-/forwarded-0.2.0.tgz",
			"integrity": "sha512-buRG0fpBtRHSTCOASe6hD258tEubFoRLb4ZNA6NxMVHNw2gOcwHo9wyablzMzOA5z9xA9L1KNjk/Nt6MT9aYow==",
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/fresh": {
			"version": "0.5.2",
			"resolved": "https://registry.npmjs.org/fresh/-/fresh-0.5.2.tgz",
			"integrity": "sha512-zJ2mQYM18rEFOudeV4GShTGIQ7RbzA7ozbU9I/XBpm7kqgMywgmylMwXHxZJmkVoYkna9d2pVXVXPdYTP9ej8Q==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/fs-minipass": {
			"version": "2.1.0",
			"resolved": "https://registry.npmjs.org/fs-minipass/-/fs-minipass-2.1.0.tgz",
			"integrity": "sha512-V/JgOLFCS+R6Vcq0slCuaeWEdNC3ouDlJMNIsacH2VtALiu9mV4LPrHc5cDl8k5aw6J8jwgWWpiTo5RYhmIzvg==",
			"dependencies": {
				"minipass": "^3.0.0"
			},
			"engines": {
				"node": ">= 8"
			}
		},
		"node_modules/fs.realpath": {
			"version": "1.0.0",
			"resolved": "https://registry.npmjs.org/fs.realpath/-/fs.realpath-1.0.0.tgz",
			"integrity": "sha512-OO0pH2lK6a0hZnAdau5ItzHPI6pUlvI7jMVnxUQRtw4owF2wk8lOSabtGDCTP4Ggrg2MbGnWO9X8K1t4+fGMDw=="
		},
		"node_modules/fsevents": {
			"version": "2.3.2",
			"resolved": "https://registry.npmjs.org/fsevents/-/fsevents-2.3.2.tgz",
			"integrity": "sha512-xiqMQR4xAeHTuB9uWm+fFRcIOgKBMiOBP+eXiyT7jsgVCq1bkVygt00oASowB7EdtpOHaaPgKt812P9ab+DDKA==",
			"dev": true,
			"hasInstallScript": true,
			"optional": true,
			"os": [
				"darwin"
			],
			"engines": {
				"node": "^8.16.0 || ^10.6.0 || >=11.0.0"
			}
		},
		"node_modules/function-bind": {
			"version": "1.1.2",
			"resolved": "https://registry.npmjs.org/function-bind/-/function-bind-1.1.2.tgz",
			"integrity": "sha512-7XHNxH7qX9xG5mIwxkhumTox/MIRNcOgDrxWsMt2pAr23WHp6MrRlN7FBSFpCpr+oVO0F744iUgR82nJMfG2SA==",
			"license": "MIT",
			"funding": {
				"url": "https://github.com/sponsors/ljharb"
			}
		},
		"node_modules/gauge": {
			"version": "3.0.2",
			"resolved": "https://registry.npmjs.org/gauge/-/gauge-3.0.2.tgz",
			"integrity": "sha512-+5J6MS/5XksCuXq++uFRsnUd7Ovu1XenbeuIuNRJxYWjgQbPuFhT14lAvsWfqfAmnwluf1OwMjz39HjfLPci0Q==",
			"dependencies": {
				"aproba": "^1.0.3 || ^2.0.0",
				"color-support": "^1.1.2",
				"console-control-strings": "^1.0.0",
				"has-unicode": "^2.0.1",
				"object-assign": "^4.1.1",
				"signal-exit": "^3.0.0",
				"string-width": "^4.2.3",
				"strip-ansi": "^6.0.1",
				"wide-align": "^1.1.2"
			},
			"engines": {
				"node": ">=10"
			}
		},
		"node_modules/get-intrinsic": {
			"version": "1.3.0",
			"resolved": "https://registry.npmjs.org/get-intrinsic/-/get-intrinsic-1.3.0.tgz",
			"integrity": "sha512-9fSjSaos/fRIVIp+xSJlE6lfwhES7LNtKaCBIamHsjr2na1BiABJPo0mOjjz8GJDURarmCPGqaiVg5mfjb98CQ==",
			"license": "MIT",
			"dependencies": {
				"call-bind-apply-helpers": "^1.0.2",
				"es-define-property": "^1.0.1",
				"es-errors": "^1.3.0",
				"es-object-atoms": "^1.1.1",
				"function-bind": "^1.1.2",
				"get-proto": "^1.0.1",
				"gopd": "^1.2.0",
				"has-symbols": "^1.1.0",
				"hasown": "^2.0.2",
				"math-intrinsics": "^1.1.0"
			},
			"engines": {
				"node": ">= 0.4"
			},
			"funding": {
				"url": "https://github.com/sponsors/ljharb"
			}
		},
		"node_modules/get-proto": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/get-proto/-/get-proto-1.0.1.tgz",
			"integrity": "sha512-sTSfBjoXBp89JvIKIefqw7U2CCebsc74kiY6awiGogKtoSGbgjYE/G/+l9sF3MWFPNc9IcoOC4ODfKHfxFmp0g==",
			"license": "MIT",
			"dependencies": {
				"dunder-proto": "^1.0.1",
				"es-object-atoms": "^1.0.0"
			},
			"engines": {
				"node": ">= 0.4"
			}
		},
		"node_modules/glob": {
			"version": "7.2.3",
			"resolved": "https://registry.npmjs.org/glob/-/glob-7.2.3.tgz",
			"integrity": "sha512-nFR0zLpU2YCaRxwoCJvL6UvCH2JFyFVIvwTLsIf21AuHlMskA1hhTdk+LlYJtOlYt9v6dvszD2BGRqBL+iQK9Q==",
			"dependencies": {
				"fs.realpath": "^1.0.0",
				"inflight": "^1.0.4",
				"inherits": "2",
				"minimatch": "^3.1.1",
				"once": "^1.3.0",
				"path-is-absolute": "^1.0.0"
			},
			"engines": {
				"node": "*"
			},
			"funding": {
				"url": "https://github.com/sponsors/isaacs"
			}
		},
		"node_modules/glob-parent": {
			"version": "5.1.2",
			"resolved": "https://registry.npmjs.org/glob-parent/-/glob-parent-5.1.2.tgz",
			"integrity": "sha512-AOIgSQCepiJYwP3ARnGx+5VnTu2HBYdzbGP45eLw1vr3zB3vZLeyed1sC9hnbcOc9/SrMyM5RPQrkGz4aS9Zow==",
			"dev": true,
			"dependencies": {
				"is-glob": "^4.0.1"
			},
			"engines": {
				"node": ">= 6"
			}
		},
		"node_modules/gopd": {
			"version": "1.2.0",
			"resolved": "https://registry.npmjs.org/gopd/-/gopd-1.2.0.tgz",
			"integrity": "sha512-ZUKRh6/kUFoAiTAtTYPZJ3hw9wNxx+BIBOijnlG9PnrJsCcSjs1wyyD6vJpaYtgnzDrKYRSqf3OO6Rfa93xsRg==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.4"
			},
			"funding": {
				"url": "https://github.com/sponsors/ljharb"
			}
		},
		"node_modules/has-flag": {
			"version": "3.0.0",
			"resolved": "https://registry.npmjs.org/has-flag/-/has-flag-3.0.0.tgz",
			"integrity": "sha512-sKJf1+ceQBr4SMkvQnBDNDtf4TXpVhVGateu0t918bl30FnbE2m4vNLX+VWe/dpjlb+HugGYzW7uQXH98HPEYw==",
			"dev": true,
			"engines": {
				"node": ">=4"
			}
		},
		"node_modules/has-symbols": {
			"version": "1.1.0",
			"resolved": "https://registry.npmjs.org/has-symbols/-/has-symbols-1.1.0.tgz",
			"integrity": "sha512-1cDNdwJ2Jaohmb3sg4OmKaMBwuC48sYni5HUw2DvsC8LjGTLK9h+eb1X6RyuOHe4hT0ULCW68iomhjUoKUqlPQ==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.4"
			},
			"funding": {
				"url": "https://github.com/sponsors/ljharb"
			}
		},
		"node_modules/has-unicode": {
			"version": "2.0.1",
			"resolved": "https://registry.npmjs.org/has-unicode/-/has-unicode-2.0.1.tgz",
			"integrity": "sha512-8Rf9Y83NBReMnx0gFzA8JImQACstCYWUplepDa9xprwwtmgEZUF0h/i5xSA625zB/I37EtrswSST6OXxwaaIJQ=="
		},
		"node_modules/hasown": {
			"version": "2.0.2",
			"resolved": "https://registry.npmjs.org/hasown/-/hasown-2.0.2.tgz",
			"integrity": "sha512-0hJU9SCPvmMzIBdZFqNPXWa6dqh7WdH0cII9y+CyS8rG3nL48Bclra9HmKhVVUHyPWNH5Y7xDwAB7bfgSjkUMQ==",
			"license": "MIT",
			"dependencies": {
				"function-bind": "^1.1.2"
			},
			"engines": {
				"node": ">= 0.4"
			}
		},
		"node_modules/http-errors": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/http-errors/-/http-errors-2.0.0.tgz",
			"integrity": "sha512-FtwrG/euBzaEjYeRqOgly7G0qviiXoJWnvEH2Z1plBdXgbyjv34pHTSb9zoeHMyDy33+DWy5Wt9Wo+TURtOYSQ==",
			"license": "MIT",
			"dependencies": {
				"depd": "2.0.0",
				"inherits": "2.0.4",
				"setprototypeof": "1.2.0",
				"statuses": "2.0.1",
				"toidentifier": "1.0.1"
			},
			"engines": {
				"node": ">= 0.8"
			}
		},
		"node_modules/https-proxy-agent": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/https-proxy-agent/-/https-proxy-agent-5.0.1.tgz",
			"integrity": "sha512-dFcAjpTQFgoLMzC2VwU+C/CbS7uRL0lWmxDITmqm7C+7F0Odmj6s9l6alZc6AELXhrnggM2CeWSXHGOdX2YtwA==",
			"dependencies": {
				"agent-base": "6",
				"debug": "4"
			},
			"engines": {
				"node": ">= 6"
			}
		},
		"node_modules/https-proxy-agent/node_modules/debug": {
			"version": "4.3.4",
			"resolved": "https://registry.npmjs.org/debug/-/debug-4.3.4.tgz",
			"integrity": "sha512-PRWFHuSU3eDtQJPvnNY7Jcket1j0t5OuOsFzPPzsekD52Zl8qUfFIPEiswXqIvHWGVHOgX+7G/vCNNhehwxfkQ==",
			"dependencies": {
				"ms": "2.1.2"
			},
			"engines": {
				"node": ">=6.0"
			},
			"peerDependenciesMeta": {
				"supports-color": {
					"optional": true
				}
			}
		},
		"node_modules/https-proxy-agent/node_modules/ms": {
			"version": "2.1.2",
			"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.2.tgz",
			"integrity": "sha512-sGkPx+VjMtmA6MX27oA4FBFELFCZZ4S4XqeGOXCv68tT+jb3vk/RyaKWP0PTKyWtmLSM0b+adUTEvbs1PEaH2w=="
		},
		"node_modules/iconv-lite": {
			"version": "0.4.24",
			"resolved": "https://registry.npmjs.org/iconv-lite/-/iconv-lite-0.4.24.tgz",
			"integrity": "sha512-v3MXnZAcvnywkTUEZomIActle7RXXeedOR31wwl7VlyoXO4Qi9arvSenNQWne1TcRwhCL1HwLI21bEqdpj8/rA==",
			"license": "MIT",
			"dependencies": {
				"safer-buffer": ">= 2.1.2 < 3"
			},
			"engines": {
				"node": ">=0.10.0"
			}
		},
		"node_modules/ieee754": {
			"version": "1.2.1",
			"resolved": "https://registry.npmjs.org/ieee754/-/ieee754-1.2.1.tgz",
			"integrity": "sha512-dcyqhDvX1C46lXZcVqCpK+FtMRQVdIMN6/Df5js2zouUsqG7I6sFxitIC+7KYK29KdXOLHdu9zL4sFnoVQnqaA==",
			"funding": [
				{
					"type": "github",
					"url": "https://github.com/sponsors/feross"
				},
				{
					"type": "patreon",
					"url": "https://www.patreon.com/feross"
				},
				{
					"type": "consulting",
					"url": "https://feross.org/support"
				}
			],
			"license": "BSD-3-Clause"
		},
		"node_modules/ignore-by-default": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/ignore-by-default/-/ignore-by-default-1.0.1.tgz",
			"integrity": "sha512-Ius2VYcGNk7T90CppJqcIkS5ooHUZyIQK+ClZfMfMNFEF9VSE73Fq+906u/CWu92x4gzZMWOwfFYckPObzdEbA==",
			"dev": true
		},
		"node_modules/inflight": {
			"version": "1.0.6",
			"resolved": "https://registry.npmjs.org/inflight/-/inflight-1.0.6.tgz",
			"integrity": "sha512-k92I/b08q4wvFscXCLvqfsHCrjrF7yiXsQuIVvVE7N82W3+aqpzuUdBbfhWcy/FZR3/4IgflMgKLOsvPDrGCJA==",
			"dependencies": {
				"once": "^1.3.0",
				"wrappy": "1"
			}
		},
		"node_modules/inherits": {
			"version": "2.0.4",
			"resolved": "https://registry.npmjs.org/inherits/-/inherits-2.0.4.tgz",
			"integrity": "sha512-k/vGaX4/Yla3WzyMCvTQOXYeIHvqOKtnqBduzTHpzpQZzAskKMhZ2K+EnBiSM9zGSoIFeMpXKxa4dYeZIQqewQ=="
		},
		"node_modules/ip-address": {
			"version": "9.0.5",
			"resolved": "https://registry.npmjs.org/ip-address/-/ip-address-9.0.5.tgz",
			"integrity": "sha512-zHtQzGojZXTwZTHQqra+ETKd4Sn3vgi7uBmlPoXVWZqYvuKmtI0l/VZTjqGmJY9x88GGOaZ9+G9ES8hC4T4X8g==",
			"license": "MIT",
			"dependencies": {
				"jsbn": "1.1.0",
				"sprintf-js": "^1.1.3"
			},
			"engines": {
				"node": ">= 12"
			}
		},
		"node_modules/ipaddr.js": {
			"version": "1.9.1",
			"resolved": "https://registry.npmjs.org/ipaddr.js/-/ipaddr.js-1.9.1.tgz",
			"integrity": "sha512-0KI/607xoxSToH7GjN1FfSbLoU0+btTicjsQSWQlh/hZykN8KpmMf7uYwPW3R+akZ6R/w18ZlXSHBYXiYUPO3g==",
			"engines": {
				"node": ">= 0.10"
			}
		},
		"node_modules/is-binary-path": {
			"version": "2.1.0",
			"resolved": "https://registry.npmjs.org/is-binary-path/-/is-binary-path-2.1.0.tgz",
			"integrity": "sha512-ZMERYes6pDydyuGidse7OsHxtbI7WVeUEozgR/g7rd0xUimYNlvZRE/K2MgZTjWy725IfelLeVcEM97mmtRGXw==",
			"dev": true,
			"dependencies": {
				"binary-extensions": "^2.0.0"
			},
			"engines": {
				"node": ">=8"
			}
		},
		"node_modules/is-extglob": {
			"version": "2.1.1",
			"resolved": "https://registry.npmjs.org/is-extglob/-/is-extglob-2.1.1.tgz",
			"integrity": "sha512-SbKbANkN603Vi4jEZv49LeVJMn4yGwsbzZworEoyEiutsN3nJYdbO36zfhGJ6QEDpOZIFkDtnq5JRxmvl3jsoQ==",
			"dev": true,
			"engines": {
				"node": ">=0.10.0"
			}
		},
		"node_modules/is-fullwidth-code-point": {
			"version": "3.0.0",
			"resolved": "https://registry.npmjs.org/is-fullwidth-code-point/-/is-fullwidth-code-point-3.0.0.tgz",
			"integrity": "sha512-zymm5+u+sCsSWyD9qNaejV3DFvhCKclKdizYaJUuHA83RLjb7nSuGnddCHGv0hk+KY7BMAlsWeK4Ueg6EV6XQg==",
			"engines": {
				"node": ">=8"
			}
		},
		"node_modules/is-glob": {
			"version": "4.0.3",
			"resolved": "https://registry.npmjs.org/is-glob/-/is-glob-4.0.3.tgz",
			"integrity": "sha512-xelSayHH36ZgE7ZWhli7pW34hNbNl8Ojv5KVmkJD4hBdD3th8Tfk9vYasLM+mXWOZhFkgZfxhLSnrwRr4elSSg==",
			"dev": true,
			"dependencies": {
				"is-extglob": "^2.1.1"
			},
			"engines": {
				"node": ">=0.10.0"
			}
		},
		"node_modules/is-number": {
			"version": "7.0.0",
			"resolved": "https://registry.npmjs.org/is-number/-/is-number-7.0.0.tgz",
			"integrity": "sha512-41Cifkg6e8TylSpdtTpeLVMqvSBEVzTttHvERD741+pnZ8ANv0004MRL43QKPDlK9cGvNp6NZWZUBlbGXYxxng==",
			"dev": true,
			"license": "MIT",
			"engines": {
				"node": ">=0.12.0"
			}
		},
		"node_modules/jsbn": {
			"version": "1.1.0",
			"resolved": "https://registry.npmjs.org/jsbn/-/jsbn-1.1.0.tgz",
			"integrity": "sha512-4bYVV3aAMtDTTu4+xsDYa6sy9GyJ69/amsu9sYF2zqjiEoZA5xJi3BrfX3uY+/IekIu7MwdObdbDWpoZdBv3/A==",
			"license": "MIT"
		},
		"node_modules/jsonwebtoken": {
			"version": "9.0.2",
			"resolved": "https://registry.npmjs.org/jsonwebtoken/-/jsonwebtoken-9.0.2.tgz",
			"integrity": "sha512-PRp66vJ865SSqOlgqS8hujT5U4AOgMfhrwYIuIhfKaoSCZcirrmASQr8CX7cUg+RMih+hgznrjp99o+W4pJLHQ==",
			"license": "MIT",
			"dependencies": {
				"jws": "^3.2.2",
				"lodash.includes": "^4.3.0",
				"lodash.isboolean": "^3.0.3",
				"lodash.isinteger": "^4.0.4",
				"lodash.isnumber": "^3.0.3",
				"lodash.isplainobject": "^4.0.6",
				"lodash.isstring": "^4.0.1",
				"lodash.once": "^4.0.0",
				"ms": "^2.1.1",
				"semver": "^7.5.4"
			},
			"engines": {
				"node": ">=12",
				"npm": ">=6"
			}
		},
		"node_modules/jsonwebtoken/node_modules/ms": {
			"version": "2.1.3",
			"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
			"integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA=="
		},
		"node_modules/jwa": {
			"version": "1.4.1",
			"resolved": "https://registry.npmjs.org/jwa/-/jwa-1.4.1.tgz",
			"integrity": "sha512-qiLX/xhEEFKUAJ6FiBMbes3w9ATzyk5W7Hvzpa/SLYdxNtng+gcurvrI7TbACjIXlsJyr05/S1oUhZrc63evQA==",
			"dependencies": {
				"buffer-equal-constant-time": "1.0.1",
				"ecdsa-sig-formatter": "1.0.11",
				"safe-buffer": "^5.0.1"
			}
		},
		"node_modules/jws": {
			"version": "3.2.2",
			"resolved": "https://registry.npmjs.org/jws/-/jws-3.2.2.tgz",
			"integrity": "sha512-YHlZCB6lMTllWDtSPHz/ZXTsi8S00usEV6v1tjq8tOUZzw7DpSDWVXjXDre6ed1w/pd495ODpHZYSdkRTsa0HA==",
			"dependencies": {
				"jwa": "^1.4.1",
				"safe-buffer": "^5.0.1"
			}
		},
		"node_modules/lodash.includes": {
			"version": "4.3.0",
			"resolved": "https://registry.npmjs.org/lodash.includes/-/lodash.includes-4.3.0.tgz",
			"integrity": "sha512-W3Bx6mdkRTGtlJISOvVD/lbqjTlPPUDTMnlXZFnVwi9NKJ6tiAk6LVdlhZMm17VZisqhKcgzpO5Wz91PCt5b0w=="
		},
		"node_modules/lodash.isboolean": {
			"version": "3.0.3",
			"resolved": "https://registry.npmjs.org/lodash.isboolean/-/lodash.isboolean-3.0.3.tgz",
			"integrity": "sha512-Bz5mupy2SVbPHURB98VAcw+aHh4vRV5IPNhILUCsOzRmsTmSQ17jIuqopAentWoehktxGd9e/hbIXq980/1QJg=="
		},
		"node_modules/lodash.isinteger": {
			"version": "4.0.4",
			"resolved": "https://registry.npmjs.org/lodash.isinteger/-/lodash.isinteger-4.0.4.tgz",
			"integrity": "sha512-DBwtEWN2caHQ9/imiNeEA5ys1JoRtRfY3d7V9wkqtbycnAmTvRRmbHKDV4a0EYc678/dia0jrte4tjYwVBaZUA=="
		},
		"node_modules/lodash.isnumber": {
			"version": "3.0.3",
			"resolved": "https://registry.npmjs.org/lodash.isnumber/-/lodash.isnumber-3.0.3.tgz",
			"integrity": "sha512-QYqzpfwO3/CWf3XP+Z+tkQsfaLL/EnUlXWVkIk5FUPc4sBdTehEqZONuyRt2P67PXAk+NXmTBcc97zw9t1FQrw=="
		},
		"node_modules/lodash.isplainobject": {
			"version": "4.0.6",
			"resolved": "https://registry.npmjs.org/lodash.isplainobject/-/lodash.isplainobject-4.0.6.tgz",
			"integrity": "sha512-oSXzaWypCMHkPC3NvBEaPHf0KsA5mvPrOPgQWDsbg8n7orZ290M0BmC/jgRZ4vcJ6DTAhjrsSYgdsW/F+MFOBA=="
		},
		"node_modules/lodash.isstring": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/lodash.isstring/-/lodash.isstring-4.0.1.tgz",
			"integrity": "sha512-0wJxfxH1wgO3GrbuP+dTTk7op+6L41QCXbGINEmD+ny/G/eCqGzxyCsh7159S+mgDDcoarnBw6PC1PS5+wUGgw=="
		},
		"node_modules/lodash.once": {
			"version": "4.1.1",
			"resolved": "https://registry.npmjs.org/lodash.once/-/lodash.once-4.1.1.tgz",
			"integrity": "sha512-Sb487aTOCr9drQVL8pIxOzVhafOjZN9UU54hiN8PU3uAiSV7lx1yYNpbNmex2PK6dSJoNTSJUUswT651yww3Mg=="
		},
		"node_modules/make-dir": {
			"version": "3.1.0",
			"resolved": "https://registry.npmjs.org/make-dir/-/make-dir-3.1.0.tgz",
			"integrity": "sha512-g3FeP20LNwhALb/6Cz6Dd4F2ngze0jz7tbzrD2wAV+o9FeNHe4rL+yK2md0J/fiSf1sa1ADhXqi5+oVwOM/eGw==",
			"dependencies": {
				"semver": "^6.0.0"
			},
			"engines": {
				"node": ">=8"
			},
			"funding": {
				"url": "https://github.com/sponsors/sindresorhus"
			}
		},
		"node_modules/make-dir/node_modules/semver": {
			"version": "6.3.1",
			"resolved": "https://registry.npmjs.org/semver/-/semver-6.3.1.tgz",
			"integrity": "sha512-BR7VvDCVHO+q2xBEWskxS6DJE1qRnb7DxzUrogb71CWoSficBxYsiAGd+Kl0mmq/MprG9yArRkyrQxTO6XjMzA==",
			"license": "ISC",
			"bin": {
				"semver": "bin/semver.js"
			}
		},
		"node_modules/math-intrinsics": {
			"version": "1.1.0",
			"resolved": "https://registry.npmjs.org/math-intrinsics/-/math-intrinsics-1.1.0.tgz",
			"integrity": "sha512-/IXtbwEk5HTPyEwyKX6hGkYXxM9nbj64B+ilVJnC/R6B0pH5G4V3b0pVbL7DBj4tkhBAppbQUlf6F6Xl9LHu1g==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.4"
			}
		},
		"node_modules/media-typer": {
			"version": "0.3.0",
			"resolved": "https://registry.npmjs.org/media-typer/-/media-typer-0.3.0.tgz",
			"integrity": "sha512-dq+qelQ9akHpcOl/gUVRTxVIOkAJ1wR3QAvb4RsVjS8oVoFjDGTc679wJYmUmknUF5HwMLOgb5O+a3KxfWapPQ==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/memory-pager": {
			"version": "1.5.0",
			"resolved": "https://registry.npmjs.org/memory-pager/-/memory-pager-1.5.0.tgz",
			"integrity": "sha512-ZS4Bp4r/Zoeq6+NLJpP+0Zzm0pR8whtGPf1XExKLJBAczGMnSi3It14OiNCStjQjM6NU1okjQGSxgEZN8eBYKg==",
			"license": "MIT",
			"optional": true
		},
		"node_modules/merge-descriptors": {
			"version": "1.0.3",
			"resolved": "https://registry.npmjs.org/merge-descriptors/-/merge-descriptors-1.0.3.tgz",
			"integrity": "sha512-gaNvAS7TZ897/rVaZ0nMtAyxNyi/pdbjbAwUpFQpN70GqnVfOiXpeUUMKRBmzXaSQ8DdTX4/0ms62r2K+hE6mQ==",
			"license": "MIT",
			"funding": {
				"url": "https://github.com/sponsors/sindresorhus"
			}
		},
		"node_modules/methods": {
			"version": "1.1.2",
			"resolved": "https://registry.npmjs.org/methods/-/methods-1.1.2.tgz",
			"integrity": "sha512-iclAHeNqNm68zFtnZ0e+1L2yUIdvzNoauKU4WBA3VvH/vPFieF7qfRlwUZU+DA9P9bPXIS90ulxoUoCH23sV2w==",
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/mime": {
			"version": "1.6.0",
			"resolved": "https://registry.npmjs.org/mime/-/mime-1.6.0.tgz",
			"integrity": "sha512-x0Vn8spI+wuJ1O6S7gnbaQg8Pxh4NNHb7KSINmEWKiPE4RKOplvijn+NkmYmmRgP68mc70j2EbeTFRsrswaQeg==",
			"license": "MIT",
			"bin": {
				"mime": "cli.js"
			},
			"engines": {
				"node": ">=4"
			}
		},
		"node_modules/mime-db": {
			"version": "1.52.0",
			"resolved": "https://registry.npmjs.org/mime-db/-/mime-db-1.52.0.tgz",
			"integrity": "sha512-sPU4uV7dYlvtWJxwwxHD0PuihVNiE7TyAbQ5SWxDCB9mUYvOgroQOwYQQOKPJ8CIbE+1ETVlOoK1UC2nU3gYvg==",
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/mime-types": {
			"version": "2.1.35",
			"resolved": "https://registry.npmjs.org/mime-types/-/mime-types-2.1.35.tgz",
			"integrity": "sha512-ZDY+bPm5zTTF+YpCrAU9nK0UgICYPT0QtT1NZWFv4s++TNkcgVaT0g6+4R2uI4MjQjzysHB1zxuWL50hzaeXiw==",
			"dependencies": {
				"mime-db": "1.52.0"
			},
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/minimatch": {
			"version": "3.1.2",
			"resolved": "https://registry.npmjs.org/minimatch/-/minimatch-3.1.2.tgz",
			"integrity": "sha512-J7p63hRiAjw1NDEww1W7i37+ByIrOWO5XQQAzZ3VOcL0PNybwpfmV/N05zFAzwQ9USyEcX6t3UO+K5aqBQOIHw==",
			"dependencies": {
				"brace-expansion": "^1.1.7"
			},
			"engines": {
				"node": "*"
			}
		},
		"node_modules/minipass": {
			"version": "3.1.6",
			"resolved": "https://registry.npmjs.org/minipass/-/minipass-3.1.6.tgz",
			"integrity": "sha512-rty5kpw9/z8SX9dmxblFA6edItUmwJgMeYDZRrwlIVN27i8gysGbznJwUggw2V/FVqFSDdWy040ZPS811DYAqQ==",
			"dependencies": {
				"yallist": "^4.0.0"
			},
			"engines": {
				"node": ">=8"
			}
		},
		"node_modules/minizlib": {
			"version": "2.1.2",
			"resolved": "https://registry.npmjs.org/minizlib/-/minizlib-2.1.2.tgz",
			"integrity": "sha512-bAxsR8BVfj60DWXHE3u30oHzfl4G7khkSuPW+qvpd7jFRHm7dLxOjUk1EHACJ/hxLY8phGJ0YhYHZo7jil7Qdg==",
			"dependencies": {
				"minipass": "^3.0.0",
				"yallist": "^4.0.0"
			},
			"engines": {
				"node": ">= 8"
			}
		},
		"node_modules/mkdirp": {
			"version": "1.0.4",
			"resolved": "https://registry.npmjs.org/mkdirp/-/mkdirp-1.0.4.tgz",
			"integrity": "sha512-vVqVZQyf3WLx2Shd0qJ9xuvqgAyKPLAiqITEtqW0oIUjzo3PePDd6fW9iFz30ef7Ysp/oiWqbhszeGWW2T6Gzw==",
			"bin": {
				"mkdirp": "bin/cmd.js"
			},
			"engines": {
				"node": ">=10"
			}
		},
		"node_modules/mongodb": {
			"version": "4.17.2",
			"resolved": "https://registry.npmjs.org/mongodb/-/mongodb-4.17.2.tgz",
			"integrity": "sha512-mLV7SEiov2LHleRJPMPrK2PMyhXFZt2UQLC4VD4pnth3jMjYKHhtqfwwkkvS/NXuo/Fp3vbhaNcXrIDaLRb9Tg==",
			"license": "Apache-2.0",
			"dependencies": {
				"bson": "^4.7.2",
				"mongodb-connection-string-url": "^2.6.0",
				"socks": "^2.7.1"
			},
			"engines": {
				"node": ">=12.9.0"
			},
			"optionalDependencies": {
				"@aws-sdk/credential-providers": "^3.186.0",
				"@mongodb-js/saslprep": "^1.1.0"
			}
		},
		"node_modules/mongodb-connection-string-url": {
			"version": "2.6.0",
			"resolved": "https://registry.npmjs.org/mongodb-connection-string-url/-/mongodb-connection-string-url-2.6.0.tgz",
			"integrity": "sha512-WvTZlI9ab0QYtTYnuMLgobULWhokRjtC7db9LtcVfJ+Hsnyr5eo6ZtNAt3Ly24XZScGMelOcGtm7lSn0332tPQ==",
			"license": "Apache-2.0",
			"dependencies": {
				"@types/whatwg-url": "^8.2.1",
				"whatwg-url": "^11.0.0"
			}
		},
		"node_modules/ms": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/ms/-/ms-2.0.0.tgz",
			"integrity": "sha512-Tpp60P6IUJDTuOq/5Z8cdskzJujfwqfOTkrwIwj7IRISpnkJnT6SyJ4PCPnGMoFjC9ddhal5KVIYtAt97ix05A==",
			"license": "MIT"
		},
		"node_modules/negotiator": {
			"version": "0.6.3",
			"resolved": "https://registry.npmjs.org/negotiator/-/negotiator-0.6.3.tgz",
			"integrity": "sha512-+EUsqGPLsM+j/zdChZjsnX51g4XrHFOIXwfnCVPGlQk/k5giakcKsuxCObBRu6DSm9opw/O6slWbJdghQM4bBg==",
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/node-addon-api": {
			"version": "3.2.1",
			"resolved": "https://registry.npmjs.org/node-addon-api/-/node-addon-api-3.2.1.tgz",
			"integrity": "sha512-mmcei9JghVNDYydghQmeDX8KoAm0FAiYyIcUt/N4nhyAipB17pllZQDOJD2fotxABnt4Mdz+dKTO7eftLg4d0A=="
		},
		"node_modules/node-fetch": {
			"version": "2.6.7",
			"resolved": "https://registry.npmjs.org/node-fetch/-/node-fetch-2.6.7.tgz",
			"integrity": "sha512-ZjMPFEfVx5j+y2yF35Kzx5sF7kDzxuDj6ziH4FFbOp87zKDZNx8yExJIb05OGF4Nlt9IHFIMBkRl41VdvcNdbQ==",
			"dependencies": {
				"whatwg-url": "^5.0.0"
			},
			"engines": {
				"node": "4.x || >=6.0.0"
			},
			"peerDependencies": {
				"encoding": "^0.1.0"
			},
			"peerDependenciesMeta": {
				"encoding": {
					"optional": true
				}
			}
		},
		"node_modules/node-fetch/node_modules/tr46": {
			"version": "0.0.3",
			"resolved": "https://registry.npmjs.org/tr46/-/tr46-0.0.3.tgz",
			"integrity": "sha1-gYT9NH2snNwYWZLzpmIuFLnZq2o="
		},
		"node_modules/node-fetch/node_modules/webidl-conversions": {
			"version": "3.0.1",
			"resolved": "https://registry.npmjs.org/webidl-conversions/-/webidl-conversions-3.0.1.tgz",
			"integrity": "sha1-JFNCdeKnvGvnvIZhHMFq4KVlSHE="
		},
		"node_modules/node-fetch/node_modules/whatwg-url": {
			"version": "5.0.0",
			"resolved": "https://registry.npmjs.org/whatwg-url/-/whatwg-url-5.0.0.tgz",
			"integrity": "sha1-lmRU6HZUYuN2RNNib2dCzotwll0=",
			"dependencies": {
				"tr46": "~0.0.3",
				"webidl-conversions": "^3.0.0"
			}
		},
		"node_modules/nodemon": {
			"version": "3.1.9",
			"resolved": "https://registry.npmjs.org/nodemon/-/nodemon-3.1.9.tgz",
			"integrity": "sha512-hdr1oIb2p6ZSxu3PB2JWWYS7ZQ0qvaZsc3hK8DR8f02kRzc8rjYmxAIvdz+aYC+8F2IjNaB7HMcSDg8nQpJxyg==",
			"dev": true,
			"license": "MIT",
			"dependencies": {
				"chokidar": "^3.5.2",
				"debug": "^4",
				"ignore-by-default": "^1.0.1",
				"minimatch": "^3.1.2",
				"pstree.remy": "^1.1.8",
				"semver": "^7.5.3",
				"simple-update-notifier": "^2.0.0",
				"supports-color": "^5.5.0",
				"touch": "^3.1.0",
				"undefsafe": "^2.0.5"
			},
			"bin": {
				"nodemon": "bin/nodemon.js"
			},
			"engines": {
				"node": ">=10"
			},
			"funding": {
				"type": "opencollective",
				"url": "https://opencollective.com/nodemon"
			}
		},
		"node_modules/nodemon/node_modules/debug": {
			"version": "4.4.0",
			"resolved": "https://registry.npmjs.org/debug/-/debug-4.4.0.tgz",
			"integrity": "sha512-6WTZ/IxCY/T6BALoZHaE4ctp9xm+Z5kY/pzYaCHRFeyVhojxlrm+46y68HA6hr0TcwEssoxNiDEUJQjfPZ/RYA==",
			"dev": true,
			"license": "MIT",
			"dependencies": {
				"ms": "^2.1.3"
			},
			"engines": {
				"node": ">=6.0"
			},
			"peerDependenciesMeta": {
				"supports-color": {
					"optional": true
				}
			}
		},
		"node_modules/nodemon/node_modules/ms": {
			"version": "2.1.3",
			"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
			"integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA==",
			"dev": true,
			"license": "MIT"
		},
		"node_modules/nopt": {
			"version": "5.0.0",
			"resolved": "https://registry.npmjs.org/nopt/-/nopt-5.0.0.tgz",
			"integrity": "sha512-Tbj67rffqceeLpcRXrT7vKAN8CwfPeIBgM7E6iBkmKLV7bEMwpGgYLGv0jACUsECaa/vuxP0IjEont6umdMgtQ==",
			"dependencies": {
				"abbrev": "1"
			},
			"bin": {
				"nopt": "bin/nopt.js"
			},
			"engines": {
				"node": ">=6"
			}
		},
		"node_modules/normalize-path": {
			"version": "3.0.0",
			"resolved": "https://registry.npmjs.org/normalize-path/-/normalize-path-3.0.0.tgz",
			"integrity": "sha512-6eZs5Ls3WtCisHWp9S2GUy8dqkpGi4BVSz3GaqiE6ezub0512ESztXUwUB6C6IKbQkY2Pnb/mD4WYojCRwcwLA==",
			"dev": true,
			"engines": {
				"node": ">=0.10.0"
			}
		},
		"node_modules/npmlog": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/npmlog/-/npmlog-5.0.1.tgz",
			"integrity": "sha512-AqZtDUWOMKs1G/8lwylVjrdYgqA4d9nu8hc+0gzRxlDb1I10+FHBGMXs6aiQHFdCUUlqH99MUMuLfzWDNDtfxw==",
			"dependencies": {
				"are-we-there-yet": "^2.0.0",
				"console-control-strings": "^1.1.0",
				"gauge": "^3.0.0",
				"set-blocking": "^2.0.0"
			}
		},
		"node_modules/object-assign": {
			"version": "4.1.1",
			"resolved": "https://registry.npmjs.org/object-assign/-/object-assign-4.1.1.tgz",
			"integrity": "sha512-rJgTQnkUnH1sFw8yT6VSU3zD3sWmu6sZhIseY8VX+GRu3P6F7Fu+JNDoXfklElbLJSnc3FUQHVe4cU5hj+BcUg==",
			"engines": {
				"node": ">=0.10.0"
			}
		},
		"node_modules/object-inspect": {
			"version": "1.13.4",
			"resolved": "https://registry.npmjs.org/object-inspect/-/object-inspect-1.13.4.tgz",
			"integrity": "sha512-W67iLl4J2EXEGTbfeHCffrjDfitvLANg0UlX3wFUUSTx92KXRFegMHUVgSqE+wvhAbi4WqjGg9czysTV2Epbew==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.4"
			},
			"funding": {
				"url": "https://github.com/sponsors/ljharb"
			}
		},
		"node_modules/on-finished": {
			"version": "2.4.1",
			"resolved": "https://registry.npmjs.org/on-finished/-/on-finished-2.4.1.tgz",
			"integrity": "sha512-oVlzkg3ENAhCk2zdv7IJwd/QUD4z2RxRwpkcGY8psCVcCYZNq4wYnVWALHM+brtuJjePWiYF/ClmuDr8Ch5+kg==",
			"license": "MIT",
			"dependencies": {
				"ee-first": "1.1.1"
			},
			"engines": {
				"node": ">= 0.8"
			}
		},
		"node_modules/once": {
			"version": "1.4.0",
			"resolved": "https://registry.npmjs.org/once/-/once-1.4.0.tgz",
			"integrity": "sha512-lNaJgI+2Q5URQBkccEKHTQOPaXdUxnZZElQTZY0MFUAuaEqe1E+Nyvgdz/aIyNi6Z9MzO5dv1H8n58/GELp3+w==",
			"dependencies": {
				"wrappy": "1"
			}
		},
		"node_modules/parseurl": {
			"version": "1.3.3",
			"resolved": "https://registry.npmjs.org/parseurl/-/parseurl-1.3.3.tgz",
			"integrity": "sha512-CiyeOxFT/JZyN5m0z9PfXw4SCBJ6Sygz1Dpl0wqjlhDEGGBP1GnsUVEL0p63hoG1fcj3fHynXi9NYO4nWOL+qQ==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.8"
			}
		},
		"node_modules/path-is-absolute": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/path-is-absolute/-/path-is-absolute-1.0.1.tgz",
			"integrity": "sha512-AVbw3UJ2e9bq64vSaS9Am0fje1Pa8pbGqTTsmXfaIiMpnr5DlDhfJOuLj9Sf95ZPVDAUerDfEk88MPmPe7UCQg==",
			"engines": {
				"node": ">=0.10.0"
			}
		},
		"node_modules/path-to-regexp": {
			"version": "0.1.12",
			"resolved": "https://registry.npmjs.org/path-to-regexp/-/path-to-regexp-0.1.12.tgz",
			"integrity": "sha512-RA1GjUVMnvYFxuqovrEqZoxxW5NUZqbwKtYz/Tt7nXerk0LbLblQmrsgdeOxV5SFHf0UDggjS/bSeOZwt1pmEQ==",
			"license": "MIT"
		},
		"node_modules/picomatch": {
			"version": "2.3.1",
			"resolved": "https://registry.npmjs.org/picomatch/-/picomatch-2.3.1.tgz",
			"integrity": "sha512-JU3teHTNjmE2VCGFzuY8EXzCDVwEqB2a8fsIvwaStHhAWJEeVd1o1QD80CU6+ZdEXXSLbSsuLwJjkCBWqRQUVA==",
			"dev": true,
			"engines": {
				"node": ">=8.6"
			},
			"funding": {
				"url": "https://github.com/sponsors/jonschlinkert"
			}
		},
		"node_modules/proxy-addr": {
			"version": "2.0.7",
			"resolved": "https://registry.npmjs.org/proxy-addr/-/proxy-addr-2.0.7.tgz",
			"integrity": "sha512-llQsMLSUDUPT44jdrU/O37qlnifitDP+ZwrmmZcoSKyLKvtZxpyV0n2/bD/N4tBAAZ/gJEdZU7KMraoK1+XYAg==",
			"dependencies": {
				"forwarded": "0.2.0",
				"ipaddr.js": "1.9.1"
			},
			"engines": {
				"node": ">= 0.10"
			}
		},
		"node_modules/pstree.remy": {
			"version": "1.1.8",
			"resolved": "https://registry.npmjs.org/pstree.remy/-/pstree.remy-1.1.8.tgz",
			"integrity": "sha512-77DZwxQmxKnu3aR542U+X8FypNzbfJ+C5XQDk3uWjWxn6151aIMGthWYRXTqT1E5oJvg+ljaa2OJi+VfvCOQ8w==",
			"dev": true
		},
		"node_modules/punycode": {
			"version": "2.3.1",
			"resolved": "https://registry.npmjs.org/punycode/-/punycode-2.3.1.tgz",
			"integrity": "sha512-vYt7UD1U9Wg6138shLtLOvdAu+8DsC/ilFtEVHcH+wydcSpNE20AfSOduf6MkRFahL5FY7X1oU7nKVZFtfq8Fg==",
			"license": "MIT",
			"engines": {
				"node": ">=6"
			}
		},
		"node_modules/qs": {
			"version": "6.13.0",
			"resolved": "https://registry.npmjs.org/qs/-/qs-6.13.0.tgz",
			"integrity": "sha512-+38qI9SOr8tfZ4QmJNplMUxqjbe7LKvvZgWdExBOmd+egZTtjLB67Gu0HRX3u/XOq7UU2Nx6nsjvS16Z9uwfpg==",
			"license": "BSD-3-Clause",
			"dependencies": {
				"side-channel": "^1.0.6"
			},
			"engines": {
				"node": ">=0.6"
			},
			"funding": {
				"url": "https://github.com/sponsors/ljharb"
			}
		},
		"node_modules/range-parser": {
			"version": "1.2.1",
			"resolved": "https://registry.npmjs.org/range-parser/-/range-parser-1.2.1.tgz",
			"integrity": "sha512-Hrgsx+orqoygnmhFbKaHE6c296J+HTAQXoxEF6gNupROmmGJRoyzfG3ccAveqCBrwr/2yxQ5BVd/GTl5agOwSg==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/raw-body": {
			"version": "2.5.2",
			"resolved": "https://registry.npmjs.org/raw-body/-/raw-body-2.5.2.tgz",
			"integrity": "sha512-8zGqypfENjCIqGhgXToC8aB2r7YrBX+AQAfIPs/Mlk+BtPTztOvTS01NRW/3Eh60J+a48lt8qsCzirQ6loCVfA==",
			"license": "MIT",
			"dependencies": {
				"bytes": "3.1.2",
				"http-errors": "2.0.0",
				"iconv-lite": "0.4.24",
				"unpipe": "1.0.0"
			},
			"engines": {
				"node": ">= 0.8"
			}
		},
		"node_modules/readable-stream": {
			"version": "3.6.0",
			"resolved": "https://registry.npmjs.org/readable-stream/-/readable-stream-3.6.0.tgz",
			"integrity": "sha512-BViHy7LKeTz4oNnkcLJ+lVSL6vpiFeX6/d3oSH8zCW7UxP2onchk+vTGB143xuFjHS3deTgkKoXXymXqymiIdA==",
			"dependencies": {
				"inherits": "^2.0.3",
				"string_decoder": "^1.1.1",
				"util-deprecate": "^1.0.1"
			},
			"engines": {
				"node": ">= 6"
			}
		},
		"node_modules/readdirp": {
			"version": "3.6.0",
			"resolved": "https://registry.npmjs.org/readdirp/-/readdirp-3.6.0.tgz",
			"integrity": "sha512-hOS089on8RduqdbhvQ5Z37A0ESjsqz6qnRcffsMU3495FuTdqSm+7bhJ29JvIOsBDEEnan5DPu9t3To9VRlMzA==",
			"dev": true,
			"dependencies": {
				"picomatch": "^2.2.1"
			},
			"engines": {
				"node": ">=8.10.0"
			}
		},
		"node_modules/rimraf": {
			"version": "3.0.2",
			"resolved": "https://registry.npmjs.org/rimraf/-/rimraf-3.0.2.tgz",
			"integrity": "sha512-JZkJMZkAGFFPP2YqXZXPbMlMBgsxzE8ILs4lMIX/2o0L9UBw9O/Y3o6wFw/i9YLapcUJWwqbi3kdxIPdC62TIA==",
			"dependencies": {
				"glob": "^7.1.3"
			},
			"bin": {
				"rimraf": "bin.js"
			},
			"funding": {
				"url": "https://github.com/sponsors/isaacs"
			}
		},
		"node_modules/safe-buffer": {
			"version": "5.2.1",
			"resolved": "https://registry.npmjs.org/safe-buffer/-/safe-buffer-5.2.1.tgz",
			"integrity": "sha512-rp3So07KcdmmKbGvgaNxQSJr7bGVSVk5S9Eq1F+ppbRo70+YeaDxkw5Dd8NPN+GD6bjnYm2VuPuCXmpuYvmCXQ==",
			"funding": [
				{
					"type": "github",
					"url": "https://github.com/sponsors/feross"
				},
				{
					"type": "patreon",
					"url": "https://www.patreon.com/feross"
				},
				{
					"type": "consulting",
					"url": "https://feross.org/support"
				}
			]
		},
		"node_modules/safer-buffer": {
			"version": "2.1.2",
			"resolved": "https://registry.npmjs.org/safer-buffer/-/safer-buffer-2.1.2.tgz",
			"integrity": "sha512-YZo3K82SD7Riyi0E1EQPojLz7kpepnSQI9IyPbHHg1XXXevb5dJI7tpyN2ADxGcQbHG7vcyRHk0cbwqcQriUtg==",
			"license": "MIT"
		},
		"node_modules/semver": {
			"version": "7.7.1",
			"resolved": "https://registry.npmjs.org/semver/-/semver-7.7.1.tgz",
			"integrity": "sha512-hlq8tAfn0m/61p4BVRcPzIGr6LKiMwo4VM6dGi6pt4qcRkmNzTcWq6eCEjEh+qXjkMDvPlOFFSGwQjoEa6gyMA==",
			"license": "ISC",
			"bin": {
				"semver": "bin/semver.js"
			},
			"engines": {
				"node": ">=10"
			}
		},
		"node_modules/send": {
			"version": "0.19.0",
			"resolved": "https://registry.npmjs.org/send/-/send-0.19.0.tgz",
			"integrity": "sha512-dW41u5VfLXu8SJh5bwRmyYUbAoSB3c9uQh6L8h/KtsFREPWpbX1lrljJo186Jc4nmci/sGUZ9a0a0J2zgfq2hw==",
			"license": "MIT",
			"dependencies": {
				"debug": "2.6.9",
				"depd": "2.0.0",
				"destroy": "1.2.0",
				"encodeurl": "~1.0.2",
				"escape-html": "~1.0.3",
				"etag": "~1.8.1",
				"fresh": "0.5.2",
				"http-errors": "2.0.0",
				"mime": "1.6.0",
				"ms": "2.1.3",
				"on-finished": "2.4.1",
				"range-parser": "~1.2.1",
				"statuses": "2.0.1"
			},
			"engines": {
				"node": ">= 0.8.0"
			}
		},
		"node_modules/send/node_modules/encodeurl": {
			"version": "1.0.2",
			"resolved": "https://registry.npmjs.org/encodeurl/-/encodeurl-1.0.2.tgz",
			"integrity": "sha512-TPJXq8JqFaVYm2CWmPvnP2Iyo4ZSM7/QKcSmuMLDObfpH5fi7RUGmd/rTDf+rut/saiDiQEeVTNgAmJEdAOx0w==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.8"
			}
		},
		"node_modules/send/node_modules/ms": {
			"version": "2.1.3",
			"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
			"integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA==",
			"license": "MIT"
		},
		"node_modules/serve-static": {
			"version": "1.16.2",
			"resolved": "https://registry.npmjs.org/serve-static/-/serve-static-1.16.2.tgz",
			"integrity": "sha512-VqpjJZKadQB/PEbEwvFdO43Ax5dFBZ2UECszz8bQ7pi7wt//PWe1P6MN7eCnjsatYtBT6EuiClbjSWP2WrIoTw==",
			"license": "MIT",
			"dependencies": {
				"encodeurl": "~2.0.0",
				"escape-html": "~1.0.3",
				"parseurl": "~1.3.3",
				"send": "0.19.0"
			},
			"engines": {
				"node": ">= 0.8.0"
			}
		},
		"node_modules/set-blocking": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/set-blocking/-/set-blocking-2.0.0.tgz",
			"integrity": "sha1-BF+XgtARrppoA93TgrJDkrPYkPc="
		},
		"node_modules/setprototypeof": {
			"version": "1.2.0",
			"resolved": "https://registry.npmjs.org/setprototypeof/-/setprototypeof-1.2.0.tgz",
			"integrity": "sha512-E5LDX7Wrp85Kil5bhZv46j8jOeboKq5JMmYM3gVGdGH8xFpPWXUMsNrlODCrkoxMEeNi/XZIwuRvY4XNwYMJpw==",
			"license": "ISC"
		},
		"node_modules/side-channel": {
			"version": "1.1.0",
			"resolved": "https://registry.npmjs.org/side-channel/-/side-channel-1.1.0.tgz",
			"integrity": "sha512-ZX99e6tRweoUXqR+VBrslhda51Nh5MTQwou5tnUDgbtyM0dBgmhEDtWGP/xbKn6hqfPRHujUNwz5fy/wbbhnpw==",
			"license": "MIT",
			"dependencies": {
				"es-errors": "^1.3.0",
				"object-inspect": "^1.13.3",
				"side-channel-list": "^1.0.0",
				"side-channel-map": "^1.0.1",
				"side-channel-weakmap": "^1.0.2"
			},
			"engines": {
				"node": ">= 0.4"
			},
			"funding": {
				"url": "https://github.com/sponsors/ljharb"
			}
		},
		"node_modules/side-channel-list": {
			"version": "1.0.0",
			"resolved": "https://registry.npmjs.org/side-channel-list/-/side-channel-list-1.0.0.tgz",
			"integrity": "sha512-FCLHtRD/gnpCiCHEiJLOwdmFP+wzCmDEkc9y7NsYxeF4u7Btsn1ZuwgwJGxImImHicJArLP4R0yX4c2KCrMrTA==",
			"license": "MIT",
			"dependencies": {
				"es-errors": "^1.3.0",
				"object-inspect": "^1.13.3"
			},
			"engines": {
				"node": ">= 0.4"
			},
			"funding": {
				"url": "https://github.com/sponsors/ljharb"
			}
		},
		"node_modules/side-channel-map": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/side-channel-map/-/side-channel-map-1.0.1.tgz",
			"integrity": "sha512-VCjCNfgMsby3tTdo02nbjtM/ewra6jPHmpThenkTYh8pG9ucZ/1P8So4u4FGBek/BjpOVsDCMoLA/iuBKIFXRA==",
			"license": "MIT",
			"dependencies": {
				"call-bound": "^1.0.2",
				"es-errors": "^1.3.0",
				"get-intrinsic": "^1.2.5",
				"object-inspect": "^1.13.3"
			},
			"engines": {
				"node": ">= 0.4"
			},
			"funding": {
				"url": "https://github.com/sponsors/ljharb"
			}
		},
		"node_modules/side-channel-weakmap": {
			"version": "1.0.2",
			"resolved": "https://registry.npmjs.org/side-channel-weakmap/-/side-channel-weakmap-1.0.2.tgz",
			"integrity": "sha512-WPS/HvHQTYnHisLo9McqBHOJk2FkHO/tlpvldyrnem4aeQp4hai3gythswg6p01oSoTl58rcpiFAjF2br2Ak2A==",
			"license": "MIT",
			"dependencies": {
				"call-bound": "^1.0.2",
				"es-errors": "^1.3.0",
				"get-intrinsic": "^1.2.5",
				"object-inspect": "^1.13.3",
				"side-channel-map": "^1.0.1"
			},
			"engines": {
				"node": ">= 0.4"
			},
			"funding": {
				"url": "https://github.com/sponsors/ljharb"
			}
		},
		"node_modules/signal-exit": {
			"version": "3.0.7",
			"resolved": "https://registry.npmjs.org/signal-exit/-/signal-exit-3.0.7.tgz",
			"integrity": "sha512-wnD2ZE+l+SPC/uoS0vXeE9L1+0wuaMqKlfz9AMUo38JsyLSBWSFcHR1Rri62LZc12vLr1gb3jl7iwQhgwpAbGQ=="
		},
		"node_modules/simple-update-notifier": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/simple-update-notifier/-/simple-update-notifier-2.0.0.tgz",
			"integrity": "sha512-a2B9Y0KlNXl9u/vsW6sTIu9vGEpfKu2wRV6l1H3XEas/0gUIzGzBoP/IouTcUQbm9JWZLH3COxyn03TYlFax6w==",
			"dev": true,
			"license": "MIT",
			"dependencies": {
				"semver": "^7.5.3"
			},
			"engines": {
				"node": ">=10"
			}
		},
		"node_modules/smart-buffer": {
			"version": "4.2.0",
			"resolved": "https://registry.npmjs.org/smart-buffer/-/smart-buffer-4.2.0.tgz",
			"integrity": "sha512-94hK0Hh8rPqQl2xXc3HsaBoOXKV20MToPkcXvwbISWLEs+64sBq5kFgn2kJDHb1Pry9yrP0dxrCI9RRci7RXKg==",
			"license": "MIT",
			"engines": {
				"node": ">= 6.0.0",
				"npm": ">= 3.0.0"
			}
		},
		"node_modules/socket.io": {
			"version": "4.8.1",
			"resolved": "https://registry.npmjs.org/socket.io/-/socket.io-4.8.1.tgz",
			"integrity": "sha512-oZ7iUCxph8WYRHHcjBEc9unw3adt5CmSNlppj/5Q4k2RIrhl8Z5yY2Xr4j9zj0+wzVZ0bxmYoGSzKJnRl6A4yg==",
			"license": "MIT",
			"dependencies": {
				"accepts": "~1.3.4",
				"base64id": "~2.0.0",
				"cors": "~2.8.5",
				"debug": "~4.3.2",
				"engine.io": "~6.6.0",
				"socket.io-adapter": "~2.5.2",
				"socket.io-parser": "~4.2.4"
			},
			"engines": {
				"node": ">=10.2.0"
			}
		},
		"node_modules/socket.io-adapter": {
			"version": "2.5.5",
			"resolved": "https://registry.npmjs.org/socket.io-adapter/-/socket.io-adapter-2.5.5.tgz",
			"integrity": "sha512-eLDQas5dzPgOWCk9GuuJC2lBqItuhKI4uxGgo9aIV7MYbk2h9Q6uULEh8WBzThoI7l+qU9Ast9fVUmkqPP9wYg==",
			"license": "MIT",
			"dependencies": {
				"debug": "~4.3.4",
				"ws": "~8.17.1"
			}
		},
		"node_modules/socket.io-adapter/node_modules/debug": {
			"version": "4.3.7",
			"resolved": "https://registry.npmjs.org/debug/-/debug-4.3.7.tgz",
			"integrity": "sha512-Er2nc/H7RrMXZBFCEim6TCmMk02Z8vLC2Rbi1KEBggpo0fS6l0S1nnapwmIi3yW/+GOJap1Krg4w0Hg80oCqgQ==",
			"license": "MIT",
			"dependencies": {
				"ms": "^2.1.3"
			},
			"engines": {
				"node": ">=6.0"
			},
			"peerDependenciesMeta": {
				"supports-color": {
					"optional": true
				}
			}
		},
		"node_modules/socket.io-adapter/node_modules/ms": {
			"version": "2.1.3",
			"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
			"integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA==",
			"license": "MIT"
		},
		"node_modules/socket.io-parser": {
			"version": "4.2.4",
			"resolved": "https://registry.npmjs.org/socket.io-parser/-/socket.io-parser-4.2.4.tgz",
			"integrity": "sha512-/GbIKmo8ioc+NIWIhwdecY0ge+qVBSMdgxGygevmdHj24bsfgtCmcUUcQ5ZzcylGFHsN3k4HB4Cgkl96KVnuew==",
			"license": "MIT",
			"dependencies": {
				"@socket.io/component-emitter": "~3.1.0",
				"debug": "~4.3.1"
			},
			"engines": {
				"node": ">=10.0.0"
			}
		},
		"node_modules/socket.io-parser/node_modules/debug": {
			"version": "4.3.7",
			"resolved": "https://registry.npmjs.org/debug/-/debug-4.3.7.tgz",
			"integrity": "sha512-Er2nc/H7RrMXZBFCEim6TCmMk02Z8vLC2Rbi1KEBggpo0fS6l0S1nnapwmIi3yW/+GOJap1Krg4w0Hg80oCqgQ==",
			"license": "MIT",
			"dependencies": {
				"ms": "^2.1.3"
			},
			"engines": {
				"node": ">=6.0"
			},
			"peerDependenciesMeta": {
				"supports-color": {
					"optional": true
				}
			}
		},
		"node_modules/socket.io-parser/node_modules/ms": {
			"version": "2.1.3",
			"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
			"integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA==",
			"license": "MIT"
		},
		"node_modules/socket.io/node_modules/debug": {
			"version": "4.3.4",
			"resolved": "https://registry.npmjs.org/debug/-/debug-4.3.4.tgz",
			"integrity": "sha512-PRWFHuSU3eDtQJPvnNY7Jcket1j0t5OuOsFzPPzsekD52Zl8qUfFIPEiswXqIvHWGVHOgX+7G/vCNNhehwxfkQ==",
			"dependencies": {
				"ms": "2.1.2"
			},
			"engines": {
				"node": ">=6.0"
			},
			"peerDependenciesMeta": {
				"supports-color": {
					"optional": true
				}
			}
		},
		"node_modules/socket.io/node_modules/ms": {
			"version": "2.1.2",
			"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.2.tgz",
			"integrity": "sha512-sGkPx+VjMtmA6MX27oA4FBFELFCZZ4S4XqeGOXCv68tT+jb3vk/RyaKWP0PTKyWtmLSM0b+adUTEvbs1PEaH2w=="
		},
		"node_modules/socks": {
			"version": "2.8.4",
			"resolved": "https://registry.npmjs.org/socks/-/socks-2.8.4.tgz",
			"integrity": "sha512-D3YaD0aRxR3mEcqnidIs7ReYJFVzWdd6fXJYUM8ixcQcJRGTka/b3saV0KflYhyVJXKhb947GndU35SxYNResQ==",
			"license": "MIT",
			"dependencies": {
				"ip-address": "^9.0.5",
				"smart-buffer": "^4.2.0"
			},
			"engines": {
				"node": ">= 10.0.0",
				"npm": ">= 3.0.0"
			}
		},
		"node_modules/sparse-bitfield": {
			"version": "3.0.3",
			"resolved": "https://registry.npmjs.org/sparse-bitfield/-/sparse-bitfield-3.0.3.tgz",
			"integrity": "sha512-kvzhi7vqKTfkh0PZU+2D2PIllw2ymqJKujUcyPMd9Y75Nv4nPbGJZXNhxsgdQab2BmlDct1YnfQCguEvHr7VsQ==",
			"license": "MIT",
			"optional": true,
			"dependencies": {
				"memory-pager": "^1.0.2"
			}
		},
		"node_modules/sprintf-js": {
			"version": "1.1.3",
			"resolved": "https://registry.npmjs.org/sprintf-js/-/sprintf-js-1.1.3.tgz",
			"integrity": "sha512-Oo+0REFV59/rz3gfJNKQiBlwfHaSESl1pcGyABQsnnIfWOFt6JNj5gCog2U6MLZ//IGYD+nA8nI+mTShREReaA==",
			"license": "BSD-3-Clause"
		},
		"node_modules/statuses": {
			"version": "2.0.1",
			"resolved": "https://registry.npmjs.org/statuses/-/statuses-2.0.1.tgz",
			"integrity": "sha512-RwNA9Z/7PrK06rYLIzFMlaF+l73iwpzsqRIFgbMLbTcLD6cOao82TaWefPXQvB2fOC4AjuYSEndS7N/mTCbkdQ==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.8"
			}
		},
		"node_modules/string_decoder": {
			"version": "1.3.0",
			"resolved": "https://registry.npmjs.org/string_decoder/-/string_decoder-1.3.0.tgz",
			"integrity": "sha512-hkRX8U1WjJFd8LsDJ2yQ/wWWxaopEsABU1XfkM8A+j0+85JAGppt16cr1Whg6KIbb4okU6Mql6BOj+uup/wKeA==",
			"dependencies": {
				"safe-buffer": "~5.2.0"
			}
		},
		"node_modules/string-width": {
			"version": "4.2.3",
			"resolved": "https://registry.npmjs.org/string-width/-/string-width-4.2.3.tgz",
			"integrity": "sha512-wKyQRQpjJ0sIp62ErSZdGsjMJWsap5oRNihHhu6G7JVO/9jIB6UyevL+tXuOqrng8j/cxKTWyWUwvSTriiZz/g==",
			"dependencies": {
				"emoji-regex": "^8.0.0",
				"is-fullwidth-code-point": "^3.0.0",
				"strip-ansi": "^6.0.1"
			},
			"engines": {
				"node": ">=8"
			}
		},
		"node_modules/strip-ansi": {
			"version": "6.0.1",
			"resolved": "https://registry.npmjs.org/strip-ansi/-/strip-ansi-6.0.1.tgz",
			"integrity": "sha512-Y38VPSHcqkFrCpFnQ9vuSXmquuv5oXOKpGeT6aGrr3o3Gc9AlVa6JBfUSOCnbxGGZF+/0ooI7KrPuUSztUdU5A==",
			"dependencies": {
				"ansi-regex": "^5.0.1"
			},
			"engines": {
				"node": ">=8"
			}
		},
		"node_modules/strnum": {
			"version": "1.1.2",
			"resolved": "https://registry.npmjs.org/strnum/-/strnum-1.1.2.tgz",
			"integrity": "sha512-vrN+B7DBIoTTZjnPNewwhx6cBA/H+IS7rfW68n7XxC1y7uoiGQBxaKzqucGUgavX15dJgiGztLJ8vxuEzwqBdA==",
			"funding": [
				{
					"type": "github",
					"url": "https://github.com/sponsors/NaturalIntelligence"
				}
			],
			"license": "MIT",
			"optional": true
		},
		"node_modules/supports-color": {
			"version": "5.5.0",
			"resolved": "https://registry.npmjs.org/supports-color/-/supports-color-5.5.0.tgz",
			"integrity": "sha512-QjVjwdXIt408MIiAqCX4oUKsgU2EqAGzs2Ppkm4aQYbjm+ZEWEcW4SfFNTr4uMNZma0ey4f5lgLrkB0aX0QMow==",
			"dev": true,
			"dependencies": {
				"has-flag": "^3.0.0"
			},
			"engines": {
				"node": ">=4"
			}
		},
		"node_modules/tar": {
			"version": "6.2.1",
			"resolved": "https://registry.npmjs.org/tar/-/tar-6.2.1.tgz",
			"integrity": "sha512-DZ4yORTwrbTj/7MZYq2w+/ZFdI6OZ/f9SFHR+71gIVUZhOQPHzVCLpvRnPgyaMpfWxxk/4ONva3GQSyNIKRv6A==",
			"license": "ISC",
			"dependencies": {
				"chownr": "^2.0.0",
				"fs-minipass": "^2.0.0",
				"minipass": "^5.0.0",
				"minizlib": "^2.1.1",
				"mkdirp": "^1.0.3",
				"yallist": "^4.0.0"
			},
			"engines": {
				"node": ">=10"
			}
		},
		"node_modules/tar/node_modules/minipass": {
			"version": "5.0.0",
			"resolved": "https://registry.npmjs.org/minipass/-/minipass-5.0.0.tgz",
			"integrity": "sha512-3FnjYuehv9k6ovOEbyOswadCDPX1piCfhV8ncmYtHOjuPwylVWsghTLo7rabjC3Rx5xD4HDx8Wm1xnMF7S5qFQ==",
			"license": "ISC",
			"engines": {
				"node": ">=8"
			}
		},
		"node_modules/to-regex-range": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/to-regex-range/-/to-regex-range-5.0.1.tgz",
			"integrity": "sha512-65P7iz6X5yEr1cwcgvQxbbIw7Uk3gOy5dIdtZ4rDveLqhrdJP+Li/Hx6tyK0NEb+2GCyneCMJiGqrADCSNk8sQ==",
			"dev": true,
			"license": "MIT",
			"dependencies": {
				"is-number": "^7.0.0"
			},
			"engines": {
				"node": ">=8.0"
			}
		},
		"node_modules/toidentifier": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/toidentifier/-/toidentifier-1.0.1.tgz",
			"integrity": "sha512-o5sSPKEkg/DIQNmH43V0/uerLrpzVedkUh8tGNvaeXpfpuwjKenlSox/2O/BTlZUtEe+JG7s5YhEz608PlAHRA==",
			"license": "MIT",
			"engines": {
				"node": ">=0.6"
			}
		},
		"node_modules/touch": {
			"version": "3.1.0",
			"resolved": "https://registry.npmjs.org/touch/-/touch-3.1.0.tgz",
			"integrity": "sha512-WBx8Uy5TLtOSRtIq+M03/sKDrXCLHxwDcquSP2c43Le03/9serjQBIztjRz6FkJez9D/hleyAXTBGLwwZUw9lA==",
			"dev": true,
			"dependencies": {
				"nopt": "~1.0.10"
			},
			"bin": {
				"nodetouch": "bin/nodetouch.js"
			}
		},
		"node_modules/touch/node_modules/nopt": {
			"version": "1.0.10",
			"resolved": "https://registry.npmjs.org/nopt/-/nopt-1.0.10.tgz",
			"integrity": "sha512-NWmpvLSqUrgrAC9HCuxEvb+PSloHpqVu+FqcO4eeF2h5qYRhA7ev6KvelyQAKtegUbC6RypJnlEOhd8vloNKYg==",
			"dev": true,
			"dependencies": {
				"abbrev": "1"
			},
			"bin": {
				"nopt": "bin/nopt.js"
			},
			"engines": {
				"node": "*"
			}
		},
		"node_modules/tr46": {
			"version": "3.0.0",
			"resolved": "https://registry.npmjs.org/tr46/-/tr46-3.0.0.tgz",
			"integrity": "sha512-l7FvfAHlcmulp8kr+flpQZmVwtu7nfRV7NZujtN0OqES8EL4O4e0qqzL0DC5gAvx/ZC/9lk6rhcUwYvkBnBnYA==",
			"license": "MIT",
			"dependencies": {
				"punycode": "^2.1.1"
			},
			"engines": {
				"node": ">=12"
			}
		},
		"node_modules/tslib": {
			"version": "2.8.1",
			"resolved": "https://registry.npmjs.org/tslib/-/tslib-2.8.1.tgz",
			"integrity": "sha512-oJFu94HQb+KVduSUQL7wnpmqnfmLsOA/nAh6b6EH0wCEoK0/mPeXU6c3wKDV83MkOuHPRHtSXKKU99IBazS/2w==",
			"license": "0BSD",
			"optional": true
		},
		"node_modules/type-is": {
			"version": "1.6.18",
			"resolved": "https://registry.npmjs.org/type-is/-/type-is-1.6.18.tgz",
			"integrity": "sha512-TkRKr9sUTxEH8MdfuCSP7VizJyzRNMjj2J2do2Jr3Kym598JVdEksuzPQCnlFPW4ky9Q+iA+ma9BGm06XQBy8g==",
			"license": "MIT",
			"dependencies": {
				"media-typer": "0.3.0",
				"mime-types": "~2.1.24"
			},
			"engines": {
				"node": ">= 0.6"
			}
		},
		"node_modules/undefsafe": {
			"version": "2.0.5",
			"resolved": "https://registry.npmjs.org/undefsafe/-/undefsafe-2.0.5.tgz",
			"integrity": "sha512-WxONCrssBM8TSPRqN5EmsjVrsv4A8X12J4ArBiiayv3DyyG3ZlIg6yysuuSYdZsVz3TKcTg2fd//Ujd4CHV1iA==",
			"dev": true
		},
		"node_modules/unpipe": {
			"version": "1.0.0",
			"resolved": "https://registry.npmjs.org/unpipe/-/unpipe-1.0.0.tgz",
			"integrity": "sha512-pjy2bYhSsufwWlKwPc+l3cN7+wuJlK6uz0YdJEOlQDbl6jo/YlPi4mb8agUkVC8BF7V8NuzeyPNqRksA3hztKQ==",
			"license": "MIT",
			"engines": {
				"node": ">= 0.8"
			}
		},
		"node_modules/util-deprecate": {
			"version": "1.0.2",
			"resolved": "https://registry.npmjs.org/util-deprecate/-/util-deprecate-1.0.2.tgz",
			"integrity": "sha1-RQ1Nyfpw3nMnYvvS1KKJgUGaDM8="
		},
		"node_modules/utils-merge": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/utils-merge/-/utils-merge-1.0.1.tgz",
			"integrity": "sha1-n5VxD1CiZ5R7LMwSR0HBAoQn5xM=",
			"engines": {
				"node": ">= 0.4.0"
			}
		},
		"node_modules/uuid": {
			"version": "8.3.2",
			"resolved": "https://registry.npmjs.org/uuid/-/uuid-8.3.2.tgz",
			"integrity": "sha512-+NYs2QeMWy+GWFOEm9xnn6HCDp0l7QBD7ml8zLUmJ+93Q5NF0NocErnwkTkXVFNiX3/fpC6afS8Dhb/gz7R7eg==",
			"bin": {
				"uuid": "dist/bin/uuid"
			}
		},
		"node_modules/vary": {
			"version": "1.1.2",
			"resolved": "https://registry.npmjs.org/vary/-/vary-1.1.2.tgz",
			"integrity": "sha1-IpnwLG3tMNSllhsLn3RSShj2NPw=",
			"engines": {
				"node": ">= 0.8"
			}
		},
		"node_modules/webidl-conversions": {
			"version": "7.0.0",
			"resolved": "https://registry.npmjs.org/webidl-conversions/-/webidl-conversions-7.0.0.tgz",
			"integrity": "sha512-VwddBukDzu71offAQR975unBIGqfKZpM+8ZX6ySk8nYhVoo5CYaZyzt3YBvYtRtO+aoGlqxPg/B87NGVZ/fu6g==",
			"license": "BSD-2-Clause",
			"engines": {
				"node": ">=12"
			}
		},
		"node_modules/whatwg-url": {
			"version": "11.0.0",
			"resolved": "https://registry.npmjs.org/whatwg-url/-/whatwg-url-11.0.0.tgz",
			"integrity": "sha512-RKT8HExMpoYx4igMiVMY83lN6UeITKJlBQ+vR/8ZJ8OCdSiN3RwCq+9gH0+Xzj0+5IrM6i4j/6LuvzbZIQgEcQ==",
			"license": "MIT",
			"dependencies": {
				"tr46": "^3.0.0",
				"webidl-conversions": "^7.0.0"
			},
			"engines": {
				"node": ">=12"
			}
		},
		"node_modules/wide-align": {
			"version": "1.1.5",
			"resolved": "https://registry.npmjs.org/wide-align/-/wide-align-1.1.5.tgz",
			"integrity": "sha512-eDMORYaPNZ4sQIuuYPDHdQvf4gyCF9rEEV/yPxGfwPkRodwEgiMUUXTx/dex+Me0wxx53S+NgUHaP7y3MGlDmg==",
			"dependencies": {
				"string-width": "^1.0.2 || 2 || 3 || 4"
			}
		},
		"node_modules/wrappy": {
			"version": "1.0.2",
			"resolved": "https://registry.npmjs.org/wrappy/-/wrappy-1.0.2.tgz",
			"integrity": "sha1-tSQ9jz7BqjXxNkYFvA0QNuMKtp8="
		},
		"node_modules/ws": {
			"version": "8.17.1",
			"resolved": "https://registry.npmjs.org/ws/-/ws-8.17.1.tgz",
			"integrity": "sha512-6XQFvXTkbfUOZOKKILFG1PDK2NDQs4azKQl26T0YS5CxqWLgXajbPZ+h4gZekJyRqFU8pvnbAbbs/3TgRPy+GQ==",
			"license": "MIT",
			"engines": {
				"node": ">=10.0.0"
			},
			"peerDependencies": {
				"bufferutil": "^4.0.1",
				"utf-8-validate": ">=5.0.2"
			},
			"peerDependenciesMeta": {
				"bufferutil": {
					"optional": true
				},
				"utf-8-validate": {
					"optional": true
				}
			}
		},
		"node_modules/yallist": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/yallist/-/yallist-4.0.0.tgz",
			"integrity": "sha512-3wdGidZyq5PB084XLES5TpOSRA3wjXAlIWMhum2kRcv/41Sn2emQ0dycQW4uZXLejwKvg6EsvbdlVL+FYEct7A=="
		}
	},
	"dependencies": {
		"@aws-crypto/sha256-browser": {
			"version": "5.2.0",
			"resolved": "https://registry.npmjs.org/@aws-crypto/sha256-browser/-/sha256-browser-5.2.0.tgz",
			"integrity": "sha512-AXfN/lGotSQwu6HNcEsIASo7kWXZ5HYWvfOmSNKDsEqC4OashTp8alTmaz+F7TC2L083SFv5RdB+qU3Vs1kZqw==",
			"optional": true,
			"requires": {
				"@aws-crypto/sha256-js": "^5.2.0",
				"@aws-crypto/supports-web-crypto": "^5.2.0",
				"@aws-crypto/util": "^5.2.0",
				"@aws-sdk/types": "^3.222.0",
				"@aws-sdk/util-locate-window": "^3.0.0",
				"@smithy/util-utf8": "^2.0.0",
				"tslib": "^2.6.2"
			},
			"dependencies": {
				"@smithy/is-array-buffer": {
					"version": "2.2.0",
					"resolved": "https://registry.npmjs.org/@smithy/is-array-buffer/-/is-array-buffer-2.2.0.tgz",
					"integrity": "sha512-GGP3O9QFD24uGeAXYUjwSTXARoqpZykHadOmA8G5vfJPK0/DC67qa//0qvqrJzL1xc8WQWX7/yc7fwudjPHPhA==",
					"optional": true,
					"requires": {
						"tslib": "^2.6.2"
					}
				},
				"@smithy/util-buffer-from": {
					"version": "2.2.0",
					"resolved": "https://registry.npmjs.org/@smithy/util-buffer-from/-/util-buffer-from-2.2.0.tgz",
					"integrity": "sha512-IJdWBbTcMQ6DA0gdNhh/BwrLkDR+ADW5Kr1aZmd4k3DIF6ezMV4R2NIAmT08wQJ3yUK82thHWmC/TnK/wpMMIA==",
					"optional": true,
					"requires": {
						"@smithy/is-array-buffer": "^2.2.0",
						"tslib": "^2.6.2"
					}
				},
				"@smithy/util-utf8": {
					"version": "2.3.0",
					"resolved": "https://registry.npmjs.org/@smithy/util-utf8/-/util-utf8-2.3.0.tgz",
					"integrity": "sha512-R8Rdn8Hy72KKcebgLiv8jQcQkXoLMOGGv5uI1/k0l+snqkOzQ1R0ChUBCxWMlBsFMekWjq0wRudIweFs7sKT5A==",
					"optional": true,
					"requires": {
						"@smithy/util-buffer-from": "^2.2.0",
						"tslib": "^2.6.2"
					}
				}
			}
		},
		"@aws-crypto/sha256-js": {
			"version": "5.2.0",
			"resolved": "https://registry.npmjs.org/@aws-crypto/sha256-js/-/sha256-js-5.2.0.tgz",
			"integrity": "sha512-FFQQyu7edu4ufvIZ+OadFpHHOt+eSTBaYaki44c+akjg7qZg9oOQeLlk77F6tSYqjDAFClrHJk9tMf0HdVyOvA==",
			"optional": true,
			"requires": {
				"@aws-crypto/util": "^5.2.0",
				"@aws-sdk/types": "^3.222.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-crypto/supports-web-crypto": {
			"version": "5.2.0",
			"resolved": "https://registry.npmjs.org/@aws-crypto/supports-web-crypto/-/supports-web-crypto-5.2.0.tgz",
			"integrity": "sha512-iAvUotm021kM33eCdNfwIN//F77/IADDSs58i+MDaOqFrVjZo9bAal0NK7HurRuWLLpF1iLX7gbWrjHjeo+YFg==",
			"optional": true,
			"requires": {
				"tslib": "^2.6.2"
			}
		},
		"@aws-crypto/util": {
			"version": "5.2.0",
			"resolved": "https://registry.npmjs.org/@aws-crypto/util/-/util-5.2.0.tgz",
			"integrity": "sha512-4RkU9EsI6ZpBve5fseQlGNUWKMa1RLPQ1dnjnQoe07ldfIzcsGb5hC5W0Dm7u423KWzawlrpbjXBrXCEv9zazQ==",
			"optional": true,
			"requires": {
				"@aws-sdk/types": "^3.222.0",
				"@smithy/util-utf8": "^2.0.0",
				"tslib": "^2.6.2"
			},
			"dependencies": {
				"@smithy/is-array-buffer": {
					"version": "2.2.0",
					"resolved": "https://registry.npmjs.org/@smithy/is-array-buffer/-/is-array-buffer-2.2.0.tgz",
					"integrity": "sha512-GGP3O9QFD24uGeAXYUjwSTXARoqpZykHadOmA8G5vfJPK0/DC67qa//0qvqrJzL1xc8WQWX7/yc7fwudjPHPhA==",
					"optional": true,
					"requires": {
						"tslib": "^2.6.2"
					}
				},
				"@smithy/util-buffer-from": {
					"version": "2.2.0",
					"resolved": "https://registry.npmjs.org/@smithy/util-buffer-from/-/util-buffer-from-2.2.0.tgz",
					"integrity": "sha512-IJdWBbTcMQ6DA0gdNhh/BwrLkDR+ADW5Kr1aZmd4k3DIF6ezMV4R2NIAmT08wQJ3yUK82thHWmC/TnK/wpMMIA==",
					"optional": true,
					"requires": {
						"@smithy/is-array-buffer": "^2.2.0",
						"tslib": "^2.6.2"
					}
				},
				"@smithy/util-utf8": {
					"version": "2.3.0",
					"resolved": "https://registry.npmjs.org/@smithy/util-utf8/-/util-utf8-2.3.0.tgz",
					"integrity": "sha512-R8Rdn8Hy72KKcebgLiv8jQcQkXoLMOGGv5uI1/k0l+snqkOzQ1R0ChUBCxWMlBsFMekWjq0wRudIweFs7sKT5A==",
					"optional": true,
					"requires": {
						"@smithy/util-buffer-from": "^2.2.0",
						"tslib": "^2.6.2"
					}
				}
			}
		},
		"@aws-sdk/client-cognito-identity": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/client-cognito-identity/-/client-cognito-identity-3.758.0.tgz",
			"integrity": "sha512-8bOXVYtf/0OUN0jXTIHLv3V0TAS6kvvCRAy7nmiL/fDde0O+ChW1WZU7CVPAOtFEpFCdKskDcxFspM7m1k6qyg==",
			"optional": true,
			"requires": {
				"@aws-crypto/sha256-browser": "5.2.0",
				"@aws-crypto/sha256-js": "5.2.0",
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/credential-provider-node": "3.758.0",
				"@aws-sdk/middleware-host-header": "3.734.0",
				"@aws-sdk/middleware-logger": "3.734.0",
				"@aws-sdk/middleware-recursion-detection": "3.734.0",
				"@aws-sdk/middleware-user-agent": "3.758.0",
				"@aws-sdk/region-config-resolver": "3.734.0",
				"@aws-sdk/types": "3.734.0",
				"@aws-sdk/util-endpoints": "3.743.0",
				"@aws-sdk/util-user-agent-browser": "3.734.0",
				"@aws-sdk/util-user-agent-node": "3.758.0",
				"@smithy/config-resolver": "^4.0.1",
				"@smithy/core": "^3.1.5",
				"@smithy/fetch-http-handler": "^5.0.1",
				"@smithy/hash-node": "^4.0.1",
				"@smithy/invalid-dependency": "^4.0.1",
				"@smithy/middleware-content-length": "^4.0.1",
				"@smithy/middleware-endpoint": "^4.0.6",
				"@smithy/middleware-retry": "^4.0.7",
				"@smithy/middleware-serde": "^4.0.2",
				"@smithy/middleware-stack": "^4.0.1",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/node-http-handler": "^4.0.3",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"@smithy/url-parser": "^4.0.1",
				"@smithy/util-base64": "^4.0.0",
				"@smithy/util-body-length-browser": "^4.0.0",
				"@smithy/util-body-length-node": "^4.0.0",
				"@smithy/util-defaults-mode-browser": "^4.0.7",
				"@smithy/util-defaults-mode-node": "^4.0.7",
				"@smithy/util-endpoints": "^3.0.1",
				"@smithy/util-middleware": "^4.0.1",
				"@smithy/util-retry": "^4.0.1",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/client-sso": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/client-sso/-/client-sso-3.758.0.tgz",
			"integrity": "sha512-BoGO6IIWrLyLxQG6txJw6RT2urmbtlwfggapNCrNPyYjlXpzTSJhBYjndg7TpDATFd0SXL0zm8y/tXsUXNkdYQ==",
			"optional": true,
			"requires": {
				"@aws-crypto/sha256-browser": "5.2.0",
				"@aws-crypto/sha256-js": "5.2.0",
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/middleware-host-header": "3.734.0",
				"@aws-sdk/middleware-logger": "3.734.0",
				"@aws-sdk/middleware-recursion-detection": "3.734.0",
				"@aws-sdk/middleware-user-agent": "3.758.0",
				"@aws-sdk/region-config-resolver": "3.734.0",
				"@aws-sdk/types": "3.734.0",
				"@aws-sdk/util-endpoints": "3.743.0",
				"@aws-sdk/util-user-agent-browser": "3.734.0",
				"@aws-sdk/util-user-agent-node": "3.758.0",
				"@smithy/config-resolver": "^4.0.1",
				"@smithy/core": "^3.1.5",
				"@smithy/fetch-http-handler": "^5.0.1",
				"@smithy/hash-node": "^4.0.1",
				"@smithy/invalid-dependency": "^4.0.1",
				"@smithy/middleware-content-length": "^4.0.1",
				"@smithy/middleware-endpoint": "^4.0.6",
				"@smithy/middleware-retry": "^4.0.7",
				"@smithy/middleware-serde": "^4.0.2",
				"@smithy/middleware-stack": "^4.0.1",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/node-http-handler": "^4.0.3",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"@smithy/url-parser": "^4.0.1",
				"@smithy/util-base64": "^4.0.0",
				"@smithy/util-body-length-browser": "^4.0.0",
				"@smithy/util-body-length-node": "^4.0.0",
				"@smithy/util-defaults-mode-browser": "^4.0.7",
				"@smithy/util-defaults-mode-node": "^4.0.7",
				"@smithy/util-endpoints": "^3.0.1",
				"@smithy/util-middleware": "^4.0.1",
				"@smithy/util-retry": "^4.0.1",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/core": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/core/-/core-3.758.0.tgz",
			"integrity": "sha512-0RswbdR9jt/XKemaLNuxi2gGr4xGlHyGxkTdhSQzCyUe9A9OPCoLl3rIESRguQEech+oJnbHk/wuiwHqTuP9sg==",
			"optional": true,
			"requires": {
				"@aws-sdk/types": "3.734.0",
				"@smithy/core": "^3.1.5",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/signature-v4": "^5.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"@smithy/util-middleware": "^4.0.1",
				"fast-xml-parser": "4.4.1",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/credential-provider-cognito-identity": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-cognito-identity/-/credential-provider-cognito-identity-3.758.0.tgz",
			"integrity": "sha512-y/rHZqyChlEkNRr59gn4hv0gjhJwGmdCdW0JI1K9p3P9p7EurWGjr2M6+goTn3ilOlcAwrl5oFKR5jLt27TkOA==",
			"optional": true,
			"requires": {
				"@aws-sdk/client-cognito-identity": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/credential-provider-env": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-env/-/credential-provider-env-3.758.0.tgz",
			"integrity": "sha512-N27eFoRrO6MeUNumtNHDW9WOiwfd59LPXPqDrIa3kWL/s+fOKFHb9xIcF++bAwtcZnAxKkgpDCUP+INNZskE+w==",
			"optional": true,
			"requires": {
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/credential-provider-http": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-http/-/credential-provider-http-3.758.0.tgz",
			"integrity": "sha512-Xt9/U8qUCiw1hihztWkNeIR+arg6P+yda10OuCHX6kFVx3auTlU7+hCqs3UxqniGU4dguHuftf3mRpi5/GJ33Q==",
			"optional": true,
			"requires": {
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/fetch-http-handler": "^5.0.1",
				"@smithy/node-http-handler": "^4.0.3",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"@smithy/util-stream": "^4.1.2",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/credential-provider-ini": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-ini/-/credential-provider-ini-3.758.0.tgz",
			"integrity": "sha512-cymSKMcP5d+OsgetoIZ5QCe1wnp2Q/tq+uIxVdh9MbfdBBEnl9Ecq6dH6VlYS89sp4QKuxHxkWXVnbXU3Q19Aw==",
			"optional": true,
			"requires": {
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/credential-provider-env": "3.758.0",
				"@aws-sdk/credential-provider-http": "3.758.0",
				"@aws-sdk/credential-provider-process": "3.758.0",
				"@aws-sdk/credential-provider-sso": "3.758.0",
				"@aws-sdk/credential-provider-web-identity": "3.758.0",
				"@aws-sdk/nested-clients": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/credential-provider-imds": "^4.0.1",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/shared-ini-file-loader": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/credential-provider-node": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-node/-/credential-provider-node-3.758.0.tgz",
			"integrity": "sha512-+DaMv63wiq7pJrhIQzZYMn4hSarKiizDoJRvyR7WGhnn0oQ/getX9Z0VNCV3i7lIFoLNTb7WMmQ9k7+z/uD5EQ==",
			"optional": true,
			"requires": {
				"@aws-sdk/credential-provider-env": "3.758.0",
				"@aws-sdk/credential-provider-http": "3.758.0",
				"@aws-sdk/credential-provider-ini": "3.758.0",
				"@aws-sdk/credential-provider-process": "3.758.0",
				"@aws-sdk/credential-provider-sso": "3.758.0",
				"@aws-sdk/credential-provider-web-identity": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/credential-provider-imds": "^4.0.1",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/shared-ini-file-loader": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/credential-provider-process": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-process/-/credential-provider-process-3.758.0.tgz",
			"integrity": "sha512-AzcY74QTPqcbXWVgjpPZ3HOmxQZYPROIBz2YINF0OQk0MhezDWV/O7Xec+K1+MPGQO3qS6EDrUUlnPLjsqieHA==",
			"optional": true,
			"requires": {
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/shared-ini-file-loader": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/credential-provider-sso": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-sso/-/credential-provider-sso-3.758.0.tgz",
			"integrity": "sha512-x0FYJqcOLUCv8GLLFDYMXRAQKGjoM+L0BG4BiHYZRDf24yQWFCAZsCQAYKo6XZYh2qznbsW6f//qpyJ5b0QVKQ==",
			"optional": true,
			"requires": {
				"@aws-sdk/client-sso": "3.758.0",
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/token-providers": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/shared-ini-file-loader": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/credential-provider-web-identity": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-provider-web-identity/-/credential-provider-web-identity-3.758.0.tgz",
			"integrity": "sha512-XGguXhBqiCXMXRxcfCAVPlMbm3VyJTou79r/3mxWddHWF0XbhaQiBIbUz6vobVTD25YQRbWSmSch7VA8kI5Lrw==",
			"optional": true,
			"requires": {
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/nested-clients": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/credential-providers": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/credential-providers/-/credential-providers-3.758.0.tgz",
			"integrity": "sha512-BaGVBdm9ynsErIc/mLuUwJ1OQcL/pkhCuAm24jpsif3evZ5wgyZnEAZB2yRin+mQnQaQT3L+KvTbdKGfjL8+fQ==",
			"optional": true,
			"requires": {
				"@aws-sdk/client-cognito-identity": "3.758.0",
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/credential-provider-cognito-identity": "3.758.0",
				"@aws-sdk/credential-provider-env": "3.758.0",
				"@aws-sdk/credential-provider-http": "3.758.0",
				"@aws-sdk/credential-provider-ini": "3.758.0",
				"@aws-sdk/credential-provider-node": "3.758.0",
				"@aws-sdk/credential-provider-process": "3.758.0",
				"@aws-sdk/credential-provider-sso": "3.758.0",
				"@aws-sdk/credential-provider-web-identity": "3.758.0",
				"@aws-sdk/nested-clients": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/core": "^3.1.5",
				"@smithy/credential-provider-imds": "^4.0.1",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/middleware-host-header": {
			"version": "3.734.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/middleware-host-header/-/middleware-host-header-3.734.0.tgz",
			"integrity": "sha512-LW7RRgSOHHBzWZnigNsDIzu3AiwtjeI2X66v+Wn1P1u+eXssy1+up4ZY/h+t2sU4LU36UvEf+jrZti9c6vRnFw==",
			"optional": true,
			"requires": {
				"@aws-sdk/types": "3.734.0",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/middleware-logger": {
			"version": "3.734.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/middleware-logger/-/middleware-logger-3.734.0.tgz",
			"integrity": "sha512-mUMFITpJUW3LcKvFok176eI5zXAUomVtahb9IQBwLzkqFYOrMJvWAvoV4yuxrJ8TlQBG8gyEnkb9SnhZvjg67w==",
			"optional": true,
			"requires": {
				"@aws-sdk/types": "3.734.0",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/middleware-recursion-detection": {
			"version": "3.734.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/middleware-recursion-detection/-/middleware-recursion-detection-3.734.0.tgz",
			"integrity": "sha512-CUat2d9ITsFc2XsmeiRQO96iWpxSKYFjxvj27Hc7vo87YUHRnfMfnc8jw1EpxEwMcvBD7LsRa6vDNky6AjcrFA==",
			"optional": true,
			"requires": {
				"@aws-sdk/types": "3.734.0",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/middleware-user-agent": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/middleware-user-agent/-/middleware-user-agent-3.758.0.tgz",
			"integrity": "sha512-iNyehQXtQlj69JCgfaOssgZD4HeYGOwxcaKeG6F+40cwBjTAi0+Ph1yfDwqk2qiBPIRWJ/9l2LodZbxiBqgrwg==",
			"optional": true,
			"requires": {
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@aws-sdk/util-endpoints": "3.743.0",
				"@smithy/core": "^3.1.5",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/nested-clients": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/nested-clients/-/nested-clients-3.758.0.tgz",
			"integrity": "sha512-YZ5s7PSvyF3Mt2h1EQulCG93uybprNGbBkPmVuy/HMMfbFTt4iL3SbKjxqvOZelm86epFfj7pvK7FliI2WOEcg==",
			"optional": true,
			"requires": {
				"@aws-crypto/sha256-browser": "5.2.0",
				"@aws-crypto/sha256-js": "5.2.0",
				"@aws-sdk/core": "3.758.0",
				"@aws-sdk/middleware-host-header": "3.734.0",
				"@aws-sdk/middleware-logger": "3.734.0",
				"@aws-sdk/middleware-recursion-detection": "3.734.0",
				"@aws-sdk/middleware-user-agent": "3.758.0",
				"@aws-sdk/region-config-resolver": "3.734.0",
				"@aws-sdk/types": "3.734.0",
				"@aws-sdk/util-endpoints": "3.743.0",
				"@aws-sdk/util-user-agent-browser": "3.734.0",
				"@aws-sdk/util-user-agent-node": "3.758.0",
				"@smithy/config-resolver": "^4.0.1",
				"@smithy/core": "^3.1.5",
				"@smithy/fetch-http-handler": "^5.0.1",
				"@smithy/hash-node": "^4.0.1",
				"@smithy/invalid-dependency": "^4.0.1",
				"@smithy/middleware-content-length": "^4.0.1",
				"@smithy/middleware-endpoint": "^4.0.6",
				"@smithy/middleware-retry": "^4.0.7",
				"@smithy/middleware-serde": "^4.0.2",
				"@smithy/middleware-stack": "^4.0.1",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/node-http-handler": "^4.0.3",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"@smithy/url-parser": "^4.0.1",
				"@smithy/util-base64": "^4.0.0",
				"@smithy/util-body-length-browser": "^4.0.0",
				"@smithy/util-body-length-node": "^4.0.0",
				"@smithy/util-defaults-mode-browser": "^4.0.7",
				"@smithy/util-defaults-mode-node": "^4.0.7",
				"@smithy/util-endpoints": "^3.0.1",
				"@smithy/util-middleware": "^4.0.1",
				"@smithy/util-retry": "^4.0.1",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/region-config-resolver": {
			"version": "3.734.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/region-config-resolver/-/region-config-resolver-3.734.0.tgz",
			"integrity": "sha512-Lvj1kPRC5IuJBr9DyJ9T9/plkh+EfKLy+12s/mykOy1JaKHDpvj+XGy2YO6YgYVOb8JFtaqloid+5COtje4JTQ==",
			"optional": true,
			"requires": {
				"@aws-sdk/types": "3.734.0",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/util-config-provider": "^4.0.0",
				"@smithy/util-middleware": "^4.0.1",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/token-providers": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/token-providers/-/token-providers-3.758.0.tgz",
			"integrity": "sha512-ckptN1tNrIfQUaGWm/ayW1ddG+imbKN7HHhjFdS4VfItsP0QQOB0+Ov+tpgb4MoNR4JaUghMIVStjIeHN2ks1w==",
			"optional": true,
			"requires": {
				"@aws-sdk/nested-clients": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/shared-ini-file-loader": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/types": {
			"version": "3.734.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/types/-/types-3.734.0.tgz",
			"integrity": "sha512-o11tSPTT70nAkGV1fN9wm/hAIiLPyWX6SuGf+9JyTp7S/rC2cFWhR26MvA69nplcjNaXVzB0f+QFrLXXjOqCrg==",
			"optional": true,
			"requires": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/util-endpoints": {
			"version": "3.743.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/util-endpoints/-/util-endpoints-3.743.0.tgz",
			"integrity": "sha512-sN1l559zrixeh5x+pttrnd0A3+r34r0tmPkJ/eaaMaAzXqsmKU/xYre9K3FNnsSS1J1k4PEfk/nHDTVUgFYjnw==",
			"optional": true,
			"requires": {
				"@aws-sdk/types": "3.734.0",
				"@smithy/types": "^4.1.0",
				"@smithy/util-endpoints": "^3.0.1",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/util-locate-window": {
			"version": "3.723.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/util-locate-window/-/util-locate-window-3.723.0.tgz",
			"integrity": "sha512-Yf2CS10BqK688DRsrKI/EO6B8ff5J86NXe4C+VCysK7UOgN0l1zOTeTukZ3H8Q9tYYX3oaF1961o8vRkFm7Nmw==",
			"optional": true,
			"requires": {
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/util-user-agent-browser": {
			"version": "3.734.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/util-user-agent-browser/-/util-user-agent-browser-3.734.0.tgz",
			"integrity": "sha512-xQTCus6Q9LwUuALW+S76OL0jcWtMOVu14q+GoLnWPUM7QeUw963oQcLhF7oq0CtaLLKyl4GOUfcwc773Zmwwng==",
			"optional": true,
			"requires": {
				"@aws-sdk/types": "3.734.0",
				"@smithy/types": "^4.1.0",
				"bowser": "^2.11.0",
				"tslib": "^2.6.2"
			}
		},
		"@aws-sdk/util-user-agent-node": {
			"version": "3.758.0",
			"resolved": "https://registry.npmjs.org/@aws-sdk/util-user-agent-node/-/util-user-agent-node-3.758.0.tgz",
			"integrity": "sha512-A5EZw85V6WhoKMV2hbuFRvb9NPlxEErb4HPO6/SPXYY4QrjprIzScHxikqcWv1w4J3apB1wto9LPU3IMsYtfrw==",
			"optional": true,
			"requires": {
				"@aws-sdk/middleware-user-agent": "3.758.0",
				"@aws-sdk/types": "3.734.0",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@mapbox/node-pre-gyp": {
			"version": "1.0.9",
			"resolved": "https://registry.npmjs.org/@mapbox/node-pre-gyp/-/node-pre-gyp-1.0.9.tgz",
			"integrity": "sha512-aDF3S3rK9Q2gey/WAttUlISduDItz5BU3306M9Eyv6/oS40aMprnopshtlKTykxRNIBEZuRMaZAnbrQ4QtKGyw==",
			"requires": {
				"detect-libc": "^2.0.0",
				"https-proxy-agent": "^5.0.0",
				"make-dir": "^3.1.0",
				"node-fetch": "^2.6.7",
				"nopt": "^5.0.0",
				"npmlog": "^5.0.1",
				"rimraf": "^3.0.2",
				"semver": "^7.3.5",
				"tar": "^6.1.11"
			}
		},
		"@mongodb-js/saslprep": {
			"version": "1.2.0",
			"resolved": "https://registry.npmjs.org/@mongodb-js/saslprep/-/saslprep-1.2.0.tgz",
			"integrity": "sha512-+ywrb0AqkfaYuhHs6LxKWgqbh3I72EpEgESCw37o+9qPx9WTCkgDm2B+eMrwehGtHBWHFU4GXvnSCNiFhhausg==",
			"optional": true,
			"requires": {
				"sparse-bitfield": "^3.0.3"
			}
		},
		"@smithy/abort-controller": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/abort-controller/-/abort-controller-4.0.1.tgz",
			"integrity": "sha512-fiUIYgIgRjMWznk6iLJz35K2YxSLHzLBA/RC6lBrKfQ8fHbPfvk7Pk9UvpKoHgJjI18MnbPuEju53zcVy6KF1g==",
			"optional": true,
			"requires": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/config-resolver": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/config-resolver/-/config-resolver-4.0.1.tgz",
			"integrity": "sha512-Igfg8lKu3dRVkTSEm98QpZUvKEOa71jDX4vKRcvJVyRc3UgN3j7vFMf0s7xLQhYmKa8kyJGQgUJDOV5V3neVlQ==",
			"optional": true,
			"requires": {
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/util-config-provider": "^4.0.0",
				"@smithy/util-middleware": "^4.0.1",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/core": {
			"version": "3.1.5",
			"resolved": "https://registry.npmjs.org/@smithy/core/-/core-3.1.5.tgz",
			"integrity": "sha512-HLclGWPkCsekQgsyzxLhCQLa8THWXtB5PxyYN+2O6nkyLt550KQKTlbV2D1/j5dNIQapAZM1+qFnpBFxZQkgCA==",
			"optional": true,
			"requires": {
				"@smithy/middleware-serde": "^4.0.2",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/util-body-length-browser": "^4.0.0",
				"@smithy/util-middleware": "^4.0.1",
				"@smithy/util-stream": "^4.1.2",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/credential-provider-imds": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/credential-provider-imds/-/credential-provider-imds-4.0.1.tgz",
			"integrity": "sha512-l/qdInaDq1Zpznpmev/+52QomsJNZ3JkTl5yrTl02V6NBgJOQ4LY0SFw/8zsMwj3tLe8vqiIuwF6nxaEwgf6mg==",
			"optional": true,
			"requires": {
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/url-parser": "^4.0.1",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/fetch-http-handler": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/fetch-http-handler/-/fetch-http-handler-5.0.1.tgz",
			"integrity": "sha512-3aS+fP28urrMW2KTjb6z9iFow6jO8n3MFfineGbndvzGZit3taZhKWtTorf+Gp5RpFDDafeHlhfsGlDCXvUnJA==",
			"optional": true,
			"requires": {
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/querystring-builder": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/util-base64": "^4.0.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/hash-node": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/hash-node/-/hash-node-4.0.1.tgz",
			"integrity": "sha512-TJ6oZS+3r2Xu4emVse1YPB3Dq3d8RkZDKcPr71Nj/lJsdAP1c7oFzYqEn1IBc915TsgLl2xIJNuxCz+gLbLE0w==",
			"optional": true,
			"requires": {
				"@smithy/types": "^4.1.0",
				"@smithy/util-buffer-from": "^4.0.0",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/invalid-dependency": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/invalid-dependency/-/invalid-dependency-4.0.1.tgz",
			"integrity": "sha512-gdudFPf4QRQ5pzj7HEnu6FhKRi61BfH/Gk5Yf6O0KiSbr1LlVhgjThcvjdu658VE6Nve8vaIWB8/fodmS1rBPQ==",
			"optional": true,
			"requires": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/is-array-buffer": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/is-array-buffer/-/is-array-buffer-4.0.0.tgz",
			"integrity": "sha512-saYhF8ZZNoJDTvJBEWgeBccCg+yvp1CX+ed12yORU3NilJScfc6gfch2oVb4QgxZrGUx3/ZJlb+c/dJbyupxlw==",
			"optional": true,
			"requires": {
				"tslib": "^2.6.2"
			}
		},
		"@smithy/middleware-content-length": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/middleware-content-length/-/middleware-content-length-4.0.1.tgz",
			"integrity": "sha512-OGXo7w5EkB5pPiac7KNzVtfCW2vKBTZNuCctn++TTSOMpe6RZO/n6WEC1AxJINn3+vWLKW49uad3lo/u0WJ9oQ==",
			"optional": true,
			"requires": {
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/middleware-endpoint": {
			"version": "4.0.6",
			"resolved": "https://registry.npmjs.org/@smithy/middleware-endpoint/-/middleware-endpoint-4.0.6.tgz",
			"integrity": "sha512-ftpmkTHIFqgaFugcjzLZv3kzPEFsBFSnq1JsIkr2mwFzCraZVhQk2gqN51OOeRxqhbPTkRFj39Qd2V91E/mQxg==",
			"optional": true,
			"requires": {
				"@smithy/core": "^3.1.5",
				"@smithy/middleware-serde": "^4.0.2",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/shared-ini-file-loader": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/url-parser": "^4.0.1",
				"@smithy/util-middleware": "^4.0.1",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/middleware-retry": {
			"version": "4.0.7",
			"resolved": "https://registry.npmjs.org/@smithy/middleware-retry/-/middleware-retry-4.0.7.tgz",
			"integrity": "sha512-58j9XbUPLkqAcV1kHzVX/kAR16GT+j7DUZJqwzsxh1jtz7G82caZiGyyFgUvogVfNTg3TeAOIJepGc8TXF4AVQ==",
			"optional": true,
			"requires": {
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/service-error-classification": "^4.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"@smithy/util-middleware": "^4.0.1",
				"@smithy/util-retry": "^4.0.1",
				"tslib": "^2.6.2",
				"uuid": "^9.0.1"
			},
			"dependencies": {
				"uuid": {
					"version": "9.0.1",
					"resolved": "https://registry.npmjs.org/uuid/-/uuid-9.0.1.tgz",
					"integrity": "sha512-b+1eJOlsR9K8HJpow9Ok3fiWOWSIcIzXodvv0rQjVoOVNpWMpxf1wZNpt4y9h10odCNrqnYp1OBzRktckBe3sA==",
					"optional": true
				}
			}
		},
		"@smithy/middleware-serde": {
			"version": "4.0.2",
			"resolved": "https://registry.npmjs.org/@smithy/middleware-serde/-/middleware-serde-4.0.2.tgz",
			"integrity": "sha512-Sdr5lOagCn5tt+zKsaW+U2/iwr6bI9p08wOkCp6/eL6iMbgdtc2R5Ety66rf87PeohR0ExI84Txz9GYv5ou3iQ==",
			"optional": true,
			"requires": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/middleware-stack": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/middleware-stack/-/middleware-stack-4.0.1.tgz",
			"integrity": "sha512-dHwDmrtR/ln8UTHpaIavRSzeIk5+YZTBtLnKwDW3G2t6nAupCiQUvNzNoHBpik63fwUaJPtlnMzXbQrNFWssIA==",
			"optional": true,
			"requires": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/node-config-provider": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/node-config-provider/-/node-config-provider-4.0.1.tgz",
			"integrity": "sha512-8mRTjvCtVET8+rxvmzRNRR0hH2JjV0DFOmwXPrISmTIJEfnCBugpYYGAsCj8t41qd+RB5gbheSQ/6aKZCQvFLQ==",
			"optional": true,
			"requires": {
				"@smithy/property-provider": "^4.0.1",
				"@smithy/shared-ini-file-loader": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/node-http-handler": {
			"version": "4.0.3",
			"resolved": "https://registry.npmjs.org/@smithy/node-http-handler/-/node-http-handler-4.0.3.tgz",
			"integrity": "sha512-dYCLeINNbYdvmMLtW0VdhW1biXt+PPCGazzT5ZjKw46mOtdgToQEwjqZSS9/EN8+tNs/RO0cEWG044+YZs97aA==",
			"optional": true,
			"requires": {
				"@smithy/abort-controller": "^4.0.1",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/querystring-builder": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/property-provider": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/property-provider/-/property-provider-4.0.1.tgz",
			"integrity": "sha512-o+VRiwC2cgmk/WFV0jaETGOtX16VNPp2bSQEzu0whbReqE1BMqsP2ami2Vi3cbGVdKu1kq9gQkDAGKbt0WOHAQ==",
			"optional": true,
			"requires": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/protocol-http": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/protocol-http/-/protocol-http-5.0.1.tgz",
			"integrity": "sha512-TE4cpj49jJNB/oHyh/cRVEgNZaoPaxd4vteJNB0yGidOCVR0jCw/hjPVsT8Q8FRmj8Bd3bFZt8Dh7xGCT+xMBQ==",
			"optional": true,
			"requires": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/querystring-builder": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/querystring-builder/-/querystring-builder-4.0.1.tgz",
			"integrity": "sha512-wU87iWZoCbcqrwszsOewEIuq+SU2mSoBE2CcsLwE0I19m0B2gOJr1MVjxWcDQYOzHbR1xCk7AcOBbGFUYOKvdg==",
			"optional": true,
			"requires": {
				"@smithy/types": "^4.1.0",
				"@smithy/util-uri-escape": "^4.0.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/querystring-parser": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/querystring-parser/-/querystring-parser-4.0.1.tgz",
			"integrity": "sha512-Ma2XC7VS9aV77+clSFylVUnPZRindhB7BbmYiNOdr+CHt/kZNJoPP0cd3QxCnCFyPXC4eybmyE98phEHkqZ5Jw==",
			"optional": true,
			"requires": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/service-error-classification": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/service-error-classification/-/service-error-classification-4.0.1.tgz",
			"integrity": "sha512-3JNjBfOWpj/mYfjXJHB4Txc/7E4LVq32bwzE7m28GN79+M1f76XHflUaSUkhOriprPDzev9cX/M+dEB80DNDKA==",
			"optional": true,
			"requires": {
				"@smithy/types": "^4.1.0"
			}
		},
		"@smithy/shared-ini-file-loader": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/shared-ini-file-loader/-/shared-ini-file-loader-4.0.1.tgz",
			"integrity": "sha512-hC8F6qTBbuHRI/uqDgqqi6J0R4GtEZcgrZPhFQnMhfJs3MnUTGSnR1NSJCJs5VWlMydu0kJz15M640fJlRsIOw==",
			"optional": true,
			"requires": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/signature-v4": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/signature-v4/-/signature-v4-5.0.1.tgz",
			"integrity": "sha512-nCe6fQ+ppm1bQuw5iKoeJ0MJfz2os7Ic3GBjOkLOPtavbD1ONoyE3ygjBfz2ythFWm4YnRm6OxW+8p/m9uCoIA==",
			"optional": true,
			"requires": {
				"@smithy/is-array-buffer": "^4.0.0",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/util-hex-encoding": "^4.0.0",
				"@smithy/util-middleware": "^4.0.1",
				"@smithy/util-uri-escape": "^4.0.0",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/smithy-client": {
			"version": "4.1.6",
			"resolved": "https://registry.npmjs.org/@smithy/smithy-client/-/smithy-client-4.1.6.tgz",
			"integrity": "sha512-UYDolNg6h2O0L+cJjtgSyKKvEKCOa/8FHYJnBobyeoeWDmNpXjwOAtw16ezyeu1ETuuLEOZbrynK0ZY1Lx9Jbw==",
			"optional": true,
			"requires": {
				"@smithy/core": "^3.1.5",
				"@smithy/middleware-endpoint": "^4.0.6",
				"@smithy/middleware-stack": "^4.0.1",
				"@smithy/protocol-http": "^5.0.1",
				"@smithy/types": "^4.1.0",
				"@smithy/util-stream": "^4.1.2",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/types": {
			"version": "4.1.0",
			"resolved": "https://registry.npmjs.org/@smithy/types/-/types-4.1.0.tgz",
			"integrity": "sha512-enhjdwp4D7CXmwLtD6zbcDMbo6/T6WtuuKCY49Xxc6OMOmUWlBEBDREsxxgV2LIdeQPW756+f97GzcgAwp3iLw==",
			"optional": true,
			"requires": {
				"tslib": "^2.6.2"
			}
		},
		"@smithy/url-parser": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/url-parser/-/url-parser-4.0.1.tgz",
			"integrity": "sha512-gPXcIEUtw7VlK8f/QcruNXm7q+T5hhvGu9tl63LsJPZ27exB6dtNwvh2HIi0v7JcXJ5emBxB+CJxwaLEdJfA+g==",
			"optional": true,
			"requires": {
				"@smithy/querystring-parser": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/util-base64": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-base64/-/util-base64-4.0.0.tgz",
			"integrity": "sha512-CvHfCmO2mchox9kjrtzoHkWHxjHZzaFojLc8quxXY7WAAMAg43nuxwv95tATVgQFNDwd4M9S1qFzj40Ul41Kmg==",
			"optional": true,
			"requires": {
				"@smithy/util-buffer-from": "^4.0.0",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/util-body-length-browser": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-body-length-browser/-/util-body-length-browser-4.0.0.tgz",
			"integrity": "sha512-sNi3DL0/k64/LO3A256M+m3CDdG6V7WKWHdAiBBMUN8S3hK3aMPhwnPik2A/a2ONN+9doY9UxaLfgqsIRg69QA==",
			"optional": true,
			"requires": {
				"tslib": "^2.6.2"
			}
		},
		"@smithy/util-body-length-node": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-body-length-node/-/util-body-length-node-4.0.0.tgz",
			"integrity": "sha512-q0iDP3VsZzqJyje8xJWEJCNIu3lktUGVoSy1KB0UWym2CL1siV3artm+u1DFYTLejpsrdGyCSWBdGNjJzfDPjg==",
			"optional": true,
			"requires": {
				"tslib": "^2.6.2"
			}
		},
		"@smithy/util-buffer-from": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-buffer-from/-/util-buffer-from-4.0.0.tgz",
			"integrity": "sha512-9TOQ7781sZvddgO8nxueKi3+yGvkY35kotA0Y6BWRajAv8jjmigQ1sBwz0UX47pQMYXJPahSKEKYFgt+rXdcug==",
			"optional": true,
			"requires": {
				"@smithy/is-array-buffer": "^4.0.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/util-config-provider": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-config-provider/-/util-config-provider-4.0.0.tgz",
			"integrity": "sha512-L1RBVzLyfE8OXH+1hsJ8p+acNUSirQnWQ6/EgpchV88G6zGBTDPdXiiExei6Z1wR2RxYvxY/XLw6AMNCCt8H3w==",
			"optional": true,
			"requires": {
				"tslib": "^2.6.2"
			}
		},
		"@smithy/util-defaults-mode-browser": {
			"version": "4.0.7",
			"resolved": "https://registry.npmjs.org/@smithy/util-defaults-mode-browser/-/util-defaults-mode-browser-4.0.7.tgz",
			"integrity": "sha512-CZgDDrYHLv0RUElOsmZtAnp1pIjwDVCSuZWOPhIOBvG36RDfX1Q9+6lS61xBf+qqvHoqRjHxgINeQz47cYFC2Q==",
			"optional": true,
			"requires": {
				"@smithy/property-provider": "^4.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"bowser": "^2.11.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/util-defaults-mode-node": {
			"version": "4.0.7",
			"resolved": "https://registry.npmjs.org/@smithy/util-defaults-mode-node/-/util-defaults-mode-node-4.0.7.tgz",
			"integrity": "sha512-79fQW3hnfCdrfIi1soPbK3zmooRFnLpSx3Vxi6nUlqaaQeC5dm8plt4OTNDNqEEEDkvKghZSaoti684dQFVrGQ==",
			"optional": true,
			"requires": {
				"@smithy/config-resolver": "^4.0.1",
				"@smithy/credential-provider-imds": "^4.0.1",
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/property-provider": "^4.0.1",
				"@smithy/smithy-client": "^4.1.6",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/util-endpoints": {
			"version": "3.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/util-endpoints/-/util-endpoints-3.0.1.tgz",
			"integrity": "sha512-zVdUENQpdtn9jbpD9SCFK4+aSiavRb9BxEtw9ZGUR1TYo6bBHbIoi7VkrFQ0/RwZlzx0wRBaRmPclj8iAoJCLA==",
			"optional": true,
			"requires": {
				"@smithy/node-config-provider": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/util-hex-encoding": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-hex-encoding/-/util-hex-encoding-4.0.0.tgz",
			"integrity": "sha512-Yk5mLhHtfIgW2W2WQZWSg5kuMZCVbvhFmC7rV4IO2QqnZdbEFPmQnCcGMAX2z/8Qj3B9hYYNjZOhWym+RwhePw==",
			"optional": true,
			"requires": {
				"tslib": "^2.6.2"
			}
		},
		"@smithy/util-middleware": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/util-middleware/-/util-middleware-4.0.1.tgz",
			"integrity": "sha512-HiLAvlcqhbzhuiOa0Lyct5IIlyIz0PQO5dnMlmQ/ubYM46dPInB+3yQGkfxsk6Q24Y0n3/JmcA1v5iEhmOF5mA==",
			"optional": true,
			"requires": {
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/util-retry": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/@smithy/util-retry/-/util-retry-4.0.1.tgz",
			"integrity": "sha512-WmRHqNVwn3kI3rKk1LsKcVgPBG6iLTBGC1iYOV3GQegwJ3E8yjzHytPt26VNzOWr1qu0xE03nK0Ug8S7T7oufw==",
			"optional": true,
			"requires": {
				"@smithy/service-error-classification": "^4.0.1",
				"@smithy/types": "^4.1.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/util-stream": {
			"version": "4.1.2",
			"resolved": "https://registry.npmjs.org/@smithy/util-stream/-/util-stream-4.1.2.tgz",
			"integrity": "sha512-44PKEqQ303d3rlQuiDpcCcu//hV8sn+u2JBo84dWCE0rvgeiVl0IlLMagbU++o0jCWhYCsHaAt9wZuZqNe05Hw==",
			"optional": true,
			"requires": {
				"@smithy/fetch-http-handler": "^5.0.1",
				"@smithy/node-http-handler": "^4.0.3",
				"@smithy/types": "^4.1.0",
				"@smithy/util-base64": "^4.0.0",
				"@smithy/util-buffer-from": "^4.0.0",
				"@smithy/util-hex-encoding": "^4.0.0",
				"@smithy/util-utf8": "^4.0.0",
				"tslib": "^2.6.2"
			}
		},
		"@smithy/util-uri-escape": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-uri-escape/-/util-uri-escape-4.0.0.tgz",
			"integrity": "sha512-77yfbCbQMtgtTylO9itEAdpPXSog3ZxMe09AEhm0dU0NLTalV70ghDZFR+Nfi1C60jnJoh/Re4090/DuZh2Omg==",
			"optional": true,
			"requires": {
				"tslib": "^2.6.2"
			}
		},
		"@smithy/util-utf8": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/@smithy/util-utf8/-/util-utf8-4.0.0.tgz",
			"integrity": "sha512-b+zebfKCfRdgNJDknHCob3O7FpeYQN6ZG6YLExMcasDHsCXlsXCEuiPZeLnJLpwa5dvPetGlnGCiMHuLwGvFow==",
			"optional": true,
			"requires": {
				"@smithy/util-buffer-from": "^4.0.0",
				"tslib": "^2.6.2"
			}
		},
		"@socket.io/component-emitter": {
			"version": "3.1.2",
			"resolved": "https://registry.npmjs.org/@socket.io/component-emitter/-/component-emitter-3.1.2.tgz",
			"integrity": "sha512-9BCxFwvbGg/RsZK9tjXd8s4UcwR0MWeFQ1XEKIQVVvAGJyINdrqKMcTRyLoK8Rse1GjzLV9cwjWV1olXRWEXVA=="
		},
		"@types/bcrypt": {
			"version": "5.0.0",
			"resolved": "https://registry.npmjs.org/@types/bcrypt/-/bcrypt-5.0.0.tgz",
			"integrity": "sha512-agtcFKaruL8TmcvqbndlqHPSJgsolhf/qPWchFlgnW1gECTN/nKbFcoFnvKAQRFfKbh+BO6A3SWdJu9t+xF3Lw==",
			"dev": true,
			"requires": {
				"@types/node": "*"
			}
		},
		"@types/body-parser": {
			"version": "1.19.2",
			"resolved": "https://registry.npmjs.org/@types/body-parser/-/body-parser-1.19.2.tgz",
			"integrity": "sha512-ALYone6pm6QmwZoAgeyNksccT9Q4AWZQ6PvfwR37GT6r6FWUPguq6sUmNGSMV2Wr761oQoBxwGGa6DR5o1DC9g==",
			"dev": true,
			"requires": {
				"@types/connect": "*",
				"@types/node": "*"
			}
		},
		"@types/connect": {
			"version": "3.4.35",
			"resolved": "https://registry.npmjs.org/@types/connect/-/connect-3.4.35.tgz",
			"integrity": "sha512-cdeYyv4KWoEgpBISTxWvqYsVy444DOqehiF3fM3ne10AmJ62RSyNkUnxMJXHQWRQQX2eR94m5y1IZyDwBjV9FQ==",
			"dev": true,
			"requires": {
				"@types/node": "*"
			}
		},
		"@types/cors": {
			"version": "2.8.17",
			"resolved": "https://registry.npmjs.org/@types/cors/-/cors-2.8.17.tgz",
			"integrity": "sha512-8CGDvrBj1zgo2qE+oS3pOCyYNqCPryMWY2bGfwA0dcfopWGgxs+78df0Rs3rc9THP4JkOhLsAa+15VdpAqkcUA==",
			"requires": {
				"@types/node": "*"
			}
		},
		"@types/express": {
			"version": "4.17.13",
			"resolved": "https://registry.npmjs.org/@types/express/-/express-4.17.13.tgz",
			"integrity": "sha512-6bSZTPaTIACxn48l50SR+axgrqm6qXFIxrdAKaG6PaJk3+zuUr35hBlgT7vOmJcum+OEaIBLtHV/qloEAFITeA==",
			"dev": true,
			"requires": {
				"@types/body-parser": "*",
				"@types/express-serve-static-core": "^4.17.18",
				"@types/qs": "*",
				"@types/serve-static": "*"
			}
		},
		"@types/express-serve-static-core": {
			"version": "4.17.28",
			"resolved": "https://registry.npmjs.org/@types/express-serve-static-core/-/express-serve-static-core-4.17.28.tgz",
			"integrity": "sha512-P1BJAEAW3E2DJUlkgq4tOL3RyMunoWXqbSCygWo5ZIWTjUgN1YnaXWW4VWl/oc8vs/XoYibEGBKP0uZyF4AHig==",
			"dev": true,
			"requires": {
				"@types/node": "*",
				"@types/qs": "*",
				"@types/range-parser": "*"
			}
		},
		"@types/jsonwebtoken": {
			"version": "8.5.8",
			"resolved": "https://registry.npmjs.org/@types/jsonwebtoken/-/jsonwebtoken-8.5.8.tgz",
			"integrity": "sha512-zm6xBQpFDIDM6o9r6HSgDeIcLy82TKWctCXEPbJJcXb5AKmi5BNNdLXneixK4lplX3PqIVcwLBCGE/kAGnlD4A==",
			"dev": true,
			"requires": {
				"@types/node": "*"
			}
		},
		"@types/mime": {
			"version": "1.3.2",
			"resolved": "https://registry.npmjs.org/@types/mime/-/mime-1.3.2.tgz",
			"integrity": "sha512-YATxVxgRqNH6nHEIsvg6k2Boc1JHI9ZbH5iWFFv/MTkchz3b1ieGDa5T0a9RznNdI0KhVbdbWSN+KWWrQZRxTw==",
			"dev": true
		},
		"@types/node": {
			"version": "17.0.38",
			"resolved": "https://registry.npmjs.org/@types/node/-/node-17.0.38.tgz",
			"integrity": "sha512-5jY9RhV7c0Z4Jy09G+NIDTsCZ5G0L5n+Z+p+Y7t5VJHM30bgwzSjVtlcBxqAj+6L/swIlvtOSzr8rBk/aNyV2g=="
		},
		"@types/nodemon": {
			"version": "1.19.1",
			"resolved": "https://registry.npmjs.org/@types/nodemon/-/nodemon-1.19.1.tgz",
			"integrity": "sha512-3teAFqCFba3W9zk4dAGUZ+rW/nrQBrSGXWyK9HfJuWxmITk2z2d3u/5cy7oFqNG2fZxPwSAWkP+a8q/QC6UU5Q==",
			"dev": true,
			"requires": {
				"@types/node": "*"
			}
		},
		"@types/qs": {
			"version": "6.9.7",
			"resolved": "https://registry.npmjs.org/@types/qs/-/qs-6.9.7.tgz",
			"integrity": "sha512-FGa1F62FT09qcrueBA6qYTrJPVDzah9a+493+o2PCXsesWHIn27G98TsSMs3WPNbZIEj4+VJf6saSFpvD+3Zsw==",
			"dev": true
		},
		"@types/range-parser": {
			"version": "1.2.4",
			"resolved": "https://registry.npmjs.org/@types/range-parser/-/range-parser-1.2.4.tgz",
			"integrity": "sha512-EEhsLsD6UsDM1yFhAvy0Cjr6VwmpMWqFBCb9w07wVugF7w9nfajxLuVmngTIpgS6svCnm6Vaw+MZhoDCKnOfsw==",
			"dev": true
		},
		"@types/serve-static": {
			"version": "1.13.10",
			"resolved": "https://registry.npmjs.org/@types/serve-static/-/serve-static-1.13.10.tgz",
			"integrity": "sha512-nCkHGI4w7ZgAdNkrEu0bv+4xNV/XDqW+DydknebMOQwkpDGx8G+HTlj7R7ABI8i8nKxVw0wtKPi1D+lPOkh4YQ==",
			"dev": true,
			"requires": {
				"@types/mime": "^1",
				"@types/node": "*"
			}
		},
		"@types/uuid": {
			"version": "8.3.4",
			"resolved": "https://registry.npmjs.org/@types/uuid/-/uuid-8.3.4.tgz",
			"integrity": "sha512-c/I8ZRb51j+pYGAu5CrFMRxqZ2ke4y2grEBO5AUjgSkSk+qT2Ea+OdWElz/OiMf5MNpn2b17kuVBwZLQJXzihw==",
			"dev": true
		},
		"@types/webidl-conversions": {
			"version": "7.0.3",
			"resolved": "https://registry.npmjs.org/@types/webidl-conversions/-/webidl-conversions-7.0.3.tgz",
			"integrity": "sha512-CiJJvcRtIgzadHCYXw7dqEnMNRjhGZlYK05Mj9OyktqV8uVT8fD2BFOB7S1uwBE3Kj2Z+4UyPmFw/Ixgw/LAlA=="
		},
		"@types/whatwg-url": {
			"version": "8.2.2",
			"resolved": "https://registry.npmjs.org/@types/whatwg-url/-/whatwg-url-8.2.2.tgz",
			"integrity": "sha512-FtQu10RWgn3D9U4aazdwIE2yzphmTJREDqNdODHrbrZmmMqI0vMheC/6NE/J1Yveaj8H+ela+YwWTjq5PGmuhA==",
			"requires": {
				"@types/node": "*",
				"@types/webidl-conversions": "*"
			}
		},
		"abbrev": {
			"version": "1.1.1",
			"resolved": "https://registry.npmjs.org/abbrev/-/abbrev-1.1.1.tgz",
			"integrity": "sha512-nne9/IiQ/hzIhY6pdDnbBtz7DjPTKrY00P/zvPSm5pOFkl6xuGrGnXn/VtTNNfNtAfZ9/1RtehkszU9qcTii0Q=="
		},
		"accepts": {
			"version": "1.3.8",
			"resolved": "https://registry.npmjs.org/accepts/-/accepts-1.3.8.tgz",
			"integrity": "sha512-PYAthTa2m2VKxuvSD3DPC/Gy+U+sOA1LAuT8mkmRuvw+NACSaeXEQ+NHcVF7rONl6qcaxV3Uuemwawk+7+SJLw==",
			"requires": {
				"mime-types": "~2.1.34",
				"negotiator": "0.6.3"
			}
		},
		"agent-base": {
			"version": "6.0.2",
			"resolved": "https://registry.npmjs.org/agent-base/-/agent-base-6.0.2.tgz",
			"integrity": "sha512-RZNwNclF7+MS/8bDg70amg32dyeZGZxiDuQmZxKLAlQjr3jGyLx+4Kkk58UO7D2QdgFIQCovuSuZESne6RG6XQ==",
			"requires": {
				"debug": "4"
			},
			"dependencies": {
				"debug": {
					"version": "4.3.4",
					"resolved": "https://registry.npmjs.org/debug/-/debug-4.3.4.tgz",
					"integrity": "sha512-PRWFHuSU3eDtQJPvnNY7Jcket1j0t5OuOsFzPPzsekD52Zl8qUfFIPEiswXqIvHWGVHOgX+7G/vCNNhehwxfkQ==",
					"requires": {
						"ms": "2.1.2"
					}
				},
				"ms": {
					"version": "2.1.2",
					"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.2.tgz",
					"integrity": "sha512-sGkPx+VjMtmA6MX27oA4FBFELFCZZ4S4XqeGOXCv68tT+jb3vk/RyaKWP0PTKyWtmLSM0b+adUTEvbs1PEaH2w=="
				}
			}
		},
		"ansi-regex": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/ansi-regex/-/ansi-regex-5.0.1.tgz",
			"integrity": "sha512-quJQXlTSUGL2LH9SUXo8VwsY4soanhgo6LNSm84E1LBcE8s3O0wpdiRzyR9z/ZZJMlMWv37qOOb9pdJlMUEKFQ=="
		},
		"anymatch": {
			"version": "3.1.2",
			"resolved": "https://registry.npmjs.org/anymatch/-/anymatch-3.1.2.tgz",
			"integrity": "sha512-P43ePfOAIupkguHUycrc4qJ9kz8ZiuOUijaETwX7THt0Y/GNK7v0aa8rY816xWjZ7rJdA5XdMcpVFTKMq+RvWg==",
			"dev": true,
			"requires": {
				"normalize-path": "^3.0.0",
				"picomatch": "^2.0.4"
			}
		},
		"aproba": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/aproba/-/aproba-2.0.0.tgz",
			"integrity": "sha512-lYe4Gx7QT+MKGbDsA+Z+he/Wtef0BiwDOlK/XkBrdfsh9J/jPPXbX0tE9x9cl27Tmu5gg3QUbUrQYa/y+KOHPQ=="
		},
		"are-we-there-yet": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/are-we-there-yet/-/are-we-there-yet-2.0.0.tgz",
			"integrity": "sha512-Ci/qENmwHnsYo9xKIcUJN5LeDKdJ6R1Z1j9V/J5wyq8nh/mYPEpIKJbBZXtZjG04HiK7zV/p6Vs9952MrMeUIw==",
			"requires": {
				"delegates": "^1.0.0",
				"readable-stream": "^3.6.0"
			}
		},
		"array-flatten": {
			"version": "1.1.1",
			"resolved": "https://registry.npmjs.org/array-flatten/-/array-flatten-1.1.1.tgz",
			"integrity": "sha512-PCVAQswWemu6UdxsDFFX/+gVeYqKAod3D3UVm91jHwynguOwAvYPhx8nNlM++NqRcK6CxxpUafjmhIdKiHibqg=="
		},
		"balanced-match": {
			"version": "1.0.2",
			"resolved": "https://registry.npmjs.org/balanced-match/-/balanced-match-1.0.2.tgz",
			"integrity": "sha512-3oSeUO0TMV67hN1AmbXsK4yaqU7tjiHlbxRDZOpH0KW9+CeX4bRAaX0Anxt0tx2MrpRpWwQaPwIlISEJhYU5Pw=="
		},
		"base64-js": {
			"version": "1.5.1",
			"resolved": "https://registry.npmjs.org/base64-js/-/base64-js-1.5.1.tgz",
			"integrity": "sha512-AKpaYlHn8t4SVbOHCy+b5+KKgvR4vrsD8vbvrbiQJps7fKDTkjkDry6ji0rUJjC0kzbNePLwzxq8iypo41qeWA=="
		},
		"base64id": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/base64id/-/base64id-2.0.0.tgz",
			"integrity": "sha512-lGe34o6EHj9y3Kts9R4ZYs/Gr+6N7MCaMlIFA3F1R2O5/m7K06AxfSeO5530PEERE6/WyEg3lsuyw4GHlPZHog=="
		},
		"bcrypt": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/bcrypt/-/bcrypt-5.0.1.tgz",
			"integrity": "sha512-9BTgmrhZM2t1bNuDtrtIMVSmmxZBrJ71n8Wg+YgdjHuIWYF7SjjmCPZFB+/5i/o/PIeRpwVJR3P+NrpIItUjqw==",
			"requires": {
				"@mapbox/node-pre-gyp": "^1.0.0",
				"node-addon-api": "^3.1.0"
			}
		},
		"binary-extensions": {
			"version": "2.2.0",
			"resolved": "https://registry.npmjs.org/binary-extensions/-/binary-extensions-2.2.0.tgz",
			"integrity": "sha512-jDctJ/IVQbZoJykoeHbhXpOlNBqGNcwXJKJog42E5HDPUwQTSdjCHdihjj0DlnheQ7blbT6dHOafNAiS8ooQKA==",
			"dev": true
		},
		"body-parser": {
			"version": "1.20.3",
			"resolved": "https://registry.npmjs.org/body-parser/-/body-parser-1.20.3.tgz",
			"integrity": "sha512-7rAxByjUMqQ3/bHJy7D6OGXvx/MMc4IqBn/X0fcM1QUcAItpZrBEYhWGem+tzXH90c+G01ypMcYJBO9Y30203g==",
			"requires": {
				"bytes": "3.1.2",
				"content-type": "~1.0.5",
				"debug": "2.6.9",
				"depd": "2.0.0",
				"destroy": "1.2.0",
				"http-errors": "2.0.0",
				"iconv-lite": "0.4.24",
				"on-finished": "2.4.1",
				"qs": "6.13.0",
				"raw-body": "2.5.2",
				"type-is": "~1.6.18",
				"unpipe": "1.0.0"
			}
		},
		"bowser": {
			"version": "2.11.0",
			"resolved": "https://registry.npmjs.org/bowser/-/bowser-2.11.0.tgz",
			"integrity": "sha512-AlcaJBi/pqqJBIQ8U9Mcpc9i8Aqxn88Skv5d+xBX006BY5u8N3mGLHa5Lgppa7L/HfwgwLgZ6NYs+Ag6uUmJRA==",
			"optional": true
		},
		"brace-expansion": {
			"version": "1.1.11",
			"resolved": "https://registry.npmjs.org/brace-expansion/-/brace-expansion-1.1.11.tgz",
			"integrity": "sha512-iCuPHDFgrHX7H2vEI/5xpz07zSHB00TpugqhmYtVmMO6518mCuRMoOYFldEBl0g187ufozdaHgWKcYFb61qGiA==",
			"requires": {
				"balanced-match": "^1.0.0",
				"concat-map": "0.0.1"
			}
		},
		"braces": {
			"version": "3.0.3",
			"resolved": "https://registry.npmjs.org/braces/-/braces-3.0.3.tgz",
			"integrity": "sha512-yQbXgO/OSZVD2IsiLlro+7Hf6Q18EJrKSEsdoMzKePKXct3gvD8oLcOQdIzGupr5Fj+EDe8gO/lxc1BzfMpxvA==",
			"dev": true,
			"requires": {
				"fill-range": "^7.1.1"
			}
		},
		"bson": {
			"version": "4.7.2",
			"resolved": "https://registry.npmjs.org/bson/-/bson-4.7.2.tgz",
			"integrity": "sha512-Ry9wCtIZ5kGqkJoi6aD8KjxFZEx78guTQDnpXWiNthsxzrxAK/i8E6pCHAIZTbaEFWcOCvbecMukfK7XUvyLpQ==",
			"requires": {
				"buffer": "^5.6.0"
			}
		},
		"buffer": {
			"version": "5.7.1",
			"resolved": "https://registry.npmjs.org/buffer/-/buffer-5.7.1.tgz",
			"integrity": "sha512-EHcyIPBQ4BSGlvjB16k5KgAJ27CIsHY/2JBmCRReo48y9rQ3MaUzWX3KVlBa4U7MyX02HdVj0K7C3WaB3ju7FQ==",
			"requires": {
				"base64-js": "^1.3.1",
				"ieee754": "^1.1.13"
			}
		},
		"buffer-equal-constant-time": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/buffer-equal-constant-time/-/buffer-equal-constant-time-1.0.1.tgz",
			"integrity": "sha512-zRpUiDwd/xk6ADqPMATG8vc9VPrkck7T07OIx0gnjmJAnHnTVXNQG3vfvWNuiZIkwu9KrKdA1iJKfsfTVxE6NA=="
		},
		"bytes": {
			"version": "3.1.2",
			"resolved": "https://registry.npmjs.org/bytes/-/bytes-3.1.2.tgz",
			"integrity": "sha512-/Nf7TyzTx6S3yRJObOAV7956r8cr2+Oj8AC5dt8wSP3BQAoeX58NoHyCU8P8zGkNXStjTSi6fzO6F0pBdcYbEg=="
		},
		"call-bind-apply-helpers": {
			"version": "1.0.2",
			"resolved": "https://registry.npmjs.org/call-bind-apply-helpers/-/call-bind-apply-helpers-1.0.2.tgz",
			"integrity": "sha512-Sp1ablJ0ivDkSzjcaJdxEunN5/XvksFJ2sMBFfq6x0ryhQV/2b/KwFe21cMpmHtPOSij8K99/wSfoEuTObmuMQ==",
			"requires": {
				"es-errors": "^1.3.0",
				"function-bind": "^1.1.2"
			}
		},
		"call-bound": {
			"version": "1.0.4",
			"resolved": "https://registry.npmjs.org/call-bound/-/call-bound-1.0.4.tgz",
			"integrity": "sha512-+ys997U96po4Kx/ABpBCqhA9EuxJaQWDQg7295H4hBphv3IZg0boBKuwYpt4YXp6MZ5AmZQnU/tyMTlRpaSejg==",
			"requires": {
				"call-bind-apply-helpers": "^1.0.2",
				"get-intrinsic": "^1.3.0"
			}
		},
		"chokidar": {
			"version": "3.5.3",
			"resolved": "https://registry.npmjs.org/chokidar/-/chokidar-3.5.3.tgz",
			"integrity": "sha512-Dr3sfKRP6oTcjf2JmUmFJfeVMvXBdegxB0iVQ5eb2V10uFJUCAS8OByZdVAyVb8xXNz3GjjTgj9kLWsZTqE6kw==",
			"dev": true,
			"requires": {
				"anymatch": "~3.1.2",
				"braces": "~3.0.2",
				"fsevents": "~2.3.2",
				"glob-parent": "~5.1.2",
				"is-binary-path": "~2.1.0",
				"is-glob": "~4.0.1",
				"normalize-path": "~3.0.0",
				"readdirp": "~3.6.0"
			}
		},
		"chownr": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/chownr/-/chownr-2.0.0.tgz",
			"integrity": "sha512-bIomtDF5KGpdogkLd9VspvFzk9KfpyyGlS8YFVZl7TGPBHL5snIOnxeshwVgPteQ9b4Eydl+pVbIyE1DcvCWgQ=="
		},
		"color-support": {
			"version": "1.1.3",
			"resolved": "https://registry.npmjs.org/color-support/-/color-support-1.1.3.tgz",
			"integrity": "sha512-qiBjkpbMLO/HL68y+lh4q0/O1MZFj2RX6X/KmMa3+gJD3z+WwI1ZzDHysvqHGS3mP6mznPckpXmw1nI9cJjyRg=="
		},
		"concat-map": {
			"version": "0.0.1",
			"resolved": "https://registry.npmjs.org/concat-map/-/concat-map-0.0.1.tgz",
			"integrity": "sha512-/Srv4dswyQNBfohGpz9o6Yb3Gz3SrUDqBH5rTuhGR7ahtlbYKnVxw2bCFMRljaA7EXHaXZ8wsHdodFvbkhKmqg=="
		},
		"console-control-strings": {
			"version": "1.1.0",
			"resolved": "https://registry.npmjs.org/console-control-strings/-/console-control-strings-1.1.0.tgz",
			"integrity": "sha512-ty/fTekppD2fIwRvnZAVdeOiGd1c7YXEixbgJTNzqcxJWKQnjJ/V1bNEEE6hygpM3WjwHFUVK6HTjWSzV4a8sQ=="
		},
		"content-disposition": {
			"version": "0.5.4",
			"resolved": "https://registry.npmjs.org/content-disposition/-/content-disposition-0.5.4.tgz",
			"integrity": "sha512-FveZTNuGw04cxlAiWbzi6zTAL/lhehaWbTtgluJh4/E95DqMwTmha3KZN1aAWA8cFIhHzMZUvLevkw5Rqk+tSQ==",
			"requires": {
				"safe-buffer": "5.2.1"
			}
		},
		"content-type": {
			"version": "1.0.5",
			"resolved": "https://registry.npmjs.org/content-type/-/content-type-1.0.5.tgz",
			"integrity": "sha512-nTjqfcBFEipKdXCv4YDQWCfmcLZKm81ldF0pAopTvyrFGVbcR6P/VAAd5G7N+0tTr8QqiU0tFadD6FK4NtJwOA=="
		},
		"cookie": {
			"version": "0.7.1",
			"resolved": "https://registry.npmjs.org/cookie/-/cookie-0.7.1.tgz",
			"integrity": "sha512-6DnInpx7SJ2AK3+CTUE/ZM0vWTUboZCegxhC2xiIydHR9jNuTAASBrfEpHhiGOZw/nX51bHt6YQl8jsGo4y/0w=="
		},
		"cookie-signature": {
			"version": "1.0.6",
			"resolved": "https://registry.npmjs.org/cookie-signature/-/cookie-signature-1.0.6.tgz",
			"integrity": "sha512-QADzlaHc8icV8I7vbaJXJwod9HWYp8uCqf1xa4OfNu1T7JVxQIrUgOWtHdNDtPiywmFbiS12VjotIXLrKM3orQ=="
		},
		"cors": {
			"version": "2.8.5",
			"resolved": "https://registry.npmjs.org/cors/-/cors-2.8.5.tgz",
			"integrity": "sha512-KIHbLJqu73RGr/hnbrO9uBeixNGuvSQjul/jdFvS/KFSIH1hWVd1ng7zOHx+YrEfInLG7q4n6GHQ9cDtxv/P6g==",
			"requires": {
				"object-assign": "^4",
				"vary": "^1"
			}
		},
		"debug": {
			"version": "2.6.9",
			"resolved": "https://registry.npmjs.org/debug/-/debug-2.6.9.tgz",
			"integrity": "sha512-bC7ElrdJaJnPbAP+1EotYvqZsb3ecl5wi6Bfi6BJTUcNowp6cvspg0jXznRTKDjm/E7AdgFBVeAPVMNcKGsHMA==",
			"requires": {
				"ms": "2.0.0"
			}
		},
		"delegates": {
			"version": "1.0.0",
			"resolved": "https://registry.npmjs.org/delegates/-/delegates-1.0.0.tgz",
			"integrity": "sha512-bd2L678uiWATM6m5Z1VzNCErI3jiGzt6HGY8OVICs40JQq/HALfbyNJmp0UDakEY4pMMaN0Ly5om/B1VI/+xfQ=="
		},
		"depd": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/depd/-/depd-2.0.0.tgz",
			"integrity": "sha512-g7nH6P6dyDioJogAAGprGpCtVImJhpPk/roCzdb3fIh61/s/nPsfR6onyMwkCAR/OlC3yBC0lESvUoQEAssIrw=="
		},
		"destroy": {
			"version": "1.2.0",
			"resolved": "https://registry.npmjs.org/destroy/-/destroy-1.2.0.tgz",
			"integrity": "sha512-2sJGJTaXIIaR1w4iJSNoN0hnMY7Gpc/n8D4qSCJw8QqFWXf7cuAgnEHxBpweaVcPevC2l3KpjYCx3NypQQgaJg=="
		},
		"detect-libc": {
			"version": "2.0.1",
			"resolved": "https://registry.npmjs.org/detect-libc/-/detect-libc-2.0.1.tgz",
			"integrity": "sha512-463v3ZeIrcWtdgIg6vI6XUncguvr2TnGl4SzDXinkt9mSLpBJKXT3mW6xT3VQdDN11+WVs29pgvivTc4Lp8v+w=="
		},
		"dotenv": {
			"version": "16.0.1",
			"resolved": "https://registry.npmjs.org/dotenv/-/dotenv-16.0.1.tgz",
			"integrity": "sha512-1K6hR6wtk2FviQ4kEiSjFiH5rpzEVi8WW0x96aztHVMhEspNpc4DVOUTEHtEva5VThQ8IaBX1Pe4gSzpVVUsKQ=="
		},
		"dunder-proto": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/dunder-proto/-/dunder-proto-1.0.1.tgz",
			"integrity": "sha512-KIN/nDJBQRcXw0MLVhZE9iQHmG68qAVIBg9CqmUYjmQIhgij9U5MFvrqkUL5FbtyyzZuOeOt0zdeRe4UY7ct+A==",
			"requires": {
				"call-bind-apply-helpers": "^1.0.1",
				"es-errors": "^1.3.0",
				"gopd": "^1.2.0"
			}
		},
		"ecdsa-sig-formatter": {
			"version": "1.0.11",
			"resolved": "https://registry.npmjs.org/ecdsa-sig-formatter/-/ecdsa-sig-formatter-1.0.11.tgz",
			"integrity": "sha512-nagl3RYrbNv6kQkeJIpt6NJZy8twLB/2vtz6yN9Z4vRKHN4/QZJIEbqohALSgwKdnksuY3k5Addp5lg8sVoVcQ==",
			"requires": {
				"safe-buffer": "^5.0.1"
			}
		},
		"ee-first": {
			"version": "1.1.1",
			"resolved": "https://registry.npmjs.org/ee-first/-/ee-first-1.1.1.tgz",
			"integrity": "sha512-WMwm9LhRUo+WUaRN+vRuETqG89IgZphVSNkdFgeb6sS/E4OrDIN7t48CAewSHXc6C8lefD8KKfr5vY61brQlow=="
		},
		"emoji-regex": {
			"version": "8.0.0",
			"resolved": "https://registry.npmjs.org/emoji-regex/-/emoji-regex-8.0.0.tgz",
			"integrity": "sha512-MSjYzcWNOA0ewAHpz0MxpYFvwg6yjy1NG3xteoqz644VCo/RPgnr1/GGt+ic3iJTzQ8Eu3TdM14SawnVUmGE6A=="
		},
		"encodeurl": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/encodeurl/-/encodeurl-2.0.0.tgz",
			"integrity": "sha512-Q0n9HRi4m6JuGIV1eFlmvJB7ZEVxu93IrMyiMsGC0lrMJMWzRgx6WGquyfQgZVb31vhGgXnfmPNNXmxnOkRBrg=="
		},
		"engine.io": {
			"version": "6.6.4",
			"resolved": "https://registry.npmjs.org/engine.io/-/engine.io-6.6.4.tgz",
			"integrity": "sha512-ZCkIjSYNDyGn0R6ewHDtXgns/Zre/NT6Agvq1/WobF7JXgFff4SeDroKiCO3fNJreU9YG429Sc81o4w5ok/W5g==",
			"requires": {
				"@types/cors": "^2.8.12",
				"@types/node": ">=10.0.0",
				"accepts": "~1.3.4",
				"base64id": "2.0.0",
				"cookie": "~0.7.2",
				"cors": "~2.8.5",
				"debug": "~4.3.1",
				"engine.io-parser": "~5.2.1",
				"ws": "~8.17.1"
			},
			"dependencies": {
				"cookie": {
					"version": "0.7.2",
					"resolved": "https://registry.npmjs.org/cookie/-/cookie-0.7.2.tgz",
					"integrity": "sha512-yki5XnKuf750l50uGTllt6kKILY4nQ1eNIQatoXEByZ5dWgnKqbnqmTrBE5B4N7lrMJKQ2ytWMiTO2o0v6Ew/w=="
				},
				"debug": {
					"version": "4.3.7",
					"resolved": "https://registry.npmjs.org/debug/-/debug-4.3.7.tgz",
					"integrity": "sha512-Er2nc/H7RrMXZBFCEim6TCmMk02Z8vLC2Rbi1KEBggpo0fS6l0S1nnapwmIi3yW/+GOJap1Krg4w0Hg80oCqgQ==",
					"requires": {
						"ms": "^2.1.3"
					}
				},
				"ms": {
					"version": "2.1.3",
					"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
					"integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA=="
				}
			}
		},
		"engine.io-parser": {
			"version": "5.2.3",
			"resolved": "https://registry.npmjs.org/engine.io-parser/-/engine.io-parser-5.2.3.tgz",
			"integrity": "sha512-HqD3yTBfnBxIrbnM1DoD6Pcq8NECnh8d4As1Qgh0z5Gg3jRRIqijury0CL3ghu/edArpUYiYqQiDUQBIs4np3Q=="
		},
		"es-define-property": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/es-define-property/-/es-define-property-1.0.1.tgz",
			"integrity": "sha512-e3nRfgfUZ4rNGL232gUgX06QNyyez04KdjFrF+LTRoOXmrOgFKDg4BCdsjW8EnT69eqdYGmRpJwiPVYNrCaW3g=="
		},
		"es-errors": {
			"version": "1.3.0",
			"resolved": "https://registry.npmjs.org/es-errors/-/es-errors-1.3.0.tgz",
			"integrity": "sha512-Zf5H2Kxt2xjTvbJvP2ZWLEICxA6j+hAmMzIlypy4xcBg1vKVnx89Wy0GbS+kf5cwCVFFzdCFh2XSCFNULS6csw=="
		},
		"es-object-atoms": {
			"version": "1.1.1",
			"resolved": "https://registry.npmjs.org/es-object-atoms/-/es-object-atoms-1.1.1.tgz",
			"integrity": "sha512-FGgH2h8zKNim9ljj7dankFPcICIK9Cp5bm+c2gQSYePhpaG5+esrLODihIorn+Pe6FGJzWhXQotPv73jTaldXA==",
			"requires": {
				"es-errors": "^1.3.0"
			}
		},
		"escape-html": {
			"version": "1.0.3",
			"resolved": "https://registry.npmjs.org/escape-html/-/escape-html-1.0.3.tgz",
			"integrity": "sha512-NiSupZ4OeuGwr68lGIeym/ksIZMJodUGOSCZ/FSnTxcrekbvqrgdUxlJOMpijaKZVjAJrWrGs/6Jy8OMuyj9ow=="
		},
		"etag": {
			"version": "1.8.1",
			"resolved": "https://registry.npmjs.org/etag/-/etag-1.8.1.tgz",
			"integrity": "sha512-aIL5Fx7mawVa300al2BnEE4iNvo1qETxLrPI/o05L7z6go7fCw1J6EQmbK4FmJ2AS7kgVF/KEZWufBfdClMcPg=="
		},
		"express": {
			"version": "4.21.2",
			"resolved": "https://registry.npmjs.org/express/-/express-4.21.2.tgz",
			"integrity": "sha512-28HqgMZAmih1Czt9ny7qr6ek2qddF4FclbMzwhCREB6OFfH+rXAnuNCwo1/wFvrtbgsQDb4kSbX9de9lFbrXnA==",
			"requires": {
				"accepts": "~1.3.8",
				"array-flatten": "1.1.1",
				"body-parser": "1.20.3",
				"content-disposition": "0.5.4",
				"content-type": "~1.0.4",
				"cookie": "0.7.1",
				"cookie-signature": "1.0.6",
				"debug": "2.6.9",
				"depd": "2.0.0",
				"encodeurl": "~2.0.0",
				"escape-html": "~1.0.3",
				"etag": "~1.8.1",
				"finalhandler": "1.3.1",
				"fresh": "0.5.2",
				"http-errors": "2.0.0",
				"merge-descriptors": "1.0.3",
				"methods": "~1.1.2",
				"on-finished": "2.4.1",
				"parseurl": "~1.3.3",
				"path-to-regexp": "0.1.12",
				"proxy-addr": "~2.0.7",
				"qs": "6.13.0",
				"range-parser": "~1.2.1",
				"safe-buffer": "5.2.1",
				"send": "0.19.0",
				"serve-static": "1.16.2",
				"setprototypeof": "1.2.0",
				"statuses": "2.0.1",
				"type-is": "~1.6.18",
				"utils-merge": "1.0.1",
				"vary": "~1.1.2"
			}
		},
		"fast-xml-parser": {
			"version": "4.4.1",
			"resolved": "https://registry.npmjs.org/fast-xml-parser/-/fast-xml-parser-4.4.1.tgz",
			"integrity": "sha512-xkjOecfnKGkSsOwtZ5Pz7Us/T6mrbPQrq0nh+aCO5V9nk5NLWmasAHumTKjiPJPWANe+kAZ84Jc8ooJkzZ88Sw==",
			"optional": true,
			"requires": {
				"strnum": "^1.0.5"
			}
		},
		"fill-range": {
			"version": "7.1.1",
			"resolved": "https://registry.npmjs.org/fill-range/-/fill-range-7.1.1.tgz",
			"integrity": "sha512-YsGpe3WHLK8ZYi4tWDg2Jy3ebRz2rXowDxnld4bkQB00cc/1Zw9AWnC0i9ztDJitivtQvaI9KaLyKrc+hBW0yg==",
			"dev": true,
			"requires": {
				"to-regex-range": "^5.0.1"
			}
		},
		"finalhandler": {
			"version": "1.3.1",
			"resolved": "https://registry.npmjs.org/finalhandler/-/finalhandler-1.3.1.tgz",
			"integrity": "sha512-6BN9trH7bp3qvnrRyzsBz+g3lZxTNZTbVO2EV1CS0WIcDbawYVdYvGflME/9QP0h0pYlCDBCTjYa9nZzMDpyxQ==",
			"requires": {
				"debug": "2.6.9",
				"encodeurl": "~2.0.0",
				"escape-html": "~1.0.3",
				"on-finished": "2.4.1",
				"parseurl": "~1.3.3",
				"statuses": "2.0.1",
				"unpipe": "~1.0.0"
			}
		},
		"forwarded": {
			"version": "0.2.0",
			"resolved": "https://registry.npmjs.org/forwarded/-/forwarded-0.2.0.tgz",
			"integrity": "sha512-buRG0fpBtRHSTCOASe6hD258tEubFoRLb4ZNA6NxMVHNw2gOcwHo9wyablzMzOA5z9xA9L1KNjk/Nt6MT9aYow=="
		},
		"fresh": {
			"version": "0.5.2",
			"resolved": "https://registry.npmjs.org/fresh/-/fresh-0.5.2.tgz",
			"integrity": "sha512-zJ2mQYM18rEFOudeV4GShTGIQ7RbzA7ozbU9I/XBpm7kqgMywgmylMwXHxZJmkVoYkna9d2pVXVXPdYTP9ej8Q=="
		},
		"fs-minipass": {
			"version": "2.1.0",
			"resolved": "https://registry.npmjs.org/fs-minipass/-/fs-minipass-2.1.0.tgz",
			"integrity": "sha512-V/JgOLFCS+R6Vcq0slCuaeWEdNC3ouDlJMNIsacH2VtALiu9mV4LPrHc5cDl8k5aw6J8jwgWWpiTo5RYhmIzvg==",
			"requires": {
				"minipass": "^3.0.0"
			}
		},
		"fs.realpath": {
			"version": "1.0.0",
			"resolved": "https://registry.npmjs.org/fs.realpath/-/fs.realpath-1.0.0.tgz",
			"integrity": "sha512-OO0pH2lK6a0hZnAdau5ItzHPI6pUlvI7jMVnxUQRtw4owF2wk8lOSabtGDCTP4Ggrg2MbGnWO9X8K1t4+fGMDw=="
		},
		"fsevents": {
			"version": "2.3.2",
			"resolved": "https://registry.npmjs.org/fsevents/-/fsevents-2.3.2.tgz",
			"integrity": "sha512-xiqMQR4xAeHTuB9uWm+fFRcIOgKBMiOBP+eXiyT7jsgVCq1bkVygt00oASowB7EdtpOHaaPgKt812P9ab+DDKA==",
			"dev": true,
			"optional": true
		},
		"function-bind": {
			"version": "1.1.2",
			"resolved": "https://registry.npmjs.org/function-bind/-/function-bind-1.1.2.tgz",
			"integrity": "sha512-7XHNxH7qX9xG5mIwxkhumTox/MIRNcOgDrxWsMt2pAr23WHp6MrRlN7FBSFpCpr+oVO0F744iUgR82nJMfG2SA=="
		},
		"gauge": {
			"version": "3.0.2",
			"resolved": "https://registry.npmjs.org/gauge/-/gauge-3.0.2.tgz",
			"integrity": "sha512-+5J6MS/5XksCuXq++uFRsnUd7Ovu1XenbeuIuNRJxYWjgQbPuFhT14lAvsWfqfAmnwluf1OwMjz39HjfLPci0Q==",
			"requires": {
				"aproba": "^1.0.3 || ^2.0.0",
				"color-support": "^1.1.2",
				"console-control-strings": "^1.0.0",
				"has-unicode": "^2.0.1",
				"object-assign": "^4.1.1",
				"signal-exit": "^3.0.0",
				"string-width": "^4.2.3",
				"strip-ansi": "^6.0.1",
				"wide-align": "^1.1.2"
			}
		},
		"get-intrinsic": {
			"version": "1.3.0",
			"resolved": "https://registry.npmjs.org/get-intrinsic/-/get-intrinsic-1.3.0.tgz",
			"integrity": "sha512-9fSjSaos/fRIVIp+xSJlE6lfwhES7LNtKaCBIamHsjr2na1BiABJPo0mOjjz8GJDURarmCPGqaiVg5mfjb98CQ==",
			"requires": {
				"call-bind-apply-helpers": "^1.0.2",
				"es-define-property": "^1.0.1",
				"es-errors": "^1.3.0",
				"es-object-atoms": "^1.1.1",
				"function-bind": "^1.1.2",
				"get-proto": "^1.0.1",
				"gopd": "^1.2.0",
				"has-symbols": "^1.1.0",
				"hasown": "^2.0.2",
				"math-intrinsics": "^1.1.0"
			}
		},
		"get-proto": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/get-proto/-/get-proto-1.0.1.tgz",
			"integrity": "sha512-sTSfBjoXBp89JvIKIefqw7U2CCebsc74kiY6awiGogKtoSGbgjYE/G/+l9sF3MWFPNc9IcoOC4ODfKHfxFmp0g==",
			"requires": {
				"dunder-proto": "^1.0.1",
				"es-object-atoms": "^1.0.0"
			}
		},
		"glob": {
			"version": "7.2.3",
			"resolved": "https://registry.npmjs.org/glob/-/glob-7.2.3.tgz",
			"integrity": "sha512-nFR0zLpU2YCaRxwoCJvL6UvCH2JFyFVIvwTLsIf21AuHlMskA1hhTdk+LlYJtOlYt9v6dvszD2BGRqBL+iQK9Q==",
			"requires": {
				"fs.realpath": "^1.0.0",
				"inflight": "^1.0.4",
				"inherits": "2",
				"minimatch": "^3.1.1",
				"once": "^1.3.0",
				"path-is-absolute": "^1.0.0"
			}
		},
		"glob-parent": {
			"version": "5.1.2",
			"resolved": "https://registry.npmjs.org/glob-parent/-/glob-parent-5.1.2.tgz",
			"integrity": "sha512-AOIgSQCepiJYwP3ARnGx+5VnTu2HBYdzbGP45eLw1vr3zB3vZLeyed1sC9hnbcOc9/SrMyM5RPQrkGz4aS9Zow==",
			"dev": true,
			"requires": {
				"is-glob": "^4.0.1"
			}
		},
		"gopd": {
			"version": "1.2.0",
			"resolved": "https://registry.npmjs.org/gopd/-/gopd-1.2.0.tgz",
			"integrity": "sha512-ZUKRh6/kUFoAiTAtTYPZJ3hw9wNxx+BIBOijnlG9PnrJsCcSjs1wyyD6vJpaYtgnzDrKYRSqf3OO6Rfa93xsRg=="
		},
		"has-flag": {
			"version": "3.0.0",
			"resolved": "https://registry.npmjs.org/has-flag/-/has-flag-3.0.0.tgz",
			"integrity": "sha512-sKJf1+ceQBr4SMkvQnBDNDtf4TXpVhVGateu0t918bl30FnbE2m4vNLX+VWe/dpjlb+HugGYzW7uQXH98HPEYw==",
			"dev": true
		},
		"has-symbols": {
			"version": "1.1.0",
			"resolved": "https://registry.npmjs.org/has-symbols/-/has-symbols-1.1.0.tgz",
			"integrity": "sha512-1cDNdwJ2Jaohmb3sg4OmKaMBwuC48sYni5HUw2DvsC8LjGTLK9h+eb1X6RyuOHe4hT0ULCW68iomhjUoKUqlPQ=="
		},
		"has-unicode": {
			"version": "2.0.1",
			"resolved": "https://registry.npmjs.org/has-unicode/-/has-unicode-2.0.1.tgz",
			"integrity": "sha512-8Rf9Y83NBReMnx0gFzA8JImQACstCYWUplepDa9xprwwtmgEZUF0h/i5xSA625zB/I37EtrswSST6OXxwaaIJQ=="
		},
		"hasown": {
			"version": "2.0.2",
			"resolved": "https://registry.npmjs.org/hasown/-/hasown-2.0.2.tgz",
			"integrity": "sha512-0hJU9SCPvmMzIBdZFqNPXWa6dqh7WdH0cII9y+CyS8rG3nL48Bclra9HmKhVVUHyPWNH5Y7xDwAB7bfgSjkUMQ==",
			"requires": {
				"function-bind": "^1.1.2"
			}
		},
		"http-errors": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/http-errors/-/http-errors-2.0.0.tgz",
			"integrity": "sha512-FtwrG/euBzaEjYeRqOgly7G0qviiXoJWnvEH2Z1plBdXgbyjv34pHTSb9zoeHMyDy33+DWy5Wt9Wo+TURtOYSQ==",
			"requires": {
				"depd": "2.0.0",
				"inherits": "2.0.4",
				"setprototypeof": "1.2.0",
				"statuses": "2.0.1",
				"toidentifier": "1.0.1"
			}
		},
		"https-proxy-agent": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/https-proxy-agent/-/https-proxy-agent-5.0.1.tgz",
			"integrity": "sha512-dFcAjpTQFgoLMzC2VwU+C/CbS7uRL0lWmxDITmqm7C+7F0Odmj6s9l6alZc6AELXhrnggM2CeWSXHGOdX2YtwA==",
			"requires": {
				"agent-base": "6",
				"debug": "4"
			},
			"dependencies": {
				"debug": {
					"version": "4.3.4",
					"resolved": "https://registry.npmjs.org/debug/-/debug-4.3.4.tgz",
					"integrity": "sha512-PRWFHuSU3eDtQJPvnNY7Jcket1j0t5OuOsFzPPzsekD52Zl8qUfFIPEiswXqIvHWGVHOgX+7G/vCNNhehwxfkQ==",
					"requires": {
						"ms": "2.1.2"
					}
				},
				"ms": {
					"version": "2.1.2",
					"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.2.tgz",
					"integrity": "sha512-sGkPx+VjMtmA6MX27oA4FBFELFCZZ4S4XqeGOXCv68tT+jb3vk/RyaKWP0PTKyWtmLSM0b+adUTEvbs1PEaH2w=="
				}
			}
		},
		"iconv-lite": {
			"version": "0.4.24",
			"resolved": "https://registry.npmjs.org/iconv-lite/-/iconv-lite-0.4.24.tgz",
			"integrity": "sha512-v3MXnZAcvnywkTUEZomIActle7RXXeedOR31wwl7VlyoXO4Qi9arvSenNQWne1TcRwhCL1HwLI21bEqdpj8/rA==",
			"requires": {
				"safer-buffer": ">= 2.1.2 < 3"
			}
		},
		"ieee754": {
			"version": "1.2.1",
			"resolved": "https://registry.npmjs.org/ieee754/-/ieee754-1.2.1.tgz",
			"integrity": "sha512-dcyqhDvX1C46lXZcVqCpK+FtMRQVdIMN6/Df5js2zouUsqG7I6sFxitIC+7KYK29KdXOLHdu9zL4sFnoVQnqaA=="
		},
		"ignore-by-default": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/ignore-by-default/-/ignore-by-default-1.0.1.tgz",
			"integrity": "sha512-Ius2VYcGNk7T90CppJqcIkS5ooHUZyIQK+ClZfMfMNFEF9VSE73Fq+906u/CWu92x4gzZMWOwfFYckPObzdEbA==",
			"dev": true
		},
		"inflight": {
			"version": "1.0.6",
			"resolved": "https://registry.npmjs.org/inflight/-/inflight-1.0.6.tgz",
			"integrity": "sha512-k92I/b08q4wvFscXCLvqfsHCrjrF7yiXsQuIVvVE7N82W3+aqpzuUdBbfhWcy/FZR3/4IgflMgKLOsvPDrGCJA==",
			"requires": {
				"once": "^1.3.0",
				"wrappy": "1"
			}
		},
		"inherits": {
			"version": "2.0.4",
			"resolved": "https://registry.npmjs.org/inherits/-/inherits-2.0.4.tgz",
			"integrity": "sha512-k/vGaX4/Yla3WzyMCvTQOXYeIHvqOKtnqBduzTHpzpQZzAskKMhZ2K+EnBiSM9zGSoIFeMpXKxa4dYeZIQqewQ=="
		},
		"ip-address": {
			"version": "9.0.5",
			"resolved": "https://registry.npmjs.org/ip-address/-/ip-address-9.0.5.tgz",
			"integrity": "sha512-zHtQzGojZXTwZTHQqra+ETKd4Sn3vgi7uBmlPoXVWZqYvuKmtI0l/VZTjqGmJY9x88GGOaZ9+G9ES8hC4T4X8g==",
			"requires": {
				"jsbn": "1.1.0",
				"sprintf-js": "^1.1.3"
			}
		},
		"ipaddr.js": {
			"version": "1.9.1",
			"resolved": "https://registry.npmjs.org/ipaddr.js/-/ipaddr.js-1.9.1.tgz",
			"integrity": "sha512-0KI/607xoxSToH7GjN1FfSbLoU0+btTicjsQSWQlh/hZykN8KpmMf7uYwPW3R+akZ6R/w18ZlXSHBYXiYUPO3g=="
		},
		"is-binary-path": {
			"version": "2.1.0",
			"resolved": "https://registry.npmjs.org/is-binary-path/-/is-binary-path-2.1.0.tgz",
			"integrity": "sha512-ZMERYes6pDydyuGidse7OsHxtbI7WVeUEozgR/g7rd0xUimYNlvZRE/K2MgZTjWy725IfelLeVcEM97mmtRGXw==",
			"dev": true,
			"requires": {
				"binary-extensions": "^2.0.0"
			}
		},
		"is-extglob": {
			"version": "2.1.1",
			"resolved": "https://registry.npmjs.org/is-extglob/-/is-extglob-2.1.1.tgz",
			"integrity": "sha512-SbKbANkN603Vi4jEZv49LeVJMn4yGwsbzZworEoyEiutsN3nJYdbO36zfhGJ6QEDpOZIFkDtnq5JRxmvl3jsoQ==",
			"dev": true
		},
		"is-fullwidth-code-point": {
			"version": "3.0.0",
			"resolved": "https://registry.npmjs.org/is-fullwidth-code-point/-/is-fullwidth-code-point-3.0.0.tgz",
			"integrity": "sha512-zymm5+u+sCsSWyD9qNaejV3DFvhCKclKdizYaJUuHA83RLjb7nSuGnddCHGv0hk+KY7BMAlsWeK4Ueg6EV6XQg=="
		},
		"is-glob": {
			"version": "4.0.3",
			"resolved": "https://registry.npmjs.org/is-glob/-/is-glob-4.0.3.tgz",
			"integrity": "sha512-xelSayHH36ZgE7ZWhli7pW34hNbNl8Ojv5KVmkJD4hBdD3th8Tfk9vYasLM+mXWOZhFkgZfxhLSnrwRr4elSSg==",
			"dev": true,
			"requires": {
				"is-extglob": "^2.1.1"
			}
		},
		"is-number": {
			"version": "7.0.0",
			"resolved": "https://registry.npmjs.org/is-number/-/is-number-7.0.0.tgz",
			"integrity": "sha512-41Cifkg6e8TylSpdtTpeLVMqvSBEVzTttHvERD741+pnZ8ANv0004MRL43QKPDlK9cGvNp6NZWZUBlbGXYxxng==",
			"dev": true
		},
		"jsbn": {
			"version": "1.1.0",
			"resolved": "https://registry.npmjs.org/jsbn/-/jsbn-1.1.0.tgz",
			"integrity": "sha512-4bYVV3aAMtDTTu4+xsDYa6sy9GyJ69/amsu9sYF2zqjiEoZA5xJi3BrfX3uY+/IekIu7MwdObdbDWpoZdBv3/A=="
		},
		"jsonwebtoken": {
			"version": "9.0.2",
			"resolved": "https://registry.npmjs.org/jsonwebtoken/-/jsonwebtoken-9.0.2.tgz",
			"integrity": "sha512-PRp66vJ865SSqOlgqS8hujT5U4AOgMfhrwYIuIhfKaoSCZcirrmASQr8CX7cUg+RMih+hgznrjp99o+W4pJLHQ==",
			"requires": {
				"jws": "^3.2.2",
				"lodash.includes": "^4.3.0",
				"lodash.isboolean": "^3.0.3",
				"lodash.isinteger": "^4.0.4",
				"lodash.isnumber": "^3.0.3",
				"lodash.isplainobject": "^4.0.6",
				"lodash.isstring": "^4.0.1",
				"lodash.once": "^4.0.0",
				"ms": "^2.1.1",
				"semver": "^7.5.4"
			},
			"dependencies": {
				"ms": {
					"version": "2.1.3",
					"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
					"integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA=="
				}
			}
		},
		"jwa": {
			"version": "1.4.1",
			"resolved": "https://registry.npmjs.org/jwa/-/jwa-1.4.1.tgz",
			"integrity": "sha512-qiLX/xhEEFKUAJ6FiBMbes3w9ATzyk5W7Hvzpa/SLYdxNtng+gcurvrI7TbACjIXlsJyr05/S1oUhZrc63evQA==",
			"requires": {
				"buffer-equal-constant-time": "1.0.1",
				"ecdsa-sig-formatter": "1.0.11",
				"safe-buffer": "^5.0.1"
			}
		},
		"jws": {
			"version": "3.2.2",
			"resolved": "https://registry.npmjs.org/jws/-/jws-3.2.2.tgz",
			"integrity": "sha512-YHlZCB6lMTllWDtSPHz/ZXTsi8S00usEV6v1tjq8tOUZzw7DpSDWVXjXDre6ed1w/pd495ODpHZYSdkRTsa0HA==",
			"requires": {
				"jwa": "^1.4.1",
				"safe-buffer": "^5.0.1"
			}
		},
		"lodash.includes": {
			"version": "4.3.0",
			"resolved": "https://registry.npmjs.org/lodash.includes/-/lodash.includes-4.3.0.tgz",
			"integrity": "sha512-W3Bx6mdkRTGtlJISOvVD/lbqjTlPPUDTMnlXZFnVwi9NKJ6tiAk6LVdlhZMm17VZisqhKcgzpO5Wz91PCt5b0w=="
		},
		"lodash.isboolean": {
			"version": "3.0.3",
			"resolved": "https://registry.npmjs.org/lodash.isboolean/-/lodash.isboolean-3.0.3.tgz",
			"integrity": "sha512-Bz5mupy2SVbPHURB98VAcw+aHh4vRV5IPNhILUCsOzRmsTmSQ17jIuqopAentWoehktxGd9e/hbIXq980/1QJg=="
		},
		"lodash.isinteger": {
			"version": "4.0.4",
			"resolved": "https://registry.npmjs.org/lodash.isinteger/-/lodash.isinteger-4.0.4.tgz",
			"integrity": "sha512-DBwtEWN2caHQ9/imiNeEA5ys1JoRtRfY3d7V9wkqtbycnAmTvRRmbHKDV4a0EYc678/dia0jrte4tjYwVBaZUA=="
		},
		"lodash.isnumber": {
			"version": "3.0.3",
			"resolved": "https://registry.npmjs.org/lodash.isnumber/-/lodash.isnumber-3.0.3.tgz",
			"integrity": "sha512-QYqzpfwO3/CWf3XP+Z+tkQsfaLL/EnUlXWVkIk5FUPc4sBdTehEqZONuyRt2P67PXAk+NXmTBcc97zw9t1FQrw=="
		},
		"lodash.isplainobject": {
			"version": "4.0.6",
			"resolved": "https://registry.npmjs.org/lodash.isplainobject/-/lodash.isplainobject-4.0.6.tgz",
			"integrity": "sha512-oSXzaWypCMHkPC3NvBEaPHf0KsA5mvPrOPgQWDsbg8n7orZ290M0BmC/jgRZ4vcJ6DTAhjrsSYgdsW/F+MFOBA=="
		},
		"lodash.isstring": {
			"version": "4.0.1",
			"resolved": "https://registry.npmjs.org/lodash.isstring/-/lodash.isstring-4.0.1.tgz",
			"integrity": "sha512-0wJxfxH1wgO3GrbuP+dTTk7op+6L41QCXbGINEmD+ny/G/eCqGzxyCsh7159S+mgDDcoarnBw6PC1PS5+wUGgw=="
		},
		"lodash.once": {
			"version": "4.1.1",
			"resolved": "https://registry.npmjs.org/lodash.once/-/lodash.once-4.1.1.tgz",
			"integrity": "sha512-Sb487aTOCr9drQVL8pIxOzVhafOjZN9UU54hiN8PU3uAiSV7lx1yYNpbNmex2PK6dSJoNTSJUUswT651yww3Mg=="
		},
		"make-dir": {
			"version": "3.1.0",
			"resolved": "https://registry.npmjs.org/make-dir/-/make-dir-3.1.0.tgz",
			"integrity": "sha512-g3FeP20LNwhALb/6Cz6Dd4F2ngze0jz7tbzrD2wAV+o9FeNHe4rL+yK2md0J/fiSf1sa1ADhXqi5+oVwOM/eGw==",
			"requires": {
				"semver": "^6.0.0"
			},
			"dependencies": {
				"semver": {
					"version": "6.3.1",
					"resolved": "https://registry.npmjs.org/semver/-/semver-6.3.1.tgz",
					"integrity": "sha512-BR7VvDCVHO+q2xBEWskxS6DJE1qRnb7DxzUrogb71CWoSficBxYsiAGd+Kl0mmq/MprG9yArRkyrQxTO6XjMzA=="
				}
			}
		},
		"math-intrinsics": {
			"version": "1.1.0",
			"resolved": "https://registry.npmjs.org/math-intrinsics/-/math-intrinsics-1.1.0.tgz",
			"integrity": "sha512-/IXtbwEk5HTPyEwyKX6hGkYXxM9nbj64B+ilVJnC/R6B0pH5G4V3b0pVbL7DBj4tkhBAppbQUlf6F6Xl9LHu1g=="
		},
		"media-typer": {
			"version": "0.3.0",
			"resolved": "https://registry.npmjs.org/media-typer/-/media-typer-0.3.0.tgz",
			"integrity": "sha512-dq+qelQ9akHpcOl/gUVRTxVIOkAJ1wR3QAvb4RsVjS8oVoFjDGTc679wJYmUmknUF5HwMLOgb5O+a3KxfWapPQ=="
		},
		"memory-pager": {
			"version": "1.5.0",
			"resolved": "https://registry.npmjs.org/memory-pager/-/memory-pager-1.5.0.tgz",
			"integrity": "sha512-ZS4Bp4r/Zoeq6+NLJpP+0Zzm0pR8whtGPf1XExKLJBAczGMnSi3It14OiNCStjQjM6NU1okjQGSxgEZN8eBYKg==",
			"optional": true
		},
		"merge-descriptors": {
			"version": "1.0.3",
			"resolved": "https://registry.npmjs.org/merge-descriptors/-/merge-descriptors-1.0.3.tgz",
			"integrity": "sha512-gaNvAS7TZ897/rVaZ0nMtAyxNyi/pdbjbAwUpFQpN70GqnVfOiXpeUUMKRBmzXaSQ8DdTX4/0ms62r2K+hE6mQ=="
		},
		"methods": {
			"version": "1.1.2",
			"resolved": "https://registry.npmjs.org/methods/-/methods-1.1.2.tgz",
			"integrity": "sha512-iclAHeNqNm68zFtnZ0e+1L2yUIdvzNoauKU4WBA3VvH/vPFieF7qfRlwUZU+DA9P9bPXIS90ulxoUoCH23sV2w=="
		},
		"mime": {
			"version": "1.6.0",
			"resolved": "https://registry.npmjs.org/mime/-/mime-1.6.0.tgz",
			"integrity": "sha512-x0Vn8spI+wuJ1O6S7gnbaQg8Pxh4NNHb7KSINmEWKiPE4RKOplvijn+NkmYmmRgP68mc70j2EbeTFRsrswaQeg=="
		},
		"mime-db": {
			"version": "1.52.0",
			"resolved": "https://registry.npmjs.org/mime-db/-/mime-db-1.52.0.tgz",
			"integrity": "sha512-sPU4uV7dYlvtWJxwwxHD0PuihVNiE7TyAbQ5SWxDCB9mUYvOgroQOwYQQOKPJ8CIbE+1ETVlOoK1UC2nU3gYvg=="
		},
		"mime-types": {
			"version": "2.1.35",
			"resolved": "https://registry.npmjs.org/mime-types/-/mime-types-2.1.35.tgz",
			"integrity": "sha512-ZDY+bPm5zTTF+YpCrAU9nK0UgICYPT0QtT1NZWFv4s++TNkcgVaT0g6+4R2uI4MjQjzysHB1zxuWL50hzaeXiw==",
			"requires": {
				"mime-db": "1.52.0"
			}
		},
		"minimatch": {
			"version": "3.1.2",
			"resolved": "https://registry.npmjs.org/minimatch/-/minimatch-3.1.2.tgz",
			"integrity": "sha512-J7p63hRiAjw1NDEww1W7i37+ByIrOWO5XQQAzZ3VOcL0PNybwpfmV/N05zFAzwQ9USyEcX6t3UO+K5aqBQOIHw==",
			"requires": {
				"brace-expansion": "^1.1.7"
			}
		},
		"minipass": {
			"version": "3.1.6",
			"resolved": "https://registry.npmjs.org/minipass/-/minipass-3.1.6.tgz",
			"integrity": "sha512-rty5kpw9/z8SX9dmxblFA6edItUmwJgMeYDZRrwlIVN27i8gysGbznJwUggw2V/FVqFSDdWy040ZPS811DYAqQ==",
			"requires": {
				"yallist": "^4.0.0"
			}
		},
		"minizlib": {
			"version": "2.1.2",
			"resolved": "https://registry.npmjs.org/minizlib/-/minizlib-2.1.2.tgz",
			"integrity": "sha512-bAxsR8BVfj60DWXHE3u30oHzfl4G7khkSuPW+qvpd7jFRHm7dLxOjUk1EHACJ/hxLY8phGJ0YhYHZo7jil7Qdg==",
			"requires": {
				"minipass": "^3.0.0",
				"yallist": "^4.0.0"
			}
		},
		"mkdirp": {
			"version": "1.0.4",
			"resolved": "https://registry.npmjs.org/mkdirp/-/mkdirp-1.0.4.tgz",
			"integrity": "sha512-vVqVZQyf3WLx2Shd0qJ9xuvqgAyKPLAiqITEtqW0oIUjzo3PePDd6fW9iFz30ef7Ysp/oiWqbhszeGWW2T6Gzw=="
		},
		"mongodb": {
			"version": "4.17.2",
			"resolved": "https://registry.npmjs.org/mongodb/-/mongodb-4.17.2.tgz",
			"integrity": "sha512-mLV7SEiov2LHleRJPMPrK2PMyhXFZt2UQLC4VD4pnth3jMjYKHhtqfwwkkvS/NXuo/Fp3vbhaNcXrIDaLRb9Tg==",
			"requires": {
				"@aws-sdk/credential-providers": "^3.186.0",
				"@mongodb-js/saslprep": "^1.1.0",
				"bson": "^4.7.2",
				"mongodb-connection-string-url": "^2.6.0",
				"socks": "^2.7.1"
			}
		},
		"mongodb-connection-string-url": {
			"version": "2.6.0",
			"resolved": "https://registry.npmjs.org/mongodb-connection-string-url/-/mongodb-connection-string-url-2.6.0.tgz",
			"integrity": "sha512-WvTZlI9ab0QYtTYnuMLgobULWhokRjtC7db9LtcVfJ+Hsnyr5eo6ZtNAt3Ly24XZScGMelOcGtm7lSn0332tPQ==",
			"requires": {
				"@types/whatwg-url": "^8.2.1",
				"whatwg-url": "^11.0.0"
			}
		},
		"ms": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/ms/-/ms-2.0.0.tgz",
			"integrity": "sha512-Tpp60P6IUJDTuOq/5Z8cdskzJujfwqfOTkrwIwj7IRISpnkJnT6SyJ4PCPnGMoFjC9ddhal5KVIYtAt97ix05A=="
		},
		"negotiator": {
			"version": "0.6.3",
			"resolved": "https://registry.npmjs.org/negotiator/-/negotiator-0.6.3.tgz",
			"integrity": "sha512-+EUsqGPLsM+j/zdChZjsnX51g4XrHFOIXwfnCVPGlQk/k5giakcKsuxCObBRu6DSm9opw/O6slWbJdghQM4bBg=="
		},
		"node-addon-api": {
			"version": "3.2.1",
			"resolved": "https://registry.npmjs.org/node-addon-api/-/node-addon-api-3.2.1.tgz",
			"integrity": "sha512-mmcei9JghVNDYydghQmeDX8KoAm0FAiYyIcUt/N4nhyAipB17pllZQDOJD2fotxABnt4Mdz+dKTO7eftLg4d0A=="
		},
		"node-fetch": {
			"version": "2.6.7",
			"resolved": "https://registry.npmjs.org/node-fetch/-/node-fetch-2.6.7.tgz",
			"integrity": "sha512-ZjMPFEfVx5j+y2yF35Kzx5sF7kDzxuDj6ziH4FFbOp87zKDZNx8yExJIb05OGF4Nlt9IHFIMBkRl41VdvcNdbQ==",
			"requires": {
				"whatwg-url": "^5.0.0"
			},
			"dependencies": {
				"tr46": {
					"version": "0.0.3",
					"resolved": "https://registry.npmjs.org/tr46/-/tr46-0.0.3.tgz",
					"integrity": "sha1-gYT9NH2snNwYWZLzpmIuFLnZq2o="
				},
				"webidl-conversions": {
					"version": "3.0.1",
					"resolved": "https://registry.npmjs.org/webidl-conversions/-/webidl-conversions-3.0.1.tgz",
					"integrity": "sha1-JFNCdeKnvGvnvIZhHMFq4KVlSHE="
				},
				"whatwg-url": {
					"version": "5.0.0",
					"resolved": "https://registry.npmjs.org/whatwg-url/-/whatwg-url-5.0.0.tgz",
					"integrity": "sha1-lmRU6HZUYuN2RNNib2dCzotwll0=",
					"requires": {
						"tr46": "~0.0.3",
						"webidl-conversions": "^3.0.0"
					}
				}
			}
		},
		"nodemon": {
			"version": "3.1.9",
			"resolved": "https://registry.npmjs.org/nodemon/-/nodemon-3.1.9.tgz",
			"integrity": "sha512-hdr1oIb2p6ZSxu3PB2JWWYS7ZQ0qvaZsc3hK8DR8f02kRzc8rjYmxAIvdz+aYC+8F2IjNaB7HMcSDg8nQpJxyg==",
			"dev": true,
			"requires": {
				"chokidar": "^3.5.2",
				"debug": "^4",
				"ignore-by-default": "^1.0.1",
				"minimatch": "^3.1.2",
				"pstree.remy": "^1.1.8",
				"semver": "^7.5.3",
				"simple-update-notifier": "^2.0.0",
				"supports-color": "^5.5.0",
				"touch": "^3.1.0",
				"undefsafe": "^2.0.5"
			},
			"dependencies": {
				"debug": {
					"version": "4.4.0",
					"resolved": "https://registry.npmjs.org/debug/-/debug-4.4.0.tgz",
					"integrity": "sha512-6WTZ/IxCY/T6BALoZHaE4ctp9xm+Z5kY/pzYaCHRFeyVhojxlrm+46y68HA6hr0TcwEssoxNiDEUJQjfPZ/RYA==",
					"dev": true,
					"requires": {
						"ms": "^2.1.3"
					}
				},
				"ms": {
					"version": "2.1.3",
					"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
					"integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA==",
					"dev": true
				}
			}
		},
		"nopt": {
			"version": "5.0.0",
			"resolved": "https://registry.npmjs.org/nopt/-/nopt-5.0.0.tgz",
			"integrity": "sha512-Tbj67rffqceeLpcRXrT7vKAN8CwfPeIBgM7E6iBkmKLV7bEMwpGgYLGv0jACUsECaa/vuxP0IjEont6umdMgtQ==",
			"requires": {
				"abbrev": "1"
			}
		},
		"normalize-path": {
			"version": "3.0.0",
			"resolved": "https://registry.npmjs.org/normalize-path/-/normalize-path-3.0.0.tgz",
			"integrity": "sha512-6eZs5Ls3WtCisHWp9S2GUy8dqkpGi4BVSz3GaqiE6ezub0512ESztXUwUB6C6IKbQkY2Pnb/mD4WYojCRwcwLA==",
			"dev": true
		},
		"npmlog": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/npmlog/-/npmlog-5.0.1.tgz",
			"integrity": "sha512-AqZtDUWOMKs1G/8lwylVjrdYgqA4d9nu8hc+0gzRxlDb1I10+FHBGMXs6aiQHFdCUUlqH99MUMuLfzWDNDtfxw==",
			"requires": {
				"are-we-there-yet": "^2.0.0",
				"console-control-strings": "^1.1.0",
				"gauge": "^3.0.0",
				"set-blocking": "^2.0.0"
			}
		},
		"object-assign": {
			"version": "4.1.1",
			"resolved": "https://registry.npmjs.org/object-assign/-/object-assign-4.1.1.tgz",
			"integrity": "sha512-rJgTQnkUnH1sFw8yT6VSU3zD3sWmu6sZhIseY8VX+GRu3P6F7Fu+JNDoXfklElbLJSnc3FUQHVe4cU5hj+BcUg=="
		},
		"object-inspect": {
			"version": "1.13.4",
			"resolved": "https://registry.npmjs.org/object-inspect/-/object-inspect-1.13.4.tgz",
			"integrity": "sha512-W67iLl4J2EXEGTbfeHCffrjDfitvLANg0UlX3wFUUSTx92KXRFegMHUVgSqE+wvhAbi4WqjGg9czysTV2Epbew=="
		},
		"on-finished": {
			"version": "2.4.1",
			"resolved": "https://registry.npmjs.org/on-finished/-/on-finished-2.4.1.tgz",
			"integrity": "sha512-oVlzkg3ENAhCk2zdv7IJwd/QUD4z2RxRwpkcGY8psCVcCYZNq4wYnVWALHM+brtuJjePWiYF/ClmuDr8Ch5+kg==",
			"requires": {
				"ee-first": "1.1.1"
			}
		},
		"once": {
			"version": "1.4.0",
			"resolved": "https://registry.npmjs.org/once/-/once-1.4.0.tgz",
			"integrity": "sha512-lNaJgI+2Q5URQBkccEKHTQOPaXdUxnZZElQTZY0MFUAuaEqe1E+Nyvgdz/aIyNi6Z9MzO5dv1H8n58/GELp3+w==",
			"requires": {
				"wrappy": "1"
			}
		},
		"parseurl": {
			"version": "1.3.3",
			"resolved": "https://registry.npmjs.org/parseurl/-/parseurl-1.3.3.tgz",
			"integrity": "sha512-CiyeOxFT/JZyN5m0z9PfXw4SCBJ6Sygz1Dpl0wqjlhDEGGBP1GnsUVEL0p63hoG1fcj3fHynXi9NYO4nWOL+qQ=="
		},
		"path-is-absolute": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/path-is-absolute/-/path-is-absolute-1.0.1.tgz",
			"integrity": "sha512-AVbw3UJ2e9bq64vSaS9Am0fje1Pa8pbGqTTsmXfaIiMpnr5DlDhfJOuLj9Sf95ZPVDAUerDfEk88MPmPe7UCQg=="
		},
		"path-to-regexp": {
			"version": "0.1.12",
			"resolved": "https://registry.npmjs.org/path-to-regexp/-/path-to-regexp-0.1.12.tgz",
			"integrity": "sha512-RA1GjUVMnvYFxuqovrEqZoxxW5NUZqbwKtYz/Tt7nXerk0LbLblQmrsgdeOxV5SFHf0UDggjS/bSeOZwt1pmEQ=="
		},
		"picomatch": {
			"version": "2.3.1",
			"resolved": "https://registry.npmjs.org/picomatch/-/picomatch-2.3.1.tgz",
			"integrity": "sha512-JU3teHTNjmE2VCGFzuY8EXzCDVwEqB2a8fsIvwaStHhAWJEeVd1o1QD80CU6+ZdEXXSLbSsuLwJjkCBWqRQUVA==",
			"dev": true
		},
		"proxy-addr": {
			"version": "2.0.7",
			"resolved": "https://registry.npmjs.org/proxy-addr/-/proxy-addr-2.0.7.tgz",
			"integrity": "sha512-llQsMLSUDUPT44jdrU/O37qlnifitDP+ZwrmmZcoSKyLKvtZxpyV0n2/bD/N4tBAAZ/gJEdZU7KMraoK1+XYAg==",
			"requires": {
				"forwarded": "0.2.0",
				"ipaddr.js": "1.9.1"
			}
		},
		"pstree.remy": {
			"version": "1.1.8",
			"resolved": "https://registry.npmjs.org/pstree.remy/-/pstree.remy-1.1.8.tgz",
			"integrity": "sha512-77DZwxQmxKnu3aR542U+X8FypNzbfJ+C5XQDk3uWjWxn6151aIMGthWYRXTqT1E5oJvg+ljaa2OJi+VfvCOQ8w==",
			"dev": true
		},
		"punycode": {
			"version": "2.3.1",
			"resolved": "https://registry.npmjs.org/punycode/-/punycode-2.3.1.tgz",
			"integrity": "sha512-vYt7UD1U9Wg6138shLtLOvdAu+8DsC/ilFtEVHcH+wydcSpNE20AfSOduf6MkRFahL5FY7X1oU7nKVZFtfq8Fg=="
		},
		"qs": {
			"version": "6.13.0",
			"resolved": "https://registry.npmjs.org/qs/-/qs-6.13.0.tgz",
			"integrity": "sha512-+38qI9SOr8tfZ4QmJNplMUxqjbe7LKvvZgWdExBOmd+egZTtjLB67Gu0HRX3u/XOq7UU2Nx6nsjvS16Z9uwfpg==",
			"requires": {
				"side-channel": "^1.0.6"
			}
		},
		"range-parser": {
			"version": "1.2.1",
			"resolved": "https://registry.npmjs.org/range-parser/-/range-parser-1.2.1.tgz",
			"integrity": "sha512-Hrgsx+orqoygnmhFbKaHE6c296J+HTAQXoxEF6gNupROmmGJRoyzfG3ccAveqCBrwr/2yxQ5BVd/GTl5agOwSg=="
		},
		"raw-body": {
			"version": "2.5.2",
			"resolved": "https://registry.npmjs.org/raw-body/-/raw-body-2.5.2.tgz",
			"integrity": "sha512-8zGqypfENjCIqGhgXToC8aB2r7YrBX+AQAfIPs/Mlk+BtPTztOvTS01NRW/3Eh60J+a48lt8qsCzirQ6loCVfA==",
			"requires": {
				"bytes": "3.1.2",
				"http-errors": "2.0.0",
				"iconv-lite": "0.4.24",
				"unpipe": "1.0.0"
			}
		},
		"readable-stream": {
			"version": "3.6.0",
			"resolved": "https://registry.npmjs.org/readable-stream/-/readable-stream-3.6.0.tgz",
			"integrity": "sha512-BViHy7LKeTz4oNnkcLJ+lVSL6vpiFeX6/d3oSH8zCW7UxP2onchk+vTGB143xuFjHS3deTgkKoXXymXqymiIdA==",
			"requires": {
				"inherits": "^2.0.3",
				"string_decoder": "^1.1.1",
				"util-deprecate": "^1.0.1"
			}
		},
		"readdirp": {
			"version": "3.6.0",
			"resolved": "https://registry.npmjs.org/readdirp/-/readdirp-3.6.0.tgz",
			"integrity": "sha512-hOS089on8RduqdbhvQ5Z37A0ESjsqz6qnRcffsMU3495FuTdqSm+7bhJ29JvIOsBDEEnan5DPu9t3To9VRlMzA==",
			"dev": true,
			"requires": {
				"picomatch": "^2.2.1"
			}
		},
		"rimraf": {
			"version": "3.0.2",
			"resolved": "https://registry.npmjs.org/rimraf/-/rimraf-3.0.2.tgz",
			"integrity": "sha512-JZkJMZkAGFFPP2YqXZXPbMlMBgsxzE8ILs4lMIX/2o0L9UBw9O/Y3o6wFw/i9YLapcUJWwqbi3kdxIPdC62TIA==",
			"requires": {
				"glob": "^7.1.3"
			}
		},
		"safe-buffer": {
			"version": "5.2.1",
			"resolved": "https://registry.npmjs.org/safe-buffer/-/safe-buffer-5.2.1.tgz",
			"integrity": "sha512-rp3So07KcdmmKbGvgaNxQSJr7bGVSVk5S9Eq1F+ppbRo70+YeaDxkw5Dd8NPN+GD6bjnYm2VuPuCXmpuYvmCXQ=="
		},
		"safer-buffer": {
			"version": "2.1.2",
			"resolved": "https://registry.npmjs.org/safer-buffer/-/safer-buffer-2.1.2.tgz",
			"integrity": "sha512-YZo3K82SD7Riyi0E1EQPojLz7kpepnSQI9IyPbHHg1XXXevb5dJI7tpyN2ADxGcQbHG7vcyRHk0cbwqcQriUtg=="
		},
		"semver": {
			"version": "7.7.1",
			"resolved": "https://registry.npmjs.org/semver/-/semver-7.7.1.tgz",
			"integrity": "sha512-hlq8tAfn0m/61p4BVRcPzIGr6LKiMwo4VM6dGi6pt4qcRkmNzTcWq6eCEjEh+qXjkMDvPlOFFSGwQjoEa6gyMA=="
		},
		"send": {
			"version": "0.19.0",
			"resolved": "https://registry.npmjs.org/send/-/send-0.19.0.tgz",
			"integrity": "sha512-dW41u5VfLXu8SJh5bwRmyYUbAoSB3c9uQh6L8h/KtsFREPWpbX1lrljJo186Jc4nmci/sGUZ9a0a0J2zgfq2hw==",
			"requires": {
				"debug": "2.6.9",
				"depd": "2.0.0",
				"destroy": "1.2.0",
				"encodeurl": "~1.0.2",
				"escape-html": "~1.0.3",
				"etag": "~1.8.1",
				"fresh": "0.5.2",
				"http-errors": "2.0.0",
				"mime": "1.6.0",
				"ms": "2.1.3",
				"on-finished": "2.4.1",
				"range-parser": "~1.2.1",
				"statuses": "2.0.1"
			},
			"dependencies": {
				"encodeurl": {
					"version": "1.0.2",
					"resolved": "https://registry.npmjs.org/encodeurl/-/encodeurl-1.0.2.tgz",
					"integrity": "sha512-TPJXq8JqFaVYm2CWmPvnP2Iyo4ZSM7/QKcSmuMLDObfpH5fi7RUGmd/rTDf+rut/saiDiQEeVTNgAmJEdAOx0w=="
				},
				"ms": {
					"version": "2.1.3",
					"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
					"integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA=="
				}
			}
		},
		"serve-static": {
			"version": "1.16.2",
			"resolved": "https://registry.npmjs.org/serve-static/-/serve-static-1.16.2.tgz",
			"integrity": "sha512-VqpjJZKadQB/PEbEwvFdO43Ax5dFBZ2UECszz8bQ7pi7wt//PWe1P6MN7eCnjsatYtBT6EuiClbjSWP2WrIoTw==",
			"requires": {
				"encodeurl": "~2.0.0",
				"escape-html": "~1.0.3",
				"parseurl": "~1.3.3",
				"send": "0.19.0"
			}
		},
		"set-blocking": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/set-blocking/-/set-blocking-2.0.0.tgz",
			"integrity": "sha1-BF+XgtARrppoA93TgrJDkrPYkPc="
		},
		"setprototypeof": {
			"version": "1.2.0",
			"resolved": "https://registry.npmjs.org/setprototypeof/-/setprototypeof-1.2.0.tgz",
			"integrity": "sha512-E5LDX7Wrp85Kil5bhZv46j8jOeboKq5JMmYM3gVGdGH8xFpPWXUMsNrlODCrkoxMEeNi/XZIwuRvY4XNwYMJpw=="
		},
		"side-channel": {
			"version": "1.1.0",
			"resolved": "https://registry.npmjs.org/side-channel/-/side-channel-1.1.0.tgz",
			"integrity": "sha512-ZX99e6tRweoUXqR+VBrslhda51Nh5MTQwou5tnUDgbtyM0dBgmhEDtWGP/xbKn6hqfPRHujUNwz5fy/wbbhnpw==",
			"requires": {
				"es-errors": "^1.3.0",
				"object-inspect": "^1.13.3",
				"side-channel-list": "^1.0.0",
				"side-channel-map": "^1.0.1",
				"side-channel-weakmap": "^1.0.2"
			}
		},
		"side-channel-list": {
			"version": "1.0.0",
			"resolved": "https://registry.npmjs.org/side-channel-list/-/side-channel-list-1.0.0.tgz",
			"integrity": "sha512-FCLHtRD/gnpCiCHEiJLOwdmFP+wzCmDEkc9y7NsYxeF4u7Btsn1ZuwgwJGxImImHicJArLP4R0yX4c2KCrMrTA==",
			"requires": {
				"es-errors": "^1.3.0",
				"object-inspect": "^1.13.3"
			}
		},
		"side-channel-map": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/side-channel-map/-/side-channel-map-1.0.1.tgz",
			"integrity": "sha512-VCjCNfgMsby3tTdo02nbjtM/ewra6jPHmpThenkTYh8pG9ucZ/1P8So4u4FGBek/BjpOVsDCMoLA/iuBKIFXRA==",
			"requires": {
				"call-bound": "^1.0.2",
				"es-errors": "^1.3.0",
				"get-intrinsic": "^1.2.5",
				"object-inspect": "^1.13.3"
			}
		},
		"side-channel-weakmap": {
			"version": "1.0.2",
			"resolved": "https://registry.npmjs.org/side-channel-weakmap/-/side-channel-weakmap-1.0.2.tgz",
			"integrity": "sha512-WPS/HvHQTYnHisLo9McqBHOJk2FkHO/tlpvldyrnem4aeQp4hai3gythswg6p01oSoTl58rcpiFAjF2br2Ak2A==",
			"requires": {
				"call-bound": "^1.0.2",
				"es-errors": "^1.3.0",
				"get-intrinsic": "^1.2.5",
				"object-inspect": "^1.13.3",
				"side-channel-map": "^1.0.1"
			}
		},
		"signal-exit": {
			"version": "3.0.7",
			"resolved": "https://registry.npmjs.org/signal-exit/-/signal-exit-3.0.7.tgz",
			"integrity": "sha512-wnD2ZE+l+SPC/uoS0vXeE9L1+0wuaMqKlfz9AMUo38JsyLSBWSFcHR1Rri62LZc12vLr1gb3jl7iwQhgwpAbGQ=="
		},
		"simple-update-notifier": {
			"version": "2.0.0",
			"resolved": "https://registry.npmjs.org/simple-update-notifier/-/simple-update-notifier-2.0.0.tgz",
			"integrity": "sha512-a2B9Y0KlNXl9u/vsW6sTIu9vGEpfKu2wRV6l1H3XEas/0gUIzGzBoP/IouTcUQbm9JWZLH3COxyn03TYlFax6w==",
			"dev": true,
			"requires": {
				"semver": "^7.5.3"
			}
		},
		"smart-buffer": {
			"version": "4.2.0",
			"resolved": "https://registry.npmjs.org/smart-buffer/-/smart-buffer-4.2.0.tgz",
			"integrity": "sha512-94hK0Hh8rPqQl2xXc3HsaBoOXKV20MToPkcXvwbISWLEs+64sBq5kFgn2kJDHb1Pry9yrP0dxrCI9RRci7RXKg=="
		},
		"socket.io": {
			"version": "4.8.1",
			"resolved": "https://registry.npmjs.org/socket.io/-/socket.io-4.8.1.tgz",
			"integrity": "sha512-oZ7iUCxph8WYRHHcjBEc9unw3adt5CmSNlppj/5Q4k2RIrhl8Z5yY2Xr4j9zj0+wzVZ0bxmYoGSzKJnRl6A4yg==",
			"requires": {
				"accepts": "~1.3.4",
				"base64id": "~2.0.0",
				"cors": "~2.8.5",
				"debug": "~4.3.2",
				"engine.io": "~6.6.0",
				"socket.io-adapter": "~2.5.2",
				"socket.io-parser": "~4.2.4"
			},
			"dependencies": {
				"debug": {
					"version": "4.3.4",
					"resolved": "https://registry.npmjs.org/debug/-/debug-4.3.4.tgz",
					"integrity": "sha512-PRWFHuSU3eDtQJPvnNY7Jcket1j0t5OuOsFzPPzsekD52Zl8qUfFIPEiswXqIvHWGVHOgX+7G/vCNNhehwxfkQ==",
					"requires": {
						"ms": "2.1.2"
					}
				},
				"ms": {
					"version": "2.1.2",
					"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.2.tgz",
					"integrity": "sha512-sGkPx+VjMtmA6MX27oA4FBFELFCZZ4S4XqeGOXCv68tT+jb3vk/RyaKWP0PTKyWtmLSM0b+adUTEvbs1PEaH2w=="
				}
			}
		},
		"socket.io-adapter": {
			"version": "2.5.5",
			"resolved": "https://registry.npmjs.org/socket.io-adapter/-/socket.io-adapter-2.5.5.tgz",
			"integrity": "sha512-eLDQas5dzPgOWCk9GuuJC2lBqItuhKI4uxGgo9aIV7MYbk2h9Q6uULEh8WBzThoI7l+qU9Ast9fVUmkqPP9wYg==",
			"requires": {
				"debug": "~4.3.4",
				"ws": "~8.17.1"
			},
			"dependencies": {
				"debug": {
					"version": "4.3.7",
					"resolved": "https://registry.npmjs.org/debug/-/debug-4.3.7.tgz",
					"integrity": "sha512-Er2nc/H7RrMXZBFCEim6TCmMk02Z8vLC2Rbi1KEBggpo0fS6l0S1nnapwmIi3yW/+GOJap1Krg4w0Hg80oCqgQ==",
					"requires": {
						"ms": "^2.1.3"
					}
				},
				"ms": {
					"version": "2.1.3",
					"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
					"integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA=="
				}
			}
		},
		"socket.io-parser": {
			"version": "4.2.4",
			"resolved": "https://registry.npmjs.org/socket.io-parser/-/socket.io-parser-4.2.4.tgz",
			"integrity": "sha512-/GbIKmo8ioc+NIWIhwdecY0ge+qVBSMdgxGygevmdHj24bsfgtCmcUUcQ5ZzcylGFHsN3k4HB4Cgkl96KVnuew==",
			"requires": {
				"@socket.io/component-emitter": "~3.1.0",
				"debug": "~4.3.1"
			},
			"dependencies": {
				"debug": {
					"version": "4.3.7",
					"resolved": "https://registry.npmjs.org/debug/-/debug-4.3.7.tgz",
					"integrity": "sha512-Er2nc/H7RrMXZBFCEim6TCmMk02Z8vLC2Rbi1KEBggpo0fS6l0S1nnapwmIi3yW/+GOJap1Krg4w0Hg80oCqgQ==",
					"requires": {
						"ms": "^2.1.3"
					}
				},
				"ms": {
					"version": "2.1.3",
					"resolved": "https://registry.npmjs.org/ms/-/ms-2.1.3.tgz",
					"integrity": "sha512-6FlzubTLZG3J2a/NVCAleEhjzq5oxgHyaCU9yYXvcLsvoVaHJq/s5xXI6/XXP6tz7R9xAOtHnSO/tXtF3WRTlA=="
				}
			}
		},
		"socks": {
			"version": "2.8.4",
			"resolved": "https://registry.npmjs.org/socks/-/socks-2.8.4.tgz",
			"integrity": "sha512-D3YaD0aRxR3mEcqnidIs7ReYJFVzWdd6fXJYUM8ixcQcJRGTka/b3saV0KflYhyVJXKhb947GndU35SxYNResQ==",
			"requires": {
				"ip-address": "^9.0.5",
				"smart-buffer": "^4.2.0"
			}
		},
		"sparse-bitfield": {
			"version": "3.0.3",
			"resolved": "https://registry.npmjs.org/sparse-bitfield/-/sparse-bitfield-3.0.3.tgz",
			"integrity": "sha512-kvzhi7vqKTfkh0PZU+2D2PIllw2ymqJKujUcyPMd9Y75Nv4nPbGJZXNhxsgdQab2BmlDct1YnfQCguEvHr7VsQ==",
			"optional": true,
			"requires": {
				"memory-pager": "^1.0.2"
			}
		},
		"sprintf-js": {
			"version": "1.1.3",
			"resolved": "https://registry.npmjs.org/sprintf-js/-/sprintf-js-1.1.3.tgz",
			"integrity": "sha512-Oo+0REFV59/rz3gfJNKQiBlwfHaSESl1pcGyABQsnnIfWOFt6JNj5gCog2U6MLZ//IGYD+nA8nI+mTShREReaA=="
		},
		"statuses": {
			"version": "2.0.1",
			"resolved": "https://registry.npmjs.org/statuses/-/statuses-2.0.1.tgz",
			"integrity": "sha512-RwNA9Z/7PrK06rYLIzFMlaF+l73iwpzsqRIFgbMLbTcLD6cOao82TaWefPXQvB2fOC4AjuYSEndS7N/mTCbkdQ=="
		},
		"string_decoder": {
			"version": "1.3.0",
			"resolved": "https://registry.npmjs.org/string_decoder/-/string_decoder-1.3.0.tgz",
			"integrity": "sha512-hkRX8U1WjJFd8LsDJ2yQ/wWWxaopEsABU1XfkM8A+j0+85JAGppt16cr1Whg6KIbb4okU6Mql6BOj+uup/wKeA==",
			"requires": {
				"safe-buffer": "~5.2.0"
			}
		},
		"string-width": {
			"version": "4.2.3",
			"resolved": "https://registry.npmjs.org/string-width/-/string-width-4.2.3.tgz",
			"integrity": "sha512-wKyQRQpjJ0sIp62ErSZdGsjMJWsap5oRNihHhu6G7JVO/9jIB6UyevL+tXuOqrng8j/cxKTWyWUwvSTriiZz/g==",
			"requires": {
				"emoji-regex": "^8.0.0",
				"is-fullwidth-code-point": "^3.0.0",
				"strip-ansi": "^6.0.1"
			}
		},
		"strip-ansi": {
			"version": "6.0.1",
			"resolved": "https://registry.npmjs.org/strip-ansi/-/strip-ansi-6.0.1.tgz",
			"integrity": "sha512-Y38VPSHcqkFrCpFnQ9vuSXmquuv5oXOKpGeT6aGrr3o3Gc9AlVa6JBfUSOCnbxGGZF+/0ooI7KrPuUSztUdU5A==",
			"requires": {
				"ansi-regex": "^5.0.1"
			}
		},
		"strnum": {
			"version": "1.1.2",
			"resolved": "https://registry.npmjs.org/strnum/-/strnum-1.1.2.tgz",
			"integrity": "sha512-vrN+B7DBIoTTZjnPNewwhx6cBA/H+IS7rfW68n7XxC1y7uoiGQBxaKzqucGUgavX15dJgiGztLJ8vxuEzwqBdA==",
			"optional": true
		},
		"supports-color": {
			"version": "5.5.0",
			"resolved": "https://registry.npmjs.org/supports-color/-/supports-color-5.5.0.tgz",
			"integrity": "sha512-QjVjwdXIt408MIiAqCX4oUKsgU2EqAGzs2Ppkm4aQYbjm+ZEWEcW4SfFNTr4uMNZma0ey4f5lgLrkB0aX0QMow==",
			"dev": true,
			"requires": {
				"has-flag": "^3.0.0"
			}
		},
		"tar": {
			"version": "6.2.1",
			"resolved": "https://registry.npmjs.org/tar/-/tar-6.2.1.tgz",
			"integrity": "sha512-DZ4yORTwrbTj/7MZYq2w+/ZFdI6OZ/f9SFHR+71gIVUZhOQPHzVCLpvRnPgyaMpfWxxk/4ONva3GQSyNIKRv6A==",
			"requires": {
				"chownr": "^2.0.0",
				"fs-minipass": "^2.0.0",
				"minipass": "^5.0.0",
				"minizlib": "^2.1.1",
				"mkdirp": "^1.0.3",
				"yallist": "^4.0.0"
			},
			"dependencies": {
				"minipass": {
					"version": "5.0.0",
					"resolved": "https://registry.npmjs.org/minipass/-/minipass-5.0.0.tgz",
					"integrity": "sha512-3FnjYuehv9k6ovOEbyOswadCDPX1piCfhV8ncmYtHOjuPwylVWsghTLo7rabjC3Rx5xD4HDx8Wm1xnMF7S5qFQ=="
				}
			}
		},
		"to-regex-range": {
			"version": "5.0.1",
			"resolved": "https://registry.npmjs.org/to-regex-range/-/to-regex-range-5.0.1.tgz",
			"integrity": "sha512-65P7iz6X5yEr1cwcgvQxbbIw7Uk3gOy5dIdtZ4rDveLqhrdJP+Li/Hx6tyK0NEb+2GCyneCMJiGqrADCSNk8sQ==",
			"dev": true,
			"requires": {
				"is-number": "^7.0.0"
			}
		},
		"toidentifier": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/toidentifier/-/toidentifier-1.0.1.tgz",
			"integrity": "sha512-o5sSPKEkg/DIQNmH43V0/uerLrpzVedkUh8tGNvaeXpfpuwjKenlSox/2O/BTlZUtEe+JG7s5YhEz608PlAHRA=="
		},
		"touch": {
			"version": "3.1.0",
			"resolved": "https://registry.npmjs.org/touch/-/touch-3.1.0.tgz",
			"integrity": "sha512-WBx8Uy5TLtOSRtIq+M03/sKDrXCLHxwDcquSP2c43Le03/9serjQBIztjRz6FkJez9D/hleyAXTBGLwwZUw9lA==",
			"dev": true,
			"requires": {
				"nopt": "~1.0.10"
			},
			"dependencies": {
				"nopt": {
					"version": "1.0.10",
					"resolved": "https://registry.npmjs.org/nopt/-/nopt-1.0.10.tgz",
					"integrity": "sha512-NWmpvLSqUrgrAC9HCuxEvb+PSloHpqVu+FqcO4eeF2h5qYRhA7ev6KvelyQAKtegUbC6RypJnlEOhd8vloNKYg==",
					"dev": true,
					"requires": {
						"abbrev": "1"
					}
				}
			}
		},
		"tr46": {
			"version": "3.0.0",
			"resolved": "https://registry.npmjs.org/tr46/-/tr46-3.0.0.tgz",
			"integrity": "sha512-l7FvfAHlcmulp8kr+flpQZmVwtu7nfRV7NZujtN0OqES8EL4O4e0qqzL0DC5gAvx/ZC/9lk6rhcUwYvkBnBnYA==",
			"requires": {
				"punycode": "^2.1.1"
			}
		},
		"tslib": {
			"version": "2.8.1",
			"resolved": "https://registry.npmjs.org/tslib/-/tslib-2.8.1.tgz",
			"integrity": "sha512-oJFu94HQb+KVduSUQL7wnpmqnfmLsOA/nAh6b6EH0wCEoK0/mPeXU6c3wKDV83MkOuHPRHtSXKKU99IBazS/2w==",
			"optional": true
		},
		"type-is": {
			"version": "1.6.18",
			"resolved": "https://registry.npmjs.org/type-is/-/type-is-1.6.18.tgz",
			"integrity": "sha512-TkRKr9sUTxEH8MdfuCSP7VizJyzRNMjj2J2do2Jr3Kym598JVdEksuzPQCnlFPW4ky9Q+iA+ma9BGm06XQBy8g==",
			"requires": {
				"media-typer": "0.3.0",
				"mime-types": "~2.1.24"
			}
		},
		"undefsafe": {
			"version": "2.0.5",
			"resolved": "https://registry.npmjs.org/undefsafe/-/undefsafe-2.0.5.tgz",
			"integrity": "sha512-WxONCrssBM8TSPRqN5EmsjVrsv4A8X12J4ArBiiayv3DyyG3ZlIg6yysuuSYdZsVz3TKcTg2fd//Ujd4CHV1iA==",
			"dev": true
		},
		"unpipe": {
			"version": "1.0.0",
			"resolved": "https://registry.npmjs.org/unpipe/-/unpipe-1.0.0.tgz",
			"integrity": "sha512-pjy2bYhSsufwWlKwPc+l3cN7+wuJlK6uz0YdJEOlQDbl6jo/YlPi4mb8agUkVC8BF7V8NuzeyPNqRksA3hztKQ=="
		},
		"util-deprecate": {
			"version": "1.0.2",
			"resolved": "https://registry.npmjs.org/util-deprecate/-/util-deprecate-1.0.2.tgz",
			"integrity": "sha1-RQ1Nyfpw3nMnYvvS1KKJgUGaDM8="
		},
		"utils-merge": {
			"version": "1.0.1",
			"resolved": "https://registry.npmjs.org/utils-merge/-/utils-merge-1.0.1.tgz",
			"integrity": "sha1-n5VxD1CiZ5R7LMwSR0HBAoQn5xM="
		},
		"uuid": {
			"version": "8.3.2",
			"resolved": "https://registry.npmjs.org/uuid/-/uuid-8.3.2.tgz",
			"integrity": "sha512-+NYs2QeMWy+GWFOEm9xnn6HCDp0l7QBD7ml8zLUmJ+93Q5NF0NocErnwkTkXVFNiX3/fpC6afS8Dhb/gz7R7eg=="
		},
		"vary": {
			"version": "1.1.2",
			"resolved": "https://registry.npmjs.org/vary/-/vary-1.1.2.tgz",
			"integrity": "sha1-IpnwLG3tMNSllhsLn3RSShj2NPw="
		},
		"webidl-conversions": {
			"version": "7.0.0",
			"resolved": "https://registry.npmjs.org/webidl-conversions/-/webidl-conversions-7.0.0.tgz",
			"integrity": "sha512-VwddBukDzu71offAQR975unBIGqfKZpM+8ZX6ySk8nYhVoo5CYaZyzt3YBvYtRtO+aoGlqxPg/B87NGVZ/fu6g=="
		},
		"whatwg-url": {
			"version": "11.0.0",
			"resolved": "https://registry.npmjs.org/whatwg-url/-/whatwg-url-11.0.0.tgz",
			"integrity": "sha512-RKT8HExMpoYx4igMiVMY83lN6UeITKJlBQ+vR/8ZJ8OCdSiN3RwCq+9gH0+Xzj0+5IrM6i4j/6LuvzbZIQgEcQ==",
			"requires": {
				"tr46": "^3.0.0",
				"webidl-conversions": "^7.0.0"
			}
		},
		"wide-align": {
			"version": "1.1.5",
			"resolved": "https://registry.npmjs.org/wide-align/-/wide-align-1.1.5.tgz",
			"integrity": "sha512-eDMORYaPNZ4sQIuuYPDHdQvf4gyCF9rEEV/yPxGfwPkRodwEgiMUUXTx/dex+Me0wxx53S+NgUHaP7y3MGlDmg==",
			"requires": {
				"string-width": "^1.0.2 || 2 || 3 || 4"
			}
		},
		"wrappy": {
			"version": "1.0.2",
			"resolved": "https://registry.npmjs.org/wrappy/-/wrappy-1.0.2.tgz",
			"integrity": "sha1-tSQ9jz7BqjXxNkYFvA0QNuMKtp8="
		},
		"ws": {
			"version": "8.17.1",
			"resolved": "https://registry.npmjs.org/ws/-/ws-8.17.1.tgz",
			"integrity": "sha512-6XQFvXTkbfUOZOKKILFG1PDK2NDQs4azKQl26T0YS5CxqWLgXajbPZ+h4gZekJyRqFU8pvnbAbbs/3TgRPy+GQ==",
			"requires": {}
		},
		"yallist": {
			"version": "4.0.0",
			"resolved": "https://registry.npmjs.org/yallist/-/yallist-4.0.0.tgz",
			"integrity": "sha512-3wdGidZyq5PB084XLES5TpOSRA3wjXAlIWMhum2kRcv/41Sn2emQ0dycQW4uZXLejwKvg6EsvbdlVL+FYEct7A=="
		}
	}
}



================================================
File: backend/package.json
================================================
{
	"name": "back-end",
	"version": "1.0.0",
	"description": "",
	"main": "src/server.js",
	"scripts": {
		"start": "tsc && ts-node ./dist/server.js",
		"nod": "nodemon --exec npx ts-node -r dotenv/config src/server.ts"
	},
	"author": "Jesse Burström",
	"dependencies": {
		"bcrypt": "^5.0.1",
		"cors": "^2.8.5",
		"dotenv": "^16.0.1",
		"express": "^4.18.1",
		"jsonwebtoken": "^9.0.2",
		"mongodb": "^4.6.0",
		"socket.io": "^4.5.1",
		"uuid": "^8.3.2"
	},
	"devDependencies": {
		"@types/bcrypt": "^5.0.0",
		"@types/body-parser": "^1.19.2",
		"@types/cors": "^2.8.12",
		"@types/express": "^4.17.13",
		"@types/jsonwebtoken": "^8.5.8",
		"@types/node": "^17.0.38",
		"@types/nodemon": "^1.19.1",
		"@types/uuid": "^8.3.4",
		"nodemon": "^3.1.9"
	}
}



================================================
File: backend/tsconfig.json
================================================
{
  "compilerOptions": {
    "outDir": "./dist",
    "moduleResolution": "node",
    "module": "commonjs",
    "allowJs": true,
    "target": "es6",
    "esModuleInterop": true
  },
  "include": ["./src/**/*"],
  "exclude": ["src/build", "src/web"]
}



================================================
File: backend/.gitignore
================================================
# Dependency directories
node_modules/
jspm_packages/

# Build outputs
dist/
build/

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# IDE and editor folders
.idea/
.vscode/
*.swp
*.swo

# OS specific
.DS_Store
Thumbs.db



================================================
File: backend/src/db.ts
================================================
import { MongoClient, Db } from "mongodb"; // Import Db type

let client: MongoClient; // Add type for client

export const initializeDbConnection = async () => {
  try {
    console.log("📊 [DB] Connecting to MongoDB at mongodb://127.0.0.1:27017...");
    client = await MongoClient.connect("mongodb://127.0.0.1:27017", {
      // useNewUrlParser and useUnifiedTopology are deprecated and default to true
      // Remove them or keep if using an older driver version where they are needed
    });
    console.log("✅ [DB] Successfully connected to MongoDB");
    
    // Create a test entry to verify write access
    const testDb = client.db('yatzy-game-log-db');
    const testCollection = testDb.collection('db_test');
    const result = await testCollection.insertOne({
      message: "Database connection test",
      timestamp: new Date()
    });
    
    console.log(`✅ [DB] Test document inserted with ID: ${result.insertedId}`);
    
    // Also check if game_moves collection exists
    const movesCollection = testDb.collection('game_moves');
    const count = await movesCollection.countDocuments();
    console.log(`📊 [DB] game_moves collection has ${count} documents`);
    
  } catch (error) {
    console.error("❌ [DB] Error connecting to MongoDB:", error);
    throw error; // Rethrow to make sure app doesn't start with broken DB
  }
};

// Add types for parameter and return value
export const getDbConnection = (dbName: string): Db => {
  if (!client) {
    console.error("❌ [DB] MongoDB client is not initialized when trying to get DB:", dbName);
    throw new Error("MongoDB client is not initialized");
  }
  
  try {
    const db = client.db(dbName);
    return db;
  } catch (error) {
    console.error(`❌ [DB] Error getting database connection for "${dbName}":`, error);
    throw error;
  }
};


================================================
File: backend/src/license.txt
================================================
flutter_unity_widget

BSD 3-Clause License

Copyright (c) 2022-present, Rex Isaac Raphael.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


================================================
File: backend/src/server.ts
================================================
import express from "express";
import { routes } from "./routes/index";
import { initializeDbConnection } from "./db";
import * as path from "path";
import cors from "cors";
import { Server } from "socket.io";
import { createServer } from "http";

// Import services
import { GameService } from "./services/GameService";
import { GameLogService } from "./services/GameLogService"; // <-- Import GameLogService
import { TopScoreService } from "./services/TopScoreService";

// Import controllers
import { GameController } from "./controllers/GameController";
import { PlayerController } from "./controllers/PlayerController";
import { ChatController } from "./controllers/ChatController";
import { spectateGameRoute, initializeSpectateRoute } from "./routes/spectateGameRoute"; // <-- Import spectate route and initializer

const PORT: number = 8000;

const app = express();

// Important client has local ip (like 192.168.0.168) not 127.0.0.1 or localhost in browser to work on local developement across different computers
// Local client connect should look like : http://192.168.0.168:8080 , or your local network ip instead of 192.168.0.168
// Also with port number this should not be there ssl online since all is taken care of with nginx or similar routing port 80 to prefeerably 8080
// for Https, socket.io and WebSocket. Requirement of Google Platform app engine flex only one port and is possible! but also convinient!
app.use(cors({
  origin: '*', // This allows all origins
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

const httpServer = createServer(app);

// All 4 systems NodeJS, Flutter, Unity and React has this flag to differ from local developement and online publish
// One improvement could be global system flag all systems look at so avoid funny errors missing to reset flag... :)
// Got idea from meetup to signal in running code visually if offline/online good idea!
let isOnline: boolean = false;

const localFlutterDir: string = "C:/Users/J/StudioProjects/flutter_system";
const localReactDir: string = "C:/Users/J/Desktop/proj";

if (isOnline) {
  //app.use(express.static(path.join(__dirname, "/build")));
  app.use(express.static(path.join(__dirname, "/web")));
} else {
  //app.use(express.static(localReactDir + "/build"));
  app.use(express.static(localFlutterDir + "/build/web"));
}

app.use(express.json());

// Add all the routes to our Express server
// exported from routes/index.js
routes().forEach((route) => {
  // Ensure correct method mapping for Express
  const method = route.method.toLowerCase() as 'get' | 'post' | 'put' | 'delete' | 'patch' | 'options' | 'head';
  if (app[method]) {
      app[method](route.path, route.handler);
  } else {
      console.error(`Invalid method ${route.method} for route ${route.path}`);
  }
});
// Add the new spectate route explicitly after other routes
app.get(spectateGameRoute.path, spectateGameRoute.handler); // <-- Add spectate route handler

////////////////////////////////// YATZY //////////////////////////////////

// Initialize Socket.IO server with proper CORS settings
const io = new Server(httpServer, {
  cors: {
    origin: "*", // Allow all origins
    methods: ["GET", "POST"],
    credentials: false,
    allowedHeaders: ["Content-Type", "Authorization"]
  },
  // Important: Configure for both websocket and polling transport
  transports: ["websocket", "polling"],
  // Add ping timeout and interval settings
  pingTimeout: 60000,
  pingInterval: 25000,
  // Disable compression for debugging
  perMessageDeflate: false,
  // Path option if needed
  path: "/socket.io/",
  // Allow reconnection
  allowEIO3: true
});

// Log middleware for debugging
io.use((socket, next) => {
  console.log("Socket middleware - connection attempt:", socket.id);
  next();
});

// Create service instances
const gameLogService = new GameLogService(); // <-- Create GameLogService instance
// Pass the io instance to TopScoreService
const topScoreService = new TopScoreService(io); // <-- Create TopScoreService instance, passing io
const gameService = new GameService(io, gameLogService, topScoreService); // <-- Pass both services

// Create controller instances
const gameController = new GameController(gameService, gameLogService); // <-- Pass log service
const playerController = new PlayerController(gameService, gameLogService); // <-- Pass log service
const chatController = new ChatController(io, gameService);

// Initialize the spectate route with service instances <-- ADD THIS
initializeSpectateRoute(gameService, gameLogService);

// Handle Socket.IO connections
io.on("connect", (socket) => {
  console.log("Client connected...", socket.id);

  // Send welcome message for connection confirmation
  socket.emit("welcome", { message: "Connection successful", id: socket.id });
  
  // Echo event for testing connection
  socket.on("echo", (data) => {
    console.log("Echo event received:", data);
    socket.emit("echo", { message: "Echo reply", ...data });
  });

  // Register socket handlers from our controllers
  gameController.registerSocketHandlers(socket);
  playerController.registerSocketHandlers(socket);
  chatController.registerSocketHandlers(socket);  // Register chat handlers

  // Listen for client to server messages
  socket.on("sendToServer", (data) => {
    console.log(`Message to server from ${socket.id}:`, data?.action || data);

    // **** Handle requestTopScores FIRST ****
    if (data?.action === 'requestTopScores') {
      // **** Get specific gameType from request ****
      const requestedGameType = data?.gameType;
      if (typeof requestedGameType !== 'string') {
        console.error(`❌ Invalid requestTopScores from ${socket.id}: Missing or invalid gameType.`);
        socket.emit('errorMsg', { message: 'Invalid request for top scores: gameType missing.' }); 
        return; // Stop processing invalid request
      }

      console.log(`🏆 Received requestTopScores from ${socket.id} for game type: ${requestedGameType}`);
      // **** Fetch scores for the SPECIFIC type (NO LIMIT) ****
      topScoreService.getTopScores(requestedGameType) // Call without limit argument
        .then(scores => {
          // **** Emit the specific list back using 'onServerMsg' ****
          socket.emit('onServerMsg', { 
              action: 'onTopScoresUpdate',
              gameType: requestedGameType, // Include gameType for context
              scores: scores 
            });
          console.log(`🏆 Sent top scores for ${requestedGameType} back to ${socket.id} via onServerMsg`);
        })
        .catch(error => {
          console.error(`❌ Error fetching scores for requestTopScores (${requestedGameType}) from ${socket.id}:`, error);
          socket.emit('errorMsg', { message: `Failed to retrieve top scores for ${requestedGameType}` }); 
        });
      return; // Stop further processing for this action
    }
    // ***********************************************
    
    // Handle chat messages (example)
    if (data?.action === 'chatMessage') {
      console.log(`💬 Chat message from ${socket.id}:`, data);
    }

    // Other general message routing/handling could go here

  });

  // Listen for client to client messages
  socket.on("sendToClients", (data) => {
    console.log(`Message to clients from ${socket.id}:`, data?.action || data);
    
    // Handle chat messages specifically
    if (data?.action === 'chatMessage') {
      console.log(`💬 Chat message broadcast from ${socket.id}:`, data);
    }
  });

  // Handle disconnection
  socket.on("disconnect", () => {
    console.log("Client disconnected...", socket.id);
    gameService.handlePlayerDisconnect(socket.id);
  });
});

app.get("/flutter", (req, res) => {
  if (isOnline) {
    res.sendFile(path.join(__dirname + "/web/index.html"));
  } else {
    res.sendFile(localFlutterDir + "/build/web/index.html");
  }
});

app.get("*", (req, res) => {
  if (isOnline) {
    //res.sendFile(path.join(__dirname + "/build/index.html"));
    res.sendFile(path.join(__dirname + "/web/index.html"));
  } else {
    res.sendFile(localReactDir + "/build/index.html");
  }
});

// Initialize database connection and start server
initializeDbConnection()
  .then(() => {
    console.log("✅ [SERVER] Database connection initialized successfully");
    
    // Verify database connection with GameLogService
    try {
      const testCollection = gameLogService.getCollection();
      console.log("✅ [SERVER] Successfully accessed game_moves collection");
    } catch (e) {
      console.error("❌ [SERVER] Error accessing game_moves collection:", e);
    }
    
    // Start the server
    httpServer.listen(PORT, () => {
      console.log(`✅ [SERVER] Server running on port ${PORT}`);
      console.log(`✅ [SERVER] Socket.IO server ready for connections`);
      isOnline 
        ? console.log("🌐 [SERVER] SERVER MODE: ONLINE") 
        : console.log("🖥️ [SERVER] SERVER MODE: OFFLINE");
      
      // Log MongoDB connection details
      console.log(`📊 [SERVER] MongoDB connected to database '${gameLogService.getDatabaseName()}'`);
      console.log(`📊 [SERVER] Using collection '${gameLogService.getCollectionName()}'`);
    });
  })
  .catch((error) => {
    console.error("❌ [SERVER] Error initializing database connection:", error);
    console.error("❌ [SERVER] Server startup failed due to database connection error");
    process.exit(1); // Exit with error code
  });


================================================
File: backend/src/controllers/ChatController.ts
================================================
import { Socket, Server } from 'socket.io';
import { GameService } from '../services/GameService';

/**
 * Controller for handling chat-related socket events
 */
export class ChatController {
  private io: Server;
  private gameService: GameService;

  constructor(io: Server, gameService?: GameService) {
    this.io = io;
    this.gameService = gameService;
  }

  /**
   * Register socket event handlers for chat events
   * @param socket Socket connection
   */
  registerSocketHandlers(socket: Socket): void {
    console.log(`💬 Registering chat handlers for socket ${socket.id}`);
    
    // Handle chat messages from sendToClients
    socket.on('sendToClients', (data) => {
      if (data.action === 'chatMessage') {
        console.log(`💬 Chat message received via sendToClients from ${socket.id}:`, data);
        this.handleChatMessage(socket, data);
      }
    });
    
    // Handle chat messages from sendToServer
    socket.on('sendToServer', (data) => {
      if (data.action === 'chatMessage') {
        console.log(`💬 Chat message received via sendToServer from ${socket.id}:`, data);
        this.handleServerChatMessage(socket, data);
      }
    });
  }

  /**
   * Handle chat message from player via sendToClients
   * @param socket Socket connection
   * @param data Chat message data
   */
  private handleChatMessage(socket: Socket, data: any): void {
    // Extract data based on format (support both legacy and modern formats)
    const chatMessage = data.chatMessage;
    const playerIds = data.playerIds;
    const gameId = data.gameId;
    const message = data.message;
    const sender = data.sender;
    
    console.log(`💬 Received chat message from ${socket.id}:`, {
      format: chatMessage ? 'legacy' : 'modern',
      chatMessage,
      gameId,
      message,
      sender,
      playerIds: playerIds?.length
    });
    
    // Handle modern format (gameId + message + sender)
    if (gameId !== undefined && message !== undefined) {
      // Format message if needed
      const formattedMessage = sender ? `${sender}: ${message}` : message;
      
      console.log(`💬 Processing modern chat format: ${formattedMessage} for game ${gameId}`);
      
      // Use the GameService to find all players in the game
      if (this.gameService) {
        const game = this.gameService.getGame(gameId);
        
        if (game) {
          console.log(`💬 Found game ${gameId} with ${game.players.length} players`);
          
          // Send to all active players EXCEPT the sender
          for (const player of game.players) {
            // Skip the sender - CRITICAL to avoid echoing messages back
            if (player.id === socket.id) {
              console.log(`💬 Skipping message sender ${socket.id}`);
              continue;
            }
            
            if (player.isActive && player.id) {
              console.log(`💬 Sending chat message to player ${player.id} in game ${gameId}`);
              this.io.to(player.id).emit('onClientMsg', {
                action: 'chatMessage',
                chatMessage: formattedMessage
              });
            }
          }
          return;
        } else {
          console.log(`💬 Could not find game with ID ${gameId}, falling back to playerIds`);
        }
      }
    }
    
    // Handle legacy format (chatMessage + playerIds)
    if (chatMessage && playerIds && Array.isArray(playerIds)) {
      console.log(`💬 Processing legacy chat format with ${playerIds.length} recipient(s)`);
      
      // Forward message to all players except sender
      for (const playerId of playerIds) {
        // Skip the sender - CRITICAL to avoid echoing messages back
        if (playerId === socket.id) {
          console.log(`💬 Skipping message sender ${socket.id}`);
          continue;
        }
        
        if (playerId) {
          console.log(`💬 Sending chat message to player ${playerId}`);
          this.io.to(playerId).emit('onClientMsg', {
            action: 'chatMessage',
            chatMessage
          });
        }
      }
    } else {
      console.log(`💬 Invalid chat message format, missing required fields`);
    }
  }
  
  /**
   * Handle chat message from player via sendToServer
   * This version supports the newer format with gameId and message properties
   * @param socket Socket connection
   * @param data Chat message data
   */
  private handleServerChatMessage(socket: Socket, data: any): void {
    const { gameId, message, sender } = data;
    
    console.log(`💬 Processing server chat message from ${socket.id}:`, { gameId, message, sender });
    
    if (!message) {
      console.log(`💬 Ignoring invalid chat message from ${socket.id} - missing message`);
      return;
    }
    
    if (!gameId) {
      console.log(`💬 Ignoring invalid chat message from ${socket.id} - missing gameId`);
      return;
    }
    
    // Format the chat message
    const chatMessage = sender ? `${sender}: ${message}` : message;
    
    // Use the GameService to find all players in the game
    if (this.gameService) {
      const game = this.gameService.getGame(gameId);
      
      if (game) {
        console.log(`💬 Found game ${gameId} with ${game.players.length} players`);
        
        // Send to all active players except the sender
        for (const player of game.players) {
          if (player.isActive && player.id && player.id !== socket.id) {
            console.log(`💬 Sending chat message to player ${player.id} in game ${gameId}`);
            this.io.to(player.id).emit('onClientMsg', {
              action: 'chatMessage',
              chatMessage
            });
          }
        }
      } else {
        console.log(`💬 Could not find game with ID ${gameId}`);
      }
    } else {
      console.log(`💬 GameService not available, broadcasting to all sockets in room`);
      
      // If GameService is not available, broadcast to all in the room
      socket.to(`game_${gameId}`).emit('onClientMsg', {
        action: 'chatMessage',
        chatMessage
      });
    }
  }
  
  /**
   * Broadcast chat message to all players in the same game as the sender
   * Used as a fallback when specific playerIds are not provided
   * @param socket Socket connection
   * @param data Chat message data
   */
  private broadcastToPlayersInSameGame(socket: Socket, data: any): void {
    if (!this.gameService) {
      console.log(`💬 GameService not available, cannot find player's game`);
      return;
    }
    
    // Find all games that this player is in
    const playerGames = [];
    
    // Use the getAllGames method to find games with this player
    this.gameService.getAllGames().forEach(game => {
      if (game.players.some(player => player.id === socket.id && player.isActive)) {
        playerGames.push(game);
      }
    });
    
    if (playerGames.length === 0) {
      console.log(`💬 Player ${socket.id} is not in any active games`);
      return;
    }
    
    console.log(`💬 Player ${socket.id} is in ${playerGames.length} active games`);
    
    // For each game, broadcast to all other active players
    for (const game of playerGames) {
      console.log(`💬 Broadcasting to all players in game ${game.id}`);
      
      const chatMessage = data.chatMessage;
      
      for (const player of game.players) {
        if (player.isActive && player.id && player.id !== socket.id) {
          console.log(`💬 Sending chat message to player ${player.id} in game ${game.id}`);
          this.io.to(player.id).emit('onClientMsg', {
            action: 'chatMessage',
            chatMessage
          });
        }
      }
    }
  }
}



================================================
File: backend/src/controllers/GameController.ts
================================================
// backend/src/controllers/GameController.ts
import { Socket } from 'socket.io';
import { GameService } from '../services/GameService';
import { PlayerFactory, Player } from '../models/Player'; // Import Player class
import { GameLogService, GameMove } from '../services/GameLogService'; // <-- Import log service
import { getSelectionLabel } from '../utils/yatzyMapping'; // <-- Import mapping
import { Game } from '../models/Game'; // Import Game class

/**
 * Controller for handling game-related socket events
 */
export class GameController {
  private gameService: GameService;
  private gameLogService: GameLogService; // <-- Add log service instance

  constructor(gameService: GameService, gameLogService: GameLogService) { // <-- Inject log service
    this.gameService = gameService;
    this.gameLogService = gameLogService; // <-- Store log service instance
  }

  /**
   * Register socket event handlers for game events
   * @param socket Socket connection
   */
  registerSocketHandlers(socket: Socket): void {
    // Request to create or join a game
    socket.on('sendToServer', (data) => {
      switch (data.action) {
        case 'requestGame':
          this.handleRequestGame(socket, data);
          break;
        case 'requestJoinGame':
          this.handleRequestJoinGame(socket, data);
          break;
        case 'removeGame': // Should this be handled differently? Maybe game end.
          this.handleRemoveGame(socket, data);
          break;
        // --- Spectate Game Action ---
        case 'spectateGame':
            this.handleSpectateGame(socket, data);
            break;
        // Add other game-related actions as needed
      }
    });

    // Handle player sending dice values
    socket.on('sendToClients', (data) => {
      if (data.action === 'sendDices') {
        // Client sends dice values after rolling *itself*
        // Server should validate and maybe re-roll for security/consistency?
        // For now, trust client roll but log it.
        this.handleSendDices(socket, data);
      } else if (data.action === 'sendSelection') {
         // Client sends selection label and dice values used
        this.handleSendSelection(socket, data);
      }
    });

    // Handle socket disconnect event
    // Disconnect logging is now handled within GameService.handlePlayerDisconnect
    // socket.on('disconnect', () => {
    //   this.handleDisconnect(socket); // No longer needed here if GameService handles it
    // });
  }

  // ... (handleRequestGame, handleRequestJoinGame, handleRemoveGame remain similar, ensure they use GameService correctly)
  handleRequestGame(socket: Socket, data: any): void {
    const { gameType, nrPlayers, userName } = data;
    // --- Simplification: Validate gameType ---
    if (!['Ordinary', 'Mini', 'Maxi'].includes(gameType)) {
         console.warn(`[GameController] Invalid gameType requested: ${gameType}. Defaulting to Ordinary? Or reject.`);
         // Decide how to handle invalid type - reject or default
         // For now, reject:
         socket.emit('onServerMsg', { action: 'error', message: `Invalid game type: ${gameType}` });
         return;
    }
    // --- End Simplification ---
    const player = PlayerFactory.createPlayer(socket.id, userName, gameType); // Pass gameType

    const game = this.gameService.createOrJoinGame(gameType, nrPlayers, player);

    // GameService now handles notifications and game start logic internally
    // No need to emit 'onGameStart' here, createOrJoinGame handles it.
  }

   handleRequestJoinGame(socket: Socket, data: any): void {
     const { gameId, userName } = data;
     const game = this.gameService.getGame(gameId);

     if (!game) {
       socket.emit('onServerMsg', { action: 'error', message: 'Game not found' });
       return;
     }
     // Check if game already started or full before creating player
     if (game.gameStarted || game.isGameFull()) {
         socket.emit('onServerMsg', { action: 'error', message: 'Cannot join game (full or already started)' });
         return;
     }

     const player = PlayerFactory.createPlayer(socket.id, userName, game.gameType); // Pass gameType

     // Try to add player using the service method
     const joinedGame = this.gameService.joinGame(gameId, player);

     if (!joinedGame) {
        // This case might be redundant due to the check above, but keep for safety
        socket.emit('onServerMsg', { action: 'error', message: 'Could not join game (unexpected error)' });
     }
     // GameService.joinGame will handle starting and notifications if full
     // GameService.createOrJoinGame (called by handleRequestGame) also handles this logic now.
     // Let's ensure joinGame also triggers the necessary updates/notifications via GameService.
     else {
         // If join was successful, GameService.createOrJoinGame or similar logic should handle notifications.
         // If joinGame itself needs to trigger updates:
         this.gameService.notifyGameUpdate(joinedGame); // Send update after successful join
         if (joinedGame.gameStarted) {
             // If the join caused the game to start, send explicit start message
             const gameData = joinedGame.toJSON();
             gameData.action = 'onGameStart';
             for (const p of joinedGame.players) {
                 if (p?.isActive && p.id) {
                     this.gameService['io'].to(p.id).emit('onServerMsg', gameData); // Access io via GameService if private
                 }
             }
         }
         this.gameService.broadcastGameList(); // Ensure list is broadcast after join
     }
   }

   handleRemoveGame(socket: Socket, data: any): void {
     const { gameId } = data;
     // Check permissions? Only allow host or if game finished?
     // For now, allow removal, GameService handles broadcast.
     console.log(`-> Received request to remove game ${gameId} from ${socket.id}`);
     const game = this.gameService.getGame(gameId);
     if (game) {
         // If game exists, ensure it's properly finished and logged before removing
         if (!game.gameFinished) {
             // Force finish? Or just remove? Let's just remove for now.
             // Optionally mark as finished first
             // game.gameFinished = true;
             // this.gameService.handleGameFinished(game); // This would log and remove
         }
         this.gameService.removeGame(gameId); // removeGame now handles logging end if finished
         this.gameService.broadcastGameList(); // Broadcast handled by GameService.removeGame -> broadcastGameList
     } else {
         console.log(`-> Game ${gameId} not found for removal.`);
     }
   }


  // Modified handleSendDices to log roll via GameService
  handleSendDices(socket: Socket, data: any): void {
    const { gameId, diceValue, keptDice /* Add keptDice if sent */ } = data; // Assuming diceValue is the result of the roll
    if (gameId === undefined || !diceValue) { // Check gameId presence
        console.error("Invalid dice data received", data);
        return;
    }
    const game = this.gameService.getGame(gameId);
    if (!game) return;
    const playerIndex = game.findPlayerIndex(socket.id);
    if (playerIndex === -1 || playerIndex !== game.playerToMove) return; // Validate turn

    console.log(`🎲 Player ${socket.id} reported dice roll: [${diceValue}] for game ${gameId}`);

    // --- Logging & Processing via GameService ---
    // Note: Client calculates the roll. Server logs what client sent.
    // 'keptDice' would ideally be the state *before* this roll. Client needs to send this.
    // GameService.processDiceRoll now handles logging the 'roll' action.
    this.gameService.processDiceRoll(gameId, socket.id, diceValue, keptDice || []); // Pass empty array if keptDice not sent

    // --- Forwarding to other clients ---
    // GameService.processDiceRoll now handles broadcasting 'sendDices' via onClientMsg to others.
    // No need to forward manually here.

    // --- Send full game state update back to everyone? ---
    // Optional: Could send the full game state after processing the roll.
    // this.gameService.notifyGameUpdate(game);
  }


  // Modified handleSendSelection to use label and log via GameService
  handleSendSelection(socket: Socket, data: any): void {
    // Expect selectionLabel instead of cell index
    const { gameId, selectionLabel, player, diceValue, score /* client might send calculated score */ } = data;
     if (gameId === undefined || !selectionLabel || player === undefined || !diceValue) { // Check gameId presence
         console.error("❌ Invalid selection data received", data);
         return;
     }

     const game = this.gameService.getGame(gameId);
     if (!game) return;

     const playerIndex = game.findPlayerIndex(socket.id);
     // Validate it's the correct player's turn and the player index matches
     if (playerIndex === -1 || playerIndex !== game.playerToMove || playerIndex !== player) {
         console.warn(`⚠️ Selection ignored: Turn mismatch or player index mismatch. Got player ${player}, expected ${game.playerToMove} (socket owner index ${playerIndex})`);
         // Optionally send error back to client
         // socket.emit('onServerMsg', { action: 'error', message: 'Invalid selection attempt.' });
         return;
     }

    console.log(`🎮 Player ${socket.id} selected '${selectionLabel}' with dice [${diceValue}] score ${score ?? 'N/A'}`);

     // --- Logging & Processing via GameService ---
     // GameService now handles logging and state updates including turn advancement
     // We pass the necessary info, including the score reported by the client.
     // Server *could* recalculate score here for validation if needed.
     const success = this.gameService.processSelection(gameId, socket.id, selectionLabel, score ?? 0); // Pass score, default to 0 if not provided

     // --- Forwarding to other clients ---
     // GameService.processSelection handles notifying *all* clients via notifyGameUpdate (onServerMsg).
     // If we *also* need the specific 'sendSelection' for onClientMsg:
     if (success) {
         this.gameService.forwardSelectionToPlayers(gameId, socket.id, data); // Forward raw data for client-side processing
     }
  }

  // Removed handleDisconnect as GameService now handles it via its own listener

  /**
   * Handle spectate game request
   * @param socket Socket connection
   * @param data Request data
   */
  async handleSpectateGame(socket: Socket, data: any): Promise<void> {
    const { gameId, userName } = data;
    
    if (gameId === undefined) {
      console.error("Invalid spectate request: missing gameId", data);
      socket.emit('onServerMsg', { action: 'error', message: 'Invalid spectate request: missing gameId' });
      return;
    }

    console.log(`📊 [DEBUG] Handling spectate request for game ${gameId} from ${socket.id} (${userName || 'Anonymous'})`);

    // Get the current game from memory
    const game = this.gameService.getGame(gameId);
    if (!game) {
      console.error(`Game ${gameId} not found for spectating in active games`);
      socket.emit('onServerMsg', { action: 'error', message: 'Game not found' });
      return;
    }

    // Check if the game has started
    if (!game.gameStarted) {
      console.error(`Game ${gameId} has not started yet, cannot spectate`);
      socket.emit('onServerMsg', { action: 'error', message: 'Game has not started yet' });
      return;
    }

    // Get game log from database to ensure we have all moves
    // Important: Check both gameId and game.id as they might differ
    console.log(`📊 [DEBUG] Fetching game log from database for gameId=${gameId} and game.id=${game.id}`);
    let gameLog = await this.gameLogService.getGameLog(gameId);
    
    // If not found with the provided gameId, try with game.id (might be different)
    if (!gameLog && gameId !== game.id) {
      console.log(`📊 [DEBUG] No log found with gameId=${gameId}, trying game.id=${game.id}`);
      gameLog = await this.gameLogService.getGameLog(game.id);
    }
    
    if (gameLog) {
      console.log(`📊 [DEBUG] Found game log with ${gameLog.moves.length} moves`);
      
      // Log all selection moves for debugging
      const selectionMoves = gameLog.moves.filter(move => move.action === 'select');
      console.log(`📊 [DEBUG] Game has ${selectionMoves.length} selection moves:`);
      selectionMoves.forEach(move => {
        console.log(`📊 [DEBUG] - Player ${move.playerIndex} selected ${move.selectionLabel} for ${move.score} points`);
      });
      
      // For each selection move in the log, ensure it's applied to the game state
      console.log(`📊 [DEBUG] Ensuring all selection moves are applied to game state`);
      for (const move of selectionMoves) {
        if (move.playerIndex >= 0 && move.playerIndex < game.players.length) {
          const player = game.players[move.playerIndex];
          if (player && move.selectionLabel && move.score !== undefined) {
            console.log(`📊 [DEBUG] Applying selection "${move.selectionLabel}" with score ${move.score} to player ${move.playerIndex}`);
            
            // Use the applySelection method from Game to apply this move
            try {
              game.applySelection(move.playerIndex, move.selectionLabel, move.score);
            } catch (e) {
              console.error(`📊 [DEBUG] Error applying selection: ${e}`);
            }
          }
        }
      }
    } else {
      console.log(`📊 [DEBUG] No game log found for game ${gameId}, using in-memory state only`);
    }

    console.log(`👁️ Player ${socket.id} (${userName || 'Anonymous'}) is spectating game ${gameId}`);

    // Force recalculation of all scores for all players
    console.log(`📊 [DEBUG] Recalculating scores for all players`);
    for (const player of game.players) {
      if (player && player.isActive) {
        // Recalculate all player scores to ensure cells show current values
        player.calculateScores();
        
        // Log player score and status of key cells
        if (player.cells) {
          const foursCell = player.cells.find(c => c && c.label === 'Fours');
          const fivesCell = player.cells.find(c => c && c.label === 'Fives');
          const houseCell = player.cells.find(c => c && c.label === 'House');
          const totalCell = player.cells.find(c => c && c.label === 'Total');
          
          console.log(`📊 [DEBUG] Player ${player.username} score: ${player.score}`);
          console.log(`📊 [DEBUG] - Fours: ${foursCell ? foursCell.value : 'N/A'} (fixed: ${foursCell ? foursCell.fixed : 'N/A'})`);
          console.log(`📊 [DEBUG] - Fives: ${fivesCell ? fivesCell.value : 'N/A'} (fixed: ${fivesCell ? fivesCell.fixed : 'N/A'})`);
          console.log(`📊 [DEBUG] - House: ${houseCell ? houseCell.value : 'N/A'} (fixed: ${houseCell ? houseCell.fixed : 'N/A'})`);
          console.log(`📊 [DEBUG] - Total: ${totalCell ? totalCell.value : 'N/A'}`);
        }
      }
    }

    // Send the current game state to the spectator
    const gameData = game.toJSON();
    gameData.action = 'onGameStart';
    gameData.spectator = true; // Mark as spectator
    
    // Log detailed information about the cells being sent
    console.log(`📊 [DEBUG] Player cells in game data:`);
    game.players.forEach((player, idx) => {
      if (player && player.cells) {
        console.log(`📊 [DEBUG] Player ${idx} (${player.username}) cells:`);
        player.cells.forEach(cell => {
          if (cell) {
            console.log(`📊 [DEBUG] - ${cell.label}: value=${cell.value}, fixed=${cell.fixed}`);
          }
        });
      }
    });
    
    console.log(`📊 [DEBUG] Sending spectator data to client`);
    socket.emit('onServerMsg', gameData);

    // Log the spectate action
    this.gameLogService.logSpectate(gameId, socket.id, userName || 'Anonymous');
    
    // Also send an immediate game update message to ensure latest state
    gameData.action = 'onGameUpdate';
    console.log(`📊 [DEBUG] Sending additional update message to reinforce state`);
    socket.emit('onServerMsg', gameData);

    // Register the socket as a spectator to receive future updates
    this.gameService.addSpectator(gameId, socket.id);
  }
}


================================================
File: backend/src/controllers/PlayerController.ts
================================================
// backend/src/controllers/PlayerController.ts
import { Socket } from "socket.io";
import { GameService } from "../services/GameService";
import { PlayerFactory } from "../models/Player";
import { GameLogService } from "../services/GameLogService"; // <-- Import

/**
 * Controller for handling player-related socket events
 */
export class PlayerController {
  private gameService: GameService;
  private gameLogService: GameLogService; // <-- Add
  private playerRegistry = new Map<string, boolean>();

  constructor(gameService: GameService, gameLogService: GameLogService) { // <-- Inject
    this.gameService = gameService;
    this.gameLogService = gameLogService; // <-- Store
  }

  registerSocketHandlers(socket: Socket): void {
    // Handle all player-related actions from the client
    socket.on("sendToServer", (data) => {
      // Log received message, but be careful not to log sensitive data if any
      console.log(`PlayerController: Received message from client ${socket.id}: Action: ${data?.action}`);

      if (!data || typeof data !== 'object') {
        console.error('Invalid data received from client', socket.id);
        return;
      }

      switch (data.action) {
        case "getId":
          this.handleGetId(socket);
          break;

        // These are now primarily handled by GameController/GameService
        // PlayerController might just log player-specific connection events if needed
        // case "createGame": // Handled by GameController via requestGame
        // case "joinGame": // Handled by GameController via requestJoinGame
        // case "requestGame": // Handled by GameController
        // case "requestJoinGame": // Handled by GameController
        // case "useRegret": // Handled by GameController
        // case "useExtraMove": // Handled by GameController

        // Roll/Select are handled by GameController as they affect shared game state
        // case "rollDice": // Client sends 'sendDices' now
        // case "selectCell": // Client sends 'sendSelection' now

        default:
           // Only log if it's not an action handled elsewhere or a common one like chat
           // Add 'requestTopScores' and 'spectateGame' to the list of known, delegated actions
              const knownDelegatedActions = [
                  'requestGame', 'requestJoinGame', 'removeGame', // GameController actions
                  'spectateGame',                                 // GameController action
                  'chatMessage',                                  // ChatController action
                  'requestTopScores'                              // Server.ts direct handler
              ];
              if (!knownDelegatedActions.includes(data.action)) {
             console.log(`PlayerController: Unknown or delegated action: ${data.action}`);
           }
      }
    });

    // Disconnect handled by GameService now
    // socket.on('disconnect', () => {
    //   this.handleDisconnect(socket); // Removed
    // });
  }

  private handleGetId(socket: Socket): void {
    // Logic remains the same, primarily involves GameService now for broadcasting list
    if (this.playerRegistry.has(socket.id)) {
        console.log(`Player ${socket.id} re-requested ID.`);
        socket.emit("onServerMsg", { action: "getId", id: socket.id });
        return;
    }

    this.playerRegistry.set(socket.id, true);
    console.log(`Player ${socket.id} connected and requested ID.`);
    socket.emit("onServerMsg", { action: "getId", id: socket.id });
    socket.emit("userId", socket.id); // Keep dedicated event if client uses it
  }

  // Removed handleCreateGame, handleJoinGame, handleRollDice, handleSelectCell
  // These actions are now initiated via requestGame/requestJoinGame or sendToClients(sendDices/sendSelection)
  // and processed primarily in GameController and GameService.

  // Removed handleDisconnect as GameService handles it globally now.
}



================================================
File: backend/src/models/BoardCell.ts
================================================
// backend/src/models/BoardCell.ts

export class BoardCell {
  index: number;
  label: string;
  value: number;
  fixed: boolean;
  isNonScoreCell: boolean; // Flag for Sum, Bonus, Total cells

  constructor(index: number, label: string, isNonScoreCell: boolean = false) {
    this.index = index;
    this.label = label;
    this.value = -1; // Default to -1 (empty)
    this.fixed = false;
    this.isNonScoreCell = isNonScoreCell || label.toLowerCase() === 'sum' || label.toLowerCase().includes('bonus') || label.toLowerCase() === 'total';
  }

  // Method to serialize cell data
  toJSON(): any {
    return {
      index: this.index,
      label: this.label, // Include label for context if needed
      value: this.value,
      fixed: this.fixed,
      isNonScoreCell: this.isNonScoreCell
    };
  }

   // Static method to reconstruct from JSON
   static fromJson(data: any, defaultLabel?: string): BoardCell {
       const cell = new BoardCell(
           data.index,
           data.label ?? defaultLabel ?? `Cell ${data.index}`, // Use label from data, fallback to default or index
           data.isNonScoreCell ?? false
       );
       cell.value = data.value ?? -1;
       cell.fixed = data.fixed ?? false;
       return cell;
   }
}


================================================
File: backend/src/models/Dice.ts
================================================
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



================================================
File: backend/src/models/Game.ts
================================================
// backend/src/models/Game.ts
import { Player, PlayerFactory } from './Player';
import { v4 as uuidv4 } from 'uuid';
import { getSelectionIndex } from '../utils/yatzyMapping'; // Import for applySelection

/**
 * Game model for Yatzy
 * Encapsulates all game-related data and logic
 */
export class Game {
  // ... (existing properties) ...
  id: number;
  gameType: string;
  players: Player[];
  maxPlayers: number;
  connectedPlayers: number;
  gameStarted: boolean;
  gameFinished: boolean;
  playerToMove: number;
  diceValues: number[];
  userNames: string[];
  gameId: number;
  playerIds: string[];
  abortedPlayers: boolean[];
  rollCount: number = 0; // Add roll count
  turnNumber: number = 0; // Add turn number tracking

  constructor(id: number, gameType: string, maxPlayers: number) {
    // ... (existing constructor logic) ...
    this.id = id;
    this.gameId = id; // For backward compatibility
    this.gameType = gameType;
    this.maxPlayers = maxPlayers;
     // Initialize players correctly using the Player model/class
     this.players = new Array(maxPlayers).fill(null).map(() =>
        PlayerFactory.createEmptyPlayer(gameType) // Pass gameType to factory
     );
    this.playerIds = new Array(maxPlayers).fill(""); // For backward compatibility
    this.userNames = new Array(maxPlayers).fill(""); // For backward compatibility
    this.abortedPlayers = new Array(maxPlayers).fill(false); // No players have aborted initially
    this.connectedPlayers = 0;
    this.gameStarted = false;
    this.gameFinished = false;
    this.playerToMove = 0;
    this.diceValues = []; // Initialize dice values array
    this.rollCount = 0; // Initialize roll count
    this.turnNumber = 1; // Start at turn 1
  }

  // ... (addPlayer, removePlayer, markPlayerAborted, etc.) ...
  addPlayer(player: Player, position: number = -1): boolean {
    if (this.connectedPlayers >= this.maxPlayers && position === -1) {
      return false;
    }
    const playerPosition = position !== -1 ? position : this.findEmptySlot();
    if (playerPosition === -1) {
      return false;
    }

    // Ensure player object is fully initialized if coming from factory
    this.players[playerPosition] = player; // Player object now includes score data
    this.playerIds[playerPosition] = player.id;
    this.userNames[playerPosition] = player.username;
    this.connectedPlayers++;
    this.abortedPlayers[playerPosition] = false; // Ensure not marked as aborted on join
    player.isActive = true; // Ensure player is active on join

    return true;
  }

   removePlayer(playerId: string): boolean {
     const playerIndex = this.findPlayerIndex(playerId);
     if (playerIndex === -1 || !this.players[playerIndex]?.isActive) { // Check if already inactive or player doesn't exist
       return false; // Player not found or already removed/inactive
     }

     console.log(`🔌 Removing player ${playerId} (index ${playerIndex}) from game ${this.id}`);

     // Mark player as inactive but keep data
     this.players[playerIndex].isActive = false;
     this.abortedPlayers[playerIndex] = true; // Mark as aborted
     // Keep playerIds and userNames for historical data/logs, but decrement connected count
     this.connectedPlayers--;


     // Game logic adjustments after removal
      if (!this.gameFinished) {
         // If the removed player was the current one to move, advance turn
         if (this.playerToMove === playerIndex) {
           console.log(`-> Player ${playerIndex} was current, advancing turn.`);
           this.advanceToNextActivePlayer(); // This handles finding the *next* active one
         }

         // Check if the game should end now (e.g., only one player left in multiplayer)
         const activePlayersCount = this.players.filter(p => p?.isActive).length; // Add null check
         if (this.maxPlayers > 1 && activePlayersCount <= 1) {
           console.log(`-> Only ${activePlayersCount} player(s) left, marking game ${this.id} as finished.`);
           this.gameFinished = true;
           // GameService will call handleGameFinished which logs end state
         } else if (this.maxPlayers === 1 && activePlayersCount === 0) {
             console.log(`-> Single player left, marking game ${this.id} as finished.`);
             this.gameFinished = true;
         }
      }


     return true;
   }


   markPlayerAborted(playerId: string): boolean {
       // This might be slightly redundant with removePlayer, ensure consistency
       const playerIndex = this.findPlayerIndex(playerId);
       if (playerIndex === -1) return false;

       if (this.players[playerIndex]?.isActive) { // Only act if they were active (add null check)
           this.players[playerIndex].isActive = false;
           this.abortedPlayers[playerIndex] = true;
           this.connectedPlayers--; // Decrement count only if they were active

           if (!this.gameFinished) {
                if (this.playerToMove === playerIndex) {
                    this.advanceToNextActivePlayer();
                }
                const activePlayersCount = this.players.filter(p => p?.isActive).length; // Add null check
                 if (this.maxPlayers > 1 && activePlayersCount <= 1) {
                     this.gameFinished = true;
                 } else if (this.maxPlayers === 1 && activePlayersCount === 0) {
                    this.gameFinished = true;
                 }
           }
       }
       return true;
   }

   /**
    * Find the index of a player by ID
    * @param playerId Player ID to find
    * @returns Player index or -1 if not found
    */
   findPlayerIndex(playerId: string): number {
     return this.players.findIndex(player => player?.id === playerId); // Add null check
   }

   /**
    * Find next available empty slot
    * @returns Index of empty slot or -1 if game is full
    */
   private findEmptySlot(): number {
     return this.players.findIndex(player => !player || !player.isActive || player.id === ""); // Add null check
   }

   /**
    * Check if game is full based on connected players
    */
   isGameFull(): boolean {
     return this.connectedPlayers >= this.maxPlayers;
   }

  // --- Additions ---
  getCurrentTurnNumber(): number {
    return this.turnNumber;
  }

  incrementRollCount(): void {
    this.rollCount++;
  }

  advanceToNextActivePlayer(): void {
    if (this.gameFinished) return; // Don't advance if game over

    const startingPlayer = this.playerToMove;
    let nextPlayer = startingPlayer;
    let checkedAll = false;

    do {
      nextPlayer = (nextPlayer + 1) % this.maxPlayers;
      if (nextPlayer === startingPlayer) {
        checkedAll = true; // We've looped back
      }
      // Found an active player who hasn't aborted
      if (this.players[nextPlayer]?.isActive && !this.abortedPlayers[nextPlayer]) { // Add null check
          this.playerToMove = nextPlayer;
          this.rollCount = 0; // Reset roll count for the new player
          // Increment turn number when looping back to the first player (or initial player)
          if (nextPlayer <= startingPlayer) { // Check if we wrapped around
              this.turnNumber++;
              console.log(`-> Advancing to turn ${this.turnNumber}`);
          }
          console.log(`-> Advanced turn to player ${this.playerToMove}`);
          return; // Exit after finding the next player
      }
    } while (!checkedAll);

    // If we exit the loop, it means no active players were found (or only one left and it was the current one)
    console.log(`-> No *other* active players found. Game might be finished or stuck.`);
     // Check again if the game should be finished based on active players
     const activePlayersCount = this.players.filter(p => p?.isActive).length; // Add null check
     if (activePlayersCount <= (this.maxPlayers > 1 ? 1 : 0)) {
         this.gameFinished = true;
         console.log(`-> Marking game ${this.id} finished as no other active players found.`);
     } else {
         // If the current player is the *only* active one left, they keep playing?
         // Or game ends? Let's assume they keep playing if solo or last one standing.
         this.rollCount = 0; // Reset rolls for their next turn action
         // Do NOT increment turn number here if it's the same player
         console.log(`-> Player ${this.playerToMove} continues turn (last active?).`);
     }
  }

  // Applies the selection and score to the player's board
  applySelection(playerIndex: number, selectionLabel: string, score: number): void {
      const cellIndex = getSelectionIndex(this.gameType, selectionLabel);
      if (cellIndex !== -1 && playerIndex >= 0 && playerIndex < this.players.length) {
          const player = this.players[playerIndex];
          if (player && !player.cells[cellIndex]?.fixed) { // Add null checks
              player.cells[cellIndex].value = score;
              player.cells[cellIndex].fixed = true;
              console.log(`-> Applied score ${score} to cell '${selectionLabel}' (index ${cellIndex}) for player ${playerIndex}`);
              // Recalculate player scores
              player.calculateScores(); // Uses internal gameType
          } else {
              console.warn(`-> Attempted to apply score to already fixed cell '${selectionLabel}' or invalid player/cell for player ${playerIndex}`);
          }
      } else {
           console.error(`-> Failed to apply selection: Invalid index (${cellIndex}) or playerIndex (${playerIndex}) for label '${selectionLabel}'`);
      }
  }

  // Check if the game is finished (all active players have filled their boards)
  isGameFinished(): boolean {
      if (this.gameFinished) return true; // Already marked
      // Check if all *active* players have completed their boards
      const activePlayers = this.players.filter(p => p?.isActive); // Add null check
      if (!activePlayers.length) { // Use length check
          // No active players left, game is finished (or maybe aborted)
          this.gameFinished = true; // Mark finished if no active players
          return true;
      }
      // Check if every active player has finished their cells
      this.gameFinished = activePlayers.every(p => p.hasCompletedGame());
      return this.gameFinished;
  }


  // --- Existing methods modified/checked ---
  setDiceValues(values: number[]): void {
    if (!values || values.length !== 5) {
      console.error('Invalid dice values - must be array of 5 numbers');
      this.diceValues = [0, 0, 0, 0, 0];
    } else {
      this.diceValues = [...values];
    }
    // Do not reset rollCount here, incrementRollCount handles it
  }


   toJSON(): any {
     // Ensure player data includes scores if needed by client
     const playersData = this.players.map(player => player ? player.toJSON() : null); // Use player's toJSON, handle null

     return {
       gameId: this.id,
       gameType: this.gameType,
       nrPlayers: this.maxPlayers, // Represents max capacity
       connected: this.connectedPlayers, // Represents current connected/active
       playerIds: this.playerIds, // Keep for compatibility if needed
       userNames: this.userNames, // Keep for compatibility if needed
       players: playersData, // Send structured player data
       gameStarted: this.gameStarted,
       gameFinished: this.isGameFinished(), // Use method to check status
       playerToMove: this.playerToMove,
       diceValues: this.diceValues,
       rollCount: this.rollCount, // Send current roll count
       turnNumber: this.turnNumber, // Send current turn number
       abortedPlayers: this.abortedPlayers
     };
   }


  static fromJSON(data: any): Game {
      const game = new Game(
          data.gameId,
          data.gameType,
          data.nrPlayers
      );
      // Populate game state from JSON
      game.gameStarted = data.gameStarted ?? false;
      game.gameFinished = data.gameFinished ?? false;
      game.playerToMove = data.playerToMove ?? 0;
      game.connectedPlayers = data.connected ?? 0;
      game.diceValues = data.diceValues ? [...data.diceValues] : []; // Ensure array copy
      game.rollCount = data.rollCount ?? 0;
      game.turnNumber = data.turnNumber ?? 1;
      game.abortedPlayers = data.abortedPlayers ? [...data.abortedPlayers] : new Array(data.nrPlayers).fill(false); // Ensure array copy

      // Reconstruct players from 'players' array if present, else fallback
      if (data.players && Array.isArray(data.players)) {
          for (let i = 0; i < game.maxPlayers; i++) {
              if (i < data.players.length && data.players[i]) { // Check if player data exists
                  // Use Player.fromJSON
                  game.players[i] = Player.fromJSON(data.players[i], game.gameType); // Pass gameType
                  // Update compatibility arrays
                  game.playerIds[i] = game.players[i].id;
                  game.userNames[i] = game.players[i].username;
              } else {
                  // If no data for this slot, ensure it's an empty player
                  game.players[i] = PlayerFactory.createEmptyPlayer(game.gameType);
                  game.playerIds[i] = "";
                  game.userNames[i] = "";
              }
          }
          // Recalculate connected players based on reconstructed state
          game.connectedPlayers = game.players.filter(p => p?.isActive).length; // Add null check

      } else if (data.playerIds && data.userNames) { // Fallback to old format
          for (let i = 0; i < data.nrPlayers; i++) {
              if (data.playerIds[i] && data.playerIds[i] != "") {
                  // Create Player with minimal data, score cells might be missing
                  game.players[i] = PlayerFactory.createPlayer(data.playerIds[i], data.userNames[i], game.gameType); // Pass gameType
                  game.players[i].isActive = !game.abortedPlayers[i]; // Set active based on aborted status
                  game.playerIds[i] = data.playerIds[i];
                  game.userNames[i] = data.userNames[i];
              } else {
                  game.players[i] = PlayerFactory.createEmptyPlayer(game.gameType);
                  game.playerIds[i] = "";
                  game.userNames[i] = "";
              }
          }
           // Recalculate connected players based on reconstructed state
          game.connectedPlayers = game.players.filter(p => p?.isActive).length; // Add null check
      }


      return game;
  }


}

// --- Helper method declarations for external use (e.g., GameService) ---
// These tell TypeScript that these methods exist on the Game class instance.
// They don't provide the implementation here.
declare module './Game' {
  interface Game {
    getCurrentTurnNumber(): number;
    incrementRollCount(): void;
    applySelection(playerIndex: number, selectionLabel: string, score: number): void;
    isGameFinished(): boolean;
  }
}

// Add declarations for Player methods if GameService needs them directly
// (Though it's better if GameService interacts via Game instance methods)
// declare module './Player' {
//     interface Player {
//         getScore(): number;
//         hasCompletedGame(): boolean;
//     }
// }



================================================
File: backend/src/models/Player.ts
================================================
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



================================================
File: backend/src/routes/getLogRoute.ts
================================================
import * as jwt from "jsonwebtoken";
import { getDbConnection } from "../db";

export const getLogRoute = {
  path: "/api/getLog/:userId",
  method: "get",
  handler: async (req, res) => {
    const { authorization } = req.headers;
    const { userId } = req.params;

    console.log("in getLogRoute", userId);
    if (!authorization) {
      console.log("No auth");
      return res.status(401).json({ message: "No authorization header sent" });
    }

    const token = authorization.split(" ")[1];

    jwt.verify(token, process.env.JWT_SECRET, async (err, decoded) => {
      console.log("token ver");
      if (err)
        return res.status(401).json({ message: "Unable to verify token" });
      console.log("token verified");
      const { id } = decoded;

      if (id !== userId) {
        console.log("id mismatch");
        return res
          .status(403)
          .json({ message: "Not allowed to update that user's data" });
      }

      const db = getDbConnection("react-auth-db");

      const cursor = db.collection("logs").find({ insertedId: userId });
      const result = await cursor.toArray();
      console.log("result ", result);
      res.status(200).json(result);
    });
  },
};



================================================
File: backend/src/routes/getTopScores.ts
================================================
//import jwt from "jsonwebtoken";
import { getDbConnection } from "../db";

export const getTopScores = {
  path: "/GetTopScores",
  method: "get",
  handler: async (req, res) => {
    //console.log(req.query.count);

    const db = getDbConnection("top-scores");

    var results;
    try {

      // --- Simplification: Validate game type ---
    const requestedType = req.query.type as string;
    if (!['Ordinary', 'Mini', 'Maxi'].includes(requestedType)) {
        console.warn(`[getTopScores Route] Invalid game type requested: ${requestedType}`);
        return res.status(400).json({ message: `Invalid game type: ${requestedType}` });
    }
    // --- End Simplification ---
      switch (req.query.type) {
        case "Ordinary": {
          console.log("getting ordinary game topscores");
          results = await db
            .collection("ordinary")
            .find({}, { projection: { _id: 0 } })
            .sort({ score: -1 })
            .toArray();
          break;
        }

        case "Mini": {
          results = await db
            .collection("mini")
            .find({}, { projection: { _id: 0 } })
            .sort({ score: -1 })
            .toArray();
          break;
        }

        case "Maxi": {
          results = await db
            .collection("maxi")
            .find({}, { projection: { _id: 0 } })
            .sort({ score: -1 })
            .toArray();
          break;
        }
      }

      //console.log("result ", results);
      res.status(200).json(results);
    } catch (e) {
      console.log(e);
      res.sendStatus(500);
    }
  },
};



================================================
File: backend/src/routes/index.ts
================================================
import { logInRoute } from "./logInRoute";
import { logRoute } from "./logRoute";
import { getLogRoute } from "./getLogRoute";
import { signUpRoute } from "./signUpRoute";
import { getTopScores } from "./getTopScores";
import { updateTopScore } from "./updateTopScore";

export const routes = () => {
  return [
    logRoute,
    getLogRoute,
    logInRoute,
    signUpRoute,
    getTopScores,
    updateTopScore,
  ];
};



================================================
File: backend/src/routes/logInRoute.ts
================================================
import * as bcrypt from "bcrypt";
import * as jwt from "jsonwebtoken";
import { getDbConnection } from "../db";

export const logInRoute = {
  path: "/api/login",
  method: "post",
  handler: async (req, res) => {
    const { email, password } = req.body;

    const db = getDbConnection("react-auth-db");
    const user = await db.collection("users").findOne({ email });

    if (!user) return res.sendStatus(401);

    const { _id: id, isVerified, passwordHash, info } = user;

    const isCorrect = await bcrypt.compare(password, passwordHash);

    if (isCorrect) {
      jwt.sign(
        { id, isVerified, email, info },
        process.env.JWT_SECRET,
        { expiresIn: "2d" },
        (err, token) => {
          if (err) {
            res.status(500).json(err);
          } else {
            res.status(200).json({ token });
          }
        }
      );
    } else {
      res.sendStatus(401);
    }
  },
};



================================================
File: backend/src/routes/logRoute.ts
================================================
import * as jwt from "jsonwebtoken";
import { getDbConnection } from "../db";

export const logRoute = {
  path: "/api/log/:userId",
  method: "post",
  handler: async (req, res) => {
    const { authorization } = req.headers;
    const { userId } = req.params;
    const activity = req.body;

    console.log("in logRoute", activity, userId);
    if (!authorization) {
      console.log("No auth");
      return res.status(401).json({ message: "No authorization header sent" });
    }

    const token = authorization.split(" ")[1];

    jwt.verify(token, process.env.JWT_SECRET, async (err, decoded) => {
      console.log("token ver");
      if (err)
        return res.status(401).json({ message: "Unable to verify token" });
      console.log("token verified");
      const { id } = decoded;

      if (id !== userId) {
        console.log("id mismatch");
        return res
          .status(403)
          .json({ message: "Not allowed to update that user's data" });
      }

      const db = getDbConnection("react-auth-db");

      const result = await db
        .collection("logs")
        .findOneAndUpdate(
          { insertedId: userId },
          { $push: { log: activity } as any },
          { upsert: true, returnDocument: 'after' }
        );
      console.log("result ", result);
      res.status(200).json(result);
    });
  },
};



================================================
File: backend/src/routes/signUpRoute.ts
================================================
import * as bcrypt from "bcrypt";
import * as jwt from "jsonwebtoken";
import { getDbConnection } from "../db";

export const signUpRoute = {
  path: "/api/signup",
  method: "post",
  handler: async (req, res) => {
    const { email, password } = req.body;

    const db = getDbConnection("react-auth-db");
    const user = await db.collection("users").findOne({ email });
    console.log(user);
    if (user) {
      return res.sendStatus(409);
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const startingInfo = {
      hairColor: "",
      favoriteFood: "",
      bio: "",
    };

    const result = await db.collection("users").insertOne({
      email,
      passwordHash,
      info: startingInfo,
      isVerified: false,
    });

    const { insertedId } = result;

    await db.collection("logs").insertOne({
      insertedId: insertedId,
      log: [],
    });

    jwt.sign(
      {
        id: insertedId,
        email,
        info: startingInfo,
        isVerified: false,
      },
      process.env.JWT_SECRET,
      {
        expiresIn: "2d",
      },
      (err, token) => {
        if (err) {
          return res.status(500).send(err);
        }
        res.status(200).json({ token });
      }
    );
  },
};



================================================
File: backend/src/routes/spectateGameRoute.ts
================================================
// backend/src/routes/spectateGameRoute.ts
import { Request, Response } from 'express'; // Import Request and Response types
import { GameService } from '../services/GameService'; // Adjust path as needed
import { GameLogService } from '../services/GameLogService'; // Adjust path as needed
import { getDbConnection } from "../db"; // If needed for direct DB access (shouldn't be)

// Temporary way to access services - proper DI would be better
let gameServiceInstance: GameService;
let gameLogServiceInstance: GameLogService;

export const initializeSpectateRoute = (gs: GameService, gls: GameLogService) => {
    gameServiceInstance = gs;
    gameLogServiceInstance = gls;
};


export const spectateGameRoute = {
  path: "/api/spectate/:gameId",
  method: "get", // Keep as string for Express compatibility
  handler: async (req: Request, res: Response) => { // Add types for req and res
    const gameIdParam = req.params.gameId;
    const gameId = parseInt(gameIdParam, 10);

    console.log(`📝 HTTP spectate request for game ID: ${gameIdParam} (${gameId})`);
    console.log(`📝 Request details: IP: ${req.ip}, User-Agent: ${req.headers['user-agent']}`);

    if (isNaN(gameId)) {
        console.error(`❌ Invalid game ID format: ${gameIdParam}`);
        return res.status(400).json({ message: "Invalid game ID format." });
    }

    if (!gameServiceInstance || !gameLogServiceInstance) {
        console.error("❌ Spectate route services not initialized!");
        return res.status(500).json({ message: "Server error: Services not available." });
    }

    try {
        // 1. Get current game state from memory
        console.log(`📝 Fetching game ${gameId} from memory...`);
        const game = gameServiceInstance.getGame(gameId);
        
        if (game) {
            console.log(`✅ Game ${gameId} found in memory. Status: ${game.gameStarted ? 'Started' : 'Not Started'}, Players: ${game.players.length}`);
            // Force recalculate player scores to ensure all cells are updated
            for (const player of game.players) {
                if (player && player.isActive) {
                    player.calculateScores();
                    
                    // Debug log player cell values
                    console.log(`📝 Player ${player.username} cell values:`);
                    for (const cell of player.cells) {
                        if (cell && cell.fixed) {
                            console.log(`   - ${cell.label}: ${cell.value}`);
                        }
                    }
                }
            }
        } else {
            console.log(`⚠️ Game ${gameId} not found in memory`);
        }
        
        const currentGameState = game ? game.toJSON() : null; // Get serializable state

        // 2. Get game log from database
        console.log(`📝 Fetching game ${gameId} log from database...`);
        const gameLog = await gameLogServiceInstance.getGameLog(gameId);

        if (gameLog) {
            console.log(`✅ Game ${gameId} log found in database with ${gameLog.moves.length} moves`);
            // Log selection moves for debugging
            const selections = gameLog.moves.filter(move => move.action === 'select');
            if (selections.length > 0) {
                console.log(`📝 Selection moves in database for game ${gameId}:`);
                selections.forEach(move => {
                    console.log(`   - Player ${move.playerIndex} selected ${move.selectionLabel} for ${move.score} points`);
                });
            } else {
                console.log(`⚠️ No selection moves found in database for game ${gameId}`);
            }
        } else {
            console.log(`⚠️ No game log found in database for game ${gameId}`);
        }

        if (!currentGameState && !gameLog) {
            console.error(`❌ Game ${gameId} not found in memory or logs`);
            return res.status(404).json({ message: "Game not found in memory or logs." });
        }

        // 3. Combine and respond
        const response = {
            message: `Spectate data for game ${gameId}`,
            currentGameStatus: game ? (game.gameFinished ? 'Finished' : (game.gameStarted ? 'Ongoing' : 'Waiting')) : (gameLog ? 'Finished/Logged' : 'Unknown'), // More detailed status
            currentGameState: currentGameState, // State from memory (might be null if game ended/removed)
            gameLog: gameLog // Full log from DB
        };
        
        console.log(`📤 Sending response for game ${gameId}: Status=${response.currentGameStatus}, Has state=${!!response.currentGameState}, Has log=${!!response.gameLog}`);
        
        // Log the actual data being sent (cell values)
        if (currentGameState && currentGameState.players && currentGameState.players.length > 0) {
            const player = currentGameState.players[0];
            if (player && player.cells) {
                console.log(`📤 Cell values in response for game ${gameId}:`);
                player.cells.forEach(cell => {
                    if (cell && cell.value !== -1 && cell.fixed) {
                        console.log(`   - ${cell.label}: ${cell.value}`);
                    }
                });
            }
        }
        
        res.status(200).json(response);

    } catch (error) {
        console.error(`❌ Error handling spectate request for game ${gameId}:`, error);
        res.status(500).json({ message: "An error occurred while fetching spectator data." });
    }
  },
};

// Ensure initializeSpectateRoute is called in server.ts *after* services are created


================================================
File: backend/src/routes/updateTopScore.ts
================================================
//import jwt from "jsonwebtoken";
import { getDbConnection } from "../db";
// --- Simplification: Import TopScoreService to trigger broadcast ---
// Assuming TopScoreService is initialized and accessible, e.g., via dependency injection or a singleton pattern
// If not easily accessible, this route would *not* broadcast updates. The service-based update is preferred.
// For now, we'll comment this out as direct service access isn't set up here.
// import { topScoreServiceInstance } from '../server'; // Example of how it might be accessed

export const updateTopScore = {
  path: "/UpdateTopScore" ,
  method: "post",
  handler: async (req, res) => {
    const db = getDbConnection("top-scores");

    var results = [];
    try {

      // --- Simplification: Validate game type ---
    const requestedType = req.body.type as string;
    if (!['Ordinary', 'Mini', 'Maxi'].includes(requestedType)) {
        console.warn(`[updateTopScore Route] Invalid game type requested: ${requestedType}`);
        return res.status(400).json({ message: `Invalid game type: ${requestedType}` });
    }
    // --- End Simplification ---

    const collectionName = requestedType.charAt(0).toLowerCase() + requestedType.slice(1);
    const collection = db.collection(collectionName);

    await collection.insertOne({ name: req.body.name, score: req.body.score });
    results = await collection
        .find({}, { projection: { _id: 0 } })
        .sort({ score: -1 })
        .toArray();

      // --- Simplification: Broadcasting should ideally happen via the Service ---
        // If topScoreServiceInstance is available:
        // await topScoreServiceInstance.broadcastTopScores();
        // Otherwise, the broadcast won't happen via this HTTP route. Clients relying
        // on the WebSocket update ('onTopScoresUpdate') are preferred.
      res.status(200).json(results);
    } catch (e) {
      console.log(e);
      res.sendStatus(500);
    }
  },
};



================================================
File: backend/src/services/GameLogService.ts
================================================
// backend/src/services/GameLogService.ts

import { Collection } from 'mongodb';
import { getDbConnection } from '../db';
import { Game } from '../models/Game'; // Assuming Game model is in models/Game.ts

const DB_NAME = 'yatzy-game-log-db';
const COLLECTION_NAME = 'game_moves';

export interface GameMove {
  turnNumber: number;
  playerIndex: number;
  playerId: string;
  action: 'roll' | 'select' | 'regret' | 'extraMove' | 'disconnect' | 'spectate';
  diceValues?: number[];
  keptDice?: boolean[]; // For rolls
  selectionLabel?: string; // For selections
  score?: number; // For selections
  spectatorName?: string; // For spectate action
  timestamp: Date;
}

export interface GameLog {
  gameId: number;
  gameInfo: {
    gameType: string;
    nrPlayers: number;
    playerUsernames: string[];
    playerIds: string[]; // Store original IDs for reference
    startTime: Date;
  };
  moves: GameMove[];
  endTime?: Date;
  finalScores?: { username: string; score: number }[];
}

export class GameLogService {
  getCollection(): Collection<GameLog> {
    const db = getDbConnection(DB_NAME);
    return db.collection<GameLog>(COLLECTION_NAME);
  }
  
  getDatabaseName(): string {
    return DB_NAME;
  }
  
  getCollectionName(): string {
    return COLLECTION_NAME;
  }

  async logGameStart(game: Game): Promise<void> {
    console.log(`[GameLogService] Logging start for game ${game.id}`);
    const collection = this.getCollection();
    const gameLog: GameLog = {
      gameId: game.id,
      gameInfo: {
        gameType: game.gameType,
        nrPlayers: game.maxPlayers,
        playerUsernames: game.players.map(p => p.username),
        playerIds: game.players.map(p => p.id), // Store initial IDs
        startTime: new Date(),
      },
      moves: [],
    };
    try {
      // Use replaceOne with upsert: true, which is semantically similar to updateOne with $set for the whole doc
      await collection.replaceOne(
        { gameId: game.id },
        gameLog, // Pass the full replacement document
        { upsert: true }
      );
    } catch (error) {
      console.error(`[GameLogService] Error logging game start for ${game.id}:`, error);
    }
  }

  async logMove(gameId: number, move: GameMove): Promise<void> {
     console.log(`[GameLogService] Logging move for game ${gameId}:`, move.action);
     if (move.action === 'select') {
         console.log(`   Selection: ${move.selectionLabel}, Score: ${move.score}`);
     } else if (move.action === 'roll') {
         console.log(`   Dice: ${move.diceValues}, Kept: ${move.keptDice}`);
     }
     
     // Debug info about the database and collection
     console.log(`[GameLogService] 📊 Using database '${DB_NAME}' and collection '${COLLECTION_NAME}'`);
     
     // Directly check MongoDB connection
     try {
       const db = getDbConnection(DB_NAME);
       console.log(`[GameLogService] ✅ Successfully connected to database '${DB_NAME}'`);
     } catch (e) {
       console.error(`[GameLogService] ❌ Error connecting to database '${DB_NAME}':`, e);
       return; // Exit early if we can't connect
     }
     
     // Check if the game exists in the database first
     const collection = this.getCollection();
     try {
       // First check if the game exists
       console.log(`[GameLogService] 🔍 Checking if game ${gameId} exists in database...`);
       const gameExists = await collection.findOne({ gameId: gameId });
       
       if (!gameExists) {
         console.log(`[GameLogService] ⚠️ Game ${gameId} not found in database. Creating game log entry before adding move.`);
         // Create a placeholder game log if it doesn't exist
         const placeholderGameLog: GameLog = {
           gameId: gameId,
           gameInfo: {
             gameType: 'Unknown', // Will be updated later
             nrPlayers: 0, // Will be updated later
             playerUsernames: [],
             playerIds: [],
             startTime: new Date(),
           },
           moves: [],
         };
         
         console.log(`[GameLogService] 📝 Inserting placeholder game log for game ${gameId}...`);
         try {
           const insertResult = await collection.insertOne(placeholderGameLog);
           console.log(`[GameLogService] ✅ Created placeholder log for game ${gameId}, insertedId: ${insertResult.insertedId}`);
         } catch (insertError) {
           console.error(`[GameLogService] ❌ Error creating placeholder log for game ${gameId}:`, insertError);
           // Try to continue anyway
         }
       } else {
         console.log(`[GameLogService] ✅ Game ${gameId} found in database with ${gameExists.moves?.length || 0} moves`);
       }
       
       // Now add the move
       console.log(`[GameLogService] 📝 Adding move to game ${gameId}...`);
       console.log(`[GameLogService] 📝 Move details: action=${move.action}, playerIndex=${move.playerIndex}, timestamp=${move.timestamp}`);
       
       const updateQuery = { gameId: gameId };
       const updateOperation = { $push: { moves: move } };
       
       console.log(`[GameLogService] 📝 Update query:`, JSON.stringify(updateQuery));
       console.log(`[GameLogService] 📝 Update operation:`, JSON.stringify(updateOperation));
       
       const result = await collection.updateOne(updateQuery, updateOperation);
       
       console.log(`[GameLogService] 📝 Move added to database: matched=${result.matchedCount}, modified=${result.modifiedCount}`);
       
       if (result.matchedCount === 0) {
         console.log(`[GameLogService] ⚠️ No document matched for game ${gameId}. Double-checking...`);
         const recheck = await collection.findOne({ gameId: gameId });
         console.log(`[GameLogService] 🔍 Recheck result: ${recheck ? 'Game found' : 'Game not found'}`);
         
         if (!recheck) {
           console.log(`[GameLogService] ⚠️ Trying one more time to create game log...`);
           const placeholderGameLog: GameLog = {
             gameId: gameId,
             gameInfo: {
               gameType: 'Unknown',
               nrPlayers: 0,
               playerUsernames: [],
               playerIds: [],
               startTime: new Date(),
             },
             moves: [move], // Include this move directly
           };
           
           try {
             const insertResult = await collection.insertOne(placeholderGameLog);
             console.log(`[GameLogService] ✅ Created new log with move for game ${gameId}, insertedId: ${insertResult.insertedId}`);
           } catch (insertError) {
             console.error(`[GameLogService] ❌ Error creating log with move for game ${gameId}:`, insertError);
           }
         }
       }
       
       // Verify the move was actually stored
       const updatedGame = await collection.findOne({ gameId: gameId });
       if (updatedGame) {
         const moveCount = updatedGame.moves?.length || 0;
         console.log(`[GameLogService] ✅ Game ${gameId} now has ${moveCount} moves in database`);
         
         // Log the last move to verify it was added correctly
         if (moveCount > 0) {
           const lastMove = updatedGame.moves[moveCount - 1];
           console.log(`[GameLogService] ✅ Last move: action=${lastMove.action}, playerIndex=${lastMove.playerIndex}`);
         }
       } else {
         console.error(`[GameLogService] ❌ Failed to find game ${gameId} after update!`);
       }
     } catch (error) {
        console.error(`[GameLogService] ❌ Error logging move for ${gameId}:`, error);
        
        // Additional error diagnostics
        console.error(`[GameLogService] ❌ Error details:`, error);
        if (error instanceof Error) {
          console.error(`[GameLogService] ❌ Error stack:`, error.stack);
        }
     }
  }

  async logGameEnd(gameId: number, finalScores: { username: string; score: number }[]): Promise<void> {
    console.log(`[GameLogService] Logging end for game ${gameId}`);
    const collection = this.getCollection();
    try {
      await collection.updateOne(
        { gameId: gameId },
        { $set: { endTime: new Date(), finalScores: finalScores } }
      );
    } catch (error) {
        console.error(`[GameLogService] Error logging game end for ${gameId}:`, error);
    }
  }


  async getGameLog(gameId: number): Promise<GameLog | null> {
    console.log(`[GameLogService] Fetching log for game ${gameId}`);
    const collection = this.getCollection();
    try {
      const gameLog = await collection.findOne({ gameId: gameId });
      
      if (gameLog) {
        console.log(`[GameLogService] Found log for game ${gameId} with ${gameLog.moves.length} moves`);
        // Log details of the moves for debugging
        if (gameLog.moves.length > 0) {
          console.log(`[GameLogService] Move details for game ${gameId}:`);
          gameLog.moves.forEach((move, index) => {
            if (move.action === 'select' && move.selectionLabel) {
              console.log(`[GameLogService] - Move #${index}: Player ${move.playerIndex} selected ${move.selectionLabel} for ${move.score} points`);
            }
          });
        }
      } else {
        console.log(`[GameLogService] No log found for game ${gameId}`);
      }
      
      return gameLog;
    } catch (error) {
      console.error(`[GameLogService] Error fetching log for ${gameId}:`, error);
      return null;
    }
  }

  /**
   * Log a spectate action
   * @param gameId Game ID
   * @param spectatorId Spectator socket ID
   * @param spectatorName Spectator name
   */
  async logSpectate(gameId: number, spectatorId: string, spectatorName: string): Promise<void> {
    console.log(`[GameLogService] Logging spectate for game ${gameId} by ${spectatorName} (${spectatorId})`);
    const game = await this.getGameLog(gameId);
    if (!game) {
      console.error(`[GameLogService] Cannot log spectate: Game ${gameId} not found`);
      return;
    }

    const spectateMove: GameMove = {
      turnNumber: game.moves.length > 0 ? game.moves[game.moves.length - 1].turnNumber : 0,
      playerIndex: -1, // -1 indicates spectator
      playerId: spectatorId,
      action: 'spectate',
      spectatorName: spectatorName,
      timestamp: new Date()
    };

    const collection = this.getCollection();
    try {
      await collection.updateOne(
        { gameId: gameId },
        { $push: { moves: spectateMove } }
      );
    } catch (error) {
      console.error(`[GameLogService] Error logging spectate for ${gameId}:`, error);
    }
  }
}


================================================
File: backend/src/services/GameService.ts
================================================
// backend/src/services/GameService.ts

import { Game } from '../models/Game';
import { Player, PlayerFactory } from '../models/Player';
import { Server, Socket } from 'socket.io'; // Import Socket type
import { GameLogService, GameMove } from './GameLogService'; // <-- Import log service and types
import { TopScoreService } from './TopScoreService'; // <-- Import TopScoreService
import { getSelectionLabel } from '../utils/yatzyMapping'; // <-- Import mapping utility

/**
 * Service for managing Yatzy games and spectators
 */
export class GameService {
  private games: Map<number, Game> = new Map();
  private spectators: Map<number, Set<string>> = new Map(); // Map<gameId, Set<spectatorId>>
  private gameIdCounter: number = 0;
  private io: Server;
  private gameLogService: GameLogService; // <-- Add log service instance
  private topScoreService: TopScoreService; // <-- Add top score service instance

  constructor(io: Server, gameLogService: GameLogService, topScoreService: TopScoreService) { // <-- Inject services
    this.io = io;
    this.gameLogService = gameLogService; // <-- Store log service instance
    this.topScoreService = topScoreService; // <-- Store top score service instance
  }

  // --- Spectator Management ---

  addSpectator(gameId: number, spectatorId: string): boolean {
    const game = this.games.get(gameId);
    if (!game || game.gameFinished) {
      console.log(`[Spectator] Cannot add spectator ${spectatorId} to non-existent or finished game ${gameId}`);
      return false; // Game doesn't exist or is finished
    }

    if (!this.spectators.has(gameId)) {
      this.spectators.set(gameId, new Set());
    }
    const gameSpectators = this.spectators.get(gameId)!; // Safe due to check above

    if (gameSpectators.has(spectatorId)) {
      console.log(`[Spectator] Spectator ${spectatorId} is already watching game ${gameId}`);
      // Optionally resend current state if needed
    } else {
        gameSpectators.add(spectatorId);
        console.log(`[Spectator] Added spectator ${spectatorId} to game ${gameId}. Total spectators: ${gameSpectators.size}`);
    }


    // Send current game state to the new spectator immediately
    const gameData = game.toJSON();
    gameData.action = 'onGameUpdate'; // Use the standard update action
    this.io.to(spectatorId).emit('onServerMsg', gameData);
    console.log(`[Spectator] Sent initial game state of game ${gameId} to new spectator ${spectatorId}`);

    return true;
  }

  removeSpectator(spectatorId: string): void {
    let removed = false;
    for (const [gameId, gameSpectators] of this.spectators.entries()) {
      if (gameSpectators.delete(spectatorId)) {
        removed = true;
        console.log(`[Spectator] Removed spectator ${spectatorId} from game ${gameId}. Remaining: ${gameSpectators.size}`);
        if (gameSpectators.size === 0) {
          this.spectators.delete(gameId);
          console.log(`[Spectator] No spectators left for game ${gameId}, removing entry.`);
        }
      }
    }
    if (removed) {
        console.log(`[Spectator] Finished removing spectator ${spectatorId} from all games.`);
    }
  }

  // --- Game Management ---

  createGame(gameType: string, maxPlayers: number): Game {
    const gameId = this.gameIdCounter++;
    const game = new Game(gameId, gameType, maxPlayers);
    this.games.set(gameId, game);
    
    // Log game start immediately after creation
    console.log(`📝 [GameService] Creating new game ${gameId} of type ${gameType} for ${maxPlayers} players`);
    this.gameLogService.logGameStart(game)
      .then(() => {
        console.log(`✅ [GameService] Successfully logged game ${gameId} creation to database`);
      })
      .catch(error => {
        console.error(`❌ [GameService] Error logging game ${gameId} creation:`, error);
      });
    
    return game;
  }

  findAvailableGame(gameType: string, maxPlayers: number): Game | null {
    for (const [_, game] of this.games) {
      if (
        game.gameType === gameType &&
        game.maxPlayers === maxPlayers &&
        !game.isGameFull() &&
        !game.gameStarted
      ) {
        return game;
      }
    }
    return null;
  }

  getGame(gameId: number): Game | undefined {
    return this.games.get(gameId);
  }

  getAllGames(): Game[] {
    return Array.from(this.games.values());
  }

  removeGame(gameId: number): boolean {
    // Potentially log game removal/completion before deleting
    const game = this.games.get(gameId);
    if (game && game.gameFinished) {
      const finalScores = game.players
        .filter(p => p?.id) // Filter out empty slots (add null check)
        .map(p => ({ username: p!.username, score: p!.getScore() })); // Assume Player has getScore() method (add non-null assertion)
      
      console.log(`📝 [GameService] Logging game ${gameId} end with scores:`, finalScores);
      this.gameLogService.logGameEnd(gameId, finalScores)
        .then(() => {
          console.log(`✅ [GameService] Successfully logged game ${gameId} end to database`);
        })
        .catch(error => {
          console.error(`❌ [GameService] Error logging game ${gameId} end:`, error);
        });
    }
    return this.games.delete(gameId);
  }

  joinGame(gameId: number, player: Player): Game | null {
    const game = this.games.get(gameId);

    if (!game || game.isGameFull() || game.gameStarted) {
      return null;
    }

    if (game.addPlayer(player)) {
      // Log game start *when the game becomes full and starts*
      if (game.isGameFull()) {
        // Check if it wasn't already started (e.g., player rejoining)
        if (!game.gameStarted) {
          game.gameStarted = true;
          // Update the existing log entry with player IDs if needed, or log an "all players joined" event
          console.log(`📝 [GameService] Game ${gameId} is now full, updating database entry`);
          this.gameLogService.logGameStart(game)
            .then(() => {
              console.log(`✅ [GameService] Successfully updated game ${gameId} with all players in database`);
            })
            .catch(error => {
              console.error(`❌ [GameService] Error updating game ${gameId} in database:`, error);
            });
        }
      }

      return game;
    }

    return null;
  }

  // Modified handlePlayerDisconnect to log the event
  handlePlayerDisconnect(playerId: string): void {
    const affectedGames: number[] = []; // Store IDs of affected games

    for (const [gameId, game] of this.games) {
      const playerIndex = game.findPlayerIndex(playerId);

      // Check if player was found and active in this game
      if (playerIndex !== -1 && game.players[playerIndex]?.isActive) { // Add null check
        console.log(`🎮 Player ${playerId} disconnected from game ${gameId}`);
        affectedGames.push(gameId);

        // Log the disconnect move
        const disconnectMove: GameMove = {
          turnNumber: game.getCurrentTurnNumber(), // Need a method in Game to track turns
          playerIndex: playerIndex,
          playerId: playerId,
          action: 'disconnect',
          timestamp: new Date(),
        };
        
        console.log(`📝 [GameService] Logging disconnect for player ${playerId} in game ${gameId}`);
        this.gameLogService.logMove(gameId, disconnectMove)
          .then(() => {
            console.log(`✅ [GameService] Successfully logged disconnect for player ${playerId} in game ${gameId}`);
          })
          .catch(error => {
            console.error(`❌ [GameService] Error logging disconnect for player ${playerId} in game ${gameId}:`, error);
          });

        // Mark the player as aborted in the game state (Game model handles internal logic)
        game.markPlayerAborted(playerId); // This method handles turn advancement if needed

        // Check if game should end (Game model's markPlayerAborted might set gameFinished)
        if (game.gameFinished) {
          console.log(`🎮 Game ${gameId} finished due to player disconnect/abort`);
          this.handleGameFinished(game); // Handle logging end and cleanup
        } else {
          // Notify remaining players about the disconnection/abort
          this.notifyGameUpdate(game);
        }
      }
    }

    // If any games were affected (player removed or game ended), broadcast the updated list
    if (affectedGames.length > 0) {
      // If games were removed inside handleGameFinished, they won't be in this.games anymore
      // Broadcast updated game list to all clients
      this.broadcastGameList();
    }

    // Also remove the disconnected user if they were a spectator
    this.removeSpectator(playerId);
  }

  broadcastGameList(): void {
    const gameList = Array.from(this.games.values())
      // Keep started games if they still have active players (or if spectator is allowed)
      // Filter out finished games explicitly if they are removed by handleGameFinished
      .filter(game => !game.gameFinished) // Filter out finished games
      .map(game => game.toJSON()); // Convert to JSON safe representation

    this.io.emit('onServerMsg', {
      action: 'onRequestGames',
      Games: gameList
    });
    console.log(`📢 Broadcasted game list: ${gameList.length} games available`);
  }

  broadcastGameListToPlayer(playerId: string): void {
    const gameList = Array.from(this.games.values())
      .filter(game => !game.gameFinished)
      .map(game => game.toJSON());

    this.io.to(playerId).emit('onServerMsg', {
      action: 'onRequestGames',
      Games: gameList
    });

    console.log(`🎮 Sent game list to player ${playerId} - ${gameList.length} games available`);
  }

  notifyGameUpdate(game: Game): void {
    const gameData = game.toJSON();

    // Determine action based on game state
    // gameData.action = game.gameStarted ? 'onGameStart' : 'onGameUpdate'; // Logic seems reversed, usually update after start? Let's use onGameUpdate generally after start.
    // Let's stick to onGameUpdate for general updates after the initial start signal
    gameData.action = 'onGameUpdate';

    console.log(`🎮 Notifying players about game ${game.id} update, action: ${gameData.action}`);

    for (let i = 0; i < game.players.length; i++) {
      const player = game.players[i];
      // Send update to active players
      if (player?.isActive && player.id) { // Add null check
        console.log(`🎮 Sending ${gameData.action} to player ${i} (${player.id})`);
        this.io.to(player.id).emit('onServerMsg', gameData);
      }
    }

    // Notify spectators
    const gameSpectators = this.spectators.get(game.id);
    if (gameSpectators && gameSpectators.size > 0) {
      console.log(`[Spectator] Notifying ${gameSpectators.size} spectators of game ${game.id} update`);
      for (const spectatorId of gameSpectators) {
        this.io.to(spectatorId).emit('onServerMsg', gameData);
      }
    }
  }

  handlePlayerStartingNewGame(playerId: string): void {
    // This function essentially forces a disconnect/abort from existing games
    console.log(`🎮 Player ${playerId} starting new game, handling potential disconnects from old games.`);
    this.handlePlayerDisconnect(playerId); // Re-use the disconnect logic
  }

  handlePlayerAbort(playerId: string): void {
    // This might be redundant if handlePlayerDisconnect covers it.
    console.log(`🎮 Player ${playerId} explicitly aborting.`);
    this.handlePlayerDisconnect(playerId); // Re-use disconnect logic which includes logging.
  }


  handleGameFinished(game: Game): void {
    console.log(`🏁 Game ${game.id} finished.`);
    // Log game end with final scores
    const finalScores = game.players
      .filter(p => p?.id) // Make sure player slot wasn't empty (add null check)
      .map(p => ({ username: p!.username, score: p!.getScore() })); // Assume Player has getScore method (add non-null assertion)
    
    console.log(`📝 [GameService] Logging game ${game.id} finish with scores:`, finalScores);
    this.gameLogService.logGameEnd(game.id, finalScores)
      .then(() => {
        console.log(`✅ [GameService] Successfully logged game ${game.id} end to database`);
      })
      .catch(error => {
        console.error(`❌ [GameService] Error logging game ${game.id} end:`, error);
      });

    // **** Update Top Scores ****
    console.log(`🏆 [GameService] Attempting to update top scores for game ${game.id} (Type: ${game.gameType})`);
    const scoreUpdatePromises = finalScores.map(playerScore => {
      if (playerScore.username && playerScore.score > 0) { // Basic check
         // Important: updateTopScore now broadcasts internally
         return this.topScoreService.updateTopScore(game.gameType, playerScore.username, playerScore.score)
           .then(success => {
              if (success) console.log(`🏆 [TopScoreService] Score update initiated for ${playerScore.username}`);
              // No need to log success here, updateTopScore handles its own logging/broadcasting
           })
           .catch(err => console.error(`❌ [TopScoreService] Error initiating score update for ${playerScore.username}:`, err));
      }
      return Promise.resolve(); // Return a resolved promise for players with no score
    });

    // Wait for all score updates to attempt broadcasting before proceeding
    Promise.all(scoreUpdatePromises).then(() => {
        console.log(`🏁 [GameService] Finished attempting top score updates for game ${game.id}.`);
        // Note: Broadcasting now happens within updateTopScore
    });
    // **************************

    // Notify all active players (and spectators) about the game finish
    this.notifyGameFinished(game);

    // Remove the game from the active games map
    this.games.delete(game.id); // Remove the game *after* notifying

    // Clean up spectators for this game
    if (this.spectators.has(game.id)) {
      console.log(`[Spectator] Removing ${this.spectators.get(game.id)?.size} spectators from finished game ${game.id}`);
      this.spectators.delete(game.id);
    }

    // Broadcast updated game list (game is removed)
    this.broadcastGameList();
  }

  notifyGameFinished(game: Game): void {
    const gameData = game.toJSON(); // Get final game state
    gameData.action = 'onGameFinished'; // Use a specific action

    console.log(`🏁 Notifying players about game ${game.id} finish`);
    for (const player of game.players) {
      if (player?.id) { // Notify even inactive players about the end? Or just active? Let's notify all who were ever part of it. (add null check)
        this.io.to(player.id).emit('onServerMsg', gameData);
      }
    }

    // Notify spectators
    const gameSpectators = this.spectators.get(game.id);
    if (gameSpectators && gameSpectators.size > 0) {
      console.log(`[Spectator] Notifying ${gameSpectators.size} spectators of game ${game.id} finish`);
      for (const spectatorId of gameSpectators) {
        this.io.to(spectatorId).emit('onServerMsg', gameData);
      }
    }
  }

  // Modified processDiceRoll to log the move
  async processDiceRoll(gameId: number, playerId: string, diceValues: number[], keptDice: boolean[], isRegret: boolean = false, isExtra: boolean = false): Promise<boolean> {
    const game = this.games.get(gameId);
    if (!game) {
      console.error(`❌ [GameService] processDiceRoll: Game ${gameId} not found`);
      return false;
    }

    const playerIndex = game.findPlayerIndex(playerId);
    if (playerIndex === -1 || playerIndex !== game.playerToMove) {
      console.error(`❌ [GameService] processDiceRoll: Invalid player ${playerId} (index ${playerIndex}) or not their turn (current: ${game.playerToMove})`);
      return false;
    }

    // --- Logging ---
    const rollMove: GameMove = {
      turnNumber: game.getCurrentTurnNumber(),
      playerIndex: playerIndex,
      playerId: playerId,
      action: 'roll',
      diceValues: [...diceValues],
      keptDice: [...keptDice],
      timestamp: new Date(),
    };

    console.log(`📝 [GameService] Logging dice roll for game ${gameId}: [${diceValues.join(', ')}]`);
    try {
      await this.gameLogService.logMove(gameId, rollMove);
      console.log(`✅ [GameService] Successfully logged dice roll for game ${gameId}`);
    } catch (error) {
      console.error(`❌ [GameService] Error logging dice roll for game ${gameId}:`, error);
    }
    // --- End Logging ---

    // --- Update Game State ---
    game.setDiceValues(diceValues);
    game.incrementRollCount();
    console.log(`🎲 [GameService] Game ${game.id} state updated: Roll ${game.rollCount}, Dice ${game.diceValues}`);
    // --- End Update Game State ---


    // --- Notify other players via onClientMsg (for potential direct dice display updates) ---
    const diceUpdateData = {
      action: 'sendDices',
      gameId: game.id,
      diceValue: diceValues,
      rollCount: game.rollCount
    };

    console.log(`🎲 Broadcasting 'sendDices' (onClientMsg) for game ${game.id}`);
    for (let i = 0; i < game.players.length; i++) {
      const player = game.players[i];
      if (player?.isActive && player.id && player.id !== playerId) {
        this.io.to(player.id).emit('onClientMsg', diceUpdateData);
      }
    }
    // --- End Notify other players ---


    // --- Notify ALL players AND spectators via onServerMsg (for full state sync) ---
    // This is the crucial addition for spectators to get updated dice/roll count
    console.log(`🔄 Notifying full game update (onServerMsg) after dice roll for game ${game.id}`);
    this.notifyGameUpdate(game);
    // --- End Notify ALL ---

    // Also send dice update to spectators via onClientMsg if needed for specific client logic
    const gameSpectators = this.spectators.get(game.id);
    if (gameSpectators && gameSpectators.size > 0) {
      console.log(`[Spectator] Sending 'sendDices' (onClientMsg) to ${gameSpectators.size} spectators`);
      for (const spectatorId of gameSpectators) {
         this.io.to(spectatorId).emit('onClientMsg', diceUpdateData);
      }
    }


    return true;
  }

  // Modified processSelection to log the move with label and score
  async processSelection(gameId: number, playerId: string, selectionLabel: string, score: number): Promise<boolean> {
    const game = this.games.get(gameId);
    if (!game) {
      console.error(`❌ [GameService] processSelection: Game ${gameId} not found`);
      return false;
    }

    const playerIndex = game.findPlayerIndex(playerId);
    if (playerIndex === -1 || playerIndex !== game.playerToMove) {
      console.error(`❌ [GameService] processSelection: Invalid player ${playerId} (index ${playerIndex}) or not their turn (current: ${game.playerToMove})`);
      return false;
    }

    console.log(`📝 [GameService] Processing selection for game ${gameId}: Player ${playerIndex} selected ${selectionLabel} for ${score} points`);

    // --- Logging ---
    const selectMove: GameMove = {
      turnNumber: game.getCurrentTurnNumber(),
      playerIndex: playerIndex,
      playerId: playerId,
      action: 'select',
      selectionLabel: selectionLabel,
      score: score, // Include the score achieved
      diceValues: [...game.diceValues], // Log the dice that led to the selection
      timestamp: new Date(),
    };
    
    console.log(`📝 [GameService] Logging selection move to database for game ${gameId}`);
    try {
      await this.gameLogService.logMove(gameId, selectMove);
      console.log(`✅ [GameService] Successfully logged selection move to database for game ${gameId}`);
      
      // Verify the move was stored
      const gameLog = await this.gameLogService.getGameLog(gameId);
      if (gameLog) {
        const selections = gameLog.moves.filter(move => move.action === 'select');
        console.log(`📊 [GameService] Game ${gameId} now has ${selections.length} selection moves in database`);
      } else {
        console.error(`❌ [GameService] Game log not found in database after logging move for game ${gameId}`);
      }
    } catch (error) {
      console.error(`❌ [GameService] Error logging selection move to database for game ${gameId}:`, error);
    }
    // --- End Logging ---

    // Apply selection in Game model
    console.log(`📝 [GameService] Applying selection to game state: ${selectionLabel} with score ${score}`);
    game.applySelection(playerIndex, selectionLabel, score);

    // Debug: Log cell values after selection
    const player = game.players[playerIndex];
    if (player && player.cells) {
      console.log(`📊 [GameService] Cell values after selection for player ${playerIndex}:`);
      for (const cell of player.cells) {
        if (cell && cell.fixed) {
          console.log(`   - ${cell.label}: ${cell.value}`);
        }
      }
    }

    // Check if game finished after this selection
    if (game.isGameFinished()) {
      console.log(`🏁 [GameService] Game ${gameId} finished after selection`);

      // **** CRUCIAL FIX: Send final update BEFORE handling finish ****
      console.log(`🔄 Notifying final game update (onServerMsg) before finishing game ${game.id}`);
      this.notifyGameUpdate(game); // Send state including the last selection
      // ***************************************************************

      this.handleGameFinished(game); // This handles logging end, notifying, removing game
    } else {
      // Clear dice for next player
      game.setDiceValues([0, 0, 0, 0, 0]);
      game.rollCount = 0;
      
      // Advance to next player
      game.advanceToNextActivePlayer();
      console.log(`🎮 [GameService] Player ${playerId} processed selection, advancing to player ${game.playerToMove}`);
      
      // Notify all players and spectators of the game update
      this.notifyGameUpdate(game);
      
      // Prepare full game state with cleared dice
      const gameData = game.toJSON();
      gameData.action = 'onGameUpdate';
      gameData.diceValues = [0, 0, 0, 0, 0];
      gameData.rollCount = 0;

      // Send to all players
      for (const player of game.players) {
        if (player?.id) {
          this.io.to(player.id).emit('onServerMsg', gameData);
        }
      }
      
      // Send to all spectators
      const spectators = this.spectators.get(game.id);
      if (spectators) {
        for (const spectatorId of spectators) {
          this.io.to(spectatorId).emit('onServerMsg', gameData);
        }
      }
    }

    return true;
  }

  // Modified forwardSelectionToPlayers to use label
  forwardSelectionToPlayers(gameId: number, senderId: string, selectionData: any): boolean {
    const game = this.games.get(gameId);
    if (!game) {
      console.log(`🎮 Cannot forward selection: Game ${gameId} not found`);
      return false;
    }

    // Ensure selectionData has the label
    if (!selectionData.selectionLabel) {
      console.error("❌ Selection data missing 'selectionLabel'");
      // Try to map from index if available (fallback for older clients?)
      if (typeof selectionData.cell === 'number') {
        selectionData.selectionLabel = getSelectionLabel(game.gameType, selectionData.cell);
        if (!selectionData.selectionLabel) return false; // Mapping failed
      } else {
        return false; // Cannot proceed without label or index
      }
    }

    console.log(`🎮 Forwarding selection for game ${gameId} from player ${senderId}: ${selectionData.selectionLabel}`);

    const messageToSend = {
      action: 'sendSelection', // Keep original action name client expects
      gameId: gameId,
      player: game.findPlayerIndex(senderId), // Send player index
      selectionLabel: selectionData.selectionLabel, // Send label
      diceValue: selectionData.diceValue, // Include dice for context
      // Include score if available in original data?
      score: selectionData.score // Assuming score might be sent by client
    };


    for (const player of game.players) {
      if (player?.isActive && player.id && player.id !== senderId) { // Add null check
        console.log(`🎮 Sending selection to player ${player.id}`);
        this.io.to(player.id).emit('onClientMsg', messageToSend);
      }
    }

    return true;
  }

  // Modified createOrJoinGame to handle logging
  createOrJoinGame(gameType: string, maxPlayers: number, player: Player): Game {
    this.handlePlayerStartingNewGame(player.id); // Handle leaving old games

    let game = this.findAvailableGame(gameType, maxPlayers);
    let isNewGame = false;

    if (!game) {
      console.log(`🎮 Creating new ${gameType} game for ${maxPlayers} players`);
      game = this.createGame(gameType, maxPlayers); // createGame now logs start implicitly
      isNewGame = true;
    } else {
      console.log(`🎮 Found existing game ${game.id} for player ${player.id} to join`);
    }

    game.addPlayer(player);

    // Update log if it's an existing game being joined
    if (!isNewGame) {
      console.log(`📝 [GameService] Updating existing game ${game.id} in database with new player ${player.id}`);
      this.gameLogService.logGameStart(game) // This updates the log with current players
        .then(() => {
          console.log(`✅ [GameService] Successfully updated game ${game.id} with new player in database`);
        })
        .catch(error => {
          console.error(`❌ [GameService] Error updating game ${game.id} in database:`, error);
        });
    }

    const activeCount = game.players.filter(p => p?.isActive).length; // Add null check

    if (game.isGameFull()) {
      if (activeCount === maxPlayers) {
        if (!game.gameStarted) { // Only set and log if it wasn't already started
          game.gameStarted = true;
          console.log(`🎮 Game ${game.id} started with ${activeCount} active players`);
          // Log an event indicating the game actually started? Optional.
          // this.gameLogService.logMove(game.id, { turnNumber: 0, playerIndex: -1, playerId: '', action: 'game_start_full', timestamp: new Date() });

          // Re-log start to ensure player list is up-to-date in the log and mark started
          console.log(`📝 [GameService] Marking game ${game.id} as started in database`);
          this.gameLogService.logGameStart(game) // Updates game log with started status and players
            .then(() => {
              console.log(`✅ [GameService] Successfully marked game ${game.id} as started in database`);
            })
            .catch(error => {
              console.error(`❌ [GameService] Error marking game ${game.id} as started in database:`, error);
            });
        }
      } else {
        console.log(`🎮 Game ${game.id} has ${activeCount}/${maxPlayers} active players, waiting`);
      }
    } else {
      console.log(`🎮 Game ${game.id} has ${game.connectedPlayers}/${maxPlayers} connected, waiting`);
    }

    // Notify players (onServerMsg includes game state)
    // Send 'onGameStart' specifically if the game just started, otherwise 'onGameUpdate'
    if (game.gameStarted && activeCount === maxPlayers) {
      const gameData = game.toJSON();
      gameData.action = 'onGameStart'; // Override action for initial start
      console.log(`🎮 Sending explicit onGameStart for game ${game.id}`);
      for (const p of game.players) {
        if (p?.isActive && p.id) { // Add null check
          this.io.to(p.id).emit('onServerMsg', gameData);
        }
      }
    } else {
      // Send general update if game not starting right now
      this.notifyGameUpdate(game);
    }

    this.broadcastGameList(); // Broadcast updated list

    return game; // <-- Ensure game is returned
  }


}

// Add helper methods to Game model if they don't exist
// These declarations inform TypeScript about methods implemented in Game.ts
declare module '../models/Game' {
  interface Game {
    getCurrentTurnNumber(): number;
    incrementRollCount(): void;
    applySelection(playerIndex: number, selectionLabel: string, score: number): void;
    isGameFinished(): boolean;
    advanceToNextActivePlayer(): void; // Added this declaration as it's used
  }
}

// Add getScore to Player model if it doesn't exist
// This declaration informs TypeScript about the method implemented in Player.ts
declare module '../models/Player' {
  interface Player {
    getScore(): number;
  }
}


================================================
File: backend/src/services/TopScoreService.ts
================================================
// backend/src/services/TopScoreService.ts
import { Collection, Db } from 'mongodb';
import { getDbConnection } from '../db';
import { Server } from 'socket.io';

const DB_NAME = 'top-scores';

// Define the supported game types explicitly
const SUPPORTED_GAME_TYPES = ["Mini", "Ordinary", "Maxi"];

interface TopScoreEntry {
  name: string;
  score: number;
}

export class TopScoreService {
  private io: Server;

  constructor(io: Server) {
    this.io = io;
  }

  private getDb(): Db {
    return getDbConnection(DB_NAME);
  }

  private getCollection(gameType: string): Collection<TopScoreEntry> {

    // --- Simplification: Check if type is supported ---
    if (!SUPPORTED_GAME_TYPES.includes(gameType)) {
         console.warn(`[TopScoreService] Unsupported game type requested for collection: ${gameType}`);
         return null;
    }
    // --- End Simplification ---
    const db = this.getDb();
    // Normalize collection name (e.g., MaxiR3 -> maxiR3)
    const collectionName = gameType.charAt(0).toLowerCase() + gameType.slice(1);
    return db.collection<TopScoreEntry>(collectionName);
  }

  /**
   * Gets the top scores for a given game type.
   * @param gameType - The type of game (e.g., "Ordinary", "MaxiR3").
   * @param limit - Optional maximum number of scores to return.
   * @returns An array of top score entries.
   */
  async getTopScores(gameType: string, limit?: number): Promise<TopScoreEntry[]> {
    try {
      // Ensure the game type is supported before querying
      if (!SUPPORTED_GAME_TYPES.includes(gameType)) {
         console.warn(`[TopScoreService] Attempted to get scores for unsupported game type: ${gameType}`);
         return [];
      }
      const collection = this.getCollection(gameType);
      // --- Simplification: Handle null collection ---
     if (!collection) {
          return []; // Return empty if type is not supported
     }
     // --- End Simplification ---
      // Build query dynamically based on limit
      let query = collection
        .find({}, { projection: { _id: 0 } })
        .sort({ score: -1 });

      // Apply limit ONLY if provided
      if (limit !== undefined && limit > 0) {
         query = query.limit(limit);
      }

      const results = await query.toArray();

      console.log(`📊 [TopScoreService] Fetched ${results.length} top scores for ${gameType}${limit ? ' (limited to ' + limit + ')' : ' (all)'}`);
      return results;
    } catch (error) {
      console.error(`❌ [TopScoreService] Error fetching top scores for ${gameType}:`, error);
      return []; // Return empty array on error
    }
  }

  /**
   * Gets top scores for all supported game types.
   * @returns A map where keys are game types and values are arrays of top score entries.
   */
  async getAllTopScores(): Promise<{ [gameType: string]: TopScoreEntry[] }> {
    const allScores: { [gameType: string]: TopScoreEntry[] } = {};
    console.log(`📊 [TopScoreService] Fetching top scores for all supported types: ${SUPPORTED_GAME_TYPES.join(', ')}`);
    for (const gameType of SUPPORTED_GAME_TYPES) {
      // Use the existing getTopScores method
      allScores[gameType] = await this.getTopScores(gameType);
    }
    console.log(`📊 [TopScoreService] Finished fetching all top scores.`);
    return allScores;
  }

  /**
   * Broadcasts all top scores to all connected clients.
   */
  async broadcastTopScores(): Promise<void> {
    try {
      const allScores = await this.getAllTopScores();
      this.io.emit('onTopScoresUpdate', allScores); // Use a specific event name
      console.log(`📢 [TopScoreService] Broadcasted updated top scores to all clients.`);
    } catch (error) {
      console.error(`❌ [TopScoreService] Error broadcasting top scores:`, error);
    }
  }

  /**
   * Attempts to add a new score to the top scores list if it qualifies.
   * @param gameType - The type of game.
   * @param name - The player's name.
   * @param score - The player's score.
   * @returns True if the score was inserted, false otherwise.
   */
  async updateTopScore(gameType: string, name: string, score: number): Promise<boolean> {
     // Basic validation
     if (!name || typeof score !== 'number' || !gameType) {
       console.warn(`❌ [TopScoreService] Invalid data for updateTopScore: name=${name}, score=${score}, gameType=${gameType}`);
       return false;
     }
     // Ensure the game type is supported before inserting
     if (!SUPPORTED_GAME_TYPES.includes(gameType)) {
        console.warn(`❌ [TopScoreService] Attempted to update score for unsupported game type: ${gameType}`);
        return false;
     }

     try {
       const collection = this.getCollection(gameType);
      // --- Simplification: Handle null collection ---
      if (!collection) {
           console.warn(`❌ [TopScoreService] Cannot update score for unsupported game type: ${gameType}`);
           return false;
      }
      // --- End Simplification ---
       const result = await collection.insertOne({ name, score });
       console.log(`✅ [TopScoreService] Inserted score ${score} for ${name} in ${gameType} (Inserted ID: ${result.insertedId})`);
       return result.acknowledged; // Return insertion status directly
     } catch (error) {
       console.error(`❌ [TopScoreService] Error inserting top score for ${gameType}:`, error);
       return false;
     }
  }
}



================================================
File: backend/src/utils/gameConfig.ts
================================================
// backend/src/utils/gameConfig.ts

interface GameTypeConfig {
    cellLabels: string[];
    nonNumericCells: string[]; // Labels like Sum, Bonus, Total
    upperSectionEndIndex: number;
    bonusThreshold: number;
    bonusAmount: number;
    diceCount: number;
    maxRolls: number;
}

export const GameConfig: { [key: string]: GameTypeConfig } = {
    Ordinary: {
        cellLabels: [
            'Ones', 'Twos', 'Threes', 'Fours', 'Fives', 'Sixes',
            'Sum', 'Bonus',
            'Pair', 'Two Pairs', 'Three of Kind', 'Four of Kind',
            'House', 'Small Straight', 'Large Straight',
            'Chance', 'Yatzy', 'Total'
        ],
        nonNumericCells: ['Sum', 'Bonus', 'Total'],
        upperSectionEndIndex: 5,
        bonusThreshold: 63,
        bonusAmount: 50,
        diceCount: 5,
        maxRolls: 3,
    },
    Mini: {
        cellLabels: [
            'Ones', 'Twos', 'Threes', 'Fours', 'Fives', 'Sixes',
            'Sum', 'Bonus',
            'Pair', 'Two Pairs', 'Three of Kind',
            'Small Straight', 'Middle Straight', 'Large Straight',
            'Chance', 'Yatzy', 'Total'
        ],
        nonNumericCells: ['Sum', 'Bonus', 'Total'],
        upperSectionEndIndex: 5,
        bonusThreshold: 50, // Value from frontend code
        bonusAmount: 25,    // Value from frontend code
        diceCount: 4,       // Value from frontend code
        maxRolls: 3,
    },
    Maxi: {
        cellLabels: [
            'Ones', 'Twos', 'Threes', 'Fours', 'Fives', 'Sixes',
            'Sum', 'Bonus',
            'Pair', 'Two Pairs', 'Three Pairs',
            'Three of Kind', 'Four of Kind', 'Five of Kind',
            'Small Straight', 'Large Straight', 'Full Straight',
            'House 3-2', 'House 3-3', 'House 2-4',
            'Chance', 'Maxi Yatzy', 'Total'
        ],
         nonNumericCells: ['Sum', 'Bonus', 'Total'],
         upperSectionEndIndex: 5,
         bonusThreshold: 84, // Value from frontend code
         bonusAmount: 100,   // Value from frontend code
         diceCount: 6,       // Value from frontend code
         maxRolls: 3,
    }
    // Note: MaxiR3, MaxiE3, MaxiRE3 use the Maxi board structure
};

// Function to get base type (could be moved here)
export function getBaseGameType(gameType: string): keyof typeof GameConfig {
  if (gameType.startsWith('Maxi')) return 'Maxi';
  if (gameType === 'Mini') return 'Mini';
  return 'Ordinary';
}


================================================
File: backend/src/utils/index.ts
================================================
/**
 * Utility functions for Yatzy server
 */

/**
 * Generate a random integer between min and max (inclusive)
 */
export function randomInt(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

/**
 * Delay execution for the specified number of milliseconds
 */
export function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Check if a variable is defined and not null
 */
export function isDefined<T>(value: T | undefined | null): value is T {
  return value !== undefined && value !== null;
}

/**
 * Create a deep copy of an object
 */
export function deepCopy<T>(obj: T): T {
  return JSON.parse(JSON.stringify(obj));
}



================================================
File: backend/src/utils/yatzyMapping.ts
================================================
// backend/src/utils/yatzyMapping.ts

// Based on the frontend `application/application.dart` structure
const gameTypeMappings = {
  Ordinary: [
    'Ones', 'Twos', 'Threes', 'Fours', 'Fives', 'Sixes',
    'Sum', 'Bonus',
    'Pair', 'Two Pairs', 'Three of Kind', 'Four of Kind',
    'House', 'Small Straight', 'Large Straight',
    'Chance', 'Yatzy', 'Total'
  ],
  Mini: [
    'Ones', 'Twos', 'Threes', 'Fours', 'Fives', 'Sixes',
    'Sum', 'Bonus',
    'Pair', 'Two Pairs', 'Three of Kind',
    'Small Straight', 'Middle Straight', 'Large Straight',
    'Chance', 'Yatzy', 'Total'
  ],
  Maxi: [ // Includes MaxiR3, MaxiE3, MaxiRE3 as they share the board structure
    'Ones', 'Twos', 'Threes', 'Fours', 'Fives', 'Sixes',
    'Sum', 'Bonus',
    'Pair', 'Two Pairs', 'Three Pairs',
    'Three of Kind', 'Four of Kind', 'Five of Kind',
    'Small Straight', 'Large Straight', 'Full Straight',
    'House 3-2', 'House 3-3', 'House 2-4',
    'Chance', 'Maxi Yatzy', 'Total'
  ]
};

function getBaseGameType(gameType: string): keyof typeof gameTypeMappings {
  if (gameType.startsWith('Maxi')) return 'Maxi';
  if (gameType === 'Mini') return 'Mini';
  return 'Ordinary'; // Default
}

export function getSelectionLabel(gameType: string, index: number): string | null {
  const baseType = getBaseGameType(gameType);
  const labels = gameTypeMappings[baseType];
  if (index >= 0 && index < labels.length) {
    return labels[index];
  }
  console.error(`Invalid index ${index} for game type ${gameType}`);
  return null;
}

export function getSelectionIndex(gameType: string, label: string): number {
  const baseType = getBaseGameType(gameType);
  const labels = gameTypeMappings[baseType];
  const index = labels.indexOf(label);
  if (index === -1) {
      console.error(`Label "${label}" not found for game type ${gameType}`);
  }
  return index; // Returns -1 if not found
}


================================================
File: lib/injection.config.dart
================================================
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: unnecessary_lambdas
// ignore_for_file: lines_longer_than_80_chars
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i1;
import 'package:injectable/injectable.dart' as _i2;

import 'core/injectable_modules.dart' as _i6;
import 'router/router.dart' as _i3;
import 'states/bloc/language/language_bloc.dart' as _i4;
import 'states/cubit/state/state_cubit.dart' as _i5;

extension GetItInjectableX on _i1.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i1.GetIt init({
    String? environment,
    _i2.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i2.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final injectableModule = _$InjectableModule();
    gh.lazySingleton<_i3.AppRouter>(() => injectableModule.router);
    gh.factory<_i4.LanguageBloc>(() => _i4.LanguageBloc());
    gh.factory<_i5.SetStateCubit>(() => _i5.SetStateCubit());
    return this;
  }
}

class _$InjectableModule extends _i6.InjectableModule {}



================================================
File: lib/injection.dart
================================================
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'initApiInjection', // default
  preferRelativeImports: true, // default
  asExtension: true, // default
)
Future configureInjection(final String environment) async {
  getIt.init(environment: environment);
}



================================================
File: lib/main.dart
================================================
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/states/bloc/language/language_bloc.dart';
import 'package:yatzy/states/cubit/state/state_cubit.dart';
import 'package:injectable/injectable.dart';
import 'core/app_widget.dart';
import 'injection.dart';
import 'shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefProvider.loadPrefs();
  await configureInjection(Environment.dev);
  runApp(
    MultiBlocProvider(providers: [
      BlocProvider(create: (_) => LanguageBloc()),
      BlocProvider(create: (_) => SetStateCubit()),
    ], child: AppWidget()),
  );
}



================================================
File: lib/shared_preferences.dart
================================================
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Interacts with shared preferences to store and retrieve data
abstract class SharedPrefProvider {
  static late final SharedPreferences prefs;

  static loadPrefs() async {
    prefs = await SharedPreferences.getInstance();
  }

  /// Static lambda functions to retrieve value from state objects
  static bool fetchPrefBool(String key) => prefs.getBool(key) ?? false;

  static int fetchPrefInt(String key) => prefs.getInt(key) ?? 0;

  static String fetchPrefString(String key) => prefs.getString(key) ?? '';

  static dynamic fetchPrefObject(String key) =>
      jsonDecode(prefs.getString(key) ?? jsonEncode({}));

  /// Static lambda functions to set value from state objects
  static Future<bool> setPrefBool(String key, bool value) async {
    return await prefs.setBool(key, value);
  }

  static Future<bool> setPrefInt(String key, int value) async {
    return await prefs.setInt(key, value);
  }

  static Future<bool> setPrefString(String key, String value) async {
    return await prefs.setString(key, value);
  }

  static Future<bool> setPrefObject(String key, value) async {
    return await prefs.setString(key, jsonEncode(value));
  }
}



================================================
File: lib/startup.dart
================================================
import 'package:flutter/cupertino.dart';

import 'package:yatzy/scroll/animations_scroll.dart';
import 'package:yatzy/top_score/top_score.dart';
import 'package:yatzy/tutorial/tutorial.dart';

import 'application/application.dart';
import 'chat/chat.dart';
import 'dices/dices.dart';
import 'input_items/input_items.dart';

var isOnline = false;
var isDebug = true;

// Updated localhost URL to ensure it works with the current network configuration
// In local development, use your actual machine's IP address instead of 192.168.0.168
// This is important for Socket.IO connections to work properly
var localhost = isOnline 
    ? isDebug 
        ? "https://fluttersystems.com" 
        : "https://clientsystem.net" 
    : "http://localhost:8000";

var localhostNET = "https://localhost:44357/api/Values";
var localhostNETIO = "wss://localhost:44357/ws";
var applicationStarted = false;
var userName = "Yatzy";
var userNames = [];
//var devicePixelRatio = 0.0;
var isTesting = false;
var isTutorial = true;
var mainPageLoaded = false;
var keySettings = GlobalKey();
late double screenWidth;
late double screenHeight;
late double devicePixelRatio;

var chosenLanguage = "Swedish";
var standardLanguage = "English";

var differentLanguages = ["English", "Swedish"];

// scrcpy -s R3CR4037M1R --shortcut-mod=lctrl --always-on-top --stay-awake --window-title "Samsung Galaxy S21"
// android:theme="@style/UnityThemeSelector.Translucent"
// android/app/src/main/AndroidManifest.xml

var inputItems = InputItems();
late Tutorial tutorial;
//var languagesGlobal = LanguagesGlobal();

late TopScore topScore;
late AnimationsScroll animationsScroll; // = AnimationsScroll();

late Application app;
late Chat chat;

late Dices dices;



================================================
File: lib/application/animations_application.dart
================================================
import 'package:flutter/animation.dart';

class AnimationsApplication {
  // Animation properties
  final animationControllers = <AnimationController>[];

  var animationDurations = List.filled(2, const Duration(seconds: 1));
  var cellAnimationControllers = [];
  var cellAnimation = [];
  var players = 0;
  var boardXAnimationPos = [];
  var boardYAnimationPos = [];

  animateBoard() {
    for (var i = 0; i < players + 1; i++) {
      cellAnimationControllers[i][0].forward();
    }
  }

  setupAnimation(TickerProvider ticket, int nrPlayers, int maxNrPlayers, int maxTotalFields) {
    players = nrPlayers;
    for (Duration d in animationDurations) {
      animationControllers.add(AnimationController(
        vsync: ticket,
        duration: d,
      ));
    }

    animationControllers[0].addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        animationControllers[0].reverse();
      }
    });

    for (var i = 0; i < maxNrPlayers + 1; i++) {
      var tmp = <AnimationController>[];
      for (var j = 0; j < maxTotalFields; j++) {
        tmp.add(AnimationController(
          vsync: ticket,
          duration: const Duration(milliseconds: 500),
        ));
      }
      cellAnimationControllers.add(tmp);
    }

    for (var i = 0; i < maxNrPlayers + 1; i++) {
      var tmp = <Animation>[];
      for (var j = 0; j < maxTotalFields; j++) {
        tmp.add(CurveTween(curve: Curves.easeInSine)
            .animate(cellAnimationControllers[i][j]));
      }
      cellAnimation.add(tmp);
    }

    for (var i = 0; i < maxNrPlayers + 1; i++) {
      for (var j = 0; j < maxTotalFields; j++) {
        cellAnimationControllers[i][j].addListener(() {
          boardXAnimationPos[i][j] = cellAnimation[i][j].value * 100.0;
          if ((j < maxTotalFields - 1) && cellAnimation[i][j].value > 0.02) {
            if (!cellAnimationControllers[i][j + 1].isAnimating) {
              cellAnimationControllers[i][j + 1].forward();
            }
          }
        });
        cellAnimationControllers[i][j]
            .addStatusListener((AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            cellAnimationControllers[i][j].reverse();
          }
        });
      }
    }
  }
}



================================================
File: lib/application/application.dart
================================================
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/application_functions_internal.dart';
import 'package:yatzy/dices/unity_communication.dart';
import 'package:yatzy/services/socket_service.dart';
import 'application_functions_internal_calc_dice_values.dart';
import '../dices/dices.dart';
import '../input_items/input_items.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';
import 'animations_application.dart';
import 'languages_application.dart';

// cannot have typedef inside class
typedef YatzyFunctions = int Function();

class Application with LanguagesApplication  {
  final BuildContext context;
  final InputItems inputItems;
  Application({required this.context, required this.gameDices, required this.inputItems}) {
    gameDices.setCallbacks(callbackUpdateDiceValues, callbackUnityCreated,
        callbackCheckPlayerToMove);
    languagesSetup(getChosenLanguage(), getStandardLanguage());
  }

  Function getChosenLanguage() {
    String f() {
      return chosenLanguage;
    }
    return f;
  }

  String getStandardLanguage() {
    return standardLanguage;
  }

  bool isSpectating = false;
  int spectatedGameId = -1;
  // Settings properties
  dynamic tabController;
  var textEditingController = TextEditingController();
  var focusNode = FocusNode();
  var animation = AnimationsApplication();
  var games = [];
  var presentations = [];
  var boardAnimation = false;

  // Application properties

  var stackedWidgets = <Widget>[];

  // "Ordinary" , "Mini", "Maxi"
  var gameType = "Ordinary";
  var nrPlayers = 1;

  // Used by animation
  var maxNrPlayers = 4;
  var maxTotalFields = 23;

  // Socket game
  Map<String, dynamic> gameData = {};

  var gameId = -1;
  var playerIds = [];
  var playerActive = [];

  var totalFields = 18;
  var bonusSum = 63;
  var bonusAmount = 50;
  var myPlayerId = -1;
  var playerToMove = 0;
  var winnerId = -1;
  var gameStarted = false;
  var gameFinished = false;

  var boardXPos = [],
      boardYPos = [],
      boardWidth = [],
      boardHeight = [],
      cellValue = [],
      fixedCell = [],
      appText = [],
      appColors = [],
      focusStatus = [];

  var listenerKey = GlobalKey();
  late Dices gameDices;
  late List<YatzyFunctions> yatzyFunctions;
  var serverId = "";

  var cellKeys = [];

  // Reference to the modern socket service
  SocketService? socketService;

  bool callbackCheckPlayerToMove() {
    return playerToMove == myPlayerId;
  }

  callbackUnityCreated() {
    if (myPlayerId == playerToMove) {
      gameDices.sendStartToUnity();
    }
  }

  callbackUpdateDiceValues() {
    updateDiceValues();
    Map<String, dynamic> msg = {};
    msg["action"] = "sendDices";
    msg["gameId"] = gameId;
    msg["playerIds"] = playerIds;
    msg["diceValue"] = gameDices.diceValue;
    
    // Use socketService for sending dice values to ensure delivery
    // This ensures we use the modern socket system which is correctly connected
    print('🎲 Sending dice values to other players: ${gameDices.diceValue}');
    if (socketService != null && socketService!.isConnected) {
      socketService?.sendToClients(msg);
    }
  }

  updateDiceValues() {
    clearFocus();
    for (var i = 0; i < totalFields; i++) {
      if (!fixedCell[playerToMove][i]) {
        cellValue[playerToMove][i] = yatzyFunctions[i]();
        appText[playerToMove + 1][i] = cellValue[playerToMove][i].toString();
      }
    }

    context.read<SetStateCubit>().setState();
  }

  setAppText() {
    if (gameType == "Mini") {
      appText[0] = [
        ones_,
        twos_,
        threes_,
        fours_,
        fives_,
        sixes_,
        sum_,
        "$bonus_ ( $bonusAmount )",
        pair_,
        twoPairs_,
        threeOfKind_,
        smallStraight_,
        middleStraight_,
        largeStraight_,
        chance_,
        yatzy_,
        totalSum_
      ];
    } else if (gameType.startsWith("Maxi")) {
      appText[0] = [
        ones_,
        twos_,
        threes_,
        fours_,
        fives_,
        sixes_,
        sum_,
        "$bonus_ ( $bonusAmount )",
        pair_,
        twoPairs_,
        threePairs_,
        threeOfKind_,
        fourOfKind_,
        fiveOfKind_,
        smallStraight_,
        largeStraight_,
        fullStraight_,
        house32_,
        house33_,
        house24_,
        chance_,
        maxiYatzy_,
        totalSum_
      ];
    } else {
      appText[0] = [
        ones_,
        twos_,
        threes_,
        fours_,
        fives_,
        sixes_,
        sum_,
        "$bonus_ ( $bonusAmount )",
        pair_,
        twoPairs_,
        threeOfKind_,
        fourOfKind_,
        house_,
        smallStraight_,
        largeStraight_,
        chance_,
        yatzy_,
        totalSum_
      ];
    }
  }

  setup() {
    topScore.loadTopScoreFromServer(gameType, context.read<SetStateCubit>());
    gameStarted = true;
    playerToMove = 0;
    winnerId = -1;

    if (gameType == "Mini") {
      totalFields = 17;
      gameDices.initDices(4);
      bonusSum = 50;
      bonusAmount = 25;

      yatzyFunctions =
          [calcOnes, calcTwos, calcThrees, calcFours, calcFives, calcSixes] +
              [
                zero,
                zero,
                calcPair,
                calcTwoPairs,
                calcThreeOfKind,
                calcSmallLadder,
                calcMiddleLadder,
                calcLargeLadder,
                calcChance,
                calcYatzy,
                zero
              ];
    } else if (gameType.startsWith("Maxi")) {
      totalFields = 23;
      gameDices.initDices(6);
      bonusSum = 84;
      bonusAmount = 100;

      yatzyFunctions =
          [calcOnes, calcTwos, calcThrees, calcFours, calcFives, calcSixes] +
              [
                zero,
                zero,
                calcPair,
                calcTwoPairs,
                calcThreePairs,
                calcThreeOfKind,
                calcFourOfKind,
                calcFiveOfKind,
                calcSmallLadder,
                calcLargeLadder,
                calcFullLadder,
                calcHouse,
                calcVilla,
                calcTower,
                calcChance,
                calcYatzy,
                zero
              ];
    } else {
      totalFields = 18;
      gameDices.initDices(5);
      bonusSum = 63;
      bonusAmount = 50;

      yatzyFunctions =
          [calcOnes, calcTwos, calcThrees, calcFours, calcFives, calcSixes] +
              [
                zero,
                zero,
                calcPair,
                calcTwoPairs,
                calcThreeOfKind,
                calcFourOfKind,
                calcHouse,
                calcSmallLadder,
                calcLargeLadder,
                calcChance,
                calcYatzy,
                zero
              ];
    }

    appText = [];
    if (isTesting) {
      for (var i = 0; i < nrPlayers + 1; i++) {
        var textColumn = List.filled(6, "0") +
            List.filled(1, "0") +
            List.filled(1, (-bonusSum).toString()) +
            List.filled(totalFields - 9, "0") +
            List.filled(1, "0");
        textColumn[5] = "";
        textColumn[totalFields - 2] = "";
        appText.add(textColumn);
      }
    } else {
      for (var i = 0; i < nrPlayers + 1; i++) {
        appText.add(List.filled(6, "") +
            List.filled(1, "0") +
            List.filled(1, (-bonusSum).toString()) +
            List.filled(totalFields - 9, "") +
            List.filled(1, "0"));
      }
    }
    setAppText();

    boardXPos = [List.filled(maxTotalFields, 0.0)];
    boardYPos = [List.filled(maxTotalFields, 0.0)];
    boardWidth = [List.filled(maxTotalFields, 0.0)];
    boardHeight = [List.filled(maxTotalFields, 0.0)];
    animation.boardXAnimationPos = [List.filled(maxTotalFields, 0.0)];
    animation.boardYAnimationPos = [List.filled(maxTotalFields, 0.0)];
    for (var i = 0; i < maxNrPlayers; i++) {
      boardXPos.add(List.filled(maxTotalFields, 0.0));
      boardYPos.add(List.filled(maxTotalFields, 0.0));
      boardWidth.add(List.filled(maxTotalFields, 0.0));
      boardHeight.add(List.filled(maxTotalFields, 0.0));
      animation.boardXAnimationPos.add(List.filled(maxTotalFields, 0.0));
      animation.boardYAnimationPos.add(List.filled(maxTotalFields, 0.0));
    }
    clearFocus();
    fixedCell = [];
    cellValue = [];
    appColors = [
      List.filled(6, Colors.white.withValues(alpha: 0.3)) +
          List.filled(2, Colors.blueAccent.withValues(alpha: 0.8)) +
          List.filled(totalFields - 9, Colors.white.withValues(alpha: 0.3)) +
          List.filled(1, Colors.blueAccent.withValues(alpha: 0.8))
    ];

    for (var i = 0; i < nrPlayers; i++) {
      if (isTesting) {
        var holdColumn = List.filled(totalFields, true);
        holdColumn[5] = false;
        holdColumn[totalFields - 2] = false;
        fixedCell.add(holdColumn);
      } else {
        fixedCell.add(List.filled(6, false) +
            [true, true] +
            List.filled(totalFields - 9, false) +
            [true]);
      }

      if (i == playerToMove) {
        appColors.add(List.filled(6, Colors.greenAccent.withValues(alpha: 0.3)) +
            List.filled(2, Colors.blue.withValues(alpha: 0.3)) +
            List.filled(totalFields - 9, Colors.greenAccent.withValues(alpha: 0.3)) +
            List.filled(1, Colors.blue.withValues(alpha: 0.3)));
      } else {
        appColors.add(List.filled(6, Colors.grey.withValues(alpha: 0.3)) +
            List.filled(2, Colors.blue.withValues(alpha: 0.3)) +
            List.filled(totalFields - 9, Colors.grey.withValues(alpha: 0.3)) +
            List.filled(1, Colors.blue.withValues(alpha: 0.3)));
      }

      if (isTesting) {
        var valueColumn = List.filled(totalFields, 0);
        valueColumn[5] = -1;
        valueColumn[totalFields - 2] = -1;
        cellValue.add(valueColumn);
      } else {
        cellValue.add(List.filled(totalFields, -1));
      }
    }
    if (gameDices.unityCreated) {
      gameDices.sendResetToUnity();
      if (myPlayerId == playerToMove) {
        gameDices.sendStartToUnity();
      }
    }

    cellKeys = [];
    for (int i = 0; i < nrPlayers + 1; i++) {
      var tmp = [];
      for (int j = 0; j < totalFields; j++) {
        tmp.add(GlobalKey());
      }
      cellKeys.add(tmp);
    }
  }

  // Method to set the socket service reference
  void setSocketService(SocketService service) {
    print('🔌 Application: Setting socket service reference');
    socketService = service;
  }
}



================================================
File: lib/application/application_functions_internal.dart
================================================
// lib/application/application_functions_internal.dart
import 'package:flutter/material.dart';
import 'package:yatzy/dices/unity_communication.dart';
import '../startup.dart';
import 'application.dart';
import '../utils/yatzy_mapping_client.dart'; // <-- Import client-side mapping
import '../states/cubit/state/state_cubit.dart'; // Import SetStateCubit
import 'package:provider/provider.dart'; // Import Provider


extension ApplicationFunctionsInternal on Application {
  // ... (clearFocus remains the same) ...
  clearFocus() {
    focusStatus = [];
    for (var i = 0; i < nrPlayers; i++) {
      focusStatus.add(List.filled(totalFields, 0));
    }
  }


  cellClick(int player, int cell) {
    // Replace isMyTurn with the original logic
    if (player == playerToMove &&
        myPlayerId == playerToMove &&
        !fixedCell[player][cell] &&
        cellValue[player][cell] != -1) {

      // Get the string label for the selected cell
      String? selectionLabel = getSelectionLabel(gameType, cell); // Use mapping function
      if (selectionLabel == null) {
          print("Error: Could not find label for cell index $cell");
          return; // Don't proceed if label is invalid
      }

      Map<String, dynamic> msg = {};
      msg["diceValue"] = gameDices.diceValue; // Current dice
      msg["gameId"] = gameId;
      // msg["playerIds"] = playerIds; // Server knows players in gameId
      msg["player"] = player; // Send player index (server validates)
      // msg["cell"] = cell; // <-- REMOVE Index
      msg["selectionLabel"] = selectionLabel; // <-- SEND Label String
      msg["score"] = cellValue[player][cell]; // Send the score client calculated
      msg["action"] = "sendSelection"; // Use consistent action name

      // Use the stored socketService directly instead of trying to access through ServiceProvider
      if (socketService != null && socketService!.isConnected) {
        print('🎮 Sending selection via socketService: player $player cell $cell label "$selectionLabel" score ${msg["score"]}');
        socketService!.sendToClients(msg);
      } else {
        print('❌ Cannot send selection: socketService is null or not connected');
        // Handle offline mode - just continue with local updates
      }

      // --- Local Update (Optimistic UI) ---
      // Apply the selection locally immediately for responsiveness.
      // Server confirmation will solidify the state via onGameUpdate.
      applyLocalSelection(player, cell, cellValue[player][cell]);
      // ---------------------------------

    } else {
        print("Ignoring cell click: Not my turn or cell invalid/fixed.");
    }
  }

  // New function to apply local UI changes after selection
  void applyLocalSelection(int player, int cell, int score) {
     if (gameDices.unityDices) {
       gameDices.sendResetToUnity();
       // Don't send start - wait for server to confirm next turn
     }

     appColors[player + 1][cell] = Colors.green.withAlpha(178); // Use alpha consistent with colorBoard
     fixedCell[player][cell] = true;
     cellValue[player][cell] = score; // Ensure value is set if passed

     // Update Sums locally
     var sum = 0;
     var totalSum = 0;
     var upperHalfSet = 0;
     for (var i = 0; i < 6; i++) {
       if (fixedCell[player][i]) {
         upperHalfSet++;
         sum += cellValue[player][i] as int; // Cast to int
       }
     }
     totalSum = sum;
     appText[player + 1][6] = sum.toString(); // Sum cell index = 6
     cellValue[player][6] = sum; // Store sum value

     // Bonus calculation index = 7
     int bonusIndex = 7;
     int bonusValue = 0; // Store calculated bonus value
     if (sum >= bonusSum) {
       bonusValue = bonusAmount;
       appText[player + 1][bonusIndex] = bonusAmount.toString();
       totalSum += bonusAmount;
     } else {
       // Check if all upper section cells are fixed
       final allUpperFixed = !fixedCell[player].sublist(0, 6).contains(false);
       if (allUpperFixed) {
         bonusValue = 0; // All fixed, no bonus
         appText[player + 1][bonusIndex] = "0";
       } else {
         bonusValue = sum - bonusSum; // Deficit
         appText[player + 1][bonusIndex] = (sum - bonusSum).toString();
       }
     }
     cellValue[player][bonusIndex] = bonusValue; // Store bonus/deficit


      // Lower section sum calculation
     for (var i = 8; i < totalFields -1; i++) { // Skip Sum, Bonus, Total (indices 6, 7, totalFields-1)
       if (fixedCell[player][i]) {
         totalSum += cellValue[player][i] as int;
       }
     }
      // Update Total Sum cell (index = totalFields - 1)
      int totalSumIndex = totalFields - 1;
      appText[player + 1][totalSumIndex] = totalSum.toString();
      cellValue[player][totalSumIndex] = totalSum;


     // Zero results for remaining selectable cells for this player?
     // This might be premature, let the server state dictate.
     // Clear focus remains useful.
     clearFocus();

     // Check if this player finished locally (for UI feedback, maybe)
      // Check all cells except Sum, Bonus, Total
      bool playerFinished = true;
      for(int j=0; j<totalFields; j++) {
          if (j != 6 && j != 7 && j != totalFields - 1 && !fixedCell[player][j]) {
              playerFinished = false;
              break;
          }
      }
      if (playerFinished) {
          print("Player $player finished locally.");
          // Server will confirm overall game finish status.
      }

     // Don't advance turn locally - wait for server message `onGameUpdate`
     colorBoard(); // Update colors immediately for selection feedback
     gameDices.clearDices(); // Clear dice display

     // Trigger UI update
     try {
       context.read<SetStateCubit>().setState();
     } catch (e) {
       print('⚠️ Error updating UI state: $e');
       // Continue without updating state
     }
  }


  // calcNewSums is now mostly handled by applyLocalSelection and server updates
  // Keep the coloring part if needed separately
  // calcNewSums(int player, int cell) { ... } // <-- REMOVE OR REFACTOR

  colorBoard() {
    // Update player column colors based on playerToMove and playerActive status
    for (var i = 0; i < nrPlayers; i++) {
      Color columnColor;
      if (i == playerToMove) {
        columnColor = Colors.greenAccent.withAlpha(77); // ~0.3 alpha
      } else if (playerActive != null && i < playerActive.length && playerActive[i]) {
        columnColor = Colors.grey.withAlpha(77); // ~0.3 alpha
      } else {
        // disconnected/aborted player
        columnColor = Colors.black.withAlpha(77); // ~0.3 alpha
      }

      for (var j = 0; j < totalFields; j++) {
          // Keep special colors for non-selectable cells
          if (j == 6 || j == 7 || j == totalFields - 1) { // Sum, Bonus, Total
              appColors[i + 1][j] = Colors.blue.withAlpha(77); // Special color for calculated fields
          }
          // Apply base color only if not already fixed with the selection color
          else if (!(fixedCell[i][j] && appColors[i + 1][j] == Colors.green.withAlpha(178))) { // Check if it's the 'just selected' color
             appColors[i + 1][j] = columnColor;
          }
          // Re-apply selection color if cell is fixed
          else if (fixedCell[i][j]) {
              appColors[i + 1][j] = Colors.green.withAlpha(178); // ~0.7 alpha for selected/fixed
          }
      }
    }
      // Update header colors based on which cells are fixed for the *current* player
     if (playerToMove >= 0 && playerToMove < nrPlayers) {
         for (var j = 0; j < totalFields; j++) {
              // Keep special colors
              if (j == 6 || j == 7 || j == totalFields - 1) {
                  appColors[0][j] = Colors.blueAccent.withAlpha(204); // ~0.8 alpha
              }
              // Highlight fixed cells in header? Or just dim unfixed? Let's dim unfixed.
              else if (fixedCell[playerToMove][j]) {
                   appColors[0][j] = Colors.white.withAlpha(178); // Brighter/Solid for fixed
              } else {
                   appColors[0][j] = Colors.white.withAlpha(77); // Dimmer for available
              }
         }
     }

  }

}



================================================
File: lib/application/application_functions_internal_calc_dice_values.dart
================================================
import 'application.dart';

extension ApplicationCalcDiceValues on Application {
  int zero() {
    return 0;
  }

  int calcOnes() {
    var eye = 1;
    var value = 0;
    for (var i = 0; i < gameDices.nrDices; i++) {
      if (gameDices.diceValue[i] == eye) {
        value += eye;
      }
    }
    return value;
  }

  int calcTwos() {
    var eye = 2;
    var value = 0;
    for (var i = 0; i < gameDices.nrDices; i++) {
      if (gameDices.diceValue[i] == eye) {
        value += eye;
      }
    }
    return value;
  }

  int calcThrees() {
    var eye = 3;
    var value = 0;
    for (var i = 0; i < gameDices.nrDices; i++) {
      if (gameDices.diceValue[i] == eye) {
        value += eye;
      }
    }
    return value;
  }

  int calcFours() {
    var eye = 4;
    var value = 0;
    for (var i = 0; i < gameDices.nrDices; i++) {
      if (gameDices.diceValue[i] == eye) {
        value += eye;
      }
    }
    return value;
  }

  int calcFives() {
    var eye = 5;
    var value = 0;
    for (var i = 0; i < gameDices.nrDices; i++) {
      if (gameDices.diceValue[i] == eye) {
        value += eye;
      }
    }
    return value;
  }

  int calcSixes() {
    var eye = 6;
    var value = 0;
    for (var i = 0; i < gameDices.nrDices; i++) {
      if (gameDices.diceValue[i] == eye) {
        value += eye;
      }
    }
    return value;
  }

  List calcDiceNr() {
    var tmp = List.filled(6, 0);
    for (var i = 0; i < gameDices.nrDices; i++) {
      tmp[gameDices.diceValue[i] - 1]++;
    }
    return tmp;
  }

  int calcPair() {
    var value = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 2) {
        value = (i + 1) * 2;
        break;
      }
    }
    return value;
  }

  int calcTwoPairs() {
    var value = 0;
    var pairs = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 2 && pairs < 2) {
        value += (i + 1) * 2;
        pairs++;
      }
    }
    if (pairs < 2) {
      value = 0;
    }
    return value;
  }

  int calcThreePairs() {
    var value = 0;
    var pairs = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 2) {
        value += (i + 1) * 2;
        pairs++;
      }
    }
    if (pairs != 3) {
      value = 0;
    }
    return value;
  }

  int calcThreeOfKind() {
    var value = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 3) {
        value = (i + 1) * 3;
        break;
      }
    }
    return value;
  }

  int calcFourOfKind() {
    var value = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 4) {
        value = (i + 1) * 4;
        break;
      }
    }
    return value;
  }

  int calcFiveOfKind() {
    var value = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 5) {
        value = (i + 1) * 5;
        break;
      }
    }
    return value;
  }

  int calcYatzy() {
    var value = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] == gameDices.nrDices) {
        if (gameDices.nrDices == 4) {
          value = 25;
        }
        if (gameDices.nrDices == 5) {
          value = 50;
        }
        if (gameDices.nrDices == 6) {
          value = 100;
        }
      }
    }
    return value;
  }

  int calcHouse() {
    var value = 0;
    var pair = 0;
    var triplet = 0;
    var diceNr = calcDiceNr();

    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 3) {
        value += (i + 1) * 3;
        triplet = 1;
        diceNr[i] = 0;
        break;
      }
    }

    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 2) {
        value += (i + 1) * 2;
        pair = 1;
        break;
      }
    }
    if ((pair != 1) || (triplet != 1)) {
      value = 0;
    }
    return value;
  }

  int calcTower() {
    var value = 0;
    var pair = 0;
    var quadruple = 0;

    var diceNr = calcDiceNr();

    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 4) {
        value += (i + 1) * 4;
        quadruple = 1;
        diceNr[i] = 0;
        break;
      }
    }

    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] >= 2) {
        value += (i + 1) * 2;
        pair = 1;
        break;
      }
    }
    if ((pair != 1) || (quadruple != 1)) {
      value = 0;
    }
    return value;
  }

  int calcVilla() {
    var value = 0;
    var threes = 0;
    var diceNr = calcDiceNr();
    for (var i = 5; i >= 0; i--) {
      if (diceNr[i] == 3) {
        value += (i + 1) * 3;
        threes++;
      }
    }
    if (threes != 2) {
      value = 0;
    }
    return value;
  }

  int calcSmallLadder() {
    var value = 0;
    var diceNr = calcDiceNr();
    if (gameType == "Ordinary") {
      // Text is not displayed and therefore not translated
      if ((diceNr[0] > 0) &&
          (diceNr[1] > 0) &&
          (diceNr[2] > 0) &&
          (diceNr[3] > 0) &&
          (diceNr[4] > 0)) {
        value = 1 + 2 + 3 + 4 + 5;
      }
    }
    if (gameType == "Mini") {
      if ((diceNr[0] > 0) &&
          (diceNr[1] > 0) &&
          (diceNr[2] > 0) &&
          (diceNr[3] > 0)) {
        value = 1 + 2 + 3 + 4;
      }
    }
    if (gameType.startsWith("Maxi")) {
      if ((diceNr[0] > 0) &&
          (diceNr[1] > 0) &&
          (diceNr[2] > 0) &&
          (diceNr[3] > 0) &&
          (diceNr[4] > 0)) {
        value = 1 + 2 + 3 + 4 + 5;
      }
    }
    return value;
  }

  int calcLargeLadder() {
    var value = 0;
    var diceNr = calcDiceNr();
    if (gameType == "Ordinary") {
      if ((diceNr[1] > 0) &&
          (diceNr[2] > 0) &&
          (diceNr[3] > 0) &&
          (diceNr[4] > 0) &&
          (diceNr[5] > 0)) {
        value = 2 + 3 + 4 + 5 + 6;
      }
    }
    if (gameType == "Mini") {
      if ((diceNr[2] > 0) &&
          (diceNr[3] > 0) &&
          (diceNr[4] > 0) &&
          (diceNr[5] > 0)) {
        value = 3 + 4 + 5 + 6;
      }
    }
    if (gameType.startsWith("Maxi")) {
      if ((diceNr[1] > 0) &&
          (diceNr[2] > 0) &&
          (diceNr[3] > 0) &&
          (diceNr[4] > 0) &&
          (diceNr[5] > 0)) {
        value = 2 + 3 + 4 + 5 + 6;
      }
    }
    return value;
  }

  int calcMiddleLadder() {
    var value = 0;
    var diceNr = calcDiceNr();
    if (gameType == "Mini") {
      if ((diceNr[1] > 0) &&
          (diceNr[2] > 0) &&
          (diceNr[3] > 0) &&
          (diceNr[4] > 0)) {
        value = 2 + 3 + 4 + 5;
      }
    }
    return value;
  }

  int calcFullLadder() {
    var value = 0;
    var diceNr = calcDiceNr();
    if (gameType.startsWith("Maxi")) {
      if ((diceNr[0] > 0) &&
          (diceNr[1] > 0) &&
          (diceNr[2] > 0) &&
          (diceNr[3] > 0) &&
          (diceNr[4] > 0) &&
          (diceNr[5] > 0)) {
        value = 1 + 2 + 3 + 4 + 5 + 6;
      }
    }
    return value;
  }

  int calcChance() {
    var value = 0;

    for (var i = 0; i < gameDices.nrDices; i++) {
      value += gameDices.diceValue[i];
    }
    return value;
  }
}



================================================
File: lib/application/communication_application.dart
================================================
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/application_functions_internal.dart';
import 'package:yatzy/dices/unity_communication.dart';

import '../chat/chat.dart';
import '../injection.dart';
import '../router/router.dart';
import '../router/router.gr.dart';
import '../services/service_provider.dart';
import '../shared_preferences.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';
import 'application.dart';

extension CommunicationApplication on Application {
  // Helper method to reset dice state when turn changes
  void resetDices() {
    // Clear dice display
    gameDices.clearDices();
    
    // Reset temporary dice values
    for (var i = 0; i < totalFields; i++) {
      if (playerToMove < nrPlayers && !fixedCell[playerToMove][i]) {
        appText[playerToMove + 1][i] = "";
        cellValue[playerToMove][i] = -1;
      }
    }
    
    // Clear focus
    clearFocus();
  }

  handlePlayerAbort(int abortedPlayerIndex) {
    print('🎮 Handling player abort for player $abortedPlayerIndex');

    // Mark player as inactive
    playerActive[abortedPlayerIndex] = false;

    // Mark their column as inactive (dark)
    for (var j = 0; j < totalFields; j++) {
      appColors[abortedPlayerIndex + 1][j] = Colors.black.withValues(alpha: 0.5);
    }

    // If the aborted player was the current player to move, advance to the next active player
    if (abortedPlayerIndex == playerToMove) {
      advanceToNextActivePlayer();
    }

    // Update the board colors
    colorBoard();

    // Send a notification to the console for debugging
    print('🎮 Player $abortedPlayerIndex has aborted the game, adjusted game state accordingly');
  }

  advanceToNextActivePlayer() {
    print('🎮 Advancing to next active player from current player $playerToMove');

    // Safety check
    if (playerActive.isEmpty) return;

    final startingPlayer = playerToMove;
    
    do {
      playerToMove = (playerToMove + 1) % nrPlayers;

      // If we've checked all players and none are active, keep current player
      if (playerToMove == startingPlayer) {
        print('🎮 All players are inactive or we\'ve checked all players');
        break;
      }
    } while (!playerActive[playerToMove]);

    print('🎮 Advanced to next active player: $playerToMove');

    // Update the board colors to show the current player
    colorBoard();
    
    // Reset dice for the new player
    resetDices();

    if (myPlayerId == playerToMove) {
      print('🎮 My turn now, enabling dice throw');
      if (gameDices.unityDices) {
        gameDices.sendResetToUnity();
        gameDices.sendStartToUnity();
      }
    }
  }

  callbackOnServerMsg(dynamic data) async {
    try {
      final router = getIt<AppRouter>();

      // *** ADD NULL CHECK FOR data ***
      if (data == null || data is! Map) {
        print('⚠️ Received invalid server message data: $data');
        return;
      }

      // *** Safely access action ***
      final action = data['action'];
      if (action == null) {
        print('⚠️ Server message missing \'action\' key: $data');
        return;
      }

      switch (action) {
        case "onGetId":
          // Explicitly cast keys and values using .map()
          final Map<String, dynamic> getIdData = (data as Map).map(
            (key, value) => MapEntry(key.toString(), value)
          );
          try {
            final serviceProvider = ServiceProvider.of(context);
            serviceProvider.socketService.socketId = getIdData["id"];
          } catch (e) {
            print('⚠️ ServiceProvider not available in onGetId: $e');
          }
          var settings = SharedPrefProvider.fetchPrefObject('yatzySettings');
          if (settings.length > 0) {
             userName = settings["userName"];
             gameType = settings["gameType"];
             nrPlayers = settings["nrPlayers"];
             boardAnimation = settings["boardAnimation"];
             chosenLanguage = settings["language"];
             gameDices.unityDices = settings["unityDices"];
             gameDices.unityLightMotion = settings["unityLightMotion"];
          }
          break;
        case "onGameStart":
          print('🎮 Received game start event for game ${data["gameId"]}');
          // --- ADD GUARD AGAINST DUPLICATE PROCESSING ---
          final incomingGameId = data["gameId"];
          if (gameId == incomingGameId && gameStarted) { // Check if we are already in this game and it's started
            print('🎮 Ignoring duplicate onGameStart for game $gameId');
            return; // Prevent reprocessing
          }
          // --- END GUARD ---

          // Check if this is a spectator message
          if (data["spectator"] == true) {
            print('👁️ Received spectator game data for game ${data["gameId"]}');
            
            // Extract player data for debugging (optional, keep if useful)
            final players = data["players"];
            if (players != null && players.isNotEmpty) {
              final player = players[0];
              if (player != null && player["cells"] != null) {
                final cells = player["cells"];
                print('📊 Spectator data - player cells:');
                for (var cell in cells) {
                  if (cell != null) {
                    print('📊 - ${cell["label"]}: value=${cell["value"]}, fixed=${cell["fixed"]}');
                  }
                }
              }
            }
            
            // Store the game data (Apply casting here)
            gameData = (data).map((key, value) => MapEntry(key.toString(), value));
            
            // Apply the cell values to the UI - this is essential
            try {
              // Use the already cast `gameData` map
              if (gameData["players"] != null && gameData["players"].isNotEmpty) {
                final player = gameData["players"][0];
                if (player != null && player["cells"] != null) {
                  final cells = player["cells"];
                  // Loop through cells and apply values to UI
                  for (var cell in cells) {
                    if (cell != null && cell["value"] != null && cell["value"] != -1 && cell["fixed"] == true) {
                      int index = cell["index"];
                      if (index >= 0 && index < totalFields) {
                        // Apply the values to the UI
                        cellValue[0][index] = cell["value"];
                        // Add safe checks before accessing appText
                        if (appText.length > 1 && appText[1].length > index) {
                           appText[1][index] = cell["value"].toString();
                        } else {
                           print('⚠️ Index $index out of bounds for appText[1] (${appText.length > 1 ? appText[1].length : 'N/A'})');
                        }
                        print('📊 Applied value ${cell["value"]} for ${cell["label"]} to UI');
                      }
                    }
                  }
                }
              }
              
              // Update the UI
              context.read<SetStateCubit>().setState();
            } catch (e) {
              print('⚠️ Error processing spectator data: $e');
            }
            return; // Return after handling spectator data
          }
          
          // Normal game start logic (for players)
          // Find our player ID in the list
          int myIndex = -1;
          if (data["playerIds"] != null) {
            myIndex = data["playerIds"].indexOf(socketService?.socketId ?? '');
          }
          
          // Only join if we are in this game
          if (myIndex >= 0) {
            
            myPlayerId = myIndex;
            // Apply casting here
            gameData = (data).map((key, value) => MapEntry(key.toString(), value));
            gameId = gameData["gameId"]; // Use the casted map

            // --- Set gameStarted flag BEFORE calling setup ---
            gameStarted = true; // Mark game as started locally *before* setup

            playerIds = gameData["playerIds"]; // Use the casted map
            playerActive = List.filled(playerIds.length, true);
            gameType = gameData["gameType"]; // Use the casted map
            nrPlayers = gameData["nrPlayers"]; // Use the casted map
            setup();
            userNames = gameData["userNames"]; // Use the casted map
            animation.players = nrPlayers;
            
            print('🎮 Game started! Transitioning to game screen, myPlayerId: $myPlayerId, gameId: $gameId');
            
            if (applicationStarted) {
              if (gameDices.unityCreated) {
                gameDices.sendResetToUnity();
                if (gameDices.unityDices && myPlayerId == playerToMove) {
                  gameDices.sendStartToUnity();
                }
              }
              // Pop back to settings first? Or directly update the existing view?
              // Let's assume we just need to ensure the state is correct.
              // A simple setState might be enough if already on ApplicationView.
              // If coming from SettingsView, pop might be needed.
              // The existing router logic seems to handle popping if needed.
              context.read<SetStateCubit>().setState(); // Ensure UI update
              // await router.pop(); // Maybe not needed if guard prevents re-entry?
            } else {
              applicationStarted = true;
              await router.pushAndPopUntil(const ApplicationView(),
                  predicate: (Route<dynamic> route) => false);
            }
          } else {
            print('🎮 Received game start for a game we\'re not in: ${data["gameId"]}');
          }
          break;
        case "onRequestGames":
          // --- Add Check: Only process if not currently in a game ---
          // This prevents the game list update from interfering right after starting a game.
          // It assumes the user sees the list primarily from the SettingsView.
          // If (gameId == -1 && !gameStarted) { // Only update list if not in an active game
          print('📩 Processing onRequestGames...');
          data = List<dynamic>.from(data["Games"]);
          games = data;
          _checkIfPlayerAborted(); // This check is likely safe now
          context.read<SetStateCubit>().setState(); // Update settings view if visible
          break;
        case "onGameUpdate":
          _processGameUpdate(data);
          break;
        case "onGameAborted":
          print('🚪 Received onGameAborted');
          // Reset state and go back to settings
          gameId = -1;
          myPlayerId = -1;
          gameFinished = false;
          isSpectating = false; // Ensure spectator mode is also reset
          spectatedGameId = -1;
          gameData = {};
          context.read<SetStateCubit>().setState();
          await router.pushAndPopUntil(const SettingsView(), predicate: (_) => false);
          break;
        case "onGameFinished":
          print('🏁 Received onGameFinished from server for game ${data["gameId"]}');
          final Map<String, dynamic> finishedGameData = (data).map(
            (key, value) => MapEntry(key.toString(), value)
          );
          gameData = finishedGameData;
          gameFinished = true; // Set flag for UI layer to handle dialog

          // Trigger UI update first
          context.read<SetStateCubit>().setState();

          if (!isSpectating) {
            // Player specific logic (dialog is handled by UI layer)
            print('🏁 Game finished for player. UI layer will handle dialog.');
            
            // **** Trigger top score fetch for THIS game type ****
            try {
               if (socketService != null && socketService!.isConnected) {
                   final finishedGameType = gameData['gameType'] ?? gameType; // Get type from finished game data or current app state
                   print('🏆 Requesting latest top scores for $finishedGameType after game finish...');
                   socketService!.sendToServer({
                     'action': 'requestTopScores',
                     'gameType': finishedGameType 
                    });
               } else {
                   print('⚠️ Cannot request top scores: SocketService not connected.');
               }
            } catch (e) {
               print('❌ Error sending requestTopScores for player: $e');
            }

          } else {
             // Spectator specific logic - DO NOTHING related to top scores
             print('🏁 Spectator received game finished signal.');
          }
          break;
        case "onTopScoresUpdate":
          print('🏆 Received top scores update');
          try {
            // Parse received data
            final Map<String, dynamic> receivedData = (data as Map).map(
              (key, value) => MapEntry(key.toString(), value)
            );
            final receivedGameType = receivedData['gameType'];
            final dynamic scoresList = receivedData['scores'];

            // Validate format
            if (receivedGameType == null || receivedGameType is! String || scoresList == null || scoresList is! List) {
               print('❌ Invalid onTopScoresUpdate data format: $receivedData');
               return;
            }

            // Convert score entries to the correct type
            List<Map<String, dynamic>> typedScores = (scoresList as List).map((scoreEntry) {
              if (scoreEntry is Map) {
                return scoreEntry.map((k, v) => MapEntry(k.toString(), v));
              } else {
                print('⚠️ Unexpected score entry format for $receivedGameType: $scoreEntry');
                return <String, dynamic>{};
              }
            }).where((map) => map.isNotEmpty).toList();

            // **** CALL NEW TopScore METHOD ****
            // Update the TopScore instance directly instead of app state
            topScore.updateScoresFromData(typedScores, context.read<SetStateCubit>());
            print('🏆 Updated TopScore instance for $receivedGameType (${typedScores.length} entries)');

            // Remove update to app.currentTopScores
            // currentTopScores = typedScores;
            // print('🏆 Updated local top scores for $receivedGameType (${currentTopScores.length} entries)');

            // Remove direct setState call here, as updateScoresFromData handles it
            // context.read<SetStateCubit>().setState();

          } catch (e) {
            print('❌ Error processing top scores update: $e');
            print('Raw data causing error: $data');
          }
          break;
      }
    } catch (e) {
      print('🎮 Error processing server message: $e');
    }
  }
  
  // Helper method to check if any players have aborted the game
  void _checkIfPlayerAborted() {
    // **** ADD THIS GUARD ****
    if (isSpectating || gameData.isEmpty || gameId == -1) {
      print('🎮 Skipping _checkIfPlayerAborted (Spectating or no active game data)');
      return;
    }
    // **** END GUARD ****

    // Existing logic...
    print('🎮 Checking for aborted players...'); // Add log

    // Track if any player's status changed
    bool playerStatusChanged = false;

    for (var i = 0; i < games.length; i++) {
      // Ensure games[i] is a Map and has the required keys
      if (games[i] is Map && games[i]["gameId"] == gameData["gameId"] && games[i]["playerIds"] != null) {
        var currentGameFromList = games[i]; // To avoid repeated lookups

        // Ensure playerActive and playerIds are initialized and match length
        if (playerActive.length != nrPlayers || playerIds.length != nrPlayers) {
           print('⚠️ Player state arrays mismatch nrPlayers ($nrPlayers). Reinitializing.');
           playerActive = List.filled(nrPlayers, true); // Reinitialize based on current game
           playerIds = List<String>.from(gameData['playerIds'] ?? List.filled(nrPlayers, "")); // Use current game data
        }


        for (var j = 0; j < nrPlayers && j < currentGameFromList["playerIds"].length; j++) {
          // Make sure indices are valid before accessing
          if (j < playerActive.length) {
             bool wasActive = playerActive[j];
             // Check if player ID is present and not empty in the game list data
             bool isActive = currentGameFromList["playerIds"][j] != null &&
                             currentGameFromList["playerIds"][j].toString().isNotEmpty;

             // If a player was active but is now inactive, they aborted
             if (wasActive && !isActive) {
               print('🎮 Player $j has aborted the game!');
               playerStatusChanged = true;
               handlePlayerAbort(j); // Make sure this function handles UI updates
             }

             // Update the local playerActive status
             playerActive[j] = isActive;
          } else {
             print('⚠️ Index $j out of bounds for playerActive (${playerActive.length})');
          }
        }
         // Update playerIds safely
         playerIds = List<String>.from(currentGameFromList["playerIds"]);
         break; // Found the matching game, no need to check others
      }
    }

    // If no specific player status changed but current player is inactive,
    // we need to advance to the next active player
    // Add checks to prevent RangeError here as well
    if (!playerStatusChanged &&
        playerToMove >= 0 && playerToMove < playerActive.length && !playerActive[playerToMove]) {
      _advanceToNextActivePlayer();
    } else if (playerToMove >= playerActive.length) {
       print('⚠️ playerToMove ($playerToMove) is out of bounds for playerActive (${playerActive.length})');
       // Reset playerToMove? Or handle error?
       if (playerActive.isNotEmpty) playerToMove = 0;
    }

    // Update board colors based on the potentially changed playerActive status
    colorBoard(); // Moved from inside the loop

    // Trigger UI update if needed (e.g., if handlePlayerAbort doesn't do it)
    if (playerStatusChanged) {
        try {
            context.read<SetStateCubit>().setState();
        } catch (e) { print('⚠️ Error updating state after abort check: $e'); }
    }
  }
  
  // Helper method to advance to the next active player
  void _advanceToNextActivePlayer() {
    print('🎮 Current player $playerToMove is inactive, advancing to next active player');
    
    // Clear unfixed cells of the current player before advancing
    for (var j = 0; j < totalFields; j++) {
      if (!fixedCell[playerToMove][j]) {
        cellValue[playerToMove][j] = -1;
        appText[playerToMove + 1][j] = "";
      }
    }
    
    // Find the next active player
    int nextPlayer = playerToMove;
    bool foundActivePlayer = false;
    
    // Try to find an active player by checking each player in order
    for (int i = 0; i < nrPlayers; i++) {
      nextPlayer = (nextPlayer + 1) % nrPlayers;
      if (playerActive[nextPlayer]) {
        foundActivePlayer = true;
        break;
      }
    }
    
    if (foundActivePlayer) {
      print('🎮 Found next active player: $nextPlayer');
      playerToMove = nextPlayer;
      
      // Reset dice for the new player
      resetDices();
      
      // If it's my turn, start dice rolling
      if (playerToMove == myPlayerId) {
        print('🎮 My turn now! Enabling dice throw');
        if (gameDices.unityDices) {
          gameDices.sendResetToUnity();
          gameDices.sendStartToUnity();
        }
      }
    } else {
      print('🎮 No active players found, game cannot continue');
    }
  }
  
  // Helper method to process game updates
  void _processGameUpdate(dynamic data) async {
    try {
      final router = getIt<AppRouter>();
      print('🎮 Processing game update: $data');

      // Check if we're in spectator mode
      bool isSpectator = data["spectator"] == true;
      
      // If spectator, we need to handle things differently
      if (isSpectator) {
        print('👁️ Processing game update as spectator');
        
        try {
          // Make a deep copy of the data to ensure all parts are updated
          Map<String, dynamic> newGameData = Map<String, dynamic>.from(data);
          
          // Log complete data for debugging
          print('👁️ COMPLETE SPECTATOR DATA: $newGameData');
          print('👁️ Received new spectator data with keys: ${newGameData.keys.join(', ')}');
          
          // Get direct board data if available
          if (newGameData['cellValue'] != null) {
            print('👁️ Found direct cellValue data: ${newGameData['cellValue']}');
          }
          
          if (newGameData['appText'] != null) {
            print('👁️ Found appText data: ${newGameData['appText']}');
          }
          
          if (newGameData['appColors'] != null) {
            print('👁️ Found appColors data (length): ${newGameData['appColors'].length}');
          }
          
          // Check for dice values - multiple possible formats
          if (newGameData['diceValues'] != null) {
            print('👁️ Dice values: ${newGameData['diceValues']}');
          } else if (newGameData['diceValue'] != null) {
            print('👁️ Dice value: ${newGameData['diceValue']}');
            // Standardize naming
            newGameData['diceValues'] = newGameData['diceValue'];
          }
          
          // Try to extract dice data from other places
          if (newGameData['gameDices'] != null && newGameData['gameDices']['diceValue'] != null) {
            newGameData['diceValues'] = newGameData['gameDices']['diceValue'];
            print('👁️ Found dice values in gameDices: ${newGameData['diceValues']}');
          }
          
          // Check for player data
          if (newGameData['players'] != null && newGameData['players'].isNotEmpty) {
            print('👁️ Found ${newGameData['players'].length} players in data');
            
            // Debug first player data
            var player = newGameData['players'][0];
            if (player != null) {
              print('👁️ First player data keys: ${player.keys.join(', ')}');
              
              // Check for score data in various formats
              if (player['scoreSheet'] != null) {
                print('👁️ Found scoreSheet: ${player['scoreSheet']}');
              } else if (player['cells'] != null) {
                print('👁️ Found cells array with ${player['cells'].length} items');
                
                // Try to construct a scoreSheet from cells if needed
                if (player['scoreSheet'] == null) {
                  Map<String, dynamic> scoreSheet = {};
                  for (var cell in player['cells']) {
                    if (cell != null && cell['key'] != null && cell['value'] != null) {
                      scoreSheet[cell['key']] = cell['value'];
                    }
                  }
                  
                  if (scoreSheet.isNotEmpty) {
                    player['scoreSheet'] = scoreSheet;
                    print('👁️ Created scoreSheet from cells: $scoreSheet');
                  }
                }
              }
            }
          }
          
          // Check if we need to populate data from cellValue
          if (newGameData['cellValue'] != null && newGameData['players'] == null) {
            try {
              // Try to create player structures from cellValue
              List<Map<String, dynamic>> players = [];
              for (int i = 0; i < newGameData['cellValue'].length; i++) {
                Map<String, dynamic> scoreSheet = {};
                
                // List of score keys in order
                List<String> scoreKeys = [
                  'ones', 'twos', 'threes', 'fours', 'fives', 'sixes',
                  'upperSum', 'bonus', 'pair', 'twoPairs', 'threeOfAKind',
                  'fourOfAKind', 'fullHouse', 'smallStraight', 'largeStraight',
                  'chance', 'yatzy', 'total'
                ];
                
                for (int j = 0; j < scoreKeys.length && j < newGameData['cellValue'][i].length; j++) {
                  if (newGameData['cellValue'][i][j] != null && newGameData['cellValue'][i][j] != -1) {
                    scoreSheet[scoreKeys[j]] = newGameData['cellValue'][i][j];
                  }
                }
                
                Map<String, dynamic> player = {
                  'name': newGameData['userNames']?[i] ?? 'Player ${i+1}',
                  'scoreSheet': scoreSheet
                };
                
                players.add(player);
              }
              
              if (players.isNotEmpty) {
                newGameData['players'] = players;
                print('👁️ Created players from cellValue: ${players.length} players');
              }
            } catch (e) {
              print('👁️ Error creating players from cellValue: $e');
            }
          }
          
          // Check for player names in various formats
          if (newGameData['userNames'] != null) {
            print('👁️ User names: ${newGameData['userNames']}');
          }
          
          // Update the game data with the new information
          gameData = newGameData;
          
          // Make sure to update the UI state to refresh the spectator view
          // We use Future.microtask to ensure the UI update happens in the next event loop
          // This helps avoid potential state inconsistencies

            try {
              print('👁️ Updating spectator UI state...');
              context.read<SetStateCubit>().setState();
              print('👁️ Updated spectator UI state successfully');
            } catch (e) {
              print('⚠️ Error updating spectator UI state: $e');
            }

        } catch (parseError) {
          print('⚠️ Error parsing spectator data: $parseError');
          // Still try to update with the raw data
          gameData = data;
          context.read<SetStateCubit>().setState();
        }
        
        // Since we're just a spectator, we don't need to navigate or setup the game
        return;
      }

      // Normal player processing starts here
      
      // If this is a different game from what we're playing, ignore it
      if (data["gameId"] != gameId && gameId != -1) {
        print('🎮 Ignoring update for different game ID: ${data["gameId"]} (our gameId: $gameId)');
        return;
      }

      // Update game data with the new information
      gameData = data;
      
      // If the game hasn't started yet, don't do anything more
      if (!(data["gameStarted"] ?? false)) {
        print('🎮 Game ${data["gameId"]} hasn\'t started yet');
        return;
      }

      // Check if the player list has changed - someone might have disconnected
      if (data["playerIds"] != null) {
        final newPlayerIds = data["playerIds"];

        // Check if this is our first update and we don't have an ID yet
        if (gameId == -1) {
          int potentialId = newPlayerIds.indexOf(socketService?.socketId ?? '');
          if (potentialId >= 0) {
            // We found ourselves in this game
            myPlayerId = potentialId;
            gameId = data["gameId"];
            playerIds = data["playerIds"];
            playerActive = List.filled(playerIds.length, true);
            gameType = data["gameType"];
            nrPlayers = data["nrPlayers"];
            setup();
            userNames = data["userNames"];
            animation.players = nrPlayers;
            
            print('🎮 Joining game $gameId as player $myPlayerId');
            
            if (applicationStarted) {
              if (gameDices.unityCreated) {
                gameDices.sendResetToUnity();
                if (gameDices.unityDices && myPlayerId == playerToMove) {
                  gameDices.sendStartToUnity();
                }
              }
              await router.pop();
            } else {
              applicationStarted = true;
              await router.pushAndPopUntil(const ApplicationView(),
                  predicate: (Route<dynamic> route) => false);
            }
            return;
          }
        }

        // Make sure playerIds and playerActive are initialized
        if (playerIds.isEmpty) {
          playerIds = List<String>.from(newPlayerIds);
          playerActive = List.filled(playerIds.length, true);
        }

        // Check if the current player is still in the game
        if (myPlayerId >= 0 && myPlayerId < newPlayerIds.length) {
          String myId = socketService?.socketId ?? '';

          if (newPlayerIds[myPlayerId] == null || 
              newPlayerIds[myPlayerId].isEmpty ||
              (newPlayerIds[myPlayerId] != myId)) {
            print('🎮 WARNING: Our player appears to have been removed from the game');
            // We've been removed from the game - we should not process this update
            return;
          }
        }

        // Process player status changes if arrays are initialized
        if (playerIds.isNotEmpty && playerActive.isNotEmpty) {
          bool playerStatusChanged = false;
          for (int i = 0; i < playerIds.length && i < playerActive.length; i++) {
            if (i < newPlayerIds.length) {
              bool wasActive = playerActive[i];
              bool isActive = newPlayerIds[i] != null && newPlayerIds[i].toString().isNotEmpty;

              // Player was active but is now inactive (aborted/disconnected)
              if (wasActive && !isActive) {
                print('🎮 Player $i has aborted/disconnected!');
                handlePlayerAbort(i);
                playerStatusChanged = true;
              }
            }
          }
        }

        // Update playerIds safely
        playerIds = List<String>.from(newPlayerIds);
      }

      // Handle player turn changes
      final newPlayerToMove = data["playerToMove"];
      if (newPlayerToMove != null && newPlayerToMove != playerToMove) {
        playerToMove = newPlayerToMove;
        print('🎮 Turn changed to player $playerToMove (my ID: $myPlayerId)');
        
        // Reset dice for the new player's turn
        resetDices();
        
        // If it's my turn, start dice rolling
        if (playerToMove == myPlayerId) {
          print('🎮 My turn now! Enabling dice throw');
          if (gameDices.unityDices) {
            gameDices.sendResetToUnity();
            gameDices.sendStartToUnity();
          }
        }
      }
      
      // Always update board colors
      colorBoard();
    } catch (e) {
      print('🎮 Error processing game update: $e');
    }
  }

  chatCallbackOnSubmitted(String text) {
    print('💬 Chat message submitted: "$text"');
    
    // Don't send empty messages
    if (text.trim().isEmpty) {
      print('💬 Ignoring empty chat message');
      return;
    }
    
    // Get the current game ID
    final gameId = this.gameId;
    
    // Format the message with the username
    final formattedMessage = "$userName: $text";

    chat.scrollController.animateTo(
      chat.scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn
    );
    
    print('💬 Sending chat message to game $gameId with players: $playerIds');
    
    // Use the modern SocketService if available
    if (socketService != null && socketService!.isConnected) {
      print('💬 Using modern SocketService to send chat message');
      
      // Create message for modern SocketService
      final msg = {
        "action": "chatMessage",
        "gameId": gameId,
        "message": text,
        "sender": userName,
        "playerIds": playerIds,
      };
      
      // Send via the modern socket service
      socketService!.sendToClients(msg);
    }
  }

  updateChat(String text) async {
    chat.messages.add(ChatMessage(text, "receiver"));

    await Future.delayed(const Duration(milliseconds: 100), () {});
    chat.scrollController.animateTo(
        chat.scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn);
  }

  callbackOnClientMsg(var data) async {
    try {
      final router = getIt<AppRouter>();
      switch (data["action"]) {
        case "sendSelection":
          print('🎲 Received selection from player: ${data["player"]}');

          // Check if this is a selection from a player that aborted
          // If the selection is from a player that's no longer active, ignore it
          int selectionPlayer = data["player"];
          if (selectionPlayer >= 0 && selectionPlayer < playerActive.length && !playerActive[selectionPlayer]) {
            print('🎲 Ignoring selection from inactive/aborted player $selectionPlayer');
            return;
          }

          // Check if the selection is for the current player (that's us) making a selection
          // or if it's from another player that we need to update on our board
          if (data["player"] != myPlayerId) {
            print('🎲 Updating board with selection from player ${data["player"]}');

            // Update dice values to show what the other player had
            gameDices.diceValue = data["diceValue"].cast<int>();
            updateDiceValues();

            // Mark the cell as selected but don't change turns
            // Actual turn change will come via the onGameUpdate message
            int player = data["player"];
            int cell = data["cell"];

            // Update the cell appearance and call calcNewSums
            appColors[player + 1][cell] = Colors.green.withValues(alpha: 0.7);
            fixedCell[player][cell] = true;
            
            // Clear unfixed cells for the current player
            for (var i = 0; i < totalFields; i++) {
              if (!fixedCell[player][i]) {
                appText[player + 1][i] = "";
                cellValue[player][i] = -1;
              }
            }
            applyLocalSelection(player, cell, cellValue[player][cell]);

            // Get next player (same logic as in calcNewSums)
            int nextPlayer = player;
            do {
              nextPlayer = (nextPlayer + 1) % nrPlayers;
            } while (!playerActive[nextPlayer]);
            
            // Clear unfixed cells for the next player
            for (var i = 0; i < totalFields; i++) {
              if (!fixedCell[nextPlayer][i]) {
                appText[nextPlayer + 1][i] = "";
                cellValue[nextPlayer][i] = -1;
              }
            }

            // Clear dice visuals
            gameDices.clearDices();
          } else {
            // This is our own selection coming back to us, we can ignore it
            // since we already processed it locally
            print('🎲 Ignoring selection from myself (player $myPlayerId)');
          }
          break;
        case "sendDices":
          data = Map<String, dynamic>.from(data);
          var dices = data["diceValue"].cast<int>();
          if (dices[0] == 0) {
            resetDices();
          } else {
            gameDices.diceValue = dices;
            updateDiceValues();
            gameDices.nrRolls += 1;
            gameDices.updateDiceImages();
            if (gameDices.unityDices) {
              gameDices.sendDicesToUnity();
            }
          }
          break;
        case "chatMessage":
          updateChat(data["chatMessage"]);
          break;
        case "onGameAborted":
          await router.push(const SettingsView());
          break;
      }
    } catch (e) {
      print('🎮 Error processing client message: $e');
    }
  }
}


================================================
File: lib/application/languages_application.dart
================================================
mixin LanguagesApplication  {

  late Function _getChosenLanguage;
  late String _standardLanguage;

  final _ones = {"English": "Ones"};
  final _twos = {"English": "Twos"};
  final _threes = {"English": "Threes"};
  final _fours = {"English": "Fours"};
  final _fives = {"English": "Fives"};
  final _sixes = {"English": "Sixes"};
  final _sum = {"English": "Sum"};
  final _bonus = {"English": "Bonus"};
  final _pair = {"English": "Pair"};
  final _twoPairs = {"English": "Two Pairs"};
  final _threePairs = {"English": "Three Pairs"};
  final _threeOfKind = {"English": "Three of Kind"};
  final _fourOfKind = {"English": "Four of Kind"};
  final _fiveOfKind = {"English": "Five of Kind"};
  final _house = {"English": "House"};
  final _smallStraight = {"English": "Small Ladder"};
  final _largeStraight = {"English": "Large Ladder"};
  final _fullStraight = {"English": "Full Straight"};
  final _middleStraight = {"English": "Middle Ladder"};
  final _house32 = {"English": "House 3+2"};
  final _house33 = {"English": "House 3+3"};
  final _house24 = {"English": "House 2+4"};
  final _chance = {"English": "Chance"};
  final _yatzy = {"English": "Yatzy"};
  final _maxiYatzy = {"English": "Maxi Yatzy"};
  final _totalSum = {"English": "Total Sum"};
  final _turn = {"English": "turn..."};
  final _your = {"English": "Your"};
  final _gameFinished = {
    "English": "Game Finished, Press Settings Button To Join New Game!"
  };
  final _pressSettingsButton = {"English": "Press Settings Button"};
  final _toJoinNewGame = {"English": "To Join New Game!"};
  final _chooseMove = {"English": "\nChoose Move"};
  final _pressSettings = {"English": "Press Settings\nButton"};

  // Settings

  final _gameTypeOrdinary = {"English": "Ordinary"};
  final _gameTypeMini = {"English": "Mini"};
  final _gameTypeMaxi = {"English": "Maxi"};
  final _gameTypeMaxiR3 = {"English": "Maxi Regret 3"};
  final _gameTypeMaxiE3 = {"English": "Maxi Extra 3"};
  final _gameTypeMaxiRE3 = {"English": "Maxi Regret Extra 3"};
  final _settings = {"English": "Settings"};
  final _game = {"English": "Game"};
  final _general = {"English": "General"};
  final _choseLanguage = {"English": "Chose Language"};
  final _startGame = {"English": "Start Game"};
  final _createGame = {"English": "Create Game"};
  final _transparency = {"English": "Transparency"};
  final _lightMotion = {"English": "Light Motion"};
  final _red = {"English": "Red"};
  final _green = {"English": "Green"};
  final _blue = {"English": "Blue"};
  final _appearance = {"English": "Appearance"};
  final _misc = {"English": "Misc"};
  final _gameRequest = {"English": "Game Request"};
  final _currentUsername = {"English": "Current username: "};
  final _enterUsername = {"English": "Enter username"};
  final _ongoingGames = {"English": "Ongoing Games"};
  final _boardAnimation = {"English": "Board Animation"};
  final _useTutorial = {"English": "Use Tutorial"};

  String get ones_ => getText(_ones);

  String get twos_ => getText(_twos);

  String get threes_ => getText(_threes);

  String get fours_ => getText(_fours);

  String get fives_ => getText(_fives);

  String get sixes_ => getText(_sixes);

  String get sum_ => getText(_sum);

  String get bonus_ => getText(_bonus);

  String get pair_ => getText(_pair);

  String get twoPairs_ => getText(_twoPairs);

  String get threePairs_ => getText(_threePairs);

  String get threeOfKind_ => getText(_threeOfKind);

  String get fourOfKind_ => getText(_fourOfKind);

  String get fiveOfKind_ => getText(_fiveOfKind);

  String get house_ => getText(_house);

  String get smallStraight_ => getText(_smallStraight);

  String get largeStraight_ => getText(_largeStraight);

  String get fullStraight_ => getText(_fullStraight);

  String get middleStraight_ => getText(_middleStraight);

  String get house32_ => getText(_house32);

  String get house33_ => getText(_house33);

  String get house24_ => getText(_house24);

  String get chance_ => getText(_chance);

  String get yatzy_ => getText(_yatzy);

  String get maxiYatzy_ => getText(_maxiYatzy);

  String get totalSum_ => getText(_totalSum);

  String get turn_ => getText(_turn);

  String get your_ => getText(_your);

  String get gameFinished_ => getText(_gameFinished);

  String get pressSettingsButton_ => getText(_pressSettingsButton);

  String get toJoinNewGame_ => getText(_toJoinNewGame);

  String get chooseMove_ => getText(_chooseMove);

  String get pressSettings_ => getText(_pressSettings);

  // Settings

  String get gameTypeOrdinary_ => getText(_gameTypeOrdinary);

  String get gameTypeMini_ => getText(_gameTypeMini);

  String get gameTypeMaxi_ => getText(_gameTypeMaxi);

  String get gameTypeMaxiR3_ => getText(_gameTypeMaxiR3);

  String get gameTypeMaxiE3_ => getText(_gameTypeMaxiE3);

  String get gameTypeMaxiRE3_ => getText(_gameTypeMaxiRE3);

  String get settings_ => getText(_settings);

  String get game_ => getText(_game);

  String get general_ => getText(_general);

  String get choseLanguage_ => getText(_choseLanguage);

  String get startGame_ => getText(_startGame);

  String get createGame_ => getText(_createGame);

  String get transparency_ => getText(_transparency);

  String get lightMotion_ => getText(_lightMotion);

  String get red_ => getText(_red);

  String get green_ => getText(_green);

  String get blue_ => getText(_blue);

  String get appearance_ => getText(_appearance);

  String get misc_ => getText(_misc);

  String get gameRequest_ => getText(_gameRequest);

  String get currentUsername_ => getText(_currentUsername);

  String get enterUsername_ => getText(_enterUsername);

  String get ongoingGames_ => getText(_ongoingGames);

  String get boardAnimation_ => getText(_boardAnimation);

  String get useTutorial_ => getText(_useTutorial);


  void languagesSetup(Function getChosenLanguage, String standardLanguage) {
    _getChosenLanguage = getChosenLanguage;
    _standardLanguage = standardLanguage;
    _ones["Swedish"] = "Ettor";
    _twos["Swedish"] = "Tvåor";
    _threes["Swedish"] = "Treor";
    _fours["Swedish"] = "Fyror";
    _fives["Swedish"] = "Femmor";
    _sixes["Swedish"] = "Sexor";
    _sum["Swedish"] = "Summa";
    _bonus["Swedish"] = "Bonus";
    _pair["Swedish"] = "Par";
    _twoPairs["Swedish"] = "Två Par";
    _threePairs["Swedish"] = "Tre Par";
    _threeOfKind["Swedish"] = "Triss";
    _fourOfKind["Swedish"] = "Fyrtal";
    _fiveOfKind["Swedish"] = "Femtal";
    _house["Swedish"] = "Kåk";
    _smallStraight["Swedish"] = "Liten Stege";
    _largeStraight["Swedish"] = "Stor Stege";
    _fullStraight["Swedish"] = "Hel Stege";
    _middleStraight["Swedish"] = "Mellan Stege";
    _house32["Swedish"] = "Kåk 3+2";
    _house33["Swedish"] = "Hus 3+3";
    _house24["Swedish"] = "Torn 2+4";
    _chance["Swedish"] = "Chans";
    _yatzy["Swedish"] = "Yatzy";
    _maxiYatzy["Swedish"] = "Maxi Yatzy";
    _totalSum["Swedish"] = "Total Summa";
    _turn["Swedish"] = "tur...";
    _your["Swedish"] = "Din";
    _gameFinished["Swedish"] =
        "Spelet Är Slut, Tryck På Inställningar Knappen För Att Starta Nytt Spel!";
    //_gameFinished["Swedish"] = "Spelet Är Slut,";
    _pressSettingsButton["Swedish"] = "Tryck På Inställningar Knappen";
    _toJoinNewGame["Swedish"] = "För Att Starta Nytt Spel!";
    _chooseMove["Swedish"] = "\nVälj Drag";
    _pressSettings["Swedish"] = "Gå Till \ninställningar";

    // Settings

    _gameTypeOrdinary["Swedish"] = "Standard";
    _settings["Swedish"] = "Inställningar";
    _game["Swedish"] = "Spel";
    _general["Swedish"] = "Allmänt";
    _choseLanguage["Swedish"] = "Välj Språk";
    _startGame["Swedish"] = "Starta Spelet";
    _createGame["Swedish"] = "Skapa Spel";
    _transparency["Swedish"] = "Transparens";
    _lightMotion["Swedish"] = "Cirkulärt Ljus";
    _red["Swedish"] = "Röd";
    _green["Swedish"] = "Grön";
    _blue["Swedish"] = "Blå";
    _appearance["Swedish"] = "Utseende";
    _misc["Swedish"] = "Diverse";
    _gameRequest["Swedish"] = "Spel Inbjudan";
    _currentUsername["Swedish"] = "Nuvarande användarnamn: ";
    _enterUsername["Swedish"] = "Ange användarnamn";
    _ongoingGames["Swedish"] = "Pågående Spel";
    _boardAnimation["Swedish"] = "Spelplans Animation";
    _useTutorial["Swedish"] = "Användar Hjälp På";
    _gameTypeMaxiR3["Swedish"] = "Maxi Ångra 3";
    _gameTypeMaxiRE3["Swedish"] = "Maxi Ångra Extra 3";
  }

  String getText(var textVariable) {
    var text = textVariable[_getChosenLanguage()];
    if (text != null) {
      return text;
    } else {
      return textVariable[_standardLanguage]!;
    }
  }
}



================================================
File: lib/application/widget_application.dart
================================================
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/application_functions_internal.dart';
import 'package:yatzy/dices/unity_communication.dart';

import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';

import 'languages_application.dart';


class WidgetSetupGameBoard extends StatefulWidget {
  final double width;
  final double height;

  const WidgetSetupGameBoard(
      {super.key, required this.width, required this.height});

  @override
  State<WidgetSetupGameBoard> createState() =>
      _WidgetSetupGameBoardState();
}

class _WidgetSetupGameBoardState extends State<WidgetSetupGameBoard> with LanguagesApplication {
  @override
  void initState() {
    super.initState();
    //languagesSetup(app.getChosenLanguage(), app.standardLanguage());
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;

    var cellWidth = min(250, width / ((app.nrPlayers) / 3 + 1.5));
    //var cellHeight = min(30.0, height / (TotalFields + 1));

    var cellHeight = height / (app.totalFields + 1.5);
    cellWidth = min(cellWidth, cellHeight * 5);

    var top = (height - cellHeight * app.totalFields) * 0.75;
    var left = (width - cellWidth * ((app.nrPlayers - 1) / 3 + 1.5)) / 2;

    if (app.boardWidth.isEmpty) {
      app.setup();
    }
    // Setup board cell positions
    for (var i = 0; i < app.totalFields; i++) {
      app.boardWidth[0][i] = cellWidth;
      app.boardHeight[0][i] = cellHeight;
      app.boardXPos[0][i] = left;
      app.boardYPos[0][i] = i * cellHeight + top;
    }

    for (var i = 0; i < app.nrPlayers; i++) {
      for (var j = 0; j < app.totalFields; j++) {
        app.boardXPos[i + 1][j] = app.boardXPos[i][j] +app.boardWidth[i][j];
        app.boardYPos[i + 1][j] = app.boardYPos[0][j];
        app.boardHeight[i + 1][j] = app.boardHeight[0][j];
        app.boardWidth[i + 1][j] = app.boardWidth[0][j] / 3;
      }
    }

    for (var i = 0; i < app.nrPlayers; i++) {
      for (var j = 0; j < app.totalFields; j++) {
        // enlarge dimension of cell in focus
        if (app.focusStatus[i][j] == 1) {
          app.boardXPos[i + 1][j] -= app.boardWidth[i + 1][j] / 2;
          app.boardWidth[i + 1][j] *= 2;
          app.boardYPos[i + 1][j] -= app.boardHeight[i + 1][j] / 2;
          app.boardHeight[i + 1][j] *= 2;
        }
      }
    }

    var listings = <Widget>[];

    // Place names
    for (var i = 0; i < app.nrPlayers; i++) {
      listings.add(Positioned(
          left: app.boardXPos[1 + i][0],
          top: app.boardYPos[1 + i][0] - cellHeight,
          child: Container(
              padding:
              const EdgeInsets.only(left: 5, right: 5, top: 0, bottom: 0),
              width: app.boardWidth[1 + i][0],
              height: cellHeight,
              child: FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                      userNames.length > i && userNames[i].isNotEmpty
                          ? userNames[i].length > 3
                              ? userNames[i].substring(0, 3)
                              : userNames[i]
                          : "P${i+1}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.black.withValues(alpha: 0.8),
                        shadows: const [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.blueAccent,
                            offset: Offset(5.0, 5.0),
                          ),
                        ],
                      ))))));
    }
    // For 'live' translation reset board text
    app.setAppText();
    for (var i = 0; i < app.totalFields; i++) {
      try {
        listings.add(
          AnimatedBuilder(
              animation: app.animation.cellAnimationControllers[0][i],
              builder: (BuildContext context, Widget? widget) {
                return Positioned(
                    key: app.cellKeys[0][i],
                    left: app.boardXPos[0][i] + app.animation.boardXAnimationPos[0][i],
                    top: app.boardYPos[0][i] + app.animation.boardYAnimationPos[0][i],
                    child: Container(
                      padding: const EdgeInsets.only(left: 10, right: 10),
                      width: app.boardWidth[0][i],
                      height: app.boardHeight[0][i],
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey,
                          width: 1.0,
                        ),
                        color: app.appColors[0][i],
                      ),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Text(
                          app.appText[0][i],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            //color: Colors.blue[800],
                            shadows: [
                              Shadow(
                                blurRadius: 5.0,
                                color: Colors.blue,
                                offset: Offset(2.0, 2.0),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ));
              }),
        );
      } catch (e) {
        // error
      }
    }

    onVerticalDragUpdate(mainX, mainY) {
      if (app.playerToMove != app.myPlayerId) {
        return;
      }
      var box = app.listenerKey.currentContext!.findRenderObject() as RenderBox;
      var position = box.localToGlobal(Offset.zero); //this is global position
      mainY -= position.dy;
      for (var i = 0; i < app.totalFields; i++) {
        if (mainY >= app.boardYPos[0][i] &&
            mainY <= app.boardYPos[0][i] + app.boardHeight[0][i]) {
          if (!app.fixedCell[app.playerToMove][i] && app.cellValue[app.playerToMove][i] != -1) {
            if (app.focusStatus[app.playerToMove][i] == 0) {
              app.clearFocus();
              app.focusStatus[app.playerToMove][i] = 1;
            }
          }
        }
      }
    }

    //add listener object to get drag positions
    //Important it comes after the part over which it should trigger
    listings.add(GestureDetector(
        key: app.listenerKey,
        onVerticalDragUpdate: (d) {
          onVerticalDragUpdate(d.globalPosition.dx, d.globalPosition.dy);

          context.read<SetStateCubit>().setState();
        },
        onTap: () {
          app.clearFocus();

          context.read<SetStateCubit>().setState();
        },
        child: SizedBox(width: width, height: height, child: const Text(""))));

    Widget? focusWidget;
    Widget tmpWidget;

    try {
      for (var i = 0; i < app.nrPlayers; i++) {
        for (var j = 0; j < app.totalFields; j++) {
          tmpWidget = AnimatedBuilder(
              animation: app.animation.cellAnimationControllers[i][j],
              builder: (BuildContext context, Widget? widget) {
                return Positioned(
                  key: app.cellKeys[i + 1][j],
                  left: app.boardXPos[i + 1][j] +
                      app.animation.boardXAnimationPos[i + 1][j],
                  top: app.boardYPos[i + 1][j] +
                      app.animation.boardYAnimationPos[i + 1][j],
                  child: GestureDetector(
                      onTap: () {
                        app.cellClick(i, j);

                        context.read<SetStateCubit>().setState();
                      },
                      child: Container(
                          width: app.boardWidth[i + 1][j],
                          height: app.boardHeight[i + 1][j],
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.blue,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                            color: app.appColors[i + 1][j],
                          ),
                          child: FittedBox(
                            fit: BoxFit.fitHeight,
                            child: Text(app.appText[i + 1][j],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ))),
                );
              });
          if (app.focusStatus[i][j] == 1) {
            focusWidget = tmpWidget;
          } else {
            listings.add(tmpWidget);
          }
        }
      }

      // The focus widget is overlapping neighbor widgets
      // it needs to be last to have priority
      if (focusWidget != null) {
        listings.add(focusWidget);
      }
    } catch (e) {
      // Error
    }
    return SizedBox(
        width: screenWidth, height: height, child: Stack(children: listings));
  }
}

class WidgetDisplayGameStatus extends StatefulWidget {
  final double width;
  final double height;

  const WidgetDisplayGameStatus(
      {super.key, required this.width, required this.height});

  @override
  State<WidgetDisplayGameStatus> createState() =>
      _WidgetDisplayGameStatusState();
}

class _WidgetDisplayGameStatusState extends State<WidgetDisplayGameStatus> with LanguagesApplication{
  @override
  void initState() {
    super.initState();
    languagesSetup(app.getChosenLanguage(), app.getStandardLanguage());
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;
    // If all active player(s) finished calculate winner

    if (app.gameFinished && app.gameStarted) {
      app.gameStarted = false;
      if (app.gameDices.unityDices) {
        app.gameDices.sendResetToUnity();
      }
    }

    var playerName = app.playerToMove == app.myPlayerId ? your_ : 
        (userNames.length > app.playerToMove && userNames[app.playerToMove].isNotEmpty 
          ? "${userNames[app.playerToMove]}'s" 
          : "Player ${app.playerToMove + 1}'s");
    var outputText = app.gameFinished ? gameFinished_ : "$playerName $turn_ ";

    Widget myWidget = Container(
        width: width,
        height: height,
        color: Colors.white.withValues(alpha: 0.3),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                  width: width,
                  height: height * 0.4,
                  child: AutoSizeText(outputText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: width / 5,
                          color: Colors.blueGrey))),
              if (app.myPlayerId != -1)
                SizedBox(
                    width: width,
                    height: height * 0.2,
                    child: FittedBox(
                        fit: BoxFit.contain,
                        child: Text(
                            "${app.gameDices.rollsLeft_}: ${(app.gameDices.nrTotalRolls - app.gameDices.nrRolls).toString()}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey))))
            ]));
    return myWidget;
  }
}



================================================
File: lib/application/widget_application_scaffold.dart
================================================
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/communication_application.dart';
import 'package:yatzy/chat/widget_chat.dart';
import 'package:yatzy/dices/unity_communication.dart';
import 'package:yatzy/dices/widget_dices.dart';
import 'package:yatzy/top_score/widget_top_scores.dart';

import '../router/router.gr.dart';
import '../scroll/widget_scroll.dart';
import '../services/service_provider.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';
import 'application.dart';
import 'widget_application.dart';

extension WidgetApplicationScaffold on Application {
  Widget widgetScaffold(BuildContext context, Function state) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    // Get best 16:9 fit
    var l = 0.0, t = 0.0, w = screenWidth, h = screenHeight, ratio = 16 / 9;
    if (w > h) {
      if (screenWidth / screenHeight < ratio) {
        h = screenWidth / ratio;
        t = (screenHeight - h) / 2;
      } else {
        w = screenHeight * ratio;
        l = (screenWidth - w) / 2;
      }
    } else {
      // topple screen, calculate best fit, topple back
      var l_ = 0.0, t_ = 0.0, w_ = screenHeight, h_ = screenWidth;

      if (screenHeight / screenWidth < ratio) {
        h_ = screenHeight / ratio;
        t_ = (screenWidth - h_) / 2;
      } else {
        w_ = screenWidth * ratio;
        l_ = (screenHeight - w_) / 2;
      }

      h = w_;
      w = h_;
      l = t_;
      t = l_;
    }

    //Widget empty(w,h) {return Container();}
    var floatingButtonSize = 0.06;

    Widget widgetFloatingButton(double size) {
      // Temporary move on portrait mode
      var moveButton = w > h ? 0 : h * 0.5;


      Widget widget = Stack(children: [
        Positioned(
            key: keySettings,
            left: l + (1.0 - floatingButtonSize * (size == h ? 2 : 1.1)) * w,
            top: t +
                (1.0 - floatingButtonSize * (size == w ? 2 : 1.1)) * h -
                moveButton,
            child: SizedBox(
                width: size * floatingButtonSize,
                height: size * floatingButtonSize,
                child: FittedBox(
                    child: FloatingActionButton(
                  heroTag: "NavigateSettings",
                  shape: const CircleBorder(),
                  onPressed: () async {
                    await AutoRouter.of(context).push(const SettingsView());
                  },
                  tooltip: settings_,
                  backgroundColor: Colors.blue.withValues(alpha: 0.5),
                  child: const Icon(Icons.settings_applications),
                ))))
      ]);

      return widget;
    }

    gameFinished = true;
    for (var i = 0; i < playerActive.length; i++) {
      if (playerActive[i]) {
        if (fixedCell[i].contains(false)) {
          gameFinished = false;
          break;
        }
      }
    }

    stackedWidgets = [];
    if (!gameDices.unityDices &&
        mainPageLoaded &&
        isTutorial &&
        callbackCheckPlayerToMove() &&
        gameDices.nrRolls < 3) {
      stackedWidgets = [
        tutorial.widgetArrow(gameDices.rollDiceKey, w, h,
            tutorial.animationController1, gameDices.pressToRoll_, 0, "R", 0.5)
      ];
      if (!tutorial.animationController1.isAnimating) {
        tutorial.animationController1.repeat(reverse: true);
      }
    }

    if (!gameDices.unityDices &&
        mainPageLoaded &&
        isTutorial &&
        callbackCheckPlayerToMove() &&
        (gameDices.nrRolls == 1 || gameDices.nrRolls == 2)) {
      stackedWidgets.add(tutorial.widgetArrow(gameDices.holdDiceKey[0], w, h,
          tutorial.animationController2, gameDices.pressToHold_, 1, "B", 0.5));
      if (!tutorial.animationController2.isAnimating) {
        tutorial.animationController2.repeat(reverse: true);
      }
    }

    if (mainPageLoaded &&
        isTutorial &&
        callbackCheckPlayerToMove() &&
        gameDices.nrRolls == 3) {
      stackedWidgets.add(tutorial.widgetArrow(
          cellKeys[myPlayerId + 1][totalFields - 5],
          w,
          h,
          tutorial.animationController2,
          chooseMove_,
          1,
          "R",
          devicePixelRatio > 2.5 ? 1.0 : 1.5));
      if (!tutorial.animationController2.isAnimating) {
        tutorial.animationController2.repeat(reverse: true);
      }
    }
    try {
      if (mainPageLoaded && isTutorial && gameFinished) {
        stackedWidgets.add(tutorial.widgetArrow(keySettings, w, h,
            tutorial.animationController3, pressSettings_, 2, "L", 0.5));
        if (!tutorial.animationController3.isAnimating) {
          tutorial.animationController3.repeat(reverse: true);
        }
      }
    } catch (e) {
      // Error
    }

    if (h > w) {
      return Scaffold(
          body: Stack(children: <Widget>[
        Image.asset("assets/images/yatzy_portrait.jpg",
            fit: BoxFit.cover, height: double.infinity, width: double.infinity),
        Stack(children: [
          Positioned(
              left: l,
              top: h * 0.75 + t,
              child: WidgetDices(width: w, height: h * 0.25)),
          Positioned(
              left: w * 0.35 + l,
              top: h * 0.0 + t,
              child: WidgetTopScore(width: w * 0.30, height: h * 0.2)),
          Positioned(
              left: l,
              top: h * 0.20 + t,
              child: WidgetSetupGameBoard(width: w, height: h * 0.55)),
          Positioned(
              left: w * 0.025 + l,
              top: h * 0.04 + t,
              child: WidgetDisplayGameStatus(width: w * 0.3, height: h * 0.16)),
          Positioned(
              left: w * 0.675 + l,
              top: h * 0.04 + t,
              child: WidgetChat(width: w * 0.30, height: h * 0.16)),
          WidgetAnimationsScroll(
              width: w,
              height: h * 0.1,
              left: w * 0.025 + l,
              top: -h * 0.03 + t)
        ]),
        widgetFloatingButton(h),
        Stack(children: stackedWidgets),
      ]));
    } else {
      // landscape

      return Scaffold(
          body: Stack(children: <Widget>[
        Image.asset("assets/images/yatzy_landscape2.jpg",
            fit: BoxFit.cover, height: double.infinity, width: double.infinity),
        Stack(children: [
          Positioned(
              left: w * 0.32 + l,
              top: h * 0.32 + t,
              child: WidgetDices(width: w * 0.625, height: h * 0.68)),
          Positioned(
              left: w * 0.81 + l,
              top: h * 0.02 + t,
              child: WidgetTopScore(width: w * 0.18, height: h * 0.3)),
          Positioned(
              left: l,
              top: t,
              child: WidgetSetupGameBoard(width: w * 0.35, height: h)),
          Positioned(
              left: w * 0.35 + l,
              top: h * 0.02 + t,
              child: WidgetDisplayGameStatus(width: w * 0.2, height: h * 0.3)),
          Positioned(
              left: w * 0.575 + l,
              top: h * 0.02 + t,
              child: WidgetChat(width: w * 0.22, height: h * 0.3)),
          WidgetAnimationsScroll(
              width: w * 0.43,
              height: h * 0.2,
              left: w * 0.355 + l,
              top: -h * 0.07 + t)
        ]),
        widgetFloatingButton(w),
        Stack(children: stackedWidgets),
      ]));
    }
  }
}



================================================
File: lib/application/widget_application_settings.dart
================================================
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/dices/unity_communication.dart';
import '../router/router.gr.dart';
import '../services/service_provider.dart';
import '../shared_preferences.dart';
import '../startup.dart';
import '../states/bloc/language/language_bloc.dart';
import '../states/bloc/language/language_event.dart';
import '../states/cubit/state/state_cubit.dart';
import '../widgets/spectator_game_board.dart';
import 'application.dart';

extension WidgetApplicationSettings on Application {
  List<Widget> widgetWaitingGame(BuildContext context) {
    List<Widget> gameWidgets = [];

    var ongoingGames = 0;
    for (var i = 0; i < games.length; i++) {
      if (!games[i]["gameStarted"]) {
        var gameTypeText = games[i]["gameType"];
        if (gameTypeText == "Ordinary") {
          gameTypeText = gameTypeOrdinary_;
        }
        var gameText = '$gameTypeText ${games[i]["connected"]}/${games[i]["nrPlayers"]} ${games[i]["userNames"]}';
        try {
          final serviceProvider = ServiceProvider.of(context);
          if (games[i]["playerIds"].indexOf(serviceProvider.socketService.socketId) == -1) {
            gameWidgets.add(inputItems.widgetButton(
                () => onAttemptJoinGame(context, i), gameText));
          } else {
            gameWidgets.add(Text(gameText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                )));
          }
        } catch (e) {
          print('⚠️ ServiceProvider not available in widgetWaitingGame: $e');
          // Add button without checking socket ID
          gameWidgets.add(inputItems.widgetButton(
              () => onAttemptJoinGame(context, i), gameText));
        }
      } else {
        // This is an ongoing game - add a spectate button
        ongoingGames++;
        var gameTypeText = games[i]["gameType"];
        if (gameTypeText == "Ordinary") {
          gameTypeText = gameTypeOrdinary_;
        }
        var gameText = '$gameTypeText ${games[i]["connected"]}/${games[i]["nrPlayers"]} ${games[i]["userNames"]} (Ongoing)';
        
        // Add spectate button
        gameWidgets.add(inputItems.widgetButton(
            () => onSpectateGame(context, games[i]["gameId"]), gameText));
      }
    }
    gameWidgets.add(Text("$ongoingGames_ : $ongoingGames",
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Colors.brown,
        )));
    return gameWidgets;
  }

  // Method to handle spectating a game
  onSpectateGame(BuildContext context, int gameId) async {
    print('🎮 Attempting to spectate game: $gameId');

    try {
      final serviceProvider = ServiceProvider.of(context);

      // Create a message to request spectating
      Map<String, dynamic> msg = {
        "action": "spectateGame",
        "gameId": gameId,
        "userName": userName // Send username for logging/display?
      };

      // Send the spectate request
      if (serviceProvider.socketService.isConnected) {
        print('🎮 Sending spectate request via socket service');

        // *** SET FLAG BEFORE sending request/setState ***
        isSpectating = true;
        spectatedGameId = gameId;
        gameData = {}; // Clear previous game data immediately

        serviceProvider.socketService.sendToServer(msg);

        // *** Update the UI AFTER setting the flags ***
        context.read<SetStateCubit>().setState(); // Update UI to show spectator board

        // Show a snackbar to indicate spectating has started
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('👁️ Spectating game #$gameId...'),
            duration: const Duration(seconds: 3),
          ),
        );

      } else {
        print('❌ Cannot spectate: Not connected to server');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot spectate: Not connected')),
        );
      }
    } catch (e) {
      print('⚠️ ServiceProvider not available in onSpectateGame: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error starting spectator mode')),
      );
      // Handle offline mode or show error
    }
  }

  onAttemptJoinGame(BuildContext context, int i) {
    Map<String, dynamic> msg = {};

    msg = games[i];

    msg["userName"] = userName;
    msg["action"] = "requestJoinGame";

    // Send the join game request
    print('🎮 Joining multiplayer game: ${msg["gameType"]} (${msg["nrPlayers"]} players)');

    // Get the service provider
    try {
      final serviceProvider = ServiceProvider.of(context);
      final socketServiceConnected = serviceProvider.socketService.isConnected;

      // Always use the modern SocketService if it's connected
      if (socketServiceConnected) {
        print('🎮 Using modern SocketService for joining game');
        serviceProvider.socketService.sendToServer(msg);
      }
    } catch (e) {
      print('⚠️ ServiceProvider not available in onAttemptJoinGame: $e');
      // Handle offline mode or show error
    }
  }

  // --- Simplified Game Type Selection ---
  Widget _buildGameTypeSelection(Function state) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.blue.shade50,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Text("Game Type", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), // Use headingStyle if available
                const SizedBox(height: 8),
                inputItems.widgetStringRadioButton( // Use widgetStringRadioButton
                    state,
                    [ // Simplified list of values
                      "Mini",
                      "Ordinary",
                      "Maxi",
                    ],
                    [ // Simplified list of translations
                      gameTypeMini_,
                      gameTypeOrdinary_,
                      gameTypeMaxi_,
                    ],
                        (x) => {gameType = x},
                    gameType),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // --- End Simplified Game Type Selection ---
  onStartGameButton(BuildContext context, Function state) async {
    try {
      final serviceProvider = ServiceProvider.of(context);
      final socketServiceConnected = serviceProvider.socketService.isConnected;

      if (socketServiceConnected) {
        Map<String, dynamic> msg = {};

        msg = {};
        msg["playerIds"] = List.filled(nrPlayers, "");
        msg["userNames"] = List.filled(nrPlayers, "");
        msg["userName"] = userName;
        msg["gameType"] = gameType;
        msg["nrPlayers"] = nrPlayers;
        msg["connected"] = 0;
        msg["gameStarted"] = false;
        msg["action"] = "requestGame";

        // Send through the active socket connection
        print('🎮 Creating multiplayer game with $nrPlayers players');

        // Always use the modern SocketService if it's connected
        if (socketServiceConnected) {
          print('🎮 Using modern SocketService for game creation');
          serviceProvider.socketService.sendToServer(msg);
        }

        state();

        msg = {};
        msg["action"] = "saveSettings";
        msg["userName"] = userName;
        msg["gameType"] = gameType;
        msg["nrPlayers"] = nrPlayers;
        msg["language"] = chosenLanguage;
        msg["boardAnimation"] = boardAnimation;
        msg["unityDices"] = gameDices.unityDices;
        msg["unityLightMotion"] = gameDices.unityLightMotion;
        SharedPrefProvider.setPrefObject('yatzySettings', msg);
      } else {
        print('❌ No socket connection - starting offline 1-player game');
        myPlayerId = 0;
        gameId = 0;
        playerIds = [""];
        playerActive = List.filled(playerIds.length, true);
        nrPlayers = 1;

        setup();
        userNames = [userName];
        animation.players = 1;
        if (applicationStarted) {
          if (gameDices.unityDices) {
            gameDices.sendResetToUnity();
            if (gameDices.unityDices && myPlayerId == playerToMove) {
              gameDices.sendStartToUnity();
            }
          }

          context.read<SetStateCubit>().setState();
          AutoRouter.of(context).pop();
        } else {
          applicationStarted = true;
          await AutoRouter.of(context).pushAndPopUntil(const ApplicationView(),
              predicate: (Route<dynamic> route) => false);
        }
      }
    } catch (e) {
      print('⚠️ ServiceProvider not available in onStartGameButton: $e');
      // Start offline game
      print('❌ No service provider - starting offline 1-player game');
      myPlayerId = 0;
      gameId = 0;
      playerIds = [""];
      playerActive = List.filled(playerIds.length, true);
      nrPlayers = 1;

      setup();
      userNames = [userName];
      animation.players = 1;
      if (applicationStarted) {
        if (gameDices.unityDices) {
          gameDices.sendResetToUnity();
          if (gameDices.unityDices && myPlayerId == playerToMove) {
            gameDices.sendStartToUnity();
          }
        }

        context.read<SetStateCubit>().setState();
        AutoRouter.of(context).pop();
      } else {
        applicationStarted = true;
        await AutoRouter.of(context).pushAndPopUntil(const ApplicationView(),
            predicate: (Route<dynamic> route) => false);
      }
    }
  }

  onChangeUserName(value) {
    userName = textEditingController.text;
  }

  // **** Updated Widget to use topScore instance ****
  Widget _buildTopScoresWidget() {
    // Read data directly from the global topScore instance
    if (topScore.topScores.isEmpty) { // Assuming the internal list is named topScores
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text("Top Scores for current game type will appear here...")),
      );
    }

    List<Widget> scoreWidgets = [];
    // Add header using the current gameType
    scoreWidgets.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Text(
          'Top Scores: $gameType', // Use app.gameType for the header
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
      )
    );

    // Limit display to top N scores
    int count = 0;
    // Iterate through the list in the topScore instance
    for (var scoreEntry in topScore.topScores) { 
      if (count >= 10) break; // Limit to top 10
      
      // Ensure scoreEntry is a Map before accessing keys
      if (scoreEntry is Map) {
          scoreWidgets.add(
            ListTile(
              dense: true,
              leading: Text('${count + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
              title: Text('${scoreEntry['name'] ?? 'Unknown'}'),
              trailing: Text('${scoreEntry['score'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          );
          count++;
      } else {
          print("⚠️ Invalid score entry format in topScore.topScores: $scoreEntry");
      }
    }
    
    // Add padding at the bottom
    scoreWidgets.add(const SizedBox(height: 10));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: scoreWidgets,
    );
  }
  // **** END UPDATED WIDGET ****

  Widget widgetScaffoldSettings(BuildContext context, Function state) {
    // Define a consistent color scheme for better visibility
    final primaryColor = Colors.blue.shade700; // Brighter primary color
    final accentColor = Theme.of(context).colorScheme.secondary;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    const tabTextStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white, // Ensure high contrast for tab text
    );

    final headingStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.onSurface,
    );

    final subtitleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.onSurface,
    );

    return DefaultTabController(
        length: tabController.length,
        child: Scaffold(
            appBar: AppBar(
              backgroundColor: primaryColor, // Explicitly set app bar color
              title: Text(
                settings_,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // High contrast white text
                  fontSize: 24,
                ),
              ),
              elevation: 4,
              bottom: TabBar(
                controller: tabController,
                isScrollable: false,
                indicatorWeight: 3,
                indicatorColor: Colors.white, // High contrast indicator
                labelColor: Colors.white, // Ensure high contrast for selected tab
                unselectedLabelColor: Colors.white.withOpacity(0.8), // Still visible unselected tabs
                tabs: [
                  Tab(child: Text(game_, style: tabTextStyle)),
                  Tab(child: Text(general_, style: tabTextStyle)),
                ],
              ),
            ),
            body: TabBarView(
              controller: tabController,
              children: [
                // Game Settings Tab
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.blue.shade50,
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Scrollbar(
                    child: ListView(
                        primary: true,
                        children: <Widget>[
                          // --- Use the simplified game type selection ---
                          _buildGameTypeSelection(state),
                          // --- End simplified game type selection ---
                              // Number of Players Selection
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  // Add decorative patterns to card
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomLeft,
                                        end: Alignment.topRight,
                                        colors: [
                                          Colors.white,
                                          Colors.blue.shade50,
                                        ],
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        children: [
                                          Text("Number of Players", style: headingStyle),
                                          const SizedBox(height: 8),
                                          inputItems.widgetIntRadioButton(
                                              state,
                                              ["1", "2", "3", "4"],
                                              (x) => {nrPlayers = x},
                                              nrPlayers),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Username Input
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  // Add decorative patterns to card
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.white,
                                          Colors.blue.shade50,
                                        ],
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        children: [
                                          Text("Player Name", style: headingStyle),
                                          const SizedBox(height: 8),
                                          Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  currentUsername_ + userName.toString(),
                                                  style: subtitleStyle,
                                                ),
                                                const SizedBox(width: 10),
                                                SizedBox(
                                                    width: 150,
                                                    height: 40,
                                                    child: inputItems.widgetInputText(
                                                        enterUsername_,
                                                        (x) => {onChangeUserName(x), state()},
                                                        (x) => {onChangeUserName(x), state()},
                                                        textEditingController,
                                                        focusNode)),
                                              ]),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Start Game Button - centered with appropriate width
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                  vertical: 8.0,
                                ),
                                child: Center(
                                  child: ElevatedButton(
                                    onPressed: () => onStartGameButton(context, state),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.green.shade700,
                                      minimumSize: const Size(200, 60), // Regular sized button
                                      padding: const EdgeInsets.symmetric(horizontal: 32),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 8,
                                    ),
                                    child: Text(
                                      createGame_,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ] +
                            // Available Games List
                            widgetWaitingGame(context) +
                            // **** ADD Top Scores Section ****
                            [ 
                              const SizedBox(height: 20), // Add some spacing
                              _buildTopScoresWidget(),
                              const SizedBox(height: 20), // Add some spacing
                            ] +
                            // Spectator View (if active)
                            (isSpectating ? [
                              // Full-screen spectator view
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: MediaQuery.of(context).size.height * 0.7, // 70% of screen height
                                  maxHeight: MediaQuery.of(context).size.height * 0.85, // 85% of screen height
                                ),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.blue.shade300),
                                    borderRadius: BorderRadius.circular(8.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Spectator header with close button
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(7.0),
                                            topRight: Radius.circular(7.0),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.visibility, color: Colors.blue, size: 22),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "Spectating Game #$spectatedGameId",
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.close, size: 18),
                                              label: const Text("Stop"),
                                              onPressed: () {
                                                // *** STOP SPECTATING LOGIC ***
                                                print('⏹️ Stopping spectator mode for game $spectatedGameId');
                                                isSpectating = false;
                                                spectatedGameId = -1;
                                                gameData = {}; // Clear the spectator data
                                                // Optionally send a message to server? (Not strictly necessary if server handles disconnects)
                                                // final serviceProvider = ServiceProvider.of(context);
                                                // serviceProvider.socketService.sendToServer({'action': 'stopSpectating', 'gameId': spectatedGameId});
                                                context.read<SetStateCubit>().setState(); // Update UI
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                                minimumSize: const Size(80, 30),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Spectator game board
                                      Expanded(
                                        child: SpectatorGameBoard(gameData: gameData), // Pass app.gameData
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] : []) +
                            // Unity Settings
                            gameDices.widgetUnitySettings(state)),
                  ),
                ),

                // General Settings Tab
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.blue.shade50,
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Scrollbar(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListView(
                        primary: true,
                        children: [
                          // Miscellaneous Settings Section
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white,
                                    Colors.blue.shade50,
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(misc_, style: headingStyle),
                                    const Divider(thickness: 1.5),
                                    const SizedBox(height: 8),
                                    // Animation Checkbox
                                    Theme(
                                      data: Theme.of(context).copyWith(
                                        checkboxTheme: CheckboxThemeData(
                                          fillColor: MaterialStateProperty.resolveWith<Color>(
                                            (Set<MaterialState> states) {
                                              if (states.contains(MaterialState.selected)) {
                                                return accentColor;
                                              }
                                              return Colors.grey.shade400;
                                            },
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                      child: inputItems.widgetCheckbox(
                                        (x) => {boardAnimation = x, state()},
                                        boardAnimation_,
                                        boardAnimation,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Language Selection
                                    Text("Language", style: subtitleStyle),
                                    const SizedBox(height: 8),
                                    inputItems.widgetDropDownList(
                                      () => {},
                                      " $choseLanguage_",
                                      differentLanguages,
                                      (language) => {
                                        chosenLanguage = language,
                                        context.read<LanguageBloc>().add(
                                          LanguageChanged(language: language),
                                        ),
                                        context.read<SetStateCubit>().setState()
                                      },
                                      chosenLanguage,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )));
  }
}



================================================
File: lib/chat/chat.dart
================================================
import 'package:flutter/cupertino.dart';

import '../input_items/input_items.dart';


class ChatMessage {
  ChatMessage(this.messageContent, this.messageType);

  var messageContent = "";
  var messageType = "";
}

class Chat {
  final Function _getChosenLanguage;
  final String _standardLanguage;

  Chat(
      {required Function getChosenLanguage,
      required String standardLanguage,
      required Function callback,
      required this.setState,
      required this.inputItems}) : _getChosenLanguage = getChosenLanguage,
        _standardLanguage = standardLanguage {

    callbackOnSubmitted = callback;
  }

  Function getChosenLanguage() {
    return _getChosenLanguage;
  }

  String standardLanguage() {
    return _standardLanguage;
  }

  final Function setState;
  final InputItems inputItems;
  late Function callbackOnSubmitted;
  final chatTextController = TextEditingController();
  final scrollController = ScrollController();
  var focusNode = FocusNode();
  var listenerKey = GlobalKey();

  // To get the slide in chat-bubble from bottom effect, 15 is for 4k full screen.
  // Otherwise chat starts from top and goes down. Maybe is some other way to start from bottom.
  List<ChatMessage> messages =
      List<ChatMessage>.generate(15, (index) => ChatMessage("", "Sender"));

  onSubmitted(String value, BuildContext context) async {
    var text = chatTextController.text;
    chatTextController.clear();
    messages.add(ChatMessage(text, "sender"));
    callbackOnSubmitted(text);

    setState();

    await Future.delayed(const Duration(milliseconds: 100), () {});
    scrollController.animateTo(scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn);
  }
}



================================================
File: lib/chat/languages_chat.dart
================================================
mixin LanguagesChat {
  late Function _getChosenLanguage;
  late String _standardLanguage;

  final _sendMessage = {"English": "Send message..."};

  String get sendMessage_ => getText(_sendMessage);

  void languagesSetup(Function getChosenLanguage, String standardLanguage) {
    _getChosenLanguage = getChosenLanguage;
    _standardLanguage = standardLanguage;
    _sendMessage["Swedish"] = "Skicka meddelande...";
  }

  String getText(var textVariable) {
    var text = textVariable[_getChosenLanguage()];
    if (text != null) {
      return text;
    } else {
      return textVariable[_standardLanguage]!;
    }
  }
}



================================================
File: lib/chat/widget_chat.dart
================================================
import 'package:flutter/material.dart';
import 'package:yatzy/chat/languages_chat.dart';
import '../startup.dart';


class WidgetChat extends StatefulWidget {
  final double width;
  final double height;

  const WidgetChat(
      {super.key, required this.width, required this.height});

  @override
  State<WidgetChat> createState() =>
      _WidgetChatState();
}

class _WidgetChatState extends State<WidgetChat> with LanguagesChat{
  @override
  void initState() {
    super.initState();
    languagesSetup(chat.getChosenLanguage(), chat.standardLanguage());
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;

    Widget widgetInputText(String hintText, Function onSubmitted,
        Function onChanged, TextEditingController controller, FocusNode focusNode,
        [int maxLength = 12]) {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: TextField(
            onChanged: (value) {
              onChanged(value);
            },
            onSubmitted: (value) {
              onSubmitted(value);
            },
            cursorColor: Colors.blue.shade700,
            focusNode: focusNode,
            controller: controller,
            maxLength: maxLength,
            style: const TextStyle(fontSize: 14.0, color: Colors.black87),
            decoration: InputDecoration(
              counterText: "",
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.9),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue.shade700, width: 2.0),
                borderRadius: BorderRadius.circular(25.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue.shade300, width: 1.0),
                borderRadius: BorderRadius.circular(25.0),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade600),
              suffixIcon: IconButton(
                icon: Icon(Icons.send, color: Colors.blue.shade700),
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    onSubmitted(controller.text);
                    controller.clear();
                  }
                },
              ),
            ),
          ));
    }

    Widget widgetChatOutput() {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          // Add a subtle gradient background
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50.withValues(alpha: 0.6),
              Colors.white.withValues(alpha: 0.2),
            ],
          ),
          // Add a subtle border
          border: Border.all(
            color: Colors.blue.shade200.withValues(alpha: 0.5),
            width: 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ListView.builder(
            controller: chat.scrollController,
            itemCount: chat.messages.length,
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 15, bottom: 10, left: 10, right: 10),
            itemBuilder: (context, index) {
              if (chat.messages[index].messageContent.isNotEmpty) {
                bool isReceiver = chat.messages[index].messageType == "receiver";
                return Container(
                  padding: const EdgeInsets.only(
                      left: 8, right: 8, top: 3, bottom: 3),
                  child: Align(
                    alignment: (isReceiver
                        ? Alignment.centerLeft
                        : Alignment.centerRight),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: width * 0.75, // Limit message width
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isReceiver ? 0 : 16),
                          bottomRight: Radius.circular(isReceiver ? 16 : 0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isReceiver 
                              ? [Colors.grey.shade200, Colors.grey.shade300]
                              : [Colors.blue.shade300, Colors.blue.shade400],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                      child: Text(
                        chat.messages[index].messageContent,
                        style: TextStyle(
                          fontSize: 14,
                          color: isReceiver ? Colors.black87 : Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Chat header
            Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade600,
                    Colors.blue.shade800,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      "Chat",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Chat messages area
            Expanded(
              child: widgetChatOutput(),
            ),
            // Input area
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: widgetInputText(
                sendMessage_, 
                (x) => chat.onSubmitted(x, context), 
                (x) => {},
                chat.chatTextController, 
                chat.focusNode, 
                150
              ),
            ),
          ],
        ),
      ),
    );
  }
}



================================================
File: lib/core/app_widget.dart
================================================
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/communication_application.dart';
import 'package:yatzy/dices/dices.dart';
import 'package:yatzy/services/service_provider.dart';
import '../application/application.dart';
import '../chat/chat.dart';
import '../injection.dart';
import '../router/router.dart';
import '../scroll/animations_scroll.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';
import '../top_score/top_score.dart';
import '../tutorial/tutorial.dart';

class AppWidget extends StatelessWidget {
  AppWidget({super.key});

  final _appRouter = getIt<AppRouter>();

  String getChosenLanguage() {
    return chosenLanguage;
  }

  @override
  Widget build(BuildContext context) {

    // Initialize application components
    topScore = TopScore(
        getChosenLanguage: getChosenLanguage,
        standardLanguage: standardLanguage);
    animationsScroll = AnimationsScroll(
        getChosenLanguage: getChosenLanguage,
        standardLanguage: standardLanguage);
    tutorial = Tutorial();
    dices = Dices(
        getChosenLanguage: getChosenLanguage,
        standardLanguage: standardLanguage,
        setState: () => context.read<SetStateCubit>().setState(),
        inputItems: inputItems);
    app =
        Application(context: context, gameDices: dices, inputItems: inputItems);
    chat = Chat(
        getChosenLanguage: getChosenLanguage,
        standardLanguage: standardLanguage,
        callback: app.chatCallbackOnSubmitted,
        setState: () => context.read<SetStateCubit>().setState(),
        inputItems: inputItems);
    
    // Initialize modern service architecture wrapped around the router
    return ServiceProvider.initialize(
      context: context,
      child: MaterialApp.router(
        title: 'Yatzy Game',
        debugShowCheckedModeBanner: false,
        routerDelegate: _appRouter.delegate(),
        routeInformationParser: _appRouter.defaultRouteParser(),
        theme: ThemeData(
          primarySwatch: Colors.blueGrey,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        builder: (context, child) {
          // After the app is built, connect to the socket server once
          // using the service provider's socket service
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              final service = ServiceProvider.of(context);
              
              print('🔄 AppWidget: Initializing network connectivity');
              // Only connect if not already connected
              if (!service.socketService.isConnected) {
                print('🔌 AppWidget: Connecting modern SocketService');
                service.socketService.connect();
              }
              
              // Connect the Application instance with the SocketService to enable
              // multiplayer dice synchronization
              print('🔄 AppWidget: Connecting modern SocketService to Application instance');
              app.setSocketService(service.socketService);
            } catch (e) {
              print('⚠️ ServiceProvider not available in AppWidget: $e');
              print('🔄 AppWidget: Running in offline mode');
              // Continue in offline mode
            }
          });
          return child!;
        },
      ),
    );
  }
}



================================================
File: lib/core/injectable_modules.dart
================================================
import 'package:injectable/injectable.dart';

import '../router/router.dart';

@module
abstract class InjectableModule {
  @lazySingleton
  AppRouter get router => AppRouter();
}



================================================
File: lib/dices/dices.dart
================================================
import 'dart:math';

import 'package:flutter/cupertino.dart';
import '../input_items/input_items.dart';
import 'unity_communication.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

import 'languages_dices.dart';


class Dices extends LanguagesDices  {
  final Function setState;
  final InputItems inputItems;
  Dices(
      {required Function getChosenLanguage, required String standardLanguage, required this.setState, required this.inputItems}) {
    languagesSetup(getChosenLanguage, standardLanguage);

    for (var i = 0; i < 6; i++) {
      holdDiceKey.add(GlobalKey());
    }
  }

  setCallbacks(cbUpdateDiceValues, cbUnityCreated, cbCheckPlayerToMove) {
    callbackUpdateDiceValues = cbUpdateDiceValues;
    callbackUnityCreated = cbUnityCreated;
    callbackCheckPlayerToMove = cbCheckPlayerToMove;
  }

  var holdDices = [], holdDiceText = [], holdDiceOpacity = [];


  var nrRolls = 0;
  var nrTotalRolls = 3;
  var nrDices = 5;
  var diceValue = List.filled(5, 0);
  var diceRef = [
    "assets/images/empty.jpg",
    "assets/images/empty.jpg",
    "assets/images/empty.jpg",
    "assets/images/empty.jpg",
    "assets/images/empty.jpg"
  ];
  var diceFile = [
    "empty.jpg",
    "1.jpg",
    "2.jpg",
    "3.jpg",
    "4.jpg",
    "5.jpg",
    "6.jpg"
  ];
  var rollDiceKey = GlobalKey();
  var holdDiceKey = [];
  late Function callbackUpdateDiceValues;
  late Function callbackUnityCreated;
  late Function callbackCheckPlayerToMove;
  late AnimationController animationController;
  late Animation<double> sizeAnimation;
  late UnityWidgetController unityWidgetController;
  var unityCreated = false;
  var unityColors = [0.0, 0.0, 0.0, 0.1];
  var unityDices = false;
  var unityTransparent = true;
  var unityLightMotion = false;
  var unityFun = false;
  var unitySnowEffect = false;
  var unityId = "";


  clearDices() {
    diceValue = List.filled(nrDices, 0);
    holdDices = List.filled(nrDices, false);
    holdDiceText = List.filled(nrDices, "");
    holdDiceOpacity = List.filled(nrDices, 0.0);
    diceRef = List.filled(nrDices, "assets/images/empty.jpg");
    nrRolls = 0;
  }

  initDices(int nrdices) {
    if (unityCreated) {
      sendResetToUnity();
    }
    nrDices = nrdices;
    diceValue = List.filled(nrDices, 0);
    holdDices = List.filled(nrDices, false);
    holdDiceText = List.filled(nrDices, "");
    holdDiceOpacity = List.filled(nrDices, 0.0);
    diceRef = List.filled(nrDices, "assets/images/empty.jpg");
    nrRolls = 0;
  }

  holdDice(int dice) {
    if (diceValue[0] != 0 && nrRolls < nrTotalRolls) {
      holdDices[dice] = !holdDices[dice];
      if (holdDices[dice]) {
        holdDiceText[dice] = hold_;
        holdDiceOpacity[dice] = 0.7;
      } else {
        holdDiceText[dice] = "";
        holdDiceOpacity[dice] = 0.0;
      }
    }
  }

  updateDiceImages() {
    for (var i = 0; i < nrDices; i++) {
      diceRef[i] = "assets/images/${diceFile[diceValue[i]]}";
    }
  }

  bool rollDices(BuildContext context) {
    if (nrRolls < nrTotalRolls) {
      nrRolls += 1;
      var randomNumberGenerator = Random(DateTime.now().millisecondsSinceEpoch);
      for (var i = 0; i < nrDices; i++) {
        if (!holdDices[i]) {
          diceValue[i] = randomNumberGenerator.nextInt(6) + 1;
          diceRef[i] = "assets/images/${diceFile[diceValue[i]]}";
        } else {
          if (nrRolls == nrTotalRolls) {
            holdDices[i] = false;
            holdDiceText[i] = "";
            holdDiceOpacity[i] = 0.0;
          }
        }
      }
      callbackUpdateDiceValues();

      return true;
    }
    return false;
  }

  List<Widget> widgetUnitySettings(Function state) {
    List<Widget> widgets = [];
    widgets.add(inputItems.widgetCheckbox(
            (x) => {unityDices = x, state()}, choseUnity_, unityDices));
    widgets.add(inputItems.widgetCheckbox(
            (x) => {unityLightMotion = x, state() , sendLightMotionChangedToUnity()},
        lightMotion_,
        unityLightMotion));
    widgets.add(inputItems.widgetCheckbox(
            (x) => {unityFun = x, state(), sendFunChangedToUnity()}, fun_, unityFun));
    widgets.add(inputItems.widgetCheckbox(
            (x) => {unitySnowEffect = x, state(),sendSnowEffectChangedToUnity()},
        snowEffect_,
        unitySnowEffect));
    return widgets;
  }
}



================================================
File: lib/dices/languages_dices.dart
================================================
class LanguagesDices{
  late Function _getChosenLanguage;
  late String _standardLanguage;

  final _hold = {"English": "HOLD"};
  final _rollsLeft = {"English": "Rolls left"};
  final _transparency = {"English": "Transparency"};
  final _lightMotion = {"English": "Light Motion"};
  final _red = {"English": "Red"};
  final _green = {"English": "Green"};
  final _blue = {"English": "Blue"};
  final _choseUnity = {"English": "3D Dices"};
  final _colorChangeOverlay = {"English": "Color Change Overlay"};
  final _fun = {"English": "Fun!"};
  final _snowEffect = {"English": "Snow Effect"};
  final _pressToRoll = {"English": "\nPress To Roll"};
  final _pressToHold = {"English": "Press To \nHold/UnHold"};

  String get choseUnity_ => getText(_choseUnity);

  String get colorChangeOverlay_ => getText(_colorChangeOverlay);

  String get hold_ => getText(_hold);

  String get transparency_ => getText(_transparency);

  String get lightMotion_ => getText(_lightMotion);

  String get red_ => getText(_red);

  String get green_ => getText(_green);

  String get blue_ => getText(_blue);

  String get rollsLeft_ => getText(_rollsLeft);

  String get fun_ => getText(_fun);

  String get snowEffect_ => getText(_snowEffect);

  String get pressToRoll_ => getText(_pressToRoll);

  String get pressToHold_ => getText(_pressToHold);

  void languagesSetup(Function getChosenLanguage, String standardLanguage) {
    _getChosenLanguage = getChosenLanguage;
    _standardLanguage = standardLanguage;
    _choseUnity["Swedish"] = "3D Tärningar";
    _colorChangeOverlay["Swedish"] = "Färginställningar Live";
    _hold["Swedish"] = "HÅLL";
    _rollsLeft["Swedish"] = "Kast kvar";
    _transparency["Swedish"] = "Transparens";
    _lightMotion["Swedish"] = "Cirkulärt Ljus";
    _red["Swedish"] = "Röd";
    _green["Swedish"] = "Grön";
    _blue["Swedish"] = "Blå";
    _rollsLeft["Swedish"] = "Kast kvar";
    _fun["Swedish"] = "Kul!";
    _snowEffect["Swedish"] = "Snö Effekt";
    _pressToRoll["Swedish"] = "Tryck För Att \nKasta";
    _pressToHold["Swedish"] = "Tryck För Att \nHålla/Släppa";
  }

  String getText(var textVariable) {
    var text = textVariable[_getChosenLanguage()];
    if (text != null) {
      return text;
    } else {
      return textVariable[_standardLanguage]!;
    }
  }
}



================================================
File: lib/dices/unity_communication.dart
================================================
import 'dart:convert';

import 'unity_message.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

import 'dices.dart';

extension UnityCommunication on Dices {
  sendResetToUnity() {
    UnityMessage msg = UnityMessage.reset(nrDices, nrTotalRolls);

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  sendStartToUnity() {
    UnityMessage msg = UnityMessage.start();

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  sendDicesToUnity() {
    var msg = UnityMessage.updateDices(diceValue);

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  sendColorsToUnity() {
    var msg = UnityMessage.updateColors(unityColors);

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  sendTransparencyChangedToUnity() {
    var msg = UnityMessage.changeBool("Transparency", unityTransparent);

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  sendLightMotionChangedToUnity() {
    var msg = UnityMessage.changeBool("LightMotion", unityLightMotion);

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  sendFunChangedToUnity() {
    var msg = UnityMessage.changeBool("Fun", unityFun);

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  sendSnowEffectChangedToUnity() {
    var msg = UnityMessage.changeBool("SnowEffect", unitySnowEffect);

    var json = msg.toJson();

    unityWidgetController.postMessage(
      "GameManager",
      "flutterMessage",
      jsonEncode(json),
    );
  }

  // Communication from Unity to Flutter
  onUnityMessage(message) {
    var msg = message.toString();
    print("Received message from unity: $msg");
    try {
      var json = jsonDecode(msg);
      if (json["actionUnity"] == "results") {
        diceValue = json["diceResult"].cast<int>();
        callbackUpdateDiceValues();
        nrRolls += 1;
      }
      if (json["actionUnity"] == "unityIdentifier") {
        unityId = json["unityId"];
        sendSnowEffectChangedToUnity();
        sendFunChangedToUnity();
        sendLightMotionChangedToUnity();
        sendResetToUnity();
        if (callbackCheckPlayerToMove()) {
          sendStartToUnity();
        }
      }
    } catch (e) {
      //Error
    }
  }

  onUnityUnloaded() {}

  // Callback that connects the created controller to the unity controller
  onUnityCreated(controller) {
    unityWidgetController = controller;
    unityCreated = true;
    sendResetToUnity();
    callbackUnityCreated();

    print("Unity Created");
  }

  // Communication from Unity when new scene is loaded to Flutter
  onUnitySceneLoaded(SceneLoaded? sceneInfo) {}
}



================================================
File: lib/dices/unity_message.dart
================================================
class UnityMessage {
  UnityMessage(this.actionUnity);

  UnityMessage.reset(this.nrDices, this.nrThrows) {
    actionUnity = "reset";
  }

  UnityMessage.start() {
    actionUnity = "start";
  }

  UnityMessage.updateDices(this.dices) {
    actionUnity = "setProperty";
    property = "Dices";
  }

  UnityMessage.updateColors(this.unityColors) {
    actionUnity = "setProperty";
    property = "Color";
  }

  UnityMessage.changeBool(this.property, this.flag) {
    actionUnity = "setProperty";
  }

  UnityMessage.fromJson(Map<String, dynamic> json)
      : actionUnity = json["actionUnity"],
        nrDices = json["nrDices"],
        nrThrows = json["nrThrows"],
        property = json["property"],
        unityColors = json["colors"],
        flag = json["flag"],
        dices = json["Dices"];

  Map<String, dynamic> toJson() => {
        "actionUnity": actionUnity,
        "nrDices": nrDices,
        "nrThrows": nrThrows,
        "property": property,
        "colors": unityColors,
        "bool": flag,
        "Dices": dices,
      };

  var actionUnity = "";
  var property = "";
  var dices = [];
  var unityColors = [0.6, 0.7, 0.8, 0.1];
  var flag = true;
  var nrDices = 5;
  var nrThrows = 3;
}



================================================
File: lib/dices/widget_dices.dart
================================================
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import '../startup.dart';
import 'unity_communication.dart';

class WidgetDices extends StatefulWidget {
  final double width;
  final double height;

  const WidgetDices({super.key, required this.width, required this.height});

  @override
  State<WidgetDices> createState() => _WidgetDicesState();
}

class _WidgetDicesState extends State<WidgetDices>
    with TickerProviderStateMixin {

  setupAnimation(TickerProvider ticket) {
    app.gameDices.animationController = AnimationController(
        vsync: ticket, duration: const Duration(milliseconds: 300));
    app.gameDices.sizeAnimation =
        CurveTween(curve: Curves.easeInSine).animate(app.gameDices.animationController);

    app.gameDices.animationController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        app.gameDices.animationController.reverse();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    setupAnimation(this);
  }

  @override
  void dispose(){
    super.dispose();
    app.gameDices.animationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;
    // First always start unity and hide if only 2D
    // Get best 16:9 fit
    var left = 0.0, top = 0.0, w = width, h = height, ratio = 16 / 9;
    if (w > h) {
      if (width / height < ratio) {
        h = width / ratio;
        top = (height - h) / 2;
      } else {
        w = height * ratio;
        left = (width - w) / 2;
      }
    } else {
      // topple screen, calculate best fit, topple back
      var l_ = 0.0, t_ = 0.0, w_ = height, h_ = width;

      if (height / width < ratio) {
        h_ = height / ratio;
        t_ = (width - h_) / 2;
      } else {
        w_ = width * ratio;
        l_ = (height - w_) / 2;
      }

      h = w_;
      w = h_;
      left = t_;
      top = l_;
    }

    if (app.gameDices.unityDices) {
      Widget widgetUnity = Positioned(
          left: left,
          top: top,
          child: SizedBox(
              // Add 75 to subtract at canvas to avoid scrollbars
              width: w + 75,
              height: h + 75,
              child: UnityWidget(
                borderRadius: BorderRadius.zero,
                onUnityCreated: app.gameDices.onUnityCreated,
                onUnityMessage: app.gameDices.onUnityMessage,
                onUnityUnloaded: app.gameDices.onUnityUnloaded,
                onUnitySceneLoaded: app.gameDices.onUnitySceneLoaded,
                fullscreen: false,
              )));

      return SizedBox(
          width: width, height: height, child: Stack(children: [widgetUnity]));
    }

    var listings = <Widget>[];

    double diceWidthHeight = 4 * width / (5 * app.gameDices.nrDices + 1);
    left = diceWidthHeight / 4;
    top = min(diceWidthHeight / 2,
        diceWidthHeight / 2 + (height - diceWidthHeight * 3.5) / 2);

    for (var i = 0; i < app.gameDices.nrDices; i++) {
      listings.add(
        Positioned(
            left: left + 1.25 * diceWidthHeight * i,
            top: top,
            child: Container(
              width: diceWidthHeight,
              height: diceWidthHeight,
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.3)),
              child: Image.asset(app.gameDices.diceRef[i]),
            )),
      );
      listings.add(Positioned(
        key: app.gameDices.holdDiceKey[i],
        left: left + 1.25 * diceWidthHeight * i,
        top: top,
        child: GestureDetector(
            onTap: () {
              app.gameDices.holdDice(i);

              app.gameDices.setState();
            },
            child: Container(
              width: diceWidthHeight,
              height: diceWidthHeight,
              decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 
                      app.gameDices.holdDiceOpacity.isNotEmpty
                          ? app.gameDices.holdDiceOpacity[i]
                          : 0.44)),
              child: FittedBox(
                alignment: Alignment.bottomCenter,
                fit: BoxFit.contain,
                child: Text(
                  app.gameDices.holdDiceText.isNotEmpty
                      ? app.gameDices.holdDiceText[i]
                      : "HOLD",
                  style: TextStyle(
                    color: Colors.black87.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )),
      ));
    }

    // Roll button

    listings.add(AnimatedBuilder(
      animation: app.gameDices.animationController,
      builder: (BuildContext context, Widget? widget) {
        final tmp = Listener(
            onPointerDown: (e) {
              if (!app.callbackCheckPlayerToMove()) {
                return;
              }
              if (app.gameDices.rollDices(context)) {
                app.gameDices.animationController.forward();

                app.gameDices.setState();
              }
            },
            child: Container(
              width: diceWidthHeight * (1 - app.gameDices.sizeAnimation.value / 2),
              height: diceWidthHeight * (1 - app.gameDices.sizeAnimation.value / 2),
              decoration: const BoxDecoration(color: Colors.red),
              child: Image.asset("assets/images/roll.jpg",
                  fit: BoxFit.cover,
                  height: double.infinity,
                  width: double.infinity),
            ));
        return Positioned(
          key: app.gameDices.rollDiceKey,
          left: left +
              diceWidthHeight * ((app.gameDices.sizeAnimation.value) / 4) +
              width / 2 -
              diceWidthHeight * 3 / 4,
          top: top +
              diceWidthHeight * (app.gameDices.sizeAnimation.value / 4) +
              1.5 * diceWidthHeight,
          child: tmp,
        );
      },
    ));

    return SizedBox(
        width: width, height: height, child: Stack(children: listings));
  }
}



================================================
File: lib/input_items/input_items.dart
================================================
import 'package:flutter/material.dart';

class InputItems {
  Widget widgetImage(double width, double height, String image) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Center(
        child:
            SizedBox(width: width, height: height, child: Image.asset(image)),
      ),
    );
  }

  Widget widgetInputDBEntry(String hintText, TextEditingController controller) {
    return Padding(
        padding:
            const EdgeInsets.only(left: 5.0, right: 5.0, top: 0, bottom: 0),
        child: TextField(
          cursorColor: Colors.black,
          controller: controller,
          style: const TextStyle(fontSize: 14.0, color: Colors.black),
          decoration: InputDecoration(
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 2.0),
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 5.0, horizontal: 5.0),
            border: const OutlineInputBorder(),
            hintText: hintText,
          ),
        ));
  }

  Widget widgetInputText(String hintText, Function onSubmitted,
      Function onChanged, TextEditingController controller, FocusNode focusNode,
      [int maxLength = 12]) {
    return Padding(
        padding:
            const EdgeInsets.only(left: 5.0, right: 5.0, top: 0, bottom: 0),
        child: TextField(
          onChanged: (value) {
            onChanged(value);
          },
          onSubmitted: (value) {
            onSubmitted(value);
          },
          cursorColor: Colors.black,
          focusNode: focusNode,
          controller: controller,
          maxLength: maxLength,
          style: const TextStyle(fontSize: 14.0, color: Colors.black),
          decoration: InputDecoration(
            counterText: "",
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 2.0),
              //borderRadius: BorderRadius.circular(25.0),
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 5.0, horizontal: 5.0),
            border: const OutlineInputBorder(),
            hintText: hintText,
          ),
        ));
  }

  // Widget widgetInputEmail(
  //     String labelText, String hintText, TextEditingController controller) {
  //   return Padding(
  //     padding:
  //         const EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 0),
  //     child: SizedBox(
  //         width: 300,
  //         child: TextFormField(
  //           controller: controller,
  //           keyboardType: TextInputType.text,
  //           decoration: InputDecoration(
  //               border: const OutlineInputBorder(),
  //               labelText: labelText,
  //               hintText: hintText),
  //           validator: (value) {
  //             if (value!.isEmpty) {
  //               return labelText + languagesGlobal.isRequired_;
  //             } else {
  //               return "";
  //             }
  //           },
  //         )),
  //   );
  // }

  // Widget widgetInputPassword(
  //     String labelText, String hintText, TextEditingController controller) {
  //   return Padding(
  //     padding:
  //         const EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 0),
  //     child: SizedBox(
  //         width: 300,
  //         child: TextFormField(
  //           obscureText: true,
  //           controller: controller,
  //           keyboardType: TextInputType.text,
  //           decoration: InputDecoration(
  //               border: const OutlineInputBorder(),
  //               labelText: labelText,
  //               hintText: hintText),
  //           validator: (value) {
  //             if (value!.isEmpty) {
  //               return labelText + languagesGlobal.isRequired_;
  //             } else {
  //               return "";
  //             }
  //           },
  //         )),
  //   );
  // }

  Widget widgetTextLink(Function onPressed, String text) {
    return TextButton(
      onPressed: () {
        onPressed();
      },
      child: Text(
        text,
        style: const TextStyle(color: Colors.blue, fontSize: 15),
      ),
    );
  }

  // decoration: BoxDecoration(
  // color: Colors.transparent,
  // boxShadow: [
  // BoxShadow(
  // color: Colors.grey.shade600,
  // spreadRadius: 1,
  // blurRadius: 15
  // )
  // ]
  // ),

  Widget widgetButton(Function onPressed, String text) {
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: ElevatedButton(
        onPressed: () {
          onPressed();
        },
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.blue.shade700,
          minimumSize: const Size(200, 50),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 6,
          shadowColor: Colors.blue.shade900,
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget widgetSizedBox(double height) {
    return SizedBox(
      height: height,
    );
  }

  Widget widgetIntRadioButton(
      Function state, List<String> values, Function onChanged, int radioValue) {
    Widget radioButton(String name) {
      return Radio(
          value: name,
          groupValue: radioValue.toString(),
          activeColor: Colors.blue.shade700, // Enhanced active color
          fillColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.blue.shade700;
            }
            return Colors.grey.shade600; // Better visible inactive color
          }),
          onChanged: (s) {
            onChanged(int.parse(s as String));
            state();
          });
    }

    var radioWidgets = <Widget>[];
    for (var i = 0; i < values.length; i++) {
      radioWidgets.add(radioButton(values[i]));
      radioWidgets.add(
        Text(
          values[i],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        )
      );
    }
    return Row(
        mainAxisAlignment: MainAxisAlignment.center, children: radioWidgets);
  }

  Widget widgetStringRadioButtonSplit(
      Function state,
      List<String> values,
      List<String> translations,
      Function onChanged,
      String radioValue,
      int splitPoint) {
    Widget radioButton(String name) {
      return Radio(
          value: name,
          groupValue: radioValue,
          activeColor: Colors.blue.shade700, // Enhanced active color
          fillColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.blue.shade700;
            }
            return Colors.grey.shade600; // Better visible inactive color
          }),
          onChanged: (s) {
            onChanged(s as String);
            state();
          });
    }

    var radioWidgets1 = <Widget>[];
    var radioWidgets2 = <Widget>[];
    for (var i = 0; i < splitPoint; i++) {
      radioWidgets1.add(radioButton(values[i]));
      radioWidgets1.add(
        Text(
          translations[i],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        )
      );
    }

    for (var i = splitPoint; i < values.length; i++) {
      radioWidgets2.add(radioButton(values[i]));
      radioWidgets2.add(
        Text(
          translations[i],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        )
      );
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: radioWidgets1
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: radioWidgets2
        ),
      ),
    ]);
  }

  Widget widgetStringRadioButton(Function state, List<String> values,
      List<String> translations, Function onChanged, String radioValue) {
    Widget radioButton(String name) {
      return Radio(
          value: name,
          groupValue: radioValue,
          activeColor: Colors.blue.shade700, // Enhanced active color
          fillColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.blue.shade700;
            }
            return Colors.grey.shade600; // Better visible inactive color
          }),
          onChanged: (s) {
            onChanged(s as String);
            state();
          });
    }

    var radioWidgets = <Widget>[];
    for (var i = 0; i < values.length; i++) {
      radioWidgets.add(radioButton(values[i]));
      radioWidgets.add(
        Text(
          translations[i],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        )
      );
    }
    return Row(
        mainAxisAlignment: MainAxisAlignment.center, children: radioWidgets);
  }

  Color getColor(Set<WidgetState> states) {
    const Set<WidgetState> interactiveStates = <WidgetState>{
      WidgetState.pressed,
      WidgetState.hovered,
      WidgetState.focused,
    };
    if (states.any(interactiveStates.contains)) {
      return Colors.blue.shade600;
    }
    return Colors.blue.shade800; // Changed from red to blue for better aesthetics
  }

  Widget widgetCheckbox(
      Function onChanged, String text, bool toggles) {
    List<Widget> checkWidgets = [];

    checkWidgets.add(SizedBox(
        height: 24, // Increased height for better touch target
        width: 24, // Added width for better proportions
        child: Checkbox(
            checkColor: Colors.white,
            fillColor: WidgetStateProperty.resolveWith(getColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4), // Slightly rounded corners
            ),
            value: toggles,
            onChanged: (bool? value) {
              onChanged(value);
            })));
    checkWidgets.add(Padding(
      padding: const EdgeInsets.only(left: 8.0), // Added padding for text
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87, // Better contrast than default
        ),
      ),
    ));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: checkWidgets, // Better vertical alignment
    );
  }

  Widget widgetSlider(BuildContext context, Function state, String text,
      Function onChanged, double slider) {
    var sliderWidgets = <Widget>[];

    sliderWidgets.add(SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: Colors.blue,
          inactiveTrackColor: Colors.blue,
          trackShape: const RectangularSliderTrackShape(),
          trackHeight: 2.0,
          thumbColor: Colors.blueAccent,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
          overlayColor: Colors.red.withAlpha(32),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
        ),
        child: SizedBox(
            //width: 150,
            height: 15,
            child: Slider(
              value: slider,
              onChanged: (value) {
                onChanged(value);
                state();
              },
            ))));
    sliderWidgets.add(Text(text));
    return Row(children: sliderWidgets);
  }

  Widget widgetDropDownList(Function state, String text, List<String> items,
      Function onChanged, String choice) {
    var dropWidgets = <Widget>[];

    dropWidgets.add(Padding(
        padding: const EdgeInsets.all(4.0),
        child: SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              value: choice,
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              focusColor: Colors.white,
              dropdownColor: Colors.white, // Added dropdown menu color
              decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(width: 2, color: Colors.blue.shade600),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(width: 2, color: Colors.blue.shade700),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50, // Background fill for better visibility
              ),
              icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade700), // Custom dropdown icon
              onChanged: (String? value) {
                onChanged(value);
                state();
              },
              items: items
                  .map((item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item, style: const TextStyle(fontSize: 16))))
                  .toList(),
            ))));
    dropWidgets.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        text, 
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
      )
    ));
    return Row(children: dropWidgets);
  }

  Widget widgetParagraph(String text) {
    var paragraphWidgets = <Widget>[];
    paragraphWidgets.add(Text(
      text,
      style: TextStyle(
        color: Colors.blue.shade900,
        fontSize: 20, 
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic
      )
    ));
    paragraphWidgets.add(Divider(
      height: 20,
      thickness: 2,
      indent: 0,
      endIndent: 50,
      color: Colors.blue.shade200, // Added color to divider
    ));
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: paragraphWidgets);
  }
}



================================================
File: lib/models/board_cell.dart
================================================
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



================================================
File: lib/models/game.dart
================================================
import 'package:flutter/foundation.dart';
import 'board_cell.dart';
import 'player.dart';

/// Represents a Yatzy game
class Game {
  /// Unique identifier for the game
  final int gameId;
  
  /// Type of game (e.g., "Ordinary", "Mini", "Maxi")
  final String gameType;
  
  /// Maximum number of players
  final int maxPlayers;
  
  /// Players in the game
  final List<Player> players;
  
  /// Whether the game has started
  bool gameStarted;
  
  /// Whether the game has finished
  bool gameFinished;
  
  /// Index of the player whose turn it is
  int playerToMove;
  
  /// Current dice values
  List<int> diceValues;
  
  /// Number of rolls made in the current turn
  int rollCount;
  
  /// Maximum rolls allowed per turn
  final int maxRolls;
  
  /// Threshold for bonus in the upper section
  final int bonusThreshold;
  
  /// Amount of bonus points awarded
  final int bonusAmount;
  
  /// Index of the last upper section field (for bonus calculation)
  final int upperSectionEndIndex;
  
  /// Cell labels based on game type
  final List<String> cellLabels;
  
  /// My player index in the game
  int myPlayerIndex;
  
  /// Whether board animations are enabled
  bool boardAnimation;
  
  /// Callback when player turns change
  VoidCallback? onPlayerTurnChanged;
  
  /// Callback when dice values change
  VoidCallback? onDiceValuesChanged;
  
  Game({
    required this.gameId,
    required this.gameType,
    required this.maxPlayers,
    required this.players,
    this.gameStarted = false,
    this.gameFinished = false,
    this.playerToMove = 0,
    this.diceValues = const [],
    this.rollCount = 0,
    this.maxRolls = 3,
    this.bonusThreshold = 63,
    this.bonusAmount = 50,
    this.upperSectionEndIndex = 5,
    required this.cellLabels,
    this.myPlayerIndex = 0,
    this.boardAnimation = false,
    this.onPlayerTurnChanged,
    this.onDiceValuesChanged,
  });
  
  /// Check if it's the current player's turn
  bool get isMyTurn => myPlayerIndex == playerToMove && players[playerToMove].isActive;
  
  /// Check if the current player can roll again
  bool get canRoll => isMyTurn && rollCount < maxRolls;
  
  /// Get the current player
  Player get currentPlayer => players[playerToMove];
  
  /// Get my player
  Player get myPlayer => players[myPlayerIndex];
  
  /// Calculate scores for all players
  void calculateScores() {
    for (var player in players) {
      player.calculateScores(
        bonusThreshold: bonusThreshold,
        bonusAmount: bonusAmount,
        upperSectionEnd: upperSectionEndIndex,
      );
    }
  }
  
  /// Advance to the next active player
  void advanceToNextPlayer() {
    int nextPlayer = (playerToMove + 1) % maxPlayers;
    int startPlayer = playerToMove;
    
    // Find next active player
    while (!players[nextPlayer].isActive) {
      nextPlayer = (nextPlayer + 1) % maxPlayers;
      
      // If we've checked all players and none are active, keep current player
      if (nextPlayer == startPlayer) {
        break;
      }
    }
    
    if (playerToMove != nextPlayer) {
      playerToMove = nextPlayer;
      rollCount = 0;
      
      // Notify that player turn changed
      if (onPlayerTurnChanged != null) {
        onPlayerTurnChanged!();
      }
    }
  }
  
  /// Set dice values
  void setDiceValues(List<int> values) {
    diceValues = List.from(values);
    
    // Notify that dice values changed
    if (onDiceValuesChanged != null) {
      onDiceValuesChanged!();
    }
  }
  
  /// Reset dice values
  void resetDice() {
    diceValues = List.filled(5, 0);
    rollCount = 0;
    
    // Notify that dice values changed
    if (onDiceValuesChanged != null) {
      onDiceValuesChanged!();
    }
  }
  
  /// Select a cell for scoring
  bool selectCell(int cellIndex) {
    if (!isMyTurn) {
      return false;
    }
    
    final player = players[playerToMove];
    if (cellIndex < 0 || cellIndex >= player.cells.length) {
      return false;
    }
    
    final cell = player.cells[cellIndex];
    if (cell.fixed) {
      return false;
    }
    
    // Fix the cell with its current value
    cell.fix();
    
    // Calculate scores
    calculateScores();
    
    // Check if game is finished
    checkGameFinished();
    
    // Advance to next player
    advanceToNextPlayer();
    
    return true;
  }
  
  /// Check if the game is finished
  void checkGameFinished() {
    // Game is finished if all active players have completed their game
    bool allCompleted = true;
    
    for (var player in players) {
      if (player.isActive && !player.hasCompletedGame) {
        allCompleted = false;
        break;
      }
    }
    
    if (allCompleted) {
      gameFinished = true;
      
      // Determine winner
      int highestScore = -1;
      int winnerId = -1;
      
      for (int i = 0; i < players.length; i++) {
        if (players[i].isActive && players[i].totalScore > highestScore) {
          highestScore = players[i].totalScore;
          winnerId = i;
        }
      }
      
      // Set winner as player to move (for UI highlighting)
      if (winnerId >= 0) {
        playerToMove = winnerId;
      }
    }
  }
  
  /// Factory constructor from JSON
  factory Game.fromJson(Map<String, dynamic> json) {
    // Determine cell labels based on game type
    final gameType = json['gameType'] ?? 'Ordinary';
    final List<String> cellLabels = _getCellLabelsForGameType(gameType);
    
    // Create player list
    final int maxPlayers = json['nrPlayers'] ?? 1;
    final List<Player> players = [];
    
    // Create players from playerIds and userNames
    if (json['playerIds'] != null && json['userNames'] != null) {
      for (int i = 0; i < maxPlayers; i++) {
        if (i < json['playerIds'].length && json['playerIds'][i] != null && json['playerIds'][i] != '') {
          players.add(Player(
            id: json['playerIds'][i],
            username: json['userNames'][i] ?? 'Player ${i + 1}',
            isActive: true,
            cells: List.generate(
              cellLabels.length,
              (index) => BoardCell(
                index: index,
                label: cellLabels[index],
              ),
            ),
          ));
        } else {
          players.add(Player(
            id: '',
            username: 'Empty',
            isActive: false,
            cells: List.generate(
              cellLabels.length,
              (index) => BoardCell(
                index: index,
                label: cellLabels[index],
              ),
            ),
          ));
        }
      }
    }
    
    return Game(
      gameId: json['gameId'] ?? 0,
      gameType: gameType,
      maxPlayers: maxPlayers,
      players: players,
      gameStarted: json['gameStarted'] ?? false,
      gameFinished: json['gameFinished'] ?? false,
      playerToMove: json['playerToMove'] ?? 0,
      diceValues: json['diceValue'] != null 
          ? List<int>.from(json['diceValue'])
          : List.filled(5, 0),
      cellLabels: cellLabels,
      myPlayerIndex: 0, // Will be set later based on socket ID
    );
  }
  
  /// Convert game to JSON
  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'gameType': gameType,
      'nrPlayers': maxPlayers,
      'playerIds': players.map((p) => p.id).toList(),
      'userNames': players.map((p) => p.username).toList(),
      'connected': players.where((p) => p.isActive).length,
      'gameStarted': gameStarted,
      'gameFinished': gameFinished,
      'playerToMove': playerToMove,
      'diceValue': diceValues,
    };
  }
  
  /// Get cell labels based on game type
  static List<String> _getCellLabelsForGameType(String gameType) {
    switch (gameType) {
      case 'Mini':
        return [
          'Ones', 'Twos', 'Threes', 'Fours', 'Fives', 'Sixes',
          'Sum', 'Bonus',
          'Pair', 'Two Pairs', 'Three of a Kind',
          'Small Straight', 'Medium Straight', 'Large Straight',
          'Chance', 'Yatzy', 'Total'
        ];
      case 'Maxi':
      case 'MaxiR3':
      case 'MaxiE3':
      case 'MaxiRE3':
        return [
          'Ones', 'Twos', 'Threes', 'Fours', 'Fives', 'Sixes',
          'Sum', 'Bonus',
          'Pair', 'Two Pairs', 'Three Pairs',
          'Three of a Kind', 'Four of a Kind', 'Five of a Kind',
          'Small Straight', 'Large Straight', 'Full Straight',
          'House 3-2', 'House 3-3', 'House 2-4',
          'Chance', 'Maxi Yatzy', 'Total'
        ];
      case 'Ordinary':
      default:
        return [
          'Ones', 'Twos', 'Threes', 'Fours', 'Fives', 'Sixes',
          'Sum', 'Bonus',
          'Pair', 'Two Pairs', 'Three of a Kind', 'Four of a Kind',
          'House', 'Small Straight', 'Large Straight',
          'Chance', 'Yatzy', 'Total'
        ];
    }
  }
}



================================================
File: lib/models/player.dart
================================================
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



================================================
File: lib/router/router.dart
================================================
import 'package:auto_route/auto_route.dart';
import 'package:yatzy/router/router.gr.dart';

@AutoRouterConfig()
class AppRouter extends $AppRouter {
  @override
  RouteType get defaultRouteType => const RouteType.material();
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: SettingsView.page, initial: true, path: '/settingsView'),
    AutoRoute(page: ApplicationView.page, path: '/applicationView'),

  ];
}



================================================
File: lib/router/router.gr.dart
================================================
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i3;
import 'package:yatzy/views/application_view.dart' as _i1;
import 'package:yatzy/views/settings_view.dart' as _i2;

abstract class $AppRouter extends _i3.RootStackRouter {
  $AppRouter({super.navigatorKey});

  @override
  final Map<String, _i3.PageFactory> pagesMap = {
    ApplicationView.name: (routeData) {
      return _i3.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i1.ApplicationView(),
      );
    },
    SettingsView.name: (routeData) {
      return _i3.AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const _i2.SettingsView(),
      );
    },
  };
}

/// generated route for
/// [_i1.ApplicationView]
class ApplicationView extends _i3.PageRouteInfo<void> {
  const ApplicationView({List<_i3.PageRouteInfo>? children})
      : super(
          ApplicationView.name,
          initialChildren: children,
        );

  static const String name = 'ApplicationView';

  static const _i3.PageInfo<void> page = _i3.PageInfo<void>(name);
}

/// generated route for
/// [_i2.SettingsView]
class SettingsView extends _i3.PageRouteInfo<void> {
  const SettingsView({List<_i3.PageRouteInfo>? children})
      : super(
          SettingsView.name,
          initialChildren: children,
        );

  static const String name = 'SettingsView';

  static const _i3.PageInfo<void> page = _i3.PageInfo<void>(name);
}



================================================
File: lib/scroll/animations_scroll.dart
================================================
import 'package:flutter/animation.dart';

import 'languages_animations_scroll.dart';

class AnimationsScroll with LanguagesAnimationsScroll {
  final Function _getChosenLanguage;
  final String _standardLanguage;

  AnimationsScroll(
      {required Function getChosenLanguage, required String standardLanguage})
      : _getChosenLanguage = getChosenLanguage,
        _standardLanguage = standardLanguage;

  var keyXPos = 0.0, keyYPos = 0.0;

  late AnimationController animationController;

  late Animation<double> positionAnimation;

  Function getChosenLanguage() {
    return _getChosenLanguage;
  }

  String standardLanguage() {
    return _standardLanguage;
  }
}



================================================
File: lib/scroll/languages_animations_scroll.dart
================================================
mixin LanguagesAnimationsScroll {
  late Function _getChosenLanguage;
  late String _standardLanguage;

  final _scrollText = {
    "English":
        "Welcome to my programming system. It is aimed at speeding up device programming. Enabling"
            " multiinteractive application building. YATZY is my test subject. Complicated enough to build a"
            " cool system around."
  };

  String get scrollText_ => getText(_scrollText);

  void languagesSetup(Function getChosenLanguage, String standardLanguage) {
    _getChosenLanguage = getChosenLanguage;
    _standardLanguage = standardLanguage;
    _scrollText["Swedish"] =
        "Välkommen till mitt programmeringssystem. Det är utvecklat för att snabba upp programmering."
        " Möjliggöra multiinteraktiv applikations utveckling. YATZY är mitt test program. Tillräckligt komplicerat"
        " för att bygga ett coolt system kring.";
  }

  String getText(var textVariable) {
    var text = textVariable[_getChosenLanguage()];
    if (text != null) {
      return text;
    } else {
      return textVariable[_standardLanguage]!;
    }
  }
}



================================================
File: lib/scroll/widget_scroll.dart
================================================
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';

import '../startup.dart';
import 'languages_animations_scroll.dart';

class WidgetAnimationsScroll extends StatefulWidget {
  final double width;
  final double height;
  final double left;
  final double top;

  const WidgetAnimationsScroll({super.key, required this.width, required this.height, required this.left, required this.top});

  @override
  State<WidgetAnimationsScroll> createState() => _WidgetAnimationsScrollState();
}

class _WidgetAnimationsScrollState extends State<WidgetAnimationsScroll>
    with TickerProviderStateMixin, LanguagesAnimationsScroll {
  setupAnimation(TickerProvider ticket) {
    animationsScroll.animationController = AnimationController(
        vsync: ticket, duration: const Duration(seconds: 1));
    animationsScroll.positionAnimation =
        CurveTween(curve: Curves.linear).animate(animationsScroll.animationController);

    animationsScroll.animationController.addListener(() {

      animationsScroll.keyYPos = animationsScroll.positionAnimation.value * 30;
    });
  }

  @override
  void initState() {
    super.initState();
    languagesSetup(animationsScroll.getChosenLanguage(), animationsScroll.standardLanguage());
    setupAnimation(this);
    animationsScroll.animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    super.dispose();
    animationsScroll.animationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;
    double left = widget.left;
    double top = widget.top;

    try {
      return AnimatedBuilder(
          animation: animationsScroll.animationController,
          builder: (BuildContext context, Widget? widget) {
            List<String> text = scrollText_.split(".");
            List<AnimatedText> animatedTexts = [];
            for (String s in text) {
              animatedTexts.add(FadeAnimatedText(s));
            }

            return
              Positioned(
                  left: left,
                  top: top + animationsScroll.keyYPos,
                  child: SizedBox(
                      width: width, //sizeAnimation,
                      height: height, //scrollHeight,
                      child: FittedBox(
                        child: DefaultTextStyle(
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                            child: AnimatedTextKit(
                              animatedTexts: animatedTexts,
                              repeatForever: true,
                            )),
                      )));
          });
    } catch (e) {
      return Container();
    }
  }
}



================================================
File: lib/services/game_service.dart
================================================
import '../models/game.dart';
import '../models/board_cell.dart';
import 'socket_service.dart';

/// Service responsible for managing game logic and state
class GameService {
  /// Socket service for network communication
  final SocketService socketService;
  
  /// Current game instance
  Game? _game;
  
  /// Callbacks for game events
  final Function(Game)? onGameUpdated;
  final Function(String)? onError;
  
  /// Creates a new GameService instance
  GameService({
    required this.socketService,
    this.onGameUpdated,
    this.onError,
  }) {
    // Register for game updates from socket service
    socketService.onGameUpdate = _handleGameUpdate;
  }
  
  /// Get the current game
  Game? get game => _game;
  
  /// Handle game update from socket service
  void _handleGameUpdate(Game updatedGame) {
    _game = updatedGame;
    
    if (onGameUpdated != null) {
      onGameUpdated!(_game!);
    }
  }
  
  /// Create a new game
  void createGame({
    required String gameType,
    required int maxPlayers,
    required String username,
  }) {
    socketService.createGame(
      gameType: gameType,
      maxPlayers: maxPlayers,
      username: username,
    );
  }
  
  /// Join an existing game
  void joinGame({
    required int gameId,
    required String username,
  }) {
    socketService.joinGame(
      gameId: gameId,
      username: username,
    );
  }
  
  /// Roll dice
  void rollDice({List<bool>? keepDice}) {
    if (_game == null) {
      _reportError('No active game');
      return;
    }
    
    if (!_game!.isMyTurn) {
      _reportError('Not your turn');
      return;
    }
    
    if (!_game!.canRoll) {
      _reportError('Cannot roll again');
      return;
    }
    
    // If keepDice not provided, assume no dice are kept
    final diceToKeep = keepDice ?? List.filled(5, false);
    
    socketService.rollDice(
      gameId: _game!.gameId,
      keepDice: diceToKeep,
    );
  }
  
  /// Calculate possible scores for a cell
  int calculateScoreForCell(BoardCell cell, List<int> diceValues) {
    if (_game == null || diceValues.length != 5) {
      return 0;
    }
    
    // Sort dice values for easier calculations
    final sortedDice = List<int>.from(diceValues)..sort();
    
    // Get cell index and label
    final cellIndex = cell.index;
    final cellLabel = cell.label.toLowerCase();
    
    // Upper section (ones through sixes)
    if (cellIndex >= 0 && cellIndex <= 5) {
      final targetValue = cellIndex + 1;
      return sortedDice.where((value) => value == targetValue).fold(0, (sum, value) => sum + value);
    }
    
    // Lower section
    switch (cellLabel) {
      case 'pair':
        return _calculatePairScore(sortedDice);
      
      case 'two pairs':
        return _calculateTwoPairsScore(sortedDice);
        
      case 'three of a kind':
        return _calculateThreeOfAKindScore(sortedDice);
        
      case 'four of a kind':
        return _calculateFourOfAKindScore(sortedDice);
        
      case 'house':
      case 'full house':
        return _calculateFullHouseScore(sortedDice);
        
      case 'small straight':
        return _calculateSmallStraightScore(sortedDice);
        
      case 'large straight':
        return _calculateLargeStraightScore(sortedDice);
        
      case 'chance':
        return sortedDice.fold(0, (sum, value) => sum + value);
        
      case 'yatzy':
      case 'maxi yatzy':
        return _calculateYatzyScore(sortedDice);
        
      default:
        return 0;
    }
  }
  
  /// Select a cell for scoring
  void selectCell(int cellIndex) {
    if (_game == null) {
      _reportError('No active game');
      return;
    }
    
    if (!_game!.isMyTurn) {
      _reportError('Not your turn');
      return;
    }
    
    // Check if the selected cell is valid
    final player = _game!.myPlayer;
    if (cellIndex < 0 || cellIndex >= player.cells.length) {
      _reportError('Invalid cell index');
      return;
    }
    
    final cell = player.cells[cellIndex];
    if (cell.fixed) {
      _reportError('Cell already fixed');
      return;
    }
    
    // Calculate possible score
    final diceValues = _game!.diceValues;
    final possibleScore = calculateScoreForCell(cell, diceValues);
    
    // Update cell value with possible score
    cell.value = possibleScore;
    
    // Send selection to server
    socketService.selectCell(
      gameId: _game!.gameId,
      cellIndex: cellIndex,
    );
  }
  
  /// Report an error
  void _reportError(String message) {
    if (onError != null) {
      onError!(message);
    }
  }
  
  // Score calculation helper methods
  
  /// Calculate score for pair
  int _calculatePairScore(List<int> sortedDice) {
    // Look for the highest pair
    for (int i = 4; i > 0; i--) {
      if (sortedDice[i] == sortedDice[i - 1]) {
        return sortedDice[i] * 2;
      }
    }
    return 0;
  }
  
  /// Calculate score for two pairs
  int _calculateTwoPairsScore(List<int> sortedDice) {
    int pairCount = 0;
    int score = 0;
    
    // Find pairs from highest to lowest
    for (int i = 4; i > 0; i--) {
      if (sortedDice[i] == sortedDice[i - 1]) {
        pairCount++;
        score += sortedDice[i] * 2;
        i--; // Skip the second die in the pair
      }
    }
    
    return pairCount >= 2 ? score : 0;
  }
  
  /// Calculate score for three of a kind
  int _calculateThreeOfAKindScore(List<int> sortedDice) {
    for (int i = 0; i <= 2; i++) {
      if (sortedDice[i] == sortedDice[i + 1] && sortedDice[i] == sortedDice[i + 2]) {
        return sortedDice[i] * 3;
      }
    }
    return 0;
  }
  
  /// Calculate score for four of a kind
  int _calculateFourOfAKindScore(List<int> sortedDice) {
    for (int i = 0; i <= 1; i++) {
      if (sortedDice[i] == sortedDice[i + 1] && 
          sortedDice[i] == sortedDice[i + 2] &&
          sortedDice[i] == sortedDice[i + 3]) {
        return sortedDice[i] * 4;
      }
    }
    return 0;
  }
  
  /// Calculate score for full house
  int _calculateFullHouseScore(List<int> sortedDice) {
    // Check if we have three of a kind + pair
    bool hasThreeOfAKind = false;
    bool hasPair = false;
    int threeOfAKindValue = 0;
    int pairValue = 0;
    
    // Check for three of a kind at the beginning
    if (sortedDice[0] == sortedDice[1] && sortedDice[1] == sortedDice[2]) {
      hasThreeOfAKind = true;
      threeOfAKindValue = sortedDice[0];
      
      // Check for pair at the end
      if (sortedDice[3] == sortedDice[4] && sortedDice[3] != threeOfAKindValue) {
        hasPair = true;
        pairValue = sortedDice[3];
      }
    } 
    // Check for three of a kind at the end
    else if (sortedDice[2] == sortedDice[3] && sortedDice[3] == sortedDice[4]) {
      hasThreeOfAKind = true;
      threeOfAKindValue = sortedDice[2];
      
      // Check for pair at the beginning
      if (sortedDice[0] == sortedDice[1] && sortedDice[0] != threeOfAKindValue) {
        hasPair = true;
        pairValue = sortedDice[0];
      }
    }
    
    return (hasThreeOfAKind && hasPair) ? (threeOfAKindValue * 3 + pairValue * 2) : 0;
  }
  
  /// Calculate score for small straight
  int _calculateSmallStraightScore(List<int> sortedDice) {
    // Small straight is 1-2-3-4-5
    if (sortedDice[0] == 1 && sortedDice[1] == 2 && 
        sortedDice[2] == 3 && sortedDice[3] == 4 && 
        sortedDice[4] == 5) {
      return 15; // Sum of 1+2+3+4+5
    }
    return 0;
  }
  
  /// Calculate score for large straight
  int _calculateLargeStraightScore(List<int> sortedDice) {
    // Large straight is 2-3-4-5-6
    if (sortedDice[0] == 2 && sortedDice[1] == 3 && 
        sortedDice[2] == 4 && sortedDice[3] == 5 && 
        sortedDice[4] == 6) {
      return 20; // Sum of 2+3+4+5+6
    }
    return 0;
  }
  
  /// Calculate score for Yatzy
  int _calculateYatzyScore(List<int> sortedDice) {
    // All five dice showing the same face
    if (sortedDice[0] == sortedDice[4]) {
      return 50; // Standard score for Yatzy
    }
    return 0;
  }
}



================================================
File: lib/services/http_service.dart
================================================
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Modern HTTP service to replace the HTTP methods in the legacy Net class
class HttpService {
  final String baseUrl;
  
  HttpService({required this.baseUrl}) {
    print('🔍 HttpService created with baseUrl: $baseUrl');
  }
  
  Future<http.Response> getDB(String route) async {
    print('🔍 HttpService.getDB: $route');
    return await http.get(Uri.parse(baseUrl + route), headers: <String, String>{
      "Content-Type": "application/json; charset=UTF-8",
    });
  }

  Future<http.Response> postDB(String route, Map<String, dynamic> json) async {
    print('🔍 HttpService.postDB: $route');
    return await http.post(Uri.parse(baseUrl + route),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: jsonEncode(json));
  }

  Future<http.Response> updateDB(String route, Map<String, dynamic> json) async {
    print('🔍 HttpService.updateDB: $route');
    return await http.post(Uri.parse(baseUrl + route),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: jsonEncode(json));
  }

  Future<http.Response> deleteDB(String route) async {
    print('🔍 HttpService.deleteDB: $route');
    return await http.delete(Uri.parse(baseUrl + route), headers: <String, String>{
      "Content-Type": "application/json; charset=UTF-8",
    });
  }

  Future<http.Response> deleteUser(String route, String email) async {
    print('🔍 HttpService.deleteUser: $route, email: $email');
    return await http.delete(Uri.parse("$baseUrl$route?email=$email"),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        });
  }

  Future<http.Response> login(String userName, String password) async {
    print('🔍 HttpService.login: username: $userName');
    return await http.post(Uri.parse("$baseUrl/Login"),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: jsonEncode(<String, String>{
          "email": userName,
          "password": password,
        }));
  }

  Future<http.Response> signup(String userName, String password) async {
    print('🔍 HttpService.signup: username: $userName');
    return await http.post(Uri.parse("$baseUrl/Signup"),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: jsonEncode(<String, String>{
          "email": userName,
          "password": password,
        }));
  }
}



================================================
File: lib/services/service_provider.dart
================================================
import 'package:flutter/material.dart';

import 'socket_service.dart';
import 'game_service.dart';

/// Provider for accessing application services
class ServiceProvider extends InheritedWidget {
  /// Socket service instance
  final SocketService socketService;
  
  /// Game service instance
  final GameService gameService;
  
  /// Constructor
  const ServiceProvider({
    super.key,
    required super.child,
    required this.socketService,
    required this.gameService,
  });
  
  /// Get the service provider from context
  static ServiceProvider of(BuildContext context) {
    final ServiceProvider? result = 
      context.dependOnInheritedWidgetOfExactType<ServiceProvider>();
    assert(result != null, 'No ServiceProvider found in context');
    return result!;
  }
  
  /// Initialize services and wrap the app with the provider
  static Widget initialize({required Widget child, required BuildContext context}) {
    // Create socket service
    final socketService = SocketService(context: context);
    
    // Create game service
    final gameService = GameService(
      socketService: socketService,
      onError: (message) {
        // Show error message (can be implemented later)
        print('Game error: $message');
      },
    );
    
    // Return provider with services
    return ServiceProvider(
      socketService: socketService,
      gameService: gameService,
      child: child,
    );
  }
  
  @override
  bool updateShouldNotify(ServiceProvider oldWidget) {
    return socketService != oldWidget.socketService || 
           gameService != oldWidget.gameService;
  }
}



================================================
File: lib/services/socket_service.dart
================================================
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/communication_application.dart';
import 'dart:convert';

import '../models/game.dart';
import '../states/cubit/state/state_cubit.dart';
import '../startup.dart';

/// Service responsible for managing Socket.IO connections with the game server
class SocketService {
  // Identity tracking for logging purposes
  static int _instanceCounter = 0;
  final int _instanceId;
  
  final BuildContext context;
  
  /// Socket.IO connection instance
  late io.Socket socket;
  
  /// ID assigned by the server
  String socketId = '';
  
  /// Whether the socket is connected
  bool isConnected = false;
  
  /// Flag to indicate if handlers have been set up for the current socket instance
  bool _handlersSetUp = false;
  
  /// Game instance
  Game? game;
  
  /// Connection in progress flag to prevent multiple connection attempts
  bool _connectingInProgress = false;
  
  /// Static tracking of global connection to prevent duplicate connections app-wide
  static bool _globalConnectionInProgress = false;
  
  /// Stack trace of connection initiation for debugging
  static String? _connectionInitiator;
  
  /// Callback when game updates are received
  Function(Game)? onGameUpdate;
  
  /// Callback when chat messages are received
  Function(Map<String, dynamic>)? onChatMessage;
  
  /// Creates a new SocketService instance
  SocketService({required this.context}) : _instanceId = ++_instanceCounter {
    print('🔍 SocketService instance #$_instanceId created: ${StackTrace.current}');
  }
  
  /// Initialize and connect to the Socket.IO server
  void connect() {
    final stackTrace = StackTrace.current.toString();
    print('🔍 SocketService #$_instanceId connect() called from:\n$stackTrace');
    
    // Global check - still useful to prevent rapid successive attempts
    if (_globalConnectionInProgress && _connectingInProgress) {
      print('🚫 [Socket #$_instanceId] Global connection already in progress, skipping additional attempt');
      print('   Original connection initiated from: $_connectionInitiator');
      return;
    }
    
    // Check if already connected - if yes, ensure handlers are set
    if (isConnected) {
      print('🚫 [Socket #$_instanceId] Already connected. Ensuring handlers are set...');
      if (!_handlersSetUp) {
         _setupEventHandlers(); // Set up handlers if somehow missed
      }
      return;
    }
    
    // Instance level check
    if (_connectingInProgress) {
      print('🚫 [Socket #$_instanceId] Connection already in progress for this instance, skipping.');
      return;
    }
    
    _connectingInProgress = true;
    _globalConnectionInProgress = true;
    _connectionInitiator = stackTrace;
    _handlersSetUp = false; // Reset handlers flag for new connection attempt
    
    print('🔌 [Socket #$_instanceId] Initiating connection to server: $localhost');
    
    try {
      // Initialize socket with proper options
      socket = io.io(
        localhost, 
        <String, dynamic>{
          'transports': ['websocket', 'polling'],
          'autoConnect': false, // Control connection manually
          'forceNew': true,     // Ensure a new connection instance
          'reconnectionAttempts': 3,
          'reconnectionDelay': 1000,
          'reconnectionDelayMax': 5000,
          'timeout': 20000,
          'extraHeaders': {'Content-Type': 'application/json'}
        }
      );
      
      // Clear existing handlers before setting new ones
      _clearEventHandlers(); 
      _setupEventHandlers();
      
      print('🔌 [Socket #$_instanceId] Socket initialized, now connecting...');
      socket.connect();
      
      // Use socket events to manage connection progress flags
      socket.onConnect((_) {
         print('✅ [Socket #$_instanceId] Connect event received.');
         _connectingInProgress = false;
         _globalConnectionInProgress = false; 
         // Handlers are already set up
      });

      socket.onConnectError((error) {
          print('❌ [Socket #$_instanceId] Connect Error event received: $error');
          _connectingInProgress = false;
          _globalConnectionInProgress = false;
          _handlersSetUp = false; // Reset on error
          // UI update happens in the handler
      });

    } catch (e) {
      print('❌ [Socket #$_instanceId] Error initializing socket connection: $e');
      _connectingInProgress = false;
      _globalConnectionInProgress = false;
    }
  }
  
  /// Remove all registered event listeners
  void _clearEventHandlers() {
    if (socket != null) {
       print('🧼 [Socket #$_instanceId] Clearing existing event handlers...');
       socket.off('connect');
       socket.off('disconnect');
       socket.off('connect_error');
       socket.off('welcome');
       socket.off('echo_response');
       socket.off('onClientMsg');
       socket.off('onServerMsg');
       socket.off('userId');
       socket.off('gameUpdate');
       socket.off('chatMessage');
       _handlersSetUp = false;
    } else {
       print('🧼 [Socket #$_instanceId] No socket instance to clear handlers from.');
    }
  }
  
  /// Set up Socket.IO event handlers
  void _setupEventHandlers() {
    if (_handlersSetUp) {
       print('🔄 [Socket #$_instanceId] Handlers already set up for this socket instance, skipping.');
       return;
    }
    if (socket == null) {
       print('❌ [Socket #$_instanceId] Cannot set up handlers: Socket is null.');
       return;
    }

    print('🔄 [Socket #$_instanceId] Setting up event handlers...');
    
    // Connection events
    socket.onConnect((_) {
      print('✅ [Socket #$_instanceId] Connected to server with socket ID: ${socket.id}');
      isConnected = true;
      socketId = socket.id ?? '';
      _connectingInProgress = false; // Ensure flags are reset on successful connect
      _globalConnectionInProgress = false;
      _sendEcho();
      _requestId();
      _updateState();
    });
    
    socket.onDisconnect((_) {
      print('❌ [Socket #$_instanceId] Disconnected from server');
      isConnected = false;
      _handlersSetUp = false; // Reset handlers flag on disconnect
      _updateState();
    });
    
    socket.onConnectError((error) {
      print('❌ [Socket #$_instanceId] Connection error: $error');
      isConnected = false;
      _handlersSetUp = false; // Reset handlers flag on error
      _updateState();
    });
    
    // Welcome event to confirm connection
    socket.on('welcome', (data) {
      print('📩 [Socket #$_instanceId] Received welcome message: $data');
      if (data is Map && data['id'] != null) {
        socketId = data['id'];
        print('🆔 [Socket #$_instanceId] Server assigned ID: $socketId');
      }
      _updateState();
    });
    
    // Echo response for testing
    socket.on('echo_response', (data) {
      print('📩 [Socket #$_instanceId] Received echo response: $data');
    });
    
    // Game-related events
    socket.on('onClientMsg', _handleClientMessage);
    socket.on('onServerMsg', _handleServerMessage);
    
    // Additional events
    socket.on('userId', _handleUserId);
    socket.on('gameUpdate', _handleGameUpdate);
    socket.on('chatMessage', _handleChatMessage);

    _handlersSetUp = true; // Mark handlers as set up
    print('✅ [Socket #$_instanceId] Event handlers set up.');
  }
  
  /// Send an echo message to test the connection
  void _sendEcho() {
    final msg = {
      'message': 'Connection test',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('📤 [Socket #$_instanceId] Sending echo test: ${jsonEncode(msg)}');
    socket.emit('echo', msg);
  }
  
  /// Request user ID from server
  void _requestId() {
    Map<String, dynamic> msg = {
      'action': 'getId',
      'id': '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('📤 [Socket #$_instanceId] Requesting ID from server');
    socket.emit('sendToServer', msg);
  }

  
  /// Handle user ID received from server
  void _handleUserId(dynamic data) {
    print('📩 [Socket #$_instanceId] Received user ID: $data');
    
    if (data is Map && data['id'] != null) {
      socketId = data['id'];
      
      _updateState();
    }
  }
  
  /// Handle client messages
  void _handleClientMessage(dynamic data) {
    print('📩 [Socket #$_instanceId] Received client message: $data');

    try {
      app.callbackOnClientMsg(data);
    } catch (e) {
      print('❌ [Socket #$_instanceId] Error processing ClientMessage: $e');
    }
    
    _updateState();
  }
  
  /// Handle server messages
  void _handleServerMessage(dynamic data) {
    print('📩 [Socket #$_instanceId] Received server message: $data');

    try {
      app.callbackOnServerMsg(data);
    } catch (e) {
      print('❌ [Socket #$_instanceId] Error processing ServerMessage: $e');
    }
    
    _updateState();
  }
  
  /// Handle game update event
  void _handleGameUpdate(dynamic data) {
    print('📩 [Socket #$_instanceId] Game update received');
    
    if (data is Map<String, dynamic>) {
      _processGameUpdate(data);
    }
    
    _updateState();
  }
  
  /// Process game update data
  void _processGameUpdate(Map<String, dynamic> gameData) {
    // Create game instance from data
    game = Game.fromJson(gameData);
    
    // Find player index based on my socket ID
    if (game != null) {
      // Update my player index
      for (int i = 0; i < game!.players.length; i++) {
        if (game!.players[i].id == socketId) {
          game!.myPlayerIndex = i;
          break;
        }
      }
      
      // Notify listeners
      if (onGameUpdate != null) {
        onGameUpdate!(game!);
      }
    }
  }
  
  /// Handle chat message event
  void _handleChatMessage(dynamic data) {
    print('📩 [Socket #$_instanceId] Chat message received: $data');
    
    if (onChatMessage != null && data is Map<String, dynamic>) {
      onChatMessage!(data);
    }
  }
  
  /// Create a new game
  void createGame({
    required String gameType,
    required int maxPlayers,
    required String username,
  }) {
    if (!isConnected) {
      print('❌ [Socket #$_instanceId] Cannot create game: Not connected to server');
      return;
    }
    
    Map<String, dynamic> msg = {
      'action': 'createGame',
      'gameType': gameType,
      'nrPlayers': maxPlayers,
      'userName': username,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('📤 [Socket #$_instanceId] Creating game: $msg');
    socket.emit('sendToServer', msg);
  }
  
  /// Join an existing game
  void joinGame({
    required int gameId,
    required String username,
  }) {
    if (!isConnected) {
      print('❌ [Socket #$_instanceId] Cannot join game: Not connected to server');
      return;
    }
    
    Map<String, dynamic> msg = {
      'action': 'joinGame',
      'gameId': gameId,
      'userName': username,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('📤 [Socket #$_instanceId] Joining game: $msg');
    socket.emit('sendToServer', msg);
  }
  
  /// Roll dice
  void rollDice({
    required int gameId,
    required List<bool> keepDice,
  }) {
    if (!isConnected || game == null) {
      print('❌ [Socket #$_instanceId] Cannot roll dice: Not connected or no active game');
      return;
    }
    
    Map<String, dynamic> msg = {
      'action': 'rollDice',
      'gameId': gameId,
      'keepDice': keepDice,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('📤 [Socket #$_instanceId] Rolling dice: $msg');
    socket.emit('sendToServer', msg);
  }
  
  /// Select a cell for scoring
  void selectCell({
    required int gameId,
    required int cellIndex,
  }) {
    if (!isConnected || game == null) {
      print('❌ [Socket #$_instanceId] Cannot select cell: Not connected or no active game');
      return;
    }
    
    Map<String, dynamic> msg = {
      'action': 'selectCell',
      'gameId': gameId,
      'cellIndex': cellIndex,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('📤 [Socket #$_instanceId] Selecting cell: $msg');
    socket.emit('sendToServer', msg);
  }
  
  /// Send a chat message
  void sendChatMessage({
    required int gameId,
    required String message,
  }) {
    if (!isConnected) {
      print('❌ [Socket #$_instanceId] Cannot send chat message: Not connected to server');
      return;
    }
    
    Map<String, dynamic> msg = {
      'action': 'chatMessage',
      'gameId': gameId,
      'message': message,
      'sender': userName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    print('📤 [Socket #$_instanceId] Sending chat message: $msg');
    socket.emit('sendToServer', msg);
  }
  
  /// Send a message to all clients in the room
  void sendToClients(Map<String, dynamic> data) {
    if (!isConnected) {
      print('❌ [Socket #$_instanceId] Cannot send to clients: Not connected');
      return;
    }
    
    print('📤 [Socket #$_instanceId] Sending to clients: $data');
    
    // Add timestamp if not present
    if (!data.containsKey('timestamp')) {
      data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    }
    
    // For dice-related events, ensure proper handling
    if (data['action'] == 'sendDices') {
      print('🎲 [Socket #$_instanceId] Sending dice values: ${data['diceValue']}');
    }
    
    // Emit the event through Socket.IO
    socket.emit('sendToClients', data);
  }
  
  /// Send a message to the server
  void sendToServer(Map<String, dynamic> data) {
    if (!isConnected) {
      print('❌ [Socket #$_instanceId] Cannot send to server: Not connected');
      return;
    }
    
    // Add timestamp
    data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    
    print('📤 [Socket #$_instanceId] Sending to server: ${jsonEncode(data)}');
    socket.emit('sendToServer', data);
  }
  
  /// Disconnect from the server
  void disconnect() {
    print('🔌 [Socket #$_instanceId] Disconnecting socket...');
    _clearEventHandlers(); // Remove listeners before disconnecting
    if (socket != null) {
      socket.disconnect();
    }
    isConnected = false;
    _handlersSetUp = false;
    _connectingInProgress = false;
    _globalConnectionInProgress = false; // Allow new connections
    _updateState();
  }
  
  /// Update the UI state
  void _updateState() {
    try {
      context.read<SetStateCubit>().setState();
    } catch (e) {
      print('❌ [Socket #$_instanceId] Error updating state: $e');
    }
  }
}



================================================
File: lib/states/bloc/language/language_bloc.dart
================================================
import 'package:injectable/injectable.dart';

import '../../../shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'language_event.dart';

@injectable
class LanguageBloc extends Bloc<LanguageEvent, String> {
  LanguageBloc() : super(SharedPrefProvider.fetchPrefString(key)) {
    on<LanguageChanged>(_languageChanged);
  }

  static const String key = 'LanguageBloc';

  Future<void> _languageChanged(
      LanguageChanged event, Emitter<String> emit) async {
    SharedPrefProvider.setPrefString(key, event.language);
    emit(event.language);
  }
}



================================================
File: lib/states/bloc/language/language_event.dart
================================================


/// Event being processed by [CounterBloc].
abstract class LanguageEvent {}

/// Notifies bloc to increment state.
class LanguageChanged extends LanguageEvent {
  final String language;

  LanguageChanged({required this.language});
}



================================================
File: lib/states/cubit/state/state_cubit.dart
================================================
import 'package:flutter_bloc/flutter_bloc.dart';

class SetStateCubit extends Cubit<int> {
  SetStateCubit() : super(0);

  Future<void> setState() async {
    emit(state + 1);
  }
}



================================================
File: lib/top_score/languages_top_score.dart
================================================
mixin LanguagesTopScore {
  late Function _getChosenLanguage;
  late String _standardLanguage;

  final _topScores = {"English": "Top Scores"};

  String get topScores_ => getText(_topScores);

  void languagesSetup(Function getChosenLanguage, String standardLanguage) {
    _getChosenLanguage = getChosenLanguage;
    _standardLanguage = standardLanguage;

    _topScores["Swedish"] = "Topplista";
  }

  String getText(var textVariable) {
    var text = textVariable[_getChosenLanguage()];
    if (text != null) {
      return text;
    } else {
      return textVariable[_standardLanguage]!;
    }
  }
}



================================================
File: lib/top_score/top_score.dart
================================================
import 'dart:convert';

import 'package:flutter/animation.dart';
import '../states/cubit/state/state_cubit.dart';
import '../services/http_service.dart';
import 'languages_top_score.dart';
import '../startup.dart';

class TopScore with LanguagesTopScore {
  final Function _getChosenLanguage;
  final String _standardLanguage;
  late AnimationController animationController;
  late Animation<double> loopAnimation;
  
  // Track which game types we've already loaded to prevent duplicate requests
  final Map<String, bool> _loadedGameTypes = {};

  TopScore(
      {required Function getChosenLanguage,
      required String standardLanguage})
      : _getChosenLanguage = getChosenLanguage,
        _standardLanguage = standardLanguage;

  List<dynamic> topScores = [];

  /// Updates the internal topScores list with data received (e.g., from WebSocket)
  /// and triggers a UI update.
  void updateScoresFromData(List<Map<String, dynamic>> newScores, SetStateCubit cubit) {
    print('📊 [TopScore] Updating scores directly from provided data (${newScores.length} entries)');
    topScores = newScores; // Update the internal list
    // No need to mark as loaded, as this comes from a push update
    try {
      cubit.setState(); // Trigger UI update
    } catch (e) {
      print('⚠️ [TopScore] Error calling setState via Cubit during updateScoresFromData: $e');
    }
  }

  Function getChosenLanguage() {
    return _getChosenLanguage;
  }

  String standardLanguage() {
    return _standardLanguage;
  }

  Future<void> loadTopScoreFromServer(String gameType, SetStateCubit cubit) async {
    print('📊 [TopScore] Loading top scores for game type: $gameType');
    try {
      var httpService = HttpService(baseUrl: localhost);
      var serverResponse = await httpService.getDB("/GetTopScores?count=20&type=$gameType");
      
      if (serverResponse.statusCode == 200) {
        final loadedScores = jsonDecode(serverResponse.body);
        topScores = loadedScores;
        print('✅ [TopScore] Loaded ${loadedScores.length} scores for $gameType');
        cubit.setState(); // Trigger UI update
      } else {
        print('⚠️ [TopScore] Failed to load scores (Status ${serverResponse.statusCode})');
      }
    } catch (e) {
      print('❌ [TopScore] Error loading scores: $e');
    }
  }

  Future updateTopScore(String name, int score, String gameType) async {
    print('📊 [TopScore] Updating top score: $name/$score/$gameType');
    try {
      var httpService= HttpService(baseUrl: localhost);
      var serverResponse = await httpService.postDB("/UpdateTopScore",
          {"name": name, "score": score, "type": gameType, "count": 20});
      if (serverResponse.statusCode == 200) {
        topScores = jsonDecode(serverResponse.body);
        _loadedGameTypes[gameType] = true;
        print('📊 [TopScore] Top scores updated successfully');
      }
    } catch (e) {
      print('❌ [TopScore] Error updating top scores: $e');
    }
  }
}



================================================
File: lib/top_score/widget_top_scores.dart
================================================
import 'package:flutter/material.dart';
import '../startup.dart';
import 'languages_top_score.dart';

class WidgetTopScore extends StatefulWidget {
  final double width;
  final double height;

  const WidgetTopScore({super.key, required this.width, required this.height});

  @override
  State<WidgetTopScore> createState() => _WidgetTopScoreState();
}

class _WidgetTopScoreState extends State<WidgetTopScore>
    with TickerProviderStateMixin, LanguagesTopScore {
  setupAnimation(TickerProvider ticket) {
    topScore.animationController = AnimationController(
        vsync: ticket, duration: const Duration(milliseconds: 3000));
    topScore.loopAnimation = CurveTween(curve: Curves.easeInSine)
        .animate(topScore.animationController);

    topScore.animationController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        topScore.animationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        topScore.animationController.forward();
      }
    });
    topScore.animationController.forward();
  }

  @override
  void initState() {
    super.initState();
    languagesSetup(topScore.getChosenLanguage(), topScore.standardLanguage());
    setupAnimation(this);
  }

  @override
  void dispose() {
    super.dispose();
    topScore.animationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;

    var containerWidth = width;
    var heightCaption = height / 6.4;
    var containerHeight = height - heightCaption;
    var left = 0.0, top = 0.0;

    List<Widget> listings = <Widget>[];

    listings.add(Positioned(
        left: left,
        top: top,
        child: Container(
            padding:
                const EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 0),
            width: containerWidth,
            height: heightCaption,
            //child: Center(
            child: FittedBox(
                fit: BoxFit.contain,
                child: Text(topScores_,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.blue[800],
                      shadows: const [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.red,
                          offset: Offset(5.0, 5.0),
                        ),
                      ],
                    ))))));
    try {
      listings.add(AnimatedBuilder(
          animation: topScore.animationController,
          builder: (BuildContext context, Widget? widget) {
            return Positioned(
              left: left,
              top: top + heightCaption,
              child: Container(
                width: containerWidth,
                height: containerHeight,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(10.0),
                    gradient: LinearGradient(
                      colors: [
                        Colors.greenAccent.withValues(alpha: 0.5),
                        Colors.lightBlueAccent.withValues(alpha: 0.5)
                      ],
                      stops: [0.0, topScore.loopAnimation.value],
                    )),
                child: Scrollbar(
                  //showTrackOnHover: true,
                  child: ListView.builder(
                      primary: true,
                      padding: const EdgeInsets.all(4),
                      itemCount: topScore.topScores.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                          height: heightCaption,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blueAccent),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                    padding: const EdgeInsets.only(
                                        left: 0, right: 5, top: 0, bottom: 0),
                                    width: containerWidth * 0.15,
                                    child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: Text("  ${index + 1}.",
                                            style: const TextStyle(
                                                fontStyle: FontStyle.italic,
                                                color: Colors.black54)))),
                                Container(
                                    padding: const EdgeInsets.only(
                                        left: 5, right: 5, top: 0, bottom: 0),
                                    width: containerWidth * 0.5,
                                    child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: Text(
                                            topScore.topScores[index]["name"],
                                            style: const TextStyle(
                                                //fontWeight: FontWeight.bold,
                                                color: Colors.black)))),
                                Container(
                                    padding: const EdgeInsets.only(
                                        left: 5, right: 0, top: 0, bottom: 0),
                                    width: containerWidth * 0.25,
                                    child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: Text(
                                            "${topScore.topScores[index]["score"]}  ",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.redAccent))))
                              ]),
                        );
                      }),
                ),
              ),
            );
          }));
    } catch (e) {
      // error
    }
    return SizedBox(
        width: width, height: height, child: Stack(children: listings));
  }
}



================================================
File: lib/tutorial/tutorial.dart
================================================
import 'package:flutter/material.dart';

class Tutorial {
  var keyXPos = List.filled(3, 0.0);
  var keyYPos = List.filled(3, 0.0);
  var animationSide = ["R", "R", "R"];

  //var arrowImage = "arrowRight";

  late AnimationController animationController1,
      animationController2,
      animationController3;
  late Animation<double> positionAnimation1,
      positionAnimation2,
      positionAnimation3;

  setup(TickerProvider ticket) {
    animationController1 = AnimationController(
        vsync: ticket, duration: const Duration(seconds: 1));
    positionAnimation1 =
        CurveTween(curve: Curves.linear).animate(animationController1);

    animationController2 = AnimationController(
        vsync: ticket, duration: const Duration(seconds: 1));
    positionAnimation2 =
        CurveTween(curve: Curves.linear).animate(animationController2);

    animationController3 = AnimationController(
        vsync: ticket, duration: const Duration(seconds: 1));
    positionAnimation3 =
        CurveTween(curve: Curves.linear).animate(animationController3);

    animationController1.addListener(() {
      switch (animationSide[0]) {
        case "R":
          keyXPos[0] = positionAnimation1.value;
          break;
        case "B":
          keyYPos[0] = positionAnimation1.value;
          break;
      }
    });

    animationController2.addListener(() {
      switch (animationSide[1]) {
        case "R":
          keyXPos[1] = positionAnimation2.value;
          break;
        case "L":
          keyXPos[1] = -positionAnimation2.value;
          break;
        case "B":
          keyYPos[1] = positionAnimation2.value;
          break;
      }
    });

    animationController3.addListener(() {
      switch (animationSide[2]) {
        case "R":
          keyXPos[2] = positionAnimation3.value;
          break;
        case "L":
          keyXPos[2] = -positionAnimation3.value;
          break;
        case "B":
          keyYPos[2] = positionAnimation3.value;
          break;
      }
    });
  }

  Widget widgetArrow(
      GlobalKey key,
      double w,
      double h,
      AnimationController animationController,
      String text,
      int controller,
      String side,
      double scale) {
    return AnimatedBuilder(
        animation: animationController,
        builder: (BuildContext context, Widget? widget) {
          animationSide[controller] = side;
          final RenderBox renderBox =
              key.currentContext?.findRenderObject() as RenderBox;
          final Size size = renderBox.size;

          Offset position =
              renderBox.localToGlobal(Offset.zero); //this is global position
          // Default from right side
          var left = position.dx + size.width;
          var top = position.dy +
              size.height / 2 -
              size.height * scale -
              size.height * scale / 2;
          var arrowImage = "arrowRight";
          switch (side) {
            case "L":
              arrowImage = "arrowLeft";
              left = position.dx - size.width * 1.5;
              break;
            case "T":
              arrowImage = "arrowTop";
              break;
            case "B":
              arrowImage = "arrowBottom";
              left = position.dx + size.width / 2 - size.width * scale / 2;
              top = position.dy + size.height;
              break;
          }

          Widget tmp;
          if (side == "R" || side == "L") {
            tmp = Column(children: [
              SizedBox(
                  height: size.height * scale,
                  child: FittedBox(
                      fit: BoxFit.fitHeight,
                      child: Text(text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black.withValues(alpha: 0.8),
                            shadows: const [
                              Shadow(
                                blurRadius: 10.0,
                                color: Colors.blueAccent,
                                offset: Offset(5.0, 5.0),
                              ),
                            ],
                          )))),
              SizedBox(
                  width: size.height * scale * 3,
                  height: size.height * scale,
                  child: Image.asset(
                    "assets/images/$arrowImage.png",
                    fit: BoxFit.fill,
                  ))
            ]);
          } else {
            tmp = Row(children: [
              SizedBox(
                  width: size.width * scale,
                  height: size.height * scale * 3,
                  child: Image.asset(
                    "assets/images/$arrowImage.png",
                    fit: BoxFit.fill,
                  )),
              SizedBox(
                  height: size.height * scale,
                  child: FittedBox(
                      fit: BoxFit.fitHeight,
                      child: Text(text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black.withValues(alpha: 0.8),
                            shadows: const [
                              Shadow(
                                blurRadius: 10.0,
                                color: Colors.blueAccent,
                                offset: Offset(5.0, 5.0),
                              ),
                            ],
                          )))),
            ]);
          }

          if (side == "T" || side == "B") {
            top = top + keyYPos[controller] * (w > h ? w * 0.02 : h * 0.02);
          } else {
            left = left + keyXPos[controller] * (w > h ? w * 0.02 : h * 0.02);
          }

          return Positioned(left: left, top: top, child: tmp);
        });
  }
}



================================================
File: lib/utils/yatzy_mapping_client.dart
================================================
// lib/utils/yatzy_mapping_client.dart

// Based on the frontend `application/application.dart` structure
// IMPORTANT: Keep this EXACTLY in sync with the server-side mapping and Application's appText[0]
const Map<String, List<String>> _gameTypeMappingsClient = {
  'Ordinary': [
    'Ones', 'Twos', 'Threes', 'Fours', 'Fives', 'Sixes',
    'Sum', 'Bonus', // Note: Bonus label might include value on UI, use base label for mapping
    'Pair', 'Two Pairs', 'Three of Kind', 'Four of Kind',
    'House', 'Small Straight', 'Large Straight',
    'Chance', 'Yatzy', 'Total'
  ],
  'Mini': [
    'Ones', 'Twos', 'Threes', 'Fours', 'Fives', 'Sixes',
    'Sum', 'Bonus',
    'Pair', 'Two Pairs', 'Three of Kind',
    'Small Straight', 'Middle Straight', 'Large Straight',
    'Chance', 'Yatzy', 'Total'
  ],
  'Maxi': [ // Includes MaxiR3, MaxiE3, MaxiRE3
    'Ones', 'Twos', 'Threes', 'Fours', 'Fives', 'Sixes',
    'Sum', 'Bonus',
    'Pair', 'Two Pairs', 'Three Pairs',
    'Three of Kind', 'Four of Kind', 'Five of Kind',
    'Small Straight', 'Large Straight', 'Full Straight',
    'House 3-2', 'House 3-3', 'House 2-4',
    'Chance', 'Maxi Yatzy', 'Total'
  ]
};

String _getBaseGameTypeClient(String gameType) {
  if (gameType.startsWith('Maxi')) return 'Maxi';
  if (gameType == 'Mini') return 'Mini';
  return 'Ordinary'; // Default
}

// Gets the base label (without score/bonus info) for mapping
String _getBaseLabel(String fullLabel) {
    if (fullLabel.contains('Bonus')) return 'Bonus';
    // Add other normalizations if needed
    return fullLabel;
}


String? getSelectionLabel(String gameType, int index) {
  final baseType = _getBaseGameTypeClient(gameType);
  final labels = _gameTypeMappingsClient[baseType];
  if (labels != null && index >= 0 && index < labels.length) {
    return labels[index];
  }
  print('Client Mapping Error: Invalid index $index for game type $gameType');
  return null;
}

int getSelectionIndex(String gameType, String label) {
  final baseType = _getBaseGameTypeClient(gameType);
  final labels = _gameTypeMappingsClient[baseType];
   final baseLabel = _getBaseLabel(label); // Normalize label if needed
  if (labels != null) {
    final index = labels.indexOf(baseLabel);
    if (index == -1) {
        print('Client Mapping Error: Label "$label" (base: "$baseLabel") not found for game type $gameType');
    }
    return index; // Returns -1 if not found
  }
  print('Client Mapping Error: Game type $gameType not found in mappings.');
  return -1;
}


================================================
File: lib/views/application_view.dart
================================================
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/widget_application_scaffold.dart';

import '../router/router.gr.dart';
import '../injection.dart';
import '../router/router.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';

@RoutePage()
class ApplicationView extends StatefulWidget {
  const ApplicationView({super.key});

  @override
  State<ApplicationView> createState() => _ApplicationViewState();
}

class _ApplicationViewState extends State<ApplicationView>
    with TickerProviderStateMixin {
  void myState() {
    if (mounted) {
       setState(() {});
    }
  }

  void _showGameFinishedDialog() {
    final router = getIt<AppRouter>();
    if (!mounted) return;
    
    String winnerMsg = "Game Over!";

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Game Finished'),
          content: Text(winnerMsg),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                
                app.gameFinished = false;
                
                router.pushAndPopUntil(const SettingsView(), predicate: (_) => false);
                
                app.gameId = -1;
                app.myPlayerId = -1;
              },
            ),
          ],
        );
      },
    );
  }

  postFrameCallback(BuildContext context) async {
    if (mounted) {
      myState();
    }
    mainPageLoaded = true;

    if (app.gameFinished && !app.isSpectating && mounted) {
       _showGameFinishedDialog();
    }
  }

  @override
  void initState() {
    super.initState();
    tutorial.setup(this);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => postFrameCallback(context));

    app.animation.setupAnimation(
        this, app.nrPlayers, app.maxNrPlayers, app.maxTotalFields);

  }

  @override
  void dispose() {
    if (animationsScroll.animationController.isAnimating) {
        animationsScroll.animationController.dispose(); 
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (app.gameFinished && !app.isSpectating && mounted) {
        _showGameFinishedDialog();
      }
    });

    return BlocBuilder<SetStateCubit, int>(builder: (context, state) {
      return app.widgetScaffold(context, myState);
    });
  }
}



================================================
File: lib/views/settings_view.dart
================================================
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/widget_application_settings.dart';

import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';

@RoutePage()
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewHomeState();
}

class _SettingsViewHomeState extends State<SettingsView>
    with TickerProviderStateMixin {
  void myState() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    app.tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SetStateCubit, int>(builder: (context, state) {
      return app.widgetScaffoldSettings(context, myState);
    });
  }
}



================================================
File: lib/widgets/spectator_game_board.dart
================================================
import 'package:flutter/material.dart';

class SpectatorGameBoard extends StatefulWidget {
  final Map<String, dynamic> gameData;

  const SpectatorGameBoard({Key? key, required this.gameData}) : super(key: key);

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
    // Print entire game data for debugging
    print('🎲 Building spectator board. Game Finished: ${widget.gameData['gameFinished']}');

    // Extract player name(s)
    List<String> playerNames = [];
    if (widget.gameData['userNames'] != null) {
      playerNames = List<String>.from(widget.gameData['userNames']);
    }
    if (playerNames.isEmpty && widget.gameData['players'] != null) {
       // Attempt to get names from player objects if userNames is missing
       try {
          playerNames = List<String>.from(widget.gameData['players'].map((p) => p?['username'] ?? 'P?'));
       } catch (_) { playerNames = ['P1']; } // Fallback
    }
    if (playerNames.isEmpty) playerNames = ['Player 1'];

    // Get current roll number and dice values
    int currentRoll = widget.gameData['rollCount'] ?? 0;
    List<int> diceValues = [];
    if (widget.gameData['diceValues'] != null) {
      try { // Add try-catch for safety
         diceValues = List<int>.from(widget.gameData['diceValues']);
      } catch (e) { print("Error parsing diceValues: $e"); }
    }

    // Check if game is finished
    bool isFinished = widget.gameData['gameFinished'] ?? false;

    return Stack( // Use Stack for overlay
      children: [
        Column(
      children: [
        // Game status header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.blue.shade200, width: 1.0),
            ),
          ),
          child: Column(
            children: [
              Text(
                "Spectating Game #${widget.gameData['gameId'] ?? '?'}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                "Roll #$currentRoll",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Dice row (if dice are available)
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
                  if (value < 1 || value > 6) return const SizedBox.shrink();

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
                            color: Colors.black.withOpacity(0.2),
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

        // Game board content
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
                  child: buildScoreTable(playerNames),
                ),
              ),
            ),
              ),
            ),
            // **** Game Finished Overlay ****
            if (isFinished)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'GAME OVER',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "You can stop spectating from the settings screen.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // **** End Game Finished Overlay ****
          ],
        ),
      ],
    );
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

  Widget buildScoreTable(List<String> playerNames) {
    // Define score categories with their labels and index
    final List<ScoreCategory> categories = [
      ScoreCategory('Ones', 0, false),
      ScoreCategory('Twos', 1, false),
      ScoreCategory('Threes', 2, false),
      ScoreCategory('Fours', 3, false),
      ScoreCategory('Fives', 4, false),
      ScoreCategory('Sixes', 5, false),
      ScoreCategory('Sum', 6, true),
      ScoreCategory('Bonus ( 50 )', 7, true),
      ScoreCategory('Par', 8, false),
      ScoreCategory('Två Par', 9, false),
      ScoreCategory('Triss', 10, false),
      ScoreCategory('Fyrtal', 11, false),
      ScoreCategory('Kåk', 12, false),
      ScoreCategory('Liten Stege', 13, false),
      ScoreCategory('Stor Stege', 14, false),
      ScoreCategory('Chans', 15, false),
      ScoreCategory('Yatzy', 16, false),
      ScoreCategory('Total Summa', 17, true),
    ];

    // Get cell data based on the specific server format
    Map<int, int> cellValues = {};

    if (widget.gameData['players'] != null &&
        widget.gameData['players'].isNotEmpty) {

      final player = widget.gameData['players'][0];
      if (player != null && player['cells'] != null) {
        for (var cell in player['cells']) {
          if (cell != null && cell['index'] != null && cell['value'] != null) {
            int index = cell['index'];
            int value = cell['value'];

            // Only show positive values (server uses -1 for empty cells)
            if (value != -1 || index == 7) { // Exception for Bonus which can be negative
              cellValues[index] = value;
            }
          }
        }
      }
    }

    print('🎲 Cell values: $cellValues');

    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {
          0: FixedColumnWidth(150),
          1: FixedColumnWidth(80),
        },
        border: TableBorder.all(
          color: Colors.blue.shade200,
          width: 1,
        ),
        children: [
          // Header row with column labels
          TableRow(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
            ),
            children: [
              const TableCell(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Category',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ...playerNames.map((name) => TableCell(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              )).toList(),
            ],
          ),

          // Score rows
          ...categories.map((category) {
            // Get the score value for this category
            int? score = cellValues[category.index];

            return TableRow(
              decoration: BoxDecoration(
                color: category.isHighlighted ? Colors.blue.shade200 : Colors.transparent,
              ),
              children: [
                // Category name cell
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      category.displayName,
                      style: TextStyle(
                        fontWeight: category.isHighlighted ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),

                // Score cell
                TableCell(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    alignment: Alignment.center,
                    color: score != null && !category.isHighlighted ?
                    Colors.green.shade100.withOpacity(0.7) : null,
                    child: Text(
                      score != null ? score.toString() : '',
                      style: TextStyle(
                        fontWeight: category.isHighlighted ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}

// Helper class to organize score categories
class ScoreCategory {
  final String displayName;
  final int index;
  final bool isHighlighted;

  ScoreCategory(this.displayName, this.index, this.isHighlighted);
}

