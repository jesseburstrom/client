# Yatzy Multiplayer Game - Codebase Documentation

## Table of Contents
1. [Introduction](#introduction)
2. [Repository Structure](#repository-structure)
3. [Frontend (Flutter) Implementation](#frontend-flutter-implementation)
4. [Backend (Express) Implementation](#backend-express-implementation)
5. [Client-Server Communication](#client-server-communication)
6. [Data Storage and Processing](#data-storage-and-processing)
7. [UI/UX Implementation](#uiux-implementation)
8. [Key Workflows](#key-workflows)
9. [Recommendations for AI Development](#recommendations-for-ai-development)

## Introduction

This document provides a comprehensive explanation of the Yatzy multiplayer game codebase, which consists of a Flutter frontend and an Express.js backend. The documentation is designed to help AI systems navigate the codebase and perform fullstack feature operations effectively.

The Yatzy game is a multiplayer dice game where players take turns rolling dice and selecting scoring combinations. The application supports real-time multiplayer functionality through WebSocket connections, user authentication, and persistent score tracking.

## Repository Structure

The repository is organized into two main components:

### Frontend (Flutter)
Located in the root directory with the main Flutter code in the `lib/` folder:

```
lib/
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
├── models/
│   ├── board_cell.dart
│   ├── game.dart
│   └── player.dart
├── router/
│   ├── router.dart
│   └── router.gr.dart
├── services/
│   ├── game_service.dart
│   ├── http_service.dart
│   ├── service_provider.dart
│   └── socket_service.dart
├── states/
│   ├── bloc/
│   │   └── language/
│   └── cubit/
│       └── state/
├── top_score/
└── views/
```

### Backend (Express)
Located in the `backend/` folder:

```
backend/
├── README.md
├── package-lock.json
├── package.json
├── tsconfig.json
├── .gitignore
└── src/
    ├── db.ts
    ├── license.txt
    ├── server.ts
    ├── controllers/
    │   ├── ChatController.ts
    │   ├── GameController.ts
    │   └── PlayerController.ts
    ├── models/
    │   ├── Dice.ts
    │   ├── Game.ts
    │   └── Player.ts
    ├── routes/
    │   ├── getLogRoute.ts
    │   ├── getTopScores.ts
    │   ├── index.ts
    │   ├── logInRoute.ts
    │   ├── logRoute.ts
    │   ├── signUpRoute.ts
    │   └── updateTopScore.ts
    ├── services/
    │   └── GameService.ts
    └── utils/
        └── index.ts
```

## Frontend (Flutter) Implementation

### Entry Point and Initialization

The application entry point is in `lib/main.dart`, which initializes the Flutter app with BLoC providers for state management:

```dart
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
```

### Core Components

1. **Models**:
   - `Game`: Represents a Yatzy game with properties like gameId, players, dice values, and game state.
   - `Player`: Represents a player in the game with properties like id, name, and score.
   - `BoardCell`: Represents a cell on the Yatzy score board.

2. **Services**:
   - `SocketService`: Manages WebSocket connections with the server for real-time game updates.
   - `GameService`: Handles game logic and state management on the client side.
   - `HttpService`: Manages HTTP requests for non-real-time operations like authentication and score retrieval.

3. **State Management**:
   - Uses Flutter BLoC pattern with Cubit for state management.
   - `LanguageBloc`: Manages language settings.
   - `SetStateCubit`: Manages UI state updates.

4. **UI Components**:
   - `widget_application.dart`: Main game board UI.
   - `widget_dices.dart`: Dice visualization using Unity integration.
   - `widget_chat.dart`: In-game chat functionality.
   - `widget_top_scores.dart`: Displays high scores.

### Game Logic

The game logic is primarily implemented in the `application/` directory:

- `application.dart`: Core game logic and state.
- `application_functions_internal_calc_dice_values.dart`: Calculates scores based on dice values.

Example of dice value calculation:
```dart
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
```

### Network Communication

The Flutter app communicates with the backend through:

1. **WebSockets** (Socket.IO client):
   - Real-time game updates
   - Chat messages
   - Player actions

2. **HTTP Requests**:
   - Authentication
   - High score retrieval
   - User profile management

## Backend (Express) Implementation

### Server Setup

The Express server is set up in `backend/src/server.ts`:

```typescript
import express from "express";
import { routes } from "./routes/index";
import { initializeDbConnection } from "./db";
import * as path from "path";
import cors from "cors";
import { Server } from "socket.io";
import { createServer } from "http";

// Import services and controllers
import { GameService } from "./services/GameService";
import { GameController } from "./controllers/GameController";
import { PlayerController } from "./controllers/PlayerController";
import { ChatController } from "./controllers/ChatController";

const PORT: number = 8000;
const app = express();

// CORS configuration
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

const httpServer = createServer(app);
```

### Core Components

1. **Controllers**:
   - `GameController`: Handles game-related socket events.
   - `PlayerController`: Manages player connections and actions.
   - `ChatController`: Processes chat messages.

2. **Models**:
   - `Game`: Server-side game state representation.
   - `Player`: Server-side player representation.
   - `Dice`: Manages dice operations.

3. **Services**:
   - `GameService`: Manages game creation, joining, and state updates.

4. **Routes**:
   - REST API endpoints for authentication, logging, and score management.

### Database Integration

MongoDB is used for persistent storage:

```typescript
// db.ts
import { MongoClient } from "mongodb";

let client;

export const initializeDbConnection = async () => {
  client = await MongoClient.connect("mongodb://127.0.0.1:27017", {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  });
};

export const getDbConnection = (dbName) => {
  const db = client.db(dbName);
  return db;
};
```

Different databases are used for different purposes:
- `react-auth-db`: User authentication
- `top-scores`: High score storage

### Socket.IO Implementation

The server uses Socket.IO for real-time communication:

```typescript
// Socket event handling
socket.on("sendToServer", (data) => {
  console.log(`Message to server from ${socket.id}:`, data?.action || data);
  
  // Handle chat messages specifically
  if (data?.action === 'chatMessage') {
    console.log(`💬 Chat message from ${socket.id}:`, data);
  }
});

socket.on("sendToClients", (data) => {
  console.log(`Message to clients from ${socket.id}:`, data?.action || data);
  
  // Handle chat messages specifically
  if (data?.action === 'chatMessage') {
    console.log(`💬 Chat message broadcast from ${socket.id}:`, data);
  }
});
```

## Client-Server Communication

### Communication Patterns

1. **Socket.IO Events**:

   - **Client to Server**:
     - `sendToServer`: Used for game requests, chat messages, and player actions.
     ```javascript
     socket.emit("sendToServer", {
       action: "requestGame",
       gameType: "Ordinary",
       nrPlayers: 2,
       userName: "Player1"
     });
     ```

   - **Client to Clients** (via Server):
     - `sendToClients`: Used for broadcasting game actions to other players.
     ```javascript
     socket.emit("sendToClients", {
       action: "sendDices",
       gameId: gameId,
       playerIds: playerIds,
       diceValue: diceValues
     });
     ```

   - **Server to Client**:
     - `onServerMsg`: Server notifications to specific clients.
     ```javascript
     socket.emit("onServerMsg", {
       action: "getId",
       id: socket.id
     });
     ```

     - `onClientMsg`: Game updates and chat messages to clients.
     ```javascript
     socket.emit("onClientMsg", {
       action: "gameJoined",
       gameId: gameId,
       success: true
     });
     ```

2. **REST API Endpoints**:

   - Authentication:
     - `POST /api/login`: User login
     - `POST /api/signup`: User registration

   - Game Data:
     - `GET /GetTopScores`: Retrieve high scores
     - `POST /updateTopScore`: Update high scores

   - Logging:
     - `POST /api/log/:userId`: Log user activity
     - `GET /api/getLog/:userId`: Retrieve user logs

### Data Formats

1. **Game State Updates**:
   ```json
   {
     "action": "onGameUpdate",
     "gameId": 123,
     "gameType": "Ordinary",
     "nrPlayers": 2,
     "connected": 2,
     "playerToMove": 0,
     "diceValues": [1, 2, 3, 4, 5],
     "rollCount": 1
   }
   ```

2. **Chat Messages**:
   ```json
   {
     "action": "chatMessage",
     "gameId": 123,
     "senderId": "socket-id-123",
     "senderName": "Player1",
     "message": "Hello everyone!"
   }
   ```

3. **Dice Actions**:
   ```json
   {
     "action": "sendDices",
     "gameId": 123,
     "playerIds": ["socket-id-123", "socket-id-456"],
     "diceValue": [1, 2, 3, 4, 5]
   }
   ```

## Data Storage and Processing

### Client-Side Storage

1. **In-Memory State**:
   - Game state is stored in memory using Dart objects and Maps.
   - Example: `Map<String, dynamic> gameData = {};`

2. **SharedPreferences**:
   - Used for persistent client-side storage of user settings and preferences.
   ```dart
   abstract class SharedPrefProvider {
     static late final SharedPreferences prefs;
     
     static loadPrefs() async {
       prefs = await SharedPreferences.getInstance();
     }
     
     static bool fetchPrefBool(String key) => prefs.getBool(key) ?? false;
     static int fetchPrefInt(String key) => prefs.getInt(key) ?? 0;
     static String fetchPrefString(String key) => prefs.getString(key) ?? '';
     static dynamic fetchPrefObject(String key) =>
         jsonDecode(prefs.getString(key) ?? jsonEncode({}));
   }
   ```

### Server-Side Storage

1. **In-Memory State**:
   - Active games are stored in memory using Maps.
   ```typescript
   private games: Map<number, Game> = new Map();
   private playerRegistry = new Map<string, boolean>();
   ```

2. **MongoDB**:
   - Used for persistent storage of user data and high scores.
   - Different collections for different data types:
     - `users`: User authentication data
     - `logs`: User activity logs
     - `ordinary`, `mini`, etc.: High scores for different game types

### Data Flow

1. **Game Creation Flow**:
   - Client sends game creation request via Socket.IO
   - Server creates game instance in memory
   - Server notifies client of game creation
   - Client updates local state with game information

2. **Game Play Flow**:
   - Player rolls dice via client UI
   - Client sends dice values to server
   - Server validates and updates game state
   - Server broadcasts updated game state to all players
   - All clients update their local state

3. **Score Persistence Flow**:
   - Game completes on server
   - Server calculates final scores
   - If high score, server persists to MongoDB
   - Clients can request updated high scores via REST API

## UI/UX Implementation

### Main UI Components

1. **Game Board**:
   - Implemented in `widget_application.dart`
   - Displays the Yatzy score sheet with cells for each scoring category
   - Updates in real-time as players make selections

2. **Dice Display**:
   - Implemented in `widget_dices.dart`
   - Uses Flutter Unity integration for 3D dice visualization
   - Supports animations for dice rolling

3. **Chat Interface**:
   - Implemented in `widget_chat.dart`
   - Allows players to communicate during the game
   - Messages are broadcast to all players in the same game

4. **Top Scores**:
   - Implemented in `widget_top_scores.dart`
   - Displays high scores for different game types

### User Experience Flow

1. **Game Setup**:
   - User selects game type (Ordinary, Mini, Maxi)
   - User chooses number of players
   - User creates or joins a game

2. **Gameplay Loop**:
   - Active player rolls dice (up to 3 times per turn)
   - Player selects which dice to keep between rolls
   - Player chooses a scoring category
   - Turn passes to next player
   - Game continues until all categories are filled

3. **Multiplayer Interaction**:
   - Real-time updates of other players' actions
   - Chat functionality for communication
   - Visual indicators of whose turn it is

4. **Game Completion**:
   - Final scores are calculated and displayed
   - High scores are updated if applicable
   - Players can choose to play again or exit

### Visual Feedback Systems

1. **Animations**:
   - Dice rolling animations
   - Score updates with visual highlights
   - Turn transitions

2. **Status Indicators**:
   - Current player highlight
   - Available actions based on game state
   - Error messages for invalid actions

## Key Workflows

### Game Creation and Joining

1. Client requests game creation:
   ```javascript
   socket.emit("sendToServer", {
     action: "requestGame",
     gameType: "Ordinary",
     nrPlayers: 2,
     userName: "Player1"
   });
   ```

2. Server creates or finds a game:
   ```typescript
   const game = this.gameService.createOrJoinGame(gameType, nrPlayers, player);
   ```

3. Server notifies client:
   ```typescript
   socket.emit("onServerMsg", {
     action: "onGameStart",
     ...game.toJSON()
   });
   ```

### Dice Rolling and Scoring

1. Client sends dice values:
   ```javascript
   socket.emit("sendToClients", {
     action: "sendDices",
     gameId: gameId,
     playerIds: playerIds,
     diceValue: diceValues
   });
   ```

2. Server processes and broadcasts:
   ```typescript
   this.io.to(gameId).emit("onClientMsg", {
     action: "diceUpdate",
     gameId: gameId,
     diceValues: diceValues,
     rollCount: game.rollCount
   });
   ```

3. Client calculates possible scores:
   ```dart
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
   ```

### Chat Communication

1. Client sends chat message:
   ```javascript
   socket.emit("sendToServer", {
     action: "chatMessage",
     gameId: gameId,
     message: "Hello everyone!"
   });
   ```

2. Server broadcasts to other players:
   ```typescript
   this.io.to(player.id).emit("onClientMsg", {
     action: "chatMessage",
     chatMessage: formattedMessage
   });
   ```

## Recommendations for AI Development

### Code Navigation Strategy

1. **Start with Entry Points**:
   - Frontend: `lib/main.dart`
   - Backend: `backend/src/server.ts`

2. **Follow Communication Flow**:
   - Trace Socket.IO events from client to server and back
   - Understand the message formats and actions

3. **Understand State Management**:
   - Frontend: BLoC pattern with Cubit
   - Backend: In-memory Maps and MongoDB persistence

### Common Feature Implementation Patterns

1. **Adding a New Game Feature**:
   - Update game model in both frontend (`models/game.dart`) and backend (`models/Game.ts`)
   - Add calculation logic in `application_functions_internal_calc_dice_values.dart`
   - Update UI components in relevant widget files
   - Add server-side validation in `GameController.ts`

2. **Adding a New UI Component**:
   - Create a new widget file following the pattern of existing widgets
   - Integrate with the application state
   - Add to the scaffold in `widget_application_scaffold.dart`

3. **Adding a New API Endpoint**:
   - Create a new route file in `backend/src/routes/`
   - Add to routes array in `routes/index.ts`
   - Implement corresponding client-side HTTP request in `services/http_service.dart`

### Key Areas for Potential Improvements

1. **Code Organization**:
   - The frontend has some redundancy in state management
   - Backend could benefit from more TypeScript type safety

2. **Error Handling**:
   - More robust error handling for network failures
   - Better user feedback for error states

3. **Testing**:
   - Add unit and integration tests for both frontend and backend

4. **Performance Optimization**:
   - Optimize MongoDB queries for high score retrieval
   - Reduce unnecessary Socket.IO broadcasts

By following this documentation, an AI system should be able to effectively navigate the codebase and implement fullstack feature operations for the Yatzy multiplayer game.
