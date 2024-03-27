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
import android.net.wifi.p2p.WifiP2pManager.ActionListener;
import android.net.wifi.p2p.nsd.WifiP2pDnsSdServiceRequest;

public class WiFiDirectManager {
    WifiP2pManager manager;
    Channel channel;
    BroadcastReceiver receiver;
    IntentFilter intentFilter;
    Context context;
    WifiP2pDnsSdServiceRequest serviceRequest;

    private List<WifiP2pDevice> peers = new ArrayList<>();
    private final Map<String, WifiP2pDevice> deviceMap = new HashMap<>();

    public WiFiDirectManager(Context context) {
        this.context = context;
    }

    public void init(Bundle savedInstanceState) {
        manager = (WifiP2pManager) context.getSystemService(Context.WIFI_P2P_SERVICE);
        channel = manager.initialize(context, Looper.getMainLooper(), null);

        registerService();
        setupServiceDiscovery();

        intentFilter = new IntentFilter();
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION);
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION);
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION);
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION);
        receiver = new WiFiDirectBroadcastReceiver(manager, channel, this, peerListListener);

        context.registerReceiver(receiver, intentFilter);

        Log.d("WiFiDirectActivity", "WiFi Direct initialized");
    }

    private void registerService() {
        Map<String, String> record = new HashMap();
        record.put("listeningPort", "8888");
        WifiP2pDnsSdServiceInfo serviceInfo = WifiP2pDnsSdServiceInfo.newInstance(
                "_katappwifidirectservice", "_presence._tcp", record);

        manager.addLocalService(channel, serviceInfo, new ActionListener() {
            @Override
            public void onSuccess() {
                Log.d("WiFiDirectActivity", "Local Service Added");
            }

            @Override
            public void onFailure(int reason) {
                Log.d("WiFiDirectActivity", "Failed to add a service");
            }
        });

        serviceRequest = WifiP2pDnsSdServiceRequest.newInstance();
        manager.addServiceRequest(channel,
                serviceRequest,
                new ActionListener() {
                    @Override
                    public void onSuccess() {
                        Log.d("WiFiDirectActivity", "Added service discovery request");
                    }

                    @Override
                    public void onFailure(int code) {
                        Log.d("WiFiDirectActivity", "Failed adding service discovery request");
                    }
                });
    }

    private void setupServiceDiscovery() {
        DnsSdTxtRecordListener txtListener = new DnsSdTxtRecordListener() {
            @Override
            public void onDnsSdTxtRecordAvailable(
                    String fullDomainName, Map<String, String> record, WifiP2pDevice device) {
                Log.d("WiFiDirectActivity", "DnsSdTxtRecord available -" + record.toString());
                if ("_katapp._tcp".equals(fullDomainName)) {
                    deviceMap.put(device.deviceAddress, device);
                }
            }
        };

        DnsSdServiceResponseListener servListener = new DnsSdServiceResponseListener() {
            @Override
            public void onDnsSdServiceAvailable(String instanceName, String registrationType,
                    WifiP2pDevice device) {
                if (instanceName.equalsIgnoreCase("_katappwifidirectservice")) {
                    deviceMap.put(device.deviceAddress, device);
                    if (!peers.contains(device))
                        peers.add(device); // if Service is found later than peer add manually
                    Log.d("WiFiDirectActivity", "Service discovery success, added peer: " + device.deviceName);
                }
            }
        };

        manager.setDnsSdResponseListeners(channel, servListener, txtListener);
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
                discoverServices();
            }

            @Override
            public void onFailure(int reasonCode) {
                Log.d("WiFiDirectActivity", "Discover peers failure " + reasonCode);
            }
        });
    }

    public void discoverServices() {
        // manager.setDnsSdResponseListeners(channel, servListener, txtListener);
        // manager.setDnsSdTxtRecordListener(channel, txtListener);
        manager.discoverServices(channel, new WifiP2pManager.ActionListener() {
            @Override
            public void onSuccess() {
                Log.d("WiFiDirectActivity", "Service discovery success");
            }

            @Override
            public void onFailure(int code) {
                Log.d("WiFiDirectActivity", "Service discovery failure " + code);
            }
        });
    }

    private PeerListListener peerListListener = new PeerListListener() {
        @Override
        public void onPeersAvailable(WifiP2pDeviceList peerList) {
            Collection<WifiP2pDevice> refreshedPeers = peerList.getDeviceList();
            // Filter peers to include only those that offer the same service
            List<WifiP2pDevice> filteredPeers = new ArrayList<>();
            for (WifiP2pDevice device : refreshedPeers) {
                if (deviceMap.containsKey(device.deviceAddress)) {
                    filteredPeers.add(device);
                }
            }

            if (!filteredPeers.equals(peers)) {
                peers.clear();
                peers.addAll(filteredPeers);

                Log.d("WiFiDirectActivity",
                        "Filtered peer list changed. Amount of peers offering the service: " + filteredPeers.size());

                // Log every peer that offers the service
                for (WifiP2pDevice peer : filteredPeers) {
                    Log.d("WiFiDirectActivity", "Service Peer: " + peer.deviceName + " " + peer.deviceAddress);
                }
            }

            if (peers.size() == 0) {
                Log.d("WiFiDirectActivity", "No service devices found");
            }
        }
    };
}
