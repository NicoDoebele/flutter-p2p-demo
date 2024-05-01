import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_p2p_demo/classes/Message.dart';
import 'package:permission_handler/permission_handler.dart';

// import location manager
import 'package:flutter_p2p_demo/classes/location_manager.dart';

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

  bool locationEnabled = false;

  List<BluetoothDevice> knownDevices = [];

  List<int> messageQueue = [];

  // save time when page was opened and first connection achieved
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
    initiateBluetooth();
    // _getDataFromAllConnectedDevices();

    _updateLocationStatus();

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

  void _onMessageListUpdate(dynamic messageListJson) async {

    List<Message> newMessages = [];

    List<dynamic> messageList = jsonDecode(messageListJson);
    for (var messageJson in messageList) {
      Message message = Message.fromJson(messageJson);

      // if message not in appData, add it
      if (!appData.contains(message)) {
        //message.receivedLocation ??= LocationManager.getCurrentLocation();
        dynamic fullDataMessageString = await platform.invokeMethod('addDataToReceivedMessage', {'message': jsonEncode(message.toJson())});

        Message fullMessage = Message.fromJson(jsonDecode(fullDataMessageString));
        //fullMessage.calculateDistanceBetweenLocations();
        newMessages.add(fullMessage);
      }
    }

    setState(() {      
      appData.addAll(newMessages);
    });
  }

  /*
  void _getDataFromAllConnectedDevices() async {
    for (BluetoothDevice device in FlutterBluePlus.connectedDevices) {
      if (device.isConnected) {
        getAllDataFromNewDevice(device);
      }
    }
  }
  */

  void initiateBluetooth() async {
    if (await FlutterBluePlus.isSupported == false) {
      print('Bluetooth is not supported on this device');
      return;
    }

    await Permission.bluetooth.request();
    await Permission.bluetoothAdvertise.request();
    await Permission.location.request();

    var subscription = FlutterBluePlus.onScanResults.listen((results) async {
      if (results.isNotEmpty) {
        ScanResult result = results.last;

        if (!result.device.isConnected) {
          result.device.connect();

          while (!result.device.isConnected) {
            await Future.delayed(const Duration(milliseconds: 50));
          }

          result.device.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.high);
          
          setState(() {
            firstConnectionTime ??= DateTime.now();
          });

          Timer.periodic(const Duration(seconds: 2), (timer) async {
            bool isReachable = await deviceIsReachable(result.device);
            if (!isReachable) {
              result.device.disconnect();
              timer.cancel();
            }
          });

          /*
          var subscription = result.device.connectionState.listen((BluetoothConnectionState state) async {
            if (state == BluetoothConnectionState.disconnected) {
              try {
                result.device.connect();
              } catch (e) {
                print('Could not reconnect to device ${result.device.remoteId}: $e');
              }
            }
          });

          result.device.cancelWhenDisconnected(subscription, delayed: true);
          */

          //getAllDataFromNewDevice(result.device);
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
    if (messageQueue.isEmpty) {
      int chunk = characteristic.device.mtuNow - 5; // 3 + 2 bytes ble overhead
      for (int i = 0; i < value.length; i += chunk) {
        List<int> subvalue = value.sublist(i, min(i + chunk, value.length));
        characteristic.write(subvalue, withoutResponse: true, timeout: timeout);
      }
      Future.delayed(const Duration(milliseconds: 100), () {
        _sendSplitWriteQueue(characteristic);
      });
    } else {
      _addToSplitWriteQueue(value);
    }
  }

  void _addToSplitWriteQueue(List<int> value) {
    messageQueue.addAll(value);
  }

  void _sendSplitWriteQueue(BluetoothCharacteristic characteristic) {
    if (messageQueue.isNotEmpty) {
      List<int> value = messageQueue;
    messageQueue = [];
    splitWrite(value, characteristic);
    }
  }

  Future<void> sendDataToAllDevices(String message) async {
    // append message delimiter
    String fullMessage = "$message%";

    List<int> messageBytes =
        utf8.encode(fullMessage); // Convert string to byte array

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

    // add location
    //Message message = Message.fromJson(jsonDecode(messageJsonString));
    //message.sentLocation = LocationManager.getCurrentLocation();
    //messageJsonString = jsonEncode(message.toJson());

    await platform.invokeMethod('addMessage', {'message': messageJsonString});

    sendDataToAllDevices(messageJsonString);
  }

  void addMessage(Message message) {
    setState(() {
      appData.add(message);
    });

    platform.invokeMethod('addMessage', {'message': message.toJson().toString()});
  }

  /*
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
  */

  Future<bool> deviceIsReachable(BluetoothDevice device) async {
    // ping device on ping uuid and get response with read request
    while (!device.isConnected) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.uuid == characteristicUUID) {
            print('Pinging device ${device.remoteId}');
            List<int> data = await characteristic.read();
            print('Received response from device ${device.remoteId}');
            return data.isNotEmpty;
          }
        }
      }

      return false;
    } catch (e) {
      print('Failed to ping device ${device.remoteId}: $e');
      return false;
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
        createMessage('1000');
      });
    } else {
      automatedMessageTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Page'),
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
          // Displaying the number of active connections
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Connections: $activeConnections'),
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
                  timeInfo = '$sizeInBytes Bytes received in ${duration.inSeconds} seconds from ${message.distanceBetweenLocations!.toStringAsFixed(2)} away';
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
