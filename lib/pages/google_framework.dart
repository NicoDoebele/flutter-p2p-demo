import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_p2p_demo/classes/message.dart';

// import location manager
import 'package:flutter_p2p_demo/classes/location_manager.dart';
// import nearby connections plugin
import 'package:nearby_connections/nearby_connections.dart';

class GoogleFrameworkPage extends StatefulWidget {
  const GoogleFrameworkPage({super.key});

  @override
  GoogleFrameworkPageState createState() => GoogleFrameworkPageState();
}

class GoogleFrameworkPageState extends State<GoogleFrameworkPage> {
  final TextEditingController _controller = TextEditingController();

  final List<Message> appData = [];

  static const platform =
      MethodChannel('org.katapp.flutter_p2p_demo.googleframework/controller');

  bool locationEnabled = false;
  int connectionAmount = 0;

  DateTime? pageOpenTime;
  DateTime? firstConnectionTime;

  bool automatedMessages = false;
  Timer? automatedMessageTimer;

  List<String> connectedIds = [];
  Map<String, String> deviceIdToDeviceName = {};
  String previousMessage = '';

  String? uniqueDeviceName;

  int resets = 0;

  Future<String?> _getUniqueDeviceName() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) { // import 'dart:io'
      var iosDeviceInfo = await deviceInfo.iosInfo;
      return "I${iosDeviceInfo.identifierForVendor}"; // unique ID on iOS
    } else if(Platform.isAndroid) {
      var androidDeviceInfo = await deviceInfo.androidInfo;
      return "A${androidDeviceInfo.androidId}"; // unique ID on Android
    } else {
      // return random ID for other platforms
      return "O${Random().nextInt(100000).toString()}";
    }
  }

  @override
  void initState() {
    setState(() {
      pageOpenTime = DateTime.now();
    });

    super.initState();

    _init();

    _updateLocationStatus();
  }

  @override
  void dispose() async {
    _controller.dispose();
    automatedMessageTimer?.cancel();
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
    uniqueDeviceName = null;

    connectedIds.clear();
    deviceIdToDeviceName.clear();
    super.dispose();
  }

  void _init() async {
    await Permission.nearbyWifiDevices.request();
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothAdvertise.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();

    uniqueDeviceName = await _getUniqueDeviceName();

    _startAdvertising();
    _startDiscovering();
  }

  void _reset() {
    connectedIds.clear();
    deviceIdToDeviceName.clear();
    setState(() {
      connectionAmount = connectedIds.length;
      firstConnectionTime = null;
    });

    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();

    _startAdvertising();
    _startDiscovering();
  }

  void _handlePlayloadReceived(String id, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      String payloadString = String.fromCharCodes(payload.bytes!);
      String fullString = previousMessage + payloadString;

      print('Payload received: $fullString');
      if (!fullString.endsWith('%')) {
        previousMessage = fullString;
        return;
      }

      previousMessage = '';
      fullString = fullString.substring(0, fullString.length - 1);
      List<String> messageStrings = fullString.split('%');
      for (String messageString in messageStrings) {
        if (messageString == '') {
          continue;
        }

        Message message = Message.fromJson(jsonDecode(messageString));
        _addMessage(message);
      }
    } else if (payload.type == PayloadType.FILE) {
      // handle file
    }
  }

  Future<bool> _startAdvertising() async {
    try {
      bool success = await Nearby().startAdvertising(
          "${uniqueDeviceName}_advertiser",
          Strategy.P2P_CLUSTER, // https://developers.google.com/nearby/connections/strategies
          onConnectionInitiated: (String id,ConnectionInfo info) {
            // Called whenever a discoverer requests connection
            _onConnectionInitiated(id, info);
          },
          onConnectionResult: (String id,Status status) {
            // Called when connection is accepted/rejected
            _onConnectionResult(id, status);
          },
          onDisconnected: (String id) {
            // Callled whenever a discoverer disconnects from advertiser
            _onDisconnected(id);
          },
          serviceId: "org.katapp.flutter_p2p_demo.googlenearbyconnections", // uniquely identifies your app
      );
      return success;
    } catch (exception) {
        // platform exceptions like unable to start bluetooth or insufficient permissions
        print(exception.toString());
        return false;
    }
  }

  void _onConnectionResult(String id, Status status) {
    print('Connection result for id $id: $status');
            
    // If connection is accepted, set connected to true
    if (status == Status.CONNECTED) {
      print('Connection accepted: $id');
      connectedIds.add(id);
      setState(() {
        connectionAmount = connectedIds.length;
        firstConnectionTime ??= DateTime.now();
      });
    } else if (status == Status.REJECTED) {
      print('Connection rejected: $id');
    } else if (status == Status.ERROR) {
      print('Connection error: $id');
      //_reset();
      setState(() {
        // This sadly does not always trigger properly, since the plugin does not handle all errors corretly
        setState(() {
          resets++;
        });
      });
      _reset();
    }

    print('Connected ids: $connectedIds');
  }

  void _onDisconnected(String id) {
    print('Disconnected: $id');

    // if in connected ids remove
    if (connectedIds.contains(id)) {
      connectedIds.remove(id);
    }

    print('Connected ids: $connectedIds');

    setState(() {
      connectionAmount = connectedIds.length;
    });
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    print('Connection initiated: $id ');

    deviceIdToDeviceName[id] = info.endpointName;

    _acceptConnection(id);

    print('Connected ids: $connectedIds');
  }

  // sometimes the device connects to itself, so we need to remove those connections
  // FIXED
  /*
  void _removeBadConnections() {
    // get all names of connected devices
    List<String> connectedDeviceNames = connectedIds.map((id) => deviceIdToDeviceName[id]!).toList();

    // get all isntances, where device names start with the same prefix before _ twice
    List<String> badDeviceNames = connectedDeviceNames.where((name) => connectedDeviceNames.where((n) => n.startsWith(name.split('_')[0])).length > 1).toList();

    // get all ids of bad devices
    List<String> badDeviceIds = deviceIdToDeviceName.keys.where((id) => badDeviceNames.contains(deviceIdToDeviceName[id])).toList();

    // remove all bad devices from connected ids
    connectedIds.removeWhere((id) => badDeviceIds.contains(id));

    // if bad devices were removed and and there are no more connections reset initial connect time
    if (badDeviceIds.isNotEmpty && connectedIds.isEmpty) {
      setState(() {
        firstConnectionTime = null;
      });
    }

    if (connectedIds.isNotEmpty) {
      setState(() {
        firstConnectionTime ??= DateTime.now();
      });
    }

    setState(() {
      connectionAmount = connectedIds.length;
    });

    // remove all bad devices
    badDeviceIds.forEach((id) {
      Nearby().disconnectFromEndpoint(id);
    });
  }
  */

  Future<bool> _startDiscovering() async {
    try {
      bool success = await Nearby().startDiscovery(
          "${uniqueDeviceName}_discoverer",
          Strategy.P2P_CLUSTER, // https://developers.google.com/nearby/connections/strategies
          onEndpointFound: (String id,String userName, String serviceId) {
            // called when an advertiser is found

            print('Service ID: $serviceId');
            if (serviceId != "org.katapp.flutter_p2p_demo.googlenearbyconnections") {
              return;
            }
            print('Endpoint found with fitting serviceID: $id');
            _requestConnections(userName, id);
          },
          onEndpointLost: (String? id) {
            //called when an advertiser is lost (only if we weren't connected to it )
          },
          serviceId: "org.katapp.flutter_p2p_demo.googlenearbyconnections", // uniquely identifies your app
      );
      return success;
    } catch (e) {
        // platform exceptions like unable to start bluetooth or insufficient permissions
        print(e.toString());
        return false;
    }
  }

  void _requestConnections(String userNickName, String endpointId) async {
    // to be called by discover whenever an endpoint is found
    // callbacks are similar to those in startAdvertising method

    if (connectedIds.contains(endpointId)) {
      return;
    }

    print("Device name: $uniqueDeviceName");

    // if device name in userNickName, don't connect
    if (userNickName.contains(uniqueDeviceName!)) {
      print('Not connecting to self');
      return;
    }

    print('Requesting connection to $userNickName with endpoint $endpointId');

    try{
      Nearby().requestConnection(
          userNickName,
          endpointId,
          onConnectionInitiated: (id, info) {
            _onConnectionInitiated(id, info);
          },
          onConnectionResult: (id, status) {
            _onConnectionResult(id, status);
          },
          onDisconnected: (id) {
            _onDisconnected(id);
          },
      );
    }catch(exception){
        // called if request was invalid
        print(exception.toString());
    }
  }

  void _acceptConnection(String endpointId) async {
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (endpointId, payload) {
          // called whenever a payload is recieved.
          _handlePlayloadReceived(endpointId, payload);
      },
      onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {
          // gives status of a payload
          // e.g success/failure/in_progress
          // bytes transferred and total bytes etc

          PayloadStatus status = payloadTransferUpdate.status;
          String statusName = status.name;
          // get bytes to be transferred
          int bytesTransferred = payloadTransferUpdate.bytesTransferred;

          print('Payload transfer update: $statusName with bytes transfered $bytesTransferred');
      }
    );
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

    // _sendMessage(message);
  }

  void _sendMessage(Message message) {
    // for every device connected, send the message
    connectedIds.forEach((id) async {
      try {
        String messageString = jsonEncode(message.toJson());
        messageString += "%";
        List<int> bytes = utf8.encode(messageString);
        // only 1mb can be sent in one chunk including headers
        int chunkSize = 1000000; // 1 million bytes
        int totalChunks = (bytes.length / chunkSize).ceil();

        for (int i = 0; i < totalChunks; i++) {
          int start = i * chunkSize;
          int end = (i + 1) * chunkSize;
          if (end > bytes.length) {
          end = bytes.length;
          }
          List<int> chunk = bytes.sublist(start, end);
          await Nearby().sendBytesPayload(id, Uint8List.fromList(chunk));
        }
      } catch (exception) {
        print(exception.toString());
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Framework'),
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
                Text('Connected devices: $connectionAmount'),
                Text(firstConnectionTime != null ? "Connection Time: ${firstConnectionTime?.difference(pageOpenTime!).inSeconds} seconds" : "No connections yet"),
                Text(resets != 0 ? "Resets due to connection errors: $resets" : ""),
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
