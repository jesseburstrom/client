### Codebase Analysis: jesseburstrom-client

**Version:** 1.0
**Date:** 2024-10-27

**Format:**
[F] File Path
  [C] Class Name
    [f] methodOrFunctionName() -> [Dependency: Class/Function/Module (Location)]
    [v] propertyName : Type
    [extends/with/implements] BaseClass/Mixin/Interface (Location)
  [f] topLevelFunctionName() -> [Dependency: Class/Function/Module (Location)]

**--- Backend (Node.js/TypeScript) ---**

[F] backend/src/server.ts
  [f] (Top Level Script)
    -> express (External)
    -> routes/index -> routes() ([F]backend/src/routes/index.ts)
    -> db -> initializeDbConnection() ([F]backend/src/db.ts)
    -> path (External: Node)
    -> cors (External)
    -> socket.io -> Server ([F]backend/node_modules/socket.io)
    -> http -> createServer (External: Node)
    -> services/GameService ([F]backend/src/services/GameService.ts)
    -> services/GameLogService ([F]backend/src/services/GameLogService.ts)
    -> services/TopScoreService ([F]backend/src/services/TopScoreService.ts)
    -> controllers/GameController ([F]backend/src/controllers/GameController.ts)
    -> controllers/PlayerController ([F]backend/src/controllers/PlayerController.ts)
    -> controllers/ChatController ([F]backend/src/controllers/ChatController.ts)
    -> routes/spectateGameRoute -> spectateGameRoute, initializeSpectateRoute ([F]backend/src/routes/spectateGameRoute.ts)
    - Creates: Express app, httpServer, io (Socket.IO Server)
    - Creates: gameLogService, topScoreService, gameService, gameController, playerController, chatController
    - Configures: CORS, express.json, express.static
    - Loops through `routes()` result, calls `app[method](path, handler)`
    - Calls: `initializeSpectateRoute(gameService, gameLogService)`
    - Sets up Socket.IO connection ('connect' event)
      - Inside 'connect':
        -> socket.emit('welcome')
        -> socket.on('echo', ...) -> socket.emit('echo')
        -> gameController.registerSocketHandlers(socket)
        -> playerController.registerSocketHandlers(socket)
        -> chatController.registerSocketHandlers(socket)
        -> socket.on('sendToServer', ...)
        -> socket.on('sendToClients', ...)
        -> socket.on('disconnect', ...) -> gameService.handlePlayerDisconnect(socket.id)
    - Defines HTTP GET '/flutter', '*' routes -> res.sendFile()
    - Calls: `initializeDbConnection()`
    - Calls: `httpServer.listen()`

[F] backend/src/db.ts
  [v] client : MongoClient (External: mongodb)
  [f] initializeDbConnection() -> MongoClient.connect (External: mongodb)
  [f] getDbConnection(dbName: string) : Db -> client.db() (External: mongodb)

[F] backend/src/routes/index.ts
  [f] routes() -> Array<RouteObject>
    -> ./logInRoute ([F]backend/src/routes/logInRoute.ts)
    -> ./logRoute ([F]backend/src/routes/logRoute.ts)
    -> ./getLogRoute ([F]backend/src/routes/getLogRoute.ts)
    -> ./signUpRoute ([F]backend/src/routes/signUpRoute.ts)
    -> ./getTopScores ([F]backend/src/routes/getTopScores.ts)
    -> ./updateTopScore ([F]backend/src/routes/updateTopScore.ts)
    <- backend/src/server.ts

[F] backend/src/routes/logInRoute.ts
  [v] logInRoute : { path, method, handler }
    [f] handler(req, res)
      -> bcrypt (External)
      -> jsonwebtoken (External)
      -> ../db -> getDbConnection() ([F]backend/src/db.ts)
      -> db.collection('users').findOne()
      -> bcrypt.compare()
      -> jwt.sign()
      -> res.status().json() / res.sendStatus()

[F] backend/src/routes/logRoute.ts
  [v] logRoute : { path, method, handler }
    [f] handler(req, res)
      -> jsonwebtoken (External)
      -> ../db -> getDbConnection() ([F]backend/src/db.ts)
      -> jwt.verify()
      -> db.collection('logs').findOneAndUpdate()
      -> res.status().json()

[F] backend/src/routes/getLogRoute.ts
  [v] getLogRoute : { path, method, handler }
    [f] handler(req, res)
      -> jsonwebtoken (External)
      -> ../db -> getDbConnection() ([F]backend/src/db.ts)
      -> jwt.verify()
      -> db.collection('logs').find().toArray()
      -> res.status().json()

[F] backend/src/routes/signUpRoute.ts
  [v] signUpRoute : { path, method, handler }
    [f] handler(req, res)
      -> bcrypt (External)
      -> jsonwebtoken (External)
      -> ../db -> getDbConnection() ([F]backend/src/db.ts)
      -> db.collection('users').findOne()
      -> bcrypt.hash()
      -> db.collection('users').insertOne()
      -> db.collection('logs').insertOne()
      -> jwt.sign()
      -> res.status().json() / res.sendStatus()

[F] backend/src/routes/getTopScores.ts
  [v] getTopScores : { path, method, handler }
    [f] handler(req, res)
      -> ../db -> getDbConnection() ([F]backend/src/db.ts)
      -> db.collection(...).find().sort().toArray()
      -> res.status().json() / res.sendStatus()

[F] backend/src/routes/updateTopScore.ts
  [v] updateTopScore : { path, method, handler }
    [f] handler(req, res)
      -> ../db -> getDbConnection() ([F]backend/src/db.ts)
      -> db.collection(...).insertOne()
      -> db.collection(...).find().sort().toArray()
      -> res.status().json() / res.sendStatus()

