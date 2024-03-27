package org.katapp.flutter_p2p_demo;

import android.content.BroadcastReceiver;
import android.content.Context;
import org.katapp.flutter_p2p_demo.WiFiDirectManager;
import android.content.Intent;
import android.net.wifi.p2p.WifiP2pManager;
import android.net.wifi.p2p.WifiP2pManager.Channel;
import android.util.Log;
import android.net.wifi.p2p.WifiP2pDevice;
import java.util.List;
import java.util.ArrayList;
import java.util.Collection;
import android.net.wifi.p2p.WifiP2pDeviceList;
import android.net.wifi.p2p.WifiP2pManager.PeerListListener;

/**
 * A BroadcastReceiver that notifies of important Wi-Fi p2p events.
 */
public class WiFiDirectBroadcastReceiver extends BroadcastReceiver {

    PeerListListener myPeerListListener;
    private WifiP2pManager manager;
    private Channel channel;
    private WiFiDirectManager wifiManager;
    private PeerListListener peerListListener;

    public WiFiDirectBroadcastReceiver(WifiP2pManager manager, Channel channel,
            WiFiDirectManager wifiManager, PeerListListener peerListListener) {
        super();
        this.manager = manager;
        this.channel = channel;
        this.wifiManager = wifiManager;
        this.myPeerListListener = peerListListener;
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();

        if (WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION.equals(action)) {
            // Check to see if Wi-Fi is enabled and notify appropriate activity

            int state = intent.getIntExtra(WifiP2pManager.EXTRA_WIFI_STATE, -1);
            if (state == WifiP2pManager.WIFI_P2P_STATE_ENABLED) {
                // Wifi P2P is enabled
                Log.d("WiFiDirectActivity", "WiFi P2P is enabled");
            } else {
                // Wi-Fi P2P is not enabled
                Log.d("WiFiDirectActivity", "WiFi P2P is not enabled");
            }

        } else if (WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION.equals(action)) {
            // Call WifiP2pManager.requestPeers() to get a list of current peers

            if (manager != null) {
                manager.requestPeers(channel, myPeerListListener);
            }

        } else if (WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION.equals(action)) {
            // Respond to new connection or disconnections
        } else if (WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION.equals(action)) {
            // Respond to this device's wifi state changing
        }
    }
}
