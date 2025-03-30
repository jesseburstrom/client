## Jesseburstrom Client/Server Codebase Analysis (Dependency Graphs)

**Objective:** Provide a compact overview of class/function relationships and dependencies, including file references, suitable for AI parsing.

---
### Backend (Node.js / TypeScript - ./backend/)
---

**1. Entry Point & Core Setup (`server.ts`)**
   - **File:** `backend/src/server.ts`
   - **Responsibilities:** Initializes Express app, HTTP server, Socket.IO server, CORS, static file serving, connects to DB, instantiates services/controllers, sets up core Socket.IO event listeners (`connect`, `disconnect`).
   - **Dependencies:**
     - `express`, `cors`, `http`, `socket.io`, `path` (Node modules)
     - `./db.ts` -> `initializeDbConnection`
     - `./routes/index.ts` -> `routes()`
     - `./services/GameService.ts` -> `GameService`
     - `./services/GameLogService.ts` -> `GameLogService`
     - `./controllers/GameController.ts` -> `GameController`
     - `./controllers/PlayerController.ts` -> `PlayerController`
     - `./controllers/ChatController.ts` -> `ChatController`
     - `./routes/spectateGameRoute.ts` -> `spectateGameRoute`, `initializeSpectateRoute`
   - **Interactions:**
     - Calls `initializeDbConnection()`.
     - Iterates `routes()` -> `app[method](path, handler)`.
     - Instantiates `GameLogService`.
     - Instantiates `GameService` (passes `io`, `gameLogService`).
     - Instantiates Controllers (passes `gameService`, `gameLogService`, `io`).
     - Calls `initializeSpectateRoute()` (passes services).
     - `io.on('connect', ...)`: Sets up socket listeners.
       - Calls `controller.registerSocketHandlers(socket)` for each controller.
       - Calls `gameService.handlePlayerDisconnect(socket.id)` on disconnect.

**2. Database (`db.ts`)**
   - **File:** `backend/src/db.ts`
   - **Responsibilities:** Manages MongoDB connection.
   - **Exports:**
     - `initializeDbConnection`: Connects to MongoDB.
     - `getDbConnection`: Returns a DB instance for a specific database name.
   - **Dependencies:** `mongodb` (Node module)

**3. Routes (`./routes/*.ts`)**
   - **File:** `backend/src/routes/index.ts`
     - **Responsibilities:** Aggregates all route definitions.
     - **Imports:** All other files in `./routes/`.
     - **Exports:** `routes()` function returning an array of route objects.
   - **File:** `backend/src/routes/logInRoute.ts`, `signUpRoute.ts`, `logRoute.ts`, `getLogRoute.ts`
     - **Responsibilities:** Define API endpoints for user auth and logging.
     - **Dependencies:** `express`, `bcrypt`, `jsonwebtoken` (Node modules), `../db.ts` -> `getDbConnection`.
     - **Interactions:** Access MongoDB via `getDbConnection`. Use `bcrypt` for hashing/comparison. Use `jwt` for token signing/verification.
   - **File:** `backend/src/routes/getTopScores.ts`, `updateTopScore.ts`
     - **Responsibilities:** Define API endpoints for high scores.
     - **Dependencies:** `express`, `../db.ts` -> `getDbConnection`.
     - **Interactions:** Access MongoDB (`top-scores` DB) via `getDbConnection`.
   - **File:** `backend/src/routes/spectateGameRoute.ts`
     - **Responsibilities:** Define API endpoint for getting spectator data; holds service references.
     - **Dependencies:** `express`, `../services/GameService.ts`, `../services/GameLogService.ts`.
     - **Exports:** `spectateGameRoute` (object), `initializeSpectateRoute` (function).
     - **Interactions (Handler):** Uses injected `GameService` (`getGame`) and `GameLogService` (`getGameLog`).

