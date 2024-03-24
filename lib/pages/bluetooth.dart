import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  BluetoothPageState createState() => BluetoothPageState();
}

class BluetoothPageState extends State<BluetoothPage> {
  final List<BluetoothDevice> devicesList = [];

  static const platform = MethodChannel('org.katapp.flutter_p2p_demo/advertising');
  final Guid serviceUUID = Guid('c07b8cf2-b8ff-4ef4-b4e1-dd8aa2415f81');

  @override
  void initState() {
    super.initState();
    initiateBluetooth();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan(); // Updated variable
    stopAdvertising();
    super.dispose();
  }

  void initiateBluetooth() async {
    if (await FlutterBluePlus.isSupported == false) {
      print('Bluetooth is not supported on this device');
      return;
    }

    await Permission.bluetooth.request();
    await Permission.bluetoothAdvertise.request();
    await Permission.location.request();

    FlutterBluePlus.onScanResults.listen((results) {
      if (results.isNotEmpty) {
        ScanResult result = results.last;

        print('Device found: ${result.device.advName}');

        if (!devicesList.contains(result.device)) {
          setState(() {
            devicesList.add(result.device);
          });
        }
      }
    });

    await FlutterBluePlus.startScan(withServices: [serviceUUID]);

    startAdvertising();
  }

  void startAdvertising() async {
    try {
      await platform.invokeMethod('startBluetoothAdvertising');
    } on PlatformException catch (e) {
      print("Failed to start Bluetooth advertising: '${e.message}'.");
    }
  }

  void stopAdvertising() async {
    try {
      await platform.invokeMethod('stopBluetoothAdvertising');
    } on PlatformException catch (e) {
      print("Failed to stop Bluetooth advertising: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Page'),
      ),
      body: ListView.builder(
        itemCount: devicesList.length,
        itemBuilder: (BuildContext context, int index) {
          return ListTile(
            title: Text(devicesList[index].platformName),
            subtitle: Text(devicesList[index].remoteId.toString()),
            onTap: () => {},
          );
        },
      ),
    );
  }
}
