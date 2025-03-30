# Project Description: jesseburstrom-client (Yatzy Game Client-Server System)

## 1. Project Overview

`jesseburstrom-client` is a client-server application primarily focused on implementing a multiplayer Yatzy game. It consists of a Flutter frontend (`lib/`) providing the user interface and game interaction, and a Node.js/Express backend (`backend/`) handling game logic, real-time communication, authentication, and data persistence.

The system appears to support:

*   Multiple Yatzy game types (Ordinary, Mini, Maxi, and variants with special rules like Regret/Extra moves).
*   Real-time multiplayer gameplay via WebSockets (Socket.IO).
*   User authentication (Sign up/Log in).
*   Top score tracking per game type.
*   A spectator mode for watching ongoing games.
*   Integration with Unity via `flutter_unity_widget` for potentially rendering 3D dice (controlled by a setting).
*   In-game chat functionality.

The backend README also mentions a React client, suggesting the backend might serve multiple frontend implementations, but this description focuses on the provided Flutter frontend and Node.js backend.

## 2. Technology Stack

*   **Frontend (`lib/`):**
    *   Framework: Flutter
    *   Language: Dart
    *   State Management: flutter_bloc / Cubit (`LanguageBloc`, `SetStateCubit`)
    *   Dependency Injection: get_it, injectable
    *   Routing: auto_route
    *   Networking:
        *   HTTP: http package (`HttpService`)
        *   WebSocket: socket_io_client (`SocketService`)
    *   UI: Material Design, auto_size_text, animated_text_kit
    *   Local Storage: shared_preferences
    *   Unity Integration: flutter_unity_widget

*   **Backend (`backend/`):**
    *   Runtime: Node.js
    *   Framework: Express.js
    *   Language: TypeScript
    *   Real-time Communication: Socket.IO
    *   Database: MongoDB (using `mongodb` driver)
    *   Authentication: JSON Web Tokens (JWT), bcrypt (password hashing)
    *   API: RESTful API endpoints, WebSocket events
    *   Utilities: cors, dotenv, uuid

## 3. Architecture

The project follows a standard **Client-Server architecture**:

*   **Backend (Server):** Acts as the central authority. It manages game state, validates actions, handles player connections, persists data (users, game logs, top scores), and facilitates real-time communication between clients. It exposes a REST API for certain actions (auth, top scores, initial spectator data) and uses Socket.IO for real-time game events and chat.
    *   **Layers:**
        *   **Routes (`src/routes/`):** Define REST API endpoints.
        *   **Controllers (`src/controllers/`):** Handle incoming Socket.IO events and REST requests, orchestrate responses, interact with services.
        *   **Services (`src/services/`):** Encapsulate core business logic (game management, logging). `GameService` is central to multiplayer logic.
        *   **Models (`src/models/`):** Define data structures (Game, Player, BoardCell).
        *   **Database (`db.ts`, `GameLogService`):** Handles MongoDB connections and data persistence.
*   **Frontend (Client):** Provides the user interface and interacts with the backend. It maintains a local representation of the game state, sends user actions to the backend, and updates the UI based on responses and real-time updates received from the backend.
    *   **Layers (typical Flutter structure):**
        *   **Views (`views/`):** Top-level screen widgets managed by the router.
        *   **Widgets (`widgets/`, `application/widget*.dart`, etc.):** Reusable UI components.
        *   **State Management (`states/`, `application/application.dart`):** Manages UI state and application-level state (using Bloc/Cubit and a central `Application` class).
        *   **Services (`services/`):** Handle communication with the backend (`HttpService`, `SocketService`) and potentially other tasks. The Flutter `GameService` acts as an interface layer over `SocketService` for game actions.
        *   **Models (`models/`):** Client-side representation of data structures.
        *   **Routing (`router/`):** Manages navigation between views.

## 4. Directory Structure Breakdown

