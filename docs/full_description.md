Okay, let's break down the technical description of this Yatzy game project, focusing on the Flutter frontend and Express backend components based on the provided codebase structure and files.

**Project Overview**

This project implements a multiplayer Yatzy game with a client-server architecture. The frontend is built using Flutter, providing the user interface and handling user interactions. The backend is built with Node.js and Express, using TypeScript, responsible for managing game logic, real-time communication via Socket.IO, and data persistence using MongoDB. The project also includes an optional Unity integration for rendering 3D dice within the Flutter application.

**Architecture**

*   **Client-Server Model:** The application follows a standard client-server architecture.
*   **Frontend (Client):** Flutter application (`lib/`) running on user devices (likely mobile or web).
*   **Backend (Server):** Node.js/Express server (`backend/`) hosting the game logic and API.
*   **Communication:**
    *   **REST API:** Used for initial actions like authentication (signup/login), fetching/updating top scores, and potentially fetching game logs or spectator data via HTTP (`backend/src/routes/`, `lib/services/http_service.dart`).
    *   **WebSockets (Socket.IO):** Used for real-time, bidirectional communication during gameplay. This includes joining/creating games, synchronizing game state (player turns, dice rolls, scores), and chat messages (`backend/src/server.ts`, `backend/src/controllers/`, `backend/src/services/`, `lib/services/socket_service.dart`).
*   **Database:** MongoDB (`backend/src/db.ts`) is used for persistence, primarily storing game logs (`GameLogService`) and top scores (`TopScoreService`). Authentication data might also be stored here (`logInRoute`, `signUpRoute`).
*   **Optional 3D Dice:** Unity project (`unity/`) integrated into Flutter (`lib/dices/`) for visual dice rolling.

**Backend (Express in `backend/`)**

1.  **Core Technologies & Setup:**
    *   **Framework:** Express.js (`backend/src/server.ts`).
    *   **Language:** TypeScript.
    *   **Real-time:** Socket.IO (`socket.io`) integrated with the Express HTTP server (`backend/src/server.ts`).
    *   **Database:** MongoDB, accessed via the `mongodb` driver (`backend/src/db.ts`).
    *   **Entry Point:** `backend/src/server.ts` initializes the Express app, sets up CORS, integrates Socket.IO, defines middleware, connects to the database (`initializeDbConnection`), initializes services and controllers, registers API routes, and starts the server.

2.  **API Routes (`backend/src/routes/`):**
    *   Provides RESTful endpoints for:
        *   Authentication (`logInRoute.ts`, `signUpRoute.ts`): Basic email/password login/signup using bcrypt for hashing and JWT for sessions.
        *   Top Scores (`getTopScores.ts`, `updateTopScore.ts`): Fetching and potentially updating high scores stored in the database. Validates game type ('Ordinary', 'Maxi').
        *   Game Logging (`logRoute.ts`, `getLogRoute.ts`): Routes likely related to user activity or potentially older game logging, using JWT for authorization.
        *   Spectating (`spectateGameRoute.ts`): An HTTP GET endpoint (`/api/spectate/:gameId`) to retrieve combined data from the active game state (if available in memory via `GameService`) and the persisted game log (`GameLogService`).

3.  **Real-time Communication (Socket.IO):**
    *   **Setup:** Socket.IO server is initialized in `server.ts` with CORS settings allowing connections from any origin (`*`). It listens for connections on the same port as the HTTP server.
    *   **Events:** Communication follows a pattern using specific event names:
        *   `connect`/`disconnect`: Standard Socket.IO connection/disconnection events. Disconnects trigger `GameService.handlePlayerDisconnect`.
        *   `sendToServer`: Generic event name used by clients to send various requests/actions to the server (e.g., `requestGame`, `requestJoinGame`, `getId`, `spectateGame`, `chatMessage`). The server routes these based on the `action` field in the data payload.
        *   `sendToClients`: Generic event name used by clients to broadcast data (intended for other clients in the same game, e.g., `sendDices`, `sendSelection`, `chatMessage`). The server often relays or processes these.
        *   `onServerMsg`: Generic event name used by the *server* to send messages/updates *to* specific clients or broadcast (e.g., `getId` response, `onGameStart`, `onGameUpdate`, `onGameFinished`, `onRequestGames`, `onTopScoresUpdate`).
        *   `onClientMsg`: Generic event name used by the *server* to forward messages *from one client to others* (e.g., forwarding `sendDices`, `sendSelection`, `chatMessage`).
    *   **Namespaces/Rooms:** While not explicitly shown in detail, the logic implies rooms are used, likely based on `gameId` (e.g., `game_${gameId}` mentioned in `ChatController`), to target messages to specific games.

4.  **Controllers (`backend/src/controllers/`):**
    *   Act as intermediaries between raw socket events and the service layer.
    *   `ChatController.ts`: Handles `chatMessage` actions received via `sendToServer` or `sendToClients`. It uses `GameService` to find players in the target game and relays messages via `onClientMsg`, ensuring the sender doesn't receive their own message back.
    *   `GameController.ts`: Handles game-related actions like `requestGame`, `requestJoinGame`, `removeGame`, `spectateGame`. It also handles client-initiated state changes like `sendDices` (client reporting its roll) and `sendSelection` (client reporting its score choice). It validates turns and delegates processing to `GameService`. Crucially handles `spectateGame` by fetching game state (from memory and logs) and sending it back to the spectator.
    *   `PlayerController.ts`: Primarily handles initial connection logic like `getId`, registering the player socket. Other player actions (joining, playing) are mostly handled by `GameController`.

5.  **Services (`backend/src/services/`):**
    *   Encapsulate the core business logic.
    *   `GameService.ts`: **Central service.** Manages the lifecycle and state of active games (`games` map). Handles game creation, finding available games, adding/removing players (`handlePlayerDisconnect`), turn advancement, processing dice rolls (`processDiceRoll`) and selections (`processSelection`), managing spectators (`addSpectator`, `removeSpectator`), checking game finish conditions (`handleGameFinished`), and broadcasting game state updates (`notifyGameUpdate`, `broadcastGameList`) to players and spectators via Socket.IO. It interacts with `GameLogService` to record game events and `TopScoreService` to update scores upon game completion.
    *   `GameLogService.ts`: Responsible for interacting with the MongoDB `game_moves` collection in the `yatzy-game-log-db` database. Logs game start, individual moves (roll, select, disconnect, spectate), and game end states including final scores. Provides `getGameLog` to retrieve historical data, used by `GameController` for spectating.
    *   `TopScoreService.ts`: Manages top scores for different game types ('Ordinary', 'Maxi'). Interacts with MongoDB collections (`ordinary`, `maxi`) in the `top-scores` database. Fetches scores (`getTopScores`), updates scores (`updateTopScore`), and broadcasts updates to connected clients via Socket.IO (`broadcastTopScores` using `onTopScoresUpdate`).

6.  **Models (`backend/src/models/`):**
    *   Define the data structures used in the application.
    *   `Game.ts`: Represents the state of a single game instance (ID, type, players, max players, status flags, current player, dice values, roll count, turn number). Includes methods for adding/removing players, checking game status, applying selections (`applySelection`), advancing turns (`advanceToNextActivePlayer`), and serialization (`toJSON`, `fromJSON`). Uses `GameConfig`.
    *   `Player.ts`: Represents a player's state (ID, username, active status, score card (`cells`), overall score, upper sum, bonus status). Contains the core Yatzy scoring logic (`_calculate...` methods, `calculateScores`, `calculatePotentialScores`) based on `GameConfig`. Includes serialization. `PlayerFactory` assists in creation.
    *   `BoardCell.ts`: Represents a single cell on the player's scorecard (index, label, value, fixed status, non-score flag). Includes serialization.
    *   `Dice.ts`: Basic model for dice rolling (seems less used as clients report rolls).

7.  **Utilities (`backend/src/utils/`):**
    *   `gameConfig.ts`: **Crucial.** Defines constants and structures for different Yatzy game types (Ordinary, Maxi), including cell labels, bonus rules, dice count, and max rolls. Used extensively in `Player` scoring and `Game` setup.
    *   `yatzyMapping.ts`: Provides functions (`getSelectionLabel`, `getSelectionIndex`) to map between the numerical index of a scorecard cell and its string label (e.g., 0 -> "Ones", 12 -> "House"). Essential for interpreting client selections sent by label.
    *   `index.ts`: Contains general utility functions (randomInt, delay, etc.).

**Frontend (Flutter in `lib/`)**

1.  **Core Technologies & Setup:**
    *   **Framework:** Flutter (`main.dart`).
    *   **Language:** Dart.
    *   **State Management:** Flutter BLoC/Cubit (`states/`). `LanguageBloc` manages language changes. `SetStateCubit` appears to be a simple mechanism to trigger global UI rebuilds.
    *   **Dependency Injection:** `get_it` and `injectable` (`injection.dart`, `injection.config.dart`). Primarily used for registering the router and BLoC/Cubit instances.
    *   **Routing:** `auto_route` (`router/`). Manages navigation between the `SettingsView` and `ApplicationView`.
    *   **Entry Point:** `main.dart` initializes Flutter bindings, loads shared preferences, sets up dependency injection, initializes BLoC providers, and runs the main `AppWidget`.
    *   **Core Widget:** `core/app_widget.dart` sets up the `MaterialApp.router`, initializes global application objects (`app`, `dices`, `chat`, `topScore`), and crucially initializes the `ServiceProvider` which in turn creates and connects the `SocketService`.

2.  **Networking (`lib/services/`):**
    *   `SocketService.dart`: **Central networking component.** Wraps the `socket_io_client` package. Manages the WebSocket connection lifecycle (`connect`, `disconnect`). Listens for server events (`onConnect`, `onServerMsg`, `onClientMsg`, etc.) and forwards the received data to callbacks within the `Application` class (`app.callbackOnServerMsg`, `app.callbackOnClientMsg`). Provides methods (`sendToServer`, `sendToClients`) for sending data to the backend. Stores the `socketId` assigned by the server.
    *   `HttpService.dart`: Handles standard HTTP requests to the backend's REST API using the `http` package. Used for fetching/updating top scores and potentially authentication.
    *   `ServiceProvider.dart`: An `InheritedWidget` used to make the initialized `SocketService` and `GameService` (client-side) accessible throughout the widget tree via `ServiceProvider.of(context)`.
    *   `GameService.dart` (Client-side): Contains client-side game logic, particularly score calculation helpers (`calculateScoreForCell`, `_calculate...Score`). Its role seems less central compared to the backend `GameService`, with much state and logic residing directly in the `Application` class.

3.  **State Management & Application Logic (`lib/application/`):**
    *   `application.dart`: **Core state holder.** This class (`app` global instance) holds a significant amount of the application's state directly, including game details (`gameId`, `gameType`, `nrPlayers`, `playerToMove`, `myPlayerId`), board state (`cellValue`, `fixedCell`, `appText`, `appColors`), player lists (`userNames`, `playerActive`), dice state (via `gameDices` reference), and references to other components like `SocketService`.
    *   `communication_application.dart`: Extension on `Application`. Contains the critical `callbackOnServerMsg` and `callbackOnClientMsg` methods. These methods parse incoming data from `SocketService`, update the state held within the `Application` instance (`gameData`, `cellValue`, `fixedCell`, `playerToMove`, etc.), handle game start/update/finish logic, update chat, and trigger UI rebuilds (`context.read<SetStateCubit>().setState()`). Handles the crucial logic for synchronizing the client's state with the server's messages. Processes spectator updates separately.
    *   `application_functions_internal.dart`: Extension on `Application`. Contains functions triggered by UI interactions, like `cellClick`, which formats and sends the `sendSelection` message via `SocketService`.
    *   `languages_application.dart`: Mixin for handling multi-language support within the Application UI.
    *   `animations_application.dart`: Manages animations, particularly for the game board cells.

4.  **UI Structure (`lib/views/`, `lib/widgets/`):**
    *   `views/`: Contains the main screen/page widgets.
        *   `ApplicationView.dart`: The main game screen, displaying the game board, dice, status, chat, and top scores. Uses `WidgetApplicationScaffold` for layout.
        *   `SettingsView.dart`: Screen for configuring game settings (type, players, username), viewing available games, joining games, spectating, and potentially general app settings (language, Unity options). Uses `WidgetApplicationSettings`.
    *   `widgets/`: Contains reusable UI components.
        *   `SpectatorGameBoard.dart`: A dedicated widget to display the game board state specifically for spectators, taking `gameData` as input. Renders the scores based on the received data. Includes dice display and a "Game Over" overlay.
    *   `application/widget_*.dart`: Contain the `build` logic for the main scaffold (`widgetScaffold`) and settings screen (`widgetScaffoldSettings`), defining the layout and positioning of different components (game board, dice, chat, top scores, status).

5.  **Game Components:**
    *   **Dice (`lib/dices/`):**
        *   `dices.dart`: Manages dice state (`diceValue`, `holdDices`, `nrRolls`). Implements client-side dice rolling logic (`rollDices`). **Important:** The client rolls its own dice and sends the result (`sendDices` action via `callbackUpdateDiceValues` -> `SocketService.sendToClients`).
        *   `widget_dices.dart`: Renders the dice UI. It can either show 2D dice representations (using `buildDiceFace`) or delegate to the `UnityWidget` if `unityDices` is enabled. Includes the roll button.
        *   `unity_communication.dart`: Handles sending messages *to* the Unity instance (reset, start, update dice, change settings) via `unityWidgetController.postMessage`. Also defines `onUnityMessage` to handle messages *from* Unity (e.g., dice roll results).
        *   `unity_message.dart`: Defines the structure for JSON messages exchanged with Unity.
    *   **Chat (`lib/chat/`):**
        *   `chat.dart`: Holds chat state (`messages`) and handles message submission logic (`onSubmitted`).
        *   `widget_chat.dart`: Renders the chat interface, including the message list and input field. Sends messages via `app.chatCallbackOnSubmitted` -> `SocketService.sendToClients`. Receives messages via `app.updateChat` (triggered by `callbackOnClientMsg`).
    *   **Top Scores (`lib/top_score/`):**
        *   `top_score.dart`: Manages the top score list (`topScores`). Fetches data initially (`loadTopScoreFromServer`) using `HttpService`. Updates data (`updateScoresFromData`) when pushed from the server via `onTopScoresUpdate` event.
        *   `widget_top_scores.dart`: Displays the fetched top scores in a scrolling list.

6.  **Models (`lib/models/`):**
    *   Client-side representations of game entities, likely mirroring the backend models but potentially simpler or with added UI-related fields.
    *   `BoardCell.dart`, `Game.dart`, `Player.dart`: Define the structure for cells, the overall game state, and player data used within the Flutter application. The `Game` model includes calculation logic and state checks relevant to the client.

7.  **Utilities:**
    *   `utils/yatzy_mapping_client.dart`: Client-side mapping between cell index and label. Must be kept in sync with the backend version. Used when sending selections (`cellClick` -> `sendSelection`).
    *   `shared_preferences.dart`: Utility class for saving/loading simple settings locally (username, game preferences, language).
    *   `startup.dart`: Contains global variables, constants (like `localhost` URL), and initializations for core objects (`app`, `dices`, `chat`, `topScore`).

**Real-time Communication Flow (Simplified)**

1.  **Connection:** `AppWidget` -> `ServiceProvider` -> `SocketService.connect()`. Server responds (`onConnect`, `welcome`, `userId`). Client requests ID (`getId`).
2.  **Game List:** Server sends `onRequestGames` via `onServerMsg`. Client (`callbackOnServerMsg`) updates `app.games` and UI (`SettingsView`).
3.  **Create/Join Game:** Client (`SettingsView`) sends `requestGame` or `requestJoinGame` via `SocketService.sendToServer`.
4.  **Game Start:** Server (`GameService`) determines game start, sends `onGameStart` via `onServerMsg`. Client (`callbackOnServerMsg`) sets up the game (`app.setup()`) and navigates to `ApplicationView`.
5.  **Dice Roll (Client):** Player clicks roll button (`WidgetDices`) -> `dices.rollDices()` calculates new `diceValue` -> `app.callbackUpdateDiceValues()` -> `SocketService.sendToClients({ action: 'sendDices', ... })`.
6.  **Dice Roll (Server):** Server (`GameController.handleSendDices`) receives `sendDices`, logs it via `GameLogService`, processes it via `GameService.processDiceRoll` (updates game state, increments roll count, calculates potential scores), and notifies *all* clients/spectators via `onServerMsg` (`onGameUpdate`).
7.  **Dice Roll (Other Clients):** Receive `onGameUpdate` via `onServerMsg`. `callbackOnServerMsg` updates `app.gameData`, including dice values and roll count. UI updates.
8.  **Score Selection (Client):** Player clicks cell (`WidgetSetupGameBoard`) -> `app.cellClick()` gets label, calculates score -> `SocketService.sendToClients({ action: 'sendSelection', selectionLabel: ..., score: ... })`.
9.  **Score Selection (Server):** Server (`GameController.handleSendSelection`) receives `sendSelection`, validates turn, logs via `GameLogService`, processes via `GameService.processSelection` (applies score, calculates derived scores, checks game end, advances turn, resets dice), and notifies *all* clients/spectators via `onServerMsg` (`onGameUpdate` or `onGameFinished`).
10. **Score Selection (Other Clients):** Receive `onGameUpdate`/`onGameFinished`. `callbackOnServerMsg` updates `app.gameData` (fixed cell, scores, player turn, dice reset). UI updates.
11. **Chat:** Client sends message (`WidgetChat`) -> `app.chatCallbackOnSubmitted` -> `SocketService.sendToClients({ action: 'chatMessage', ... })`. Server (`ChatController`) receives, finds recipients, forwards via `onClientMsg` to other players. Clients (`callbackOnClientMsg`) receive and display (`app.updateChat`).
12. **Spectating:** Client sends `spectateGame` -> Server (`GameController`) fetches state/log, sends `onGameStart` with `spectator: true` -> Client (`callbackOnServerMsg`) displays `SpectatorGameBoard`. Subsequent updates are sent via `onGameUpdate`.

**Key Features Implementation**

*   **Game Logic:** Core scoring logic resides in `backend/src/models/Player.ts` and is driven by `GameService`. Client-side has duplicate calculation logic in `lib/services/game_service.dart` (potentially for preview) and maybe within `Application` updates. Turn management is handled by `GameService`.
*   **Real-time Sync:** Primarily handled by `GameService` broadcasting state via `onServerMsg` (`onGameUpdate`, `onGameStart`, `onGameFinished`) after processing client actions (`sendDices`, `sendSelection`). `SocketService` on the client receives these and updates the `Application` state.
*   **Spectating:** Initiated via `spectateGame` action (socket) or HTTP route. `GameController` gathers data (memory + log) and sends initial state. `GameService` adds spectator ID and forwards subsequent `onGameUpdate` messages. `SpectatorGameBoard.dart` renders this data.
*   **Chat:** Client sends `chatMessage` via `sendToClients`. `ChatController` relays via `onClientMsg`. Client listens and updates UI.
*   **Top Scores:** Fetched/updated via REST API (`HttpService`). Real-time updates pushed by `TopScoreService` via Socket.IO (`onTopScoresUpdate`).
*   **Game Logging:** `GameLogService` persists moves/events triggered by `GameService` actions to MongoDB.

**Unity Integration**

*   **Purpose:** Renders 3D dice for a more visually appealing experience (optional via `unityDices` flag).
*   **Communication (Flutter -> Unity):** `lib/dices/unity_communication.dart` sends JSON messages via `unityWidgetController.postMessage` to the `GameManager` object in Unity to trigger actions (reset, start roll, update settings).
*   **Communication (Unity -> Flutter):** Unity (`GameManagerScript.cs`, likely using `UnityMessageManager.cs` from the plugin) sends JSON messages back (e.g., dice roll results) which are handled by `dices.onUnityMessage`.

This detailed description covers the primary technical aspects of the frontend and backend based on the provided file structure and code snippets.

```
RELATIONSHIP_TYPES:
  CALLS: Function/method invocation.
  INSTANTIATES: Class instantiation.
  IMPORTS: Module/file import.
  EXTENDS: Class inheritance.
  IMPLEMENTS: Interface implementation (TS/Dart).
  USES_MIXIN: Dart mixin usage.
  REFERENCES: Accessing a field/property of another class/object or global variable.
  DEPENDS_ON: Dependency, often injected via constructor or framework.
  SENDS_SOCKET_EVENT: Emitting a Socket.IO event.
  HANDLES_SOCKET_EVENT: Listening for a Socket.IO event.
  HTTP_GET/POST/PUT/DELETE/PATCH: Makes an HTTP request.
  HANDLES_ROUTE: Express route handler.
  UNITY_POSTMESSAGE: Flutter sending message to Unity.
  UNITY_FLUTTERMESSAGE_HANDLER: Unity method handling messages from Flutter.
  UNITY_SENDMESSAGE_FLUTTER: Unity sending message to Flutter.
  FLUTTER_UNITYMESSAGE_HANDLER: Flutter method handling messages from Unity.
  DB_CONNECT: Establishes DB connection.
  DB_READ: Reads from database.
  DB_WRITE: Writes to database.
  UI_BUILD: Dart widget build method (implies UI dependency).
  USES_BLOC/CUBIT: Interacts with a Bloc/Cubit for state management.
  USES_DI: Uses GetIt for dependency injection.
  EXPORTS: Exporting a function/class/variable.
```

**FILE:** `backend/src/controllers/ChatController.ts`
  - **CLASS:** `ChatController`
    - IMPORTS: `Server`, `Socket` from `socket.io` (Module)
    - IMPORTS: `GameService` from `../services/GameService.ts`
    - DEPENDS_ON: `Server` (constructor, field `io`)
    - DEPENDS_ON: `GameService` (constructor, field `gameService`)
    - **METHOD:** `constructor(io: Server, gameService?: GameService)`
      - REFERENCES: `this.io`
      - REFERENCES: `this.gameService`
    - **METHOD:** `registerSocketHandlers(socket: Socket)`
      - CALLS: `console.log`
      - HANDLES_SOCKET_EVENT: `socket.on('sendToClients', callback)`
        - CALLS: `this.handleChatMessage(socket, data)` (conditionally)
      - HANDLES_SOCKET_EVENT: `socket.on('sendToServer', callback)`
        - CALLS: `this.handleServerChatMessage(socket, data)` (conditionally)
    - **METHOD:** `handleChatMessage(socket: Socket, data: any)`
      - REFERENCES: `this.io`
      - REFERENCES: `this.gameService`
      - CALLS: `console.log`
      - CALLS: `this.gameService.getGame`
      - CALLS: `game.players.forEach`
      - SENDS_SOCKET_EVENT: `this.io.to(...).emit('onClientMsg', ...)`
      - CALLS: `Array.isArray`
    - **METHOD:** `handleServerChatMessage(socket: Socket, data: any)`
      - REFERENCES: `this.io`
      - REFERENCES: `this.gameService`
      - CALLS: `console.log`
      - CALLS: `this.gameService.getGame`
      - CALLS: `game.players.forEach`
      - SENDS_SOCKET_EVENT: `this.io.to(...).emit('onClientMsg', ...)`
      - SENDS_SOCKET_EVENT: `socket.to(...).emit('onClientMsg', ...)`
    - **METHOD:** `broadcastToPlayersInSameGame(socket: Socket, data: any)`
      - REFERENCES: `this.io`
      - REFERENCES: `this.gameService`
      - CALLS: `console.log`
      - CALLS: `this.gameService.getAllGames`
      - CALLS: `game.players.some`
      - CALLS: `game.players.forEach`
      - SENDS_SOCKET_EVENT: `this.io.to(...).emit('onClientMsg', ...)`

**FILE:** `backend/src/controllers/GameController.ts`
  - **CLASS:** `GameController`
    - IMPORTS: `Socket` from `socket.io` (Module)
    - IMPORTS: `GameService` from `../services/GameService.ts`
    - IMPORTS: `PlayerFactory`, `Player` from `../models/Player.ts`
    - IMPORTS: `GameLogService`, `GameMove` from `../services/GameLogService.ts`
    - IMPORTS: `getSelectionLabel` from `../utils/yatzyMapping.ts`
    - IMPORTS: `Game` from `../models/Game.ts`
    - DEPENDS_ON: `GameService` (constructor, field `gameService`)
    - DEPENDS_ON: `GameLogService` (constructor, field `gameLogService`)
    - **METHOD:** `constructor(gameService: GameService, gameLogService: GameLogService)`
      - REFERENCES: `this.gameService`
      - REFERENCES: `this.gameLogService`
    - **METHOD:** `registerSocketHandlers(socket: Socket)`
      - HANDLES_SOCKET_EVENT: `socket.on('sendToServer', callback)`
        - CALLS: `this.handleRequestGame` (conditionally)
        - CALLS: `this.handleRequestJoinGame` (conditionally)
        - CALLS: `this.handleRemoveGame` (conditionally)
        - CALLS: `this.handleSpectateGame` (conditionally)
      - HANDLES_SOCKET_EVENT: `socket.on('sendToClients', callback)`
        - CALLS: `this.handleSendDices` (conditionally)
        - CALLS: `this.handleSendSelection` (conditionally)
    - **METHOD:** `handleRequestGame(socket: Socket, data: any)`
      - CALLS: `console.warn`
      - SENDS_SOCKET_EVENT: `socket.emit('onServerMsg', ...)`
      - CALLS: `PlayerFactory.createPlayer`
      - CALLS: `this.gameService.createOrJoinGame`
    - **METHOD:** `handleRequestJoinGame(socket: Socket, data: any)`
      - CALLS: `this.gameService.getGame`
      - SENDS_SOCKET_EVENT: `socket.emit('onServerMsg', ...)`
      - CALLS: `game.isGameFull`
      - CALLS: `PlayerFactory.createPlayer`
      - CALLS: `this.gameService.joinGame`
      - CALLS: `this.gameService.notifyGameUpdate`
      - CALLS: `joinedGame.toJSON`
      - SENDS_SOCKET_EVENT: `this.gameService['io'].to(...).emit('onServerMsg', ...)`
      - CALLS: `this.gameService.broadcastGameList`
    - **METHOD:** `handleRemoveGame(socket: Socket, data: any)`
      - CALLS: `console.log`
      - CALLS: `this.gameService.getGame`
      - CALLS: `this.gameService.removeGame`
      - CALLS: `this.gameService.broadcastGameList`
    - **METHOD:** `handleSendDices(socket: Socket, data: any)`
      - CALLS: `console.error`
      - CALLS: `this.gameService.getGame`
      - CALLS: `game.findPlayerIndex`
      - CALLS: `console.log`
      - CALLS: `this.gameService.processDiceRoll`
    - **METHOD:** `handleSendSelection(socket: Socket, data: any)`
      - CALLS: `console.error`
      - CALLS: `console.warn`
      - CALLS: `this.gameService.getGame`
      - CALLS: `game.findPlayerIndex`
      - CALLS: `console.log`
      - CALLS: `this.gameService.processSelection`
      - CALLS: `this.gameService.forwardSelectionToPlayers`
    - **METHOD:** `handleSpectateGame(socket: Socket, data: any)`
      - CALLS: `console.error`
      - CALLS: `console.log`
      - SENDS_SOCKET_EVENT: `socket.emit('onServerMsg', ...)`
      - CALLS: `this.gameService.getGame`
      - CALLS: `this.gameLogService.getGameLog`
      - CALLS: `gameLog.moves.filter`
      - CALLS: `gameLog.moves.forEach`
      - CALLS: `game.applySelection`
      - CALLS: `game.players.forEach`
      - CALLS: `player.calculateScores`
      - CALLS: `player.cells.find`
      - CALLS: `game.toJSON`
      - CALLS: `this.gameLogService.logSpectate`
      - CALLS: `this.gameService.addSpectator`

**FILE:** `backend/src/controllers/PlayerController.ts`
  - **CLASS:** `PlayerController`
    - IMPORTS: `Socket` from `socket.io` (Module)
    - IMPORTS: `GameService` from `../services/GameService.ts`
    - IMPORTS: `PlayerFactory` from `../models/Player.ts`
    - IMPORTS: `GameLogService` from `../services/GameLogService.ts`
    - DEPENDS_ON: `GameService` (constructor, field `gameService`)
    - DEPENDS_ON: `GameLogService` (constructor, field `gameLogService`)
    - FIELD: `playerRegistry: Map<string, boolean>`
    - **METHOD:** `constructor(gameService: GameService, gameLogService: GameLogService)`
      - REFERENCES: `this.gameService`
      - REFERENCES: `this.gameLogService`
    - **METHOD:** `registerSocketHandlers(socket: Socket)`
      - HANDLES_SOCKET_EVENT: `socket.on('sendToServer', callback)`
        - CALLS: `console.log`
        - CALLS: `console.error`
        - CALLS: `this.handleGetId` (conditionally)
    - **METHOD:** `handleGetId(socket: Socket)`
      - CALLS: `this.playerRegistry.has`
      - CALLS: `console.log`
      - SENDS_SOCKET_EVENT: `socket.emit('onServerMsg', ...)`
      - CALLS: `this.playerRegistry.set`
      - SENDS_SOCKET_EVENT: `socket.emit('userId', ...)`

**FILE:** `backend/src/db.ts`
  - IMPORTS: `MongoClient`, `Db` from `mongodb` (Module)
  - **FUNCTION:** `initializeDbConnection`
    - EXPORTS: Function `initializeDbConnection`
    - CALLS: `console.log`
    - DB_CONNECT: `MongoClient.connect`
    - CALLS: `client.db`
    - DB_WRITE: `testCollection.insertOne`
    - DB_READ: `movesCollection.countDocuments`
    - CALLS: `console.error`
  - **FUNCTION:** `getDbConnection(dbName: string)`
    - EXPORTS: Function `getDbConnection`
    - CALLS: `console.error`
    - CALLS: `client.db`
    - THROWS: `Error`

**FILE:** `backend/src/models/BoardCell.ts`
  - **CLASS:** `BoardCell`
    - EXPORTS: Class `BoardCell`
    - FIELD: `index: number`
    - FIELD: `label: string`
    - FIELD: `value: number`
    - FIELD: `fixed: boolean`
    - FIELD: `isNonScoreCell: boolean`
    - **METHOD:** `constructor(index: number, label: string, isNonScoreCell?: boolean)`
      - REFERENCES: `this.index`, `this.label`, `this.value`, `this.fixed`, `this.isNonScoreCell`
      - CALLS: `label.toLowerCase`
      - CALLS: `label.includes`
    - **METHOD:** `toJSON()`
      - RETURNS: Object literal
    - **STATIC METHOD:** `fromJson(data: any, defaultLabel?: string)`
      - INSTANTIATES: `BoardCell`
      - RETURNS: `BoardCell`

**FILE:** `backend/src/models/Dice.ts`
  - **CLASS:** `Dice`
    - EXPORTS: Class `Dice`
    - FIELD: `values: number[]`
    - FIELD: `diceCount: number`
    - **METHOD:** `constructor(diceCount?: number)`
      - CALLS: `this.reset`
    - **METHOD:** `roll()`
      - CALLS: `Math.floor`, `Math.random`
      - CALLS: `this.getValues`
    - **METHOD:** `rollSelected(keptDice: boolean[])`
      - CALLS: `Math.floor`, `Math.random`
      - CALLS: `this.getValues`
    - **METHOD:** `getValues()`
      - RETURNS: `number[]`
    - **METHOD:** `setValues(values: number[])`
      - REFERENCES: `this.values`
    - **METHOD:** `reset()`
      - REFERENCES: `this.values`

**FILE:** `backend/src/models/Game.ts`
  - **CLASS:** `Game`
    - EXPORTS: Class `Game`
    - IMPORTS: `Player`, `PlayerFactory` from `./Player.ts`
    - IMPORTS: `v4 as uuidv4` from `uuid` (Module)
    - IMPORTS: `getSelectionIndex` from `../utils/yatzyMapping.ts`
    - IMPORTS: `GameConfig`, `getBaseGameType` from `../utils/gameConfig.ts`
    - FIELD: `id: number`
    - FIELD: `gameType: string`
    - FIELD: `players: Player[]`
    - FIELD: `maxPlayers: number`
    - FIELD: `connectedPlayers: number`
    - FIELD: `gameStarted: boolean`
    - FIELD: `gameFinished: boolean`
    - FIELD: `playerToMove: number`
    - FIELD: `diceValues: number[]`
    - FIELD: `userNames: string[]`
    - FIELD: `gameId: number`
    - FIELD: `playerIds: string[]`
    - FIELD: `abortedPlayers: boolean[]`
    - FIELD: `rollCount: number`
    - FIELD: `turnNumber: number`
    - **METHOD:** `constructor(id: number, gameType: string, maxPlayers: number)`
      - REFERENCES: `GameConfig`, `getBaseGameType`
      - CALLS: `PlayerFactory.createEmptyPlayer`
    - **METHOD:** `addPlayer(player: Player, position?: number)`
      - CALLS: `this.findEmptySlot`
    - **METHOD:** `removePlayer(playerId: string)`
      - CALLS: `this.findPlayerIndex`
      - CALLS: `console.log`
      - CALLS: `this.advanceToNextActivePlayer`
      - CALLS: `this.players.filter`
    - **METHOD:** `markPlayerAborted(playerId: string)`
      - CALLS: `this.findPlayerIndex`
      - CALLS: `this.advanceToNextActivePlayer`
      - CALLS: `this.players.filter`
    - **METHOD:** `findPlayerIndex(playerId: string)`
      - CALLS: `this.players.findIndex`
    - **METHOD:** `findEmptySlot()`
      - CALLS: `this.players.findIndex`
    - **METHOD:** `isGameFull()`
    - **METHOD:** `getCurrentTurnNumber()`
    - **METHOD:** `incrementRollCount()`
    - **METHOD:** `advanceToNextActivePlayer()`
      - CALLS: `console.log`
      - CALLS: `this.players.filter`
    - **METHOD:** `applySelection(playerIndex: number, selectionLabel: string, score: number)`
      - CALLS: `getSelectionIndex`
      - REFERENCES: `this.players`
      - REFERENCES: `player.cells`
      - CALLS: `player.calculateScores`
      - CALLS: `console.log`, `console.warn`, `console.error`
    - **METHOD:** `isGameFinished()`
      - CALLS: `this.players.filter`
      - CALLS: `activePlayers.every`
      - CALLS: `p.hasCompletedGame`
    - **METHOD:** `setDiceValues(values: number[])`
      - REFERENCES: `GameConfig`, `getBaseGameType`
      - CALLS: `console.error`, `console.warn`
    - **METHOD:** `toJSON()`
      - CALLS: `this.players.map`
      - CALLS: `player.toJSON`
      - CALLS: `this.isGameFinished`
    - **STATIC METHOD:** `fromJSON(data: any)`
      - INSTANTIATES: `Game`
      - CALLS: `Player.fromJSON`
      - CALLS: `PlayerFactory.createEmptyPlayer`
      - CALLS: `PlayerFactory.createPlayer`
      - CALLS: `game.players.filter`

