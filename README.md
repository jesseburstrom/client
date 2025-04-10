# Multiplayer Yatzy Game

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com/your-username/yatzy-game) <!-- Replace with actual build status badge if applicable -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A real-time multiplayer Yatzy game built with a Flutter frontend and a Node.js/Express backend, featuring optional 3D dice rendering via Unity integration.

## Table of Contents

-   [Project Overview](#project-overview)
-   [Features](#features)
-   [Architecture](#architecture)
-   [Technologies Used](#technologies-used)
-   [Screenshots](#screenshots) <!-- Placeholder -->
-   [Getting Started](#getting-started)
    -   [Prerequisites](#prerequisites)
    -   [Backend Setup](#backend-setup)
    -   [Frontend Setup](#frontend-setup)
    -   [Unity Setup (Optional)](#unity-setup-optional)
-   [Usage](#usage)
-   [API & Real-time Events](#api--real-time-events)
    -   [REST API](#rest-api)
    -   [Socket.IO Events](#socketio-events)
-   [Project Structure](#project-structure)
-   [Contributing](#contributing)
-   [License](#license)
-   [Acknowledgements](#acknowledgements)

## Project Overview

This project implements a classic Yatzy dice game with multiplayer capabilities. Users can sign up, log in, create new games, join existing games, or spectate ongoing matches. Gameplay is synchronized in real-time using WebSockets, allowing players to see dice rolls, score selections, and chat messages instantly. The backend handles all game logic, scoring, and data persistence, while the Flutter frontend provides an interactive user interface. An optional Unity integration allows for rendering visually appealing 3D dice within the Flutter app.

## Features

*   **Multiplayer Gameplay:** Supports multiple players per game (configurable).
*   **Real-time Synchronization:** Uses Socket.IO for instant updates on game state, dice rolls, scores, and chat.
*   **Authentication:** Basic user signup and login using JWT for session management.
*   **Game Lobby:** View available games and join waiting rooms.
*   **Spectator Mode:** Watch ongoing games in real-time.
*   **Yatzy Scoring:** Implements standard 'Ordinary' Yatzy and 'Maxi' Yatzy scoring rules.
*   **In-Game Chat:** Real-time chat functionality within game rooms.
*   **Top Scores:** Persistent high score tracking for different game types.
*   **Game Logging:** Records game moves and events for persistence and spectating.
*   **Optional 3D Dice:** Integrates a Unity project for rendering 3D dice rolls within the Flutter UI.
*   **Multi-language Support:** Basic infrastructure for internationalization in the frontend.

## Architecture

The application follows a standard client-server architecture:

1.  **Frontend (Client):** A Flutter application (`lib/`) responsible for the UI, user interactions, and communicating with the backend. Runs on user devices (Mobile/Web).
2.  **Backend (Server):** A Node.js/Express application (`backend/`) written in TypeScript. It manages game logic, user sessions, real-time communication via Socket.IO, and database interactions.
3.  **Database:** MongoDB is used for persisting user data (potentially), game logs, and top scores.
4.  **Communication:**
    *   **REST API:** Handles authentication (signup/login), fetching/updating top scores, and retrieving spectator/log data via standard HTTP requests.
    *   **WebSockets (Socket.IO):** Provides the primary channel for real-time, bidirectional communication during gameplay (joining games, sending rolls/selections, chat, game state synchronization).
5.  **Optional Unity Integration:** A separate Unity project (`unity/`) can be built and integrated into the Flutter app (`lib/dices/`) to provide 3D dice rendering, communicating via messages posted between Flutter and Unity.

```mermaid
graph LR
    A[Flutter Client] -- REST API --> B(Express Backend);
    A -- Socket.IO --> B;
    B -- MongoDB Driver --> C(MongoDB Database);
    B -- Socket.IO --> A;
    D(Unity Dice Renderer);
    A -- FlutterUnityWidget --> D;
    D -- FlutterUnityWidget --> A;

    subgraph "Client (User Device)"
        A
        D
    end

    subgraph "Server"
        B
        C
    end

    style D stroke-dasharray: 5 5, fill:#eee;```

## Technologies Used

**Frontend (Flutter - `lib/`)**

*   Language: Dart
*   Framework: Flutter
*   State Management: Flutter BLoC/Cubit (`SetStateCubit`, `LanguageBloc`)
*   Routing: `auto_route`
*   Networking:
    *   `http` (REST API)
    *   `socket_io_client` (WebSockets)
*   Dependency Injection: `get_it`, `injectable`
*   Local Storage: `shared_preferences`
*   UI: Material Design
*   Optional: `flutter_unity_widget` (for Unity integration)

**Backend (Express - `backend/`)**

*   Language: TypeScript
*   Framework: Node.js, Express.js
*   Real-time Communication: Socket.IO
*   Database: MongoDB (using `mongodb` driver)
*   Authentication: `bcrypt` (hashing), `jsonwebtoken` (JWT)
*   Utility: `uuid`

**Optional 3D Dice**

*   Engine: Unity

## Screenshots

<!-- Add screenshots of your application here -->
*   *[Screenshot 1: Login/Signup Screen]*
*   *[Screenshot 2: Game Lobby/Settings Screen]*
*   *[Screenshot 3: Gameplay Screen (Ordinary)]*
*   *[Screenshot 4: Gameplay Screen (Maxi)]*
*   *[Screenshot 5: Chat Interface]*
*   *[Screenshot 6: Top Scores]*
*   *[Screenshot 7: Spectator View]*
*   *[Screenshot 8: Optional 3D Dice]*

## Getting Started

### Prerequisites

*   Node.js and npm (or yarn) installed.
*   Flutter SDK installed.
*   MongoDB server running (locally or cloud instance).
*   (Optional) Unity Hub and Unity Editor installed (if using 3D dice).

### Backend Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/yatzy-game.git
    cd yatzy-game/backend
    ```
2.  **Install dependencies:**
    ```bash
    npm install
    # or
    yarn install
    ```
3.  **Configure Environment Variables:**
    Create a `.env` file in the `backend/` directory and add the following variables:
    ```env
    # Example values - replace with your actual configuration
    MONGO_DB_URI_LOG=mongodb://127.0.0.1:27017/yatzy-game-log-db
    MONGO_DB_URI_TOPSCORES=mongodb://127.0.0.1:27017/top-scores
    MONGO_DB_URI_AUTH=mongodb://127.0.0.1:27017/react-auth-db # Or your main user DB
    JWT_SECRET=your_very_secret_jwt_key # Replace with a strong secret
    PORT=8000 # Optional, defaults to 8000
    ```
    *Note: The database connection strings (`MONGO_DB_URI_*`) seem hardcoded in `db.ts` and routes. You might need to refactor to use the `.env` file properly or ensure your local MongoDB matches the hardcoded URIs.*
4.  **Compile TypeScript:**
    ```bash
    npm run build
    ```
5.  **Run the server:**
    ```bash
    npm start
    # Or for development with auto-reloading (if nodemon/ts-node-dev is configured):
    # npm run dev
    ```
    The backend server should now be running (default: `http://localhost:8000`).

### Frontend Setup

1.  **Navigate to the frontend directory:**
    ```bash
    cd ../lib # From the backend directory, or cd yatzy-game/lib from root
    ```
2.  **Get Flutter dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Configure Backend URL:**
    Ensure the `localhost` variable in `lib/startup.dart` points to your running backend server (e.g., `http://localhost:8000`). Adjust if your backend runs on a different address or port, especially when testing on physical devices.
4.  **Generate Code (if needed for `injectable`/`auto_route`):**
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```
5.  **Run the Flutter app:**
    Select your target device (emulator, physical device, or web) and run:
    ```bash
    flutter run
    ```

### Unity Setup (Optional)

1.  **Open the Unity Project:** Open the `unity/yatzy` project in the Unity Hub.
2.  **Build for Target Platform:**
    *   Follow the instructions provided by the `flutter_unity_widget` package for building the Unity project as a library for your target platform (Android/iOS/WebGL).
    *   The editor scripts in `unity/yatzy/Assets/FlutterUnityIntegration/Editor/` likely assist with this process (e.g., `Build.cs`). Use the `Flutter` menu items in the Unity Editor.
3.  **Integrate Build Output:** Place the built Unity library files into the appropriate locations within your Flutter project structure as required by `flutter_unity_widget`.
4.  **Enable Unity in Flutter:** Ensure the `unityDices` flag in `lib/dices/dices.dart` or relevant settings allows the `UnityWidget` to be used.

## Usage

1.  **Launch the Flutter App:** Start the application on your device/emulator/web.
2.  **Signup/Login:** Create a new account or log in using existing credentials.
3.  **Settings Screen:**
    *   Choose game type ('Ordinary' or 'Maxi').
    *   Select the number of players for a new game.
    *   Enter your desired username.
    *   View available games waiting for players and click to join.
    *   View ongoing games and click to spectate.
    *   Adjust general settings like language or Unity options.
    *   Click "Create Game" to start a new game lobby.
4.  **Gameplay Screen:**
    *   If it's your turn, click the "Roll" button (up to 3 times).
    *   Click on dice to hold/unhold them between rolls.
    *   Click on an available score cell on your column to lock in the score for the current dice.
    *   The game automatically advances to the next player.
5.  **Chat:** Use the chat input field to send messages to other players in the game.
6.  **Game End:** When all score cells are filled for all active players, the game ends, and final scores are displayed.

## API & Real-time Events

### REST API

*   `POST /api/signup`: Creates a new user account.
*   `POST /api/login`: Authenticates a user and returns a JWT.
*   `GET /GetTopScores?type=<gameType>`: Retrieves top scores for the specified game type ('Ordinary', 'Maxi').
*   `POST /UpdateTopScore`: Adds a new score entry (used internally by backend or potentially for manual updates).
*   `GET /api/spectate/:gameId`: Retrieves combined current state and logged moves for spectating via HTTP.
*   `/api/log/:userId` (POST), `/api/getLog/:userId` (GET): Older/Internal logging routes, potentially requiring JWT authorization.

### Socket.IO Events

Communication primarily uses generic event names with an `action` field in the payload.

*   **Client -> Server (`sendToServer` event):**
    *   `{ action: 'getId' }`: Client requests its unique socket ID upon connection.
    *   `{ action: 'requestGame', gameType: '...', nrPlayers: ..., userName: '...' }`: Client requests to create/join a game lobby.
    *   `{ action: 'requestJoinGame', gameId: ..., userName: '...' }`: Client requests to join a specific waiting game.
    *   `{ action: 'spectateGame', gameId: ..., userName: '...' }`: Client requests to spectate a game.
    *   `{ action: 'requestTopScores', gameType: '...'}`: Client requests current top scores for a type.
    *   *Other actions potentially handled by controllers.*

*   **Client -> Server (Broadcast intention via `sendToClients` event):**
    *   `{ action: 'sendDices', gameId: ..., diceValue: [...], keptDice: [...] }`: Client reports its dice roll result. Server validates, processes, logs, and relays/updates state.
    *   `{ action: 'sendSelection', gameId: ..., selectionLabel: '...', score: ..., player: ..., diceValue: [...] }`: Client reports its score selection. Server validates, processes, logs, and relays/updates state.
    *   `{ action: 'chatMessage', gameId: ..., message: '...', sender: '...' }`: Client sends a chat message intended for others in the game. Server relays.

*   **Server -> Client (`onServerMsg` event):**
    *   `{ action: 'getId', id: '...' }`: Server responds with the client's assigned socket ID.
    *   `{ action: 'onRequestGames', Games: [...] }`: Server sends the list of available/ongoing games.
    *   `{ action: 'onGameStart', ...gameData, spectator?: true }`: Server signals the start of a game (or sends initial spectator state). Contains full game state.
    *   `{ action: 'onGameUpdate', ...gameData }`: Server sends an updated game state after a roll, selection, or player change. Contains full game state.
    *   `{ action: 'onGameFinished', ...gameData }`: Server signals the end of the game. Contains final game state.
    *   `{ action: 'onTopScoresUpdate', gameType: '...', scores: [...] }`: Server pushes updated top scores for a specific game type.
    *   `{ action: 'error', message: '...' }`: Server sends an error message to a specific client.

*   **Server -> Client (Forwarding via `onClientMsg` event):**
    *   `{ action: 'chatMessage', chatMessage: '...' }`: Server forwards a chat message from one client to others in the same game.
    *   *(Potentially others like `sendDices`, `sendSelection` if client-side logic relies on direct peer messages, though `onGameUpdate` is generally preferred for state sync)*.

*   **Standard Socket.IO Events:** `connect`, `disconnect`, `connect_error`, `welcome`.

## Project Structure

```
.
├── backend/
│   ├── src/
│   │   ├── controllers/    # Handles Socket.IO event routing
│   │   ├── db.ts           # MongoDB connection setup
│   │   ├── models/         # Data models (Game, Player, Cell)
│   │   ├── routes/         # Express REST API routes
│   │   ├── services/       # Core business logic (GameService, LogService, TopScoreService)
│   │   ├── utils/          # Utility functions and game configuration
│   │   └── server.ts       # Main Express/Socket.IO server setup
│   ├── nodemon.json
│   ├── package.json
│   └── tsconfig.json
├── lib/
│   ├── application/      # Core application state, logic, UI builders
│   ├── assets/           # Images, fonts, etc.
│   ├── chat/             # Chat state and UI widgets
│   ├── core/             # Main AppWidget, DI setup
│   ├── dices/            # Dice logic, UI widgets, Unity communication
│   ├── input_items/      # Reusable input widgets
│   ├── models/           # Frontend data models
│   ├── router/           # Navigation setup (auto_route)
│   ├── services/         # Networking (Socket, HTTP) and client-side logic
│   ├── states/           # BLoC/Cubit state management
│   ├── top_score/        # Top score state and UI widgets
│   ├── utils/            # Frontend utility functions
│   ├── views/            # Main screen views (Settings, Application)
│   ├── widgets/          # Reusable UI widgets (e.g., SpectatorBoard)
│   ├── injection.config.dart # Generated DI code
│   ├── injection.dart    # DI setup
│   ├── main.dart         # Flutter application entry point
│   └── startup.dart      # Global variables and initializations
├── unity/
│   └── yatzy/            # Unity project source for 3D dice
├── pubspec.yaml          # Flutter dependencies
├── full_description.md   # (Source document for this README)
└── README.md             # This file
```

## Contributing

Contributions are welcome! Please follow these steps:

1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/your-feature-name`).
3.  Make your changes.
4.  Commit your changes (`git commit -m 'Add some feature'`).
5.  Push to the branch (`git push origin feature/your-feature-name`).
6.  Open a Pull Request.

Please ensure your code follows the existing style and includes relevant tests if applicable.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details (You'll need to create a LICENSE file with the MIT text).

## Acknowledgements

*   Inspiration from the classic Yatzy dice game.
*   Mention any libraries or assets used that require attribution.
*   Contributors (if any).
```

**Key Points and Improvements in the Generated README:**

1.  **Structure:** Follows a standard, logical README layout.
2.  **Clarity:** Uses clear headings and concise language extracted from the detailed description.
3.  **Professional Tone:** Maintains a professional tone suitable for a GitHub project.
4.  **Visuals:** Includes placeholders for badges and screenshots, and crucially, a `mermaid` diagram to visually represent the architecture directly within the README.
5.  **Key Sections:** Covers all essential aspects like features, architecture, technology stack, setup, usage, API/events, and project structure.
6.  **Setup Instructions:** Provides inferred but standard setup steps for both backend and frontend, highlighting the need for environment configuration and database setup.
7.  **API/Events Summary:** Condenses the detailed event information from the description into a more digestible summary of the main communication patterns.
8.  **Project Structure:** Uses the provided directory structure for clarity.
9.  **Standard Sections:** Includes boilerplate "Contributing" and "License" sections.
10. **Markdown Formatting:** Uses appropriate Markdown for readability (code blocks, lists, bolding, etc.).
