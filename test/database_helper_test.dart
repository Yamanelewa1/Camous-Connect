import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:campusconnect/sqllite/databasehelper.dart';
import 'package:campusconnect/sqllite/localevent.dart';
import 'package:campusconnect/sqllite/localstudygroup.dart';
import 'package:campusconnect/sqllite/localclass.dart';

void main() {
  // ✅ Initialize the FFI for VM testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbHelper = DatabaseHelper.instance;

  group('SQLite DatabaseHelper Tests', () {
    // EVENTS
    test('Insert and fetch LocalEvent', () async {
      final event = LocalEvent(
        id: 'event_test',
        title: 'Test Event',
        description: 'Description',
        date: DateTime.now(),
        creatorId: 'user123',
        userReminders: {'user123': 5},
      );

      await dbHelper.insertEvent(event);
      final events = await dbHelper.fetchEvents();
      expect(events.any((e) => e.id == 'event_test'), true);
    });

    test('Update LocalEvent', () async {
      final updated = LocalEvent(
        id: 'event_test',
        title: 'Updated Title',
        description: 'Updated Desc',
        date: DateTime.now(),
        creatorId: 'user123',
        userReminders: {'user123': 10},
      );

      await dbHelper.updateEvent(updated);
      final events = await dbHelper.fetchEvents();
      expect(events.firstWhere((e) => e.id == 'event_test').title, 'Updated Title');
    });

    test('Delete LocalEvent', () async {
      await dbHelper.deleteEvent('event_test');
      final events = await dbHelper.fetchEvents();
      expect(events.any((e) => e.id == 'event_test'), false);
    });

    // STUDY GROUPS
    test('Insert and fetch LocalStudyGroup', () async {
      final group = LocalStudyGroup(
        id: 'group_test',
        topic: 'Test Topic',
        sessionTime: DateTime(2025, 5, 16, 12, 0),
        createdAt: DateTime.parse('2025-05-16'),
        creatorId: 'user456',
        rsvps: ['user456'],
        synced: false,
        classId: 'class1',
        firestoreId: null,
      );

      await dbHelper.insertStudyGroup(group);
      final groups = await dbHelper.fetchStudyGroups();
      expect(groups.any((g) => g.id == 'group_test'), true);
    });

    test('Mark Study Group as Synced', () async {
      await dbHelper.markStudyGroupAsSynced('group_test');
      final groups = await dbHelper.fetchStudyGroups();
      final syncedGroup = groups.firstWhere((g) => g.id == 'group_test');
      expect(syncedGroup.synced, true);
    });

    test('Delete Study Group by Firestore ID', () async {
      final groupWithFSID = LocalStudyGroup(
        id: 'group_test',
        topic: 'Test Topic',
        sessionTime: DateTime(2025, 5, 16, 12, 0),
        createdAt: DateTime.parse('2025-05-16'),
        creatorId: 'user456',
        rsvps: ['user456'],
        synced: true,
        classId: 'class1',
        firestoreId: 'fs123',
      );

      await dbHelper.updateStudyGroup(groupWithFSID);
      await dbHelper.deleteStudyGroupByFirestoreId('fs123');
      final groups = await dbHelper.fetchStudyGroups();
      expect(groups.any((g) => g.firestoreId == 'fs123'), false);
    });

    // LOCAL CLASSES
    test('Insert and fetch LocalClass for user', () async {
      final localClass = LocalClass(
        id: 'class_test',
        name: 'Test Class',
        professor: 'Prof X',
        room: '101',
        materials: '[]',
        schedule: '{}',
        userId: 'user789',
      );

      await dbHelper.insertClass(localClass);
      final classes = await dbHelper.fetchUserClasses('user789');
      expect(classes.any((c) => c.id == 'class_test'), true);
    });

    test('Delete assigned class only for user', () async {
      await dbHelper.deleteAssignedClassOnly('user789', 'class_test');
      final classes = await dbHelper.fetchUserClasses('user789');
      expect(classes.any((c) => c.id == 'class_test'), false);
    });
  });
}