**4. Controllers (`./controllers/*.ts`)**
   - **File:** `backend/src/controllers/GameController.ts`
     - **Responsibilities:** Handles game logic Socket.IO events (`requestGame`, `requestJoinGame`, `sendDices`, `sendSelection`, `useRegret`, `useExtraMove`, `spectateGame`).
     - **Dependencies:** `socket.io` (types), `../services/GameService.ts`, `../services/GameLogService.ts`, `../models/Player.ts`, `../models/Game.ts`, `../utils/yatzyMapping.ts`.
     - **Interactions:**
       - Constructor takes `GameService`, `GameLogService`.
       - `registerSocketHandlers` sets up listeners for specific actions.
       - Calls `gameService.createOrJoinGame()`, `gameService.getGame()`, `gameService.joinGame()`, `gameService.removeGame()`, `gameService.processDiceRoll()`, `gameService.processSelection()`, `gameService.logRegret()`, `gameService.logExtraMove()`, `gameLogService.getGameLog()`, `gameService.addSpectator()`.
       - Uses `PlayerFactory.createPlayer()`.
       - Uses `getSelectionLabel()`, `getSelectionIndex()`.
       - Uses `game.applySelection()`, `game.toJSON()`.
   - **File:** `backend/src/controllers/PlayerController.ts`
     - **Responsibilities:** Handles player-specific Socket.IO events (`getId`).
     - **Dependencies:** `socket.io` (types), `../services/GameService.ts`, `../services/GameLogService.ts`.
     - **Interactions:**
       - Constructor takes `GameService`, `GameLogService`.
       - `registerSocketHandlers` sets up listeners.
       - Calls `gameService.broadcastGameListToPlayer()`.
   - **File:** `backend/src/controllers/ChatController.ts`
     - **Responsibilities:** Handles chat message Socket.IO events (`chatMessage`).
     - **Dependencies:** `socket.io` (types), `../services/GameService.ts`.
     - **Interactions:**
       - Constructor takes `io`, `GameService`.
       - `registerSocketHandlers` sets up listeners.
       - Uses `gameService.getGame()` to find players.
       - Uses `io.to(playerId).emit()` to send messages.

**5. Services (`./services/*.ts`)**
   - **File:** `backend/src/services/GameService.ts`
     - **Responsibilities:** Core game state management (creating, finding, joining, removing games), player connection/disconnection handling, processing game actions (rolls, selections), managing spectators, broadcasting updates.
     - **Dependencies:** `../models/Game.ts`, `../models/Player.ts`, `socket.io` (types), `./GameLogService.ts`.
     - **Interactions:**
       - Constructor takes `io`, `GameLogService`.
       - Manages `games` Map, `spectators` Map.
       - Calls `gameLogService.logGameStart()`, `gameLogService.logMove()`, `gameLogService.logGameEnd()`, `gameLogService.logRegret()`, `gameLogService.logExtraMove()`.
       - Creates/manipulates `Game` and `Player` instances.
       - Uses `io.emit()`, `io.to().emit()` extensively for broadcasting/sending messages (`onServerMsg`, `onClientMsg`).
   - **File:** `backend/src/services/GameLogService.ts`
     - **Responsibilities:** Handles interaction with the MongoDB `game_moves` collection for logging game events.
     - **Dependencies:** `mongodb` (types), `../db.ts` -> `getDbConnection`, `../models/Game.ts`.
     - **Interactions:**
       - Uses `getDbConnection()` to get the DB instance.
       - Calls `db.collection().replaceOne()`, `db.collection().updateOne()`, `db.collection().findOne()`, `db.collection().insertOne()`.
     - **Exports:** `GameMove`, `GameLog` interfaces.

**6. Models (`./models/*.ts`)**
   - **File:** `backend/src/models/Game.ts`
     - **Responsibilities:** Represents the state of a single game instance.
     - **Dependencies:** `./Player.ts`, `uuid`, `../utils/yatzyMapping.ts`.
     - **Interactions:** Contains `Player` objects. Uses `PlayerFactory`. Calls `player.calculateScores()`, `player.hasCompletedGame()`. Uses `getSelectionIndex()`.
   - **File:** `backend/src/models/Player.ts`
     - **Responsibilities:** Represents the state of a single player within a game.
     - **Dependencies:** `./BoardCell.ts`, `../utils/gameConfig.ts`.
     - **Interactions:** Contains `BoardCell` objects. Uses `GameConfig`.
   - **File:** `backend/src/models/BoardCell.ts`
     - **Responsibilities:** Represents a single cell on the scorecard. Minimal dependencies.
   - **File:** `backend/src/models/Dice.ts`
     - **Responsibilities:** Basic dice rolling logic (appears less used server-side, client sends results). Minimal dependencies.