*   **`jesseburstrom-client/`**
    *   **`backend/`**: Contains the Node.js/Express server code.
        *   `node_modules/`: Project dependencies (ignored by git).
        *   `dist/`: Compiled TypeScript output (ignored by git).
        *   `.env`: Environment variables (ignored by git).
        *   `package.json`, `package-lock.json`: Node.js project definition and dependencies.
        *   `tsconfig.json`: TypeScript compiler configuration.
        *   `src/`: Source code for the backend.
            *   `controllers/`: Handles incoming requests/events (Game, Player, Chat).
            *   `db.ts`: MongoDB connection setup.
            *   `models/`: Data structure definitions (Game, Player, BoardCell, Dice).
            *   `routes/`: REST API endpoint definitions.
            *   `services/`: Business logic (GameService, GameLogService).
            *   `utils/`: Utility functions and game configuration (gameConfig, yatzyMapping).
            *   `server.ts`: Main server entry point, sets up Express and Socket.IO.
    *   **`lib/`**: Contains the Flutter frontend code.
        *   `application/`: Core application logic, state, UI widgets for the main game view.
        *   `chat/`: Chat feature implementation (state, UI).
        *   `core/`: Core setup files (DI modules, root AppWidget).
        *   `dices/`: Dice logic, UI, and Unity integration files.
        *   `input_items/`: Reusable input widgets (buttons, text fields, etc.).
        *   `models/`: Frontend data models (BoardCell, Game, Player).
        *   `router/`: AutoRoute configuration and generated files.
        *   `scroll/`: Scrolling text animation feature.
        *   `services/`: Frontend services (HttpService, SocketService, GameService, ServiceProvider).
        *   `states/`: Bloc/Cubit state management setup.
        *   `top_score/`: Top score display feature.
        *   `tutorial/`: In-app tutorial feature.
        *   `utils/`: Client-side utility functions (yatzyMappingClient).
        *   `views/`: Top-level screen widgets (ApplicationView, SettingsView).
        *   `widgets/`: Other reusable widgets (SpectatorGameBoard).
        *   `injection.dart`, `injection.config.dart`: Dependency injection setup.
        *   `main.dart`: Flutter application entry point.
        *   `shared_preferences.dart`: Utility for local storage.
        *   `startup.dart`: Global configuration variables/flags.

## 5. Interconnection & Data Flow

Communication between the Flutter frontend and the Node.js backend happens via two primary mechanisms:

1.  **REST API (HTTP):** Used for actions that don't require real-time updates or are typically request-response based.
    *   **Authentication:** `/api/signup`, `/api/login` (POST). Frontend `HttpService` sends credentials, backend `logInRoute`/`signUpRoute` handle validation/creation, interact with MongoDB (`react-auth-db`), and return JWTs.
    *   **Top Scores:** `/GetTopScores` (GET), `/UpdateTopScore` (POST). Frontend `HttpService` calls these, backend routes interact with MongoDB (`top-scores`).
    *   **Spectator Initial Data:** `/api/spectate/:gameId` (GET). Frontend `HttpService` (or potentially direct call within Settings) fetches initial game state and log from backend `spectateGameRoute`, which uses `GameService` and `GameLogService`.
    *   **(Potential) User Logging:** `/api/log/:userId` (POST), `/api/getLog/:userId` (GET). Requires JWT auth.

2.  **WebSocket (Socket.IO):** Used for real-time game events, multiplayer state synchronization, and chat.
    *   **Connection:** Flutter `SocketService` establishes a persistent connection to the backend Socket.IO server defined in `server.ts`.
    *   **Client -> Server Events (`sendToServer`):**
        *   `getId`: Client requests its server-assigned ID (`PlayerController`).
        *   `requestGame`/`createGame`: Client requests to create/join a game (`GameController` -> `GameService`).
        *   `requestJoinGame`/`joinGame`: Client requests to join a specific game (`GameController` -> `GameService`).
        *   `useRegret`/`useExtraMove`: Client uses a special move (`GameController` -> `GameService`).
        *   `spectateGame` (WS): Client requests to start spectating via WebSocket (`GameController` -> `GameService.addSpectator`).
        *   `chatMessage`: Client sends a chat message intended for the server or broadcast (`ChatController`).
    *   **Client -> Other Clients Events (`sendToClients`):**
        *   `sendDices`: Client informs server/others about its dice roll result (`GameController` -> `GameService.processDiceRoll` -> Broadcast).
        *   `sendSelection`: Client informs server/others about its score selection (`GameController` -> `GameService.processSelection` -> Broadcast).
        *   `chatMessage`: Client sends a chat message to be broadcast (`ChatController` -> Broadcast).
    *   **Server -> Client Events (`onServerMsg`, `onClientMsg`):**
        *   `onGetId` / `userId`: Server sends the client its unique socket ID (response to `getId`).
        *   `onRequestGames`: Server broadcasts the list of available games (`GameService.broadcastGameList`).
        *   `onGameStart`: Server informs players that a game they are in has started (`GameService.createOrJoinGame`).
        *   `onGameUpdate`: Server broadcasts the updated state of a game to all players and spectators (`GameService.notifyGameUpdate`). This is the primary mechanism for state sync.
        *   `onGameFinished`: Server informs players/spectators that a game has ended (`GameService.handleGameFinished`).
        *   `onGameAborted`: Server informs a player if the game they were in was aborted (potentially).
        *   `chatMessage` (`onClientMsg` or `onServerMsg`): Server relays chat messages to relevant clients (`ChatController`).
        *   `sendDices` / `sendSelection` (`onClientMsg`): Server relays dice rolls or selections made by one player to other players in the game (`GameService.processDiceRoll`/`forwardSelectionToPlayers`).

    *   **State Synchronization:** The backend `GameService` maintains the authoritative game state. Client actions trigger events sent to the server. The server validates the action, updates the state in the corresponding `Game` object instance, logs the move via `GameLogService`, and then broadcasts the updated game state (`onGameUpdate`) to all connected clients (players and spectators) in that game room. The Flutter client receives this update in `SocketService._handleServerMessage` -> `app.callbackOnServerMsg` -> `_processGameUpdate` and updates its local UI state.

