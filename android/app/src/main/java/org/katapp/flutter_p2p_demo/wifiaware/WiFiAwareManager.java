package org.katapp.flutter_p2p_demo.wifiaware;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.wifi.aware.AttachCallback;
import android.net.wifi.aware.WifiAwareManager;
import android.net.wifi.aware.WifiAwareSession;
import android.util.Log;
import android.content.pm.PackageManager;
import android.net.wifi.aware.DiscoverySessionCallback;
import android.net.wifi.aware.PublishConfig;
import android.net.wifi.aware.SubscribeConfig;
import android.net.wifi.aware.PeerHandle;
import android.net.wifi.aware.PublishDiscoverySession;
import android.net.wifi.aware.SubscribeDiscoverySession;
import java.util.List;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.net.NetworkSpecifier;
import android.net.wifi.aware.WifiAwareNetworkSpecifier;
import android.net.wifi.aware.WifiAwareNetworkInfo;
import java.net.Inet6Address;
import java.net.ServerSocket;
import android.os.Handler;
import android.os.Looper;
import java.util.ArrayList;
import java.net.Socket;
import java.io.IOException;
import java.io.OutputStream;
import java.io.InputStream;
import org.json.JSONException;
import org.json.JSONObject;

import org.katapp.flutter_p2p_demo.wifidirect.interfaces.WiFiAwareConnectionInfoListener;
import org.katapp.flutter_p2p_demo.message.Message;

public class WiFiAwareManager {
    private Context context;
    private WifiAwareManager wifiAwareManager;
    private IntentFilter filter;
    private WiFiAwareBroadcastReceiver receiver;
    private WifiAwareSession session;
    private PublishDiscoverySession publishSession;
    private SubscribeDiscoverySession subscribeSession;
    private ConnectivityManager connectivityManager;
    private Network network;
    private NetworkCapabilities networkCapabilities;
    private ConnectivityManager.NetworkCallback networkCallback;
    private WiFiAwareConnectionInfoListener connectionInfoListener;

    private Handler mainHandler = new Handler(Looper.getMainLooper());

    private ServerSocket serverSocket;
    private List<Socket> subscribers = new ArrayList<>();
    int port;
    private Thread serverThread;

    private List<Socket> clientSockets = new ArrayList<>();
    private List<Thread> clientThreads = new ArrayList<>();

    private List<Inet6Address> connectedPeerIpv6Addresses = new ArrayList<>();

    private String priorData = "";

    public void setConnectionInfoListener(WiFiAwareConnectionInfoListener connectionInfoListener) {
        this.connectionInfoListener = connectionInfoListener;
    }

    private final PublishConfig publishConfig = new PublishConfig.Builder()
            .setServiceName("KatAppWiFiAwareService")
            .build();
    private final SubscribeConfig subscribeConfig = new SubscribeConfig.Builder()
            .setServiceName("KatAppWiFiAwareService")
            .build();

    public WiFiAwareManager(Context context) {
        this.context = context;
    }

