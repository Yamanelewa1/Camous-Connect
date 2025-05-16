class LocalClass {
  final String id;
  final String name;
  final String professor;
  final String room;
  final String materials;
  final String schedule;
  final String userId; // to associate with the current user

  LocalClass({
    required this.id,
    required this.name,
    required this.professor,
    required this.room,
    required this.materials,
    required this.schedule,
    required this.userId,
  });

  factory LocalClass.fromMap(Map<String, dynamic> map) {
    return LocalClass(
      id: map['id'],
      name: map['name'],
      professor: map['professor'],
      room: map['room'],
      materials: map['materials'],
      schedule: map['schedule'],
      userId: map['userId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'professor': professor,
      'room': room,
      'materials': materials,
      'schedule': schedule,
      'userId': userId,
    };
  }
}