[F] backend/src/routes/spectateGameRoute.ts
  [v] gameServiceInstance : GameService ([F]backend/src/services/GameService.ts)
  [v] gameLogServiceInstance : GameLogService ([F]backend/src/services/GameLogService.ts)
  [f] initializeSpectateRoute(gs, gls) <- backend/src/server.ts
  [v] spectateGameRoute : { path, method, handler }
    [f] handler(req, res)
      -> gameServiceInstance.getGame()
      -> gameLogServiceInstance.getGameLog()
      -> game.toJSON()
      -> res.status().json()

[F] backend/src/controllers/ChatController.ts
  [C] ChatController
    [v] io : Server (External: socket.io)
    [v] gameService : GameService ([F]backend/src/services/GameService.ts)
    [f] constructor(io, gameService) <- backend/src/server.ts
    [f] registerSocketHandlers(socket) <- backend/src/server.ts
      -> socket.on('sendToClients', ...) -> this.handleChatMessage()
      -> socket.on('sendToServer', ...) -> this.handleServerChatMessage()
    [f] handleChatMessage(socket, data)
      -> gameService.getGame()
      -> io.to(playerId).emit('onClientMsg')
    [f] handleServerChatMessage(socket, data)
      -> gameService.getGame()
      -> io.to(playerId).emit('onClientMsg')
      -> socket.to(room).emit('onClientMsg')
    [f] broadcastToPlayersInSameGame(socket, data)
      -> gameService.getAllGames()
      -> io.to(playerId).emit('onClientMsg')

[F] backend/src/controllers/GameController.ts
  [C] GameController
    [v] gameService : GameService ([F]backend/src/services/GameService.ts)
    [v] gameLogService : GameLogService ([F]backend/src/services/GameLogService.ts)
    [f] constructor(gameService, gameLogService) <- backend/src/server.ts
    [f] registerSocketHandlers(socket) <- backend/src/server.ts
      -> socket.on('sendToServer', ...) -> handles various actions (requestGame, joinGame, useRegret, etc.)
      -> socket.on('sendToClients', ...) -> handles sendDices, sendSelection
    [f] handleRequestGame(socket, data) -> PlayerFactory.createPlayer(), gameService.createOrJoinGame()
    [f] handleRequestJoinGame(socket, data) -> gameService.getGame(), PlayerFactory.createPlayer(), gameService.joinGame(), gameService.notifyGameUpdate(), gameService.broadcastGameList()
    [f] handleRemoveGame(socket, data) -> gameService.getGame(), gameService.removeGame(), gameService.broadcastGameList()
    [f] handleSendDices(socket, data) -> gameService.getGame(), gameService.processDiceRoll()
    [f] handleSendSelection(socket, data) -> gameService.getGame(), gameService.processSelection(), gameService.forwardSelectionToPlayers()
    [f] handleUseRegret(socket, data) -> gameService.getGame(), gameService.logRegret(), gameService.notifyGameUpdate()
    [f] handleUseExtraMove(socket, data) -> gameService.getGame(), gameService.logExtraMove(), gameService.notifyGameUpdate()
    [f] handleSpectateGame(socket, data) -> gameService.getGame(), gameLogService.getGameLog(), game.toJSON(), gameLogService.logSpectate(), socket.emit('onServerMsg'), gameService.addSpectator()

[F] backend/src/controllers/PlayerController.ts
  [C] PlayerController
    [v] gameService : GameService ([F]backend/src/services/GameService.ts)
    [v] gameLogService : GameLogService ([F]backend/src/services/GameLogService.ts)
    [v] playerRegistry : Map<string, boolean>
    [f] constructor(gameService, gameLogService) <- backend/src/server.ts
    [f] registerSocketHandlers(socket) <- backend/src/server.ts
      -> socket.on('sendToServer', ...) -> this.handleGetId()
    [f] handleGetId(socket) -> playerRegistry.set(), socket.emit('onServerMsg'), gameService.broadcastGameListToPlayer()

[F] backend/src/services/GameLogService.ts
  [C] GameLogService
    [f] constructor() <- backend/src/server.ts
    [f] getCollection() : Collection<GameLog> -> getDbConnection().collection() ([F]backend/src/db.ts)
    [f] getDatabaseName()
    [f] getCollectionName()
    [f] logGameStart(game: Game) -> this.getCollection().replaceOne()
    [f] logMove(gameId, move: GameMove) -> this.getCollection().updateOne(), this.getCollection().findOne(), this.getCollection().insertOne()
    [f] logGameEnd(gameId, finalScores) -> this.getCollection().updateOne()
    [f] getGameLog(gameId) : Promise<GameLog | null> -> this.getCollection().findOne()
    [f] logSpectate(gameId, spectatorId, spectatorName) -> this.getGameLog(), this.getCollection().updateOne()