**7. Utils (`./utils/*.ts`)**
   - **File:** `backend/src/utils/gameConfig.ts`
     - **Responsibilities:** Provides configuration (labels, thresholds, counts) for different Yatzy game types.
     - **Used by:** `Player.ts`.
   - **File:** `backend/src/utils/yatzyMapping.ts`
     - **Responsibilities:** Maps between cell labels (strings) and cell indices (numbers).
     - **Used by:** `GameController.ts`, `Game.ts`.
   - **File:** `backend/src/utils/index.ts`
     - **Responsibilities:** Generic utility functions. (Appears less used in core logic shown).

---
### Frontend (Flutter / Dart - ./lib/)
---

**1. Entry Point & Core Setup**
   - **File:** `lib/main.dart`
     - **Responsibilities:** Initializes Flutter bindings, `SharedPrefProvider`, Dependency Injection (`configureInjection`), BLoC providers (`LanguageBloc`, `SetStateCubit`), runs `AppWidget`.
     - **Dependencies:** `flutter/material.dart`, `flutter_bloc`, `injectable`, `./injection.dart`, `./shared_preferences.dart`, `./core/app_widget.dart`, `./states/*`.
   - **File:** `lib/core/app_widget.dart`
     - **Responsibilities:** Root widget. Sets up `MaterialApp.router`. Initializes legacy global state objects (`app`, `dices`, `chat`, `topScore`, etc.). Initializes `ServiceProvider`. Connects `SocketService` in `addPostFrameCallback`. Links `SocketService` to `Application` instance (`app.setSocketService`).
     - **Dependencies:** `flutter/material.dart`, `auto_route`, `flutter_bloc`, `../application/*`, `../dices/*`, `../chat/*`, `../top_score/*`, `../scroll/*`, `../tutorial/*`, `../injection.dart`, `../router/router.dart`, `../services/service_provider.dart`, `../startup.dart`, `../states/cubit/state/state_cubit.dart`.
   - **File:** `lib/startup.dart`
     - **Responsibilities:** Defines global variables (legacy state management, URLs, flags like `isOnline`). Initializes instances of legacy classes (`inputItems`, etc.).
     - **Dependencies:** References many classes (`InputItems`, `Tutorial`, `TopScore`, `AnimationsScroll`, `Application`, `Chat`, `Dices`).

**2. Dependency Injection & Router**
   - **File:** `lib/injection.dart`, `lib/injection.config.dart`, `lib/core/injectable_modules.dart`
     - **Responsibilities:** Configures GetIt for dependency injection using `injectable`. Primarily injects `AppRouter`.
     - **Dependencies:** `get_it`, `injectable`, `../router/router.dart`.
   - **File:** `lib/router/router.dart`, `lib/router/router.gr.dart`
     - **Responsibilities:** Defines navigation routes using `auto_route`. Routes: `SettingsView`, `ApplicationView`.
     - **Dependencies:** `auto_route`, `../views/*.dart`.

