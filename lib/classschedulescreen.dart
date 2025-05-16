import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'main.dart';

class ClassScheduleScreen extends StatefulWidget {
  @override
  _ClassScheduleScreenState createState() => _ClassScheduleScreenState();
}

class _ClassScheduleScreenState extends State<ClassScheduleScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String? _localZone;

  @override
  void initState() {
    super.initState();
    _initializeTimezone();
  }

  Future<void> _initializeTimezone() async {
    final localTimeZone = await FlutterTimezone.getLocalTimezone();
    tzData.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(localTimeZone));
    setState(() {
      _localZone = localTimeZone;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Class Schedule')),
        body: Center(child: Text('User not logged in')),
      );
    }

    final userClassRef = firestore.collection('users').doc(uid).collection('classes');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('📅 Class Schedule'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade700, Colors.blue.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: userClassRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

            final classList = snapshot.data!.docs;

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 100, 16, 16),
              separatorBuilder: (_, __) => SizedBox(height: 12),
              itemCount: classList.length,
              itemBuilder: (context, index) {
                final doc = classList[index];
                final classData = doc.data() as Map<String, dynamic>;
                classData['id'] = doc.id;
                final title = classData['name'] ?? 'Unnamed Class';
                final scheduleString = classData['schedule'] ?? '';
                final hasReminder = classData.containsKey('reminder_offset');

                return GestureDetector(
                  onLongPress: () => _cancelNotification(context, classData),
                  child: Card(
                    color: Colors.white.withOpacity(0.9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(title,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              ),
                              Icon(
                                hasReminder ? Icons.notifications_active : Icons.notifications_off,
                                color: hasReminder ? Colors.green : Colors.grey,
                              )
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(scheduleString, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                          SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _showClassDetails(context, classData),
                              child: Text('Manage Reminder'),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showClassDetails(BuildContext context, Map<String, dynamic> classItem) {
    int reminderOffsetMinutes = 5;
    final currentOffset = classItem['reminder_offset'];
    if (currentOffset is int) reminderOffsetMinutes = currentOffset;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(classItem['name'] ?? ''),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('👨‍🏫 Professor: ${classItem['professor'] ?? 'N/A'}'),
              Text('🏫 Room: ${classItem['room'] ?? 'N/A'}'),
              if (classItem['materials'] != null)
                Text('📚 Materials: ${classItem['materials']}'),
              SizedBox(height: 16),
              Text('⏰ Reminder Before Class:'),
              DropdownButton<int>(
                value: reminderOffsetMinutes,
                items: [5, 10, 15, 30, 60].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value minutes before'),
                  );
                }).toList(),
                onChanged: (newVal) {
                  if (newVal != null) {
                    setState(() {
                      reminderOffsetMinutes = newVal;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _scheduleNotification(context, classItem, reminderOffsetMinutes);
              },
              child: Text('Save Reminder'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _cancelNotification(context, classItem);
              },
              child: Text('Cancel Reminder'),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleNotification(BuildContext context, Map<String, dynamic> classItem, int? offsetMinutes) async {
    final className = classItem['name'] ?? 'Class';
    final classRoom = classItem['room'] ?? 'Room';
    final scheduleStr = classItem['schedule'] ?? '';
    final classId = classItem['id'];
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || classId == null) return;

    try {
      final parts = scheduleStr.split('–');
      if (parts.length != 2) throw 'Invalid schedule format';

      final dayStr = parts[0].trim();
      final timeStr = parts[1].trim();

      final weekdayMap = {
        'sunday': DateTime.sunday,
        'monday': DateTime.monday,
        'tuesday': DateTime.tuesday,
        'wednesday': DateTime.wednesday,
        'thursday': DateTime.thursday,
        'friday': DateTime.friday,
        'saturday': DateTime.saturday,
      };

      final weekday = weekdayMap[dayStr.toLowerCase()];
      if (weekday == null) throw 'Invalid weekday';

      final timeParts = timeStr.split(' ');
      final hourMinute = timeParts[0].split(':');
      int hour = int.parse(hourMinute[0]);
      int minute = int.parse(hourMinute[1]);
      final isPM = timeParts[1].toLowerCase() == 'pm';

      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;

      final now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

      while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
        scheduled = scheduled.add(Duration(days: 1));
      }

      final int finalOffset = offsetMinutes ?? 10;
      final reminderTime = scheduled.subtract(Duration(minutes: finalOffset));

      print("🕒 Local Timezone: \${tz.local.name}\nNow: \$now\nScheduled: \$reminderTime");

      await flutterLocalNotificationsPlugin.cancel(classId.hashCode ^ finalOffset);

      if (reminderTime.isBefore(now)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("⛔ Reminder time already passed."), backgroundColor: Colors.red),
          );
        }
        return;
      }

      await flutterLocalNotificationsPlugin.zonedSchedule(
        classId.hashCode ^ finalOffset,
        '📚 Reminder: $className',
        'Starts in $finalOffset minutes in room $classRoom',
        reminderTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'class_channel_id',
            'Class Reminders',
            channelDescription: 'User-scheduled reminders for classes',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );

      await firestore
          .collection('users')
          .doc(uid)
          .collection('classes')
          .doc(classId)
          .update({'reminder_offset': finalOffset});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⏰ Reminder set $finalOffset minutes before $className.')),
        );
      }
    } catch (e) {
      print("❌ Exception: \$e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to schedule reminder: \$e')),
        );
      }
    }
  }

  void _cancelNotification(BuildContext context, Map<String, dynamic> classItem) async {
    final classId = classItem['id'];
    final offset = classItem['reminder_offset'] ?? 10;

    await flutterLocalNotificationsPlugin.cancel(classId.hashCode ^ offset);
    await firestore
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('classes')
        .doc(classId)
        .update({'reminder_offset': FieldValue.delete()});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🔕 Reminder for ${classItem['name']} canceled.')),
      );
    }
  }
}
