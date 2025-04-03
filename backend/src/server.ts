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

const PORT: number = 8002;

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
  //app.use(express.static(path.join(__dirname, "/build")));
  app.use("/new", express.static(path.join(__dirname, "web")));

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