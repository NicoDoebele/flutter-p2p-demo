import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_p2p_demo/classes/message.dart';

// import location manager
import 'package:flutter_p2p_demo/classes/location_manager.dart';

class WiFiAwarePage extends StatefulWidget {
  const WiFiAwarePage({super.key});

  @override
  WiFiAwarePageState createState() => WiFiAwarePageState();
}

class WiFiAwarePageState extends State<WiFiAwarePage> {
  final TextEditingController _controller = TextEditingController();

  final List<Message> appData = [];

  static const platform =
      MethodChannel('org.katapp.flutter_p2p_demo.wifiaware/controller');
    
  static const EventChannel _connectionEventChannel =
      EventChannel('org.katapp.flutter_p2p_demo.wifiaware/connection');
  
  static const EventChannel _messageEventChannel = 
      EventChannel('org.katapp.flutter_p2p_demo.wifiaware/messageStream');

  bool locationEnabled = false;
  bool connected = false;

  DateTime? pageOpenTime;
  DateTime? firstConnectionTime;

  bool automatedMessages = false;
  Timer? automatedMessageTimer;

  @override
  void initState() {
    setState(() {
      pageOpenTime = DateTime.now();
    });

    super.initState();
    _messageEventChannel
      .receiveBroadcastStream()
      .listen(_onMessageReceived);
    _connectionEventChannel
      .receiveBroadcastStream()
      .listen(_onConnectionChanged);
    //_startServerSocket();
    _init();

    _updateLocationStatus();
  }

  @override
  void dispose() async {
    _controller.dispose();
    _stopWiFiAware();
    _messageEventChannel.receiveBroadcastStream().listen(null);
    _connectionEventChannel.receiveBroadcastStream().listen(null);
    automatedMessageTimer?.cancel();
    super.dispose();
  }

  void _onConnectionChanged(dynamic event) {
    print('Connection changed: $event');

    setState(() {
      connected = event;

      if (connected && firstConnectionTime == null) {
        firstConnectionTime = DateTime.now();
      }
    });
  }

  void _onMessageReceived(dynamic event) {
    print('Received message: $event');
    final message = Message.fromJson(jsonDecode(event));
    _addMessage(message);
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

  void _sendMessageToSubscribers(Message messasge) {
    print('Sending message to subscribers: $messasge');
    platform.invokeMethod('sendMessageToSubscribers', {'message': jsonEncode(messasge.toJson())});
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

    if (appData.contains(message)) {
      return;
    }

    setState(() {
      appData.insert(0, message);
    });

    _controller.clear();

    _sendMessageToSubscribers(message);
  }

  void _addMessage(Message message) async {
    if (appData.contains(message)) {
      return;
    }

    String fixedMessageString = await platform.invokeMethod('addDataToReceivedMessage', {'message': jsonEncode(message.toJson())});

    //message.receivedLocation = LocationManager.getCurrentLocation();
    //message.calculateDistanceBetweenLocations();

    Message fullDataMessage = Message.fromJson(jsonDecode(fixedMessageString));

    setState(() {
      appData.insert(0, fullDataMessage);
    });

    // _sendMessageToSubscribers(message);
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
        _createMessage(_controller.text);
      });
    } else {
      automatedMessageTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Aware Page'),
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
                Text(connected ? 'Connected' : 'Not connected'),
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
