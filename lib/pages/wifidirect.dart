import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_p2p_demo/classes/Message.dart';
import 'package:permission_handler/permission_handler.dart';

class WiFiDirectPage extends StatefulWidget {
  const WiFiDirectPage({super.key});

  @override
  WiFiDirectPageState createState() => WiFiDirectPageState();
}

class WiFiDirectPageState extends State<WiFiDirectPage> {
  final TextEditingController _controller = TextEditingController();

  final List<Message> appData = [];
  int activeConnections = 0;
  bool isConnected = false;
  bool isGroupOwner = false;

  ServerSocket? serverSocket;
  final List<Socket> clients = [];
  Socket? clientSocket;

  String previousData = '';

  Timer? updateTimer;

  static const platform =
      MethodChannel('org.katapp.flutter_p2p_demo.wifidirect/controller');

  static const EventChannel _connectionEventChannel =
      EventChannel('org.katapp.flutter_p2p_demo.wifidirect/connection');

  @override
  void initState() {
    super.initState();
    _connectionEventChannel
        .receiveBroadcastStream()
        .listen(_onConnectionChange, onError: _onError);
    _start();
  }

  @override
  void dispose() {
    _stopWiFiDirect();
    _connectionEventChannel.receiveBroadcastStream().listen(null);

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

  void _stopWiFiDirect() {
    try {
      platform.invokeMethod('stop');
    } on PlatformException catch (e) {
      print("Failed to stop WiFi Direct: '${e.message}'.");
    }
  }

  void _start() async {
    await Permission.nearbyWifiDevices.request();
    await Permission.location.request();

    try {
      await platform.invokeMethod('start');
    } on PlatformException catch (e) {
      print("Failed to init WiFi Direct: '${e.message}'.");
    }
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

  void _createMessage(String size) async {

    int messageSize;

    if (size == '') {
      messageSize = 0;
    } else {
      messageSize = int.parse(size);
    }

    dynamic messageJsonString = await platform.invokeMethod('createMessage', {'size': messageSize});

    Message message = Message.fromJson(jsonDecode(messageJsonString));

    if (appData.contains(message)) {
      return;
    }

    setState(() {
      appData.add(message);
    });

    _controller.clear();

    if (isGroupOwner && isConnected) {
      for (final client in clients) {
        client.write(messageJsonString);
      }
    } else if (isConnected) {
      clientSocket?.write(messageJsonString);
    }
  }

  void _addMessage(Message message) {
    if (appData.contains(message)) {
      return;
    }

    message.timeReceived = DateTime.now();

    setState(() {
      appData.add(message);
    });

    if (isGroupOwner && isConnected) {
      for (final client in clients) {
        client.write(message.toJson());
      }
    } else if (isConnected) {
      clientSocket?.write(message.toJson());
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
      final messageJsonString = utf8.decode(data);
      print(
          'Data from ${client.remoteAddress.address}:${client.remotePort} - $messageJsonString');
      
      try {
        final message = Message.fromJson(jsonDecode(previousData + messageJsonString));
        _addMessage(message);
        previousData = '';
      } catch (e) {
        print('Error: $e');
        previousData += messageJsonString;
      }


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
      final messageJsonString = utf8.decode(data);
      print('Data from ${clientSocket?.remoteAddress.address}:${clientSocket?.port} - $messageJsonString');

      try {
        final message = Message.fromJson(jsonDecode(previousData + messageJsonString));
        _addMessage(message);
        previousData = '';
      } catch (e) {
        print('Error: $e');
        previousData += messageJsonString;
      }
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
                final message = appData[index];
                // Calculating the difference in time between timeSent and timeReceived, if both are available
                String timeInfo;

                String jsonString = message.toJson();
                List<int> jsonBytes = utf8.encode(jsonString);
                int sizeInBytes = jsonBytes.length;

                if (message.timeSent != null && message.timeReceived != null) {
                  final duration = message.timeReceived!.difference(message.timeSent!);
                  timeInfo = '$sizeInBytes Bytes received in ${duration.inSeconds} seconds';
                } else {
                  timeInfo = 'Sent from this device';
                }

                return ListTile(
                  title: Text('${message.sender} :: ${message.id}'),
                  subtitle: Text(timeInfo),
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
                      hintText: 'Amount of Bytes to send',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number, // Set the keyboard type to numeric
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly, // Allow digits only, no decimals or negatives
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    _createMessage(_controller.text);
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
