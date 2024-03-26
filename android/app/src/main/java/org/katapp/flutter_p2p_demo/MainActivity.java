package org.katapp.flutter_p2p_demo;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import android.os.Bundle;

import org.katapp.flutter_p2p_demo.BleGattServerManager;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "org.katapp.flutter_p2p_demo/advertising";
    private BleGattServerManager bleGattServerManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        bleGattServerManager = new BleGattServerManager(this);
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
                        default:
                            result.notImplemented();
                    }
                });
    }
}