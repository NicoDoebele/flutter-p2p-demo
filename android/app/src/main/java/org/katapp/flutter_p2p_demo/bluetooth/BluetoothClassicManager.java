package org.katapp.flutter_p2p_demo.bluetooth;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothServerSocket;
import android.bluetooth.BluetoothSocket;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.BroadcastReceiver;
import android.util.Log;
import android.os.Handler;
import android.os.Looper;

import java.util.Set;
import java.util.UUID;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.IOException;

import org.katapp.flutter_p2p_demo.bluetooth.interfaces.BluetoothClassicConnectionListener;
import org.katapp.flutter_p2p_demo.bluetooth.interfaces.BluetoothClassicMessageListener;

public class BluetoothClassicManager {
    BluetoothManager bluetoothManager;
    BluetoothAdapter bluetoothAdapter;
    Context context;
    BluetoothBroadcastReceiver bluetoothBroadcastReceiver;

    final String NAME = "KATAPP_BLUETOOTH_CLASSIC";
    final UUID BLUETOOTH_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");

    private AcceptThread acceptThread;
    private ConnectThread connectThread;
    private Thread readThread;

    private BluetoothClassicMessageListener messageListener;
    private BluetoothClassicConnectionListener connectionListener;

    private BluetoothSocket socket;

    private final BluetoothBroadcastReceiver receiver = new BluetoothBroadcastReceiver();

    private Handler mainHandler;

    public BluetoothClassicManager(Context context) {
        this.context = context;
    }

    public void setBluetoothClassicMessageListener(BluetoothClassicMessageListener messageListener) {
        this.messageListener = messageListener;
    }

    public void setBluetoothClassicConnectionListener(BluetoothClassicConnectionListener connectionListener) {
        this.connectionListener = connectionListener;
    }

    public BluetoothAdapter getBluetoothAdapter() {
        return bluetoothAdapter;
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
        acceptThread.start();

        mainHandler = new Handler(Looper.getMainLooper());

        getPairedDevices();
    }

    public void stop() {
        bluetoothAdapter = null;
        bluetoothManager = null;

        if (acceptThread != null) {
            acceptThread.interrupt();
            acceptThread = null;
        }

        if (connectThread != null) {
            connectThread.interrupt();
            connectThread = null;
        }

        if (readThread != null) {
            readThread.interrupt();
            readThread = null;
        }

        closeSocket();

        mainHandler = null;

        context.unregisterReceiver(receiver);
    }

    private void getPairedDevices() {
        Set<BluetoothDevice> pairedDevices = bluetoothAdapter.getBondedDevices();

        Log.d("BluetoothClassic", "Paired devices: " + pairedDevices.size());

        if (pairedDevices.size() > 0) {
        // There are paired devices. Get the name and address of each paired device.
            for (BluetoothDevice device : pairedDevices) {
                String deviceName = device.getName();
                String deviceHardwareAddress = device.getAddress(); // MAC address
                Log.d("BluetoothClassic", "Device name: " + deviceName + " MAC address: " + deviceHardwareAddress);

                // start connect thread
                connectThread = new ConnectThread(device, BLUETOOTH_UUID, this);
                connectThread.start();
            }
        }
    }

    public void manageBluetoothSocket(BluetoothSocket socket) {
        if (this.socket == null) {
            this.socket = socket;
            mainHandler.post(() -> {
                if (connectionListener != null) {
                    connectionListener.onConnectionStateChanged(true);
                }
            });
            startReading();
            Log.d("BluetoothClassic", "Connected to device: " + socket.getRemoteDevice().getName() + " " + socket.getRemoteDevice().getAddress());
            return;
        }

        closeSocket();
        Log.d("Bluetooth", "Connected to device: " + socket.getRemoteDevice().getName() + " " + socket.getRemoteDevice().getAddress() + " already connected, socket closed");
    }

