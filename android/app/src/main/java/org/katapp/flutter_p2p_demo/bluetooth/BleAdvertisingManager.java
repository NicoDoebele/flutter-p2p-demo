package org.katapp.flutter_p2p_demo.bluetooth;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.AdvertiseCallback;
import android.bluetooth.le.AdvertiseSettings;
import android.bluetooth.le.BluetoothLeAdvertiser;
import android.bluetooth.le.AdvertiseData;
import android.content.Context;
import android.os.ParcelUuid;

public class BleAdvertisingManager {
    private BluetoothLeAdvertiser bleAdvertiser;
    private AdvertiseCallback advertiseCallback;

    public BleAdvertisingManager(Context context) {
        BluetoothManager bluetoothManager = (BluetoothManager) context.getSystemService(Context.BLUETOOTH_SERVICE);
        BluetoothAdapter bluetoothAdapter = bluetoothManager.getAdapter();
        if (bluetoothAdapter != null) {
            bleAdvertiser = bluetoothAdapter.getBluetoothLeAdvertiser();
        }
    }

    public void startAdvertising() {

        if (bleAdvertiser == null) {
            // BLE Advertising is not supported on this device
            return;
        }

        AdvertiseSettings settings = new AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .setConnectable(true)
                .build();

        AdvertiseData data = new AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .addServiceUuid(ParcelUuid.fromString("c07b8cf2-b8ff-4ef4-b4e1-dd8aa2415f81"))
                .build();

        advertiseCallback = new AdvertiseCallback() {
            @Override
            public void onStartSuccess(AdvertiseSettings settingsInEffect) {
                super.onStartSuccess(settingsInEffect);
                // Advertising started successfully
                System.out.println("Advertising started successfully");
            }

            @Override
            public void onStartFailure(int errorCode) {
                super.onStartFailure(errorCode);
                // Advertising failed to start
                System.out.println("Advertising failed to start. Error code: " + errorCode);
            }
        };

        bleAdvertiser.startAdvertising(settings, data, advertiseCallback);
    }

    public void stopAdvertising() {
        if (bleAdvertiser != null && advertiseCallback != null) {
            bleAdvertiser.stopAdvertising(advertiseCallback);
        }
    }
}
