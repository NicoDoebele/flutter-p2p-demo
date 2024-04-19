import 'dart:convert';

class Message {
  int id;
  String sender;
  DateTime? timeSent;
  DateTime? timeReceived;
  String? dataToAchieveMessageSize;

  Message({
    required this.id,
    required this.sender,
    this.timeSent,
    this.timeReceived,
    this.dataToAchieveMessageSize,
  });

  // Convert a Map into an instance of Message
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      sender: json['sender'] as String,
      timeSent: json['timeSent'] != null ? DateTime.fromMillisecondsSinceEpoch(json['timeSent'] as int) : null,
      timeReceived: json['timeReceived'] != null ? DateTime.fromMillisecondsSinceEpoch(json['timeReceived'] as int) : null,
      dataToAchieveMessageSize: json['dataToAchieveMessageSize'] as String?,
    );
  }

  // Convert an instance of Message to a JSON string
  String toJson() {
    final Map<String, dynamic> json = {
      'id': id,
      'sender': sender,
      'timeSent': timeSent?.millisecondsSinceEpoch,
      'timeReceived': timeReceived?.millisecondsSinceEpoch,
      'dataToAchieveMessageSize': dataToAchieveMessageSize,
    };
    return jsonEncode(json);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Message &&
      other.id == id &&
      other.sender == sender &&
      other.timeSent == timeSent &&
      other.timeReceived == timeReceived &&
      other.dataToAchieveMessageSize == dataToAchieveMessageSize;
  }

  @override
  int get hashCode => id.hashCode ^ sender.hashCode ^ timeSent.hashCode ^ timeReceived.hashCode ^ (dataToAchieveMessageSize?.hashCode ?? 0);

  @override
  String toString() {
    return 'Message(id: $id, sender: $sender, timeSent: $timeSent, timeReceived: $timeReceived, dataToAchieveMessageSize: $dataToAchieveMessageSize)';
  }
}
