package org.katapp.flutter_p2p_demo;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import org.katapp.flutter_p2p_demo.BleAdvertisingManager;
import android.os.Bundle;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "org.katapp.flutter_p2p_demo/advertising";
    private BleAdvertisingManager bleAdvertisingManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        bleAdvertisingManager = new BleAdvertisingManager(this);
    }

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "startBluetoothAdvertising":
                            bleAdvertisingManager.startAdvertising();
                            result.success(null);
                            break;
                        case "stopBluetoothAdvertising":
                            bleAdvertisingManager.stopAdvertising();
                            result.success(null);
                            break;
                        default:
                            result.notImplemented();
                    }
                });
    }
}