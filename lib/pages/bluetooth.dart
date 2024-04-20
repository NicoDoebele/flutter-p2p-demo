import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_p2p_demo/classes/Message.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  BluetoothPageState createState() => BluetoothPageState();
}

class BluetoothPageState extends State<BluetoothPage> {
  final TextEditingController _controller = TextEditingController();

  final List<Message> appData = [];
  int activeConnections = 0;

  Timer? updateTimer;

  static const platform =
      MethodChannel('org.katapp.flutter_p2p_demo.bluetooth/controller');
  static const messageStream =
      EventChannel('org.katapp.flutter_p2p_demo.bluetooth/connection');

  final Guid serviceUUID = Guid('c07b8cf2-b8ff-4ef4-b4e1-dd8aa2415f81');
  final Guid characteristicUUID = Guid('5e6525b1-4a90-4baf-a4a1-9b4a53641970');

  @override
  void initState() {
    super.initState();
    initiateBluetooth();
    _getDataFromAllConnectedDevices();

    messageStream.receiveBroadcastStream().listen(_onMessageListUpdate);

    // every 2 sec update the active connections
    updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      updateActiveConnections();
    });
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan(); // Updated variable
    for (BluetoothDevice device in FlutterBluePlus.connectedDevices) {
      device.disconnect();
    }
    stopGattServer();
    updateTimer?.cancel();
    _controller.dispose();

    messageStream.receiveBroadcastStream().listen(null).cancel();

    super.dispose();
  }

  void _onMessageListUpdate(dynamic messageListJson) {
    setState(() {
      appData.clear();
      
      List<dynamic> messageList = jsonDecode(messageListJson);
      for (var message in messageList) {
        appData.add(Message.fromJson(message));
      }
    });
  }

  void _getDataFromAllConnectedDevices() async {
    for (BluetoothDevice device in FlutterBluePlus.connectedDevices) {
      if (device.isConnected) {
        getAllDataFromNewDevice(device);
      }
    }
  }

  void initiateBluetooth() async {
    if (await FlutterBluePlus.isSupported == false) {
      print('Bluetooth is not supported on this device');
      return;
    }

    await Permission.bluetooth.request();
    await Permission.bluetoothAdvertise.request();
    await Permission.location.request();

    var subscription = FlutterBluePlus.onScanResults.listen((results) {
      if (results.isNotEmpty) {
        ScanResult result = results.last;

        if (!result.device.isConnected) {
          result.device.connect();

          getAllDataFromNewDevice(result.device);
          //subscribeToDeviceServive(result.device);
          //knownDevices.add(result.device);
        }
      }
    });

    FlutterBluePlus.cancelWhenScanComplete(subscription);

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

  /*
  Write to each device instead
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
  */

  Future<void> splitWrite(List<int> value, BluetoothCharacteristic characteristic, {int timeout = 15}) async {
    int chunk = characteristic.device.mtuNow - 5; // 3 + 2 bytes ble overhead
    for (int i = 0; i < value.length; i += chunk) {
      List<int> subvalue = value.sublist(i, min(i + chunk, value.length));
      await characteristic.write(subvalue, withoutResponse:false, timeout: timeout);
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
              //await characteristic.write(messageBytes, allowLongWrite: true);
              await splitWrite(messageBytes, characteristic);
              print("Message sent to device ${device.remoteId}");
            } catch (e) {
              print("Failed to send message to device ${device.remoteId}: $e");
            }
          }
        }
      }
    }
  }

  Future<void> createMessage(String sizeString) async {
    _controller.clear();
    int size;

    if (sizeString == '') {
      size = 0;
    } else {
      size = int.parse(sizeString);
    }

    var messageJsonString = await platform.invokeMethod('createMessage', {'size': size});
    sendDataToAllDevices(messageJsonString);
  }

  void addMessage(Message message) {
    setState(() {
      appData.add(message);
    });

    platform.invokeMethod('addMessage', {'message': message.toJson().toString()});
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

          try {
            String jsonString = utf8.decode(data);
            var jsonData = jsonDecode(jsonString);

            if (jsonData is List) {
              List<Message> messages = jsonData.map((item) => Message.fromJson(item)).toList();
              for (Message m in messages) {
                addMessage(m);
              }
            } else if (jsonData is Map) {
              addMessage(Message.fromJson(jsonData as Map<String, dynamic>));
            }
          } catch (e) {
            print('Failed to process data: $e');
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
                final message = appData[index];
                // Calculating the difference in time between timeSent and timeReceived, if both are available
                String timeInfo;

                String jsonString = message.toJson().toString();
                List<int> jsonBytes = utf8.encode(jsonString);
                int sizeInBytes = jsonBytes.length;

                if (message.timeSent != null && message.timeReceived != null && message.distanceBetweenLocations != null) {
                  final duration = message.timeReceived!.difference(message.timeSent!);
                  timeInfo = '$sizeInBytes Bytes received in ${duration.inSeconds} seconds from ${message.distanceBetweenLocations!.toStringAsFixed(2)} +-5 meters away';
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
                    createMessage(_controller.text);
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
