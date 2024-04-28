package org.katapp.flutter_p2p_demo.bluetooth;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.util.Log;

import java.util.Set;
import java.util.UUID;

public class BluetoothClassicManager {
    BluetoothManager bluetoothManager;
    BluetoothAdapter bluetoothAdapter;
    Context context;
    BluetoothBroadcastReceiver bluetoothBroadcastReceiver;
    BluetoothSocket socket;

    final String NAME = "KATAPP_BLUETOOTH_CLASSIC";
    final UUID BLUETOOTH_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");

    private AcceptThread acceptThread;
    private ConnectThread connectThread;

    private final BluetoothBroadcastReceiver receiver = new BluetoothBroadcastReceiver();

    public BluetoothClassicManager(Context context) {
        this.context = context;
    }
    
    public void start() {
        bluetoothManager = context.getSystemService(BluetoothManager.class);
        bluetoothAdapter = bluetoothManager.getAdapter();

        // Register for broadcasts when a device is discovered.
        IntentFilter filter = new IntentFilter(BluetoothDevice.ACTION_FOUND);
        context.registerReceiver(receiver, filter);

        Log.d("Bluetooth", "Bluetooth adapter: " + bluetoothAdapter.getName() + " " + bluetoothAdapter.getAddress());

        // start accept thread
        acceptThread = new AcceptThread(NAME, BLUETOOTH_UUID, this);
        acceptThread.run();

        getPairedDevices();
    }

    public void stop() {
        bluetoothAdapter = null;
        bluetoothManager = null;

        context.unregisterReceiver(receiver);
    }

    private void getPairedDevices() {
        Set<BluetoothDevice> pairedDevices = bluetoothAdapter.getBondedDevices();

        Log.d("Bluetooth", "Paired devices: " + pairedDevices.size());

        if (pairedDevices.size() > 0) {
        // There are paired devices. Get the name and address of each paired device.
            for (BluetoothDevice device : pairedDevices) {
                String deviceName = device.getName();
                String deviceHardwareAddress = device.getAddress(); // MAC address
                Log.d("Bluetooth", "Device name: " + deviceName + " MAC address: " + deviceHardwareAddress);

                // start connect thread
                connectThread = new ConnectThread(device, this);
                connectThread.run();
            }
        }
    }

    public void manageBluetoothSocket(BluetoothSocket socket) {
        // Do something with the socket
        
    }

    /*
    private void makeDiscoverable() {
        int requestCode = 1;
        Intent discoverableIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE);
        discoverableIntent.putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, 0);
        context.startActivityForResult(discoverableIntent, requestCode);
    }
    */
}

class BluetoothBroadcastReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (BluetoothDevice.ACTION_FOUND.equals(action)) {
            // Discovery has found a device. Get the BluetoothDevice
            // object and its info from the Intent.
            BluetoothDevice device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
            String deviceName = device.getName();
            String deviceHardwareAddress = device.getAddress(); // MAC address
        }
    }
}

private class AcceptThread extends Thread {
    private final BluetoothServerSocket mmServerSocket;
    private BluetoothClassicManager bluetoothClassicManager;
 
    public AcceptThread(String name, UUID uuid, BluetoothClassicManager bluetoothClassicManager) {
        // Use a temporary object that is later assigned to mmServerSocket
        // because mmServerSocket is final.
        BluetoothServerSocket tmp = null;
        this.bluetoothClassicManager = bluetoothClassicManager;
        try {
            // MY_UUID is the app's UUID string, also used by the client code.
            tmp = bluetoothAdapter.listenUsingRfcommWithServiceRecord(name, uuid);
        } catch (IOException e) {
            Log.e(TAG, "Socket's listen() method failed", e);
        }
        mmServerSocket = tmp;
    }
 
    public void run() {
        BluetoothSocket socket = null;
        // Keep listening until exception occurs or a socket is returned.
        while (true) {
            try {
                socket = mmServerSocket.accept();
            } catch (IOException e) {
                Log.e(TAG, "Socket's accept() method failed", e);
                break;
            }
 
            if (socket != null) {
                // A connection was accepted. Perform work associated with
                // the connection in a separate thread.
                bluetoothClassicManager.manageBluetoothSocket(socket);
                //mmServerSocket.close();
                //break;
            }
        }
    }
 
    // Closes the connect socket and causes the thread to finish.
    public void cancel() {
        try {
            mmServerSocket.close();
        } catch (IOException e) {
            Log.e(TAG, "Could not close the connect socket", e);
        }
    }
}

private class ConnectThread extends Thread {
    private final BluetoothSocket mmSocket;
    private final BluetoothDevice mmDevice;
    private BluetoothClassicManager bluetoothClassicManager;
 
    public ConnectThread(BluetoothDevice device, BluetoothClassicManager bluetoothClassicManager) {
        // Use a temporary object that is later assigned to mmSocket
        // because mmSocket is final.
        BluetoothSocket tmp = null;
        mmDevice = device;
        this.bluetoothClassicManager = bluetoothClassicManager;
 
        try {
            // Get a BluetoothSocket to connect with the given BluetoothDevice.
            // MY_UUID is the app's UUID string, also used in the server code.
            tmp = device.createRfcommSocketToServiceRecord(MY_UUID);
        } catch (IOException e) {
            Log.e(TAG, "Socket's create() method failed", e);
        }
        mmSocket = tmp;
    }
 
    public void run() {
        try {
            // Connect to the remote device through the socket. This call blocks
            // until it succeeds or throws an exception.
            mmSocket.connect();
        } catch (IOException connectException) {
            // Unable to connect; close the socket and return.
            try {
                mmSocket.close();
            } catch (IOException closeException) {
                Log.e(TAG, "Could not close the client socket", closeException);
            }
            return;
        }
 
        // The connection attempt succeeded. Perform work associated with
        // the connection in a separate thread.
        bluetoothClassicManager.manageBluetoothSocket(mmSocket);
    }
 
    // Closes the client socket and causes the thread to finish.
    public void cancel() {
        try {
            mmSocket.close();
        } catch (IOException e) {
            Log.e(TAG, "Could not close the client socket", e);
        }
    }
 }
 