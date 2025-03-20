# unityplugin

Unity source ( Mind funny assets, taken from asset store as free assets :) ) for the client_system Flutter project.

It features websocket to communicate from flutter to unity web until issue is resolved. It is though interesting to learn how that can work anyway!
NodeJS server gets connected to Unity, sends back uuid which unity sends to flutter to use as id for server sending messages.
If connection abort it all repeats automatically so robust protocol!

I use Unity 2022.1.0b5 currently

[Link To Client](https://github.com/jesseburstrom/proj/)


![Editor Image](unity.jpg?raw=true "Server Database")

After build at flutter in build/web/UnityLibrary/index.html check file TransparencyFix/transparency-fix-flutter.txt to fix transparency on web build.