## 6. Key Features Detailed

*   **Real-time Multiplayer:** Managed by the backend `GameService` and `Socket.IO`. `GameService` tracks active games and players. Actions are sent via Socket.IO, processed by the server, and state updates are broadcast back to clients.
*   **Yatzy Game Logic:**
    *   Backend: `Game` and `Player` models (`backend/src/models/`) manage state (turns, scores, cells, rolls). `GameService` orchestrates turn advancement, game start/end. Score calculation logic seems to primarily reside on the *client* (`application/application_functions_internal_calc_dice_values.dart`), which sends the calculated score with its selection (`sendSelection`). The server logs this score. *Note: Server-side validation of scores would be a good improvement.*
    *   Frontend: `Application` class holds local state. `application_functions_internal_calc_dice_values.dart` contains score calculation logic used to display potential scores. `cellClick` sends the selection (including label and calculated score) to the backend.
*   **Authentication:** Handled via REST API (`/api/signup`, `/api/login`). Uses bcrypt for password hashing and JWT for session management. `react-auth-db` in MongoDB stores user credentials.
*   **Database Persistence:** MongoDB is used for:
    *   User accounts (`react-auth-db` -> `users` collection).
    *   (Potential) User activity logs (`react-auth-db` -> `logs` collection).
    *   Yatzy game moves and results (`yatzy-game-log-db` -> `game_moves` collection, managed by `GameLogService`).
    *   Top scores (`top-scores` database -> collections per game type).
*   **Spectator Mode:**
    *   Initiation: Client likely calls the REST endpoint (`/api/spectate/:gameId`) via `HttpService` to get initial game state and log history.
    *   Real-time Updates: Client sends a `spectateGame` event via WebSocket. Backend `GameService.addSpectator` registers the socket ID. Subsequent `onGameUpdate` broadcasts from `GameService.notifyGameUpdate` are sent to spectators as well as players.
    *   UI: `widgets/spectator_game_board.dart` is likely used to render the read-only game state.
*   **Unity Integration:** `flutter_unity_widget` is used. The `Dices` widget can display the Unity view. `UnityCommunication` extension handles message passing between Flutter and Unity for dice state, rolls, and settings (like transparency, effects).
*   **State Management (Flutter):** Uses Bloc/Cubit (`LanguageBloc` for language, `SetStateCubit` for triggering general UI updates) and a central `Application` class instance (`app`) which holds much of the game UI state directly. `ServiceProvider` provides access to `SocketService` and `GameService`.

## 7. Setup & Running

*   **Backend:**
    1.  Navigate to the `backend/` directory.
    2.  Install dependencies: `npm install`
    3.  Create a `.env` file based on requirements (likely `JWT_SECRET`, potentially MongoDB connection string although it defaults to local).
    4.  Run in development: `npm run nod` (uses `nodemon` and `ts-node`).
    5.  Build for production: `npm run build` (or similar, uses `tsc`), then `node dist/server.js`.
*   **Frontend:**
    1.  Navigate to the root directory (`jesseburstrom-client/`).
    2.  Ensure Flutter SDK is installed.
    3.  Run on a device/emulator: `flutter run`
*   **Configuration:** The `isOnline` flag in `backend/src/server.ts` and `lib/startup.dart` controls static file serving paths and potentially backend URLs (`localhost` variable in `lib/startup.dart`). Ensure the `localhost` URL in `lib/startup.dart` correctly points to the running backend server, especially when testing on a physical device (use the backend machine's local network IP, not `localhost` or `127.0.0.1`).

## 8. Potential Improvements / Notes

*   **Server-Side Score Validation:** The server currently seems to trust the score sent by the client during `sendSelection`. Adding server-side calculation based on the logged dice roll would improve robustness.
*   **Error Handling:** More specific error messages could be sent back to the client from the backend. Frontend error handling could be more robust (e.g., showing Snackbars for connection issues or invalid actions).
*   **State Management:** The Flutter frontend relies heavily on a global `app` instance and a simple `SetStateCubit`. For larger applications, refining state management (e.g., more specific Blocs/Cubits per feature) could improve maintainability.
*   **Model Synchronization:** Ensure frontend models (`lib/models/`) stay perfectly synchronized with backend models (`backend/src/models/`) and the data structures used in JSON communication.
*   **Configuration Management:** Centralize the `isOnline` flag and backend URL configuration.
*   **Code Clarity:** Some areas, especially in the frontend state management and communication handling (`Application`, `CommunicationApplication`), could potentially be refactored for better separation of concerns.
*   **Dice Model Usage:** The backend `Dice.ts` model doesn't seem actively used in the primary game flow described by the controllers/services, which rely on client-sent dice values. Its purpose might be vestigial or for future features.

This description provides a comprehensive overview of the project structure, technologies, and interactions, suitable for understanding the codebase's flow and key components.