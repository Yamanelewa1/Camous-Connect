class LocalStudyGroup {
  final String id;
  final String topic;
  final DateTime sessionTime;
  final DateTime createdAt;
  final String creatorId;
  final List<String> rsvps;
  final bool synced;
  final String? classId;
  final String? firestoreId; // ✅ Added field

  LocalStudyGroup({
    required this.id,
    required this.topic,
    required this.sessionTime,
    required this.createdAt,
    required this.creatorId,
    required this.rsvps,
    this.synced = false,
    this.classId,
    this.firestoreId,
  });

  /// Convert to local SQLite map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'topic': topic,
      'session_time': sessionTime.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'creator_id': creatorId,
      'rsvps': rsvps.join(','), // stored as CSV in SQLite
      'synced': synced ? 1 : 0,
      'class_id': classId,
      'firestore_id': firestoreId, // ✅ new field
    };
  }

  /// Convert to Firestore upload format
  Map<String, dynamic> toFirestoreMap() {
    return {
      'topic': topic,
      'session_time': sessionTime.toIso8601String(),
      'timestamp': createdAt.toIso8601String(),
      'creator': creatorId,
      'rsvps': rsvps,
      'class_id': classId,
    };
  }

  /// Recreate object from SQLite map
  factory LocalStudyGroup.fromMap(Map<String, dynamic> map) {
    return LocalStudyGroup(
      id: map['id'],
      topic: map['topic'],
      sessionTime: DateTime.parse(map['session_time']),
      createdAt: DateTime.parse(map['created_at']),
      creatorId: map['creator_id'],
      rsvps: map['rsvps'] == null || map['rsvps'].toString().isEmpty
          ? []
          : map['rsvps'].toString().split(','),
      synced: map['synced'] == 1,
      classId: map['class_id'],
      firestoreId: map['firestore_id'], // ✅ new field
    );
  }
}