[F] backend/src/services/GameService.ts
  [C] GameService
    [v] games : Map<number, Game>
    [v] spectators : Map<number, Set<string>>
    [v] gameIdCounter : number
    [v] io : Server (External: socket.io)
    [v] gameLogService : GameLogService ([F]backend/src/services/GameLogService.ts)
    [v] topScoreService : TopScoreService ([F]backend/src/services/TopScoreService.ts)
    [f] constructor(io, gameLogService, topScoreService) <- backend/src/server.ts
    [f] addSpectator(gameId, spectatorId) -> games.get(), spectators.set/get(), game.toJSON(), io.to().emit('onServerMsg')
    [f] removeSpectator(spectatorId) -> spectators.delete()
    [f] createGame(gameType, maxPlayers) : Game -> new Game(), games.set(), gameLogService.logGameStart()
    [f] findAvailableGame(gameType, maxPlayers) : Game | null -> games.values() iteration
    [f] getGame(gameId) : Game | undefined -> games.get()
    [f] getAllGames() : Game[] -> Array.from(games.values())
    [f] removeGame(gameId) : boolean -> games.get(), game.players.map(), player.getScore(), gameLogService.logGameEnd(), games.delete()
    [f] joinGame(gameId, player: Player) : Game | null -> games.get(), game.addPlayer(), gameLogService.logGameStart()
    [f] handlePlayerDisconnect(playerId) <- backend/src/server.ts (socket disconnect)
      -> games iteration, game.findPlayerIndex(), gameLogService.logMove(), game.markPlayerAborted(), this.handleGameFinished(), this.notifyGameUpdate(), this.broadcastGameList(), this.removeSpectator()
    [f] broadcastGameList() -> games.values().map(game.toJSON()), io.emit('onServerMsg')
    [f] broadcastGameListToPlayer(playerId) -> games.values().map(game.toJSON()), io.to(playerId).emit('onServerMsg')
    [f] notifyGameUpdate(game: Game) -> game.toJSON(), io.to(player.id).emit('onServerMsg'), spectators.get(), io.to(spectatorId).emit('onServerMsg')
    [f] handlePlayerStartingNewGame(playerId) -> this.handlePlayerDisconnect()
    [f] handlePlayerAbort(playerId) -> this.handlePlayerDisconnect()
    [f] handleGameFinished(game: Game) -> game.players.map(), player.getScore(), gameLogService.logGameEnd(), topScoreService.updateTopScore(), this.notifyGameFinished(), games.delete(), spectators.delete(), this.broadcastGameList()
    [f] notifyGameFinished(game: Game) -> game.toJSON(), io.to(player.id).emit('onServerMsg'), spectators.get(), io.to(spectatorId).emit('onServerMsg')
    [f] processDiceRoll(gameId, playerId, diceValues, keptDice) -> games.get(), game.findPlayerIndex(), gameLogService.logMove(), game.setDiceValues(), game.incrementRollCount(), io.to(player.id).emit('onClientMsg'), spectators.get(), io.to(spectatorId).emit('onClientMsg'), this.notifyGameUpdate()
    [f] processSelection(gameId, playerId, selectionLabel, score) -> games.get(), game.findPlayerIndex(), gameLogService.logMove(), game.applySelection(), game.isGameFinished(), this.handleGameFinished(), game.setDiceValues(), game.advanceToNextActivePlayer(), this.notifyGameUpdate()
    [f] forwardSelectionToPlayers(gameId, senderId, selectionData) -> games.get(), getSelectionLabel(), game.findPlayerIndex(), io.to(player.id).emit('onClientMsg')
    [f] createOrJoinGame(gameType, maxPlayers, player: Player) : Game -> this.handlePlayerStartingNewGame(), this.findAvailableGame(), this.createGame(), game.addPlayer(), gameLogService.logGameStart(), this.notifyGameUpdate(), this.broadcastGameList()
    [f] logRegret(gameId, playerId) -> games.get(), game.findPlayerIndex(), gameLogService.logMove()
    [f] logExtraMove(gameId, playerId) -> games.get(), game.findPlayerIndex(), gameLogService.logMove()

[F] backend/src/services/TopScoreService.ts
  [C] TopScoreService
    [f] constructor() <- backend/src/server.ts
    [f] getDb() : Db -> getDbConnection() ([F]backend/src/db.ts)
    [f] getCollection(gameType) : Collection<TopScoreEntry> -> this.getDb().collection()
    [f] getTopScores(gameType, limit) : Promise<TopScoreEntry[]> -> this.getCollection().find().sort().limit().toArray()
    [f] updateTopScore(gameType, name, score) : Promise<boolean> -> this.getCollection().insertOne()

[F] backend/src/models/BoardCell.ts
  [C] BoardCell
    [v] index, label, value, fixed, isNonScoreCell
    [f] constructor()
    [f] toJSON() : any
    [sf] fromJson(data, defaultLabel) : BoardCell -> new BoardCell()

[F] backend/src/models/Dice.ts
  [C] Dice
    [v] values : number[]
    [v] diceCount : number
    [f] constructor()
    [f] roll() : number[] -> Math.random()
    [f] rollSelected(keptDice: boolean[]) : number[] -> Math.random()
    [f] getValues() : number[]
    [f] setValues(values: number[])
    [f] reset()

[F] backend/src/models/Game.ts
  [C] Game
    [v] id, gameType, players: Player[], maxPlayers, connectedPlayers, gameStarted, gameFinished, playerToMove, diceValues: number[], userNames: string[], gameId, playerIds: string[], abortedPlayers: boolean[], rollCount: number, turnNumber: number
    -> PlayerFactory ([F]backend/src/models/Player.ts)
    -> uuidv4 (External: uuid)
    -> getSelectionIndex ([F]backend/src/utils/yatzyMapping.ts)
    [f] constructor(id, gameType, maxPlayers) -> PlayerFactory.createEmptyPlayer()
    [f] addPlayer(player: Player, position: number) : boolean -> this.findEmptySlot()
    [f] removePlayer(playerId: string) : boolean -> this.findPlayerIndex(), this.advanceToNextActivePlayer()
    [f] markPlayerAborted(playerId: string) : boolean -> this.findPlayerIndex(), this.advanceToNextActivePlayer()
    [f] findPlayerIndex(playerId: string) : number -> players.findIndex()
    [f] findEmptySlot() : number -> players.findIndex()
    [f] isGameFull() : boolean
    [f] getCurrentTurnNumber() : number
    [f] incrementRollCount()
    [f] advanceToNextActivePlayer()
    [f] applySelection(playerIndex, selectionLabel, score) -> getSelectionIndex(), player.calculateScores()
    [f] isGameFinished() : boolean -> player.hasCompletedGame()
    [f] setDiceValues(values: number[])
    [f] toJSON() : any -> player.toJSON()
    [sf] fromJSON(data) : Game -> new Game(), Player.fromJSON(), PlayerFactory.createPlayer(), PlayerFactory.createEmptyPlayer()

