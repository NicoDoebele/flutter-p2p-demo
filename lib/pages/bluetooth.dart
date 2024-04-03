import 'dart:async';
import 'dart:convert';

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
  final List<BluetoothDevice> knownDevices = [];
  final TextEditingController _controller = TextEditingController();

  final List<String> appData = [];
  int activeConnections = 0;

  Timer? updateTimer;

  static const platform =
      MethodChannel('org.katapp.flutter_p2p_demo.bluetooth/controller');
  final Guid serviceUUID = Guid('c07b8cf2-b8ff-4ef4-b4e1-dd8aa2415f81');
  final Guid characteristicUUID = Guid('5e6525b1-4a90-4baf-a4a1-9b4a53641970');

  @override
  void initState() {
    super.initState();
    initiateBluetooth();

    // every 2 sec update the active connections
    updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      updateActiveConnections();
    });
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan(); // Updated variable
    stopGattServer();
    updateTimer?.cancel();
    _controller.dispose();
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

        if (!result.device.isConnected) {
          result.device.connect();
          getAllDataFromNewDevice(result.device);

          if (!knownDevices.contains(result.device)) {
            subscribeToDeviceServive(result.device);
          } else {
            knownDevices.add(result.device);
          }
        }
      }
    });

    await FlutterBluePlus.startScan(withServices: [serviceUUID]);

    startGattServer();
  }

  void startGattServer() async {
    try {
      await platform.invokeMethod('start');
    } on PlatformException catch (e) {
      print("Failed to start Bluetooth GattServer: '${e.message}'.");
    }
  }

  void stopGattServer() async {
    try {
      await platform.invokeMethod('stop');
    } on PlatformException catch (e) {
      print("Failed to stop Bluetooth GattServer: '${e.message}'.");
    }
  }

  void updateActiveConnections() async {
    setState(() {
      activeConnections = FlutterBluePlus.connectedDevices.length;
    });
  }

  Future<void> subscribeToDeviceServive(BluetoothDevice device) async {
    //wait until device is connected
    while (!device.isConnected) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid == characteristicUUID) {
          await characteristic.setNotifyValue(true);
          characteristic.onValueReceived.listen((data) {
            String readableData = utf8.decode(data);

            if (!appData.contains(readableData)) {
              addData(readableData);
            }
          });
        }
      }
    }
  }

  Future<void> sendDataToAllDevices(String message) async {
    List<int> messageBytes =
        utf8.encode(message); // Convert string to byte array

    for (BluetoothDevice device in FlutterBluePlus.connectedDevices) {
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.uuid == characteristicUUID) {
            try {
              await characteristic.write(messageBytes, withoutResponse: false);
              print("Message sent to device ${device.remoteId}");
            } catch (e) {
              print("Failed to send message to device ${device.remoteId}: $e");
            }
          }
        }
      }
    }
  }

  Future<void> addData(String message) async {
    // if data in appData return
    if (appData.contains(message)) {
      return;
    }

    _controller.clear();

    setState(() {
      appData.add(message);
    });
    // use platform to update locale data
    await platform.invokeMethod('updateBluetoothDataList', {'data': message});
  }

  Future<void> getAllDataFromNewDevice(BluetoothDevice device) async {
    while (!device.isConnected) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid == characteristicUUID) {
          List<int> data = await characteristic.read();
          String readableData = utf8.decode(data);
          List<String> singleWords = readableData.split(', ');
          for (String word in singleWords) {
            addData(word);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Page'),
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
                    // Use the text from the controller in addData
                    addData(_controller.text);
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