**3. Views**
   - **File:** `lib/views/settings_view.dart`
     - **Responsibilities:** UI for settings, creating/joining games, viewing available games, spectating.
     - **Dependencies:** `flutter/material.dart`, `auto_route`, `flutter_bloc`, `../application/widget_application_settings.dart`, `../startup.dart`, `../states/cubit/state/state_cubit.dart`.
     - **Interactions:** Uses `app.widgetScaffoldSettings()` to build UI. Uses `SetStateCubit` for updates. Calls `app.onStartGameButton()`, `app.onAttemptJoinGame()`, `app.onSpectateGame()`. Includes `SpectatorGameBoard`.
   - **File:** `lib/views/application_view.dart`
     - **Responsibilities:** Main game view UI container.
     - **Dependencies:** `flutter/material.dart`, `auto_route`, `flutter_bloc`, `../application/widget_application_scaffold.dart`, `../startup.dart`, `../states/cubit/state/state_cubit.dart`, `../tutorial/tutorial.dart`, `../scroll/animations_scroll.dart`.
     - **Interactions:** Uses `app.widgetScaffold()` to build UI. Initializes `app.setup()`, `tutorial.setup()`, `app.animation.setupAnimation()`. Uses `SetStateCubit`. Calls `topScore.loadTopScoreFromServer()`.

**4. Application Logic (Legacy Global State)**
   - **File:** `lib/application/application.dart`
     - **Responsibilities:** Holds main legacy game state (board, players, game type, etc.). References other components (`Dices`, `InputItems`, `AnimationsApplication`). Provides callbacks to `Dices`. Links to `SocketService`.
     - **Dependencies:** `flutter/material.dart`, `flutter_bloc`, `./application_functions_internal.dart`, `../dices/dices.dart`, `../dices/unity_communication.dart`, `../input_items/input_items.dart`, `../services/socket_service.dart`, `../startup.dart`, `../states/cubit/state/state_cubit.dart`, `./animations_application.dart`, `./languages_application.dart`.
     - **Interactions:** `setup()` initializes board state. `setSocketService()` stores service ref. `callbackUpdateDiceValues()`, `callbackUnityCreated()`, `callbackCheckPlayerToMove()` are called by `Dices`. `updateDiceValues()` calls `yatzyFunctions` and triggers state update.
   - **File:** `lib/application/communication_application.dart` (Extension)
     - **Responsibilities:** Handles incoming socket messages (`callbackOnServerMsg`, `callbackOnClientMsg`) by updating the state in `Application`. Handles chat submission (`chatCallbackOnSubmitted`).
     - **Dependencies:** `flutter/material.dart`, `flutter_bloc`, `../chat/chat.dart`, `../injection.dart`, `../router/router.dart`, `../router/router.gr.dart`, `../services/service_provider.dart`, `../shared_preferences.dart`, `../startup.dart`, `../states/cubit/state/state_cubit.dart`, `./application.dart`.
     - **Interactions:** Calls `router`, `SetStateCubit`, reads `socketService`, interacts with `gameDices`, updates `app` state (`gameData`, `myPlayerId`, etc.). Calls `app.setup()`.
   - **File:** `lib/application/application_functions_internal.dart` (Extension)
     - **Responsibilities:** Contains game interaction logic (`cellClick`, `applyLocalSelection`, `colorBoard`).
     - **Dependencies:** `flutter/material.dart`, `provider`, `../dices/unity_communication.dart`, `../startup.dart`, `./application.dart`, `../utils/yatzy_mapping_client.dart`, `../states/cubit/state/state_cubit.dart`.
     - **Interactions:** Called by UI gestures. Calls `socketService.sendToClients()`. Calls `getSelectionLabel()`. Updates `app` state (`appColors`, `fixedCell`, `cellValue`, `appText`). Calls `gameDices.sendResetToUnity()`, `gameDices.clearDices()`. Calls `SetStateCubit`.
   - **File:** `lib/application/application_functions_internal_calc_dice_values.dart` (Extension)
     - **Responsibilities:** Contains pure functions to calculate potential scores based on current dice values.
     - **Dependencies:** `./application.dart`.
     - **Interactions:** Reads `app.gameDices.diceValue`. Called by `app.updateDiceValues()`.
   - **File:** `lib/application/widget_application_scaffold.dart` (Extension)
     - **Responsibilities:** Builds the main scaffold widget for the application view. Includes layout logic, floating action buttons.
     - **Dependencies:** `auto_route`, `flutter/material.dart`, `flutter_bloc`, `./communication_application.dart`, `../chat/widget_chat.dart`, `../dices/unity_communication.dart`, `../dices/widget_dices.dart`, `../top_score/widget_top_scores.dart`, `../router/router.gr.dart`, `../scroll/widget_scroll.dart`, `../services/service_provider.dart`, `../startup.dart`, `../states/cubit/state/state_cubit.dart`, `./application.dart`, `./widget_application.dart`.
     - **Interactions:** Calls other widget builders (`WidgetDices`, `WidgetTopScore`, `WidgetSetupGameBoard`, etc.). Handles FAB presses (calls `app.setup`, `gameDices.rollDices`, interacts with router, sends messages via `socketService`).
   - **File:** `lib/application/widget_application_settings.dart` (Extension)
     - **Responsibilities:** Builds the settings view UI. Includes logic for displaying available games, joining games, spectating.
     - **Dependencies:** `auto_route`, `flutter/material.dart`, `flutter_bloc`, `../dices/unity_communication.dart`, `../router/router.gr.dart`, `../services/service_provider.dart`, `../shared_preferences.dart`, `../startup.dart`, `../states/bloc/language/language_bloc.dart`, `../states/bloc/language/language_event.dart`, `../states/cubit/state/state_cubit.dart`, `../widgets/spectator_game_board.dart`, `./application.dart`.
     - **Interactions:** Reads `app.games`. Calls `inputItems.widgetButton`, `inputItems.widgetCheckbox`, etc. Calls `onAttemptJoinGame`, `onStartGameButton`, `onSpectateGame`, `onChangeUserName`. Interacts with `LanguageBloc`, `SetStateCubit`. Includes `SpectatorGameBoard`.
   - **File:** `lib/application/widget_application.dart` (`WidgetSetupGameBoard`, `WidgetDisplayGameStatus`)
     - **Responsibilities:** Builds the game board UI and the game status display.
     - **Dependencies:** `dart:math`, `auto_size_text`, `flutter/material.dart`, `flutter_bloc`, `./application_functions_internal.dart`, `../dices/unity_communication.dart`, `../startup.dart`, `../states/cubit/state/state_cubit.dart`, `./languages_application.dart`.
     - **Interactions:** Reads `app` state (`nrPlayers`, `totalFields`, `board*` arrays, `appText`, `appColors`, `focusStatus`). Calls `app.cellClick`. Uses `SetStateCubit`.