[F] backend/src/models/Player.ts
  [C] Player
    [v] id, username, isActive, cells: BoardCell[], score, upperSum, bonusAchieved, regretsLeft?, extraMovesLeft?
    -> BoardCell ([F]backend/src/models/BoardCell.ts)
    -> GameConfig, getBaseGameType ([F]backend/src/utils/gameConfig.ts)
    [f] constructor(id, username, gameType, ...) -> new BoardCell()
    [f] calculateScores() -> GameConfig
    [f] hasCompletedGame() : boolean -> cells.every()
    [f] getScore() : number
    [f] toJSON() : any -> cell.toJSON()
    [sf] fromJSON(data, gameType) : Player -> BoardCell.fromJson(), new Player()
  [C] PlayerFactory
    [sf] createPlayer(id, username, gameType) : Player -> new Player()
    [sf] createEmptyPlayer(gameType) : Player -> new BoardCell(), new Player()

[F] backend/src/utils/gameConfig.ts
  [v] GameConfig : { [key: string]: GameTypeConfig }
  [f] getBaseGameType(gameType: string) : keyof typeof GameConfig

[F] backend/src/utils/index.ts
  [f] randomInt(min, max) -> Math.random()
  [f] delay(ms) -> Promise(setTimeout)
  [f] isDefined(value)
  [f] deepCopy(obj) -> JSON.parse(JSON.stringify())

[F] backend/src/utils/yatzyMapping.ts
  [v] gameTypeMappings : { [key: string]: string[] }
  [f] getBaseGameType(gameType: string) : keyof typeof gameTypeMappings
  [f] getSelectionLabel(gameType, index) : string | null
  [f] getSelectionIndex(gameType, label) : number


**--- Frontend (Flutter/Dart) ---**

[F] lib/main.dart
  [f] main()
    -> WidgetsFlutterBinding (External: Flutter)
    -> SharedPrefProvider.loadPrefs() ([F]lib/shared_preferences.dart)
    -> configureInjection() ([F]lib/injection.dart)
    -> runApp()
    -> MultiBlocProvider (External: flutter_bloc)
      -> LanguageBloc ([F]lib/states/bloc/language/language_bloc.dart)
      -> SetStateCubit ([F]lib/states/cubit/state/state_cubit.dart)
      -> AppWidget ([F]lib/core/app_widget.dart)

[F] lib/core/app_widget.dart
  [C] AppWidget extends StatelessWidget
    [v] _appRouter : AppRouter ([F]lib/router/router.dart)
    [f] build(context)
      -> topScore = TopScore() ([F]lib/top_score/top_score.dart)
      -> animationsScroll = AnimationsScroll() ([F]lib/scroll/animations_scroll.dart)
      -> tutorial = Tutorial() ([F]lib/tutorial/tutorial.dart)
      -> dices = Dices() ([F]lib/dices/dices.dart)
      -> app = Application() ([F]lib/application/application.dart)
      -> chat = Chat() ([F]lib/chat/chat.dart)
      -> ServiceProvider.initialize() ([F]lib/services/service_provider.dart)
        -> SocketService ([F]lib/services/socket_service.dart)
        -> GameService ([F]lib/services/game_service.dart)
      -> MaterialApp.router() (External: Flutter)
        -> ServiceProvider.of(context).socketService.connect()
        -> app.setSocketService(service)

[F] lib/injection.dart
  [v] getIt : GetIt (External: get_it)
  [f] configureInjection(environment) -> getIt.initApiInjection() (Generated: [F]lib/injection.config.dart)

[F] lib/injection.config.dart (Generated)
  [X] GetItInjectableX on GetIt
    [f] init() -> GetItHelper, injectableModule.router, LanguageBloc, SetStateCubit

[F] lib/core/injectable_modules.dart
  [C] InjectableModule (abstract)
    [f] router : AppRouter -> new AppRouter() ([F]lib/router/router.dart)

[F] lib/router/router.dart
  [C] AppRouter extends $AppRouter (Generated: [F]lib/router/router.gr.dart)
    [v] routes -> List<AutoRoute> (Defines SettingsView, ApplicationView)

[F] lib/router/router.gr.dart (Generated)
  [C] $AppRouter extends RootStackRouter
  [C] ApplicationView extends PageRouteInfo
  [C] SettingsView extends PageRouteInfo

[F] lib/shared_preferences.dart
  [C] SharedPrefProvider (abstract)
    [v] prefs : SharedPreferences (External: shared_preferences)
    [sf] loadPrefs() -> SharedPreferences.getInstance()
    [sf] fetchPref...(key) -> prefs.get...()
    [sf] setPref...(key, value) -> prefs.set...()

[F] lib/startup.dart
  [v] (Global Variables: isOnline, isDebug, localhost, applicationStarted, userName, ...)

