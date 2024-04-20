import 'dart:convert';
import 'dart:ffi';

import 'package:flutter_p2p_demo/classes/location.dart';

class Message {
  int id;
  String sender;
  DateTime? timeSent;
  DateTime? timeReceived;
  String? dataToAchieveMessageSize;
  Location? sentLocation;
  Location? receivedLocation;
  double? distanceBetweenLocations;


  Message({
    required this.id,
    required this.sender,
    this.timeSent,
    this.timeReceived,
    this.dataToAchieveMessageSize,
    this.sentLocation,
    this.receivedLocation,
    this.distanceBetweenLocations,
  });

  // Convert a Map into an instance of Message
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      sender: json['sender'] as String,
      timeSent: json['timeSent'] != null ? DateTime.fromMillisecondsSinceEpoch(json['timeSent'] as int) : null,
      timeReceived: json['timeReceived'] != null ? DateTime.fromMillisecondsSinceEpoch(json['timeReceived'] as int) : null,
      dataToAchieveMessageSize: json['dataToAchieveMessageSize'] as String?,
      sentLocation: json['sentLocation'] != null ? Location.fromJson(json['sentLocation'] as Map<String, dynamic>) : null,
      receivedLocation: json['receivedLocation'] != null ? Location.fromJson(json['receivedLocation'] as Map<String, dynamic>) : null,
      distanceBetweenLocations: (json['distanceBetweenLocations'] != null) ? json['distanceBetweenLocations'].toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'timeSent': timeSent?.millisecondsSinceEpoch,
      'timeReceived': timeReceived?.millisecondsSinceEpoch,
      'dataToAchieveMessageSize': dataToAchieveMessageSize,
      'sentLocation': sentLocation?.toJson(),
      'receivedLocation': receivedLocation?.toJson(),
      'distanceBetweenLocations': distanceBetweenLocations,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Message &&
      other.id == id &&
      other.sender == sender;
  }

  @override
  int get hashCode => id.hashCode ^ sender.hashCode;

  @override
  String toString() {
    return 'Message(id: $id, sender: $sender, timeSent: $timeSent, timeReceived: $timeReceived, dataToAchieveMessageSize: $dataToAchieveMessageSize, sentLocation: $sentLocation, receivedLocation: $receivedLocation, distanceBetweenLocations: $distanceBetweenLocations)';
  }
}
