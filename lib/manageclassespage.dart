import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:campusconnect/sqllite/databasehelper.dart';
import 'main.dart'; // assumes flutterLocalNotificationsPlugin is initialized there

class ManageClassesPage extends StatefulWidget {
  @override
  _ManageClassesPageState createState() => _ManageClassesPageState();
}

class _ManageClassesPageState extends State<ManageClassesPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _professorController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _materialsController = TextEditingController();

  String? _selectedDay;
  TimeOfDay? _selectedTime;
  Map<String, String> _userMap = {};
  String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() async {
    final usersSnapshot = await firestore.collection('users').get();
    setState(() {
      _userMap = {
        for (var doc in usersSnapshot.docs)
          doc.id: doc.data()['username'] ?? doc.id
      };
    });
  }

  void _addClass() async {
    if (_nameController.text.isNotEmpty &&
        _professorController.text.isNotEmpty &&
        _roomController.text.isNotEmpty &&
        _materialsController.text.isNotEmpty &&
        _selectedDay != null &&
        _selectedTime != null) {
      final schedule = "$_selectedDay – ${_selectedTime!.format(context)}";
      await firestore.collection('classes').add({
        'name': _nameController.text,
        'professor': _professorController.text,
        'room': _roomController.text,
        'materials': _materialsController.text,
        'schedule': schedule,
      });
      _clearInputs();
    }
  }

  void _assignClassToUser(String classId, String userId) async {
    final classDoc = await firestore.collection('classes').doc(classId).get();
    if (classDoc.exists) {
      final classData = classDoc.data()!;
      final cleanedData = Map<String, dynamic>.from(classData)..remove('reminder_offset');

      await firestore
          .collection('users')
          .doc(userId)
          .collection('classes')
          .doc(classId)
          .set(cleanedData);

      await firestore.collection('users').doc(userId).update({
        'classes': FieldValue.arrayUnion([classId])
      });
    }
  }

  void _removeClassFromUser(String classId, String userId) async {
    try {
      // Delete subcollection document
      await firestore
          .collection('users')
          .doc(userId)
          .collection('classes')
          .doc(classId)
          .delete();

      // Remove from array field
      await firestore.collection('users').doc(userId).update({
        'classes': FieldValue.arrayRemove([classId])
      });
      await DatabaseHelper.instance.deleteAssignedClassOnly(userId, classId);


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Class removed from ${_userMap[userId]}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove: $e')),
      );
    }
  }


  Future<void> _updateClass(String classId) async {
    if (_selectedDay != null && _selectedTime != null) {
      final newSchedule = "$_selectedDay – ${_selectedTime!.format(context)}";
      final classDoc = firestore.collection('classes').doc(classId);

      final docSnapshot = await classDoc.get();
      if (!docSnapshot.exists) return;

      await classDoc.update({
        'schedule': newSchedule,
        'name': _nameController.text,
        'professor': _professorController.text,
        'room': _roomController.text,
        'materials': _materialsController.text,
      });

      final studentsSnapshot = await firestore.collection('users').get();

      for (var student in studentsSnapshot.docs) {
        final studentClassRef = firestore
            .collection('users')
            .doc(student.id)
            .collection('classes')
            .doc(classId);

        final studentClassSnapshot = await studentClassRef.get();
        if (studentClassSnapshot.exists) {
          await studentClassRef.update({
            'schedule': newSchedule,
            'name': _nameController.text,
            'professor': _professorController.text,
            'room': _roomController.text,
            'materials': _materialsController.text,
            'reminder_offset': 10
          });

          await flutterLocalNotificationsPlugin.show(
            classId.hashCode ^ student.id.hashCode,
            '⏰ Class Rescheduled',
            '${_nameController.text} is now at $newSchedule',
            NotificationDetails(
              android: AndroidNotificationDetails(
                'class_update_channel',
                'Class Updates',
                channelDescription: 'Notifications for class schedule updates',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
          );
        }
      }
    }
  }

  void _clearInputs() {
    _nameController.clear();
    _professorController.clear();
    _roomController.clear();
    _materialsController.clear();
    setState(() {
      _selectedDay = null;
      _selectedTime = null;
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final days = [
      'Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Classes'),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade100, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [

                // Section: Class Information
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text("Create or Update Class", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        TextField(controller: _nameController, decoration: InputDecoration(labelText: 'Class Name')),
                        TextField(controller: _professorController, decoration: InputDecoration(labelText: 'Professor')),
                        TextField(controller: _roomController, decoration: InputDecoration(labelText: 'Room')),
                        TextField(controller: _materialsController, decoration: InputDecoration(labelText: 'Materials')),
                        SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _selectedDay,
                          hint: Text("Select Day"),
                          items: days.map((day) => DropdownMenuItem(value: day, child: Text(day))).toList(),
                          onChanged: (val) => setState(() => _selectedDay = val),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(_selectedTime == null
                                  ? 'No time selected'
                                  : 'Time: ${_selectedTime!.format(context)}'),
                            ),
                            TextButton(onPressed: _pickTime, child: Text('Pick Time')),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _addClass,
                                child: Text('Create Class'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo,foregroundColor: Colors.white),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _selectedClassId == null ? null : () => _updateClass(_selectedClassId!),
                                child: Text('Update Class'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Section: Assign Class to User
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assign Class to User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        StreamBuilder<QuerySnapshot>(
                          stream: firestore.collection('classes').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return CircularProgressIndicator();
                            final classDocs = snapshot.data!.docs;
                            return DropdownButtonFormField<String>(
                              decoration: InputDecoration(labelText: 'Select Class'),
                              items: classDocs.map((doc) => DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(doc['name']),
                              )).toList(),
                              onChanged: (val) async {
                                if (val != null) {
                                  final classDoc = await firestore.collection('classes').doc(val).get();
                                  final data = classDoc.data();
                                  if (data != null) {
                                    setState(() {
                                      _selectedClassId = val;
                                      _nameController.text = data['name'] ?? '';
                                      _professorController.text = data['professor'] ?? '';
                                      _roomController.text = data['room'] ?? '';
                                      _materialsController.text = data['materials'] ?? '';
                                      final schedule = data['schedule'] as String? ?? '';
                                      final parts = schedule.split('–');
                                      if (parts.length == 2) {
                                        _selectedDay = parts[0].trim();
                                        final timeStr = parts[1].trim();
                                        final timeParts = timeStr.split(' ');
                                        if (timeParts.length == 2) {
                                          final hourMin = timeParts[0].split(':');
                                          int hour = int.parse(hourMin[0]);
                                          int minute = int.parse(hourMin[1]);
                                          final isPM = timeParts[1].toLowerCase() == 'pm';
                                          if (isPM && hour != 12) hour += 12;
                                          if (!isPM && hour == 12) hour = 0;
                                          _selectedTime = TimeOfDay(hour: hour, minute: minute);
                                        }
                                      }
                                    });
                                  }
                                }
                              },
                            );
                          },
                        ),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(labelText: 'Select User'),
                          items: _userMap.entries.map((entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null && _selectedClassId != null) {
                              _assignClassToUser(_selectedClassId!, val);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Class assigned to ${_userMap[val]}')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Section: Remove Class from User
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remove Class from User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(labelText: 'Select User'),
                          items: _userMap.entries.map((entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null && _selectedClassId != null) {
                              _removeClassFromUser(_selectedClassId!, val);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Class removed from ${_userMap[val]}')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  void dispose() {
    _nameController.dispose();
    _professorController.dispose();
    _roomController.dispose();
    _materialsController.dispose();
    super.dispose();
  }
}
