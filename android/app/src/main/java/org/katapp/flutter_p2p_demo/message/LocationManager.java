package org.katapp.flutter_p2p_demo.message;

import java.util.concurrent.CountDownLatch;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.tasks.OnSuccessListener;
import android.location.Location;
import org.json.JSONObject;

public class LocationManager {
    private static Location currentLocation;
    private static FusedLocationProviderClient fusedLocationClient;

    public static void setFusedLocationClient(FusedLocationProviderClient newFusedLocationClient) {
        fusedLocationClient = newFusedLocationClient;
    }

    public static Location getCurrentLocation() throws InterruptedException {
        final CountDownLatch latch = new CountDownLatch(1);

        fusedLocationClient.getCurrentLocation(LocationRequest.PRIORITY_HIGH_ACCURACY, null)
            .addOnSuccessListener(new OnSuccessListener<Location>() {
                @Override
                public void onSuccess(Location location) {
                    if (location != null) {
                        currentLocation = location;
                    }
                    latch.countDown();  // Notify that the location has been fetched
                }
            });

        latch.await();  // Wait here until the onSuccess callback is called
        return currentLocation;  // Return the fetched location
    }

    public static Location getLastKnownLocation() throws InterruptedException {
        final CountDownLatch latch = new CountDownLatch(1);

        fusedLocationClient.getLastLocation()
            .addOnSuccessListener(new OnSuccessListener<Location>() {
                @Override
                public void onSuccess(Location location) {
                    if (location != null) {
                        currentLocation = location;
                    }
                    latch.countDown();  // Notify that the location has been fetched
                }
            });

        latch.await();  // Wait here until the onSuccess callback is called
        return currentLocation;  // Return the fetched location
    }

    public static float distanceBetweenLocations(Location location1, Location location2) {
        return location1.distanceTo(location2);
    }
}