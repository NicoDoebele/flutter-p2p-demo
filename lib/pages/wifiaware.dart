import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class WiFiAwarePage extends StatefulWidget {
  const WiFiAwarePage({super.key});

  @override
  WiFiAwarePageState createState() => WiFiAwarePageState();
}

class WiFiAwarePageState extends State<WiFiAwarePage> {
  final TextEditingController _controller = TextEditingController();

  final List<String> appData = [];

  static const platform =
      MethodChannel('org.katapp.flutter_p2p_demo.wifiaware/controller');

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() async {
    _controller.dispose();
    _stopWiFiAware();
    super.dispose();
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

  void _addData(String data, bool isReceived) {
    setState(() {
      appData.add(data);
    });

    if (!isReceived) {
      _controller.clear();
    }
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
