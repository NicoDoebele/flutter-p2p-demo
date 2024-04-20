package org.katapp.flutter_p2p_demo.message;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.Date;
import java.util.UUID;

import android.location.Location;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.tasks.OnSuccessListener;
import android.util.Log;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;

import org.katapp.flutter_p2p_demo.message.LocationManager;

public class Message {
    // For this prototype, we can check for message duplicates by combinding the message id and sender
    private static int idCounter = 0;
    private int id;
    // Create a unique sender name for this android device
    private static final String senderRandom = UUID.randomUUID().toString().split("-")[0];
    private String sender = android.os.Build.MODEL + " :: " + senderRandom;

    // The time the message was sent and received is used to determine the time it took to transfer the message
    private Date timeSent;
    private Date timeReceived;

    // This is used to achieve a certain message size for transfer speed testing
    // After the message is received, the receiver will check the size of the total JSON String received and assume each character is 1 byte
    private String dataToAchieveMessageSize;

    // Used to calculate the distance between the sender and receiver
    private Location sentLocation;
    private Location receivedLocation;

    private float distanceBetweenLocations;

    public Message(int size) {
        this.id = idCounter++;

        // create a string of size 'size' to achieve the desired message size for transfer speed testing
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < size; i++) {
            sb.append("a");
        }
        dataToAchieveMessageSize = sb.toString();
    }

    public Message(String json) {
        try {
            JSONObject jsonObject = new JSONObject(json);
            this.id = jsonObject.getInt("id");
            this.sender = jsonObject.getString("sender");
            this.timeSent = new Date(jsonObject.getLong("timeSent"));
            if (!jsonObject.isNull("timeReceived")) {
                this.timeReceived = new Date(jsonObject.getLong("timeReceived"));
            }
            this.dataToAchieveMessageSize = jsonObject.getString("dataToAchieveMessageSize");
            if (!jsonObject.isNull("sentLocation")) {
                JSONObject sentLocationJson = jsonObject.getJSONObject("sentLocation");
                this.sentLocation = new Location("");
                this.sentLocation.setLatitude(sentLocationJson.getDouble("latitude"));
                this.sentLocation.setLongitude(sentLocationJson.getDouble("longitude"));
            }
            if (!jsonObject.isNull("receivedLocation")) {
                JSONObject receivedLocationJson = jsonObject.getJSONObject("receivedLocation");
                this.receivedLocation = new Location("");
                this.receivedLocation.setLatitude(receivedLocationJson.getDouble("latitude"));
                this.receivedLocation.setLongitude(receivedLocationJson.getDouble("longitude"));
            }
            this.distanceBetweenLocations = (float) jsonObject.getDouble("distanceBetweenLocations");
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    public int getId() {
        return id;
    }

    public String getSender() {
        return sender;
    }

    public Date getTimeSent() {
        return timeSent;
    }

    public void setTimeSentAsCurrent() {
        this.timeSent = new Date();
    }

    public Date getTimeReceived() {
        return timeReceived;
    }

    public void setTimeReceivedAsCurrent() {
        this.timeReceived = new Date();
    }

    public Location getSentLocation() {
        return sentLocation;
    }

    public Location getReceivedLocation() {
        return receivedLocation;
    }

    public void setSentLocationAsCurrent() {
        try {
            sentLocation = LocationManager.getCurrentLocation();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

    public void setReceivedLocationAsCurrent() {
        try {
            receivedLocation = LocationManager.getCurrentLocation();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }

        if (sentLocation != null && receivedLocation != null) {
            distanceBetweenLocations = LocationManager.distanceBetweenLocations(sentLocation, receivedLocation);
        }
    }

    public JSONObject toJson() {
        JSONObject jsonObject = new JSONObject();
        try {
            jsonObject.put("id", id);
            jsonObject.put("sender", sender);
            jsonObject.put("timeSent", timeSent.getTime());
            jsonObject.put("timeReceived", timeReceived == null ? JSONObject.NULL : timeReceived.getTime());
            jsonObject.put("dataToAchieveMessageSize", dataToAchieveMessageSize);
            jsonObject.put("sentLocation", sentLocation == null ? JSONObject.NULL : new JSONObject()
                .put("latitude", sentLocation.getLatitude())
                .put("longitude", sentLocation.getLongitude()));
            jsonObject.put("receivedLocation", receivedLocation == null ? JSONObject.NULL : new JSONObject()
                .put("latitude", receivedLocation.getLatitude())
                .put("longitude", receivedLocation.getLongitude()));
            jsonObject.put("distanceBetweenLocations", distanceBetweenLocations);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        return jsonObject;
    }

    // equals using id and sender
    @Override
    public boolean equals(Object obj) {
        if (obj instanceof Message) {
            Message other = (Message) obj;
            return this.id == other.id && this.sender.equals(other.sender);
        }
        return false;
    }
}
