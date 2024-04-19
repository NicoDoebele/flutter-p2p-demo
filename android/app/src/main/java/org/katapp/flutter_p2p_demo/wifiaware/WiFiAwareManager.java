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

import org.katapp.flutter_p2p_demo.wifidirect.interfaces.WiFiAwareConnectionInfoListener;

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
    int port;

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
        if (session != null) {
            session.close();
            session = null;
        }

        if (publishSession != null) {
            publishSession.close();
            publishSession = null;
        }

        if (subscribeSession != null) {
            subscribeSession.close();
            subscribeSession = null;
        }

        if (network != null) {
            connectivityManager.unregisterNetworkCallback(networkCallback);
            network = null;
        }

        context.unregisterReceiver(receiver);

        wifiAwareManager = null;
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

    private void sendInfoToDart() {

        if (networkCapabilities == null) {
            return;
        }

        WifiAwareNetworkInfo peerAwareInfo = (WifiAwareNetworkInfo) networkCapabilities.getTransportInfo();
        Inet6Address peerIpv6 = peerAwareInfo.getPeerIpv6Addr();
        int peerPort = peerAwareInfo.getPort();

        mainHandler.post(() -> {
            if (connectionInfoListener != null) {
                connectionInfoListener.onConnectionInfoAvailable(peerIpv6.toString(), port);
            }
        });
    }

    private void createSocket() {
        try {
            serverSocket = new ServerSocket(0);
            port = serverSocket.getLocalPort();
        } catch (Exception e) {
            Log.d("WiFiAwareManager", "Error creating server socket");
        }
    }

    private void requestNetwork(PublishDiscoverySession publishSession, SubscribeDiscoverySession subscribeSession, PeerHandle peerHandle) {
        NetworkSpecifier networkSpecifier;

        if (publishSession != null) {
            createSocket();

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
                sendInfoToDart();
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
                sendInfoToDart();
            }

            @Override
            public void onLost(Network network) {
                Log.d("WiFiAwareManager", "WiFi Aware network lost");
                network = null;
                networkCapabilities = null;
                sendInfoToDart();
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