[F] lib/application/application.dart
  [C] Application with LanguagesApplication
    [v] context, inputItems, gameDices : Dices
    [v] (State variables: isSpectating, gameType, nrPlayers, gameData, gameId, myPlayerId, board state arrays, ...)
    [v] animation : AnimationsApplication ([F]lib/application/animations_application.dart)
    [v] socketService : SocketService? ([F]lib/services/socket_service.dart)
    [f] constructor() -> gameDices.setCallbacks(), languagesSetup()
    [f] getChosenLanguage() -> chosenLanguage (Global)
    [f] getStandardLanguage() -> standardLanguage (Global)
    [f] callbackCheckPlayerToMove() -> playerToMove == myPlayerId
    [f] callbackUnityCreated() -> gameDices.sendStartToUnity()
    [f] callbackUpdateDiceValues() -> updateDiceValues(), socketService?.sendToClients()
    [f] updateDiceValues() -> clearFocus(), yatzyFunctions[i](), context.read<SetStateCubit>().setState()
    [f] setAppText()
    [f] setup() -> topScore.loadTopScoreFromServer(), gameDices.initDices(), yatzyFunctions assignment, state initialization
    [f] setSocketService(service)

[F] lib/application/application_functions_internal.dart
  [X] ApplicationFunctionsInternal on Application
    [f] clearFocus()
    [f] cellClick(player, cell) -> getSelectionLabel(), socketService?.sendToClients(), applyLocalSelection()
    [f] applyLocalSelection(player, cell, score) -> gameDices.sendResetToUnity(), fixedCell assignment, score calculations, colorBoard(), gameDices.clearDices(), context.read<SetStateCubit>().setState()
    [f] colorBoard()

[F] lib/application/communication_application.dart
  [X] CommunicationApplication on Application
    [f] resetDices() -> gameDices.clearDices(), clearFocus()
    [f] handlePlayerAbort(abortedPlayerIndex) -> advanceToNextActivePlayer(), colorBoard()
    [f] advanceToNextActivePlayer() -> colorBoard(), resetDices(), gameDices.sendResetToUnity(), gameDices.sendStartToUnity()
    [f] callbackOnServerMsg(data) -> ServiceProvider.of().socketService, SharedPrefProvider.fetchPrefObject(), _processGameUpdate(), setup(), router.push/pop, _checkIfPlayerAborted(), showDialog()
    [f] _checkIfPlayerAborted() -> handlePlayerAbort(), _advanceToNextActivePlayer(), colorBoard()
    [f] _advanceToNextActivePlayer() -> resetDices(), gameDices.sendResetToUnity(), gameDices.sendStartToUnity()
    [f] _processGameUpdate(data) -> game = Game.fromJson(), context.read<SetStateCubit>().setState() // Handles spectator logic here as well
    [f] chatCallbackOnSubmitted(text) -> chat.scrollController, socketService?.sendToClients()
    [f] updateChat(text) -> chat.messages.add(), chat.scrollController.animateTo()
    [f] callbackOnClientMsg(data) -> app.callbackOnClientMsg(), updateDiceValues(), gameDices.updateDiceImages(), gameDices.sendDicesToUnity(), updateChat(), router.push()

[F] lib/application/application_functions_internal_calc_dice_values.dart
  [X] ApplicationCalcDiceValues on Application
    [f] (Pure score calculation functions: zero, calcOnes, calcPair, calcYatzy, etc.) -> calcDiceNr(), gameDices.diceValue

[F] lib/application/animations_application.dart
  [C] AnimationsApplication
    [v] animationControllers, animationDurations, cellAnimationControllers, ...
    [f] animateBoard() -> controller.forward()
    [f] setupAnimation(ticket, nrPlayers, ...) -> AnimationController(), CurveTween()

[F] lib/application/languages_application.dart
  [M] LanguagesApplication
    [f] languagesSetup()
    [f] getText(textVariable)
    [v] (_ones, _twos, ..., _settings_, ...) : Map<String, String>

[F] lib/application/widget_application.dart
  [C] WidgetSetupGameBoard extends StatefulWidget -> _WidgetSetupGameBoardState
  [C] _WidgetSetupGameBoardState extends State<WidgetSetupGameBoard> with LanguagesApplication
    [f] build(context) -> app.setup(), app.setAppText(), AnimatedBuilder(), Positioned(), Container(), FittedBox(), Text(), GestureDetector() -> app.cellClick(), context.read<SetStateCubit>().setState()
  [C] WidgetDisplayGameStatus extends StatefulWidget -> _WidgetDisplayGameStatusState
  [C] _WidgetDisplayGameStatusState extends State<WidgetDisplayGameStatus> with LanguagesApplication
    [f] build(context) -> AutoSizeText(), Text() (Displays game state from `app`)

[F] lib/application/widget_application_scaffold.dart
  [X] WidgetApplicationScaffold on Application
    [f] widgetScaffold(context, state) -> MediaQuery, Scaffold(), Stack(), Positioned(), WidgetDices(), WidgetTopScore(), WidgetSetupGameBoard(), WidgetDisplayGameStatus(), WidgetChat(), WidgetAnimationsScroll(), widgetFloatingButton()

[F] lib/application/widget_application_settings.dart
  [X] WidgetApplicationSettings on Application
    [f] widgetWaitingGame(context) -> inputItems.widgetButton(), Text() -> onAttemptJoinGame(), onSpectateGame()
    [f] onSpectateGame(context, gameId) -> ServiceProvider.of().socketService.sendToServer(), context.read<SetStateCubit>().setState()
    [f] onAttemptJoinGame(context, i) -> ServiceProvider.of().socketService.sendToServer()
    [f] onStartGameButton(context, state) -> ServiceProvider.of().socketService.sendToServer(), setup(), AutoRouter.of().push/pop(), SharedPrefProvider.setPrefObject()
    [f] onChangeUserName(value)
    [f] widgetScaffoldSettings(context, state) -> DefaultTabController(), Scaffold(), AppBar(), TabBar(), TabBarView(), ListView(), Card(), Container(), Column(), Row(), Text(), inputItems various widgets, ElevatedButton(), widgetWaitingGame(), SpectatorGameBoard() ([F]lib/widgets/spectator_game_board.dart), gameDices.widgetUnitySettings()

