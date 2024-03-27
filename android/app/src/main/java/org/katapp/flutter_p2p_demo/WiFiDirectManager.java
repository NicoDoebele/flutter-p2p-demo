package org.katapp.flutter_p2p_demo;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.net.wifi.p2p.WifiP2pManager;
import android.net.wifi.p2p.WifiP2pManager.Channel;
import org.katapp.flutter_p2p_demo.WiFiDirectBroadcastReceiver;
import android.content.IntentFilter;
import android.os.Bundle;
import android.util.Log;
import android.content.Intent;
import android.os.Looper;
import android.net.wifi.p2p.WifiP2pDevice;
import java.util.ArrayList;
import java.util.List;
import java.util.Collection;
import java.util.Map;
import java.util.HashMap;
import android.net.wifi.p2p.WifiP2pDeviceList;
import android.net.wifi.p2p.WifiP2pManager.PeerListListener;
import android.net.wifi.p2p.WifiP2pManager.DnsSdServiceResponseListener;
import android.net.wifi.p2p.WifiP2pManager.DnsSdTxtRecordListener;
import android.net.wifi.p2p.nsd.WifiP2pDnsSdServiceInfo;

public class WiFiDirectManager {
    WifiP2pManager manager;
    Channel channel;
    BroadcastReceiver receiver;
    IntentFilter intentFilter;
    Context context;

    private List<WifiP2pDevice> peers = new ArrayList<>();

    public WiFiDirectManager(Context context) {
        this.context = context;
    }

    public void init(Bundle savedInstanceState) {
        manager = (WifiP2pManager) context.getSystemService(Context.WIFI_P2P_SERVICE);
        channel = manager.initialize(context, Looper.getMainLooper(), null);

        intentFilter = new IntentFilter();
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION);
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION);
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION);
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION);
        receiver = new WiFiDirectBroadcastReceiver(manager, channel, this, peerListListener);

        context.registerReceiver(receiver, intentFilter);

        Log.d("WiFiDirectActivity", "WiFi Direct initialized");
    }

    /* register the broadcast receiver with the intent values to be matched */
    public void resume() {
        context.registerReceiver(receiver, intentFilter);
    }

    /* unregister the broadcast receiver */
    public void pause() {
        context.unregisterReceiver(receiver);
    }

    public void discoverPeers() {
        manager.discoverPeers(channel, new WifiP2pManager.ActionListener() {
            @Override
            public void onSuccess() {
                Log.d("WiFiDirectActivity", "Discover peers success");
            }

            @Override
            public void onFailure(int reasonCode) {
                Log.d("WiFiDirectActivity", "Discover peers failure " + reasonCode);
            }
        });
    }

    private PeerListListener peerListListener = new PeerListListener() {
        @Override
        public void onPeersAvailable(WifiP2pDeviceList peerList) {
            Collection<WifiP2pDevice> refreshedPeers = peerList.getDeviceList();

            if (!refreshedPeers.equals(peers)) {
                peers.clear();
                peers.addAll(refreshedPeers);

                Log.d("WiFiDirectActivity",
                        "Peer list changed. Amount of peers: " + refreshedPeers.size());

                // Log every peer
                for (WifiP2pDevice peer : refreshedPeers) {
                    Log.d("WiFiDirectActivity", "Peer: " + peer.deviceName + " " + peer.deviceAddress);
                }
            }

            if (peers.size() == 0) {
                Log.d("WiFiDirectActivity", "No devices found");
            }
        }
    };

}
