package org.katapp.flutter_p2p_demo.wifidirect.interfaces;

public interface WiFiAwareConnectionInfoListener {
    void onConnectionInfoAvailable(String peerIpv6, int port);
}