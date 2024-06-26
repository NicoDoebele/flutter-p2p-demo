import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_p2p_demo/classes/message.dart';

// import location manager
import 'package:flutter_p2p_demo/classes/location_manager.dart';

class BluetoothClassicPage extends StatefulWidget {
  const BluetoothClassicPage({super.key});

  @override
  BluetoothClassicState createState() => BluetoothClassicState();
}

class BluetoothClassicState extends State<BluetoothClassicPage> {
  final TextEditingController _controller = TextEditingController();

  final List<Message> appData = [];

  static const platform =
      MethodChannel('org.katapp.flutter_p2p_demo.bluetooth_classic/controller');
    
  static const EventChannel _connectionEventChannel =
      EventChannel('org.katapp.flutter_p2p_demo.bluetooth_classic/connection');
  
  static const EventChannel _messageEventChannel = 
      EventChannel('org.katapp.flutter_p2p_demo.bluetooth_classic/message');

  bool locationEnabled = false;
  bool connected = false;

  DateTime? pageOpenTime;
  DateTime? firstConnectionTime;

  bool automatedMessages = false;
  Timer? automatedMessageTimer;

  bool showStatistics = false;

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
    _stopBluetoothClassic();
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

  void _stopBluetoothClassic() {
    try {
      platform.invokeMethod('stop');
    } on PlatformException catch (e) {
      print("Failed to stop Bluetooth Classic: '${e.message}'.");
    }
  }

  void _init() async {
    await Permission.nearbyWifiDevices.request();
    await Permission.location.request();

    try {
      await platform.invokeMethod('start');
    } on PlatformException catch (e) {
      print("Failed to init Bluetooth Classic: '${e.message}'.");
    }
  }

  void _sendMessage(Message messasge) {
    print('Sending message to subscribers: $messasge');
    platform.invokeMethod('sendMessage', {'message': jsonEncode(messasge.toJson())});
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

    //_controller.clear();

    _sendMessage(message);
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
      automatedMessageTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        _createMessage(_controller.text);
      });
    } else {
      automatedMessageTimer?.cancel();
    }
  }

  void _toggleStatistics() {
    setState(() {
      showStatistics = !showStatistics;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Classic'),
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
          IconButton(
            icon: Icon(
              Icons.show_chart,
              color: showStatistics ? Colors.green : Colors.red,  // Change color based on condition
            ),
            onPressed: _toggleStatistics,
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
                Text('Recieved: ${appData.where((message) => message.timeReceived != null).length} | Sent: ${appData.where((message) => message.timeReceived == null).length}'),
              ],
            ),
          ),
          // Displaying messages from "data"
          Expanded(
            child: showStatistics ? _buildStatistics() : _buildMessages(),
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

  ListView _buildStatistics() {
    final List<Message> receivedMessages = appData.where((message) => message.timeReceived != null).toList();

    // count by timeReceived - timeSent in seconds, display how many messages for each second
    final Map<int, int> messagesPerSecond = {};
    for (final message in receivedMessages) {
      final seconds = message.timeReceived!.difference(message.timeSent!).inSeconds;
      messagesPerSecond[seconds] = (messagesPerSecond[seconds] ?? 0) + 1;
    }

    return ListView.builder(
      itemCount: messagesPerSecond.length,
      itemBuilder: (context, index) {
        final seconds = messagesPerSecond.keys.elementAt(index);
        final count = messagesPerSecond.values.elementAt(index);
        return ListTile(
          title: Text('$count messages received in $seconds seconds'),
        );
      },
    );
  }

  ListView _buildMessages() {
    return ListView.builder(
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
    );
  }
}