**FILE:** `backend/src/models/Player.ts`
  - **CLASS:** `Player`
    - EXPORTS: Class `Player`
    - IMPORTS: `BoardCell` from `./BoardCell.ts`
    - IMPORTS: `GameConfig`, `getBaseGameType` from `../utils/gameConfig.ts`
    - FIELD: `id: string`
    - FIELD: `username: string`
    - FIELD: `isActive: boolean`
    - FIELD: `cells: BoardCell[]`
    - FIELD: `score: number`
    - FIELD: `upperSum: number`
    - FIELD: `bonusAchieved: boolean`
    - FIELD: `gameType: string`
    - **METHOD:** `_countDice(diceValues: number[])`
    - **METHOD:** `_calculateUpperSection(diceValues: number[], faceValue: number)`
    - **METHOD:** `_calculatePairScore(diceValues: number[])`
      - CALLS: `this._countDice`
    - **METHOD:** `_calculateTwoPairsScore(diceValues: number[])`
      - CALLS: `this._countDice`
    - **METHOD:** `_calculateThreeOfKindScore(diceValues: number[])`
      - CALLS: `this._countDice`
    - **METHOD:** `_calculateFourOfKindScore(diceValues: number[])`
      - CALLS: `this._countDice`
    - **METHOD:** `_calculateFullHouseScore(diceValues: number[])`
      - CALLS: `this._countDice`
    - **METHOD:** `_calculateSmallStraightScore(diceValues: number[])`
      - CALLS: `Set`, `sort`, `includes`
    - **METHOD:** `_calculateLargeStraightScore(diceValues: number[])`
      - CALLS: `Set`, `sort`, `includes`
    - **METHOD:** `_calculateChanceScore(diceValues: number[])`
      - CALLS: `reduce`
    - **METHOD:** `_calculateYatzyScore(diceValues: number[])`
      - REFERENCES: `GameConfig`, `getBaseGameType`
      - CALLS: `this._countDice`
    - **METHOD:** `_calculateThreePairsScore(diceValues: number[])`
      - REFERENCES: `this.gameType`
      - CALLS: `this._countDice`
    - **METHOD:** `_calculateFiveOfKindScore(diceValues: number[])`
      - REFERENCES: `this.gameType`
      - CALLS: `this._countDice`
    - **METHOD:** `_calculateFullStraightScore(diceValues: number[])`
      - REFERENCES: `this.gameType`
      - CALLS: `Set`, `sort`
    - **METHOD:** `_calculateHouse32Score(diceValues: number[])`
      - CALLS: `this._calculateFullHouseScore`
    - **METHOD:** `_calculateHouse33Score(diceValues: number[])`
      - REFERENCES: `this.gameType`
      - CALLS: `this._countDice`
    - **METHOD:** `_calculateHouse24Score(diceValues: number[])`
      - REFERENCES: `this.gameType`
      - CALLS: `this._countDice`
    - **METHOD:** `_getScoreFunction(label: string)`
      - RETURNS: Function
    - **METHOD:** `constructor(...)`
      - REFERENCES: `GameConfig`, `getBaseGameType`
      - CALLS: `config.cellLabels.map`
      - INSTANTIATES: `BoardCell`
      - CALLS: `this.calculateScores`
    - **METHOD:** `calculatePotentialScores(diceValues: number[])`
      - CALLS: `this.clearPotentialScores`
      - CALLS: `this.cells.forEach`
      - CALLS: `this._getScoreFunction`
    - **METHOD:** `clearPotentialScores()`
      - CALLS: `console.log`
      - CALLS: `this.cells.forEach`
      - CALLS: `this.calculateScores`
    - **METHOD:** `calculateScores()`
      - REFERENCES: `GameConfig`, `getBaseGameType`
      - CALLS: `this.cells.findIndex`
      - CALLS: `this.cells.slice`
      - CALLS: `every`
    - **METHOD:** `hasCompletedGame()`
      - CALLS: `this.cells.every`
    - **METHOD:** `getScore()`
    - **METHOD:** `calculateDerivedScores()` (Similar logic to `calculateScores`)
      - REFERENCES: `GameConfig`, `getBaseGameType`
      - CALLS: `this.cells.findIndex`
      - CALLS: `this.cells.slice`
      - CALLS: `every`
    - **METHOD:** `toJSON()`
      - CALLS: `this.cells.map`
      - CALLS: `cell.toJSON`
    - **STATIC METHOD:** `fromJSON(data: any, gameType?: string)`
      - REFERENCES: `GameConfig`, `getBaseGameType`
      - CALLS: `data.cells.map`
      - CALLS: `BoardCell.fromJson`
      - INSTANTIATES: `Player`
  - **CLASS:** `PlayerFactory`
    - EXPORTS: Class `PlayerFactory`
    - **STATIC METHOD:** `createPlayer(id: string, username: string, gameType?: string)`
      - REFERENCES: `getBaseGameType`
      - CALLS: `console.warn`
      - INSTANTIATES: `Player`
    - **STATIC METHOD:** `createEmptyPlayer(gameType?: string)`
      - REFERENCES: `getBaseGameType`, `GameConfig`
      - CALLS: `console.warn`
      - CALLS: `config.cellLabels.map`
      - INSTANTIATES: `BoardCell`
      - INSTANTIATES: `Player`

**FILE:** `backend/src/routes/getLogRoute.ts`
  - IMPORTS: `jwt` from `jsonwebtoken` (Module)
  - IMPORTS: `getDbConnection` from `../db.ts`
  - **OBJECT:** `getLogRoute`
    - EXPORTS: Object `getLogRoute`
    - FIELD: `path: string`
    - FIELD: `method: string`
    - FIELD: `handler: async function(req, res)`
      - HANDLES_ROUTE: GET `/api/getLog/:userId`
      - CALLS: `console.log`
      - REFERENCES: `req.headers`, `req.params`
      - CALLS: `res.status(...).json(...)`
      - CALLS: `authorization.split`
      - CALLS: `jwt.verify`
      - CALLS: `getDbConnection`
      - DB_READ: `db.collection('logs').find`
      - CALLS: `cursor.toArray`

**FILE:** `backend/src/routes/getTopScores.ts`
  - IMPORTS: `getDbConnection` from `../db.ts`
  - **OBJECT:** `getTopScores`
    - EXPORTS: Object `getTopScores`
    - FIELD: `path: string`
    - FIELD: `method: string`
    - FIELD: `handler: async function(req, res)`
      - HANDLES_ROUTE: GET `/GetTopScores`
      - CALLS: `getDbConnection`
      - REFERENCES: `req.query.type`
      - CALLS: `console.warn`
      - CALLS: `res.status(...).json(...)`
      - CALLS: `console.log`
      - DB_READ: `db.collection(...).find(...).sort(...).toArray()`
      - CALLS: `res.sendStatus`

**FILE:** `backend/src/routes/index.ts`
  - IMPORTS: `logInRoute` from `./logInRoute.ts`
  - IMPORTS: `logRoute` from `./logRoute.ts`
  - IMPORTS: `getLogRoute` from `./getLogRoute.ts`
  - IMPORTS: `signUpRoute` from `./signUpRoute.ts`
  - IMPORTS: `getTopScores` from `./getTopScores.ts`
  - IMPORTS: `updateTopScore` from `./updateTopScore.ts`
  - **FUNCTION:** `routes()`
    - EXPORTS: Function `routes`
    - RETURNS: Array of route objects (`logRoute`, `getLogRoute`, etc.)

**FILE:** `backend/src/routes/logInRoute.ts`
  - IMPORTS: `bcrypt` from `bcrypt` (Module)
  - IMPORTS: `jwt` from `jsonwebtoken` (Module)
  - IMPORTS: `getDbConnection` from `../db.ts`
  - **OBJECT:** `logInRoute`
    - EXPORTS: Object `logInRoute`
    - FIELD: `path: string`
    - FIELD: `method: string`
    - FIELD: `handler: async function(req, res)`
      - HANDLES_ROUTE: POST `/api/login`
      - REFERENCES: `req.body`
      - CALLS: `getDbConnection`
      - DB_READ: `db.collection('users').findOne`
      - CALLS: `res.sendStatus`
      - CALLS: `bcrypt.compare`
      - CALLS: `jwt.sign`
      - CALLS: `res.status(...).json(...)`

**FILE:** `backend/src/routes/logRoute.ts`
  - IMPORTS: `jwt` from `jsonwebtoken` (Module)
  - IMPORTS: `getDbConnection` from `../db.ts`
  - **OBJECT:** `logRoute`
    - EXPORTS: Object `logRoute`
    - FIELD: `path: string`
    - FIELD: `method: string`
    - FIELD: `handler: async function(req, res)`
      - HANDLES_ROUTE: POST `/api/log/:userId`
      - REFERENCES: `req.headers`, `req.params`, `req.body`
      - CALLS: `console.log`
      - CALLS: `res.status(...).json(...)`
      - CALLS: `authorization.split`
      - CALLS: `jwt.verify`
      - CALLS: `getDbConnection`
      - DB_WRITE: `db.collection('logs').findOneAndUpdate`

**FILE:** `backend/src/routes/signUpRoute.ts`
  - IMPORTS: `bcrypt` from `bcrypt` (Module)
  - IMPORTS: `jwt` from `jsonwebtoken` (Module)
  - IMPORTS: `getDbConnection` from `../db.ts`
  - **OBJECT:** `signUpRoute`
    - EXPORTS: Object `signUpRoute`
    - FIELD: `path: string`
    - FIELD: `method: string`
    - FIELD: `handler: async function(req, res)`
      - HANDLES_ROUTE: POST `/api/signup`
      - REFERENCES: `req.body`
      - CALLS: `getDbConnection`
      - DB_READ: `db.collection('users').findOne`
      - CALLS: `console.log`
      - CALLS: `res.sendStatus`
      - CALLS: `bcrypt.hash`
      - DB_WRITE: `db.collection('users').insertOne`
      - DB_WRITE: `db.collection('logs').insertOne`
      - CALLS: `jwt.sign`
      - CALLS: `res.status(...).send(...)`
      - CALLS: `res.status(...).json(...)`

**FILE:** `backend/src/routes/spectateGameRoute.ts`
  - IMPORTS: `Request`, `Response` from `express` (Module)
  - IMPORTS: `GameService` from `../services/GameService.ts`
  - IMPORTS: `GameLogService` from `../services/GameLogService.ts`
  - IMPORTS: `getDbConnection` from `../db.ts`
  - FIELD: `gameServiceInstance: GameService`
  - FIELD: `gameLogServiceInstance: GameLogService`
  - **FUNCTION:** `initializeSpectateRoute(gs: GameService, gls: GameLogService)`
    - EXPORTS: Function `initializeSpectateRoute`
    - ASSIGNS: `gameServiceInstance`, `gameLogServiceInstance`
  - **OBJECT:** `spectateGameRoute`
    - EXPORTS: Object `spectateGameRoute`
    - FIELD: `path: string`
    - FIELD: `method: string`
    - FIELD: `handler: async function(req: Request, res: Response)`
      - HANDLES_ROUTE: GET `/api/spectate/:gameId`
      - CALLS: `parseInt`
      - CALLS: `console.log`, `console.error`
      - REFERENCES: `req.params`, `req.ip`, `req.headers`
      - CALLS: `res.status(...).json(...)`
      - REFERENCES: `gameServiceInstance`, `gameLogServiceInstance`
      - CALLS: `gameServiceInstance.getGame`
      - CALLS: `game.players.forEach`
      - CALLS: `player.calculateScores`
      - CALLS: `cell.label`, `cell.value`, `cell.fixed`
      - CALLS: `game.toJSON`
      - CALLS: `gameLogServiceInstance.getGameLog`
      - CALLS: `gameLog.moves.filter`
      - CALLS: `gameLog.moves.forEach`

**FILE:** `backend/src/routes/updateTopScore.ts`
  - IMPORTS: `getDbConnection` from `../db.ts`
  - **OBJECT:** `updateTopScore`
    - EXPORTS: Object `updateTopScore`
    - FIELD: `path: string`
    - FIELD: `method: string`
    - FIELD: `handler: async function(req, res)`
      - HANDLES_ROUTE: POST `/UpdateTopScore`
      - CALLS: `getDbConnection`
      - REFERENCES: `req.body.type`, `req.body.name`, `req.body.score`
      - CALLS: `console.warn`
      - CALLS: `res.status(...).json(...)`
      - DB_WRITE: `collection.insertOne`
      - DB_READ: `collection.find(...).sort(...).toArray()`
      - CALLS: `console.log`
      - CALLS: `res.sendStatus`

**FILE:** `backend/src/server.ts`
  - IMPORTS: `express` from `express` (Module)
  - IMPORTS: `routes` from `./routes/index.ts`
  - IMPORTS: `initializeDbConnection` from `./db.ts`
  - IMPORTS: `path` from `path` (Module)
  - IMPORTS: `cors` from `cors` (Module)
  - IMPORTS: `Server` from `socket.io` (Module)
  - IMPORTS: `createServer` from `http` (Module)
  - IMPORTS: `GameService` from `./services/GameService.ts`
  - IMPORTS: `GameLogService` from `./services/GameLogService.ts`
  - IMPORTS: `TopScoreService` from `./services/TopScoreService.ts`
  - IMPORTS: `GameController` from `./controllers/GameController.ts`
  - IMPORTS: `PlayerController` from `./controllers/PlayerController.ts`
  - IMPORTS: `ChatController` from `./controllers/ChatController.ts`
  - IMPORTS: `spectateGameRoute`, `initializeSpectateRoute` from `./routes/spectateGameRoute.ts`
  - CALLS: `express()`
  - CALLS: `app.use(cors(...))`
  - CALLS: `createServer(app)`
  - CALLS: `console.log`
  - CALLS: `app.use(express.static(...))`
  - CALLS: `app.use(express.json())`
  - CALLS: `routes()`
  - CALLS: `app[method](route.path, route.handler)`
  - CALLS: `app.get(spectateGameRoute.path, spectateGameRoute.handler)`
  - INSTANTIATES: `Server` (Socket.IO)
  - CALLS: `io.use(...)`
  - INSTANTIATES: `GameLogService`
  - INSTANTIATES: `TopScoreService`
  - INSTANTIATES: `GameService`
  - INSTANTIATES: `GameController`
  - INSTANTIATES: `PlayerController`
  - INSTANTIATES: `ChatController`
  - CALLS: `initializeSpectateRoute(gameService, gameLogService)`
  - HANDLES_SOCKET_EVENT: `io.on('connect', callback)`
    - CALLS: `console.log`, `console.error`
    - SENDS_SOCKET_EVENT: `socket.emit('welcome', ...)`
    - CALLS: `gameService.broadcastGameListToPlayer`
    - HANDLES_SOCKET_EVENT: `socket.on('echo', callback)`
      - SENDS_SOCKET_EVENT: `socket.emit('echo', ...)`
    - CALLS: `gameController.registerSocketHandlers(socket)`
    - CALLS: `playerController.registerSocketHandlers(socket)`
    - CALLS: `chatController.registerSocketHandlers(socket)`
    - HANDLES_SOCKET_EVENT: `socket.on('sendToServer', callback)`
      - REFERENCES: `data.action`, `data.gameType`
      - CALLS: `topScoreService.getTopScores`
      - SENDS_SOCKET_EVENT: `socket.emit('onServerMsg', ...)`
      - SENDS_SOCKET_EVENT: `socket.emit('errorMsg', ...)`
    - HANDLES_SOCKET_EVENT: `socket.on('sendToClients', callback)`
    - HANDLES_SOCKET_EVENT: `socket.on('disconnect', callback)`
      - CALLS: `gameService.handlePlayerDisconnect(socket.id)`
  - CALLS: `app.get('/', ...)`
  - CALLS: `initializeDbConnection()`
  - CALLS: `gameLogService.getCollection()`
  - CALLS: `httpServer.listen(PORT, ...)`
  - CALLS: `gameLogService.getDatabaseName()`
  - CALLS: `gameLogService.getCollectionName()`
  - CALLS: `process.exit`

**FILE:** `backend/src/services/GameLogService.ts`
  - **CLASS:** `GameLogService`
    - EXPORTS: Class `GameLogService`
    - IMPORTS: `Collection` from `mongodb` (Module)
    - IMPORTS: `getDbConnection` from `../db.ts`
    - IMPORTS: `Game` from `../models/Game.ts`
    - INTERFACE: `GameMove` (Exported)
    - INTERFACE: `GameLog` (Exported)
    - **METHOD:** `getCollection()`
      - CALLS: `getDbConnection`
      - CALLS: `db.collection`
    - **METHOD:** `getDatabaseName()`
    - **METHOD:** `getCollectionName()`
    - **METHOD:** `logGameStart(game: Game)`
      - CALLS: `console.log`, `console.error`
      - CALLS: `this.getCollection`
      - CALLS: `game.players.map`
      - DB_WRITE: `collection.replaceOne`
    - **METHOD:** `logMove(gameId: number, move: GameMove)`
      - CALLS: `console.log`, `console.error`
      - CALLS: `getDbConnection` (for debug)
      - CALLS: `this.getCollection`
      - DB_READ: `collection.findOne` (check exists)
      - DB_WRITE: `collection.insertOne` (placeholder)
      - DB_WRITE: `collection.updateOne`
      - CALLS: `JSON.stringify`
    - **METHOD:** `logGameEnd(gameId: number, finalScores: ...)`
      - CALLS: `console.log`, `console.error`
      - CALLS: `this.getCollection`
      - DB_WRITE: `collection.updateOne`
    - **METHOD:** `getGameLog(gameId: number)`
      - CALLS: `console.log`, `console.error`
      - CALLS: `this.getCollection`
      - DB_READ: `collection.findOne`
      - CALLS: `gameLog.moves.forEach`
    - **METHOD:** `logSpectate(gameId: number, spectatorId: string, spectatorName: string)`
      - CALLS: `console.log`, `console.error`
      - CALLS: `this.getGameLog`
      - CALLS: `this.getCollection`
      - DB_WRITE: `collection.updateOne`

**FILE:** `backend/src/services/GameService.ts`
  - **CLASS:** `GameService`
    - EXPORTS: Class `GameService`
    - IMPORTS: `Game` from `../models/Game.ts`
    - IMPORTS: `Player`, `PlayerFactory` from `../models/Player.ts`
    - IMPORTS: `Server`, `Socket` from `socket.io` (Module)
    - IMPORTS: `GameLogService`, `GameMove` from `./GameLogService.ts`
    - IMPORTS: `TopScoreService` from `./TopScoreService.ts`
    - IMPORTS: `getSelectionLabel` from `../utils/yatzyMapping.ts`
    - IMPORTS: `GameConfig`, `getBaseGameType` from `../utils/gameConfig.ts`
    - DEPENDS_ON: `Server` (constructor, field `io`)
    - DEPENDS_ON: `GameLogService` (constructor, field `gameLogService`)
    - DEPENDS_ON: `TopScoreService` (constructor, field `topScoreService`)
    - FIELD: `games: Map<number, Game>`
    - FIELD: `spectators: Map<number, Set<string>>`
    - **METHOD:** `constructor(io: Server, gameLogService: GameLogService, topScoreService: TopScoreService)`
    - **METHOD:** `addSpectator(gameId: number, spectatorId: string)`
      - REFERENCES: `this.games`, `this.spectators`, `this.io`
      - CALLS: `console.log`
      - CALLS: `this.games.get`
      - CALLS: `this.spectators.has`, `this.spectators.get`, `this.spectators.set`
      - CALLS: `gameSpectators.add`, `gameSpectators.has`
      - CALLS: `game.toJSON`
      - SENDS_SOCKET_EVENT: `this.io.to(...).emit('onServerMsg', ...)`
    - **METHOD:** `removeSpectator(spectatorId: string)`
      - REFERENCES: `this.spectators`
      - CALLS: `console.log`
      - CALLS: `this.spectators.entries`, `this.spectators.delete`
      - CALLS: `gameSpectators.delete`
    - **METHOD:** `createGame(gameType: string, maxPlayers: number)`
      - REFERENCES: `this.games`, `this.gameIdCounter`
      - CALLS: `console.log`, `console.error`
      - INSTANTIATES: `Game`
      - CALLS: `this.games.set`
      - CALLS: `this.gameLogService.logGameStart`
    - **METHOD:** `findAvailableGame(gameType: string, maxPlayers: number)`
      - REFERENCES: `this.games`
      - CALLS: `game.isGameFull`
    - **METHOD:** `getGame(gameId: number)`
      - REFERENCES: `this.games`
      - CALLS: `this.games.get`
    - **METHOD:** `getAllGames()`
      - REFERENCES: `this.games`
      - CALLS: `Array.from`
    - **METHOD:** `removeGame(gameId: number)`
      - REFERENCES: `this.games`
      - CALLS: `console.log`, `console.error`
      - CALLS: `this.games.get`
      - CALLS: `game.players.filter`
      - CALLS: `p.getScore`
      - CALLS: `this.gameLogService.logGameEnd`
      - CALLS: `this.games.delete`
    - **METHOD:** `joinGame(gameId: number, player: Player)`
      - REFERENCES: `this.games`
      - CALLS: `this.games.get`
      - CALLS: `game.isGameFull`
      - CALLS: `game.addPlayer`
      - CALLS: `console.log`, `console.error`
      - CALLS: `this.gameLogService.logGameStart`
    - **METHOD:** `handlePlayerDisconnect(playerId: string)`
      - REFERENCES: `this.games`
      - CALLS: `console.log`, `console.error`
      - CALLS: `game.findPlayerIndex`
      - CALLS: `game.getCurrentTurnNumber`
      - CALLS: `this.gameLogService.logMove`
      - CALLS: `game.markPlayerAborted`
      - CALLS: `this.handleGameFinished`
      - CALLS: `this.notifyGameUpdate`
      - CALLS: `this.broadcastGameList`
      - CALLS: `this.removeSpectator`
    - **METHOD:** `broadcastGameList()`
      - REFERENCES: `this.games`, `this.io`
      - CALLS: `console.log`
      - CALLS: `Array.from`
      - CALLS: `game.toJSON`
      - SENDS_SOCKET_EVENT: `this.io.emit('onServerMsg', ...)`
    - **METHOD:** `broadcastGameListToPlayer(playerId: string)`
      - REFERENCES: `this.games`, `this.io`
      - CALLS: `console.log`
      - CALLS: `Array.from`
      - CALLS: `game.toJSON`
      - SENDS_SOCKET_EVENT: `this.io.to(...).emit('onServerMsg', ...)`
    - **METHOD:** `notifyGameUpdate(game: Game)`
      - REFERENCES: `this.io`, `this.spectators`
      - CALLS: `game.players.forEach`
      - CALLS: `p.calculateDerivedScores`
      - CALLS: `game.toJSON`
      - SENDS_SOCKET_EVENT: `this.io.to(...).emit('onServerMsg', ...)`
    - **METHOD:** `handlePlayerStartingNewGame(playerId: string)`
      - CALLS: `console.log`
      - CALLS: `this.handlePlayerDisconnect`
    - **METHOD:** `handlePlayerAbort(playerId: string)`
      - CALLS: `console.log`
      - CALLS: `this.handlePlayerDisconnect`
    - **METHOD:** `handleGameFinished(game: Game)`
      - REFERENCES: `this.games`, `this.spectators`
      - CALLS: `console.log`, `console.error`
      - CALLS: `game.players.filter`
      - CALLS: `p.getScore`
      - CALLS: `this.gameLogService.logGameEnd`
      - CALLS: `finalScores.map`
      - CALLS: `this.topScoreService.updateTopScore`
      - CALLS: `Promise.all`
      - CALLS: `this.notifyGameFinished`
      - CALLS: `this.games.delete`
      - CALLS: `this.spectators.delete`
      - CALLS: `this.broadcastGameList`
    - **METHOD:** `notifyGameFinished(game: Game)`
      - REFERENCES: `this.io`, `this.spectators`
      - CALLS: `console.log`
      - CALLS: `game.toJSON`
      - SENDS_SOCKET_EVENT: `this.io.to(...).emit('onServerMsg', ...)`
    - **METHOD:** `processDiceRoll(gameId: number, playerId: string, diceValues: number[], keptDice: boolean[], ...)`
      - REFERENCES: `this.games`
      - CALLS: `console.error`, `console.log`
      - CALLS: `this.games.get`
      - CALLS: `game.findPlayerIndex`
      - CALLS: `game.getCurrentTurnNumber`
      - CALLS: `this.gameLogService.logMove`
      - CALLS: `game.setDiceValues`
      - CALLS: `game.incrementRollCount`
      - CALLS: `game.players.forEach`
      - CALLS: `p.clearPotentialScores`
      - CALLS: `currentPlayer.calculatePotentialScores`
      - CALLS: `currentPlayer.calculateScores`
      - CALLS: `this.notifyGameUpdate`
    - **METHOD:** `processSelection(gameId: number, playerId: string, selectionLabel: string, score: number)`
      - REFERENCES: `this.games`
      - CALLS: `console.error`, `console.log`
      - CALLS: `this.games.get`
      - CALLS: `game.findPlayerIndex`
      - CALLS: `game.getCurrentTurnNumber`
      - CALLS: `this.gameLogService.logMove`
      - CALLS: `this.gameLogService.getGameLog`
      - CALLS: `game.applySelection`
      - CALLS: `game.players.forEach`
      - CALLS: `p.clearPotentialScores`
      - CALLS: `game.isGameFinished`
      - CALLS: `this.notifyGameUpdate`
      - CALLS: `this.handleGameFinished`
      - CALLS: `game.advanceToNextActivePlayer`
      - REFERENCES: `GameConfig`, `getBaseGameType`
      - CALLS: `game.setDiceValues`
    - **METHOD:** `forwardSelectionToPlayers(gameId: number, senderId: string, selectionData: any)`
      - REFERENCES: `this.games`, `this.io`
      - CALLS: `console.log`, `console.error`
      - CALLS: `this.games.get`
      - CALLS: `getSelectionLabel`
      - CALLS: `game.findPlayerIndex`
      - SENDS_SOCKET_EVENT: `this.io.to(...).emit('onClientMsg', ...)`
    - **METHOD:** `createOrJoinGame(gameType: string, maxPlayers: number, player: Player)`
      - REFERENCES: `this.io`
      - CALLS: `console.error`, `console.warn`, `console.log`
      - CALLS: `this.handlePlayerStartingNewGame`
      - CALLS: `this.findAvailableGame`
      - CALLS: `this.createGame`
      - CALLS: `game.addPlayer`
      - CALLS: `this.gameLogService.logGameStart`
      - CALLS: `game.players.filter`
      - CALLS: `game.isGameFull`
      - CALLS: `game.toJSON`
      - SENDS_SOCKET_EVENT: `this.io.to(...).emit('onServerMsg', ...)`
      - CALLS: `this.notifyGameUpdate`
      - CALLS: `this.broadcastGameList`

**FILE:** `backend/src/services/TopScoreService.ts`
  - **CLASS:** `TopScoreService`
    - EXPORTS: Class `TopScoreService`
    - IMPORTS: `Collection`, `Db` from `mongodb` (Module)
    - IMPORTS: `getDbConnection` from `../db.ts`
    - IMPORTS: `Server` from `socket.io` (Module)
    - FIELD: `SUPPORTED_GAME_TYPES: string[]`
    - DEPENDS_ON: `Server` (constructor, field `io`)
    - **METHOD:** `constructor(io: Server)`
    - **METHOD:** `getDb()`
      - CALLS: `getDbConnection`
    - **METHOD:** `getCollection(gameType: string)`
      - CALLS: `console.warn`
      - CALLS: `this.getDb`
      - CALLS: `db.collection`
    - **METHOD:** `getTopScores(gameType: string, limit?: number)`
      - CALLS: `console.warn`, `console.error`, `console.log`
      - CALLS: `this.getCollection`
      - DB_READ: `collection.find(...).sort(...).limit(...).toArray()`
    - **METHOD:** `getAllTopScores()`
      - CALLS: `console.log`
      - CALLS: `this.getTopScores`
    - **METHOD:** `broadcastTopScores()`
      - REFERENCES: `this.io`
      - CALLS: `this.getAllTopScores`
      - SENDS_SOCKET_EVENT: `this.io.emit('onTopScoresUpdate', ...)`
      - CALLS: `console.log`, `console.error`
    - **METHOD:** `updateTopScore(gameType: string, name: string, score: number)`
      - CALLS: `console.warn`, `console.error`, `console.log`
      - CALLS: `this.getCollection`
      - DB_WRITE: `collection.insertOne`

**FILE:** `backend/src/utils/gameConfig.ts`
  - INTERFACE: `GameTypeConfig` (Not explicitly exported, used internally)
  - **OBJECT:** `GameConfig`
    - EXPORTS: Object `GameConfig`
  - **FUNCTION:** `getBaseGameType(gameType: string)`
    - EXPORTS: Function `getBaseGameType`

**FILE:** `backend/src/utils/index.ts`
  - **FUNCTION:** `randomInt(min: number, max: number)`
    - EXPORTS: Function `randomInt`
    - CALLS: `Math.floor`, `Math.random`
  - **FUNCTION:** `delay(ms: number)`
    - EXPORTS: Function `delay`
    - CALLS: `setTimeout`
    - INSTANTIATES: `Promise`
  - **FUNCTION:** `isDefined<T>(value: T | undefined | null)`
    - EXPORTS: Function `isDefined`
  - **FUNCTION:** `deepCopy<T>(obj: T)`
    - EXPORTS: Function `deepCopy`
    - CALLS: `JSON.parse`, `JSON.stringify`

**FILE:** `backend/src/utils/yatzyMapping.ts`
  - FIELD: `gameTypeMappings` (Internal object)
  - **FUNCTION:** `getBaseGameType(gameType: string)` (Internal)
  - **FUNCTION:** `getSelectionLabel(gameType: string, index: number)`
    - EXPORTS: Function `getSelectionLabel`
    - CALLS: `getBaseGameType`
    - CALLS: `console.error`
  - **FUNCTION:** `getSelectionIndex(gameType: string, label: string)`
    - EXPORTS: Function `getSelectionIndex`
    - CALLS: `getBaseGameType`
    - CALLS: `labels.indexOf`
    - CALLS: `console.error`

**FILE:** `lib/application/animations_application.dart`
  - **CLASS:** `AnimationsApplication`
    - FIELD: `animationControllers: List<AnimationController>`
    - FIELD: `animationDurations: List<Duration>`
    - FIELD: `cellAnimationControllers: List<dynamic>`
    - FIELD: `cellAnimation: List<dynamic>`
    - FIELD: `players: int`
    - FIELD: `boardXAnimationPos: List<dynamic>`
    - FIELD: `boardYAnimationPos: List<dynamic>`
    - **METHOD:** `animateBoard()`
      - CALLS: `cellAnimationControllers[i][0].forward()`
    - **METHOD:** `setupAnimation(TickerProvider, int, int, int)`
      - INSTANTIATES: `AnimationController`
      - CALLS: `animationControllers[0].addStatusListener`
      - INSTANTIATES: `CurveTween`
      - CALLS: `CurveTween(...).animate(...)`
      - CALLS: `cellAnimationControllers[i][j].addListener`
      - CALLS: `cellAnimationControllers[i][j].addStatusListener`

**FILE:** `lib/application/application_functions_internal.dart`
  - **EXTENSION:** `ApplicationFunctionsInternal` on `Application`
    - **METHOD:** `clearFocus()`
      - REFERENCES: `focusStatus`, `nrPlayers`, `totalFields`
    - **METHOD:** `cellClick(int player, int cell)`
      - REFERENCES: `playerToMove`, `myPlayerId`, `fixedCell`, `cellValue`, `gameType`, `gameDices`, `gameId`, `socketService`, `dices`
      - CALLS: `getSelectionLabel`
      - CALLS: `print`
      - CALLS: `socketService.sendToClients`

**FILE:** `lib/application/application.dart`
  - **CLASS:** `Application`
    - USES_MIXIN: `LanguagesApplication`
    - FIELD: `context: BuildContext`
    - FIELD: `inputItems: InputItems`
    - FIELD: `gameDices: Dices`
    - FIELD: `tabController: dynamic`
    - FIELD: `textEditingController: TextEditingController`
    - FIELD: `focusNode: FocusNode`
    - FIELD: `animation: AnimationsApplication`
    - FIELD: `games: List<dynamic>`
    - FIELD: `presentations: List<dynamic>`
    - FIELD: `boardAnimation: bool`
    - FIELD: `stackedWidgets: List<Widget>`
    - FIELD: `gameType: String`
    - FIELD: `nrPlayers: int`
    - FIELD: `maxNrPlayers: int`
    - FIELD: `maxTotalFields: int`
    - FIELD: `gameData: Map<String, dynamic>`
    - FIELD: `gameId: int`
    - FIELD: `playerActive: List<bool>`
    - FIELD: `totalFields: int`
    - FIELD: `bonusSum: int`
    - FIELD: `bonusAmount: int`
    - FIELD: `myPlayerId: int`
    - FIELD: `playerToMove: int`
    - FIELD: `winnerId: int`
    - FIELD: `gameStarted: bool`
    - FIELD: `gameFinished: bool`
    - FIELD: `boardXPos`, `boardYPos`, `boardWidth`, `boardHeight`, `cellValue`, `fixedCell`, `appText`, `appColors`, `focusStatus`: `List<dynamic>`
    - FIELD: `listenerKey: GlobalKey`
    - FIELD: `serverId: String`
    - FIELD: `socketService: SocketService?`
    - FIELD: `isSpectating: bool`
    - FIELD: `spectatedGameId: int`
    - **METHOD:** `constructor({context, gameDices, inputItems})`
      - CALLS: `gameDices.setCallbacks`
      - CALLS: `languagesSetup`
      - CALLS: `getChosenLanguage`
      - CALLS: `getStandardLanguage`
    - **METHOD:** `getChosenLanguage()`
    - **METHOD:** `getStandardLanguage()`
    - **METHOD:** `callbackCheckPlayerToMove()`
      - REFERENCES: `playerToMove`, `myPlayerId`
    - **METHOD:** `callbackUnityCreated()`
      - REFERENCES: `myPlayerId`, `playerToMove`, `gameDices`
      - CALLS: `gameDices.sendStartToUnity`
    - **METHOD:** `callbackUpdateDiceValues()`
      - REFERENCES: `gameId`, `gameDices`, `socketService`
      - CALLS: `print`
      - CALLS: `socketService?.sendToClients`
    - **METHOD:** `setAppText()`
      - REFERENCES: `gameType`, `appText`, `bonusAmount`, `ones_`, `twos_`, ... `totalSum_`
    - **METHOD:** `setup()`
      - REFERENCES: `topScore`, `gameType`, `gameStarted`, `playerToMove`, `winnerId`, `totalFields`, `gameDices`, `bonusSum`, `bonusAmount`, `appText`, `isTesting`, `nrPlayers`, `boardXPos`, `boardYPos`, `boardWidth`, `boardHeight`, `animation`, `focusStatus`, `fixedCell`, `cellValue`, `appColors`, `myPlayerId`
      - CALLS: `topScore.loadTopScoreFromServer`
      - CALLS: `context.read<SetStateCubit>()`
      - CALLS: `gameDices.initDices`
      - CALLS: `setAppText`
      - CALLS: `clearFocus`
      - CALLS: `gameDices.sendResetToUnity`
      - CALLS: `gameDices.sendStartToUnity`
    - **METHOD:** `setSocketService(SocketService service)`
      - REFERENCES: `socketService`
      - CALLS: `print`