[F] lib/chat/chat.dart
  [C] ChatMessage
  [C] Chat
    [v] _getChosenLanguage, _standardLanguage, setState, inputItems, callbackOnSubmitted
    [v] chatTextController, scrollController, focusNode, listenerKey, messages: List<ChatMessage>
    [f] constructor()
    [f] onSubmitted(value, context) -> chatTextController.clear(), messages.add(), callbackOnSubmitted(), setState(), scrollController.animateTo()

[F] lib/chat/languages_chat.dart
  [M] LanguagesChat
    [v] _sendMessage
    [f] languagesSetup()
    [f] getText()

[F] lib/chat/widget_chat.dart
  [C] WidgetChat extends StatefulWidget -> _WidgetChatState
  [C] _WidgetChatState extends State<WidgetChat> with LanguagesChat
    [f] build(context) -> Container(), Column(), Row(), Icon(), Text(), Expanded(), ListView.builder(), Align(), widgetInputText() -> chat.onSubmitted()

[F] lib/dices/dices.dart
  [C] Dices extends LanguagesDices
    [v] setState, inputItems
    [v] (State: holdDices, nrRolls, diceValue, diceRef, ...)
    [v] unityWidgetController: UnityWidgetController, unityCreated, unityDices, ...
    [f] constructor()
    [f] setCallbacks(cbUpdateDiceValues, cbUnityCreated, cbCheckPlayerToMove)
    [f] clearDices()
    [f] initDices(nrdices) -> sendResetToUnity()
    [f] holdDice(dice)
    [f] updateDiceImages()
    [f] rollDices(context) -> Random(), callbackUpdateDiceValues()
    [f] widgetUnitySettings(state) -> inputItems.widgetCheckbox(), send...ChangedToUnity()

[F] lib/dices/unity_communication.dart
  [X] UnityCommunication on Dices
    [f] send...ToUnity() -> UnityMessage.toJson(), unityWidgetController.postMessage()
    [f] onUnityMessage(message) -> jsonDecode(), callbackUpdateDiceValues()
    [f] onUnityUnloaded()
    [f] onUnityCreated(controller) -> unityWidgetController assignment, sendResetToUnity(), callbackUnityCreated()
    [f] onUnitySceneLoaded(sceneInfo)

[F] lib/dices/unity_message.dart
  [C] UnityMessage
    [f] constructor()
    [f] toJson()
    [sf] fromJson()

[F] lib/dices/widget_dices.dart
  [C] WidgetDices extends StatefulWidget -> _WidgetDicesState
  [C] _WidgetDicesState extends State<WidgetDices> with TickerProviderStateMixin
    [f] setupAnimation(ticket) -> AnimationController(), CurveTween()
    [f] build(context) -> Positioned(), SizedBox(), UnityWidget(), Stack(), Container(), Image.asset(), GestureDetector() -> app.gameDices.holdDice(), AnimatedBuilder(), Listener() -> app.gameDices.rollDices()

[F] lib/input_items/input_items.dart
  [C] InputItems
    [f] (Various UI widget factory methods: widgetImage, widgetInputText, widgetButton, widgetCheckbox, widgetSlider, widgetDropDownList, ...)

[F] lib/models/board_cell.dart (Frontend)
  [C] BoardCell
    [v] index, label, value, fixed, xPos, yPos, ...
    [f] constructor()
    [f] setPosition()
    [f] get displayText
    [f] get isEmpty
    [f] clear()
    [f] setValue()
    [f] fix()
    [f] setFocus()
    [f] copyWith()

[F] lib/models/game.dart (Frontend)
  [C] Game
    [v] gameId, gameType, maxPlayers, players: List<Player>, gameStarted, gameFinished, playerToMove, diceValues, ...
    [f] constructor()
    [f] get isMyTurn
    [f] get canRoll
    [f] get currentPlayer -> players[]
    [f] get myPlayer -> players[]
    [f] calculateScores() -> player.calculateScores()
    [f] advanceToNextPlayer() -> onPlayerTurnChanged?.call()
    [f] setDiceValues(values) -> onDiceValuesChanged?.call()
    [f] resetDice() -> onDiceValuesChanged?.call()
    [f] selectCell(cellIndex) -> player.cells[], cell.fix(), calculateScores(), checkGameFinished(), advanceToNextPlayer()
    [f] checkGameFinished() -> player.hasCompletedGame
    [sf] fromJson(json) -> _getCellLabelsForGameType(), new Player(), new BoardCell(), new Game()
    [f] toJson() -> player.id, player.username
    [sf] _getCellLabelsForGameType(gameType)

[F] lib/models/player.dart (Frontend)
  [C] Player
    [v] id, username, isActive, cells: List<BoardCell>, _totalScore, _upperSectionSum
    [f] constructor()
    [f] get totalScore
    [f] get upperSectionSum
    [f] calculateScores(bonusThreshold, bonusAmount, upperSectionEnd)
    [f] clearUnfixedCells() -> cell.clear()
    [f] get hasCompletedGame -> cells.every()
    [sf] fromJson(json, cellLabels) -> List.generate(BoardCell()), new Player()
    [f] toJson() -> cells.map(cell.value/fixed)

[F] lib/scroll/animations_scroll.dart
  [C] AnimationsScroll with LanguagesAnimationsScroll
    [v] _getChosenLanguage, _standardLanguage, keyXPos, keyYPos, animationController, positionAnimation
    [f] constructor()
    [f] getChosenLanguage()

[F] lib/scroll/languages_animations_scroll.dart
  [M] LanguagesAnimationsScroll
    [v] _scrollText
    [f] languagesSetup()
    [f] getText()