**5. Services (Modern)**
   - **File:** `lib/services/service_provider.dart`
     - **Responsibilities:** InheritedWidget to provide access to modern services (`SocketService`, `GameService`). Initializes these services.
     - **Dependencies:** `flutter/material.dart`, `./socket_service.dart`, `./game_service.dart`.
   - **File:** `lib/services/socket_service.dart`
     - **Responsibilities:** Manages the Socket.IO connection, event handling (listening and emitting), holds socket ID. Replaces legacy `Net`.
     - **Dependencies:** `flutter/material.dart`, `socket_io_client`, `flutter_bloc`, `../application/communication_application.dart`, `dart:convert`, `../models/game.dart`, `../states/cubit/state/state_cubit.dart`, `../startup.dart`.
     - **Interactions:** Connects to the server URL from `startup.dart`. Emits events (`sendToServer`, `sendToClients`). Listens for events (`onConnect`, `onDisconnect`, `onServerMsg`, `onClientMsg`, etc.). Calls legacy `app.callbackOnServerMsg`/`app.callbackOnClientMsg`. Uses `SetStateCubit`.
   - **File:** `lib/services/http_service.dart`
     - **Responsibilities:** Handles HTTP requests (GET, POST, UPDATE, DELETE). Replaces legacy `Net`.
     - **Dependencies:** `dart:convert`, `package:http/http.dart`.
     - **Interactions:** Makes HTTP calls to the base URL from `startup.dart`.
   - **File:** `lib/services/game_service.dart`
     - **Responsibilities:** Intended to manage client-side game logic (currently less utilized, `Application` holds most state). Listens for updates from `SocketService`.
     - **Dependencies:** `../models/game.dart`, `../models/board_cell.dart`, `./socket_service.dart`.
     - **Interactions:** Takes `SocketService` in constructor. `_handleGameUpdate` updates internal `_game` state. Provides methods like `createGame`, `joinGame`, `rollDice`, `selectCell` which call corresponding `SocketService` methods.

