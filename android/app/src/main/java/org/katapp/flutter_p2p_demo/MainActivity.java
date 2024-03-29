package org.katapp.flutter_p2p_demo;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.EventChannel;
import android.os.Bundle;

import org.katapp.flutter_p2p_demo.BleGattServerManager;
import org.katapp.flutter_p2p_demo.WiFiDirectManager;
import android.util.Log;
import android.net.wifi.p2p.WifiP2pInfo;
import java.util.HashMap;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "org.katapp.flutter_p2p_demo/advertising";
    private static final String EVENT_CHANNEL = "org.katapp.flutter_p2p_demo/connection";
    private BleGattServerManager bleGattServerManager;
    private WiFiDirectManager wifiDirectManager;
    Bundle savedInstanceState;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        this.savedInstanceState = savedInstanceState;
        bleGattServerManager = new BleGattServerManager(this);
        wifiDirectManager = new WiFiDirectManager(this);
    }

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {

        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "startBluetoothGattServer":
                            bleGattServerManager.startGattServer();
                            result.success(null);
                            break;
                        case "stopBluetoothGattServer":
                            bleGattServerManager.startGattServer();
                            result.success(null);
                            break;
                        case "updateBluetoothDataList":
                            String data = call.argument("data");
                            bleGattServerManager.updateDataList(data);
                            result.success(null);
                            break;
                        case "initWifiDirect":
                            wifiDirectManager.init(savedInstanceState);
                            result.success(null);
                            break;
                        case "wifiDirectDiscoverPeers":
                            wifiDirectManager.discoverPeers();
                            result.success(null);
                            break;
                        default:
                            result.notImplemented();
                    }
                });

        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), EVENT_CHANNEL)
                .setStreamHandler(new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object arguments, EventChannel.EventSink events) {
                        wifiDirectManager.setWiFiP2PConnectionInfoListener(info -> {

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
    }

}