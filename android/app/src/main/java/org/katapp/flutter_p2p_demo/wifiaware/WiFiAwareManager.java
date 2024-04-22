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
import java.nio.charset.StandardCharsets;
import java.net.InetAddress;
import java.util.Iterator;

import org.katapp.flutter_p2p_demo.wifidirect.interfaces.WiFiAwareConnectionInfoListener;
import org.katapp.flutter_p2p_demo.wifidirect.interfaces.WiFiAwareMessageListener;
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
    private WiFiAwareMessageListener messageListener;

    private Handler mainHandler = new Handler(Looper.getMainLooper());

    private ServerSocket serverSocket;
    private List<Socket> subscribers = new ArrayList<>();
    int port = 8888;
    private Thread serverThread;

    private List<Socket> clientSockets = new ArrayList<>();
    private List<Thread> clientThreads = new ArrayList<>();

    // keep track of ipv6 addresses of servers connected to
    private final List<Inet6Address> serverAddresses = new ArrayList<>();

    private String priorData = "";

    public void setConnectionInfoListener(WiFiAwareConnectionInfoListener connectionInfoListener) {
        this.connectionInfoListener = connectionInfoListener;
    }

    public void setMessageListener(WiFiAwareMessageListener messageListener) {
        this.messageListener = messageListener;
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
        messageListener = null;

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
            serverSocket = new ServerSocket(port);
            //port = serverSocket.getLocalPort();
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
            Iterator<Socket> iterator = subscribers.iterator();
            while (iterator.hasNext()) {
                Socket subscriber = iterator.next();
                try {
                    OutputStream out = subscriber.getOutputStream();
                    out.write(data);
                    out.flush();
                } catch (IOException e) {
                    System.err.println("Error sending data to client: " + subscriber.getInetAddress());
                    e.printStackTrace();
        
                    try {
                        subscriber.close();
                    } catch (IOException e2) {
                        System.err.println("Error closing client socket");
                        e2.printStackTrace();
                    }
        
                    iterator.remove(); // Safe removal during iteration
        
                    System.out.println("Subscriber disconnected: " + subscriber.getInetAddress());
                }
            }
        }
    }

    private void connectToServer() {
        WifiAwareNetworkInfo peerAwareInfo = (WifiAwareNetworkInfo) networkCapabilities.getTransportInfo();
        Inet6Address peerIpv6 = peerAwareInfo.getPeerIpv6Addr();
        //int peerPort = peerAwareInfo.getPort();
        int peerPort = port;

        Log.d("WiFiAwareManager", "Connecting to server " + peerIpv6 + " on port " + peerPort);

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
                        partialMessage.append(new String(data, 0, bytesRead, StandardCharsets.UTF_8)); // Specify charset
                        processMessages(partialMessage);
                    }
                } catch (IOException e) {
                    Log.e("WiFiAwareManager", "Error reading from server", e);
                } finally {
                    try {
                        socket.close();
                    } catch (IOException e) {
                        Log.e("WiFiAwareManager", "Error closing socket", e);
                    }
                }
            });

            socketThread.start();
            clientThreads.add(socketThread);
        } catch (IOException e) {
            Log.d("WiFiAwareManager", "Error connecting to server", e);
        }
    }

    private void processMessages(StringBuilder partialMessage) {
        int lastIndex = 0;
        int depth = 0; // Depth counter for nested JSON
        boolean inString = false; // Track whether currently inside a string

        for (int i = 0; i < partialMessage.length(); i++) {
            char c = partialMessage.charAt(i);

            if (c == '"' && (i == 0 || partialMessage.charAt(i - 1) != '\\')) {
                inString = !inString;
            }

            if (!inString) {
                if (c == '{' || c == '[') {
                    depth++;
                } else if (c == '}' || c == ']') {
                    depth--;
                }
            }

            if ((c == '}' || c == ']') && depth == 0 && !inString) {
                String subStr = partialMessage.substring(lastIndex, i + 1);
                try {
                    JSONObject messageJSON = new JSONObject(subStr);
                    Message messageObject = new Message(messageJSON.toString());

                    new Thread(() -> sendMessageToDart(messageObject)).start();

                    lastIndex = i + 1;
                } catch (JSONException e) {
                    Log.e("WiFiAwareManager", "Malformed JSON", e);
                    continue;
                }
            }
        }

        partialMessage.delete(0, lastIndex);
    }

    private void sendMessageToDart(Message message) {
        message.setTimeReceivedAsCurrent();
        //message.setReceivedLocationAsCurrent();
        
        mainHandler.post(() -> {
            if (messageListener != null) {
                messageListener.onMessageReceived(message.toJson().toString());
            }
        });
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
                .setPort(port)
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

                synchronized (clientSockets) {
                    // close client connections and threads and open new
                    for (Socket clientSocket : clientSockets) {
                        try {
                            clientSocket.close();
                        } catch (IOException e) {
                            Log.e("WiFiAwareManager", "Error closing client socket", e);
                        }
                    }

                    for (Thread clientThread : clientThreads) {
                        clientThread.interrupt();
                    }

                    clientSockets.clear();
                }

                mainHandler.post(() -> {
                    if (connectionInfoListener != null) {
                        connectionInfoListener.onConnectionChange(true);
                    }
                });

                connectToServer();
            }

            @Override
            public void onLost(Network network) {
                Log.d("WiFiAwareManager", "WiFi Aware network lost");
                // network = null;
                // networkCapabilities = null;

                mainHandler.post(() -> {
                    if (connectionInfoListener != null) {
                        connectionInfoListener.onConnectionChange(false);
                    }
                });
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