package org.katapp.flutter_p2p_demo.message;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.Date;
import java.util.UUID;

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

    public JSONObject toJson() {
        JSONObject jsonObject = new JSONObject();
        try {
            jsonObject.put("id", id);
            jsonObject.put("sender", sender);
            jsonObject.put("timeSent", timeSent.getTime());
            jsonObject.put("timeReceived", timeReceived == null ? JSONObject.NULL : timeReceived.getTime());
            jsonObject.put("dataToAchieveMessageSize", dataToAchieveMessageSize);
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