**FILE:** `lib/application/communication_application.dart`
  - **EXTENSION:** `CommunicationApplication` on `Application`
    - **METHOD:** `resetDices()`
      - REFERENCES: `gameDices`, `totalFields`, `playerToMove`, `fixedCell`, `appText`, `cellValue`
      - CALLS: `gameDices.clearDices`
      - CALLS: `clearFocus`
    - **METHOD:** `callbackOnServerMsg(dynamic data)`
      - REFERENCES: `getIt<AppRouter>`, `socketService`, `SharedPrefProvider`, `userName`, `gameType`, `nrPlayers`, `boardAnimation`, `chosenLanguage`, `gameDices`, `gameId`, `gameStarted`, `gameData`, `myPlayerId`, `userNames`, `animation`, `applicationStarted`, `isSpectating`, `spectatedGameId`, `topScore`, `appText`
      - CALLS: `print`
      - CALLS: `ServiceProvider.of`
      - CALLS: `SharedPrefProvider.fetchPrefObject`
      - CALLS: `data.map`
      - CALLS: `socketService?.socketId`
      - CALLS: `List<dynamic>.from`
      - CALLS: `context.read<SetStateCubit>().setState`
      - CALLS: `setup`
      - CALLS: `gameDices.sendResetToUnity`
      - CALLS: `gameDices.sendStartToUnity`
      - CALLS: `router.pushAndPopUntil`
      - CALLS: `router.pop`
      - CALLS: `_processGameUpdate`
      - CALLS: `topScore.updateScoresFromData`
    - **METHOD:** `_processGameUpdate(dynamic data)`
      - REFERENCES: `getIt<AppRouter>`, `isSpectating`, `gameId`, `gameData`, `context`, `socketService`, `myPlayerId`, `gameType`, `nrPlayers`, `playerActive`, `totalFields`, `fixedCell`, `cellValue`, `appText`, `appColors`, `playerToMove`, `gameDices`
      - CALLS: `print`
      - CALLS: `Map<String, dynamic>.from`
      - CALLS: `context.read<SetStateCubit>().setState`
      - CALLS: `setup`
      - CALLS: `gameDices.sendResetToUnity`
      - CALLS: `gameDices.sendStartToUnity`
      - CALLS: `router.pushAndPopUntil`
      - CALLS: `router.pop`
      - CALLS: `resetDices`
    - **METHOD:** `chatCallbackOnSubmitted(String text)`
      - REFERENCES: `chat`, `gameId`, `socketService`, `userName`
      - CALLS: `print`
      - CALLS: `chat.scrollController.animateTo`
      - CALLS: `socketService.sendToClients`
    - **METHOD:** `updateChat(String text)`
      - REFERENCES: `chat`
      - INSTANTIATES: `ChatMessage`
      - CALLS: `chat.messages.add`
      - CALLS: `Future.delayed`
      - CALLS: `chat.scrollController.animateTo`
    - **METHOD:** `callbackOnClientMsg(var data)`
      - REFERENCES: `getIt<AppRouter>`, `playerActive`, `myPlayerId`, `gameDices`
      - CALLS: `print`
      - CALLS: `data.cast<int>`
      - CALLS: `resetDices`
      - CALLS: `gameDices.updateDiceImages`
      - CALLS: `gameDices.sendDicesToUnity`
      - CALLS: `updateChat`
      - CALLS: `router.push`

**FILE:** `lib/application/languages_application.dart`
  - **MIXIN:** `LanguagesApplication`
    - FIELD: `_getChosenLanguage: Function`
    - FIELD: `_standardLanguage: String`
    - FIELD: `_ones`, `_twos`, ... (Map<String, String>)
    - **METHOD:** `ones_`, `twos_`, ... (getters)
      - CALLS: `getText`
    - **METHOD:** `languagesSetup(Function, String)`
    - **METHOD:** `getText(var textVariable)`
      - CALLS: `_getChosenLanguage()`

**FILE:** `lib/application/widget_application_scaffold.dart`
  - **EXTENSION:** `WidgetApplicationScaffold` on `Application`
    - **METHOD:** `widgetScaffold(BuildContext context, Function state)`
      - REFERENCES: `screenWidth`, `screenHeight`, `devicePixelRatio`, `stackedWidgets`, `settings_`, `h`, `w`, `l`, `t`
      - UI_BUILD: Implies UI structure
      - CALLS: `MediaQuery.of`, `AutoRouter.of`, `widgetFloatingButton`, `WidgetDices`, `WidgetTopScore`, `WidgetSetupGameBoard`, `WidgetDisplayGameStatus`, `WidgetChat`
      - INSTANTIATES: `Scaffold`, `Stack`, `Container`, `Positioned`, `LinearGradient`, `SizedBox`, `FittedBox`, `FloatingActionButton`, `Icon`
      - EVENT_HANDLER: `FloatingActionButton.onPressed`
        - CALLS: `AutoRouter.of(context).push(SettingsView)`

**FILE:** `lib/application/widget_application_settings.dart`
  - **EXTENSION:** `WidgetApplicationSettings` on `Application`
    - **METHOD:** `widgetWaitingGame(BuildContext context)`
      - REFERENCES: `games`, `gameTypeOrdinary_`, `ongoingGames_`, `inputItems`, `headingStyle`, `myPlayerSocketId`
      - CALLS: `ServiceProvider.of`, `socketService.socketId`, `print`, `List<String>.from`, `map`, `join`, `inputItems.widgetButton`, `onAttemptJoinGame`, `onSpectateGame`, `Text`
      - INSTANTIATES: `Padding`, `Card`, `TextStyle`
    - **METHOD:** `onSpectateGame(BuildContext context, int gameId)`
      - REFERENCES: `ServiceProvider`, `socketService`, `userName`, `isSpectating`, `spectatedGameId`, `gameData`
      - CALLS: `print`, `ServiceProvider.of`, `socketService.isConnected`, `socketService.sendToServer`, `context.read<SetStateCubit>().setState`, `ScaffoldMessenger.of(...).showSnackBar`
      - INSTANTIATES: `SnackBar`
    - **METHOD:** `onAttemptJoinGame(BuildContext context, int i)`
      - REFERENCES: `games`, `userName`, `ServiceProvider`
      - CALLS: `print`, `ServiceProvider.of`, `socketService.isConnected`, `socketService.sendToServer`
    - **METHOD:** `_buildGameTypeSelection(Function state)`
      - REFERENCES: `inputItems`, `gameTypeOrdinary_`, `gameTypeMaxi_`, `gameType`
      - UI_BUILD: Implies UI structure
      - CALLS: `inputItems.widgetStringRadioButton`
      - INSTANTIATES: `Padding`, `Card`, `Container`, `BoxDecoration`, `LinearGradient`, `Column`, `Text`, `SizedBox`
    - **METHOD:** `onStartGameButton(BuildContext context, Function state)`
      - REFERENCES: `ServiceProvider`, `nrPlayers`, `userName`, `gameType`, `chosenLanguage`, `boardAnimation`, `gameDices`, `SharedPrefProvider`
      - CALLS: `ServiceProvider.of`, `socketService.isConnected`, `print`, `List.filled`, `socketService.sendToServer`, `state()`, `SharedPrefProvider.setPrefObject`
    - **METHOD:** `onChangeUserName(value)`
      - REFERENCES: `userName`, `textEditingController`
    - **METHOD:** `widgetScaffoldSettings(BuildContext context, Function state)`
      - REFERENCES: `tabController`, `settings_`, `game_`, `general_`, `primaryColor`, `accentColor`, `tabTextStyle`, `headingStyle`, `subtitleStyle`, `isSpectating`, `gameData`, `gameDices`
      - UI_BUILD: Implies UI structure
      - CALLS: `_buildGameTypeSelection`, `inputItems.widgetIntRadioButton`, `inputItems.widgetInputText`, `onChangeUserName`, `onStartGameButton`, `widgetWaitingGame`, `context.read<SetStateCubit>().setState`, `inputItems.widgetCheckbox`, `inputItems.widgetDropDownList`, `context.read<LanguageBloc>().add`, `gameDices.widgetUnitySettings`
      - INSTANTIATES: `DefaultTabController`, `Scaffold`, `AppBar`, `TabBar`, `Tab`, `TabBarView`, `Container`, `BoxDecoration`, `LinearGradient`, `Scrollbar`, `ListView`, `Padding`, `Card`, `Column`, `Row`, `Text`, `SizedBox`, `ElevatedButton`, `Theme`, `CheckboxThemeData`, `Divider`, `Icon`, `SpectatorGameBoard`
      - EVENT_HANDLER: `ElevatedButton.onPressed` (Start Game)
      - EVENT_HANDLER: `ElevatedButton.onPressed` (Stop Spectating)

**FILE:** `lib/application/widget_application.dart`
  - **CLASS:** `WidgetSetupGameBoard` (StatefulWidget)
    - FIELD: `width: double`
    - FIELD: `height: double`
    - **METHOD:** `createState()` -> `_WidgetSetupGameBoardState`
  - **CLASS:** `_WidgetSetupGameBoardState`
    - USES_MIXIN: `TickerProviderStateMixin`, `LanguagesApplication`
    - **METHOD:** `initState()`
      - CALLS: `super.initState`, `languagesSetup`, `app.getChosenLanguage`, `app.getStandardLanguage`
    - **METHOD:** `build(BuildContext context)`
      - REFERENCES: `widget.width`, `widget.height`, `app.nrPlayers`, `app.totalFields`, `app.boardWidth`, `app.boardHeight`, `app.boardXPos`, `app.boardYPos`, `app.animation`, `app.appText`, `app.appColors`, `userNames`, `app.playerToMove`, `app.myPlayerId`, `app.listenerKey`, `app.fixedCell`, `app.cellValue`, `app.focusStatus`, `screenWidth`
      - UI_BUILD: Implies UI structure
      - CALLS: `min`, `app.setup`, `app.setAppText`, `AnimatedBuilder`, `Positioned`, `Container`, `BoxDecoration`, `Border.all`, `FittedBox`, `Text`, `GestureDetector`, `app.cellClick`, `context.read<SetStateCubit>().setState`, `app.clearFocus`
      - EVENT_HANDLER: `GestureDetector.onVerticalDragUpdate`
      - EVENT_HANDLER: `GestureDetector.onTap` (Clear focus)
      - EVENT_HANDLER: `GestureDetector.onTap` (Cell click)
  - **CLASS:** `WidgetDisplayGameStatus` (StatefulWidget)
    - FIELD: `width: double`
    - FIELD: `height: double`
    - **METHOD:** `createState()` -> `_WidgetDisplayGameStatusState`
  - **CLASS:** `_WidgetDisplayGameStatusState`
    - USES_MIXIN: `LanguagesApplication`
    - **METHOD:** `initState()`
      - CALLS: `super.initState`, `languagesSetup`, `app.getChosenLanguage`, `app.getStandardLanguage`
    - **METHOD:** `build(BuildContext context)`
      - REFERENCES: `widget.width`, `widget.height`, `app.gameFinished`, `app.gameStarted`, `app.gameDices`, `app.playerToMove`, `app.myPlayerId`, `your_`, `userNames`, `turn_`, `gameFinished_`, `app.gameDices.rollsLeft_`, `app.gameDices.nrTotalRolls`, `app.gameDices.nrRolls`
      - UI_BUILD: Implies UI structure
      - CALLS: `app.gameDices.sendResetToUnity`, `Container`, `Column`, `SizedBox`, `AutoSizeText`, `FittedBox`, `Text`

**FILE:** `lib/chat/chat.dart`
  - **CLASS:** `ChatMessage`
    - FIELD: `messageContent: String`
    - FIELD: `messageType: String`
    - **METHOD:** `constructor(String, String)`
  - **CLASS:** `Chat`
    - FIELD: `_getChosenLanguage: Function`
    - FIELD: `_standardLanguage: String`
    - FIELD: `setState: Function`
    - FIELD: `inputItems: InputItems`
    - FIELD: `callbackOnSubmitted: Function`
    - FIELD: `chatTextController: TextEditingController`
    - FIELD: `scrollController: ScrollController`
    - FIELD: `focusNode: FocusNode`
    - FIELD: `messages: List<ChatMessage>`
    - **METHOD:** `constructor({...})`
    - **METHOD:** `getChosenLanguage()`
    - **METHOD:** `standardLanguage()`
    - **METHOD:** `onSubmitted(String value, BuildContext context)`
      - REFERENCES: `chatTextController`, `messages`, `callbackOnSubmitted`, `scrollController`
      - CALLS: `chatTextController.clear`, `messages.add`, `callbackOnSubmitted`, `setState`, `Future.delayed`, `scrollController.animateTo`
      - INSTANTIATES: `ChatMessage`

**FILE:** `lib/chat/languages_chat.dart`
  - **MIXIN:** `LanguagesChat`
    - FIELD: `_getChosenLanguage: Function`
    - FIELD: `_standardLanguage: String`
    - FIELD: `_sendMessage: Map<String, String>`
    - **METHOD:** `sendMessage_` (getter)
      - CALLS: `getText`
    - **METHOD:** `languagesSetup(Function, String)`
    - **METHOD:** `getText(var textVariable)`
      - CALLS: `_getChosenLanguage()`

**FILE:** `lib/chat/widget_chat.dart`
  - **CLASS:** `WidgetChat` (StatefulWidget)
    - FIELD: `width: double`
    - FIELD: `height: double`
    - **METHOD:** `createState()` -> `_WidgetChatState`
  - **CLASS:** `_WidgetChatState`
    - USES_MIXIN: `LanguagesChat`
    - **METHOD:** `initState()`
      - CALLS: `super.initState`, `languagesSetup`, `chat.getChosenLanguage`, `chat.standardLanguage`
    - **METHOD:** `build(BuildContext context)`
      - REFERENCES: `widget.width`, `widget.height`, `sendMessage_`, `chat`
      - UI_BUILD: Implies UI structure
      - CALLS: `widgetInputText`, `widgetChatOutput`, `Container`, `BoxDecoration`, `LinearGradient`, `BoxShadow`, `ClipRRect`, `Column`, `Padding`, `Row`, `Icon`, `SizedBox`, `Text`, `Expanded`
      - EVENT_HANDLER: `IconButton.onPressed` (Send message)
    - **METHOD:** `widgetInputText(...)` (Internal Helper)
      - INSTANTIATES: `Padding`, `TextField`, `TextStyle`, `InputDecoration`, `OutlineInputBorder`, `BorderSide`, `IconButton`, `Icon`
    - **METHOD:** `widgetChatOutput()` (Internal Helper)
      - REFERENCES: `chat`
      - CALLS: `Container`, `BoxDecoration`, `LinearGradient`, `Border.all`, `Padding`, `ListView.builder`, `Align`, `BoxConstraints`, `Text`

**FILE:** `lib/core/app_widget.dart`
  - **CLASS:** `AppWidget` (StatelessWidget)
    - FIELD: `_appRouter: AppRouter`
    - **METHOD:** `constructor()`
      - USES_DI: `getIt<AppRouter>`
    - **METHOD:** `getChosenLanguage()`
      - REFERENCES: `chosenLanguage`
    - **METHOD:** `build(BuildContext context)`
      - REFERENCES: `topScore`, `dices`, `app`, `chat`, `_appRouter`, `inputItems`
      - UI_BUILD: Main application setup
      - CALLS: `TopScore`, `Dices`, `Application`, `Chat`, `ServiceProvider.initialize`, `MaterialApp.router`, `ThemeData`, `WidgetsBinding.instance.addPostFrameCallback`, `ServiceProvider.of`, `socketService.connect`, `app.setSocketService`
      - INSTANTIATES: `TopScore`, `Dices`, `Application`, `Chat`
      - DEPENDS_ON: `SetStateCubit` (via `setState` callback in Dices/Chat)
      - DEPENDS_ON: `AppRouter` (field)
      - DEPENDS_ON: `ServiceProvider`

**FILE:** `lib/core/injectable_modules.dart`
  - **CLASS:** `InjectableModule` (abstract)
    - ANNOTATION: `@module`
    - **METHOD:** `router` (getter)
      - ANNOTATION: `@lazySingleton`
      - USES_DI: Provides `AppRouter`
      - INSTANTIATES: `AppRouter`

**FILE:** `lib/dices/dices.dart`
  - **CLASS:** `Dices`
    - EXTENDS: `LanguagesDices`
    - FIELD: `setState: Function`
    - FIELD: `inputItems: InputItems`
    - FIELD: `holdDices`, `holdDiceText`, `holdDiceOpacity`: `List<dynamic>`
    - FIELD: `nrRolls: int`
    - FIELD: `nrTotalRolls: int`
    - FIELD: `nrDices: int`
    - FIELD: `diceValue: List<int>`
    - FIELD: `diceRef: List<String>`
    - FIELD: `diceFile: List<String>`
    - FIELD: `callbackUpdateDiceValues: Function`
    - FIELD: `callbackUnityCreated: Function`
    - FIELD: `callbackCheckPlayerToMove: Function`
    - FIELD: `sizeAnimation: Animation<double>`
    - FIELD: `unityWidgetController: UnityWidgetController`
    - FIELD: `unityCreated: bool`
    - FIELD: `unityColors: List<double>`
    - FIELD: `unityDices: bool`
    - FIELD: `unityTransparent: bool`
    - FIELD: `unityLightMotion: bool`
    - FIELD: `unityFun: bool`
    - FIELD: `unitySnowEffect: bool`
    - FIELD: `unityId: String`
    - **METHOD:** `constructor({...})`
      - CALLS: `languagesSetup`
    - **METHOD:** `setCallbacks(cb1, cb2, cb3)`
    - **METHOD:** `clearDices()`
    - **METHOD:** `initDices(int nrdices)`
      - CALLS: `sendResetToUnity`
    - **METHOD:** `holdDice(int dice)`
      - REFERENCES: `diceValue`, `nrRolls`, `nrTotalRolls`, `holdDices`, `holdDiceText`, `holdDiceOpacity`, `hold_`
    - **METHOD:** `updateDiceImages()`
      - REFERENCES: `nrDices`, `diceRef`, `diceFile`, `diceValue`
    - **METHOD:** `rollDices(BuildContext context)`
      - REFERENCES: `app.gameFinished`, `nrRolls`, `nrTotalRolls`, `nrDices`, `holdDices`, `diceValue`, `diceRef`, `diceFile`
      - CALLS: `callbackCheckPlayerToMove`, `print`, `Random`, `nextInt`, `callbackUpdateDiceValues`
      - INSTANTIATES: `Random`
    - **METHOD:** `widgetUnitySettings(Function state)`
      - REFERENCES: `inputItems`, `showUnityOptions`, `unityDices`, `choseUnity_`, `unityLightMotion`, `lightMotion_`, `unityFun`, `fun_`, `unitySnowEffect`, `snowEffect_`
      - CALLS: `inputItems.widgetCheckbox`, `sendLightMotionChangedToUnity`, `sendFunChangedToUnity`, `sendSnowEffectChangedToUnity`

**FILE:** `lib/dices/languages_dices.dart`
  - **CLASS:** `LanguagesDices` (mixin)
    - FIELD: `_getChosenLanguage: Function`
    - FIELD: `_standardLanguage: String`
    - FIELD: `_hold`, `_rollsLeft`, ... (Map<String, String>)
    - **METHOD:** `choseUnity_`, `colorChangeOverlay_`, ... (getters)
      - CALLS: `getText`
    - **METHOD:** `languagesSetup(Function, String)`
    - **METHOD:** `getText(var textVariable)`
      - CALLS: `_getChosenLanguage()`

**FILE:** `lib/dices/unity_communication.dart`
  - **EXTENSION:** `UnityCommunication` on `Dices`
    - **METHOD:** `sendResetToUnity()`
      - REFERENCES: `nrDices`, `nrTotalRolls`, `unityWidgetController`
      - CALLS: `print`, `UnityMessage.reset`, `msg.toJson`, `jsonEncode`, `unityWidgetController.postMessage`
      - UNITY_POSTMESSAGE: To `GameManager.flutterMessage`
    - **METHOD:** `sendStartToUnity()`
      - REFERENCES: `unityWidgetController`
      - CALLS: `UnityMessage.start`, `msg.toJson`, `jsonEncode`, `unityWidgetController.postMessage`
      - UNITY_POSTMESSAGE: To `GameManager.flutterMessage`
    - **METHOD:** `sendDicesToUnity()`
      - REFERENCES: `diceValue`, `unityWidgetController`
      - CALLS: `UnityMessage.updateDices`, `msg.toJson`, `jsonEncode`, `unityWidgetController.postMessage`
      - UNITY_POSTMESSAGE: To `GameManager.flutterMessage`
    - **METHOD:** `sendColorsToUnity()`
      - REFERENCES: `unityColors`, `unityWidgetController`
      - CALLS: `UnityMessage.updateColors`, `msg.toJson`, `jsonEncode`, `unityWidgetController.postMessage`
      - UNITY_POSTMESSAGE: To `GameManager.flutterMessage`
    - **METHOD:** `sendTransparencyChangedToUnity()`
      - REFERENCES: `unityTransparent`, `unityWidgetController`
      - CALLS: `UnityMessage.changeBool`, `msg.toJson`, `jsonEncode`, `unityWidgetController.postMessage`
      - UNITY_POSTMESSAGE: To `GameManager.flutterMessage`
    - **METHOD:** `sendLightMotionChangedToUnity()`
      - REFERENCES: `unityLightMotion`, `unityWidgetController`
      - CALLS: `UnityMessage.changeBool`, `msg.toJson`, `jsonEncode`, `unityWidgetController.postMessage`
      - UNITY_POSTMESSAGE: To `GameManager.flutterMessage`
    - **METHOD:** `sendFunChangedToUnity()`
      - REFERENCES: `unityFun`, `unityWidgetController`
      - CALLS: `UnityMessage.changeBool`, `msg.toJson`, `jsonEncode`, `unityWidgetController.postMessage`
      - UNITY_POSTMESSAGE: To `GameManager.flutterMessage`
    - **METHOD:** `sendSnowEffectChangedToUnity()`
      - REFERENCES: `unitySnowEffect`, `unityWidgetController`
      - CALLS: `UnityMessage.changeBool`, `msg.toJson`, `jsonEncode`, `unityWidgetController.postMessage`
      - UNITY_POSTMESSAGE: To `GameManager.flutterMessage`
    - **METHOD:** `onUnityMessage(message)`
      - REFERENCES: `diceValue`, `callbackUpdateDiceValues`, `nrRolls`, `unityId`
      - FLUTTER_UNITYMESSAGE_HANDLER: Handles messages from Unity.
      - CALLS: `print`, `jsonDecode`, `json.cast<int>`, `sendSnowEffectChangedToUnity`, `sendFunChangedToUnity`, `sendLightMotionChangedToUnity`, `sendResetToUnity`, `callbackCheckPlayerToMove`, `sendStartToUnity`
    - **METHOD:** `onUnityUnloaded()`
    - **METHOD:** `onUnityCreated(controller)`
      - REFERENCES: `unityWidgetController`, `unityCreated`
      - CALLS: `sendResetToUnity`, `callbackUnityCreated`, `print`
    - **METHOD:** `onUnitySceneLoaded(SceneLoaded? sceneInfo)`

**FILE:** `lib/dices/unity_message.dart`
  - **CLASS:** `UnityMessage`
    - FIELD: `actionUnity: String`
    - FIELD: `property: String`
    - FIELD: `dices: List`
    - FIELD: `unityColors: List<double>`
    - FIELD: `flag: bool`
    - FIELD: `nrDices: int`
    - FIELD: `nrThrows: int`
    - **CONSTRUCTOR:** `UnityMessage(this.actionUnity)`
    - **CONSTRUCTOR:** `UnityMessage.reset(this.nrDices, this.nrThrows)`
    - **CONSTRUCTOR:** `UnityMessage.start()`
    - **CONSTRUCTOR:** `UnityMessage.updateDices(this.dices)`
    - **CONSTRUCTOR:** `UnityMessage.updateColors(this.unityColors)`
    - **CONSTRUCTOR:** `UnityMessage.changeBool(this.property, this.flag)`
    - **FACTORY:** `UnityMessage.fromJson(Map<String, dynamic> json)`
    - **METHOD:** `toJson()`

**FILE:** `lib/dices/widget_dices.dart`
  - **CLASS:** `WidgetDices` (StatefulWidget)
    - FIELD: `width: double`
    - FIELD: `height: double`
    - **METHOD:** `createState()` -> `_WidgetDicesState`
  - **CLASS:** `_WidgetDicesState`
    - USES_MIXIN: `TickerProviderStateMixin`
    - FIELD: `_localAnimationController: AnimationController`
    - FIELD: `_localSizeAnimation: Animation<double>`
    - **METHOD:** `initState()`
      - CALLS: `super.initState`, `AnimationController`, `CurveTween.animate`, `_localAnimationController.addStatusListener`
    - **METHOD:** `dispose()`
      - CALLS: `_localAnimationController.stop`, `_localAnimationController.dispose`, `super.dispose`, `print`
    - **STATIC METHOD:** `buildDiceFace(int value, double diceSize)`
      - UI_BUILD: Helper for dice UI
      - INSTANTIATES: `Container`, `Stack`, `Center`, `Align`, `Padding`
    - **METHOD:** `build(BuildContext context)`
      - REFERENCES: `widget.width`, `widget.height`, `app.gameDices`, `left`, `top`, `w`, `h`
      - UI_BUILD: Builds either UnityWidget or 2D dice UI
      - CALLS: `min`, `Positioned`, `SizedBox`, `UnityWidget`, `app.gameDices.onUnityCreated`, `app.gameDices.onUnityMessage`, `app.gameDices.onUnityUnloaded`, `app.gameDices.onUnitySceneLoaded`, `GestureDetector`, `app.callbackCheckPlayerToMove`, `app.gameDices.holdDice`, `app.gameDices.setState`, `Container`, `BoxDecoration`, `BorderRadius.circular`, `Border.all`, `BoxShadow`, `buildDiceFace`, `AnimatedBuilder`, `app.gameFinished`, `app.gameDices.nrRolls`, `app.gameDices.nrTotalRolls`, `ElevatedButton`, `app.gameDices.rollDices`, `_localAnimationController.forward`, `ElevatedButton.styleFrom`, `CircleBorder`, `Icon`
      - EVENT_HANDLER: `GestureDetector.onTap` (Hold Dice)
      - EVENT_HANDLER: `ElevatedButton.onPressed` (Roll Dice)

**FILE:** `lib/injection.config.dart` - Generated DI configuration.
  - CALLS: `GetItHelper`, `factory`, `lazySingleton`
  - REFERENCES: `AppRouter`, `LanguageBloc`, `SetStateCubit`, `InjectableModule`

**FILE:** `lib/injection.dart`
  - IMPORTS: `get_it`, `injectable`, `injection.config.dart`
  - FIELD: `getIt: GetIt`
  - **FUNCTION:** `configureInjection(String environment)`
    - ANNOTATION: `@InjectableInit`
    - CALLS: `getIt.init`

**FILE:** `lib/input_items/input_items.dart`
  - **CLASS:** `InputItems`
    - **METHOD:** `widgetImage(...)` -> `Widget`
    - **METHOD:** `widgetInputDBEntry(...)` -> `Widget`
    - **METHOD:** `widgetInputText(...)` -> `Widget`
    - **METHOD:** `widgetTextLink(...)` -> `Widget`
    - **METHOD:** `widgetButton(...)` -> `Widget`
    - **METHOD:** `widgetSizedBox(...)` -> `Widget`
    - **METHOD:** `widgetIntRadioButton(...)` -> `Widget`
    - **METHOD:** `widgetStringRadioButtonSplit(...)` -> `Widget`
    - **METHOD:** `widgetStringRadioButton(...)` -> `Widget`
    - **METHOD:** `getColor(...)` -> `Color`
    - **METHOD:** `widgetCheckbox(...)` -> `Widget`
    - **METHOD:** `widgetSlider(...)` -> `Widget`
    - **METHOD:** `widgetDropDownList(...)` -> `Widget`
    - **METHOD:** `widgetParagraph(...)` -> `Widget`

**FILE:** `lib/main.dart`
  - IMPORTS: `flutter/material.dart`, `flutter_bloc`, `yatzy/...`
  - CALLS: `WidgetsFlutterBinding.ensureInitialized`, `SharedPrefProvider.loadPrefs`, `configureInjection`, `runApp`
  - INSTANTIATES: `MultiBlocProvider`, `BlocProvider<LanguageBloc>`, `BlocProvider<SetStateCubit>`, `AppWidget`

**FILE:** `lib/models/board_cell.dart`
  - **CLASS:** `BoardCell`
    - FIELD: `index: int`, `label: String`, `value: int`, `fixed: bool`, `xPos: double`, `yPos: double`, `width: double`, `height: double`, `textColor: Color`, `backgroundColor: Color`, `hasFocus: bool`
    - **METHOD:** `constructor({...})`
    - **METHOD:** `setPosition(double, double, double, double)`
    - **METHOD:** `displayText` (getter)
    - **METHOD:** `isEmpty` (getter)
    - **METHOD:** `clear()`
    - **METHOD:** `setValue(int)`
    - **METHOD:** `fix()`
    - **METHOD:** `setFocus(bool)`
    - **METHOD:** `copyWith({...})` -> `BoardCell`

**FILE:** `lib/models/game.dart`
  - **CLASS:** `Game`
    - IMPORTS: `flutter/foundation.dart`, `./board_cell.dart`, `./player.dart`
    - FIELD: `gameId: int`, `gameType: String`, `maxPlayers: int`, `players: List<Player>`, `gameStarted: bool`, `gameFinished: bool`, `playerToMove: int`, `diceValues: List<int>`, `rollCount: int`, `maxRolls: int`, `bonusThreshold: int`, `bonusAmount: int`, `upperSectionEndIndex: int`, `cellLabels: List<String>`, `myPlayerIndex: int`, `boardAnimation: bool`, `onPlayerTurnChanged: VoidCallback?`, `onDiceValuesChanged: VoidCallback?`
    - **METHOD:** `constructor({...})`
    - **METHOD:** `isMyTurn` (getter)
    - **METHOD:** `canRoll` (getter)
    - **METHOD:** `currentPlayer` (getter)
    - **METHOD:** `myPlayer` (getter)
    - **METHOD:** `calculateScores()`
      - CALLS: `player.calculateScores`
    - **METHOD:** `advanceToNextPlayer()`
      - CALLS: `onPlayerTurnChanged?()`
    - **METHOD:** `setDiceValues(List<int>)`
      - CALLS: `List.from`, `onDiceValuesChanged?()`
    - **METHOD:** `resetDice()`
      - CALLS: `List.filled`, `onDiceValuesChanged?()`
    - **METHOD:** `selectCell(int)`
      - REFERENCES: `isMyTurn`, `players`, `playerToMove`, `myPlayerIndex`, `currentPlayer`, `cell.fixed`, `diceValues`
      - CALLS: `player.cells[cellIndex].fix`, `calculateScores`, `checkGameFinished`, `advanceToNextPlayer`
    - **METHOD:** `checkGameFinished()`
      - CALLS: `players.every`, `player.hasCompletedGame`
    - **FACTORY:** `fromJson(Map<String, dynamic>)`
      - CALLS: `_getCellLabelsForGameType`, `List.generate`, `BoardCell`, `Player`, `List<int>.from`, `List.filled`
      - INSTANTIATES: `Player`, `BoardCell`, `Game`
    - **METHOD:** `toJson()`
    - **STATIC METHOD:** `_getCellLabelsForGameType(String)`

**FILE:** `lib/models/player.dart`
  - **CLASS:** `Player`
    - IMPORTS: `./board_cell.dart`
    - FIELD: `id: String`, `username: String`, `isActive: bool`, `cells: List<BoardCell>`, `_totalScore: int`, `_upperSectionSum: int`
    - **METHOD:** `constructor({...})`
    - **METHOD:** `totalScore` (getter)
    - **METHOD:** `upperSectionSum` (getter)
    - **METHOD:** `calculateScores({...})`
    - **METHOD:** `clearUnfixedCells()`
      - CALLS: `cell.clear`
    - **METHOD:** `hasCompletedGame` (getter)
      - CALLS: `cells.every`
    - **FACTORY:** `fromJson(Map<String, dynamic>, List<String>)`
      - CALLS: `List.generate`, `BoardCell`
      - INSTANTIATES: `BoardCell`, `Player`
    - **METHOD:** `toJson()`
      - CALLS: `cells.map`, `toList`

**FILE:** `lib/router/router.dart`
  - IMPORTS: `auto_route`, `./router.gr.dart`
  - **CLASS:** `AppRouter`
    - EXTENDS: `$AppRouter`
    - ANNOTATION: `@AutoRouterConfig()`
    - **METHOD:** `defaultRouteType` (getter)
    - **METHOD:** `routes` (getter)
      - INSTANTIATES: `AutoRoute` (`SettingsView.page`, `ApplicationView.page`)

**FILE:** `lib/router/router.gr.dart` - Generated Router configuration.

**FILE:** `lib/services/game_service.dart`
  - **CLASS:** `GameService`
    - IMPORTS: `../models/game.dart`, `../models/board_cell.dart`, `./socket_service.dart`
    - FIELD: `socketService: SocketService`
    - FIELD: `_game: Game?`
    - FIELD: `onGameUpdated: Function(Game)?`
    - FIELD: `onError: Function(String)?`
    - **METHOD:** `constructor({...})`
      - REFERENCES: `socketService.onGameUpdate`
    - **METHOD:** `game` (getter)
    - **METHOD:** `_handleGameUpdate(Game)`
      - REFERENCES: `_game`, `onGameUpdated`
      - CALLS: `onGameUpdated?()`
    - **METHOD:** `createGame({...})`
      - CALLS: `socketService.createGame`
    - **METHOD:** `joinGame({...})`
      - CALLS: `socketService.joinGame`
    - **METHOD:** `rollDice({...})`
      - REFERENCES: `_game`, `_game.isMyTurn`, `_game.canRoll`
      - CALLS: `_reportError`, `List.filled`, `socketService.rollDice`
    - **METHOD:** `calculateScoreForCell(BoardCell, List<int>)`
      - REFERENCES: `_game`
      - CALLS: `List<int>.from`, `sort`, `toLowerCase`, `_calculatePairScore`, `_calculateTwoPairsScore`, `_calculateThreeOfAKindScore`, `_calculateFourOfAKindScore`, `_calculateFullHouseScore`, `_calculateSmallStraightScore`, `_calculateLargeStraightScore`, `fold`, `_calculateYatzyScore`
    - **METHOD:** `selectCell(int)`
      - REFERENCES: `_game`, `_game.isMyTurn`, `_game.myPlayer`, `cell.fixed`, `_game.diceValues`
      - CALLS: `_reportError`, `player.cells[cellIndex]`, `calculateScoreForCell`, `cell.value = ...`, `socketService.selectCell`
    - **METHOD:** `_reportError(String)`
      - REFERENCES: `onError`
      - CALLS: `onError?()`
    - **METHOD:** `_calculatePairScore(List<int>)`
    - **METHOD:** `_calculateTwoPairsScore(List<int>)`
    - **METHOD:** `_calculateThreeOfAKindScore(List<int>)`
    - **METHOD:** `_calculateFourOfAKindScore(List<int>)`
    - **METHOD:** `_calculateFullHouseScore(List<int>)`
    - **METHOD:** `_calculateSmallStraightScore(List<int>)`
    - **METHOD:** `_calculateLargeStraightScore(List<int>)`
    - **METHOD:** `_calculateYatzyScore(List<int>)`

