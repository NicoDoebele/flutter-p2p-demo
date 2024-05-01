import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_p2p_demo/classes/Message.dart';
import 'package:permission_handler/permission_handler.dart';

// import location manager
import 'package:flutter_p2p_demo/classes/location_manager.dart';

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

  DateTime? pageOpenTime;
  DateTime? firstConnectionTime;

  bool automatedMessages = false;
  Timer? automatedMessageTimer;

  static const platform =
      MethodChannel('org.katapp.flutter_p2p_demo.wifidirect/controller');

  static const EventChannel _connectionEventChannel =
      EventChannel('org.katapp.flutter_p2p_demo.wifidirect/connection');

  bool locationEnabled = false;

  @override
  void initState() {
    setState(() {
      pageOpenTime = DateTime.now();
    });

    super.initState();
    _updateLocationStatus();
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
    if (data == null) {
      setState(() {
        isConnected = false;
        isGroupOwner = false;
      });
      // close all sockets
      serverSocket?.close();
      clientSocket?.close();
      for (final client in clients) {
        client.close();
      }
      serverSocket = null;
      clientSocket = null;
      clients.clear();
      return;
    }

    final Map<String, dynamic> connectionInfo = Map<String, dynamic>.from(data);

    print("Connection details received: $connectionInfo");
    // Now you can use the data as needed
    final String groupOwnerAddress = connectionInfo['groupOwnerAddress'];
    final bool groupOwner = connectionInfo['isGroupOwner'];

    setState(() {
      isConnected = true;
      isGroupOwner = groupOwner;
      firstConnectionTime ??= DateTime.now();
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
    //message.sentLocation = LocationManager.getCurrentLocation();

    String newMessageJsonString = jsonEncode(message.toJson());

    if (appData.contains(message)) {
      return;
    }

    setState(() {
      appData.add(message);
    });

    _controller.clear();

    if (isGroupOwner && isConnected) {
      for (final client in clients) {
        client.write(newMessageJsonString);
      }
    } else if (isConnected) {
      clientSocket?.write(newMessageJsonString);
    }
  }

  void _addMessage(Message message) async {
    if (appData.contains(message)) {
      return;
    }

    String fixedMessageString = await platform.invokeMethod('addDataToReceivedMessage', {'message': jsonEncode(message.toJson())});

    Message messageWithData = Message.fromJson(jsonDecode(fixedMessageString));
    //messageWithData.receivedLocation = LocationManager.getCurrentLocation();
    //messageWithData.calculateDistanceBetweenLocations();

    setState(() {
      appData.add(messageWithData);
    });

    if (isGroupOwner && isConnected) {
      for (final client in clients) {
        client.write(jsonEncode(messageWithData.toJson()));
      }
    } else if (isConnected) {
      clientSocket?.write(jsonEncode(messageWithData.toJson()));
    }
  }

  void _startServerSocket() async {
    serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 8888);
    print('Hosting on: ${serverSocket?.address.address}:${serverSocket?.port}');
    try {
      serverSocket?.listen((client) {
        _handleClientConnection(client);
      });
    } catch (e) {
      print('Error: $e');
    }
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
    try {
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
    } catch (e) {
      print('Error: $e');
    }
  }

  void _toggleLocation() async {
    //LocationManager.updateLocationStatus(!LocationManager.isLocationEnabled());
    //_updateLocationStatus();

    dynamic status = await platform.invokeMethod('toggleLocationEnabled');
    setState(() {
      locationEnabled = status;
    });
  }

  void _updateLocationStatus() async {
    //final status = LocationManager.isLocationEnabled();
    dynamic status = await platform.invokeMethod('isLocationEnabled');
    setState(() {
      locationEnabled = status;
    });
  }

  void _toggleAutomaticMessages() {
    setState(() {
      automatedMessages = !automatedMessages;
    });

    if (automatedMessages) {
      automatedMessageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _createMessage('1000');
      });
    } else {
      automatedMessageTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Direct Page'),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.timer,
              color: automatedMessages ? Colors.green : Colors.red,  // Change color based on condition
            ),
            onPressed: _toggleAutomaticMessages,
          ),
          IconButton(
            icon: Icon(
              Icons.location_on,
              color: locationEnabled ? Colors.green : Colors.red,  // Change color based on condition
            ),
            onPressed: _toggleLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Is Connected: $isConnected | Is Group Owner: $isGroupOwner'),
                Text(firstConnectionTime != null ? "Connection Time: ${firstConnectionTime?.difference(pageOpenTime!).inSeconds} seconds" : "No connections yet"),
              ],
            ),
          ),
          // Displaying messages from "data"
          Expanded(
            child: ListView.builder(
              itemCount: appData.length,
              itemBuilder: (context, index) {
                final message = appData[index];
                // Calculating the difference in time between timeSent and timeReceived, if both are available
                String timeInfo;

                String jsonString = message.toJson().toString();
                List<int> jsonBytes = utf8.encode(jsonString);
                int sizeInBytes = jsonBytes.length;

                if (message.timeSent != null && message.timeReceived != null && message.distanceBetweenLocations != 0) {
                  final duration = message.timeReceived!.difference(message.timeSent!);
                  timeInfo = '$sizeInBytes Bytes received in ${duration.inSeconds} seconds from ${message.distanceBetweenLocations!.toStringAsFixed(2)} meters away';
                }else if (message.timeSent != null && message.timeReceived != null) {
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
