import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_p2p_demo/classes/message.dart';

class WiFiAwarePage extends StatefulWidget {
  const WiFiAwarePage({super.key});

  @override
  WiFiAwarePageState createState() => WiFiAwarePageState();
}

class WiFiAwarePageState extends State<WiFiAwarePage> {
  final TextEditingController _controller = TextEditingController();

  final List<Message> appData = [];

  ServerSocket? serverSocket;
  final List<Socket> subscribers = [];

  final List<Socket> clientSockets = [];

  final List<Map<String, dynamic>> connectionInfos = [];

  String previousData = '';

  static const platform =
      MethodChannel('org.katapp.flutter_p2p_demo.wifiaware/controller');
    
  static const EventChannel _connectionEventChannel =
      EventChannel('org.katapp.flutter_p2p_demo.wifiaware/connection');

  @override
  void initState() {
    super.initState();
    _connectionEventChannel
      .receiveBroadcastStream()
      .listen(_onConnectionChange);
    //_startServerSocket();
    _init();
  }

  @override
  void dispose() async {
    _controller.dispose();
    _stopWiFiAware();
    _connectionEventChannel.receiveBroadcastStream().listen(null);
    await serverSocket?.close();
    for (final subscriber in subscribers) {
      await subscriber.close();
    }
    for (final clientSocket in clientSockets) {
      await clientSocket.close();
    }
    serverSocket = null;
    subscribers.clear();
    clientSockets.clear();
    super.dispose();
  }

  void _onConnectionChange(dynamic event) {
    print('Connection event: $event');

    // get port and address by map
    final Map<String, dynamic> connectionInfo = Map<String, dynamic>.from(event);

    connectionInfos.add(connectionInfo);

    if (connectionInfo.length == 1) {
      final String address = connectionInfos[0]['ipv6'];
      final int port = connectionInfos[0]['port'];

      _connectToHost(address, port);
    }
  }

  void _stopWiFiAware() {
    try {
      platform.invokeMethod('stop');
    } on PlatformException catch (e) {
      print("Failed to stop WiFi Aware: '${e.message}'.");
    }
  }

  void _init() async {
    await Permission.nearbyWifiDevices.request();
    await Permission.location.request();

    try {
      await platform.invokeMethod('start');
    } on PlatformException catch (e) {
      print("Failed to init WiFi Aware: '${e.message}'.");
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

    for (final subscriber in subscribers) {
      subscriber.write(messageJsonString);
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

    for (final subscriber in subscribers) {
      subscriber.write(message.toJson());
    }
  }

  void _startServerSocket() async {
    serverSocket = await ServerSocket.bind(InternetAddress('::1'), 8888);
    print('Hosting on: ${serverSocket?.address.address}:${serverSocket?.port}');
    serverSocket?.listen((client) {
      _handleClientConnection(client);
    });
  }

  void _handleClientConnection(Socket client) async {
    print(
        'Client connected: ${client.remoteAddress.address}:${client.remotePort}');
    subscribers.add(client);
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
      subscribers.remove(client);
      print(
          'Client disconnected: ${client.remoteAddress.address}:${client.remotePort}');
    });
  }

  Future<void> _connectToHost(String address, int port) async {
    InternetAddress serverAddress = InternetAddress(address);
    Socket clientSocket = await Socket.connect(serverAddress, port);
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

    clientSockets.add(clientSocket);
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
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('TEXT_PLACEHOLDER'),
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