**FILE:** `lib/services/http_service.dart`
  - **CLASS:** `HttpService`
    - IMPORTS: `dart:convert`, `package:http/http.dart`
    - FIELD: `baseUrl: String`
    - **METHOD:** `constructor({...})`
      - CALLS: `print`
    - **METHOD:** `getDB(String)`
      - CALLS: `print`, `Uri.parse`, `http.get`
      - HTTP_GET
    - **METHOD:** `postDB(String, Map)`
      - CALLS: `print`, `Uri.parse`, `jsonEncode`, `http.post`
      - HTTP_POST
    - **METHOD:** `updateDB(String, Map)`
      - CALLS: `print`, `Uri.parse`, `jsonEncode`, `http.post`
      - HTTP_POST (often PUT/PATCH, but uses POST here)
    - **METHOD:** `deleteDB(String)`
      - CALLS: `print`, `Uri.parse`, `http.delete`
      - HTTP_DELETE
    - **METHOD:** `deleteUser(String, String)`
      - CALLS: `print`, `Uri.parse`, `http.delete`
      - HTTP_DELETE
    - **METHOD:** `login(String, String)`
      - CALLS: `print`, `Uri.parse`, `jsonEncode`, `http.post`
      - HTTP_POST: To `/Login`
    - **METHOD:** `signup(String, String)`
      - CALLS: `print`, `Uri.parse`, `jsonEncode`, `http.post`
      - HTTP_POST: To `/Signup`

**FILE:** `lib/services/service_provider.dart`
  - **CLASS:** `ServiceProvider`
    - EXTENDS: `InheritedWidget`
    - IMPORTS: `package:flutter/material.dart`, `./socket_service.dart`, `./game_service.dart`
    - FIELD: `socketService: SocketService`
    - FIELD: `gameService: GameService`
    - **METHOD:** `constructor({...})`
    - **STATIC METHOD:** `of(BuildContext)` -> `ServiceProvider`
      - CALLS: `context.dependOnInheritedWidgetOfExactType`
    - **STATIC METHOD:** `initialize({...})` -> `Widget`
      - CALLS: `print`
      - INSTANTIATES: `SocketService`, `GameService`, `ServiceProvider`
    - **METHOD:** `updateShouldNotify(ServiceProvider)`

**FILE:** `lib/services/socket_service.dart`
  - **CLASS:** `SocketService`
    - IMPORTS: `flutter/...`, `socket_io_client`, `yatzy/...`, `dart:convert`
    - FIELD: `_instanceId: int`
    - FIELD: `context: BuildContext`
    - FIELD: `socket: io.Socket`
    - FIELD: `socketId: String`
    - FIELD: `isConnected: bool`
    - FIELD: `_handlersSetUp: bool`
    - FIELD: `game: Game?`
    - FIELD: `_connectingInProgress: bool`
    - FIELD: `_globalConnectionInProgress: bool` (static)
    - FIELD: `_connectionInitiator: String?` (static)
    - FIELD: `onGameUpdate: Function(Game)?`
    - FIELD: `onChatMessage: Function(Map<String, dynamic>)?`
    - **METHOD:** `constructor({...})`
      - CALLS: `print`, `StackTrace.current`
    - **METHOD:** `connect()`
      - REFERENCES: `_instanceId`, `_globalConnectionInProgress`, `_connectingInProgress`, `isConnected`, `_handlersSetUp`, `_connectionInitiator`, `localhost`, `isOnline`
      - CALLS: `print`, `StackTrace.current.toString`, `_setupEventHandlers`, `_clearEventHandlers`, `io.io`, `socket.connect`, `socket.onConnect`, `socket.onConnectError`
    - **METHOD:** `_clearEventHandlers()`
      - CALLS: `print`, `socket.off`
    - **METHOD:** `_setupEventHandlers()`
      - REFERENCES: `_handlersSetUp`, `socket`
      - CALLS: `print`, `socket.onConnect`, `_sendEcho`, `_requestId`, `_updateState`, `socket.onDisconnect`, `socket.onConnectError`, `socket.on('welcome')`, `socket.on('echo_response')`, `socket.on('onClientMsg', _handleClientMessage)`, `socket.on('onServerMsg', _handleServerMessage)`, `socket.on('userId', _handleUserId)`, `socket.on('gameUpdate', _handleGameUpdate)`, `socket.on('chatMessage', _handleChatMessage)`
      - HANDLES_SOCKET_EVENT: Various socket events.
    - **METHOD:** `_sendEcho()`
      - REFERENCES: `socket`
      - CALLS: `print`, `jsonEncode`, `socket.emit`
      - SENDS_SOCKET_EVENT: `socket.emit('echo', ...)`
    - **METHOD:** `_requestId()`
      - REFERENCES: `socket`
      - CALLS: `print`, `socket.emit`
      - SENDS_SOCKET_EVENT: `socket.emit('sendToServer', {'action': 'getId', ...})`
    - **METHOD:** `_handleUserId(dynamic data)`
      - REFERENCES: `socketId`
      - CALLS: `print`, `_updateState`
    - **METHOD:** `_handleClientMessage(dynamic data)`
      - REFERENCES: `app`
      - CALLS: `print`, `app.callbackOnClientMsg`, `_updateState`
    - **METHOD:** `_handleServerMessage(dynamic data)`
      - REFERENCES: `app`
      - CALLS: `print`, `app.callbackOnServerMsg`, `_updateState`
    - **METHOD:** `_handleGameUpdate(dynamic data)`
      - CALLS: `print`, `_processGameUpdate`, `_updateState`
    - **METHOD:** `_processGameUpdate(Map<String, dynamic> gameData)`
      - REFERENCES: `game`, `socketId`, `onGameUpdate`
      - CALLS: `Game.fromJson`, `game.players.length`, `onGameUpdate?()`
    - **METHOD:** `_handleChatMessage(dynamic data)`
      - REFERENCES: `onChatMessage`
      - CALLS: `print`, `onChatMessage?()`
    - **METHOD:** `createGame({...})`
      - REFERENCES: `isConnected`, `socket`
      - CALLS: `print`, `socket.emit`
      - SENDS_SOCKET_EVENT: `socket.emit('sendToServer', {'action': 'createGame', ...})`
    - **METHOD:** `joinGame({...})`
      - REFERENCES: `isConnected`, `socket`
      - CALLS: `print`, `socket.emit`
      - SENDS_SOCKET_EVENT: `socket.emit('sendToServer', {'action': 'joinGame', ...})`
    - **METHOD:** `rollDice({...})`
      - REFERENCES: `isConnected`, `game`, `socket`
      - CALLS: `print`, `socket.emit`
      - SENDS_SOCKET_EVENT: `socket.emit('sendToServer', {'action': 'rollDice', ...})`
    - **METHOD:** `selectCell({...})`
      - REFERENCES: `isConnected`, `game`, `socket`
      - CALLS: `print`, `socket.emit`
      - SENDS_SOCKET_EVENT: `socket.emit('sendToServer', {'action': 'selectCell', ...})`
    - **METHOD:** `sendChatMessage({...})`
      - REFERENCES: `isConnected`, `userName`, `socket`
      - CALLS: `print`, `socket.emit`
      - SENDS_SOCKET_EVENT: `socket.emit('sendToServer', {'action': 'chatMessage', ...})`
    - **METHOD:** `sendToClients(Map<String, dynamic> data)`
      - REFERENCES: `isConnected`, `socket`
      - CALLS: `print`, `socket.emit`
      - SENDS_SOCKET_EVENT: `socket.emit('sendToClients', ...)`
    - **METHOD:** `sendToServer(Map<String, dynamic> data)`
      - REFERENCES: `isConnected`, `socket`
      - CALLS: `print`, `jsonEncode`, `socket.emit`
      - SENDS_SOCKET_EVENT: `socket.emit('sendToServer', ...)`
    - **METHOD:** `disconnect()`
      - REFERENCES: `socket`, `isConnected`, `_handlersSetUp`, `_connectingInProgress`, `_globalConnectionInProgress`
      - CALLS: `print`, `_clearEventHandlers`, `socket.disconnect`, `_updateState`
    - **METHOD:** `_updateState()`
      - REFERENCES: `context`
      - CALLS: `context.read<SetStateCubit>().setState`, `print`

**FILE:** `lib/shared_preferences.dart`
  - **CLASS:** `SharedPrefProvider` (abstract)
    - IMPORTS: `dart:convert`, `package:shared_preferences/shared_preferences.dart`
    - FIELD: `prefs: SharedPreferences` (static)
    - **STATIC METHOD:** `loadPrefs()`
      - CALLS: `SharedPreferences.getInstance`
    - **STATIC METHOD:** `fetchPrefBool(String)` -> `bool`
      - CALLS: `prefs.getBool`
    - **STATIC METHOD:** `fetchPrefInt(String)` -> `int`
      - CALLS: `prefs.getInt`
    - **STATIC METHOD:** `fetchPrefString(String)` -> `String`
      - CALLS: `prefs.getString`
    - **STATIC METHOD:** `fetchPrefObject(String)` -> `dynamic`
      - CALLS: `prefs.getString`, `jsonDecode`, `jsonEncode`
    - **STATIC METHOD:** `setPrefBool(String, bool)` -> `Future<bool>`
      - CALLS: `prefs.setBool`
    - **STATIC METHOD:** `setPrefInt(String, int)` -> `Future<bool>`
      - CALLS: `prefs.setInt`
    - **STATIC METHOD:** `setPrefString(String, String)` -> `Future<bool>`
      - CALLS: `prefs.setString`
    - **STATIC METHOD:** `setPrefObject(String, dynamic)` -> `Future<bool>`
      - CALLS: `jsonEncode`, `prefs.setString`

**FILE:** `lib/startup.dart`
  - IMPORTS: `yatzy/...`
  - FIELD: `isOnline: bool`
  - FIELD: `localhost: String`
  - FIELD: `showUnityOptions: bool`
  - FIELD: `applicationStarted: bool`
  - FIELD: `userName: String`
  - FIELD: `userNames: List`
  - FIELD: `isTesting: bool`
  - FIELD: `isTutorial: bool`
  - FIELD: `mainPageLoaded: bool`
  - FIELD: `screenWidth: double`, `screenHeight: double`, `devicePixelRatio: double`
  - FIELD: `chosenLanguage: String`
  - FIELD: `standardLanguage: String`
  - FIELD: `differentLanguages: List<String>`
  - FIELD: `inputItems: InputItems`
  - FIELD: `topScore: TopScore`
  - FIELD: `app: Application`
  - FIELD: `chat: Chat`
  - FIELD: `dices: Dices`
  - INSTANTIATES: `InputItems`

**FILE:** `lib/states/bloc/language/language_bloc.dart`
  - **CLASS:** `LanguageBloc`
    - EXTENDS: `Bloc<LanguageEvent, String>`
    - IMPORTS: `injectable`, `../../shared_preferences.dart`, `flutter_bloc`, `./language_event.dart`
    - ANNOTATION: `@injectable`
    - **METHOD:** `constructor()`
      - CALLS: `super`, `SharedPrefProvider.fetchPrefString`, `on<LanguageChanged>(_languageChanged)`
    - FIELD: `key: String` (static)
    - **METHOD:** `_languageChanged(LanguageChanged, Emitter<String>)`
      - CALLS: `SharedPrefProvider.setPrefString`, `emit`

**FILE:** `lib/states/bloc/language/language_event.dart`
  - **CLASS:** `LanguageEvent` (abstract)
  - **CLASS:** `LanguageChanged`
    - EXTENDS: `LanguageEvent`
    - FIELD: `language: String`
    - **METHOD:** `constructor({language})`

**FILE:** `lib/states/cubit/state/state_cubit.dart`
  - **CLASS:** `SetStateCubit`
    - EXTENDS: `Cubit<int>`
    - IMPORTS: `flutter_bloc`
    - **METHOD:** `constructor()`
      - CALLS: `super(0)`
    - **METHOD:** `setState()`
      - CALLS: `emit`

**FILE:** `lib/top_score/languages_top_score.dart`
  - **MIXIN:** `LanguagesTopScore`
    - FIELD: `_getChosenLanguage: Function`
    - FIELD: `_standardLanguage: String`
    - FIELD: `_topScores: Map<String, String>`
    - **METHOD:** `topScores_` (getter)
      - CALLS: `getText`
    - **METHOD:** `languagesSetup(Function, String)`
    - **METHOD:** `getText(var textVariable)`
      - CALLS: `_getChosenLanguage()`

**FILE:** `lib/top_score/top_score.dart`
  - **CLASS:** `TopScore`
    - USES_MIXIN: `LanguagesTopScore`
    - IMPORTS: `dart:convert`, `flutter/animation.dart`, `../states/cubit/state/state_cubit.dart`, `../services/http_service.dart`, `./languages_top_score.dart`, `../startup.dart`
    - FIELD: `_getChosenLanguage: Function`
    - FIELD: `_standardLanguage: String`
    - FIELD: `animationController: AnimationController`
    - FIELD: `loopAnimation: Animation<double>`
    - FIELD: `_loadedGameTypes: Map<String, bool>`
    - FIELD: `topScores: List<dynamic>`
    - **METHOD:** `constructor({...})`
    - **METHOD:** `updateScoresFromData(List<Map<String, dynamic>>, SetStateCubit)`
      - CALLS: `print`, `cubit.setState`
    - **METHOD:** `getChosenLanguage()`
    - **METHOD:** `standardLanguage()`
    - **METHOD:** `loadTopScoreFromServer(String, SetStateCubit)`
      - CALLS: `print`, `HttpService`, `httpService.getDB`, `jsonDecode`, `cubit.setState`
      - INSTANTIATES: `HttpService`
      - HTTP_GET: To `/GetTopScores`
    - **METHOD:** `updateTopScore(String, int, String)`
      - CALLS: `print`, `HttpService`, `httpService.postDB`, `jsonDecode`
      - INSTANTIATES: `HttpService`
      - HTTP_POST: To `/UpdateTopScore`

**FILE:** `lib/top_score/widget_top_scores.dart`
  - **CLASS:** `WidgetTopScore` (StatefulWidget)
    - IMPORTS: `flutter/material.dart`, `../startup.dart`, `./languages_top_score.dart`
    - FIELD: `width: double`
    - FIELD: `height: double`
    - **METHOD:** `createState()` -> `_WidgetTopScoreState`
  - **CLASS:** `_WidgetTopScoreState`
    - USES_MIXIN: `TickerProviderStateMixin`, `LanguagesTopScore`
    - **METHOD:** `setupAnimation(TickerProvider)`
      - REFERENCES: `topScore.animationController`, `topScore.loopAnimation`
      - CALLS: `AnimationController`, `CurveTween`, `animate`, `topScore.animationController.addStatusListener`, `topScore.animationController.forward`
    - **METHOD:** `initState()`
      - CALLS: `super.initState`, `languagesSetup`, `topScore.getChosenLanguage`, `topScore.standardLanguage`, `setupAnimation`
    - **METHOD:** `dispose()`
      - CALLS: `topScore.animationController.dispose`, `super.dispose`
    - **METHOD:** `build(BuildContext context)`
      - REFERENCES: `widget.width`, `widget.height`, `topScores_`, `topScore.animationController`, `topScore.loopAnimation`, `topScore.topScores`
      - UI_BUILD: Implies UI structure
      - CALLS: `Positioned`, `Container`, `Padding`, `FittedBox`, `Text`, `AnimatedBuilder`, `BoxDecoration`, `Border.all`, `BorderRadius.circular`, `LinearGradient`, `Scrollbar`, `ListView.builder`, `Row`

**FILE:** `lib/utils/yatzy_mapping_client.dart`
  - FIELD: `_gameTypeMappingsClient: Map<String, List<String>>` (Internal)
  - **FUNCTION:** `_getBaseGameTypeClient(String)` (Internal)
  - **FUNCTION:** `_getBaseLabel(String)` (Internal)
  - **FUNCTION:** `getSelectionLabel(String, int)`
    - EXPORTS: Function `getSelectionLabel`
    - CALLS: `_getBaseGameTypeClient`, `print`
  - **FUNCTION:** `getSelectionIndex(String, String)`
    - EXPORTS: Function `getSelectionIndex`
    - CALLS: `_getBaseGameTypeClient`, `_getBaseLabel`, `labels.indexOf`, `print`

**FILE:** `lib/views/application_view.dart`
  - **CLASS:** `ApplicationView` (StatefulWidget)
    - IMPORTS: `auto_route`, `flutter/material.dart`, `flutter_bloc`, `../application/widget_application_scaffold.dart`, `../startup.dart`, `../states/cubit/state/state_cubit.dart`
    - ANNOTATION: `@RoutePage()`
    - **METHOD:** `createState()` -> `_ApplicationViewState`
  - **CLASS:** `_ApplicationViewState`
    - USES_MIXIN: `TickerProviderStateMixin`
    - **METHOD:** `myState()`
      - CALLS: `setState`
    - **METHOD:** `postFrameCallback(BuildContext context)`
      - REFERENCES: `mainPageLoaded`
      - CALLS: `myState`
    - **METHOD:** `initState()`
      - REFERENCES: `app.animation`, `app.nrPlayers`, `app.maxNrPlayers`, `app.maxTotalFields`
      - CALLS: `super.initState`, `WidgetsBinding.instance.addPostFrameCallback`, `app.animation.setupAnimation`
    - **METHOD:** `build(BuildContext context)`
      - REFERENCES: `app`
      - UI_BUILD: Builds the main application scaffold
      - CALLS: `BlocBuilder<SetStateCubit, int>`, `app.widgetScaffold`

**FILE:** `lib/views/settings_view.dart`
  - **CLASS:** `SettingsView` (StatefulWidget)
    - IMPORTS: `auto_route`, `flutter/material.dart`, `flutter_bloc`, `../application/widget_application_settings.dart`, `../startup.dart`, `../states/cubit/state/state_cubit.dart`
    - ANNOTATION: `@RoutePage()`
    - **METHOD:** `createState()` -> `_SettingsViewHomeState`
  - **CLASS:** `_SettingsViewHomeState`
    - USES_MIXIN: `TickerProviderStateMixin`
    - **METHOD:** `myState()`
      - CALLS: `setState`
    - **METHOD:** `initState()`
      - REFERENCES: `app.tabController`
      - CALLS: `super.initState`, `TabController`
    - **METHOD:** `build(BuildContext context)`
      - REFERENCES: `app`
      - UI_BUILD: Builds the settings screen scaffold
      - CALLS: `BlocBuilder<SetStateCubit, int>`, `app.widgetScaffoldSettings`

**FILE:** `lib/widgets/spectator_game_board.dart`
  - **CLASS:** `SpectatorGameBoard` (StatefulWidget)
    - IMPORTS: `flutter/material.dart`
    - FIELD: `gameData: Map<String, dynamic>`
    - **METHOD:** `createState()` -> `_SpectatorGameBoardState`
  - **CLASS:** `_SpectatorGameBoardState`
    - FIELD: `_horizontalScrollController: ScrollController`
    - FIELD: `_verticalScrollController: ScrollController`
    - **METHOD:** `dispose()`
      - CALLS: `_horizontalScrollController.dispose`, `_verticalScrollController.dispose`, `super.dispose`
    - **METHOD:** `build(BuildContext context)`
      - REFERENCES: `widget.gameData`
      - UI_BUILD: Builds the spectator board UI
      - CALLS: `print`, `List<String>.from`, `List<int>.from`, `Stack`, `Column`, `Container`, `BoxDecoration`, `Border`, `BorderSide`, `Text`, `SizedBox`, `Row`, `List.generate`, `Padding`, `getDiceFace`, `Expanded`, `RawScrollbar`, `SingleChildScrollView`, `buildScoreTable`, `Positioned.fill`, `Center`
      - INSTANTIATES: `TextStyle`, `Icon`, `Table`, `TableRow`, `TableCell`
    - **METHOD:** `getDiceFace(int value)` -> `Widget`
      - UI_BUILD: Helper for dice UI
      - INSTANTIATES: `Container`, `BoxDecoration`, `Column`, `Row`
    - **METHOD:** `buildScoreTable(List<String>)` -> `Widget`
      - REFERENCES: `widget.gameData`, `categories`
      - UI_BUILD: Builds the score table UI
      - CALLS: `print`, `Padding`, `Table`, `TableBorder.all`, `TableRow`, `BoxDecoration`, `TableCell`, `Text`
      - INSTANTIATES: `ScoreCategory`, `TextStyle`
  - **CLASS:** `ScoreCategory`
    - FIELD: `displayName: String`, `index: int`, `isHighlighted: bool`
    - **METHOD:** `constructor(String, int, bool)`

**FILE:** `unity/yatzy/Assets/FlutterUnityIntegration/Demo/GameManager.cs`
  - **CLASS:** `GameManager`
    - EXTENDS: `MonoBehaviour`
    - IMPORTS: `System`, `Collections`, `Collections.Generic`, `FlutterUnityIntegration`, `UnityEngine`
    - **METHOD:** `Start()`
      - CALLS: `gameObject.AddComponent<UnityMessageManager>()`
    - **METHOD:** `Update()`
    - **METHOD:** `HandleWebFnCall(String action)`
      - CALLS: `Time.timeScale = ...`, `Application.Unload()`, `Application.Quit()`

**FILE:** `unity/yatzy/Assets/FlutterUnityIntegration/Demo/Rotate.cs`
  - **CLASS:** `Rotate`
    - EXTENDS: `MonoBehaviour`, `IEventSystemHandler`
    - IMPORTS: `System`, `FlutterUnityIntegration`, `UnityEngine`, `UnityEngine.EventSystems`
    - FIELD: `RotateAmount: Vector3`
    - **METHOD:** `Start()`
      - INSTANTIATES: `Vector3`
    - **METHOD:** `Update()`
      - REFERENCES: `gameObject.transform`, `RotateAmount`, `Time.deltaTime`, `Input.touchCount`, `Input.GetTouch`, `Camera.main`
      - CALLS: `transform.Rotate`, `Input.GetTouch(...).phase.Equals`, `Camera.main.ScreenPointToRay`, `Physics.Raycast`, `UnityMessageManager.Instance.SendMessageToFlutter`
      - UNITY_SENDMESSAGE_FLUTTER: Via `UnityMessageManager`
    - **METHOD:** `SetRotationSpeed(String message)`
      - CALLS: `float.Parse`
      - INSTANTIATES: `Vector3`

**FILE:** `unity/yatzy/Assets/FlutterUnityIntegration/Demo/SceneLoader.cs`
  - **CLASS:** `SceneLoader`
    - EXTENDS: `MonoBehaviour`
    - IMPORTS: `Collections`, `Collections.Generic`, `FlutterUnityIntegration`, `UnityEngine`, `UnityEngine.SceneManagement`
    - **METHOD:** `Start()`
    - **METHOD:** `Update()`
    - **METHOD:** `LoadScene(int idx)`
      - CALLS: `Debug.Log`, `SceneManager.LoadScene`
    - **METHOD:** `MessengerFlutter()`
      - CALLS: `UnityMessageManager.Instance.SendMessageToFlutter`
      - UNITY_SENDMESSAGE_FLUTTER: Via `UnityMessageManager`
    - **METHOD:** `SwitchNative()`
      - CALLS: `UnityMessageManager.Instance.ShowHostMainWindow`
    - **METHOD:** `UnloadNative()`
      - CALLS: `UnityMessageManager.Instance.UnloadMainWindow`
    - **METHOD:** `QuitNative()`
      - CALLS: `UnityMessageManager.Instance.QuitUnityWindow`

**FILE:** `unity/yatzy/Assets/FlutterUnityIntegration/Editor/Build.cs` - Editor Script (Build related, less runtime dependency)
  - **CLASS:** `Build`
    - EXTENDS: `EditorWindow`
    - REFERENCES: UnityEditor APIs, System.IO, System.Linq, System.Text.RegularExpressions
    - Contains build logic for Android, iOS, WebGL, Windows.
    - CALLS: `ModifyAndroidGradle`, `SetupAndroidProject`, `SetupAndroidProjectForPlugin`, `BuildIOS`, `SetupIOSProjectForPlugin`, `BuildWebGL`, `ModifyWebGLExport`, `BuildWindowsOS`, `ExportAddressables`.

**FILE:** `unity/yatzy/Assets/FlutterUnityIntegration/Editor/SweetShellHelper.cs` - Editor Script (Build related)
  - **CLASS:** `SweetShellHelper` (static)
    - **METHOD:** `Bash(this string cmd, string fileName)` (extension method)
      - CALLS: `Process.Start`, `TaskCompletionSource`

**FILE:** `unity/yatzy/Assets/FlutterUnityIntegration/Editor/XCodePostBuild.cs` - Editor Script (iOS Build related)
  - **CLASS:** `XcodePostBuild` (static)
    - REFERENCES: UnityEditor APIs, UnityEditor.iOS.Xcode, System.IO
    - Contains iOS post-build processing logic.

**FILE:** `unity/yatzy/Assets/FlutterUnityIntegration/NativeAPI.cs`
  - **CLASS:** `NativeAPI`
    - IMPORTS: `System.Runtime.InteropServices`, `UnityEngine.SceneManagement`, `UnityEngine`, `System`
    - **STATIC METHOD:** `OnUnityMessage(string)` (iOS Internal Import)
    - **STATIC METHOD:** `OnUnitySceneLoaded(string, int, bool, bool)` (iOS Internal Import)
    - **STATIC METHOD:** `OnUnityMessageWeb(string)` (WebGL Internal Import)
    - **STATIC METHOD:** `OnUnitySceneLoadedWeb(string, int, bool, bool)` (WebGL Internal Import)
    - **STATIC METHOD:** `OnSceneLoaded(Scene scene, LoadSceneMode mode)`
      - CALLS: `AndroidJavaClass`, `jc.CallStatic("onUnitySceneLoaded", ...)` (Android)
      - CALLS: `OnUnitySceneLoadedWeb(...)` (WebGL)
      - CALLS: `OnUnitySceneLoaded(...)` (iOS)
      - CALLS: `Debug.Log`
    - **STATIC METHOD:** `SendMessageToFlutter(string message)`
      - CALLS: `AndroidJavaClass`, `jc.CallStatic("onUnityMessage", ...)` (Android)
      - CALLS: `OnUnityMessageWeb(...)` (WebGL)
      - CALLS: `OnUnityMessage(...)` (iOS)
      - CALLS: `Debug.Log`
      - UNITY_SENDMESSAGE_FLUTTER: Platform specific calls.
    - **STATIC METHOD:** `ShowHostMainWindow()`
      - CALLS: `AndroidJavaClass`, `jc.GetStatic<AndroidJavaObject>`, `overrideActivity.Call("showMainActivity")` (Android)
      - CALLS: `Debug.Log`
    - **STATIC METHOD:** `UnloadMainWindow()`
      - CALLS: `AndroidJavaClass`, `jc.GetStatic<AndroidJavaObject>`, `overrideActivity.Call("unloadPlayer")` (Android)
      - CALLS: `Debug.Log`
    - **STATIC METHOD:** `QuitUnityWindow()`
      - CALLS: `AndroidJavaClass`, `jc.GetStatic<AndroidJavaObject>`, `overrideActivity.Call("quitPlayer")` (Android)
      - CALLS: `Debug.Log`

**FILE:** `unity/yatzy/Assets/FlutterUnityIntegration/SingletonMonoBehaviour.cs`
  - **CLASS:** `SingletonMonoBehaviour<T>` (abstract)
    - EXTENDS: `MonoBehaviour`
    - IMPORTS: `System`, `UnityEngine`
    - FIELD: `LazyInstance: Lazy<T>` (static)
    - **PROPERTY:** `Instance` (static getter)
    - **STATIC METHOD:** `CreateSingleton()`
      - INSTANTIATES: `GameObject`, `T` (via AddComponent)
      - CALLS: `DontDestroyOnLoad`

**FILE:** `unity/yatzy/Assets/FlutterUnityIntegration/UnityMessageManager.cs`
  - **CLASS:** `MessageHandler`
    - FIELD: `id: int`, `seq: string`, `name: String`, `data: JToken`
    - **STATIC METHOD:** `Deserialize(string)` -> `MessageHandler`
      - CALLS: `JObject.Parse`, `m.GetValue(...).Value<T>()`
      - INSTANTIATES: `MessageHandler`
    - **METHOD:** `getData<T>()` -> `T`
    - **METHOD:** `constructor(...)`
    - **METHOD:** `send(object data)`
      - CALLS: `JObject.FromObject`, `UnityMessageManager.Instance.SendMessageToFlutter`, `o.ToString()`
      - UNITY_SENDMESSAGE_FLUTTER: Sends response back to Flutter.
  - **CLASS:** `UnityMessage`
    - FIELD: `name: String`, `data: JObject`, `callBack: Action<object>`
  - **CLASS:** `UnityMessageManager`
    - EXTENDS: `SingletonMonoBehaviour<UnityMessageManager>`
    - IMPORTS: `System`, `Collections.Generic`, `Newtonsoft.Json.Linq`, `UnityEngine`, `UnityEngine.SceneManagement`
    - FIELD: `MessagePrefix: string` (const)
    - FIELD: `ID: int` (static)
    - FIELD: `OnMessage: MessageDelegate`
    - FIELD: `OnFlutterMessage: MessageHandlerDelegate`
    - FIELD: `waitCallbackMessageMap: Dictionary<int, UnityMessage>`
    - **STATIC METHOD:** `generateId()`
    - **METHOD:** `Start()`
      - REFERENCES: `SceneManager.sceneLoaded`
    - **METHOD:** `OnSceneLoaded(Scene scene, LoadSceneMode mode)`
      - CALLS: `NativeAPI.OnSceneLoaded`
    - **METHOD:** `ShowHostMainWindow()`
      - CALLS: `NativeAPI.ShowHostMainWindow`
    - **METHOD:** `UnloadMainWindow()`
      - CALLS: `NativeAPI.UnloadMainWindow`
    - **METHOD:** `QuitUnityWindow()`
      - CALLS: `NativeAPI.QuitUnityWindow`
    - **METHOD:** `SendMessageToFlutter(string message)`
      - CALLS: `NativeAPI.SendMessageToFlutter`
      - UNITY_SENDMESSAGE_FLUTTER: Via NativeAPI.
    - **METHOD:** `SendMessageToFlutter(UnityMessage message)`
      - CALLS: `generateId`, `waitCallbackMessageMap.Add`, `JObject.FromObject`, `UnityMessageManager.Instance.SendMessageToFlutter`, `o.ToString()`
      - UNITY_SENDMESSAGE_FLUTTER: Via string overload.
    - **METHOD:** `onMessage(string message)` (Handles internal Unity messages?)
      - CALLS: `OnMessage?.Invoke`
    - **METHOD:** `onFlutterMessage(string message)` (Handles messages from Flutter)
      - UNITY_FLUTTERMESSAGE_HANDLER: Entry point for Flutter messages.
      - CALLS: `message.StartsWith`, `message.Replace`, `MessageHandler.Deserialize`, `waitCallbackMessageMap.TryGetValue`, `waitCallbackMessageMap.Remove`, `m.callBack?.Invoke`, `handler.getData<object>()`, `OnFlutterMessage?.Invoke`

**FILE:** `unity/yatzy/Assets/Scripts/CircularMotionScript.cs`
  - **CLASS:** `CircularMotionScript`
    - EXTENDS: `MonoBehaviour`
    - IMPORTS: `Collections`, `Collections.Generic`, `UnityEngine`
    - FIELD: `timeCounter: float`, `myColor: Color`, `lightMotion: bool`, `originalPosition: Vector3`, `speed: float`
    - **METHOD:** `Start()`
      - INSTANTIATES: `Color`
    - **METHOD:** `Update()`
      - REFERENCES: `lightMotion`, `timeCounter`, `Time.deltaTime`, `speed`, `originalPosition`, `transform.position`, `myColor`
      - CALLS: `Mathf.Cos`, `Mathf.Sin`, `GameObject.Find`, `GetComponent<Renderer>`, `material.color = ...`
      - INSTANTIATES: `Vector3`

**FILE:** `unity/yatzy/Assets/Scripts/Connection.cs` (Seems unused or legacy based on `UnityMessageManager`)
  - **CLASS:** `Connection`
    - EXTENDS: `MonoBehaviour`
    - IMPORTS: `System`, `Collections`, `Collections.Concurrent`, `Collections.Generic`, `UnityEngine`, `NativeWebSocket`
    - FIELD: `websocket: WebSocket`
    - FIELD: `_actions: ConcurrentQueue<Action>`
    - FIELD: `isOnline: bool`
    - **METHOD:** `Start()`
      - INSTANTIATES: `WebSocket`
      - CALLS: `websocket.Connect`
      - HANDLES_SOCKET_EVENT: `websocket.OnOpen`, `websocket.OnError`, `websocket.OnClose`, `websocket.OnMessage` -> `_actions.Enqueue`
    - **METHOD:** `Update()`
      - CALLS: `_actions.TryDequeue`, `action?.Invoke`, `websocket.DispatchMessageQueue`
    - **METHOD:** `OnApplicationQuit()`
      - CALLS: `websocket.Close`

**FILE:** `unity/yatzy/Assets/Scripts/DiceCheckZoneScript.cs`
  - **CLASS:** `DiceCheckZoneScript`
    - EXTENDS: `MonoBehaviour`
    - IMPORTS: `Collections`, `Collections.Generic`, `UnityEngine`
    - FIELD: `vel: Vector3`, `angVel: Vector3`
    - **METHOD:** `OnTriggerStay(Collider col)`
      - CALLS: `col.gameObject.GetComponentInParent<DiceScript>()`, `GetDiceNumber`, `GetComponentInParent<Rigidbody>()`, `linearVelocity`, `angularVelocity`, `rotation.eulerAngles`, `Mathf.Abs`, `SetDiceNumber`

**FILE:** `unity/yatzy/Assets/Scripts/DiceScript.cs`
  - **CLASS:** `DiceScript`
    - EXTENDS: `MonoBehaviour`
    - IMPORTS: `Collections`, `Collections.Generic`, `UnityEngine`
    - FIELD: `diceNumber: int`, `originalPosition: Vector3`, `cupPosition: Vector3`, `startPosition: Vector3`, `respondsToClicks: bool`, `isGreen: bool`, `isBlue: bool`, `isActive: bool`
    - **METHOD:** `Awake()`
      - REFERENCES: `transform.position`
    - **METHOD:** `Update()`
    - **METHOD:** `OnMouseDown()`
      - REFERENCES: `respondsToClicks`, `isGreen`, `transform.position`, `originalPosition`, `transform.name`, `transform.rotation.eulerAngles`
      - CALLS: `GameObject.Find`, `GetComponent<DiceScript>()`, `Replace`, `Quaternion.Euler`
    - **METHOD:** `GetDiceNumber()`
    - **METHOD:** `SetDiceNumber(int number)`