    private boolean isAvailable() {
        return context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_WIFI_AWARE);
    }

    public void start() {
        if (!isAvailable()) {
            Log.d("WiFiAwareManager", "WiFi Aware is not available");
            return;
        }

        createSocket();

        wifiAwareManager = (WifiAwareManager) context.getSystemService(Context.WIFI_AWARE_SERVICE);
        filter = new IntentFilter(WifiAwareManager.ACTION_WIFI_AWARE_STATE_CHANGED);
        receiver = new WiFiAwareBroadcastReceiver(wifiAwareManager);
        connectivityManager = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);

        context.registerReceiver(receiver, filter);

        wifiAwareManager.attach(new AttachCallback() {
            @Override
            public void onAttached(WifiAwareSession wifiAwareSession) {
                Log.d("WiFiAwareManager", "WiFi Aware attached");

                session = wifiAwareSession;
                startPublishing();
                startSubscribing();
            }

            @Override
            public void onAttachFailed() {
                Log.d("WiFiAwareManager", "WiFi Aware attach failed");
            }
        }, null);
    }

    public void stop() {

        if (serverSocket != null) {
            try {
                serverSocket.close();
            } catch (Exception e) {
                Log.d("WiFiAwareManager", "Error closing server socket");
            }
        }

        for (Socket subscriber : subscribers) {
            try {
                subscriber.close();
            } catch (Exception e) {
                Log.d("WiFiAwareManager", "Error closing subscriber socket");
            }
        }

        for (Socket clientSocket : clientSockets) {
            try {
                clientSocket.close();
            } catch (Exception e) {
                Log.d("WiFiAwareManager", "Error closing client socket");
            }
        }

        for (Thread clientThread : clientThreads) {
            clientThread.interrupt();
        }

        serverThread.interrupt();
        serverSocket = null;
        serverThread = null;

        clientThreads.clear();
        subscribers.clear();
        clientSockets.clear();

        if (network != null) {
            connectivityManager.unregisterNetworkCallback(networkCallback);
            network = null;
        }

        if (publishSession != null) {
            publishSession.close();
            publishSession = null;
        }

        if (subscribeSession != null) {
            subscribeSession.close();
            subscribeSession = null;
        }

        if (session != null) {
            session.close();
            session = null;
        }

        context.unregisterReceiver(receiver);

        wifiAwareManager = null;

        connectionInfoListener = null;

        mainHandler.removeCallbacksAndMessages(null);

        Log.d("WiFiAwareManager", "WiFi Aware stopped");
    }

    private void startPublishing() {
        if (session == null) {
            return;
        }

        session.publish(publishConfig, new DiscoverySessionCallback() {
            @Override
            public void onPublishStarted(PublishDiscoverySession session) {
                Log.d("WiFiAwareManager", "WiFi Aware publish started");
                publishSession = session;
            }

            @Override
            public void onMessageReceived(PeerHandle peerHandle, byte[] message) {
                String messageString = new String(message);
                Log.d("WiFiAwareManager", "WiFi Aware message received " + messageString);
                if (messageString.equals("Session Request")) {
                    requestNetwork(publishSession, null, peerHandle);
                    publishSession.sendMessage(peerHandle, 0, "Session Accepted".getBytes());
                }
            }
        }, null);
    }

    private void createSocket() {
        try {
            serverSocket = new ServerSocket(8888);
            port = serverSocket.getLocalPort();
            serverThread = new Thread(this::acceptClients);
            serverThread.start();
        } catch (Exception e) {
            Log.d("WiFiAwareManager", "Error creating server socket");
        }
    }

    private void acceptClients() {
        try {
            while (true) {
                Socket subscriber = serverSocket.accept(); // accept a connection
                synchronized (subscribers) {
                    subscribers.add(subscriber); // add to the list
                }
                System.out.println("Subscriber connected: " + subscriber.getInetAddress());
            }
        } catch (IOException e) {
            System.err.println("Error accepting subscriber connection");
            e.printStackTrace();
        }
    }

    public void sendDataToAllClients(String messageJson) {
        new Thread(() -> {
            sendDatatoAllClientsThread(messageJson);
        }).start();
    }

    private void sendDatatoAllClientsThread(String messageJson) {
        byte[] data = messageJson.getBytes();

        Log.d("WiFiAwareManager", "Sending data to all subscribers");
        Log.d("WiFiAwareManager", "Subscribers: " + subscribers.size());

        synchronized (subscribers) {
            for (Socket subscriber : subscribers) {
                try {
                    OutputStream out = subscriber.getOutputStream();
                    out.write(data);
                    out.flush();
                } catch (IOException e) {
                    System.err.println("Error sending data to client: " + subscriber.getInetAddress());
                    e.printStackTrace();
                }
            }
        }
    }

    private void connectToServer() {
        WifiAwareNetworkInfo peerAwareInfo = (WifiAwareNetworkInfo) networkCapabilities.getTransportInfo();
        Inet6Address peerIpv6 = peerAwareInfo.getPeerIpv6Addr();
        //int peerPort = peerAwareInfo.getPort();
        int peerPort = 8888;

        if (connectedPeerIpv6Addresses.contains(peerIpv6)) {
            return;
        }

        connectedPeerIpv6Addresses.add(peerIpv6);
    
        try {
            Socket socket = network.getSocketFactory().createSocket(peerIpv6, peerPort);
            clientSockets.add(socket);
            Log.d("WiFiAwareManager", "Connected to server");
    
            Thread socketThread = new Thread(() -> {
                StringBuilder partialMessage = new StringBuilder();
                try (InputStream inputStream = socket.getInputStream()) {
                    byte[] data = new byte[1024];
                    int bytesRead;
                    while ((bytesRead = inputStream.read(data)) != -1) {
                        partialMessage.append(new String(data, 0, bytesRead));
                        processMessages(partialMessage);
                    }
                } catch (IOException e) {
                    System.err.println("Error reading from server");
                    e.printStackTrace();
                } finally {
                    try {
                        socket.close();
                    } catch (IOException e) {
                        System.err.println("Error closing socket");
                        e.printStackTrace();
                    }
                }
            });
    
            socketThread.start();
            clientThreads.add(socketThread);
        } catch (IOException e) {
            Log.d("WiFiAwareManager", "Error connecting to server");
            e.printStackTrace();
        }
    }

    private void processMessages(StringBuilder partialMessage) {
        try {
            int lastIndex = 0;
            for (int i = 0; i < partialMessage.length(); i++) {
                if (partialMessage.charAt(i) == '}' && isJsonComplete(partialMessage, lastIndex, i)) {
                    String subStr = partialMessage.substring(lastIndex, i + 1);
                    try {
                        JSONObject messageJSON = new JSONObject(subStr);
                        Message messageObject = new Message(messageJSON.toString());
                        messageObject.setTimeReceivedAsCurrent();
        
                        mainHandler.post(() -> {
                            if (connectionInfoListener != null) {
                                connectionInfoListener.onMessageReceived(messageObject.toJson().toString());
                            }
                        });
        
                        lastIndex = i + 1;
                    } catch (JSONException e) {
                        continue; // not a complete JSON object yet
                    }
                }
            }
            partialMessage.delete(0, lastIndex); // Clear the processed part of the buffer
        } catch (Exception e) {
            System.err.println("Error processing message");
            e.printStackTrace();
        }
    }
    
    private boolean isJsonComplete(StringBuilder partialMessage, int start, int end) {
        String testingStr = partialMessage.substring(start, end + 1);
        try {
            new JSONObject(testingStr);
            return true;
        } catch (JSONException e) {
            return false;
        }
    }

    private void requestNetwork(PublishDiscoverySession publishSession, SubscribeDiscoverySession subscribeSession, PeerHandle peerHandle) {
        NetworkSpecifier networkSpecifier;

        if (publishSession != null) {
            networkSpecifier = new WifiAwareNetworkSpecifier.Builder(publishSession, peerHandle)
                .setPskPassphrase("KatAppPassword")
                .setPort(8888)
                .build();
        } else if (subscribeSession != null) {
            networkSpecifier = new WifiAwareNetworkSpecifier.Builder(subscribeSession, peerHandle)
                .setPskPassphrase("KatAppPassword")
                .build();
        } else {
            return;
        }

        NetworkRequest myNetworkRequest = new NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI_AWARE)
            .setNetworkSpecifier(networkSpecifier)
            .build();
        networkCallback = new ConnectivityManager.NetworkCallback() {
            @Override
            public void onAvailable(Network newNetwork) {
                Log.d("WiFiAwareManager", "WiFi Aware network available");
                network = newNetwork;
            }

            @Override
            public void onUnavailable() {
                Log.d("WiFiAwareManager", "WiFi Aware network request failed - unavailable");
            }

            @Override
            public void onCapabilitiesChanged(Network newNetwork, NetworkCapabilities newNetworkCapabilities) {
                Log.d("WiFiAwareManager", "WiFi Aware network capabilities changed");
                network = newNetwork;
                networkCapabilities = newNetworkCapabilities;
                connectToServer();
            }

            @Override
            public void onLost(Network network) {
                Log.d("WiFiAwareManager", "WiFi Aware network lost");
                // network = null;
                // networkCapabilities = null;
            }
        };

        connectivityManager.requestNetwork(myNetworkRequest, networkCallback);
        Log.d("WiFiAwareManager", "WiFi Aware network requested");
    }

    private void startSubscribing() {
        if (session == null) {
            return;
        }

        session.subscribe(subscribeConfig, new DiscoverySessionCallback() {
            @Override
            public void onSubscribeStarted(SubscribeDiscoverySession session) {
                Log.d("WiFiAwareManager", "WiFi Aware subscribe started");
                subscribeSession = session;
            }

            @Override
            public void onServiceDiscovered(PeerHandle peerHandle,
                    byte[] serviceSpecificInfo, List<byte[]> matchFilter) {
                Log.d("WiFiAwareManager", "WiFi Aware service discovered");
                subscribeSession.sendMessage(peerHandle, 0, "Session Request".getBytes());
            }

            @Override
            public void onMessageReceived(PeerHandle peerHandle, byte[] message) {
                String messageString = new String(message);
                Log.d("WiFiAwareManager", "WiFi Aware message received " + messageString);
                if (messageString.equals("Session Accepted")) {
                    requestNetwork(null, subscribeSession, peerHandle);
                }
            }
        }, null);
    }
}

class WiFiAwareBroadcastReceiver extends BroadcastReceiver {
    private WifiAwareManager wifiAwareManager;

    public WiFiAwareBroadcastReceiver(WifiAwareManager wifiAwareManager) {
        this.wifiAwareManager = wifiAwareManager;
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        if (wifiAwareManager.isAvailable()) {
            Log.d("WiFiAwareManager", "WiFi Aware is available");
        } else {
            Log.d("WiFiAwareManager", "WiFi Aware is not available");
        }
    }
}