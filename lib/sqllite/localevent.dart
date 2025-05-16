import 'package:cloud_firestore/cloud_firestore.dart';

class LocalEvent {
  final String id;
  final String title;
  final DateTime date;
  final String description;
  final Map<String, int> userReminders;
  final String creatorId;
  final String? firestoreId; // ✅ Add this line

  LocalEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.creatorId,
    this.description = '',
    this.userReminders = const {},
    this.firestoreId, // ✅ Add this here
  });


  Map<String, dynamic> toMap({bool forFirestore = false}) {
    final base = {
      'id': id,
      'title': title,
      'creatorId': creatorId,
      'dateTime': forFirestore
          ? Timestamp.fromMillisecondsSinceEpoch(date.millisecondsSinceEpoch)
          : date.millisecondsSinceEpoch,
      'description': description,
      'reminders': userReminders.entries
          .map((e) => {'userId': e.key, 'offset': e.value})
          .toList(),
    };
    if (forFirestore) {
      base.addAll({
        'creator': creatorId,
        'rsvps': [],
        'user_reminders': userReminders,
      });
    } else if (firestoreId != null) {
      base['firestoreId'] = firestoreId ?? '';

    }
    return base;
  }


  factory LocalEvent.fromMap(Map<String, dynamic> m) {
    final rawDate = m['dateTime'];
    DateTime parsed;
    if (rawDate is Timestamp) {
      parsed = rawDate.toDate();
    } else if (rawDate is int) {
      parsed = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else {
      parsed = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    }

    final remList = m['reminders'] as List<dynamic>? ?? [];
    final remMap = <String, int>{};
    for (var e in remList) {
      if (e is Map && e.containsKey('userId') && e.containsKey('offset')) {
        remMap[e['userId'].toString()] = int.tryParse(e['offset'].toString()) ?? 0;
      }
    }

    return LocalEvent(
      id: m['id'] as String,
      title: m['title'] as String,
      date: parsed,
      creatorId: m['creatorId'] as String? ?? '',
      description: m['description'] as String? ?? '',
      userReminders: remMap,
      firestoreId: m['firestoreId'] as String?, // ✅ Add this line
    );

  }
}