**FILE:** `unity/yatzy/Assets/Scripts/GameManagerScript.cs`
  - **CLASS:** `GameManagerScript`
    - EXTENDS: `MonoBehaviour`
    - IMPORTS: `System`, `Collections`, `Collections.Generic`, `UnityEngine`, `Newtonsoft.Json`, `Newtonsoft.Json.Linq`, `FlutterUnityIntegration`, `Random=UnityEngine.Random`
    - **CLASS:** `jsonCommunicator` (nested)
      - FIELD: `actionUnity: string`, `diceResult: List<int>`
      - **METHOD:** `constructor(string, List<int>)`
    - FIELD: `throwDices: bool`, `throwActive: bool`, `go: GameObject[]`, `goG: GameObject[]`, `goB: GameObject[]`, `goSnow: GameObject`, `goSnowActive: bool`, `diceResult: List<int>` (static), `rb: Rigidbody` (static), `c: float`, `nrDices: int`, `nrThrows: int`, `nrThrowsRemaining: int`, `animatorCup: Animator`, `animatorCat: Animator`, `animatorDog: Animator`, `timeFromThrownDices: float`, `rethrow: bool`, `dicesActive: bool`
    - **METHOD:** `Start()`
      - CALLS: `Debug.Log`, `SystemInfo.graphicsDeviceType`, `gameObject.AddComponent<UnityMessageManager>`, `GameObject.Find`, `InitDices`, `GetComponent<Animator>`, `animatorCat.Play`, `animatorDog.Play`
      - INSTANTIATES: `GameObject[]`, `List<int>`, `Vector3`
    - **METHOD:** `InitDices(bool initRotation = true)`
      - REFERENCES: `maxNrDices`, `go`, `goG`, `goB`, `nrDices`, `diceResult`
      - CALLS: `GetComponent<DiceScript>()`, `GameObject.Find`, `transform.position`, `Quaternion.Euler`
    - **METHOD:** `SetDices(List<int> dices)`
      - REFERENCES: `go`
      - CALLS: `Quaternion.Euler`
    - **METHOD:** `Update()`
      - REFERENCES: `nrDices`, `diceResult`, `go`, `dicesActive`, `rethrow`, `goB`, `nrThrowsRemaining`, `timeFromThrownDices`, `throwDices`, `animatorCup`, `Time.time`
      - CALLS: `GetComponent<DiceScript>().GetDiceNumber`, `GetComponent<DiceScript>().isActive`, `GetComponentInParent<Rigidbody>()`, `GetComponent<DiceScript>().respondsToClicks = true`, `JsonConvert.SerializeObject`, `UnityMessageManager.Instance.SendMessageToFlutter`, `InitDices`, `GetComponent<Rigidbody>()`, `Random.Range`, `GetComponent<DiceScript>().SetDiceNumber`, `animatorCup.Play`
      - INSTANTIATES: `jsonCommunicator`, `Vector3`
      - UNITY_SENDMESSAGE_FLUTTER: Via `UnityMessageManager`
    - **METHOD:** `SetNrDices(string strNrDices)`
      - REFERENCES: `nrDices`
      - CALLS: `int.Parse`, `InitDices`
    - **METHOD:** `flutterMessage(String json)`
      - UNITY_FLUTTERMESSAGE_HANDLER: Handles messages from Flutter.
      - REFERENCES: `throwDices`, `throwActive`, `nrDices`, `nrThrows`, `nrThrowsRemaining`, `goSnow`, `goSnowActive`
      - CALLS: `Debug.Log`, `JObject.Parse`, `UnityMessageManager.Instance.SendMessageToFlutter`, `InitDices`, `GameObject.Find`, `GetComponent<CircularMotionScript>()`, `GetComponent<ParticleSystem>()`, `(int)o[...]`, `(float)o[...]`, `(bool)o[...]`, `(JArray)o[...]`, `SetDices`, `goSnow.SetActive`
      - INSTANTIATES: `GameObject`, `Color`, `List<int>`

**FILE:** `unity/yatzy/Assets/Scripts/ThrowDices.cs`
  - **CLASS:** `ThrowDices`
    - EXTENDS: `MonoBehaviour`
    - IMPORTS: `Collections`, `Collections.Generic`, `UnityEngine`
    - FIELD: `gameManager: GameObject`
    - **METHOD:** `Awake()`
      - CALLS: `GameObject.Find`
    - **METHOD:** `OnMouseDown()`
      - REFERENCES: `gameManager`
      - CALLS: `Debug.Log`, `GetComponent<GameManagerScript>()`
    - **METHOD:** `Update()`

