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

    style D stroke-dasharray: 5 5, fill:#eee;

