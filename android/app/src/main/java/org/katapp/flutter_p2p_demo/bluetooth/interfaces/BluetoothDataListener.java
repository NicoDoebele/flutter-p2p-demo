package org.katapp.flutter_p2p_demo.bluetooth.interfaces;

import java.util.List;

public interface BluetoothDataListener {
    void onDataListUpdated(List<String> dataList);
}