**FILE:** `unity/yatzy/Assets/WebSocket/WebSocket.cs` (Seems unused or legacy based on `UnityMessageManager`)
  - **CLASS:** `MainThreadUtil`
  - **CLASS:** `WaitForUpdate`
  - **NAMESPACE:** `NativeWebSocket`
    - DELEGATE: `WebSocketOpenEventHandler`, `WebSocketMessageEventHandler`, `WebSocketErrorEventHandler`, `WebSocketCloseEventHandler`
    - ENUM: `WebSocketCloseCode`, `WebSocketState`
    - INTERFACE: `IWebSocket`
    - **CLASS:** `WebSocketHelpers` (static)
      - **METHOD:** `ParseCloseCodeEnum(int)`
      - **METHOD:** `GetErrorMessageFromCode(int, Exception)` -> `WebSocketException`
    - **CLASS:** `WebSocketException` (extends Exception)
    - **CLASS:** `WebSocketUnexpectedException` (extends WebSocketException)
    - **CLASS:** `WebSocketInvalidArgumentException` (extends WebSocketException)
    - **CLASS:** `WebSocketInvalidStateException` (extends WebSocketException)
    - **CLASS:** `WaitForBackgroundThread`
    - **CLASS:** `WebSocket` (implements IWebSocket)
      - Platform specific implementations (#if UNITY_WEBGL / #else)
      - Handles WebSocket connection, sending, receiving.
      - **WEBGL:** Uses DllImport to JavaScript functions.
      - **OTHER:** Uses `System.Net.WebSockets.ClientWebSocket`.
    - **CLASS:** `WebSocketFactory` (static)
      - Platform specific implementations (#if UNITY_WEBGL / #else)
      - **WEBGL:** Manages JS WebSocket instances via DllImport and callbacks.
      - **OTHER:** Provides `CreateInstance`.


```

This file is a merged representation of a subset of the codebase, containing specifically included files and files not matching ignore patterns, combined into a single document by Repomix.

<directory_structure>
backend/src/controllers/ChatController.ts
backend/src/controllers/GameController.ts
backend/src/controllers/PlayerController.ts
backend/src/db.ts
backend/src/models/BoardCell.ts
backend/src/models/Dice.ts
backend/src/models/Game.ts
backend/src/models/Player.ts
backend/src/routes/getLogRoute.ts
backend/src/routes/getTopScores.ts
backend/src/routes/index.ts
backend/src/routes/logInRoute.ts
backend/src/routes/logRoute.ts
backend/src/routes/signUpRoute.ts
backend/src/routes/spectateGameRoute.ts
backend/src/routes/updateTopScore.ts
backend/src/server.ts
backend/src/services/GameLogService.ts
backend/src/services/GameService.ts
backend/src/services/TopScoreService.ts
backend/src/utils/gameConfig.ts
backend/src/utils/index.ts
backend/src/utils/yatzyMapping.ts
lib/application/animations_application.dart
lib/application/application_functions_internal.dart
lib/application/application.dart
lib/application/communication_application.dart
lib/application/languages_application.dart
lib/application/widget_application_scaffold.dart
lib/application/widget_application_settings.dart
lib/application/widget_application.dart
lib/chat/chat.dart
lib/chat/languages_chat.dart
lib/chat/widget_chat.dart
lib/core/app_widget.dart
lib/core/injectable_modules.dart
lib/dices/dices.dart
lib/dices/languages_dices.dart
lib/dices/unity_communication.dart
lib/dices/unity_message.dart
lib/dices/widget_dices.dart
lib/injection.config.dart
lib/injection.dart
lib/input_items/input_items.dart
lib/main.dart
lib/models/board_cell.dart
lib/models/game.dart
lib/models/player.dart
lib/router/router.dart
lib/router/router.gr.dart
lib/services/game_service.dart
lib/services/http_service.dart
lib/services/service_provider.dart
lib/services/socket_service.dart
lib/shared_preferences.dart
lib/startup.dart
lib/states/bloc/language/language_bloc.dart
lib/states/bloc/language/language_event.dart
lib/states/cubit/state/state_cubit.dart
lib/top_score/languages_top_score.dart
lib/top_score/top_score.dart
lib/top_score/widget_top_scores.dart
lib/utils/yatzy_mapping_client.dart
lib/views/application_view.dart
lib/views/settings_view.dart
lib/widgets/spectator_game_board.dart
unity/yatzy/Assets/FlutterUnityIntegration/Demo/GameManager.cs
unity/yatzy/Assets/FlutterUnityIntegration/Demo/Rotate.cs
unity/yatzy/Assets/FlutterUnityIntegration/Demo/SceneLoader.cs
unity/yatzy/Assets/FlutterUnityIntegration/Editor/Build.cs
unity/yatzy/Assets/FlutterUnityIntegration/Editor/SweetShellHelper.cs
unity/yatzy/Assets/FlutterUnityIntegration/Editor/XCodePostBuild.cs
unity/yatzy/Assets/FlutterUnityIntegration/NativeAPI.cs
unity/yatzy/Assets/FlutterUnityIntegration/SingletonMonoBehaviour.cs
unity/yatzy/Assets/FlutterUnityIntegration/UnityMessageManager.cs
unity/yatzy/Assets/Scripts/CircularMotionScript.cs
unity/yatzy/Assets/Scripts/Connection.cs
unity/yatzy/Assets/Scripts/DiceCheckZoneScript.cs
unity/yatzy/Assets/Scripts/DiceScript.cs
unity/yatzy/Assets/Scripts/GameManagerScript.cs
unity/yatzy/Assets/Scripts/ThrowDices.cs
unity/yatzy/Assets/WebSocket/WebSocket.cs
</directory_structure>

<files>
This section contains the contents of the repository's files.

<file path="backend/src/controllers/ChatController.ts">
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
</file>

<file path="backend/src/controllers/GameController.ts">
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
    const allowedTypes = ['Ordinary', 'Maxi']; // Only allow these
        if (!allowedTypes.includes(gameType)) {
             console.warn(`[GameController] Invalid gameType requested: ${gameType}. Rejecting.`);
             socket.emit('onServerMsg', { action: 'error', message: `Invalid game type: ${gameType}. Allowed types are Ordinary, Maxi.` });
             return;
        }
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
</file>

<file path="backend/src/controllers/PlayerController.ts">
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
</file>

<file path="backend/src/db.ts">
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
</file>

<file path="backend/src/models/BoardCell.ts">
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
    this.value = label.toLowerCase() === 'sum' ||  label.toLowerCase() === 'total' ? 0 : -1; // Default to -1 (empty)
    this.fixed = label.toLowerCase() === 'sum' || label.toLowerCase().includes('bonus') || label.toLowerCase() === 'total';
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
</file>

<file path="backend/src/models/Dice.ts">
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
</file>

<file path="backend/src/models/Game.ts">
// backend/src/models/Game.ts
import { Player, PlayerFactory } from './Player';
import { v4 as uuidv4 } from 'uuid';
import { getSelectionIndex } from '../utils/yatzyMapping'; // Import for applySelection
import { GameConfig, getBaseGameType } from '../utils/gameConfig';
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
    const config = GameConfig[getBaseGameType(gameType)];
    const diceCount = config ? config.diceCount : 5; // Use config
    this.diceValues = new Array(diceCount).fill(0); // Initialize with correct number of zeros
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
                 if (this.maxPlayers > 1 && activePlayersCount < 1) {
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
    // --- CORRECTED LOGIC ---
        if (!values) {
          console.error('[Game.setDiceValues] Invalid dice values received: null or undefined');
          // Fallback: Create zeros based on game config
          const config = GameConfig[getBaseGameType(this.gameType)];
          const diceCount = config ? config.diceCount : 5; // Default 5 if config missing
          this.diceValues = new Array(diceCount).fill(0);
          console.log(`[Game.setDiceValues] Setting dice to ${diceCount} zeros due to invalid input.`);
        } else {
           const config = GameConfig[getBaseGameType(this.gameType)];
           const expectedDiceCount = config ? config.diceCount : values.length; // Use actual length if config fails

           if (values.length !== expectedDiceCount) {
               // This might happen if client sends wrong number, or if config is wrong. Log it.
               console.warn(`[Game.setDiceValues] Dice length mismatch. Expected ${expectedDiceCount} for type ${this.gameType}, got ${values.length}. Storing received values.`);
               // Decide: Store anyway? Or fallback to zeros? Let's store received for now.
               this.diceValues = [...values];
           } else {
               // Length matches expected count, store normally
               this.diceValues = [...values]; // Copy the received values
               // console.log(`[Game.setDiceValues] Stored dice: [${this.diceValues.join(', ')}]`); // Optional log
           }
        }

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
</file>

<file path="backend/src/models/Player.ts">
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
</file>

<file path="backend/src/routes/getLogRoute.ts">
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
</file>

<file path="backend/src/routes/getTopScores.ts">
//import jwt from "jsonwebtoken";
import { getDbConnection } from "../db";

export const getTopScores = {
  path: "/GetTopScores",
  method: "get",
  handler: async (req, res) => {
    const db = getDbConnection("top-scores");
    var results;
    try {
        // --- MODIFIED: Validate game type ---
        const requestedType = req.query.type as string;
        const allowedTypes = ['Ordinary', 'Maxi']; // Only allow these
        if (!allowedTypes.includes(requestedType)) {
            console.warn(`[getTopScores Route] Invalid game type requested: ${requestedType}`);
            return res.status(400).json({ message: `Invalid game type: ${requestedType}` });
        }
        // --- End Modification ---

        // Simplified switch or use if/else
        let collectionName = '';
        if (requestedType === 'Ordinary') {
            collectionName = 'ordinary';
        } else if (requestedType === 'Maxi') {
            collectionName = 'maxi';
        }
        // No else needed due to validation above

        console.log(`getting ${collectionName} game topscores`);
        results = await db
            .collection(collectionName)
            .find({}, { projection: { _id: 0 } })
            .sort({ score: -1 })
            .toArray();

        res.status(200).json(results);
    } catch (e) {
      console.log(e);
      res.sendStatus(500);
    }
  },
};
</file>

<file path="backend/src/routes/index.ts">
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
</file>

<file path="backend/src/routes/logInRoute.ts">
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
</file>

<file path="backend/src/routes/logRoute.ts">
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
</file>

<file path="backend/src/routes/signUpRoute.ts">
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
</file>

<file path="backend/src/routes/spectateGameRoute.ts">
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
</file>

<file path="backend/src/routes/updateTopScore.ts">
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

      // --- MODIFIED: Validate game type ---
      const requestedType = req.body.type as string;
      const allowedTypes = ['Ordinary', 'Maxi']; // Only allow these
      if (!allowedTypes.includes(requestedType)) {
          console.warn(`[updateTopScore Route] Invalid game type requested: ${requestedType}`);
          return res.status(400).json({ message: `Invalid game type: ${requestedType}` });
      }
      // --- End Modification ---

    // Simplified logic
    let collectionName = '';
    if (requestedType === 'Ordinary') {
        collectionName = 'ordinary';
    } else if (requestedType === 'Maxi') {
        collectionName = 'maxi';
    }
    // No else needed due to validation above

    const collection = db.collection(collectionName);

    await collection.insertOne({ name: req.body.name, score: req.body.score });
    results = await collection
        .find({}, { projection: { _id: 0 } })
        .sort({ score: -1 })
        .toArray();

      // Broadcasting handled by TopScoreService ideally
      res.status(200).json(results);
    } catch (e) {
      console.log(e);
      res.sendStatus(500);
    }
  },
};
</file>

<file path="backend/src/server.ts">
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

app.use(cors({
  origin: '*', // This allows all origins
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

const httpServer = createServer(app);

let isOnline: boolean = true;

const localFlutterDir: string = "C:/Users/J/StudioProjects/flutter_system";
const localReactDir: string = "C:/Users/J/Desktop/proj";

console.log("Starting Server...");

if (isOnline) {
  //app.use("/new", express.static(path.join(__dirname, "web")));
  // Middleware to log requests to UnityLibrary
  app.use((req, res, next) => {
    console.log(`[UNITY STATIC] ${req.url}`);
    next();
  });
  app.use(express.static(path.join(__dirname, "web")));

} else {
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
  
   // ***** FIX: Send the current game list to the newly connected player *****
   try {
    console.log(`🔌 Sending current game list to newly connected player ${socket.id}`);
    gameService.broadcastGameListToPlayer(socket.id); // <-- ADD THIS LINE
  } catch (error) {
    console.error(`❌ Error sending game list to player ${socket.id}:`, error);
  }
  // **********************************************************************
  
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

app.get("/", (req, res) => {
  if (isOnline) {
    res.sendFile(path.join(__dirname + "/web/index.html"));
  } else {
    res.sendFile(localFlutterDir + "/build/web/index.html");
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
</file>

<file path="backend/src/services/GameLogService.ts">
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
</file>

<file path="backend/src/services/GameService.ts">
// backend/src/services/GameService.ts

import { Game } from '../models/Game';
import { Player, PlayerFactory } from '../models/Player';
import { Server, Socket } from 'socket.io'; // Import Socket type
import { GameLogService, GameMove } from './GameLogService'; // <-- Import log service and types
import { TopScoreService } from './TopScoreService'; // <-- Import TopScoreService
import { getSelectionLabel } from '../utils/yatzyMapping'; // <-- Import mapping utility
import { GameConfig, getBaseGameType } from '../utils/gameConfig';

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
    // --- Recalculate ALL players' derived scores before sending update ---
    // Ensures Sum/Bonus/Total are always up-to-date in the sent payload.
    // Potential scores are handled by calculatePotentialScores/clearPotentialScores calls elsewhere.
    game.players.forEach(p => {
        if (p) { // Calculate even for inactive players so spectators see correct final sums
             p.calculateDerivedScores(); // Recalculates Sum/Bonus/Total based on fixed cells
        }
    });
    // --- End Recalculation ---

    const gameData = game.toJSON(); // Serialize the final state
    gameData.action = 'onGameUpdate';

    // console.log(`🎮 Notifying players about game ${game.id} update`); // Less verbose log

    // Send to all players (active or not) and spectators
    for (const player of game.players) {
        if (player?.id) {
            this.io.to(player.id).emit('onServerMsg', gameData);
        }
    }
    const gameSpectators = this.spectators.get(game.id);
    if (gameSpectators) {
       for (const spectatorId of gameSpectators) {
           this.io.to(spectatorId).emit('onServerMsg', gameData);
       }
    }
  }
  // notifyGameUpdate(game: Game): void {
  //   // --- Recalculate ALL players' derived scores before sending update ---
  //       // Ensures Sum/Bonus/Total are always up-to-date in the sent payload.
  //       // Potential scores are handled by calculatePotentialScores/clearPotentialScores calls elsewhere.
  //       game.players.forEach(p => {
  //         if (p) { // Calculate even for inactive players so spectators see correct final sums
  //              p.calculateDerivedScores(); // Recalculates Sum/Bonus/Total based on fixed cells
  //         }
  //     });
  //     // --- End Recalculation ---
  //   const gameData = game.toJSON();

  //   // Determine action based on game state
  //   // gameData.action = game.gameStarted ? 'onGameStart' : 'onGameUpdate'; // Logic seems reversed, usually update after start? Let's use onGameUpdate generally after start.
  //   // Let's stick to onGameUpdate for general updates after the initial start signal
  //   gameData.action = 'onGameUpdate';

  //   console.log(`🎮 Notifying players about game ${game.id} update, action: ${gameData.action}`);

  //   for (let i = 0; i < game.players.length; i++) {
  //     const player = game.players[i];
  //     // Send update to active players
  //     if (player?.isActive && player.id) { // Add null check
  //       console.log(`🎮 Sending ${gameData.action} to player ${i} (${player.id})`);
  //       this.io.to(player.id).emit('onServerMsg', gameData);
  //     }
  //   }

  //   // Notify spectators
  //   const gameSpectators = this.spectators.get(game.id);
  //   if (gameSpectators && gameSpectators.size > 0) {
  //     console.log(`[Spectator] Notifying ${gameSpectators.size} spectators of game ${game.id} update`);
  //     for (const spectatorId of gameSpectators) {
  //       this.io.to(spectatorId).emit('onServerMsg', gameData);
  //     }
  //   }
  // }

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

     // Clear potential scores for ALL players FIRST
        //    This ensures the previous player's potential scores are gone before calculating new ones.
        console.log(`[GameService] Clearing potentials for ALL players before calculating new ones.`);
        game.players.forEach(p => {
            if (p) {
                p.clearPotentialScores(); // Resets non-fixed values to -1 and updates derived scores
            }
        });

      // --- *** ADDED: Calculate Potential Scores for Current Player *** ---
      const currentPlayer = game.players[playerIndex];
      if (currentPlayer) {
          currentPlayer.calculatePotentialScores(diceValues); // This updates the .value of unfixed cells
          // Also recalculate derived scores like Sum/Bonus/Total for display consistency
          currentPlayer.calculateScores();
      }
      // --- *** END ADDED *** ---

    // --- Notify other players via onClientMsg (for potential direct dice display updates) ---
    // const diceUpdateData = {
    //   action: 'sendDices',
    //   gameId: game.id,
    //   diceValue: diceValues,
    //   rollCount: game.rollCount
    // };

    // console.log(`🎲 Broadcasting 'sendDices' (onClientMsg) for game ${game.id}`);
    // for (let i = 0; i < game.players.length; i++) {
    //   const player = game.players[i];
    //   if (player?.isActive && player.id && player.id !== playerId) {
    //     this.io.to(player.id).emit('onClientMsg', diceUpdateData);
    //   }
    // }
    // --- End Notify other players ---


    // --- Notify ALL players AND spectators via onServerMsg (for full state sync) ---
    // This is the crucial addition for spectators to get updated dice/roll count
    console.log(`🔄 Notifying full game update (onServerMsg) after dice roll for game ${game.id}`);
    this.notifyGameUpdate(game);
    // --- End Notify ALL ---

    // // Also send dice update to spectators via onClientMsg if needed for specific client logic
    // const gameSpectators = this.spectators.get(game.id);
    // if (gameSpectators && gameSpectators.size > 0) {
    //   console.log(`[Spectator] Sending 'sendDices' (onClientMsg) to ${gameSpectators.size} spectators`);
    //   for (const spectatorId of gameSpectators) {
    //      this.io.to(spectatorId).emit('onClientMsg', diceUpdateData);
    //   }
    // }


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

    const currentPlayer = game.players[playerIndex];
    if (!currentPlayer) return false; // Should not happen

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

    // --- Recalculate derived scores (Sum, Bonus, Total) for the player who just selected ---
    //currentPlayer.calculateScores();
    game.players.forEach(p => {
      if (p) {
          p.clearPotentialScores(); // Resets non-fixed values to -1 and updates derived scores
      }
    });
    //currentPlayer.calculateDerivedScores();

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
      // --- *** ADDED: Clear potential scores before final update *** ---
      // Not strictly necessary as game is over, but good practice
      currentPlayer.clearPotentialScores(); // Clear for the player who made the last move
      // --- *** END ADDED *** ---
      // **** CRUCIAL FIX: Send final update BEFORE handling finish ****
      console.log(`🔄 Notifying final game update (onServerMsg) before finishing game ${game.id}`);
      this.notifyGameUpdate(game); // Send state including the last selection
      // ***************************************************************

      this.handleGameFinished(game); // This handles logging end, notifying, removing game
    } else {
      // Advance turn to the next active player FIRST
      game.advanceToNextActivePlayer();
      const nextPlayerIndex = game.playerToMove;
      const nextPlayer = game.players[nextPlayerIndex];

       // --- Clear potential scores for the player whose turn it is NOW ---
       if (nextPlayer) {
           console.log(`[GameService] Clearing potential scores for next player ${nextPlayerIndex} (${nextPlayer.username})`);
           nextPlayer.clearPotentialScores(); // Resets non-fixed values to -1 and recalculates derived scores
       } else {
           console.warn(`[GameService] Could not find next player at index ${nextPlayerIndex} to clear scores.`);
       }
       // --- End Clearing Potential Scores ---

      // --- Reset dice state for the *game* dynamically ---
      const config = GameConfig[getBaseGameType(game.gameType)];
      const diceCount = config.diceCount;
      const zeroDiceArray = new Array(diceCount).fill(0); // Create array of 0s with correct length
      game.setDiceValues(zeroDiceArray); // Use the dynamic array
      game.rollCount = 0;
      // --- End Resetting Dice State ---

      console.log(`🎮 [GameService] Advanced turn to player ${game.playerToMove}. Dice reset.`);

      // --- Notify ALL clients (players and spectators) of the updated game state ONCE ---
      // notifyGameUpdate handles serialization and sending to players/spectators.
      // It will send the state *after* potential scores are cleared and dice are reset.
      this.notifyGameUpdate(game);
      // --- End Notification ---
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
    // --- ADDED Validation ---
    const allowedTypes = ['Ordinary', 'Maxi'];
    if (!allowedTypes.includes(gameType)) {
        console.error(`[GameService] Attempt to create/join invalid game type: ${gameType}`);
        // How to handle? Throw error? Return null? For now, log and default.
        // Ideally, the controller should prevent this. Let's default to Ordinary.
        gameType = 'Ordinary';
        console.warn(`[GameService] Defaulting to 'Ordinary' game type.`);
    }
    // --- End Validation ---
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
</file>

<file path="backend/src/services/TopScoreService.ts">
// backend/src/services/TopScoreService.ts
import { Collection, Db } from 'mongodb';
import { getDbConnection } from '../db';
import { Server } from 'socket.io';

const DB_NAME = 'top-scores';

// Define the supported game types explicitly
const SUPPORTED_GAME_TYPES = ["Ordinary", "Maxi"];

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

  private getCollection(gameType: string): Collection<TopScoreEntry> | null { // Added null return possibility

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
</file>

<file path="backend/src/utils/gameConfig.ts">
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
  return 'Ordinary';
}
</file>

<file path="backend/src/utils/index.ts">
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
</file>

<file path="backend/src/utils/yatzyMapping.ts">
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
  Maxi: [
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
</file>

<file path="lib/application/animations_application.dart">
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
</file>

<file path="lib/application/application_functions_internal.dart">
// lib/application/application_functions_internal.dart
import 'application.dart';
import '../utils/yatzy_mapping_client.dart';

extension ApplicationFunctionsInternal on Application {
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
      String? selectionLabel = getSelectionLabel(gameType, cell);

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
      }
      print("sendSelection");
      // clearFocus();
      // if (dices.unityDices) {
      //   dices.sendResetToUnity();
      // }
      // gameDices.clearDices();
    } else {
        print("Ignoring cell click: Not my turn or cell invalid/fixed.");
    }
  }

  // colorBoard() {
  //   // Update player column colors based on playerToMove and playerActive status
  //   for (var i = 0; i < nrPlayers; i++) {
  //     Color columnColor;
  //     if (i == playerToMove) {
  //       columnColor = Colors.greenAccent.withAlpha(77); // ~0.3 alpha
  //     } else if (i < playerActive.length && playerActive[i]) {
  //       columnColor = Colors.grey.withAlpha(77); // ~0.3 alpha
  //     } else {
  //       // disconnected/aborted player
  //       columnColor = Colors.black.withAlpha(77); // ~0.3 alpha
  //     }
  //
  //     for (var j = 0; j < totalFields; j++) {
  //         // Keep special colors for non-selectable cells
  //         if (j == 6 || j == 7 || j == totalFields - 1) { // Sum, Bonus, Total
  //             appColors[i + 1][j] = Colors.blue.withAlpha(77); // Special color for calculated fields
  //         }
  //         // Apply base color only if not already fixed with the selection color
  //         else if (!(fixedCell[i][j] && appColors[i + 1][j] == Colors.green.withAlpha(178))) { // Check if it's the 'just selected' color
  //            appColors[i + 1][j] = columnColor;
  //         }
  //         // Re-apply selection color if cell is fixed
  //         else if (fixedCell[i][j]) {
  //             appColors[i + 1][j] = Colors.green.withAlpha(178); // ~0.7 alpha for selected/fixed
  //         }
  //     }
  //   }
  //     // Update header colors based on which cells are fixed for the *current* player
  //    if (playerToMove >= 0 && playerToMove < nrPlayers) {
  //        for (var j = 0; j < totalFields; j++) {
  //             // Keep special colors
  //             if (j == 6 || j == 7 || j == totalFields - 1) {
  //                 appColors[0][j] = Colors.blueAccent.withAlpha(204); // ~0.8 alpha
  //             }
  //             // Highlight fixed cells in header? Or just dim unfixed? Let's dim unfixed.
  //             else if (fixedCell[playerToMove][j]) {
  //                  appColors[0][j] = Colors.white.withAlpha(178); // Brighter/Solid for fixed
  //             } else {
  //                  appColors[0][j] = Colors.white.withAlpha(77); // Dimmer for available
  //             }
  //        }
  //    }
  //
  // }

}
</file>

<file path="lib/application/application.dart">
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/application_functions_internal.dart';
import 'package:yatzy/dices/unity_communication.dart';
import 'package:yatzy/services/socket_service.dart';
import '../dices/dices.dart';
import '../input_items/input_items.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';
import 'animations_application.dart';
import 'languages_application.dart';

// cannot have typedef inside class

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

  // "Ordinary" ,"Maxi"
  var gameType = "Ordinary";
  var nrPlayers = 1;

  // Used by animation
  var maxNrPlayers = 4;
  var maxTotalFields = 23;

  // Socket game
  Map<String, dynamic> gameData = {};

  var gameId = -1;
  //var playerIds = [];
  List<bool> playerActive = [];

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
  var serverId = "";

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
    Map<String, dynamic> msg = {};
    msg["action"] = "sendDices";
    msg["gameId"] = gameId;
    //msg["playerIds"] = playerIds;
    msg["diceValue"] = gameDices.diceValue;
    
    // Use socketService for sending dice values to ensure delivery
    // This ensures we use the modern socket system which is correctly connected
    print('🎲 Sending dice values to other players: ${gameDices.diceValue}');
    if (socketService != null && socketService!.isConnected) {
      socketService?.sendToClients(msg);
    }
  }

  setAppText() {
   if (gameType.startsWith("Maxi")) {
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

    if (gameType.startsWith("Maxi")) {
      totalFields = 23;
      gameDices.initDices(6);
      bonusSum = 84;
      bonusAmount = 100;

    } else {
      totalFields = 18;
      gameDices.initDices(5);
      bonusSum = 63;
      bonusAmount = 50;

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
  }

  // Method to set the socket service reference
  void setSocketService(SocketService service) {
    print('🔌 Application: Setting socket service reference');
    socketService = service;
  }
}
</file>

<file path="lib/application/communication_application.dart">
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
          final Map<String, dynamic> getIdData = (data).map(
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
            final Map<String, dynamic> receivedData = (data).map(
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
            List<Map<String, dynamic>> typedScores = (scoresList).map((scoreEntry) {
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
  
  // Helper method to process game updates
  void _processGameUpdate(dynamic data) async {
    try {
      final router = getIt<AppRouter>();
      print('🎮 Processing game update: $data'); // Log action

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


      if (data["playerIds"] != null) {
        final newPlayerIds = data["playerIds"];

        List<dynamic> playersData = gameData['players'];
        playerActive = (gameData['abortedPlayers'] as List<dynamic>)
            .map((e) => !(e as bool))
            .toList();

        // --- Update cell state for each player ---
        for (int p = 0; p < playersData.length; p++) {
          var playerData = playersData[p];
          if (playerData?['cells'] is List) {
            List<dynamic> cellsData = playerData['cells'];
            bool isAbortedPlayer = gameData['abortedPlayers'][p];
            for (int c = 0; c < cellsData.length; c++) {
              // Skip if cell index is out of bounds for local arrays
              if (c >= totalFields || p >= fixedCell.length || c >= fixedCell[p].length || p >= cellValue.length || c >= cellValue[p].length || p + 1 >= appText.length || c >= appText[p+1].length || p + 1 >= appColors.length || c >= appColors[p+1].length)
                {print("continue");continue;}

              var cellData = cellsData[c];

              if (cellData != null) {
                try {
                  final bool serverFixed = cellData['fixed'] ?? false;
                  final int serverValue = cellData['value'] ?? -1;
                  final bool isNonScoreCell = cellData['isNonScoreCell'] ?? (c == 6 || c == 7 || c == totalFields - 1);


                  // --- Apply server state directly to local state ---
                  fixedCell[p][c] = serverFixed;
                  cellValue[p][c] = serverValue;
                  appText[p + 1][c] = serverValue != -1 ? serverValue.toString() : "";

                  // --- Update Color based on Fixed Status and Cell Type ---
                  if (isAbortedPlayer) {
                    appColors[p + 1][c] = Colors.black.withAlpha(178);
                  } else if (isNonScoreCell) {
                    // Always use the special color for Sum, Bonus, Total
                    appColors[p + 1][c] = Colors.blue.withAlpha(77);
                  } else if (serverFixed) {
                    // Use the "fixed" color if the cell is marked fixed by the server
                    appColors[p + 1][c] = Colors.green.withAlpha(178); // ~0.7 alpha
                  }
                } catch (e) { print("❌ Error updating cell state [$p][$c]: $e"); }
              }
            }
          }
        }

      // ****** END: CORE STATE SYNCHRONIZATION ******

        // Check if this is our first update and we don't have an ID yet
        if (gameId == -1) {
          int potentialId = newPlayerIds.indexOf(socketService?.socketId ?? '');
          if (potentialId >= 0) {
            // We found ourselves in this game
            myPlayerId = potentialId;
            gameId = data["gameId"];
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
      }

      // Handle player turn changes
      final newPlayerToMove = data["playerToMove"];
      print('playerToMove $playerToMove newPlayerToMove $newPlayerToMove');
      if (newPlayerToMove != null && data["diceValues"][0] == 0) {
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
      //colorBoard();
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

    chat.scrollController.animateTo(
      chat.scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn
    );
    
    print('💬 Sending chat message to game $gameId');
    
    // Use the modern SocketService if available
    if (socketService != null && socketService!.isConnected) {
      print('💬 Using modern SocketService to send chat message');
      
      // Create message for modern SocketService
      final msg = {
        "action": "chatMessage",
        "gameId": gameId,
        "message": text,
        "sender": userName,
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

            // Mark the cell as selected but don't change turns
            // Actual turn change will come via the onGameUpdate message
            int player = data["player"];

            // Get next player (same logic as in calcNewSums)
            int nextPlayer = player;
            do {
              nextPlayer = (nextPlayer + 1) % nrPlayers;
            } while (!playerActive[nextPlayer]);

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
</file>

<file path="lib/application/languages_application.dart">
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
</file>

<file path="lib/application/widget_application_scaffold.dart">
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:yatzy/chat/widget_chat.dart';
import 'package:yatzy/dices/widget_dices.dart';
import 'package:yatzy/top_score/widget_top_scores.dart';

import '../router/router.gr.dart';
import '../startup.dart';
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

    stackedWidgets = [];

    if (h > w) {
      return Scaffold(
          body: Stack(children: <Widget>[
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft, // Start gradient at bottom-left
                  end: Alignment.topRight,     // End gradient at top-right
                  colors: [
                    Colors.blue.shade300, // Lighter blue at the start
                    Colors.blue.shade800, // Darker blue at the end
                    // You can add more colors and use the 'stops' property
                    // for more complex gradients if desired.
                  ],
                ),
              ),
            ),
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

        ]),
        widgetFloatingButton(h),
        Stack(children: stackedWidgets),
      ]));
    } else {
      // landscape

      return Scaffold(
          body: Stack(children: <Widget>[
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft, // Start gradient at bottom-left
                  end: Alignment.topRight,     // End gradient at top-right
                  colors: [
                    Colors.blue.shade300, // Lighter blue at the start
                    Colors.blue.shade800, // Darker blue at the end
                    // You can add more colors and use the 'stops' property
                    // for more complex gradients if desired.
                  ],
                ),
              ),
            ),
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

        ]),
        widgetFloatingButton(w),
        Stack(children: stackedWidgets),
      ]));
    }
  }
}
</file>

<file path="lib/application/widget_application_settings.dart">
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/service_provider.dart';
import '../shared_preferences.dart';
import '../startup.dart';
import '../states/bloc/language/language_bloc.dart';
import '../states/bloc/language/language_event.dart';
import '../states/cubit/state/state_cubit.dart';
import '../widgets/spectator_game_board.dart';
import 'application.dart';

extension WidgetApplicationSettings on Application {

  // List<Widget> widgetWaitingGame(BuildContext context) {
  //   List<Widget> gameWidgets = [];
  //
  //   var ongoingGames = 0;
  //   for (var i = 0; i < games.length; i++) {
  //     if (!games[i]["gameStarted"]) {
  //       var gameTypeText = games[i]["gameType"];
  //       if (gameTypeText == "Ordinary") {
  //         gameTypeText = gameTypeOrdinary_;
  //       }
  //       var gameText = '$gameTypeText ${games[i]["connected"]}/${games[i]["nrPlayers"]} ${games[i]["userNames"]}';
  //       try {
  //         final serviceProvider = ServiceProvider.of(context);
  //         if (games[i]["playerIds"].indexOf(serviceProvider.socketService.socketId) == -1) {
  //           gameWidgets.add(inputItems.widgetButton(
  //               () => onAttemptJoinGame(context, i), gameText));
  //         } else {
  //           gameWidgets.add(Text(gameText,
  //               textAlign: TextAlign.center,
  //               style: const TextStyle(
  //                 fontWeight: FontWeight.bold,
  //                 fontSize: 20,
  //                 color: Colors.black87,
  //               )));
  //         }
  //       } catch (e) {
  //         print('⚠️ ServiceProvider not available in widgetWaitingGame: $e');
  //         // Add button without checking socket ID
  //         gameWidgets.add(inputItems.widgetButton(
  //             () => onAttemptJoinGame(context, i), gameText));
  //       }
  //     } else {
  //       // This is an ongoing game - add a spectate button
  //       ongoingGames++;
  //       var gameTypeText = games[i]["gameType"];
  //       if (gameTypeText == "Ordinary") {
  //         gameTypeText = gameTypeOrdinary_;
  //       }
  //       var gameText = '$gameTypeText ${games[i]["connected"]}/${games[i]["nrPlayers"]} ${games[i]["userNames"]} (Ongoing)';
  //
  //       // Add spectate button
  //       gameWidgets.add(inputItems.widgetButton(
  //           () => onSpectateGame(context, games[i]["gameId"]), gameText));
  //     }
  //   }
  //   gameWidgets.add(Text("$ongoingGames_ : $ongoingGames",
  //       textAlign: TextAlign.center,
  //       style: const TextStyle(
  //         fontWeight: FontWeight.bold,
  //         fontSize: 20,
  //         color: Colors.brown,
  //       )));
  //   return gameWidgets;
  // }
  List<Widget> widgetWaitingGame(BuildContext context) {
    List<Widget> gameWidgets = [];
    int spectatableOngoingGames = 0; // Counter for games shown with Spectate button
    String myPlayerSocketId = ''; // Initialize

    final headingStyle = TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.secondary); // Consistent heading style

    try {
      // Get socket ID safely
      final serviceProvider = ServiceProvider.of(context);
      // Ensure socketService and its ID are not null before accessing
      myPlayerSocketId = serviceProvider.socketService.socketId;
      print("My Socket ID for filtering: $myPlayerSocketId");
    } catch (e) {
      print('⚠️ ServiceProvider not available or socketId null in widgetWaitingGame: $e');
      // Proceed without socket ID, filtering won't work correctly for the current player
    }

    // Add header for clarity
    if (games.isNotEmpty) {
      gameWidgets.add(Padding(
        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
        child: Text(ongoingGames_, style: headingStyle, textAlign: TextAlign.center),
      ));
    } else {
      return gameWidgets; // Return early if no games
    }


    for (var i = 0; i < games.length; i++) {
      final currentGame = games[i];
      // Basic validation of game data structure
      if (currentGame == null || currentGame is! Map || currentGame["gameId"] == null) {
        print("⚠️ Skipping invalid game entry at index $i: $currentGame");
        continue;
      }

      final bool gameStarted = currentGame["gameStarted"] ?? false;
      final List<dynamic>? gamePlayerIds = currentGame["playerIds"]; // Can be null or not a List
      final int gameId = currentGame["gameId"]; // Already checked for null above

      // Determine if the current player is in this game
      bool playerIsInGame = false;
      if (myPlayerSocketId.isNotEmpty && gamePlayerIds != null && gamePlayerIds is List) {
        try {
          // Safely check if the list contains the player's ID
          playerIsInGame = gamePlayerIds.map((e) => e.toString()).contains(myPlayerSocketId);
        } catch (e) {
          print("⚠️ Error checking playerIds for game $gameId: $e");
          // Assume player is not in game if there's an error parsing IDs
        }
      }

      // --- Logic to decide what to show ---
      String gameTypeText = currentGame["gameType"] ?? 'Unknown';
      if (gameTypeText == "Ordinary") gameTypeText = gameTypeOrdinary_;
      String userNamesText = (currentGame["userNames"] as List?)?.join(', ') ?? 'N/A';
      String connectedText = '${currentGame["connected"] ?? '?'}/${currentGame["nrPlayers"] ?? '?'}';

      if (!gameStarted) {
        // --- Game is WAITING for players ---
        String gameText = '$gameTypeText $connectedText [$userNamesText]';

        if (playerIsInGame) {
          // Player IS in this waiting game - show informative text
          gameWidgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Card( // Wrap in Card for better visuals
              elevation: 1,
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("⏳ You are waiting in: $gameText",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey)),
              ),
            ),
          ));
        } else {
          // Player is NOT in this waiting game - show Join button
          gameWidgets.add(inputItems.widgetButton(
                  () => onAttemptJoinGame(context, i), "➕ Join: $gameText"));
        }
      } else {
        // --- Game HAS STARTED ---
        if (!playerIsInGame) {
          // Player is NOT in this ongoing game - show Spectate button
          spectatableOngoingGames++; // Increment counter
          String gameText = '$gameTypeText $connectedText [$userNamesText] (Ongoing)';
          gameWidgets.add(inputItems.widgetButton(
                  () => onSpectateGame(context, gameId), "👁️ Spectate: $gameText"));
        } else {
          // Player IS in this ongoing game - show nothing in this list
          print("Skipping started game $gameId for available games list because player $myPlayerSocketId is in it.");
        }
      }
    }

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
                const Text("Game Type", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), // Use headingStyle if available
                const SizedBox(height: 8),
                inputItems.widgetStringRadioButton( // Use widgetStringRadioButton
                    state,
                    [ // Simplified list of values
                      "Ordinary",
                      "Maxi",
                    ],
                    [ // Simplified list of translations
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
        print('❌ No socket connection');
      }
    } catch (e) {
      print('⚠️ ServiceProvider not available in onStartGameButton: $e');
    }
  }

  onChangeUserName(value) {
    userName = textEditingController.text;
  }

  Widget widgetScaffoldSettings(BuildContext context, Function state) {
    // Define a consistent color scheme for better visibility
    final primaryColor = Colors.blue.shade700; // Brighter primary color
    final accentColor = Theme.of(context).colorScheme.secondary;

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
                unselectedLabelColor: Colors.white.withValues(alpha: 0.8), // Still visible unselected tabs
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
                                        color: Colors.black.withValues(alpha: 0.1),
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
                                          fillColor: WidgetStateProperty.resolveWith<Color>(
                                            (Set<WidgetState> states) {
                                              if (states.contains(WidgetState.selected)) {
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
</file>

<file path="lib/application/widget_application.dart">
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
              // ***** FIX: Add !app.gameFinished check *****
              if (!app.gameFinished && app.myPlayerId != -1)
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
              // ***** END FIX *****
            ]));
    return myWidget;
  }
}
</file>

<file path="lib/chat/chat.dart">
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
</file>

<file path="lib/chat/languages_chat.dart">
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
</file>

<file path="lib/chat/widget_chat.dart">
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
</file>

<file path="lib/core/app_widget.dart">
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/communication_application.dart';
import 'package:yatzy/dices/dices.dart';
import 'package:yatzy/services/service_provider.dart';
import '../application/application.dart';
import '../chat/chat.dart';
import '../injection.dart';
import '../router/router.dart';
import '../startup.dart';
import '../states/cubit/state/state_cubit.dart';
import '../top_score/top_score.dart';

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
</file>

<file path="lib/core/injectable_modules.dart">
import 'package:injectable/injectable.dart';

import '../router/router.dart';

@module
abstract class InjectableModule {
  @lazySingleton
  AppRouter get router => AppRouter();
}
</file>

<file path="lib/dices/dices.dart">
import 'dart:math';

import 'package:flutter/cupertino.dart';
import '../input_items/input_items.dart';
import '../startup.dart';
import 'unity_communication.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

import 'languages_dices.dart';


class Dices extends LanguagesDices  {
  final Function setState;
  final InputItems inputItems;
  Dices(
      {required Function getChosenLanguage, required String standardLanguage, required this.setState, required this.inputItems}) {
    languagesSetup(getChosenLanguage, standardLanguage);
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
  late Function callbackUpdateDiceValues;
  late Function callbackUnityCreated;
  late Function callbackCheckPlayerToMove;
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
    // ***** FIX: Add checks for game state *****
    if (app.gameFinished) { // Check if the game is globally finished
      print("🎲 Roll blocked: Game is finished.");
      return false;
    }

    if (!callbackCheckPlayerToMove()) { // Check if it's actually my turn
      print("🎲 Roll blocked: Not my turn.");
      return false;
    }
    // ***** END FIX *****
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
    print("🎲 Roll blocked: No rolls left ($nrRolls/$nrTotalRolls).");
    return false;
  }

  List<Widget> widgetUnitySettings(Function state) {
    List<Widget> widgets = [];
    if (!showUnityOptions) {
      return widgets;
    }
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
</file>

<file path="lib/dices/languages_dices.dart">
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
</file>

<file path="lib/dices/unity_communication.dart">
import 'dart:convert';

import 'unity_message.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

import 'dices.dart';

extension UnityCommunication on Dices {
  sendResetToUnity() {
    print("Sending Reset To Unity");
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
</file>

<file path="lib/dices/unity_message.dart">
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
</file>

<file path="lib/dices/widget_dices.dart">
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

  late AnimationController _localAnimationController;
  late Animation<double> _localSizeAnimation;

  @override
  void initState() {
    super.initState();
    _localAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _localSizeAnimation =
        CurveTween(curve: Curves.easeInSine).animate(_localAnimationController);

    _localAnimationController.addStatusListener((AnimationStatus status) {
      if (!mounted) return;
      if (status == AnimationStatus.completed) {
        _localAnimationController.reverse();
      }
    });
    //setupAnimation(this);
  }

  @override
  void dispose(){
    print("Disposing WidgetDicesState...");
    try {
      _localAnimationController.stop();
      _localAnimationController.dispose();
      print("Disposed local WidgetDices controller.");
    } catch (e) { print("Error disposing local WidgetDices controller: $e"); }
    super.dispose();
  }

  // --- ADD Reusable Dice Face Widget Builder ---
  // Takes the dice value (1-6) and the desired size for the dice face container
  static Widget buildDiceFace(int value, double diceSize) {
    final double dotSize = diceSize * 0.18; // Size of each dot
    final double padding = diceSize * 0.1;  // Padding around dots/groups

    Widget dot = Container(
      width: dotSize,
      height: dotSize,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle, // Make dots circular
      ),
    );

    List<Widget> children;

    switch (value) {
      case 1:
        children = [Center(child: dot)];
        break;
      case 2:
        children = [
          Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.bottomRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
        ];
        break;
      case 3:
        children = [
          Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Center(child: dot),
          Align(alignment: Alignment.bottomRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
        ];
        break;
      case 4:
        children = [
          Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.bottomLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.bottomRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
        ];
        break;
      case 5:
        children = [
          Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Center(child: dot),
          Align(alignment: Alignment.bottomLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.bottomRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
        ];
        break;
      case 6:
        children = [
          Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(left: padding), child: dot)),
          Align(alignment: Alignment.centerRight, child: Padding(padding: EdgeInsets.only(right: padding), child: dot)),
          Align(alignment: Alignment.bottomLeft, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
          Align(alignment: Alignment.bottomRight, child: Padding(padding: EdgeInsets.all(padding), child: dot)),
        ];
        break;
      default: // Handle 0 or invalid values - show empty
        children = [];
        break;
    }

    // Return the dots within a Stack to allow positioning
    return Stack(children: children);
  }
  // --- END Dice Face Builder ---

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
                //webUrl: '/UnityLibrary/index.html',
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

    double diceWidgetSize = 4 * width / (5 * app.gameDices.nrDices + 1);
    left = diceWidgetSize / 4;
    top = min(diceWidgetSize / 2,
        diceWidgetSize / 2 + (height - diceWidgetSize * 3.5) / 2);

    for (var i = 0; i < app.gameDices.nrDices; i++) {
      // Boundary check for diceValue array
      int diceValue = (i < app.gameDices.diceValue.length) ? app.gameDices.diceValue[i] : 0;

      listings.add(
        Positioned(
            left: left + 1.25 * diceWidgetSize * i,
            top: top,
            child: GestureDetector( // Keep GestureDetector for hold functionality
              onTap: () {
                if (app.callbackCheckPlayerToMove()) { // Only allow hold if it's my turn
                  app.gameDices.holdDice(i);
                  app.gameDices.setState(); // This should trigger a rebuild via Bloc
                }
              },
              child: Container(
                width: diceWidgetSize,
                height: diceWidgetSize,
                decoration: BoxDecoration(
                    color: Colors.white, // White background for dice
                    borderRadius: BorderRadius.circular(diceWidgetSize * 0.15), // Rounded corners
                    border: Border.all(color: Colors.grey.shade400),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 3,
                        offset: const Offset(1, 2),
                      )
                    ]
                ),
                // --- Use the new dice face builder ---
                child: buildDiceFace(diceValue, diceWidgetSize),
                // --------------------------------------
              ),
            )),
      );

      // Add the "HOLD" overlay if needed
      // Boundary check for holdDiceOpacity and holdDiceText
      double holdOpacity = (i < app.gameDices.holdDiceOpacity.length) ? app.gameDices.holdDiceOpacity[i] : 0.0;

      if (holdOpacity > 0) {
        listings.add(Positioned(
          left: left + 1.25 * diceWidgetSize * i,
          top: top,
          child: IgnorePointer( // Makes overlay non-interactive
            child: Container(
              width: diceWidgetSize,
              height: diceWidgetSize,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: holdOpacity * 0.7), // Adjust opacity
                borderRadius: BorderRadius.circular(diceWidgetSize * 0.15),
              ),
              child: const Center(
              ),
            ),
          ),
        ));
      }
    }

    // --- Update Roll button ---
    listings.add(AnimatedBuilder(
      animation: _localAnimationController, // Use local controller
      builder: (BuildContext context, Widget? builderWidget) { // Renamed widget parameter
        final bool canRoll = !app.gameFinished &&
            app.callbackCheckPlayerToMove() &&
            app.gameDices.nrRolls < app.gameDices.nrTotalRolls;

        // Calculate button size based on animation
        double buttonScaleFactor = (1 - _localSizeAnimation.value / 2);
        double buttonSize = diceWidgetSize * 1.5; // Make button a bit larger than dice

        return Positioned(
          // Center the button roughly, adjust vertical position
          left: left + (width / 2) - (buttonSize * buttonScaleFactor / 2) - (diceWidgetSize/4), // Centering adjustment
          top: top + diceWidgetSize * 1.5, // Position below the dice row
          child: SizedBox( // Use SizedBox to apply animated size
            width: buttonSize * 0.8 * buttonScaleFactor, // Make button more square
            height: buttonSize * 0.8 * buttonScaleFactor, // Make button more square
            child: ElevatedButton(
              onPressed: canRoll ? () {
                if (app.gameDices.rollDices(context)) {
                  _localAnimationController.forward(); // Start local animation
                }
              } : null, // Disable button if cannot roll
              style: ElevatedButton.styleFrom(
                backgroundColor: canRoll ? Colors.red.shade600 : Colors.grey.shade500,
                foregroundColor: Colors.white,
                shape: const CircleBorder(), // Make it circular for a classic roll feel
                padding: EdgeInsets.zero, // Remove padding to center icon
                elevation: canRoll ? 4 : 0,
              ),
              // --- Use Icon instead of Label ---
              child: Icon(
                // Option 1: Send/Throw motion
                  Icons.send,
                  // Option 2: Replay/Re-roll symbol
                  // Icons.replay,
                  // Option 3: Casino/Dice symbol
                  // Icons.casino_outlined, // Kept this as an option too
                  size: buttonSize * 0.4 * buttonScaleFactor // Adjust icon size
              ),
              // ---------------------------------
            ),
          ),
        );
      },
    ));
    // --- End Roll button update ---

    return SizedBox(
        width: width, height: height, child: Stack(children: listings));
  }
}
</file>

<file path="lib/injection.config.dart">
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
</file>

<file path="lib/injection.dart">
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
</file>

<file path="lib/input_items/input_items.dart">
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
</file>

<file path="lib/main.dart">
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
</file>

<file path="lib/models/board_cell.dart">
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
</file>

<file path="lib/models/game.dart">
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
</file>

<file path="lib/models/player.dart">
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
</file>

<file path="lib/router/router.dart">
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
</file>

<file path="lib/router/router.gr.dart">
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
</file>

<file path="lib/services/game_service.dart">
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
</file>

<file path="lib/services/http_service.dart">
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
</file>

<file path="lib/services/service_provider.dart">
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
</file>

<file path="lib/services/socket_service.dart">
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
      if (isOnline) {
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
              'extraHeaders': {'Content-Type': 'application/json'},
              //'path': '/new/socket.io/',
              'path': '/socket.io/',
            }
        );
      } else {
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
              'extraHeaders': {'Content-Type': 'application/json'},
            }
        );
      }

      
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
    }
  
  /// Set up Socket.IO event handlers
  void _setupEventHandlers() {
    if (_handlersSetUp) {
       print('🔄 [Socket #$_instanceId] Handlers already set up for this socket instance, skipping.');
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
    socket.disconnect();
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
</file>

<file path="lib/shared_preferences.dart">
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
</file>

<file path="lib/startup.dart">
import 'package:yatzy/top_score/top_score.dart';
import 'application/application.dart';
import 'chat/chat.dart';
import 'dices/dices.dart';
import 'input_items/input_items.dart';

var isOnline = true;

var localhost = isOnline
        ? "https://fluttersystems.com"
    : "http://localhost:8000";

var showUnityOptions = false;
var applicationStarted = false;
var userName = "Yatzy";
var userNames = [];
var isTesting = false;
var isTutorial = true;
var mainPageLoaded = false;
late double screenWidth;
late double screenHeight;
late double devicePixelRatio;

var chosenLanguage = "Swedish";
var standardLanguage = "English";

var differentLanguages = ["English", "Swedish"];

// android:theme="@style/UnityThemeSelector.Translucent"
// android/app/src/main/AndroidManifest.xml

var inputItems = InputItems();
//var languagesGlobal = LanguagesGlobal();

late TopScore topScore;

late Application app;
late Chat chat;

late Dices dices;
</file>

<file path="lib/states/bloc/language/language_bloc.dart">
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
</file>

<file path="lib/states/bloc/language/language_event.dart">
/// Event being processed by [CounterBloc].
abstract class LanguageEvent {}

/// Notifies bloc to increment state.
class LanguageChanged extends LanguageEvent {
  final String language;

  LanguageChanged({required this.language});
}
</file>

<file path="lib/states/cubit/state/state_cubit.dart">
import 'package:flutter_bloc/flutter_bloc.dart';

class SetStateCubit extends Cubit<int> {
  SetStateCubit() : super(0);

  Future<void> setState() async {
    emit(state + 1);
  }
}
</file>

<file path="lib/top_score/languages_top_score.dart">
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
</file>

<file path="lib/top_score/top_score.dart">
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
</file>

<file path="lib/top_score/widget_top_scores.dart">
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
    topScore.animationController.dispose();
    super.dispose();
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
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.white70,

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
</file>

<file path="lib/utils/yatzy_mapping_client.dart">
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
</file>

<file path="lib/views/application_view.dart">
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yatzy/application/widget_application_scaffold.dart';

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

  postFrameCallback(BuildContext context) async {
    if (mounted) {
      myState();
    }
    mainPageLoaded = true;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback((_) => postFrameCallback(context));

    app.animation.setupAnimation(
        this, app.nrPlayers, app.maxNrPlayers, app.maxTotalFields);

  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SetStateCubit, int>(builder: (context, state) {
      return app.widgetScaffold(context, myState);
    });
  }
}
</file>

<file path="lib/views/settings_view.dart">
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
</file>

<file path="lib/widgets/spectator_game_board.dart">
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
                  color: Colors.black.withValues(alpha: 0.5),
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
              )),
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
                    Colors.green.shade100.withValues(alpha: 0.7) : null,
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
          }),
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
</file>

<file path="unity/yatzy/Assets/FlutterUnityIntegration/Demo/GameManager.cs">
using System;
using System.Collections;
using System.Collections.Generic;
using FlutterUnityIntegration;
using UnityEngine;

public class GameManager : MonoBehaviour
{
    // Start is called before the first frame update
    // Start is called before the first frame update
    void Start()
    {
        gameObject.AddComponent<UnityMessageManager>();
    }

    // Update is called once per frame
    void Update()
    { }

    void HandleWebFnCall(String action)
    {
        switch (action)
        {
            case "pause":
                Time.timeScale = 0;
                break;
            case "resume":
                Time.timeScale = 1;
                break;
            case "unload":
                Application.Unload();
                break;
            case "quit":
                Application.Quit();
                break;
        }
    }
}
</file>

<file path="unity/yatzy/Assets/FlutterUnityIntegration/Demo/Rotate.cs">
using System;
using FlutterUnityIntegration;
using UnityEngine;
using UnityEngine.EventSystems;

public class Rotate : MonoBehaviour, IEventSystemHandler
{
    [SerializeField]
    Vector3 RotateAmount;

    // Start is called before the first frame update
    void Start()
    {
        RotateAmount = new Vector3(0, 0, 0);
    }

    // Update is called once per frame
    void Update()
    {
        gameObject.transform.Rotate(RotateAmount * Time.deltaTime * 120);

        for (int i = 0; i < Input.touchCount; ++i)
        {
            if (Input.GetTouch(i).phase.Equals(TouchPhase.Began))
            {
                var hit = new RaycastHit();

                Ray ray = Camera.main.ScreenPointToRay(Input.GetTouch(i).position);

                if (Physics.Raycast(ray, out hit))
                {
                    // This method is used to send data to Flutter
                    UnityMessageManager.Instance.SendMessageToFlutter("The cube feels touched.");
                }
            }
        }
    }

    // This method is called from Flutter
    public void SetRotationSpeed(String message)
    {
        float value = float.Parse(message);
        RotateAmount = new Vector3(value, value, value);
    }
}
</file>

<file path="unity/yatzy/Assets/FlutterUnityIntegration/Demo/SceneLoader.cs">
using System.Collections;
using System.Collections.Generic;
using FlutterUnityIntegration;
using UnityEngine;
using UnityEngine.SceneManagement;

public class SceneLoader : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        // mMessenger = new UnityMessageManager();
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void LoadScene(int idx)
    {
        Debug.Log("scene = " + idx);
        SceneManager.LoadScene(idx, LoadSceneMode.Single);
    }

    public void MessengerFlutter()
    {

        UnityMessageManager.Instance.SendMessageToFlutter("Hey man");
    }

    public void SwitchNative()
    {
        UnityMessageManager.Instance.ShowHostMainWindow();
    }

    public void UnloadNative()
    {
        UnityMessageManager.Instance.UnloadMainWindow();
    }

    public void QuitNative()
    {
        UnityMessageManager.Instance.QuitUnityWindow();
    }
}
</file>

<file path="unity/yatzy/Assets/FlutterUnityIntegration/Editor/Build.cs">
using System;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;
using Application = UnityEngine.Application;
using BuildResult = UnityEditor.Build.Reporting.BuildResult;

// uncomment for addressables
//using UnityEditor.AddressableAssets;
//using UnityEditor.AddressableAssets.Settings;

namespace FlutterUnityIntegration.Editor
{
    public class Build : EditorWindow
    {
        private static readonly string ProjectPath = Path.GetFullPath(Path.Combine(Application.dataPath, ".."));
        private static readonly string APKPath = Path.Combine(ProjectPath, "Builds/" + Application.productName + ".apk");

        private static readonly string AndroidExportPath = Path.GetFullPath(Path.Combine(ProjectPath, "../../android/unityLibrary"));
        private static readonly string WindowsExportPath = Path.GetFullPath(Path.Combine(ProjectPath, "../../windows/unityLibrary/data"));
        private static readonly string IOSExportPath = Path.GetFullPath(Path.Combine(ProjectPath, "../../ios/UnityLibrary"));
        private static readonly string WebExportPath = Path.GetFullPath(Path.Combine(ProjectPath, "../../web/UnityLibrary"));
        private static readonly string IOSExportPluginPath = Path.GetFullPath(Path.Combine(ProjectPath, "../../ios_xcode/UnityLibrary"));

        private bool _pluginMode = false;
        private static string _persistentKey = "flutter-unity-widget-pluginMode";

        //#region GUI Member Methods
        [MenuItem("Flutter/Export Android %&n", false, 1)]
        public static void DoBuildAndroidLibrary()
        {
            DoBuildAndroid(Path.Combine(APKPath, "unityLibrary"), false);

            // Copy over resources from the launcher module that are used by the library
            Copy(Path.Combine(APKPath + "/launcher/src/main/res"), Path.Combine(AndroidExportPath, "src/main/res"));
        }

        [MenuItem("Flutter/Export Android Plugin %&p", false, 5)]
        public static void DoBuildAndroidPlugin()
        {
            DoBuildAndroid(Path.Combine(APKPath, "unityLibrary"), true);

            // Copy over resources from the launcher module that are used by the library
            Copy(Path.Combine(APKPath + "/launcher/src/main/res"), Path.Combine(AndroidExportPath, "src/main/res"));
        }

        [MenuItem("Flutter/Export IOS %&i", false, 2)]
        public static void DoBuildIOS()
        {
            BuildIOS(IOSExportPath);
        }

        [MenuItem("Flutter/Export IOS Plugin %&o", false, 6)]
        public static void DoBuildIOSPlugin()
        {
            BuildIOS(IOSExportPluginPath);

            // Automate so manual steps
            SetupIOSProjectForPlugin();

            // Build Archive
            // BuildUnityFrameworkArchive();

        }

        [MenuItem("Flutter/Export Web GL %&w", false, 3)]
        public static void DoBuildWebGL()
        {
            BuildWebGL(WebExportPath);
        }


        [MenuItem("Flutter/Export Windows %&d", false, 4)]
        public static void DoBuildWindowsOS()
        {
            BuildWindowsOS(WindowsExportPath);
        }

        [MenuItem("Flutter/Settings %&S", false, 7)]
        public static void PluginSettings()
        {
            EditorWindow.GetWindow(typeof(Build));
        }

        private void OnGUI()
        {
            GUILayout.Label("Flutter Unity Widget Settings", EditorStyles.boldLabel);

            EditorGUI.BeginChangeCheck();
            _pluginMode = EditorGUILayout.Toggle("Plugin Mode", _pluginMode);

            if (EditorGUI.EndChangeCheck())
            {
                EditorPrefs.SetBool(_persistentKey, _pluginMode);
            }
        }

        private void OnEnable()
        {
            _pluginMode = EditorPrefs.GetBool(_persistentKey, false);
        }
        //#endregion


        //#region Build Member Methods

        private static void BuildWindowsOS(String path)
        {
            // Switch to Android standalone build.
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);

            if (Directory.Exists(path))
                Directory.Delete(path, true);

            if (Directory.Exists(WindowsExportPath))
                Directory.Delete(WindowsExportPath, true);

            var playerOptions = new BuildPlayerOptions
            {
                scenes = GetEnabledScenes(),
                target = BuildTarget.StandaloneWindows64,
                locationPathName = path,
                options = BuildOptions.AllowDebugging
            };

            // Switch to Android standalone build.
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Standalone, BuildTarget.StandaloneWindows64);

            // build addressable
            ExportAddressables();
            var report = BuildPipeline.BuildPlayer(playerOptions);

            if (report.summary.result != BuildResult.Succeeded)
                throw new Exception("Build failed");
        }

        private static void BuildWebGL(String path)
        {
            // Switch to Android standalone build.
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);

            if (Directory.Exists(path))
                Directory.Delete(path, true);

            if (Directory.Exists(WebExportPath))
                Directory.Delete(WebExportPath, true);

            // EditorUserBuildSettings. = true;

            var playerOptions = new BuildPlayerOptions();
            playerOptions.scenes = GetEnabledScenes();
            playerOptions.target = BuildTarget.WebGL;
            playerOptions.locationPathName = path;

            // Switch to Android standalone build.
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.WebGL, BuildTarget.WebGL);
            // build addressable
            ExportAddressables();
            var report = BuildPipeline.BuildPlayer(playerOptions);

            if (report.summary.result != BuildResult.Succeeded)
                throw new Exception("Build failed");

            // Copy(path, WebExportPath);
            ModifyWebGLExport();
        }

        private static void DoBuildAndroid(String buildPath, bool isPlugin)
        {
            // Switch to Android standalone build.
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);

            if (Directory.Exists(APKPath))
                Directory.Delete(APKPath, true);

            if (Directory.Exists(AndroidExportPath))
                Directory.Delete(AndroidExportPath, true);

            EditorUserBuildSettings.androidBuildSystem = AndroidBuildSystem.Gradle;
            EditorUserBuildSettings.exportAsGoogleAndroidProject = true;

            var playerOptions = new BuildPlayerOptions();
            playerOptions.scenes = GetEnabledScenes();
            playerOptions.target = BuildTarget.Android;
            playerOptions.locationPathName = APKPath;
            playerOptions.options = BuildOptions.AllowDebugging;

            // Switch to Android standalone build.
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);
            // build addressable
            ExportAddressables();
            var report = BuildPipeline.BuildPlayer(playerOptions);

            if (report.summary.result != BuildResult.Succeeded)
                throw new Exception("Build failed");

            Copy(buildPath, AndroidExportPath);

            // Modify build.gradle
            ModifyAndroidGradle(isPlugin);

            if(isPlugin)
            {
                SetupAndroidProjectForPlugin();
            } else
            {
                SetupAndroidProject();
            }
        }

        private static void ModifyWebGLExport()
        {
            // Modify index.html
            var indexFile = Path.Combine(WebExportPath, "index.html");
            var indexHtmlText = File.ReadAllText(indexFile);

            indexHtmlText = indexHtmlText.Replace("<script>", @"
            <script>
              var mainUnityInstance;

              window['handleUnityMessage'] = function (params) {
                window.parent.postMessage({
                    name: 'onUnityMessage',
                    data: params,
                   }, '*');
              };

              window['handleUnitySceneLoaded'] = function (name, buildIndex, isLoaded, isValid) {
                window.parent.postMessage({
                    name: 'onUnitySceneLoaded',
                    data: {
                        'name': name,
                        'buildIndex': buildIndex,
                        'isLoaded': isLoaded == 1,
                        'isValid': isValid == 1,
                    }
                   }, '*');
              };

              window.parent.addEventListener('unityFlutterBiding', function (args) {
                const obj = JSON.parse(args.data);
                mainUnityInstance.SendMessage(obj.gameObject, obj.methodName, obj.message);
              });

              window.parent.addEventListener('unityFlutterBidingFnCal', function (args) {
                mainUnityInstance.SendMessage('GameManager', 'HandleWebFnCall', args);
              });
            ");

            indexHtmlText = indexHtmlText.Replace("}).then((unityInstance) => {", @"
         }).then((unityInstance) => {
           window.parent.postMessage('unityReady', '*');
           mainUnityInstance = unityInstance;
         ");
            
            //
            // window.parent.addEventListener("flutter2js", function (params) {
            //     const obj = JSON.parse(params.data);
            //     globalUnityInstance.SendMessage(obj.gameObject, obj.method, obj.data);
            // });
            
            File.WriteAllText(indexFile, indexHtmlText);
        }

        private static void ModifyAndroidGradle(bool isPlugin)
        {
            // Modify build.gradle
            var buildFile = Path.Combine(AndroidExportPath, "build.gradle");
            var buildText = File.ReadAllText(buildFile);
            buildText = buildText.Replace("com.android.application", "com.android.library");
            buildText = buildText.Replace("bundle {", "splits {");
            buildText = buildText.Replace("enableSplit = false", "enable false");
            buildText = buildText.Replace("enableSplit = true", "enable true");
            buildText = buildText.Replace("implementation fileTree(dir: 'libs', include: ['*.jar'])", "implementation(name: 'unity-classes', ext:'jar')");
            buildText = buildText.Replace(" + unityStreamingAssets.tokenize(', ')", "");

            if(isPlugin)
            {
                buildText = Regex.Replace(buildText, @"implementation\(name: 'androidx.* ext:'aar'\)", "\n");
            }
//        build_text = Regex.Replace(build_text, @"commandLineArgs.add\(\"--enable-debugger\"\)", "\n");
//        build_text = Regex.Replace(build_text, @"commandLineArgs.add\(\"--profiler-report\"\)", "\n");
//        build_text = Regex.Replace(build_text, @"commandLineArgs.add\(\"--profiler-output-file=\" + workingDir + \"/build/il2cpp_\"+ abi + \"_\" + configuration + \"/il2cpp_conv.traceevents\"\)", "\n");

            buildText = Regex.Replace(buildText, @"\n.*applicationId '.+'.*\n", "\n");
            File.WriteAllText(buildFile, buildText);

            // Modify AndroidManifest.xml
            var manifestFile = Path.Combine(AndroidExportPath, "src/main/AndroidManifest.xml");
            var manifestText = File.ReadAllText(manifestFile);
            manifestText = Regex.Replace(manifestText, @"<application .*>", "<application>");
            var regex = new Regex(@"<activity.*>(\s|\S)+?</activity>", RegexOptions.Multiline);
            manifestText = regex.Replace(manifestText, "");
            File.WriteAllText(manifestFile, manifestText);

            // Modify proguard-unity.txt
            var proguardFile = Path.Combine(AndroidExportPath, "proguard-unity.txt");
            var proguardText = File.ReadAllText(proguardFile);
            proguardText = proguardText.Replace("-ignorewarnings", "-keep class com.xraph.plugin.** { *; }\n-ignorewarnings");
            File.WriteAllText(proguardFile, proguardText);

        }

        private static void BuildIOS(String path)
        {
            // Switch to ios standalone build.
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.iOS, BuildTarget.iOS);

            if (Directory.Exists(path))
                Directory.Delete(path, true);

            EditorUserBuildSettings.iOSXcodeBuildConfig = XcodeBuildConfig.Release;

            var playerOptions = new BuildPlayerOptions
            {
                scenes = GetEnabledScenes(),
                target = BuildTarget.iOS,
                locationPathName = path,
                options = BuildOptions.AllowDebugging
            };

            // build addressable
            ExportAddressables();

            var report = BuildPipeline.BuildPlayer(playerOptions);

            if (report.summary.result != BuildResult.Succeeded)
                throw new Exception("Build failed");
        }

        //#endregion


        //#region Other Member Methods
        private static void Copy(string source, string destinationPath)
        {
            if (Directory.Exists(destinationPath))
                Directory.Delete(destinationPath, true);

            Directory.CreateDirectory(destinationPath);

            foreach (var dirPath in Directory.GetDirectories(source, "*",
                         SearchOption.AllDirectories))
                Directory.CreateDirectory(dirPath.Replace(source, destinationPath));

            foreach (var newPath in Directory.GetFiles(source, "*.*",
                         SearchOption.AllDirectories))
                File.Copy(newPath, newPath.Replace(source, destinationPath), true);
        }

        private static string[] GetEnabledScenes()
        {
            var scenes = EditorBuildSettings.scenes
                .Where(s => s.enabled)
                .Select(s => s.path)
                .ToArray();

            return scenes;
        }

        // uncomment for addressables
        private static void ExportAddressables() {
            /*
        Debug.Log("Start building player content (Addressables)");
        Debug.Log("BuildAddressablesProcessor.PreExport start");

        AddressableAssetSettings.CleanPlayerContent(
            AddressableAssetSettingsDefaultObject.Settings.ActivePlayerDataBuilder);

        AddressableAssetProfileSettings profileSettings = AddressableAssetSettingsDefaultObject.Settings.profileSettings;
        string profileId = profileSettings.GetProfileId("Default");
        AddressableAssetSettingsDefaultObject.Settings.activeProfileId = profileId;

        AddressableAssetSettings.BuildPlayerContent();
        Debug.Log("BuildAddressablesProcessor.PreExport done");
        */
        }


        /// <summary>
        /// This method tries to autome the build setup required for Android
        /// </summary>
        private static void SetupAndroidProject()
        {
            var androidPath = Path.GetFullPath(Path.Combine(ProjectPath, "../../android"));
            var androidAppPath = Path.GetFullPath(Path.Combine(ProjectPath, "../../android/app"));
            var projBuildPath = Path.Combine(androidPath, "build.gradle");
            var appBuildPath = Path.Combine(androidAppPath, "build.gradle");
            var settingsPath = Path.Combine(androidPath, "settings.gradle");

            var projBuildScript = File.ReadAllText(projBuildPath);
            var settingsScript = File.ReadAllText(settingsPath);
            var appBuildScript = File.ReadAllText(appBuildPath);

            // Sets up the project build.gradle files correctly
            if (!Regex.IsMatch(projBuildScript, @"flatDir[^/]*[^}]*}"))
            {
                var regex = new Regex(@"allprojects \{[^\{]*\{", RegexOptions.Multiline);
                projBuildScript = regex.Replace(projBuildScript, @"
allprojects {
    repositories {
        flatDir {
            dirs ""${project(':unityLibrary').projectDir}/libs""
        }
");
                File.WriteAllText(projBuildPath, projBuildScript);
            }

            // Sets up the project settings.gradle files correctly
            if (!Regex.IsMatch(settingsScript, @"include "":unityLibrary"""))
            {
                settingsScript += @"

include "":unityLibrary""
project("":unityLibrary"").projectDir = file(""./unityLibrary"")
";
                File.WriteAllText(settingsPath, settingsScript);
            }


            // Sets up the project app build.gradle files correctly
            if (!Regex.IsMatch(appBuildScript, @"dependencies \{"))
            {
                appBuildScript += @"
dependencies {
    implementation project(':unityLibrary')
}
";
                File.WriteAllText(appBuildPath, appBuildScript);
            } else
            {
                if (!appBuildScript.Contains(@"implementation project(':unityLibrary')"))
                {
                    var regex = new Regex(@"dependencies \{", RegexOptions.Multiline);
                    appBuildScript = regex.Replace(appBuildScript, @"
dependencies {
    implementation project(':unityLibrary')
");
                    File.WriteAllText(appBuildPath, appBuildScript);
                }
            }
        }

        /// <summary>
        /// This method tries to autome the build setup required for Android
        /// </summary>
        private static void SetupAndroidProjectForPlugin()
        {
            var androidPath = Path.GetFullPath(Path.Combine(ProjectPath, "../../android"));
            var projBuildPath = Path.Combine(androidPath, "build.gradle");
            var settingsPath = Path.Combine(androidPath, "settings.gradle");

            var projBuildScript = File.ReadAllText(projBuildPath);
            var settingsScript = File.ReadAllText(settingsPath);

            // Sets up the project build.gradle files correctly
            if (Regex.IsMatch(projBuildScript, @"// BUILD_ADD_UNITY_LIBS"))
            {
                var regex = new Regex(@"// BUILD_ADD_UNITY_LIBS", RegexOptions.Multiline);
                projBuildScript = regex.Replace(projBuildScript, @"
        flatDir {
            dirs ""${project(':unityLibrary').projectDir}/libs""
        }
");
                File.WriteAllText(projBuildPath, projBuildScript);
            }

            // Sets up the project settings.gradle files correctly
            if (!Regex.IsMatch(settingsScript, @"include "":unityLibrary"""))
            {
                settingsScript += @"

include "":unityLibrary""
project("":unityLibrary"").projectDir = file(""./unityLibrary"")
";
                File.WriteAllText(settingsPath, settingsScript);
            }
        }

        private static void SetupIOSProjectForPlugin()
        {
            var iosRunnerPath = Path.GetFullPath(Path.Combine(ProjectPath, "../../ios"));
            var pubsecFile = Path.Combine(iosRunnerPath, "flutter_unity_widget.podspec");
            var pubsecText = File.ReadAllText(pubsecFile);

            if (!Regex.IsMatch(pubsecText, @"\w\.xcconfig(?:[^}]*})+") && !Regex.IsMatch(pubsecText, @"tar -xvjf UnityFramework.tar.bz2"))
            {
                var regex = new Regex(@"\w\.xcconfig(?:[^}]*})+", RegexOptions.Multiline);
                pubsecText = regex.Replace(pubsecText, @"
	spec.xcconfig = {
        'FRAMEWORK_SEARCH_PATHS' => '""${PODS_ROOT}/../.symlinks/plugins/flutter_unity_widget/ios"" ""${PODS_ROOT}/../.symlinks/flutter/ios-release"" ""${PODS_CONFIGURATION_BUILD_DIR}""',
        'OTHER_LDFLAGS' => '$(inherited) -framework UnityFramework \${PODS_LIBRARIES}'
    }

    spec.vendored_frameworks = ""UnityFramework.framework""
			");
                File.WriteAllText(pubsecFile, pubsecText);
            }
        }

        // DO NOT USE (Contact before trying)
        private static async void BuildUnityFrameworkArchive()
        {
            var xcprojectExt = "/Unity-iPhone.xcodeproj";

            // check if we have a workspace or not
            if (Directory.Exists(IOSExportPluginPath + "/Unity-iPhone.xcworkspace")) {
                xcprojectExt = "/Unity-iPhone.xcworkspace";
            }

            const string framework = "UnityFramework";
            var xcprojectName = $"{IOSExportPluginPath}{xcprojectExt}";
            var schemeName = $"{framework}";
            var buildPath = IOSExportPluginPath + "/build";
            var frameworkNameWithExt = $"{framework}.framework";

            var iosRunnerPath = Path.GetFullPath(Path.Combine(ProjectPath, "../../ios/"));
            const string iosArchiveDir = "Release-iphoneos-archive";
            var iosArchiveFrameworkPath = $"{buildPath}/{iosArchiveDir}/Products/Library/Frameworks/{frameworkNameWithExt}";
            var dysmNameWithExt = $"{frameworkNameWithExt}.dSYM";

            try
            {
                Debug.Log("### Cleaning up after old builds");
                await $" - rf {iosRunnerPath}{frameworkNameWithExt}".Bash("rm");
                await $" - rf {buildPath}".Bash("rm");

                Debug.Log("### BUILDING FOR iOS");
                Debug.Log("### Building for device (Archive)");

                await $"archive -workspace {xcprojectName} -scheme {schemeName} -sdk iphoneos -archivePath {buildPath}/Release-iphoneos.xcarchive ENABLE_BITCODE=NO |xcpretty".Bash("xcodebuild");

                Debug.Log("### Copying framework files");
                await $" -RL {iosArchiveFrameworkPath} {iosRunnerPath}/{frameworkNameWithExt}".Bash("cp");
                await $" -RL {iosArchiveFrameworkPath}/{dysmNameWithExt} {iosRunnerPath}/{dysmNameWithExt}".Bash("cp");
                Debug.Log("### DONE ARCHIVING");
            }
            catch (Exception e)
            {
                Debug.Log(e);
            }


        }

        //#endregion
    }
}
</file>

<file path="unity/yatzy/Assets/FlutterUnityIntegration/Editor/SweetShellHelper.cs">
using System.Diagnostics;
using System.Threading.Tasks;
using System;

public static class SweetShellHelper
{
    public static Task<int> Bash(this string cmd, string fileName)
    {
        var source = new TaskCompletionSource<int>();
        var escapedArgs = cmd.Replace("\"", "\\\"");
        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = $"\"{escapedArgs}\"",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            },
            EnableRaisingEvents = true
        };
        process.Exited += (sender, args) =>
        {
            UnityEngine.Debug.LogWarning(process.StandardError.ReadToEnd());
            UnityEngine.Debug.Log(process.StandardOutput.ReadToEnd());
            if (process.ExitCode == 0)
            {
                source.SetResult(0);
            }
            else
            {
                source.SetException(new Exception($"Command `{cmd}` failed with exit code `{process.ExitCode}`"));
            }

            process.Dispose();
        };

        try
        {
            process.Start();
        }
        catch (Exception e)
        {
            UnityEngine.Debug.LogError(e);
            source.SetException(e);
        }

        return source.Task;
    }
}
</file>

<file path="unity/yatzy/Assets/FlutterUnityIntegration/Editor/XCodePostBuild.cs">
/*
MIT License
Copyright (c) 2021 REX ISAAC RAPHAEL
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#if UNITY_IOS

using System;

using System.Collections.Generic;
using System.IO;

using UnityEditor;
using UnityEditor.Callbacks;
using UnityEditor.iOS.Xcode;
using UnityEngine;

/// <summary>
/// Adding this post build script to Unity project enables the flutter-unity-widget to access it
/// </summary>
public static class XcodePostBuild
{

    /// <summary>
    /// The identifier added to touched file to avoid double edits when building to existing directory without
    /// replace existing content.
    /// </summary>
    private const string TouchedMarker = "https://github.com/juicycleff/flutter-unity-view-widget";

    [PostProcessBuild]
    public static void OnPostBuild(BuildTarget target, string pathToBuiltProject)
    {
        if (target != BuildTarget.iOS)
        {
            return;
        }

        PatchUnityNativeCode(pathToBuiltProject);

        UpdateUnityProjectFiles(pathToBuiltProject);

        UpdateBuildSettings(pathToBuiltProject);
    }

    /// <summary>
    /// We need to set particular build settings on the UnityFramework target.
    /// This includes:
    ///   - skip_install = NO (It is YES by default)
    /// </summary>
    /// <param name="pathToBuildProject"></param>
    private static void UpdateBuildSettings(string pathToBuildProject)
    {
        var pbx = new PBXProject();
        var pbxPath = Path.Combine(pathToBuildProject, "Unity-iPhone.xcodeproj/project.pbxproj");
        pbx.ReadFromFile(pbxPath);

        var targetGuid = pbx.GetUnityFrameworkTargetGuid();
        var projGuid = pbx.ProjectGuid();

        // Set skip_install to NO 
        pbx.SetBuildProperty(targetGuid, "SKIP_INSTALL", "NO");

        // Set some linker flags
        pbx.SetBuildProperty(projGuid, "ENABLE_BITCODE", "YES");

        // Persist changes
        pbx.WriteToFile(pbxPath);
    }

    /// <summary>
    /// We need to add the Data folder to the UnityFramework framework
    /// </summary>
    private static void UpdateUnityProjectFiles(string pathToBuiltProject)
    {
        var pbx = new PBXProject();
        var pbxPath = Path.Combine(pathToBuiltProject, "Unity-iPhone.xcodeproj/project.pbxproj");
        pbx.ReadFromFile(pbxPath);

        // PatchRemoveTargetMembership(pathToBuiltProject);
        // Add unityLibrary/Data
        var targetGuid = pbx.TargetGuidByName("UnityFramework");
        var fileGuid = pbx.AddFolderReference(Path.Combine(pathToBuiltProject, "Data"), "Data");
        pbx.AddFileToBuild(targetGuid, fileGuid);

        pbx.WriteToFile(pbxPath);
    }

    /// <summary>
    /// Make necessary changes to Unity build output that enables it to be embedded into existing Xcode project.
    /// </summary>
    private static void PatchUnityNativeCode(string pathToBuiltProject)
    {
        if (!CheckUnityAppController(Path.Combine(pathToBuiltProject, "Classes/UnityAppController.h")))
        {
            EditUnityAppControllerH(Path.Combine(pathToBuiltProject, "Classes/UnityAppController.h"));
            MarkUnityAppControllerH(Path.Combine(pathToBuiltProject, "Classes/UnityAppController.h"));
        }

        if (!CheckUnityAppController(Path.Combine(pathToBuiltProject, "Classes/UnityAppController.mm")))
        {
            EditUnityAppControllerMM(Path.Combine(pathToBuiltProject, "Classes/UnityAppController.mm"));
            MarkUnityAppControllerMM(Path.Combine(pathToBuiltProject, "Classes/UnityAppController.mm"));
        }
    }

    private static bool MarkUnityAppControllerH(string path)
    {
        var inScope = false;
        var mark = false;
        EditCodeFile(path, line =>
        {
            inScope |= line.Contains("include \"RenderPluginDelegate.h\"");
            if (inScope)
            {
                if (line.Trim() == "")
                {
                    inScope = false;

                    return new string[]
                    {
                        "",
                        "// Edited by " + TouchedMarker,
                        "",
                    };
                }

                return new string[] { line };
            }

            return new string[] { line };
        });
        return mark;
    }

    private static bool MarkUnityAppControllerMM(string path)
    {
        var inScope = false;
        var mark = false;
        EditCodeFile(path, line =>
        {
            inScope |= line.Contains("#include <sys/sysctl.h>");
            if (inScope)
            {
                if (line.Trim() == "")
                {
                    inScope = false;

                    return new string[]
                    {
                        "",
                        "// Edited by " + TouchedMarker,
                        "",
                    };
                }

                return new string[] { line };
            }

            return new string[] { line };
        });
        return mark;
    }
    private static bool CheckUnityAppController(string path)
    {
        var mark = false;
        EditCodeFile(path, line =>
        {
            mark |= line.Contains("// Edited by " + TouchedMarker);
            return new string[] { line };
        });
        return mark;
    }

    /// <summary>
    /// Edit 'UnityAppController.h': returns 'UnityAppController' from 'AppDelegate' class.
    /// </summary>
    private static void EditUnityAppControllerH(string path)
    {
        var inScope = false;
        var markerDetected = false;

        // Modify inline GetAppController
        EditCodeFile(path, line =>
        {
            inScope |= line.Contains("include \"RenderPluginDelegate.h\"");

            if (inScope && !markerDetected)
            {
                if (line.Trim() == "")
                {
                    inScope = false;
                    markerDetected = true;

                    return new string[]
                    {
                        "",
                        "// Added by " + TouchedMarker,
                        "@protocol UnityEventListener <NSObject>",
                        "- (void)onSceneLoaded:(NSString *)name buildIndex:(NSInteger *)bIndex loaded:(bool *)isLoaded valid:(bool *)IsValid;",
                        "- (void)onMessage:(NSString *)message;",
                        "@end",
                        "",
                    };
                }

                return new string[] { line };
            }

            return new string[] { line };
        });

        inScope = false;
        markerDetected = false;

        // Modify inline GetAppController
        EditCodeFile(path, line =>
        {
            inScope |= line.Contains("include \"RenderPluginDelegate.h\"");

            if (inScope && !markerDetected)
            {
                if (line.Trim() == "")
                {
                    inScope = false;
                    markerDetected = true;

                    return new string[]
                    {
                        "",
                        "// Added by " + TouchedMarker,
                        "typedef void(^unitySceneLoadedCallbackType)(const char* name, const int* buildIndex, const bool* isLoaded, const bool* IsValid);",
                        "",
                        "typedef void(^unityMessageCallbackType)(const char* message);",
                        "",
                    };
                }

                return new string[] { line };
            }

            return new string[] { line };
        });

        inScope = false;
        markerDetected = false;

        // Modify inline GetAppController
        EditCodeFile(path, line =>
        {
            inScope |= line.Contains("quitHandler)");

            if (inScope && !markerDetected)
            {
                if (line.Trim() == "")
                {
                    inScope = false;
                    markerDetected = true;

                    return new string[]
                    {
                        "@property (nonatomic, copy)                                 void(^unitySceneLoadedHandler)(const char* name, const int* buildIndex, const bool* isLoaded, const bool* IsValid);",
                        "@property (nonatomic, copy)                                 void(^unityMessageHandler)(const char* message);",
                    };
                }

                return new string[] { line };
            }

            return new string[] { line };
        });

    }

    /// <summary>
    /// Edit 'UnityAppController.mm': triggers 'UnityReady' notification after Unity is actually started.
    /// </summary>
    private static void EditUnityAppControllerMM(string path)
    {

        var inScope = false;
        var markerDetected = false;

        EditCodeFile(path, line =>
        {
            if (line.Trim() == "@end")
            {
                return new string[]
                {
                    "",
                    "// Added by " + TouchedMarker,
                    "extern \"C\" void OnUnityMessage(const char* message)",
                    "{",
                    "    if (GetAppController().unityMessageHandler) {",
                    "        GetAppController().unityMessageHandler(message);",
                    "    }",
                    "}",
                    "",
                    "extern \"C\" void OnUnitySceneLoaded(const char* name, const int* buildIndex, const bool* isLoaded, const bool* IsValid)",
                    "{",
                    "    if (GetAppController().unitySceneLoadedHandler) {",
                    "        GetAppController().unitySceneLoadedHandler(name, buildIndex, isLoaded, IsValid);",
                    "    }",
                    "}",
                    line,

                };
            }

            inScope |= line.Contains("- (void)startUnity:");
            markerDetected |= inScope && line.Contains(TouchedMarker);

            if (inScope && line.Trim() == "}")
            {
                inScope = false;

                if (markerDetected)
                {
                    return new string[] { line };
                }
                else
                {
                    return new string[]
                    {
                        "    // Modified by " + TouchedMarker,
                        @"    [[NSNotificationCenter defaultCenter] postNotificationName: @""UnityReady"" object:self];",
                        "}",
                    };
                }
            }

            return new string[] { line };
        });

    }


    private static void EditCodeFile(string path, Func<string, IEnumerable<string>> lineHandler)
    {
        var bakPath = path + ".bak";
        if (File.Exists(bakPath))
        {
            File.Delete(bakPath);
        }

        File.Move(path, bakPath);

        using (var reader = File.OpenText(bakPath))
        using (var stream = File.Create(path))
        using (var writer = new StreamWriter(stream))
        {
            string line;
            while ((line = reader.ReadLine()) != null)
            {
                var outputs = lineHandler(line);
                foreach (var o in outputs)
                {
                    writer.WriteLine(o);
                }
            }
        }
    }
}

#endif
</file>

<file path="unity/yatzy/Assets/FlutterUnityIntegration/NativeAPI.cs">
using System.Runtime.InteropServices;
using UnityEngine.SceneManagement;
using UnityEngine;
using System;

namespace FlutterUnityIntegration
{
    public class NativeAPI
    {
#if UNITY_IOS && !UNITY_EDITOR
    [DllImport("__Internal")]
    public static extern void OnUnityMessage(string message);

    [DllImport("__Internal")]
    public static extern void OnUnitySceneLoaded(string name, int buildIndex, bool isLoaded, bool IsValid);
#endif

#if UNITY_WEBGL
        [DllImport("__Internal")]
        public static extern void OnUnityMessageWeb(string message);

        [DllImport("__Internal")]
        public static extern void OnUnitySceneLoadedWeb(string name, int buildIndex, bool isLoaded, bool isValid);
#endif

        public static void OnSceneLoaded(Scene scene, LoadSceneMode mode)
        {
#if UNITY_ANDROID
        try
        {
            AndroidJavaClass jc = new AndroidJavaClass("com.xraph.plugin.flutter_unity_widget.UnityPlayerUtils");
            jc.CallStatic("onUnitySceneLoaded", scene.name, scene.buildIndex, scene.isLoaded, scene.IsValid());
        }
        catch (Exception e)
        {
            Debug.Log(e.Message);
        }
#elif UNITY_WEBGL
            OnUnitySceneLoadedWeb(scene.name, scene.buildIndex, scene.isLoaded, scene.IsValid());
#elif UNITY_IOS && !UNITY_EDITOR
        OnUnitySceneLoaded(scene.name, scene.buildIndex, scene.isLoaded, scene.IsValid());
#endif
        }

        public static void SendMessageToFlutter(string message)
        {
#if UNITY_ANDROID
        try
        {
            AndroidJavaClass jc = new AndroidJavaClass("com.xraph.plugin.flutter_unity_widget.UnityPlayerUtils");
            jc.CallStatic("onUnityMessage", message);
        }
        catch (Exception e)
        {
            Debug.Log(e.Message);
        }
#elif UNITY_WEBGL
        OnUnityMessageWeb(message);
#elif UNITY_IOS && !UNITY_EDITOR
        OnUnityMessage(message);
#endif
        }

        public static void ShowHostMainWindow()
        {
#if UNITY_ANDROID
        try
        {
            var jc = new AndroidJavaClass("com.xraph.plugin.flutter_unity_widget.OverrideUnityActivity");
            var overrideActivity = jc.GetStatic<AndroidJavaObject>("instance");
            overrideActivity.Call("showMainActivity");
        }
        catch (Exception e)
        {
            Debug.Log(e.Message);
        }
#elif UNITY_IOS && !UNITY_EDITOR
        // NativeAPI.showHostMainWindow();
#endif
        }

        public static void UnloadMainWindow()
        {
#if UNITY_ANDROID
        try
        {
            AndroidJavaClass jc = new AndroidJavaClass("com.xraph.plugin.flutter_unity_widget.OverrideUnityActivity");
            AndroidJavaObject overrideActivity = jc.GetStatic<AndroidJavaObject>("instance");
            overrideActivity.Call("unloadPlayer");
        }
        catch (Exception e)
        {
            Debug.Log(e.Message);
        }
#elif UNITY_IOS && !UNITY_EDITOR
        // NativeAPI.unloadPlayer();
#endif
        }

        public static void QuitUnityWindow()
        {
#if UNITY_ANDROID
        try
        {
            AndroidJavaClass jc = new AndroidJavaClass("com.xraph.plugin.flutter_unity_widget.OverrideUnityActivity");
            AndroidJavaObject overrideActivity = jc.GetStatic<AndroidJavaObject>("instance");
            overrideActivity.Call("quitPlayer");
        }
        catch (Exception e)
        {
            Debug.Log(e.Message);
        }
#elif UNITY_IOS && !UNITY_EDITOR
        // NativeAPI.quitPlayer();
#endif
        }
    }
}
</file>

<file path="unity/yatzy/Assets/FlutterUnityIntegration/SingletonMonoBehaviour.cs">
using System;
using UnityEngine;

namespace FlutterUnityIntegration
{
    public abstract class SingletonMonoBehaviour<T> : MonoBehaviour where T : MonoBehaviour
    {
        private static readonly Lazy<T> LazyInstance = new Lazy<T>(CreateSingleton);

        public static T Instance => LazyInstance.Value;

        private static T CreateSingleton()
        {
            var ownerObject = new GameObject($"{typeof(T).Name} (singleton)");
            var instance = ownerObject.AddComponent<T>();
            DontDestroyOnLoad(ownerObject);
            return instance;
        }
    }
}
</file>

<file path="unity/yatzy/Assets/FlutterUnityIntegration/UnityMessageManager.cs">
using System;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace FlutterUnityIntegration
{
    public class MessageHandler
    {
        public int id;
        public string seq;

        public String name;
        private readonly JToken data;

        public static MessageHandler Deserialize(string message)
        {
            var m = JObject.Parse(message);
            var handler = new MessageHandler(
                m.GetValue("id").Value<int>(),
                m.GetValue("seq").Value<string>(),
                m.GetValue("name").Value<string>(),
                m.GetValue("data")
            );
            return handler;
        }

        public T getData<T>()
        {
            return data.Value<T>();
        }

        public MessageHandler(int id, string seq, string name, JToken data)
        {
            this.id = id;
            this.seq = seq;
            this.name = name;
            this.data = data;
        }

        public void send(object data)
        {
            var o = JObject.FromObject(new
            {
                id = id,
                seq = "end",
                name = name,
                data = data
            });
            UnityMessageManager.Instance.SendMessageToFlutter(UnityMessageManager.MessagePrefix + o.ToString());
        }
    }

    public class UnityMessage
    {
        public String name;
        public JObject data;
        public Action<object> callBack;
    }

    public class UnityMessageManager : SingletonMonoBehaviour<UnityMessageManager>
    {

        public const string MessagePrefix = "@UnityMessage@";
        private static int ID = 0;

        private static int generateId()
        {
            ID = ID + 1;
            return ID;
        }

        public delegate void MessageDelegate(string message);
        public event MessageDelegate OnMessage;

        public delegate void MessageHandlerDelegate(MessageHandler handler);
        public event MessageHandlerDelegate OnFlutterMessage;

        private readonly Dictionary<int, UnityMessage> waitCallbackMessageMap = new Dictionary<int, UnityMessage>();

        private void Start()
        {
            SceneManager.sceneLoaded += OnSceneLoaded;
        }

        void OnSceneLoaded(Scene scene, LoadSceneMode mode)
        {
            NativeAPI.OnSceneLoaded(scene, mode);

        }

        public void ShowHostMainWindow()
        {
            NativeAPI.ShowHostMainWindow();
        }

        public void UnloadMainWindow()
        {
            NativeAPI.UnloadMainWindow();
        }


        public void QuitUnityWindow()
        {
            NativeAPI.QuitUnityWindow();
        }


        public void SendMessageToFlutter(string message)
        {
            NativeAPI.SendMessageToFlutter(message);
        }

        public void SendMessageToFlutter(UnityMessage message)
        {
            var id = generateId();
            if (message.callBack != null)
            {
                waitCallbackMessageMap.Add(id, message);
            }

            var o = JObject.FromObject(new
            {
                id = id,
                seq = message.callBack != null ? "start" : "",
                name = message.name,
                data = message.data
            });
            UnityMessageManager.Instance.SendMessageToFlutter(MessagePrefix + o.ToString());
        }

        void onMessage(string message)
        {
            OnMessage?.Invoke(message);
        }

        void onFlutterMessage(string message)
        {
            if (message.StartsWith(MessagePrefix))
            {
                message = message.Replace(MessagePrefix, "");
            }
            else
            {
                return;
            }

            var handler = MessageHandler.Deserialize(message);
            if ("end".Equals(handler.seq))
            {
                // handle callback message
                if (!waitCallbackMessageMap.TryGetValue(handler.id, out var m)) return;
                waitCallbackMessageMap.Remove(handler.id);
                m.callBack?.Invoke(handler.getData<object>()); // todo
                return;
            }

            OnFlutterMessage?.Invoke(handler);
        }
    }
}
</file>

<file path="unity/yatzy/Assets/Scripts/CircularMotionScript.cs">
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CircularMotionScript : MonoBehaviour
{
    float timeCounter=0;
    public Color myColor;
    public bool lightMotion;
    Vector3 originalPosition;
    private float speed;
    // Start is called before the first frame update
    void Start()
    {
        speed = 10f;
        originalPosition = transform.position;
        lightMotion = true;
        myColor = new Color(0.15f, 0.10f, 0.0f, 0f);
        // goStartPlane = new GameObject();  
        // goPlane = new GameObject();  
        // goWall1 = new GameObject();  
        // goWall2 = new GameObject();  
        // goStartPlane = GameObject.Find("StartPlane");
        // goPlane = GameObject.Find("Plane");
        // goWall1 = GameObject.Find("Wall1");
        // goWall2 = GameObject.Find("Wall2");
        // meshRendererStartPlane = new MeshRenderer();
        // meshRendererPlane = new MeshRenderer();
        // meshRendererWall1 = new MeshRenderer();
        // meshRendererWall2 = new MeshRenderer();
        // meshRendererStartPlane = goStartPlane.GetComponent<MeshRenderer>();
        // meshRendererPlane = goPlane.GetComponent<MeshRenderer>();
        // meshRendererWall1 = goWall1.GetComponent<MeshRenderer>();
        // meshRendererWall2 = goWall3.GetComponent<MeshRenderer>();

    }

    // Update is called once per frame
    void Update()
    {
        if (lightMotion) {
            timeCounter += Time.deltaTime;

            float x = speed * Mathf.Cos(timeCounter) + originalPosition.x;
            float y = transform.position.y;
            float z = speed * Mathf.Sin(timeCounter) + originalPosition.z;

            transform.position  = new Vector3(x, y, z);
        }

        GameObject.Find("StartPlane").GetComponent<Renderer>().material.color = myColor;
        //GameObject.Find("Wall1").GetComponent<Renderer>().material.color = myColor;
        //GameObject.Find("Wall2").GetComponent<Renderer>().material.color = myColor;
        GameObject.Find("Plane").GetComponent<Renderer>().material.color = myColor;
        // meshRendererStartPlane.material.color = myColor;
        // meshRendererPlane.material.color = myColor;
        // meshRendererWall1.material.color = myColor;
        // meshRendererWall2.material.color = myColor;
    }
}
</file>

<file path="unity/yatzy/Assets/Scripts/Connection.cs">
using System;
using System.Collections;
using System.Collections.Concurrent;
using System.Collections.Generic;
using UnityEngine;

using NativeWebSocket;

public class Connection : MonoBehaviour
{
  WebSocket websocket;
  private readonly ConcurrentQueue<Action> _actions = new ConcurrentQueue<Action>(); 
  bool isOnline = false;
  // Start is called before the first frame update
  async void Start()
  {
    // websocket = new WebSocket("ws://echo.websocket.org");
    websocket = isOnline ? new WebSocket("wss://clientsystem.net/ws") : new WebSocket("ws://localhost:8001");

    websocket.OnOpen += () =>
    {
      Debug.Log("Connection open!");
    };

    websocket.OnError += (e) =>
    {
      Debug.Log("Error! " + e);
    };

    websocket.OnClose += (e) =>
    {
      Debug.Log("Connection closed!");
    };

    websocket.OnMessage += (bytes) =>
    {
      // Reading a plain text message
      var message = System.Text.Encoding.UTF8.GetString(bytes);
      Debug.Log("Received OnMessage! (" + bytes.Length + " bytes) " + message);
      _actions.Enqueue(() => GameObject.Find("GameManager").GetComponent<GameManagerScript>().flutterMessage(message));
    };

    // Keep sending messages at every 0.3s
    //InvokeRepeating("SendWebSocketMessage", 0.0f, 0.3f);

    await websocket.Connect();
  }

  void Update()
  {
    // Work the dispatched actions on the Unity main thread
    while(_actions.Count > 0)
    {
        if(_actions.TryDequeue(out var action))
        {
            action?.Invoke();
        }
    }

    #if !UNITY_WEBGL || UNITY_EDITOR
      websocket.DispatchMessageQueue();
    #endif
  }

  // async void SendWebSocketMessage()
  // {
  //   if (websocket.State == WebSocketState.Open)
  //   {
  //     // Sending bytes
  //     await websocket.Send(new byte[] { 10, 20, 30 });

  //     // Sending plain text
  //     await websocket.SendText("plain text message");
  //   }
  // }

  private async void OnApplicationQuit()
  {
    await websocket.Close();
  }
}
</file>

<file path="unity/yatzy/Assets/Scripts/DiceCheckZoneScript.cs">
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DiceCheckZoneScript : MonoBehaviour {

	private Vector3 vel;
	private Vector3 angVel;

	void OnTriggerStay(Collider col)
	{
		if (col.gameObject.GetComponentInParent<DiceScript>().GetDiceNumber() == 0) {
			vel = col.gameObject.GetComponentInParent<Rigidbody>().linearVelocity;
			angVel = col.gameObject.GetComponentInParent<Rigidbody>().angularVelocity;
			//if (vel.x < 1e-7f && vel.y < 1e-7f && vel.z < 1e-7f && angVel.x < 1e-7f && angVel.y < 1e-7f && angVel.z < 1e-7f)
			if (vel.x == 0f && vel.y == 0f && vel.z == 0f && angVel.x == 0f && angVel.y == 0f && angVel.z == 0f)
			{
				// Check to see rotation in plane direction is multiple of 90 degrees i.e. lies flat.
				Vector3 rot = col.gameObject.GetComponentInParent<Rigidbody>().rotation.eulerAngles;
				
				// Allow up to 25degree deviation it's still clear which side is top, also check for the negative version of angles :)
					if (Mathf.Abs(rot.x % 90.0f) < 35.0f && Mathf.Abs(rot.z % 90.0f) < 35.0f ||
					Mathf.Abs(90f-rot.x % 90.0f) < 35.0f && Mathf.Abs(rot.z % 90.0f) < 35.0f ||
					Mathf.Abs(rot.x % 90.0f) < 35.0f && Mathf.Abs(90f-rot.z % 90.0f) < 35.0f ||
					Mathf.Abs(90f-rot.x % 90.0f) < 35.0f && Mathf.Abs(90f-rot.z % 90.0f) < 35.0f) {
					switch (col.gameObject.name) {
					case "Side1":

						col.gameObject.GetComponentInParent<DiceScript>().SetDiceNumber(6);
						break;
					case "Side2":
						col.gameObject.GetComponentInParent<DiceScript>().SetDiceNumber(5);
						break;
					case "Side3":
						col.gameObject.GetComponentInParent<DiceScript>().SetDiceNumber(4);
						break;
					case "Side4":
						col.gameObject.GetComponentInParent<DiceScript>().SetDiceNumber(3);
						break;
					case "Side5":
						col.gameObject.GetComponentInParent<DiceScript>().SetDiceNumber(2);
						break;
					case "Side6":
						col.gameObject.GetComponentInParent<DiceScript>().SetDiceNumber(1);
						break;
					} 
				} else {
					// Debug.Log("Failed Throw!!!!!!!!!!!!!!!!!!!!!!!");
					// Debug.Log("rot.x: " + rot.x.ToString() + " rot.y: " + rot.y.ToString() + " rot.z: " + rot.z.ToString());
					// Debug.Log(col.gameObject.name);
				}
			}			
		}
	}
}
</file>

<file path="unity/yatzy/Assets/Scripts/DiceScript.cs">
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DiceScript : MonoBehaviour {

	public int diceNumber;
	public Vector3 originalPosition;
	public Vector3 cupPosition;
	public Vector3 startPosition;
	public bool respondsToClicks;
	public bool isGreen;
	public bool isBlue;
	public bool isActive;
	
	void Awake() {
		originalPosition = transform.position;
		diceNumber = 0;
		respondsToClicks = false;
		isActive = false;
	}
	
	
	void Update () {
		
	}

	void OnMouseDown(){
		if (respondsToClicks) {
			if (isGreen) {
				// Put current dice in storage
				transform.position = originalPosition;
				// Move blue dice to start position
				GameObject go = GameObject.Find(transform.name.Replace('G', 'B'));
				go.transform.position = go.GetComponent<DiceScript>().startPosition;
				// rotate it right
				Vector3 rot = transform.rotation.eulerAngles;
                go.transform.rotation = Quaternion.Euler(rot.x, rot.y, rot.z);	
				go.GetComponent<DiceScript>().isActive = true;			
			} else {
				// Put current dice in storage
				transform.position = originalPosition;
				// Move blue dice to start position
				GameObject go = GameObject.Find(transform.name.Replace('B', 'G'));
				go.transform.position = go.GetComponent<DiceScript>().startPosition;
				// rotate it right
				Vector3 rot = transform.rotation.eulerAngles;
                go.transform.rotation = Quaternion.Euler(rot.x, rot.y, rot.z);
				isActive = false;			
			}
		}
	}

	public int GetDiceNumber() {
		return diceNumber;
	}
	public void SetDiceNumber(int number) {
		diceNumber = number;
	}

}
</file>

<file path="unity/yatzy/Assets/Scripts/GameManagerScript.cs">
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using FlutterUnityIntegration;
using Random=UnityEngine.Random;

public class GameManagerScript : MonoBehaviour 
{

    public class jsonCommunicator{
        public string actionUnity;
        public List<int> diceResult;

        public jsonCommunicator(string _actionUnity, List<int> _diceResult) {
            actionUnity = _actionUnity;
            diceResult = new List<int>(_diceResult);
        }
    }

    
    //UnityMessageManager unityMessageManager;
    
    public bool throwDices = false;
    public bool throwActive;

    private static int maxNrDices = 10;
    GameObject []go;
    GameObject []goG;
    GameObject []goB;
    GameObject goSnow;
    bool goSnowActive = false;
    private static List<int> diceResult;
    //private static int []diceResult;
    static Rigidbody rb;
    
    private float c;
    private int nrDices = 5;
    private int nrThrows = 3;
    private int nrThrowsRemaining = 3;
    private Animator animatorCup;
    private Animator animatorCat;
    private Animator animatorDog;
    private float timeFromThrownDices;
    private bool rethrow = false;
    private bool dicesActive = false;
   
    void Start()
    {
        Debug.Log(SystemInfo.graphicsDeviceType);
        gameObject.AddComponent<UnityMessageManager>();
        throwActive = true;
        goSnow = new GameObject();
        goSnow = GameObject.Find("Snow");
        for(int i = 0; i < goSnow.transform.childCount; i++)
        {
            GameObject Go = goSnow.transform.GetChild(i).gameObject;
            Debug.Log(Go.GetComponent<ParticleSystem>().main.startSize.constant);
        }
        goSnow.SetActive(false);
        Time.timeScale = 2f;
        //unityMessageManager = GetComponent<UnityMessageManager>();
        go = new GameObject[maxNrDices];
        goG = new GameObject[maxNrDices];
        goB = new GameObject[maxNrDices];
        diceResult = new List<int>(new int[maxNrDices]);
        
        go[0] = GameObject.Find("Dice1");
        goG[0] = GameObject.Find("DiceG1");
        goB[0] = GameObject.Find("DiceB1");
        for (int i=1; i<maxNrDices; i++) {
            go[i] = GameObject.Find("Dice"+(i+1).ToString());
            goG[i] = GameObject.Find("DiceG"+(i+1).ToString());
            goB[i] = GameObject.Find("DiceB"+(i+1).ToString());
        }

        InitDices();

        float sep = 1.1f;
        float height = 2f;
        go[0].GetComponent<DiceScript>().cupPosition = new Vector3(0,1+height,0);
        go[1].GetComponent<DiceScript>().cupPosition = new Vector3(sep,1+height,0);
        go[2].GetComponent<DiceScript>().cupPosition = new Vector3(-sep,1+height,0);
        go[3].GetComponent<DiceScript>().cupPosition = new Vector3(0,1+height,sep);
        go[4].GetComponent<DiceScript>().cupPosition = new Vector3(0,1+height,-sep);
        go[5].GetComponent<DiceScript>().cupPosition = new Vector3(sep,2+height,sep);
        go[6].GetComponent<DiceScript>().cupPosition = new Vector3(-sep,2+height,sep);
        go[7].GetComponent<DiceScript>().cupPosition = new Vector3(sep,2+height,-sep);
        go[8].GetComponent<DiceScript>().cupPosition = new Vector3(-sep,2+height,-sep);
        go[9].GetComponent<DiceScript>().cupPosition = new Vector3(0,4+height,0);

        // anim = GameObject.Find("Empire_Cup").GetComponent<Animator>();
        animatorCup = GameObject.Find("Empire_Cup").GetComponent<Animator>();
        animatorCup.speed = 1f;
        animatorCat = GameObject.Find("cat_Walk").GetComponent<Animator>();
        animatorCat.Play("Walk");
        animatorDog = GameObject.Find("DogPBR").GetComponent<Animator>();
        animatorDog.Play("Attack01");
        Physics.gravity = new Vector3(0, -20f, 0);
    }

    void InitDices(bool initRotation = true) {

        // Reset all positions first
        for (int i=0; i<maxNrDices; i++) {
            go[i].transform.position = go[i].GetComponent<DiceScript>().originalPosition;
            goG[i].transform.position = goG[i].GetComponent<DiceScript>().originalPosition;
            goB[i].transform.position = goB[i].GetComponent<DiceScript>().originalPosition;
        }

        float c = (20f - nrDices) / (nrDices + 1f);
        go[0].transform.position = new Vector3(GameObject.Find("StartPlane").transform.position.x, 
                                                GameObject.Find("StartPlane").transform.position.y+2.5f, 
                                                GameObject.Find("StartPlane").transform.position.z+c+0.5f-10f);
        if (initRotation){
            go[0].transform.rotation = Quaternion.Euler(0f, 90f, 0f);
        }                                        
        
        go[0].GetComponent<DiceScript>().startPosition = go[0].transform.position;
        goG[0].GetComponent<DiceScript>().startPosition = go[0].transform.position;
        goB[0].GetComponent<DiceScript>().startPosition = go[0].transform.position;
        goB[0].GetComponent<DiceScript>().isActive = false;
        
        for (int i=1; i<nrDices; i++) {
            go[i].transform.position = new Vector3(go[i-1].transform.position.x, go[i-1].transform.position.y, go[i-1].transform.position.z + 1 + c );
            if (initRotation){
                go[i].transform.rotation = Quaternion.Euler(0f, 90f, 0f);
            }
            go[i].GetComponent<DiceScript>().startPosition = go[i].transform.position;
            goG[i].GetComponent<DiceScript>().startPosition = go[i].transform.position;
            goB[i].GetComponent<DiceScript>().startPosition = go[i].transform.position;
            goB[i].GetComponent<DiceScript>().isActive = false;
        }

        for (int i=0; i<nrDices; i++) {
            diceResult[i] = 0; 
        }
    }

    void SetDices(List<int> dices) {
        for(var i=0;i<dices.Count;i++) {
            go[i].transform.rotation = Quaternion.Euler(0f, 90f, 0f);
            switch (dices[i]) {
                case 1:
                    go[i].transform.rotation = Quaternion.Euler(90f, 90f, 0f);
                    break;
                case 2:
                    go[i].transform.rotation = Quaternion.Euler(0f, 90f, 270f);
                    break;
                case 4:
                    go[i].transform.rotation = Quaternion.Euler(180f, 90f, 0f);
                    break;
                case 5:
                    go[i].transform.rotation = Quaternion.Euler(0f, 90f, 90f);
                    break;
                case 6:
                    go[i].transform.rotation = Quaternion.Euler(270f, 90f, 0f);
                    break;
            }
        }
    }
    
    void Update()
    {

        bool isFinished = true;
        for (int i=0; i<nrDices; i++) {
            diceResult[i] = go[i].GetComponent<DiceScript>().GetDiceNumber();
            isFinished = isFinished && diceResult[i] != 0;
        }

        if (isFinished && dicesActive && !rethrow) {
            dicesActive = false;
            for (int i=0; i<nrDices; i++) {
                // Position green dices on start bar if not HOLD i.e blue dice there
                if (!goB[i].GetComponent<DiceScript>().isActive) {
                    //rb = goB[i].GetComponent<Rigidbody>();
                    //rb.angularVelocity = new Vector3(0, 0, 0);
                    goG[i].transform.position = goG[i].GetComponent<DiceScript>().startPosition;
                    Vector3 rot = go[i].GetComponentInParent<Rigidbody>().rotation.eulerAngles;
                    goG[i].transform.rotation = Quaternion.Euler(rot.x, 90f, rot.z);
                    goG[i].GetComponent<DiceScript>().respondsToClicks = true;
                    goB[i].GetComponent<DiceScript>().respondsToClicks = true;
                } 
            }
            var json = new jsonCommunicator("results", diceResult.GetRange(0,nrDices));

            string jsonStr = JsonConvert.SerializeObject(json).ToString();
            nrThrowsRemaining -= 1;
            if (nrThrowsRemaining == 0) {
                InitDices(false);  
                throwActive = false;                      
            }
            UnityMessageManager.Instance.SendMessageToFlutter(jsonStr); 
        }

       
        // Put Dices in Cup
        if ((Time.time - timeFromThrownDices > 7f) && dicesActive || (throwDices && nrThrowsRemaining > 0) || Input.GetKeyDown (KeyCode.O)) {
           Debug.Log(Time.time - timeFromThrownDices);
            dicesActive = true;
            throwDices = false;
            for (int i = 0; i < nrDices; i++) {
                // Check to see which blue dice is on start block HOLD them i.e put corresponding red in storage
                // If not blue put green dice in storage and red in cup
                if (goB[i].GetComponent<DiceScript>().isActive) {
                    go[i].transform.position = go[i].GetComponent<DiceScript>().originalPosition;
                } else {
                    goG[i].transform.position = goG[i].GetComponent<DiceScript>().originalPosition;
                    go[i].transform.position = go[i].GetComponent<DiceScript>().cupPosition + GameObject.Find("Empire_Cup").transform.position;
                    go[i].transform.rotation = Quaternion.identity;
                    rb = go[i].GetComponent<Rigidbody>();
                    rb.angularVelocity = new Vector3(Random.Range (50, 80), Random.Range (50, 80), Random.Range (50, 80));
                    go[i].GetComponent<DiceScript>().SetDiceNumber(0);
                    diceResult[i] = 0;
                }
            }
            
            animatorCup.Play("move");
            timeFromThrownDices = Time.time;
            rethrow = false;
        }
    }

    public void SetNrDices(string strNrDices) {
        nrDices = int.Parse(strNrDices);
        InitDices();
    }
    public void flutterMessage(String json) {
        GameObject localGameObject = new GameObject();
        Debug.Log(json);
        JObject o = JObject.Parse(json);
        Debug.Log(o);
        string action = (string)o["actionUnity"];
        if (action == "unityIdentifier") {
            UnityMessageManager.Instance.SendMessageToFlutter(json);
        } else if (action == "throwDices") {
            throwDices = true;
        } else if (action == "start") {
            Debug.Log("start");
            throwActive = true;
        } else if (action == "reset") {
            nrDices = (int)o["nrDices"];
            nrThrows = (int)o["nrThrows"];
            nrThrowsRemaining = nrThrows;
            InitDices();
            throwActive = false;
        } else if (action == "setProperty") {
            string property = (string)o["property"];
            
            localGameObject = GameObject.Find("CircleLight");
            switch(property){
                case "Color":
                    localGameObject.GetComponent<CircularMotionScript>().myColor = new Color((float)o["colors"][0], (float)o["colors"][1], (float)o["colors"][2], (float)o["colors"][3]);
                break;
                case "Transparency":
                    //localGameObject.GetComponent<CircularMotionScript>().transparentMode = (bool)o["bool"];
                    Debug.Log((bool)o["bool"]);
                    //Debug.Log(localGameObject.GetComponent<CircularMotionScript>().transparentMode);
                break;
                case "LightMotion":
                    localGameObject.GetComponent<CircularMotionScript>().lightMotion = (bool)o["bool"];
                    Debug.Log((bool)o["bool"]);
                    Debug.Log(localGameObject.GetComponent<CircularMotionScript>().lightMotion);
                break;
                case "Dices":
                    InitDices();
                    var temp = (JArray)o["Dices"];
                    Debug.Log(temp);
                    List<int> gotDices = new List<int>(new int[temp.Count]);
                    
                    for(var i=0;i<temp.Count;i++){
                        gotDices[i] = (int)o["Dices"][i];
                    }
                    Debug.Log(gotDices);
                    SetDices(gotDices);
                    break;
                case "SnowEffect":
                    
                    goSnowActive = (bool)o["bool"];
                    goSnow.SetActive(goSnowActive);
                    break;

            }
           
        }
      
    }

   }
</file>

<file path="unity/yatzy/Assets/Scripts/ThrowDices.cs">
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ThrowDices : MonoBehaviour
{
    GameObject gameManager;
    // Start is called before the first frame update
    void Awake()
    {
        gameManager = GameObject.Find("GameManager");
    }
    void OnMouseDown(){
        Debug.Log("MouseDown");
            
        if (gameManager.GetComponent<GameManagerScript>().throwActive) {
            gameManager.GetComponent<GameManagerScript>().throwDices = true;
        }
    }
    // Update is called once per frame
    void Update()
    {
        
    }
}
</file>

<file path="unity/yatzy/Assets/WebSocket/WebSocket.cs">
using System;
using System.Collections.Generic;
using System.IO;
using System.Net.WebSockets;
using System.Runtime.CompilerServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using AOT;
using System.Runtime.InteropServices;
using UnityEngine;
using System.Collections;

public class MainThreadUtil : MonoBehaviour
{
    public static MainThreadUtil Instance { get; private set; }
    public static SynchronizationContext synchronizationContext { get; private set; }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
    public static void Setup()
    {
        Instance = new GameObject("MainThreadUtil")
            .AddComponent<MainThreadUtil>();
        synchronizationContext = SynchronizationContext.Current;
    }

    public static void Run(IEnumerator waitForUpdate)
    {
        synchronizationContext.Post(_ => Instance.StartCoroutine(
                    waitForUpdate), null);
    }

    void Awake()
    {
        gameObject.hideFlags = HideFlags.HideAndDontSave;
        DontDestroyOnLoad(gameObject);
    }
}

public class WaitForUpdate : CustomYieldInstruction
{
    public override bool keepWaiting
    {
        get { return false; }
    }

    public MainThreadAwaiter GetAwaiter()
    {
        var awaiter = new MainThreadAwaiter();
        MainThreadUtil.Run(CoroutineWrapper(this, awaiter));
        return awaiter;
    }

    public class MainThreadAwaiter : INotifyCompletion
    {
        Action continuation;

        public bool IsCompleted { get; set; }

        public void GetResult() { }

        public void Complete()
        {
            IsCompleted = true;
            continuation?.Invoke();
        }

        void INotifyCompletion.OnCompleted(Action continuation)
        {
            this.continuation = continuation;
        }
    }

    public static IEnumerator CoroutineWrapper(IEnumerator theWorker, MainThreadAwaiter awaiter)
    {
        yield return theWorker;
        awaiter.Complete();
    }
}

namespace NativeWebSocket
{
    public delegate void WebSocketOpenEventHandler();
    public delegate void WebSocketMessageEventHandler(byte[] data);
    public delegate void WebSocketErrorEventHandler(string errorMsg);
    public delegate void WebSocketCloseEventHandler(WebSocketCloseCode closeCode);

    public enum WebSocketCloseCode
    {
        /* Do NOT use NotSet - it's only purpose is to indicate that the close code cannot be parsed. */
        NotSet = 0,
        Normal = 1000,
        Away = 1001,
        ProtocolError = 1002,
        UnsupportedData = 1003,
        Undefined = 1004,
        NoStatus = 1005,
        Abnormal = 1006,
        InvalidData = 1007,
        PolicyViolation = 1008,
        TooBig = 1009,
        MandatoryExtension = 1010,
        ServerError = 1011,
        TlsHandshakeFailure = 1015
    }

    public enum WebSocketState
    {
        Connecting,
        Open,
        Closing,
        Closed
    }

    public interface IWebSocket
    {
        event WebSocketOpenEventHandler OnOpen;
        event WebSocketMessageEventHandler OnMessage;
        event WebSocketErrorEventHandler OnError;
        event WebSocketCloseEventHandler OnClose;

        WebSocketState State { get; }
    }

    public static class WebSocketHelpers
    {
        public static WebSocketCloseCode ParseCloseCodeEnum(int closeCode)
        {

            if (WebSocketCloseCode.IsDefined(typeof(WebSocketCloseCode), closeCode))
            {
                return (WebSocketCloseCode)closeCode;
            }
            else
            {
                return WebSocketCloseCode.Undefined;
            }

        }

        public static WebSocketException GetErrorMessageFromCode(int errorCode, Exception inner)
        {
            switch (errorCode)
            {
                case -1:
                    return new WebSocketUnexpectedException("WebSocket instance not found.", inner);
                case -2:
                    return new WebSocketInvalidStateException("WebSocket is already connected or in connecting state.", inner);
                case -3:
                    return new WebSocketInvalidStateException("WebSocket is not connected.", inner);
                case -4:
                    return new WebSocketInvalidStateException("WebSocket is already closing.", inner);
                case -5:
                    return new WebSocketInvalidStateException("WebSocket is already closed.", inner);
                case -6:
                    return new WebSocketInvalidStateException("WebSocket is not in open state.", inner);
                case -7:
                    return new WebSocketInvalidArgumentException("Cannot close WebSocket. An invalid code was specified or reason is too long.", inner);
                default:
                    return new WebSocketUnexpectedException("Unknown error.", inner);
            }
        }
    }

    public class WebSocketException : Exception
    {
        public WebSocketException() { }
        public WebSocketException(string message) : base(message) { }
        public WebSocketException(string message, Exception inner) : base(message, inner) { }
    }

    public class WebSocketUnexpectedException : WebSocketException
    {
        public WebSocketUnexpectedException() { }
        public WebSocketUnexpectedException(string message) : base(message) { }
        public WebSocketUnexpectedException(string message, Exception inner) : base(message, inner) { }
    }

    public class WebSocketInvalidArgumentException : WebSocketException
    {
        public WebSocketInvalidArgumentException() { }
        public WebSocketInvalidArgumentException(string message) : base(message) { }
        public WebSocketInvalidArgumentException(string message, Exception inner) : base(message, inner) { }
    }

    public class WebSocketInvalidStateException : WebSocketException
    {
        public WebSocketInvalidStateException() { }
        public WebSocketInvalidStateException(string message) : base(message) { }
        public WebSocketInvalidStateException(string message, Exception inner) : base(message, inner) { }
    }

    public class WaitForBackgroundThread
    {
        public ConfiguredTaskAwaitable.ConfiguredTaskAwaiter GetAwaiter()
        {
            return Task.Run(() => { }).ConfigureAwait(false).GetAwaiter();
        }
    }

#if UNITY_WEBGL && !UNITY_EDITOR

  /// <summary>
  /// WebSocket class bound to JSLIB.
  /// </summary>
  public class WebSocket : IWebSocket {

    /* WebSocket JSLIB functions */
    [DllImport ("__Internal")]
    public static extern int WebSocketConnect (int instanceId);

    [DllImport ("__Internal")]
    public static extern int WebSocketClose (int instanceId, int code, string reason);

    [DllImport ("__Internal")]
    public static extern int WebSocketSend (int instanceId, byte[] dataPtr, int dataLength);

    [DllImport ("__Internal")]
    public static extern int WebSocketSendText (int instanceId, string message);

    [DllImport ("__Internal")]
    public static extern int WebSocketGetState (int instanceId);

    protected int instanceId;

    public event WebSocketOpenEventHandler OnOpen;
    public event WebSocketMessageEventHandler OnMessage;
    public event WebSocketErrorEventHandler OnError;
    public event WebSocketCloseEventHandler OnClose;

    public WebSocket (string url, Dictionary<string, string> headers = null) {
      if (!WebSocketFactory.isInitialized) {
        WebSocketFactory.Initialize ();
      }

      int instanceId = WebSocketFactory.WebSocketAllocate (url);
      WebSocketFactory.instances.Add (instanceId, this);

      this.instanceId = instanceId;
    }

    public WebSocket (string url, string subprotocol, Dictionary<string, string> headers = null) {
      if (!WebSocketFactory.isInitialized) {
        WebSocketFactory.Initialize ();
      }

      int instanceId = WebSocketFactory.WebSocketAllocate (url);
      WebSocketFactory.instances.Add (instanceId, this);

      WebSocketFactory.WebSocketAddSubProtocol(instanceId, subprotocol);

      this.instanceId = instanceId;
    }

    public WebSocket (string url, List<string> subprotocols, Dictionary<string, string> headers = null) {
      if (!WebSocketFactory.isInitialized) {
        WebSocketFactory.Initialize ();
      }

      int instanceId = WebSocketFactory.WebSocketAllocate (url);
      WebSocketFactory.instances.Add (instanceId, this);

      foreach (string subprotocol in subprotocols) {
        WebSocketFactory.WebSocketAddSubProtocol(instanceId, subprotocol);
      }

      this.instanceId = instanceId;
    }

    ~WebSocket () {
      WebSocketFactory.HandleInstanceDestroy (this.instanceId);
    }

    public int GetInstanceId () {
      return this.instanceId;
    }

    public Task Connect () {
      int ret = WebSocketConnect (this.instanceId);

      if (ret < 0)
        throw WebSocketHelpers.GetErrorMessageFromCode (ret, null);

      return Task.CompletedTask;
    }

	public void CancelConnection () {
		if (State == WebSocketState.Open)
			Close (WebSocketCloseCode.Abnormal);
	}

    public Task Close (WebSocketCloseCode code = WebSocketCloseCode.Normal, string reason = null) {
      int ret = WebSocketClose (this.instanceId, (int) code, reason);

      if (ret < 0)
        throw WebSocketHelpers.GetErrorMessageFromCode (ret, null);

      return Task.CompletedTask;
    }

    public Task Send (byte[] data) {
      int ret = WebSocketSend (this.instanceId, data, data.Length);

      if (ret < 0)
        throw WebSocketHelpers.GetErrorMessageFromCode (ret, null);

      return Task.CompletedTask;
    }

    public Task SendText (string message) {
      int ret = WebSocketSendText (this.instanceId, message);

      if (ret < 0)
        throw WebSocketHelpers.GetErrorMessageFromCode (ret, null);

      return Task.CompletedTask;
    }

    public WebSocketState State {
      get {
        int state = WebSocketGetState (this.instanceId);

        if (state < 0)
          throw WebSocketHelpers.GetErrorMessageFromCode (state, null);

        switch (state) {
          case 0:
            return WebSocketState.Connecting;

          case 1:
            return WebSocketState.Open;

          case 2:
            return WebSocketState.Closing;

          case 3:
            return WebSocketState.Closed;

          default:
            return WebSocketState.Closed;
        }
      }
    }

    public void DelegateOnOpenEvent () {
      this.OnOpen?.Invoke ();
    }

    public void DelegateOnMessageEvent (byte[] data) {
      this.OnMessage?.Invoke (data);
    }

    public void DelegateOnErrorEvent (string errorMsg) {
      this.OnError?.Invoke (errorMsg);
    }

    public void DelegateOnCloseEvent (int closeCode) {
      this.OnClose?.Invoke (WebSocketHelpers.ParseCloseCodeEnum (closeCode));
    }

  }

#else

    public class WebSocket : IWebSocket
    {
        public event WebSocketOpenEventHandler OnOpen;
        public event WebSocketMessageEventHandler OnMessage;
        public event WebSocketErrorEventHandler OnError;
        public event WebSocketCloseEventHandler OnClose;

        private Uri uri;
        private Dictionary<string, string> headers;
        private List<string> subprotocols;
        private ClientWebSocket m_Socket = new ClientWebSocket();

        private CancellationTokenSource m_TokenSource;
        private CancellationToken m_CancellationToken;

        private readonly object OutgoingMessageLock = new object();
        private readonly object IncomingMessageLock = new object();

        private bool isSending = false;
        private List<ArraySegment<byte>> sendBytesQueue = new List<ArraySegment<byte>>();
        private List<ArraySegment<byte>> sendTextQueue = new List<ArraySegment<byte>>();

        public WebSocket(string url, Dictionary<string, string> headers = null)
        {
            uri = new Uri(url);

            if (headers == null)
            {
                this.headers = new Dictionary<string, string>();
            }
            else
            {
                this.headers = headers;
            }

            subprotocols = new List<string>();

            string protocol = uri.Scheme;
            if (!protocol.Equals("ws") && !protocol.Equals("wss"))
                throw new ArgumentException("Unsupported protocol: " + protocol);
        }

        public WebSocket(string url, string subprotocol, Dictionary<string, string> headers = null)
        {
            uri = new Uri(url);

            if (headers == null)
            {
                this.headers = new Dictionary<string, string>();
            }
            else
            {
                this.headers = headers;
            }

            subprotocols = new List<string> {subprotocol};

            string protocol = uri.Scheme;
            if (!protocol.Equals("ws") && !protocol.Equals("wss"))
                throw new ArgumentException("Unsupported protocol: " + protocol);
        }

        public WebSocket(string url, List<string> subprotocols, Dictionary<string, string> headers = null)
        {
            uri = new Uri(url);

            if (headers == null)
            {
                this.headers = new Dictionary<string, string>();
            }
            else
            {
                this.headers = headers;
            }

            this.subprotocols = subprotocols;

            string protocol = uri.Scheme;
            if (!protocol.Equals("ws") && !protocol.Equals("wss"))
                throw new ArgumentException("Unsupported protocol: " + protocol);
        }

        public void CancelConnection()
        {
            m_TokenSource?.Cancel();
        }

        public async Task Connect()
        {
            try
            {
                m_TokenSource = new CancellationTokenSource();
                m_CancellationToken = m_TokenSource.Token;

                m_Socket = new ClientWebSocket();

                foreach (var header in headers)
                {
                    m_Socket.Options.SetRequestHeader(header.Key, header.Value);
                }

                foreach (string subprotocol in subprotocols) {
                    m_Socket.Options.AddSubProtocol(subprotocol);
                }

                await m_Socket.ConnectAsync(uri, m_CancellationToken);
                OnOpen?.Invoke();

                await Receive();
            }
            catch (Exception ex)
            {
                OnError?.Invoke(ex.Message);
                OnClose?.Invoke(WebSocketCloseCode.Abnormal);
            }
            finally
            {
                if (m_Socket != null)
                {
                    m_TokenSource.Cancel();
                    m_Socket.Dispose();
                }
            }
        }

        public WebSocketState State
        {
            get
            {
                switch (m_Socket.State)
                {
                    case System.Net.WebSockets.WebSocketState.Connecting:
                        return WebSocketState.Connecting;

                    case System.Net.WebSockets.WebSocketState.Open:
                        return WebSocketState.Open;

                    case System.Net.WebSockets.WebSocketState.CloseSent:
                    case System.Net.WebSockets.WebSocketState.CloseReceived:
                        return WebSocketState.Closing;

                    case System.Net.WebSockets.WebSocketState.Closed:
                        return WebSocketState.Closed;

                    default:
                        return WebSocketState.Closed;
                }
            }
        }

        public Task Send(byte[] bytes)
        {
            // return m_Socket.SendAsync(buffer, WebSocketMessageType.Binary, true, CancellationToken.None);
            return SendMessage(sendBytesQueue, WebSocketMessageType.Binary, new ArraySegment<byte>(bytes));
        }

        public Task SendText(string message)
        {
            var encoded = Encoding.UTF8.GetBytes(message);

            // m_Socket.SendAsync(buffer, WebSocketMessageType.Text, true, CancellationToken.None);
            return SendMessage(sendTextQueue, WebSocketMessageType.Text, new ArraySegment<byte>(encoded, 0, encoded.Length));
        }

        private async Task SendMessage(List<ArraySegment<byte>> queue, WebSocketMessageType messageType, ArraySegment<byte> buffer)
        {
            // Return control to the calling method immediately.
            // await Task.Yield ();

            // Make sure we have data.
            if (buffer.Count == 0)
            {
                return;
            }

            // The state of the connection is contained in the context Items dictionary.
            bool sending;

            lock (OutgoingMessageLock)
            {
                sending = isSending;

                // If not, we are now.
                if (!isSending)
                {
                    isSending = true;
                }
            }

            if (!sending)
            {
                // Lock with a timeout, just in case.
                if (!Monitor.TryEnter(m_Socket, 1000))
                {
                    // If we couldn't obtain exclusive access to the socket in one second, something is wrong.
                    await m_Socket.CloseAsync(WebSocketCloseStatus.InternalServerError, string.Empty, m_CancellationToken);
                    return;
                }

                try
                {
                    // Send the message synchronously.
                    var t = m_Socket.SendAsync(buffer, messageType, true, m_CancellationToken);
                    t.Wait(m_CancellationToken);
                }
                finally
                {
                    Monitor.Exit(m_Socket);
                }

                // Note that we've finished sending.
                lock (OutgoingMessageLock)
                {
                    isSending = false;
                }

                // Handle any queued messages.
                await HandleQueue(queue, messageType);
            }
            else
            {
                // Add the message to the queue.
                lock (OutgoingMessageLock)
                {
                    queue.Add(buffer);
                }
            }
        }

        private async Task HandleQueue(List<ArraySegment<byte>> queue, WebSocketMessageType messageType)
        {
            var buffer = new ArraySegment<byte>();
            lock (OutgoingMessageLock)
            {
                // Check for an item in the queue.
                if (queue.Count > 0)
                {
                    // Pull it off the top.
                    buffer = queue[0];
                    queue.RemoveAt(0);
                }
            }

            // Send that message.
            if (buffer.Count > 0)
            {
                await SendMessage(queue, messageType, buffer);
            }
        }

        private List<byte[]> m_MessageList = new List<byte[]>();

        // simple dispatcher for queued messages.
        public void DispatchMessageQueue()
        {
            if (m_MessageList.Count == 0)
            {
                return;
            }

            List<byte[]> messageListCopy;

            lock (IncomingMessageLock)
            {
                messageListCopy = new List<byte[]>(m_MessageList);
                m_MessageList.Clear();
            }

            var len = messageListCopy.Count;
            for (int i = 0; i < len; i++)
            {
                OnMessage?.Invoke(messageListCopy[i]);
            }
        }

        public async Task Receive()
        {
            WebSocketCloseCode closeCode = WebSocketCloseCode.Abnormal;
            await new WaitForBackgroundThread();

            ArraySegment<byte> buffer = new ArraySegment<byte>(new byte[8192]);
            try
            {
                while (m_Socket.State == System.Net.WebSockets.WebSocketState.Open)
                {
                    WebSocketReceiveResult result = null;

                    using (var ms = new MemoryStream())
                    {
                        do
                        {
                            result = await m_Socket.ReceiveAsync(buffer, m_CancellationToken);
                            ms.Write(buffer.Array, buffer.Offset, result.Count);
                        }
                        while (!result.EndOfMessage);

                        ms.Seek(0, SeekOrigin.Begin);

                        if (result.MessageType == WebSocketMessageType.Text)
                        {
                            lock (IncomingMessageLock)
                            {
                              m_MessageList.Add(ms.ToArray());
                            }

                            //using (var reader = new StreamReader(ms, Encoding.UTF8))
                            //{
                            //	string message = reader.ReadToEnd();
                            //	OnMessage?.Invoke(this, new MessageEventArgs(message));
                            //}
                        }
                        else if (result.MessageType == WebSocketMessageType.Binary)
                        {
                            lock (IncomingMessageLock)
                            {
                              m_MessageList.Add(ms.ToArray());
                            }
                        }
                        else if (result.MessageType == WebSocketMessageType.Close)
                        {
                            await Close();
                            closeCode = WebSocketHelpers.ParseCloseCodeEnum((int)result.CloseStatus);
                            break;
                        }
                    }
                }
            }
            catch (Exception)
            {
                m_TokenSource.Cancel();
            }
            finally
            {
                await new WaitForUpdate();
                OnClose?.Invoke(closeCode);
            }
        }

        public async Task Close()
        {
            if (State == WebSocketState.Open)
            {
                await m_Socket.CloseAsync(WebSocketCloseStatus.NormalClosure, string.Empty, m_CancellationToken);
            }
        }
    }
#endif

    ///
    /// Factory
    ///

    /// <summary>
    /// Class providing static access methods to work with JSLIB WebSocket or WebSocketSharp interface
    /// </summary>
    public static class WebSocketFactory
    {

#if UNITY_WEBGL && !UNITY_EDITOR
    /* Map of websocket instances */
    public static Dictionary<Int32, WebSocket> instances = new Dictionary<Int32, WebSocket> ();

    /* Delegates */
    public delegate void OnOpenCallback (int instanceId);
    public delegate void OnMessageCallback (int instanceId, System.IntPtr msgPtr, int msgSize);
    public delegate void OnErrorCallback (int instanceId, System.IntPtr errorPtr);
    public delegate void OnCloseCallback (int instanceId, int closeCode);

    /* WebSocket JSLIB callback setters and other functions */
    [DllImport ("__Internal")]
    public static extern int WebSocketAllocate (string url);

    [DllImport ("__Internal")]
    public static extern int WebSocketAddSubProtocol (int instanceId, string subprotocol);

    [DllImport ("__Internal")]
    public static extern void WebSocketFree (int instanceId);

    [DllImport ("__Internal")]
    public static extern void WebSocketSetOnOpen (OnOpenCallback callback);

    [DllImport ("__Internal")]
    public static extern void WebSocketSetOnMessage (OnMessageCallback callback);

    [DllImport ("__Internal")]
    public static extern void WebSocketSetOnError (OnErrorCallback callback);

    [DllImport ("__Internal")]
    public static extern void WebSocketSetOnClose (OnCloseCallback callback);

    /* If callbacks was initialized and set */
    public static bool isInitialized = false;

    /*
     * Initialize WebSocket callbacks to JSLIB
     */
    public static void Initialize () {

      WebSocketSetOnOpen (DelegateOnOpenEvent);
      WebSocketSetOnMessage (DelegateOnMessageEvent);
      WebSocketSetOnError (DelegateOnErrorEvent);
      WebSocketSetOnClose (DelegateOnCloseEvent);

      isInitialized = true;

    }

    /// <summary>
    /// Called when instance is destroyed (by destructor)
    /// Method removes instance from map and free it in JSLIB implementation
    /// </summary>
    /// <param name="instanceId">Instance identifier.</param>
    public static void HandleInstanceDestroy (int instanceId) {

      instances.Remove (instanceId);
      WebSocketFree (instanceId);

    }

    [MonoPInvokeCallback (typeof (OnOpenCallback))]
    public static void DelegateOnOpenEvent (int instanceId) {

      WebSocket instanceRef;

      if (instances.TryGetValue (instanceId, out instanceRef)) {
        instanceRef.DelegateOnOpenEvent ();
      }

    }

    [MonoPInvokeCallback (typeof (OnMessageCallback))]
    public static void DelegateOnMessageEvent (int instanceId, System.IntPtr msgPtr, int msgSize) {

      WebSocket instanceRef;

      if (instances.TryGetValue (instanceId, out instanceRef)) {
        byte[] msg = new byte[msgSize];
        Marshal.Copy (msgPtr, msg, 0, msgSize);

        instanceRef.DelegateOnMessageEvent (msg);
      }

    }

    [MonoPInvokeCallback (typeof (OnErrorCallback))]
    public static void DelegateOnErrorEvent (int instanceId, System.IntPtr errorPtr) {

      WebSocket instanceRef;

      if (instances.TryGetValue (instanceId, out instanceRef)) {

        string errorMsg = Marshal.PtrToStringAuto (errorPtr);
        instanceRef.DelegateOnErrorEvent (errorMsg);

      }

    }

    [MonoPInvokeCallback (typeof (OnCloseCallback))]
    public static void DelegateOnCloseEvent (int instanceId, int closeCode) {

      WebSocket instanceRef;

      if (instances.TryGetValue (instanceId, out instanceRef)) {
        instanceRef.DelegateOnCloseEvent (closeCode);
      }

    }
#endif

        /// <summary>
        /// Create WebSocket client instance
        /// </summary>
        /// <returns>The WebSocket instance.</returns>
        /// <param name="url">WebSocket valid URL.</param>
        public static WebSocket CreateInstance(string url)
        {
            return new WebSocket(url);
        }

    }

}
</file>

</files>