**6. State Management**
   - **File:** `lib/states/bloc/language/*`
     - **Responsibilities:** Manages the selected language using `flutter_bloc`. Persists state using `SharedPrefProvider`.
     - **Dependencies:** `injectable`, `flutter_bloc`, `../../shared_preferences.dart`.
   - **File:** `lib/states/cubit/state/state_cubit.dart`
     - **Responsibilities:** Simple Cubit used globally to trigger UI rebuilds (equivalent to `setState`).
     - **Dependencies:** `flutter_bloc`.

**7. Models**
   - **File:** `lib/models/game.dart`, `player.dart`, `board_cell.dart`
     - **Responsibilities:** Client-side data models representing game, player, and cell state. Simpler than server-side counterparts.
     - **Dependencies:** `flutter/foundation.dart`.
     - **Interactions:** `Game.fromJson` used in `SocketService` (or `Application`) to update state from server data. `Player.calculateScores` used locally.

**8. UI Components & Features**
   - **File:** `lib/dices/*`
     - **Responsibilities:** Manages dice UI (2D/3D), dice state (`diceValue`, `holdDices`), communication with Unity (`flutter_unity_widget`).
     - **Dependencies:** `dart:math`, `flutter/cupertino.dart`, `flutter_unity_widget`, `../input_items/input_items.dart`, `dart:convert`, `./unity_message.dart`.
     - **Interactions:** `WidgetDices` displays dice. `Dices` class holds state, `rollDices` performs client-side roll. `UnityCommunication` extension sends/receives messages to/from Unity. Calls `callbackUpdateDiceValues`, `callbackUnityCreated`.
   - **File:** `lib/chat/*`
     - **Responsibilities:** Manages chat UI and local message list.
     - **Dependencies:** `flutter/cupertino.dart`, `../input_items/input_items.dart`.
     - **Interactions:** `WidgetChat` displays messages and input field. `Chat` class holds `messages`. `onSubmitted` calls `app.chatCallbackOnSubmitted`.
   - **File:** `lib/top_score/*`
     - **Responsibilities:** Fetches and displays top scores.
     - **Dependencies:** `dart:convert`, `flutter/animation.dart`, `../services/http_service.dart`, `../startup.dart`.
     - **Interactions:** `WidgetTopScore` displays the list. `TopScore` class uses `HttpService` (`getDB`, `postDB`) to interact with the backend API.
   - **File:** `lib/scroll/*`
     - **Responsibilities:** Displays scrolling text animation.
     - **Dependencies:** `animated_text_kit`, `flutter/material.dart`, `../startup.dart`.
   - **File:** `lib/tutorial/*`
     - **Responsibilities:** Provides tutorial overlay arrows.
     - **Dependencies:** `flutter/material.dart`.
   - **File:** `lib/input_items/input_items.dart`
     - **Responsibilities:** Reusable UI input widgets (buttons, checkboxes, text fields, etc.).
     - **Dependencies:** `flutter/material.dart`.
   - **File:** `lib/widgets/spectator_game_board.dart`
     - **Responsibilities:** Displays the game board state for a spectator based on received `gameData`.
     - **Dependencies:** `flutter/material.dart`.

**9. Utils & Shared Preferences**
   - **File:** `lib/utils/yatzy_mapping_client.dart`
     - **Responsibilities:** Client-side mapping between cell labels and indices. *Must match server version.*
     - **Used By:** `ApplicationFunctionsInternal`.
   - **File:** `lib/shared_preferences.dart`
     - **Responsibilities:** Wrapper around `shared_preferences` package for storing/retrieving simple key-value data.
     - **Dependencies:** `dart:convert`, `shared_preferences`.
     - **Used By:** `main.dart`, `LanguageBloc`, `communication_application.dart`.

---
**(End of Analysis)**