import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class WiFiDirectPage extends StatefulWidget {
  const WiFiDirectPage({super.key});

  @override
  WiFiDirectPageState createState() => WiFiDirectPageState();
}

class WiFiDirectPageState extends State<WiFiDirectPage> {
  final TextEditingController _controller = TextEditingController();

  final List<String> appData = [];
  int activeConnections = 0;
  bool isConnected = false;
  bool isGroupOwner = false;

  ServerSocket? serverSocket;
  final List<Socket> clients = [];
  Socket? clientSocket;

  Timer? updateTimer;

  static const platform =
      MethodChannel('org.katapp.flutter_p2p_demo/advertising');

  static const EventChannel _connectionEventChannel =
      EventChannel('org.katapp.flutter_p2p_demo/connection');

  @override
  void initState() {
    super.initState();
    _connectionEventChannel
        .receiveBroadcastStream()
        .listen(_onConnectionChange, onError: _onError);
    _init();
  }

  @override
  void dispose() {
    serverSocket?.close();
    clientSocket?.close();
    for (final client in clients) {
      client.close();
    }
    serverSocket = null;
    clientSocket = null;
    clients.clear();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      print("App is in background");
    } else if (state == AppLifecycleState.resumed) {
      print("App is in foreground");
    }
  }

  void _init() async {
    await Permission.nearbyWifiDevices.request();
    await Permission.location.request();

    try {
      await platform.invokeMethod('initWifiDirect');
    } on PlatformException catch (e) {
      print("Failed to init WiFi Direct: '${e.message}'.");
    }

    _startDiscovery();
  }

  void _onError(Object error) {
    print("Error received: $error");
    // Handle any errors
  }

  void _onConnectionChange(dynamic data) {
    final Map<String, dynamic> connectionInfo = Map<String, dynamic>.from(data);

    print("Connection details received: $connectionInfo");
    // Now you can use the data as needed
    final String groupOwnerAddress = connectionInfo['groupOwnerAddress'];
    final bool groupOwner = connectionInfo['isGroupOwner'];

    setState(() {
      isConnected = true;
      isGroupOwner = groupOwner;
    });

    // Use the received information as needed
    print("Group Owner Address: $groupOwnerAddress");
    print("Is Group Owner: $isGroupOwner");

    if (isGroupOwner) {
      _startServerSocket();
    } else {
      _connectToHost(groupOwnerAddress);
    }
  }

  void _startDiscovery() async {
    try {
      await platform.invokeMethod('wifiDirectDiscoverPeers');
    } on PlatformException catch (e) {
      print("Failed to start WiFi Direct Discovery: '${e.message}'.");
    }
  }

  void _addData(String data, bool isReceived) {

    if (appData.contains(data)) {
      return;
    }

    setState(() {
      appData.add(data);
    });

    if (!isReceived) {
      _controller.clear();
    }

    if (isGroupOwner && isConnected) {
      for (final client in clients) {
        client.write(data);
      }
    } else if (isConnected) {
      clientSocket?.write(data);
    }
  }

  void _startServerSocket() async {
    serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 8888);
    print('Hosting on: ${serverSocket?.address.address}:${serverSocket?.port}');
    serverSocket?.listen((client) {
      _handleClientConnection(client);
    });
  }

  void _handleClientConnection(Socket client) async {
    print(
        'Client connected: ${client.remoteAddress.address}:${client.remotePort}');
    clients.add(client);
    client.listen((data) {
      final message = utf8.decode(data);
      print(
          'Data from ${client.remoteAddress.address}:${client.remotePort} - $message');
      _addData(message, true);
    }, onDone: () {
      clients.remove(client);
      print(
          'Client disconnected: ${client.remoteAddress.address}:${client.remotePort}');
    });
  }

  Future<void> _connectToHost(String address) async {
    clientSocket = await Socket.connect(address, 8888);
    print(
        'Connected to: ${clientSocket?.remoteAddress.address}:${clientSocket?.port}');

    clientSocket?.listen((data) {
      final message = utf8.decode(data);
      _addData(message, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Direct Page'),
      ),
      body: Column(
        children: [
          // Displaying the number of active connections
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
                'Is Connected: $isConnected | Is Group Owner: $isGroupOwner'),
          ),
          // Displaying messages from "data"
          Expanded(
            child: ListView.builder(
              itemCount: appData.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(appData[index]),
                );
              },
            ),
          ),
          // Input and Send button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _controller, // Use the controller here
                    decoration: const InputDecoration(
                      hintText: 'Enter some text',
                      border: OutlineInputBorder(),
                    ),
                    // Removed inputFormatters to allow any type of input
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    _addData(_controller.text, false);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