    private void startReading() {
        readThread = new Thread(() -> {
            try {
                InputStream inputStream = socket.getInputStream();
                byte[] buffer = new byte[1024];
                int bytesRead;

                while ((bytesRead = inputStream.read(buffer)) != -1) {
                    String message = new String(buffer, 0, bytesRead);
                    mainHandler.post(() -> {
                        if (messageListener != null) {
                            messageListener.onMessageReceived(message);
                        }
                    });
                }
            } catch (IOException e) {
                mainHandler.post(() -> {
                    if (connectionListener != null) {
                        connectionListener.onConnectionStateChanged(false);
                    }
                });
                Log.e("BluetoothClassic", "Error reading from socket: " + e.getMessage());
                closeSocket();
            }
        });
        readThread.start();
    }

    public void sendMessage(String message) {
        if (socket != null) {
            try {
                OutputStream outputStream = socket.getOutputStream();
                outputStream.write(message.getBytes());
            } catch (IOException e) {
                Log.e("BluetoothClassic", "Error writing to socket: " + e.getMessage());
            }
            Log.d("BluetoothClassic", "Sent message: " + message);
        }
    }

    private void closeSocket() {
        if (socket == null) {
            return;
        }

        try {
            socket.close();
            socket = null;
            Log.d("BluetoothClassic", "Socket closed");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
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

class AcceptThread extends Thread {
    private final BluetoothServerSocket mmServerSocket;
    private BluetoothClassicManager bluetoothClassicManager;
 
    public AcceptThread(String name, UUID uuid, BluetoothClassicManager bluetoothClassicManager) {
        // Use a temporary object that is later assigned to mmServerSocket
        // because mmServerSocket is final.
        BluetoothServerSocket tmp = null;
        this.bluetoothClassicManager = bluetoothClassicManager;
        try {
            // MY_UUID is the app's UUID string, also used by the client code.
            tmp = bluetoothClassicManager.getBluetoothAdapter().listenUsingRfcommWithServiceRecord(name, uuid);
        } catch (IOException e) {
            Log.e("BluetoothClassic", "Socket's listen() method failed", e);
        }
        mmServerSocket = tmp;
    }
 
    public void run() {
        BluetoothSocket socket = null;
        // Keep listening until exception occurs or a socket is returned.
        while (true) {
            try {
                socket = mmServerSocket.accept();
                Log.d("BluetoothClassic", "Socket accepted");
            } catch (IOException e) {
                Log.e("BluetoothClassic", "Socket's accept() method failed", e);
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
            Log.e("BluetoothClassic", "Could not close the connect socket", e);
        }
    }
}

class ConnectThread extends Thread {
    private final BluetoothSocket mmSocket;
    private final BluetoothDevice mmDevice;
    private BluetoothClassicManager bluetoothClassicManager;
 
    public ConnectThread(BluetoothDevice device, UUID uuid, BluetoothClassicManager bluetoothClassicManager) {
        // Use a temporary object that is later assigned to mmSocket
        // because mmSocket is final.
        BluetoothSocket tmp = null;
        mmDevice = device;
        this.bluetoothClassicManager = bluetoothClassicManager;
 
        try {
            // Get a BluetoothSocket to connect with the given BluetoothDevice.
            // MY_UUID is the app's UUID string, also used in the server code.
            tmp = device.createRfcommSocketToServiceRecord(uuid);
        } catch (IOException e) {
            Log.e("BluetoothClassic", "Socket's create() method failed", e);
        }
        mmSocket = tmp;
    }
 
    public void run() {
        try {
            // Connect to the remote device through the socket. This call blocks
            // until it succeeds or throws an exception.
            mmSocket.connect();
            Log.d("BluetoothClassic", "Socket connected");
        } catch (IOException connectException) {
            // Unable to connect; close the socket and return.
            try {
                mmSocket.close();
            } catch (IOException closeException) {
                Log.e("BluetoothClassic", "Could not close the client socket", closeException);
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
            Log.e("BluetoothClassic", "Could not close the client socket", e);
        }
    }
 }
 