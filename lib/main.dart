import 'package:flutter/material.dart';
import 'package:flutter_p2p_demo/pages/bluetooth.dart';
import 'package:flutter_p2p_demo/pages/google_framework.dart';
import 'package:flutter_p2p_demo/pages/wifidirect.dart';
import 'package:flutter_p2p_demo/pages/wifiaware.dart';
import 'package:flutter_p2p_demo/pages/bluetooth_classic.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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
        title: const Text('Choose the technology to use'),
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
              child: const Text('Bluetooth Low Energy'),
            ),
            const SizedBox(height: 20), // Adds space between the two buttons.
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const BluetoothClassicPage()),
                );
              },
              child: const Text('Bluetooth Classic'),
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
              child: const Text('Wi-Fi Direct'),
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
              child: const Text('Wi-Fi Aware'),
            ),
            const SizedBox(height: 20), // Adds space between the two buttons.
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const GoogleFrameworkPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[50], // Set the button color to red
              ),
              child: const Text('Google Nearby Connections Framework'),
            ),
          ],
        ),
      ),
    );
  }
}
