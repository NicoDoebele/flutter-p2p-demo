package org.katapp.flutter_p2p_demo;

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

public class WiFiAwareManager {
    private Context context;
    private WifiAwareManager wifiAwareManager;
    private IntentFilter filter;
    private WiFiAwareBroadcastReceiver receiver;
    private WifiAwareSession session;

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

    public void init() {
        if (!isAvailable()) {
            Log.d("WiFiAwareManager", "WiFi Aware is not available");
            return;
        }

        wifiAwareManager = (WifiAwareManager) context.getSystemService(Context.WIFI_AWARE_SERVICE);
        filter = new IntentFilter(WifiAwareManager.ACTION_WIFI_AWARE_STATE_CHANGED);
        receiver = new WiFiAwareBroadcastReceiver(wifiAwareManager);

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

    private void startPublishing() {
        if (session == null) {
            return;
        }

        session.publish(publishConfig, new DiscoverySessionCallback() {
            @Override
            public void onPublishStarted(PublishDiscoverySession session) {
                Log.d("WiFiAwareManager", "WiFi Aware publish started");
            }

            @Override
            public void onMessageReceived(PeerHandle peerHandle, byte[] message) {
                Log.d("WiFiAwareManager", "WiFi Aware message received");
            }
        }, null);
    }

    private void startSubscribing() {
        if (session == null) {
            return;
        }

        session.subscribe(subscribeConfig, new DiscoverySessionCallback() {
            @Override
            public void onSubscribeStarted(SubscribeDiscoverySession session) {
                Log.d("WiFiAwareManager", "WiFi Aware subscribe started");
            }

            @Override
            public void onServiceDiscovered(PeerHandle peerHandle,
                    byte[] serviceSpecificInfo, List<byte[]> matchFilter) {
                Log.d("WiFiAwareManager", "WiFi Aware service discovered");
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