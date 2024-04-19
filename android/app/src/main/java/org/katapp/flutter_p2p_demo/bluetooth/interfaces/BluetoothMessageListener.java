package org.katapp.flutter_p2p_demo.bluetooth.interfaces;

import java.util.List;

import org.katapp.flutter_p2p_demo.message.Message;

public interface BluetoothMessageListener {
    void onMessageListUpdated(String messageList);
}