[F] lib/scroll/widget_scroll.dart
  [C] WidgetAnimationsScroll extends StatefulWidget -> _WidgetAnimationsScrollState
  [C] _WidgetAnimationsScrollState extends State<WidgetAnimationsScroll> with TickerProviderStateMixin, LanguagesAnimationsScroll
    [f] setupAnimation(ticket) -> AnimationController(), CurveTween()
    [f] build(context) -> AnimatedBuilder(), Positioned(), SizedBox(), FittedBox(), DefaultTextStyle(), AnimatedTextKit() (External: animated_text_kit)

[F] lib/services/game_service.dart (Frontend)
  [C] GameService
    [v] socketService : SocketService ([F]lib/services/socket_service.dart)
    [v] _game : Game? ([F]lib/models/game.dart)
    [v] onGameUpdated : Function(Game)?
    [v] onError : Function(String)?
    [f] constructor() -> socketService.onGameUpdate = _handleGameUpdate
    [f] get game
    [f] _handleGameUpdate(updatedGame) -> _game assignment, onGameUpdated?.call()
    [f] createGame(...) -> socketService.createGame()
    [f] joinGame(...) -> socketService.joinGame()
    [f] rollDice(...) -> socketService.rollDice()
    [f] calculateScoreForCell(cell, diceValues) -> _calculate...Score helpers
    [f] selectCell(cellIndex) -> socketService.selectCell()
    [f] _reportError(message) -> onError?.call()
    [f] (_calculate...Score helpers) - Pure score logic

[F] lib/services/http_service.dart
  [C] HttpService
    [v] baseUrl : String
    [f] constructor()
    [f] getDB(route) -> http.get (External: http)
    [f] postDB(route, json) -> http.post (External: http)
    [f] updateDB(route, json) -> http.post (External: http)
    [f] deleteDB(route) -> http.delete (External: http)
    [f] deleteUser(route, email) -> http.delete (External: http)
    [f] login(userName, password) -> http.post (External: http)
    [f] signup(userName, password) -> http.post (External: http)

[F] lib/services/service_provider.dart
  [C] ServiceProvider extends InheritedWidget
    [v] socketService : SocketService ([F]lib/services/socket_service.dart)
    [v] gameService : GameService ([F]lib/services/game_service.dart)
    [f] constructor()
    [sf] of(context) -> context.dependOnInheritedWidgetOfExactType()
    [sf] initialize(child, context) -> new SocketService(), new GameService(), new ServiceProvider()
    [f] updateShouldNotify(oldWidget)

[F] lib/services/socket_service.dart
  [C] SocketService
    [v] context : BuildContext
    [v] socket : io.Socket (External: socket_io_client)
    [v] socketId : String
    [v] isConnected : bool
    [v] game : Game? ([F]lib/models/game.dart)
    [v] onGameUpdate : Function(Game)?
    [v] onChatMessage : Function(Map<String, dynamic>)?
    [f] constructor()
    [f] connect() -> io.io(), _setupEventHandlers(), socket.connect()
    [f] _setupEventHandlers() -> socket.onConnect(), socket.onDisconnect(), socket.on('welcome'), socket.on('echo_response'), socket.on('onClientMsg'), socket.on('onServerMsg'), socket.on('userId'), socket.on('gameUpdate'), socket.on('chatMessage')
    [f] _sendEcho() -> socket.emit('echo')
    [f] _requestId() -> socket.emit('sendToServer')
    [f] _handleUserId(data) -> _updateState()
    [f] _handleClientMessage(data) -> app.callbackOnClientMsg(), _updateState()
    [f] _handleServerMessage(data) -> app.callbackOnServerMsg(), _updateState()
    [f] _handleGameUpdate(data) -> _processGameUpdate(), _updateState()
    [f] _processGameUpdate(gameData) -> game = Game.fromJson(), onGameUpdate?.call()
    [f] _handleChatMessage(data) -> onChatMessage?.call()
    [f] createGame(...) -> socket.emit('sendToServer')
    [f] joinGame(...) -> socket.emit('sendToServer')
    [f] rollDice(...) -> socket.emit('sendToServer')
    [f] selectCell(...) -> socket.emit('sendToServer')
    [f] sendChatMessage(...) -> socket.emit('sendToServer')
    [f] sendToClients(data) -> socket.emit('sendToClients')
    [f] sendToServer(data) -> socket.emit('sendToServer')
    [f] disconnect() -> socket.disconnect()
    [f] _updateState() -> context.read<SetStateCubit>().setState()

[F] lib/states/bloc/language/language_bloc.dart
  [C] LanguageBloc extends Bloc<LanguageEvent, String>
    [f] constructor() -> SharedPrefProvider.fetchPrefString() ([F]lib/shared_preferences.dart)
    [f] _languageChanged(event, emit) -> SharedPrefProvider.setPrefString(), emit()

[F] lib/states/bloc/language/language_event.dart
  [C] LanguageEvent (abstract)
  [C] LanguageChanged extends LanguageEvent

[F] lib/states/cubit/state/state_cubit.dart
  [C] SetStateCubit extends Cubit<int>
    [f] setState() -> emit()

[F] lib/top_score/top_score.dart
  [C] TopScore with LanguagesTopScore
    [v] _getChosenLanguage, _standardLanguage, animationController, loopAnimation, topScores
    [f] constructor()
    [f] loadTopScoreFromServer(gameType, cubit) -> HttpService.getDB(), jsonDecode(), cubit.setState()
    [f] updateTopScore(name, score, gameType) -> HttpService.postDB(), jsonDecode()

[F] lib/top_score/languages_top_score.dart
  [M] LanguagesTopScore
    [v] _topScores
    [f] languagesSetup()
    [f] getText()

