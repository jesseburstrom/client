import express from "express";
import { routes } from "./routes/index";
import { initializeDbConnection } from "./db";
import * as path from "path";
import cors from "cors";
import { Server } from "socket.io";
import { createServer } from "http";

// Import services
import { GameService } from "./services/GameService";

// Import controllers
import { GameController } from "./controllers/GameController";
import { PlayerController } from "./controllers/PlayerController";
import { ChatController } from "./controllers/ChatController";

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
  app[route.method](route.path, route.handler);
});

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
const gameService = new GameService(io);

// Create controller instances
const gameController = new GameController(gameService);
const playerController = new PlayerController(gameService);
const chatController = new ChatController(io, gameService);

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
    
    // Handle chat messages specifically
    if (data?.action === 'chatMessage') {
      console.log(`💬 Chat message from ${socket.id}:`, data);
    }
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
initializeDbConnection().then(() => {
  console.log("Database connection initialized");
  
  // Start the server
  httpServer.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Socket.IO server ready for connections`);
    isOnline ? console.log("SERVER MODE: ONLINE") : console.log("SERVER MODE: OFFLINE");
  });
});
