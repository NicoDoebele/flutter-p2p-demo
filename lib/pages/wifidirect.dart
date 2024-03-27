import 'dart:async';

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

  Timer? updateTimer;

  static const platform =
      MethodChannel('org.katapp.flutter_p2p_demo/advertising');

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
    } else if (state == AppLifecycleState.resumed) {}
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

  void _startDiscovery() async {
    try {
      await platform.invokeMethod('wifiDirectDiscoverPeers');
    } on PlatformException catch (e) {
      print("Failed to start WiFi Direct Discovery: '${e.message}'.");
    }
  }

  void _addData(String data) {
    setState(() {
      appData.add(data);
    });

    _controller.clear();
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
            child: Text('Active Connections: $activeConnections'),
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
                    _addData(_controller.text);
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