[F] lib/top_score/widget_top_scores.dart
  [C] WidgetTopScore extends StatefulWidget -> _WidgetTopScoreState
  [C] _WidgetTopScoreState extends State<WidgetTopScore> with TickerProviderStateMixin, LanguagesTopScore
    [f] setupAnimation(ticket) -> AnimationController(), CurveTween()
    [f] build(context) -> AnimatedBuilder(), Positioned(), Container(), FittedBox(), Text(), Scrollbar(), ListView.builder(), Row()

[F] lib/tutorial/tutorial.dart
  [C] Tutorial
    [v] keyXPos, keyYPos, animationSide, animationController1/2/3, positionAnimation1/2/3
    [f] setup(ticket) -> AnimationController(), CurveTween()
    [f] widgetArrow(key, w, h, controller, text, side, scale) -> AnimatedBuilder(), RenderBox, Positioned(), Column()/Row(), SizedBox(), FittedBox(), Text(), Image.asset()

[F] lib/utils/yatzy_mapping_client.dart
  [v] _gameTypeMappingsClient : Map<String, List<String>>
  [f] _getBaseGameTypeClient(gameType)
  [f] _getBaseLabel(fullLabel)
  [f] getSelectionLabel(gameType, index) : String?
  [f] getSelectionIndex(gameType, label) : number

[F] lib/views/application_view.dart
  [C] ApplicationView extends StatefulWidget (@RoutePage) -> _ApplicationViewState
  [C] _ApplicationViewState extends State<ApplicationView> with TickerProviderStateMixin
    [f] initState() -> app.setup(), tutorial.setup(), WidgetsBinding.addPostFrameCallback(), app.animation.setupAnimation()
    [f] postFrameCallback(context) -> topScore.loadTopScoreFromServer()
    [f] build(context) -> BlocBuilder<SetStateCubit, int>(), app.widgetScaffold()

[F] lib/views/settings_view.dart
  [C] SettingsView extends StatefulWidget (@RoutePage) -> _SettingsViewHomeState
  [C] _SettingsViewHomeState extends State<SettingsView> with TickerProviderStateMixin
    [f] initState() -> TabController()
    [f] build(context) -> BlocBuilder<SetStateCubit, int>(), app.widgetScaffoldSettings()

[F] lib/widgets/spectator_game_board.dart
  [C] SpectatorGameBoard extends StatefulWidget -> _SpectatorGameBoardState
  [C] _SpectatorGameBoardState extends State<SpectatorGameBoard>
    [v] _horizontalScrollController, _verticalScrollController
    [f] build(context) -> Stack(), Column(), Container(), Text(), Row(), Expanded(), RawScrollbar(), SingleChildScrollView(), buildScoreTable(), Positioned.fill() (for overlay)
    [f] getDiceFace(value) -> Container(), Column(), Row() (Draws dice dots)
    [f] buildScoreTable(playerNames) -> Padding(), Table(), TableRow(), TableCell(), Text() (Builds UI table from gameData)


**--- Key Interactions & Entry Points ---**

*   **Backend:**
    *   Entry: `backend/src/server.ts` starts the Express server and Socket.IO listener.
    *   Database: `backend/src/db.ts` initializes and provides MongoDB connection.
    *   HTTP API: Handled by route files in `backend/src/routes/` (e.g., login, signup, top scores).
    *   WebSockets: `server.ts` sets up Socket.IO, delegates events to Controllers (`ChatController`, `GameController`, `PlayerController`).
    *   Core Logic: Services (`GameService`, `GameLogService`, `TopScoreService`) handle business logic, interacting with DB and models. `GameService` is central for game state.
    *   Models: Define data structures (`Game`, `Player`, `BoardCell`).
*   **Frontend:**
    *   Entry: `lib/main.dart` initializes Flutter, Bloc, DI, and runs `AppWidget`.
    *   Root Widget: `lib/core/app_widget.dart` sets up `MaterialApp.router`, initializes services (`ServiceProvider`), and major application components (`Application`, `Dices`, `Chat`, etc.).
    *   State Management: `BlocProvider` in `main.dart` (`LanguageBloc`, `SetStateCubit`). `SetStateCubit` is used widely for triggering UI updates.
    *   Navigation: `auto_route` defined in `lib/router/`. Views are in `lib/views/`.
    *   Networking: `SocketService` manages WebSocket connection. `HttpService` handles REST API calls (e.g., top scores). `ServiceProvider` makes these available.
    *   Core Logic Container: `lib/application/application.dart` (and its extensions) holds much of the UI state and orchestrates interactions between UI, services, and dice logic. *Note: This class is quite large.*
    *   UI Widgets: Specific UI parts are in `lib/application/widget_*`, `lib/chat/widget_chat.dart`, `lib/dices/widget_dices.dart`, `lib/top_score/widget_top_scores.dart`, etc.
    *   Models: Frontend models in `lib/models/` represent UI state, potentially differing slightly from backend models.
*   **Backend <-> Frontend:**
    *   **HTTP:** Frontend `HttpService` calls backend API routes (e.g., `/GetTopScores`, `/UpdateTopScore`, `/api/login`).
    *   **WebSockets:** Frontend `SocketService` connects to backend Socket.IO server.
        *   Client sends actions (`sendToServer`, `sendToClients`) handled by backend Controllers. Key actions: `requestGame`, `requestJoinGame`, `sendDices`, `sendSelection`, `chatMessage`, `spectateGame`.
        *   Server sends updates (`onServerMsg`, `onClientMsg`) handled by frontend `CommunicationApplication` extension (`callbackOnServerMsg`, `callbackOnClientMsg`). Key messages: `onGameStart`, `onGameUpdate`, `onGameFinished`, `sendDices`, `sendSelection`, `chatMessage`.