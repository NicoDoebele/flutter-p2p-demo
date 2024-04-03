package org.katapp.flutter_p2p_demo.wifidirect.interfaces;

import android.net.wifi.p2p.WifiP2pInfo;

public interface WiFiP2PConnectionInfoListener {
    void onConnectionInfoAvailable(WifiP2pInfo info);
}