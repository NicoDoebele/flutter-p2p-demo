package org.katapp.flutter_p2p_demo;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.EventChannel;
import android.os.Bundle;
import android.util.Log;
import android.net.wifi.p2p.WifiP2pInfo;
import java.util.HashMap;
import java.util.Map;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;

import org.katapp.flutter_p2p_demo.message.Message;
import org.katapp.flutter_p2p_demo.bluetooth.BleGattServerManager;
import org.katapp.flutter_p2p_demo.wifidirect.WiFiDirectManager;
import org.katapp.flutter_p2p_demo.wifiaware.WiFiAwareManager;
import org.katapp.flutter_p2p_demo.message.LocationManager;

public class MainActivity extends FlutterActivity {
    private static final String EVENT_CHANNEL = "org.katapp.flutter_p2p_demo/connection";
    private BleGattServerManager bleGattServerManager;
    private WiFiDirectManager wifiDirectManager;
    private WiFiAwareManager wifiAwareManager;
    private FusedLocationProviderClient fusedLocationClient;
    private Bundle savedInstanceState;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        this.savedInstanceState = savedInstanceState;
        bleGattServerManager = new BleGattServerManager(this);
        wifiDirectManager = new WiFiDirectManager(this);
        wifiAwareManager = new WiFiAwareManager(this);
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this);
        LocationManager.setFusedLocationClient(fusedLocationClient);
    }

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {

        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                "org.katapp.flutter_p2p_demo.bluetooth/controller")
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "start":
                            bleGattServerManager.start();
                            result.success(null);
                            break;
                        case "stop":
                            bleGattServerManager.stop();
                            result.success(null);
                            break;
                        case "createMessage":
                            Integer size = call.argument("size");

                            new Thread(() -> {
                                Message createMessage = new Message(size);
                                createMessage.setSentLocationAsCurrent();
                                createMessage.setTimeSentAsCurrent();

                                //bleGattServerManager.updateMessageList(createMessage);
                                result.success(createMessage.toJson().toString());
                            }).start();
                            break;
                        case "addDataToReceivedMessage":
                            String messageString = call.argument("message");
                            Message message = new Message(messageString);

                            new Thread(() -> {
                                if (!message.getSender().equals(android.os.Build.MODEL + " :: " + Message.getSenderRandom())) {
                                    // if message is not from this device, add the received time and location
                                    message.setTimeReceivedAsCurrent();
                                    message.setReceivedLocationAsCurrent();
                                }

                                result.success(message.toJson().toString());
                            }).start();
                            break;
                        case "addMessage":
                            String messageJsonString = call.argument("message");
                            Message addMessage = new Message(messageJsonString);

                            bleGattServerManager.updateMessageList(addMessage);
                            result.success(null);
                            break;
                        case "isLocationEnabled":
                            result.success(LocationManager.isLocationEnabled());
                            break;
                        case "toggleLocationEnabled":
                            LocationManager.setLocationEnabled(!LocationManager.isLocationEnabled());
                            result.success(LocationManager.isLocationEnabled());
                            break;
                        default:
                            result.notImplemented();
                    }
                });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                "org.katapp.flutter_p2p_demo.wifidirect/controller")
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "start":
                            wifiDirectManager.start();
                            result.success(null);
                            break;
                        case "stop":
                            wifiDirectManager.stop();
                            result.success(null);
                            break;
                        case "createMessage":
                            Integer size = call.argument("size");

                            new Thread(() -> {
                                Message createMessage = new Message(size);
                                createMessage.setSentLocationAsCurrent();
                                createMessage.setTimeSentAsCurrent();

                                result.success(createMessage.toJson().toString());
                            }).start();
                            break;
                        case "addDataToReceivedMessage":
                            String messageString = call.argument("message");
                            Message message = new Message(messageString);

                            new Thread(() -> {
                                message.setTimeReceivedAsCurrent();
                                message.setReceivedLocationAsCurrent();

                                result.success(message.toJson().toString());
                            }).start();
                            break;
                        case "isLocationEnabled":
                            result.success(LocationManager.isLocationEnabled());
                            break;
                        case "toggleLocationEnabled":
                            LocationManager.setLocationEnabled(!LocationManager.isLocationEnabled());
                            result.success(LocationManager.isLocationEnabled());
                            break;
                        default:
                            result.notImplemented();
                    }
                });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                "org.katapp.flutter_p2p_demo.wifiaware/controller")
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "start":
                            wifiAwareManager.start();
                            result.success(null);
                            break;
                        case "stop":
                            wifiAwareManager.stop();
                            result.success(null);
                            break;
                        case "createMessage":
                            Integer size = call.argument("size");

                            new Thread(() -> {
                                Message createMessage = new Message(size);
                                createMessage.setSentLocationAsCurrent();
                                createMessage.setTimeSentAsCurrent();

                                result.success(createMessage.toJson().toString());
                            }).start();
                            break;
                        case "sendMessageToSubscribers":
                            String messageJsonString = call.argument("message");
                            Log.d("WiFiAwareActivity", "Sending message to all clients: " + messageJsonString);
                            wifiAwareManager.sendDataToAllClients(messageJsonString);
                            result.success(null);
                            break;
                        case "isLocationEnabled":
                            result.success(LocationManager.isLocationEnabled());
                            break;
                        case "toggleLocationEnabled":
                            LocationManager.setLocationEnabled(!LocationManager.isLocationEnabled());
                            result.success(LocationManager.isLocationEnabled());
                            break;
                        default:
                            result.notImplemented();
                    }
                });

        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                "org.katapp.flutter_p2p_demo.wifidirect/connection")
                .setStreamHandler(new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object arguments, EventChannel.EventSink events) {
                        wifiDirectManager.setWiFiP2PConnectionInfoListener(info -> {

                            if (info == null) {
                                events.success(null);
                                return;
                            }

                            if (!info.groupFormed) {
                                Log.d("WiFiDirectActivity", "Group not formed");
                                events.error("GROUP_NOT_FORMED", "Group not formed", null);
                                return;
                            }

                            events.success(new HashMap<String, Object>() {
                                {
                                    put("groupOwnerAddress", info.groupOwnerAddress.getHostAddress());
                                    put("isGroupOwner", info.isGroupOwner);
                                }
                            });
                        });
                    }

                    @Override
                    public void onCancel(Object arguments) {
                        wifiDirectManager.setWiFiP2PConnectionInfoListener(null);
                    }
                });

        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                "org.katapp.flutter_p2p_demo.wifiaware/connection")
                .setStreamHandler(new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object arguments, EventChannel.EventSink events) {
                        wifiAwareManager.setConnectionInfoListener(connected -> {
                            events.success(connected);
                        });
                    }

                    @Override
                    public void onCancel(Object arguments) {
                        wifiAwareManager.setConnectionInfoListener(null);
                    }
                });

        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                "org.katapp.flutter_p2p_demo.wifiaware/messageStream")
                .setStreamHandler(new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object arguments, EventChannel.EventSink events) {
                        wifiAwareManager.setMessageListener(message -> {
                            events.success(message);
                        });
                    }

                    @Override
                    public void onCancel(Object arguments) {
                        wifiAwareManager.setMessageListener(null);
                    }
                });

        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                "org.katapp.flutter_p2p_demo.bluetooth/connection")
                .setStreamHandler(new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object arguments, EventChannel.EventSink events) {
                        bleGattServerManager.setBluetoothMessageListener(messageList -> {
                            events.success(messageList);
                        });
                    }

                    @Override
                    public void onCancel(Object arguments) {
                        bleGattServerManager.setBluetoothMessageListener(null);
                    }
                });

    }

}