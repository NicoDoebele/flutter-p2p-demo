package org.katapp.flutter_p2p_demo.bluetooth;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothGattServer;
import android.bluetooth.BluetoothGattServerCallback;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGattCharacteristic;
import android.content.Context;
import java.util.UUID;
import java.util.ArrayList;
import java.util.List;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattDescriptor;

import org.katapp.flutter_p2p_demo.bluetooth.BleAdvertisingManager;

public class BleGattServerManager {
    private Context context;
    private BluetoothManager bluetoothManager;
    private BluetoothAdapter bluetoothAdapter;
    private BluetoothGattServer gattServer;
    private BleAdvertisingManager advertisingManager;
    private BluetoothGattCharacteristic characteristic;

    private final List<String> dataList = new ArrayList<>();
    private List<BluetoothDevice> subscribedDevices = new ArrayList<>();

    private final UUID SERVICE_UUID = UUID.fromString("c07b8cf2-b8ff-4ef4-b4e1-dd8aa2415f81");
    private final UUID CHARACTERISTIC_UUID = UUID.fromString("5e6525b1-4a90-4baf-a4a1-9b4a53641970");
    private final UUID CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");

    public BleGattServerManager(Context context) {
        this.context = context;
        bluetoothManager = (BluetoothManager) context.getSystemService(Context.BLUETOOTH_SERVICE);
        bluetoothAdapter = bluetoothManager.getAdapter();
        advertisingManager = new BleAdvertisingManager(context);
    }

    public void start() {
        if (bluetoothAdapter == null) {
            System.out.println("Bluetooth not supported");
            return;
        }

        gattServer = bluetoothManager.openGattServer(context, gattServerCallback);
        setupService();
        advertisingManager.startAdvertising();
    }

    private void setupService() {
        BluetoothGattService service = new BluetoothGattService(SERVICE_UUID,
                BluetoothGattService.SERVICE_TYPE_PRIMARY);
        characteristic = new BluetoothGattCharacteristic(
                CHARACTERISTIC_UUID,
                BluetoothGattCharacteristic.PROPERTY_READ | BluetoothGattCharacteristic.PROPERTY_WRITE
                        | BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                BluetoothGattCharacteristic.PERMISSION_READ | BluetoothGattCharacteristic.PERMISSION_WRITE);

        BluetoothGattDescriptor descriptor = new BluetoothGattDescriptor(CCCD_UUID,
                BluetoothGattDescriptor.PERMISSION_WRITE | BluetoothGattDescriptor.PERMISSION_READ);
        characteristic.addDescriptor(descriptor);
        service.addCharacteristic(characteristic);
        gattServer.addService(service);
    }

    public void stop() {
        if (gattServer != null) {
            gattServer.close();
        }
        advertisingManager.stopAdvertising();
    }

    public void updateDataList(String data) {

        // if data alredy in list return
        if (dataList.contains(data)) {
            System.out.println("Data already in list");
            return;
        }

        dataList.add(data);
        System.out.println(dataList.toString());
        notifySubscribedDevices(data.getBytes());
        System.out.println("Data received: " + data);
    }

    public void notifySubscribedDevices(byte[] data) {
        System.out.println("Notify subscribed devices");
        for (BluetoothDevice device : subscribedDevices) {
            System.out.println("Notifying Device: " + device.getAddress());
            characteristic.setValue(data);
            gattServer.notifyCharacteristicChanged(device, characteristic, false);
        }
    }

    private final BluetoothGattServerCallback gattServerCallback = new BluetoothGattServerCallback() {
        @Override
        public void onConnectionStateChange(BluetoothDevice device, int status, int newState) {
            super.onConnectionStateChange(device, status, newState);
            // Handle device connection and disconnection
        }

        @Override
        public void onCharacteristicReadRequest(BluetoothDevice device, int requestId, int offset,
                BluetoothGattCharacteristic characteristic) {
            if (CHARACTERISTIC_UUID.equals(characteristic.getUuid())) {
                // Concatenate all strings from dataList with a separator for demonstration
                String allData = String.join(", ", dataList); // Using comma as a separator
                byte[] data = allData.getBytes();
                gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, data);
            } else {
                gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null);
            }
        }

        @Override
        public void onCharacteristicWriteRequest(BluetoothDevice device, int requestId,
                BluetoothGattCharacteristic characteristic, boolean preparedWrite,
                boolean responseNeeded, int offset, byte[] value) {
            if (CHARACTERISTIC_UUID.equals(characteristic.getUuid())) {
                // Add received data to dataList
                String receivedData = new String(value);

                updateDataList(receivedData);

                if (responseNeeded) {
                    gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value);
                }
            }
        }

        @Override
        public void onDescriptorWriteRequest(BluetoothDevice device, int requestId,
                BluetoothGattDescriptor descriptor,
                boolean preparedWrite, boolean responseNeeded,
                int offset, byte[] value) {
            System.out.println("Descriptor write request received with uuid" + descriptor.getUuid());
            if (CCCD_UUID.equals(descriptor.getUuid())) {
                System.out.println("Descriptor write request received");
                boolean isSubscribed = (value[0] == 1);
                if (isSubscribed) {
                    System.out.println("Subscribing device: " + device.getAddress());
                    // Add device to subscribed devices list
                    if (!subscribedDevices.contains(device)) {
                        subscribedDevices.add(device);
                        System.out.println("Device subscribed: " + device.getAddress());
                    }
                } else {
                    // Remove device from subscribed devices list
                    subscribedDevices.remove(device);
                }

                if (responseNeeded) {
                    gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null);
                }
            }
        }
    };
}
