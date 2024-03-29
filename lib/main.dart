import 'package:flutter/material.dart';
import 'package:flutter_p2p_demo/pages/bluetooth.dart';
import 'package:flutter_p2p_demo/pages/wifidirect.dart';
import 'package:flutter_p2p_demo/pages/wifiaware.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter P2P Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Page'),
      ),
      body: Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // This centers the buttons vertically.
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const BluetoothPage()),
                );
              },
              child: const Text('Go to Bluetooth Page'),
            ),
            const SizedBox(height: 20), // Adds space between the two buttons.
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const WiFiDirectPage()),
                );
              },
              child: const Text('Go to WiFi Direct Page'),
            ),
            const SizedBox(height: 20), // Adds space between the two buttons.
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const WiFiAwarePage()),
                );
              },
              child: const Text('Go to WiFi Aware Page'),
            ),
          ],
        ),
      ),
    );
  }
}
