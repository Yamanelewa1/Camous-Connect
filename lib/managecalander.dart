import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCreateCalendarScreen extends StatefulWidget {
  @override
  _AdminCreateCalendarScreenState createState() => _AdminCreateCalendarScreenState();
}

class _AdminCreateCalendarScreenState extends State<AdminCreateCalendarScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  String? _selectedClassId;
  Map<String, String> _classMap = {};
  Map<String, List<Map<String, dynamic>>> _classEvents = {};

  String? _updatingUserId;
  String? _updatingEventId;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadAllCalendarEvents();
  }

  void _loadClasses() async {
    final snapshot = await firestore.collection('classes').get();
    setState(() {
      _classMap = {
        for (var doc in snapshot.docs) doc.id: doc.data()['name'] ?? doc.id
      };
    });
  }

  Future<void> _loadAllCalendarEvents() async {
    final usersSnapshot = await firestore.collection('users').get();
    final Map<String, List<Map<String, dynamic>>> tempEvents = {};
    final Set<String> seenEvents = {};

    for (var userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;
      final calendarSnapshot = await firestore.collection('users').doc(userId).collection('calendar').get();
      for (var eventDoc in calendarSnapshot.docs) {
        final data = eventDoc.data();
        final classId = data['class_id'];
        if (classId != null) {
          final uniqueKey = '${data['title']}_${data['date']}_${data['time']}_$classId';
          if (!seenEvents.contains(uniqueKey)) {
            seenEvents.add(uniqueKey);
            tempEvents.putIfAbsent(classId, () => []);
            tempEvents[classId]!.add({...data, 'eventId': eventDoc.id, 'userId': userId});
          }
        }
      }
    }

    setState(() {
      _classEvents = tempEvents;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now().add(Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = picked.format(context);
      });
    }
  }

  void _createOrUpdateCalendarEventForClass() async {
    final title = _titleController.text.trim();
    final date = _dateController.text.trim();
    final time = _timeController.text.trim();
    final note = _noteController.text.trim();

    if (title.isEmpty || date.isEmpty || time.isEmpty || _selectedClassId == null) return;

    if (_updatingEventId != null && _updatingUserId != null) {
      await firestore.collection('users').doc(_updatingUserId).collection('calendar').doc(_updatingEventId).update({
        'title': title,
        'date': date,
        'time': time,
        'note': note,
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Calendar event updated.')));
    } else {
      final userSnapshot = await firestore.collection('users').get();
      bool anyInserted = false;

      for (var userDoc in userSnapshot.docs) {
        final userId = userDoc.id;
        final userClass = await firestore.collection('users').doc(userId).collection('classes').doc(_selectedClassId).get();

        if (userClass.exists) {
          final existing = await firestore
              .collection('users')
              .doc(userId)
              .collection('calendar')
              .where('title', isEqualTo: title)
              .where('date', isEqualTo: date)
              .where('time', isEqualTo: time)
              .where('class_id', isEqualTo: _selectedClassId)
              .get();

          if (existing.docs.isEmpty) {
            await firestore.collection('users').doc(userId).collection('calendar').add({
              'title': title,
              'date': date,
              'time': time,
              'note': note,
              'class_id': _selectedClassId,
            });
            anyInserted = true;
          }
        }
      }

      if (anyInserted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📅 Calendar event assigned successfully.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ Duplicate event already exists.')));
      }
    }

    _clearInputs();
    await _loadAllCalendarEvents();
  }

  void _deleteCalendarEvent(String userId, String eventId) async {
    final eventDoc = await firestore.collection('users').doc(userId).collection('calendar').doc(eventId).get();
    final data = eventDoc.data();
    if (data == null) return;

    final title = data['title'];
    final date = data['date'];
    final time = data['time'];
    final classId = data['class_id'];

    final usersSnapshot = await firestore.collection('users').get();
    for (var user in usersSnapshot.docs) {
      final uid = user.id;
      final snapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('calendar')
          .where('title', isEqualTo: title)
          .where('date', isEqualTo: date)
          .where('time', isEqualTo: time)
          .where('class_id', isEqualTo: classId)
          .get();

      for (var doc in snapshot.docs) {
        await firestore.collection('users').doc(uid).collection('calendar').doc(doc.id).delete();
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🗑️ Event deleted from all users.')));
    await _loadAllCalendarEvents();
  }

  void _clearInputs() {
    _titleController.clear();
    _dateController.clear();
    _timeController.clear();
    _noteController.clear();
    _updatingUserId = null;
    _updatingEventId = null;
    setState(() => _selectedClassId = null);
  }

  void _populateForm(Map<String, dynamic> event) {
    _titleController.text = event['title'] ?? '';
    _dateController.text = event['date'] ?? '';
    _timeController.text = event['time'] ?? '';
    _noteController.text = event['note'] ?? '';
    _updatingUserId = event['userId'];
    _updatingEventId = event['eventId'];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedClassEvents = _selectedClassId != null ? _classEvents[_selectedClassId!] ?? [] : [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Calendar Event'),
        backgroundColor: Colors.indigo,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade700, Colors.indigo.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Card(
                      color: Colors.white.withOpacity(0.95),
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextField(controller: _titleController, decoration: InputDecoration(labelText: 'Event Title')),
                            SizedBox(height: 12),
                            TextFormField(
                              controller: _dateController,
                              readOnly: true,
                              decoration: InputDecoration(labelText: 'Date', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                              onTap: _pickDate,
                            ),
                            SizedBox(height: 12),
                            TextFormField(
                              controller: _timeController,
                              readOnly: true,
                              decoration: InputDecoration(labelText: 'Time', border: OutlineInputBorder(), suffixIcon: Icon(Icons.access_time)),
                              onTap: _pickTime,
                            ),
                            SizedBox(height: 12),
                            TextField(controller: _noteController, decoration: InputDecoration(labelText: 'Note')),
                            SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(labelText: 'Select Class'),
                              value: _selectedClassId,
                              items: _classMap.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                              onChanged: (val) => setState(() => _selectedClassId = val),
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _createOrUpdateCalendarEventForClass,
                              child: Text(_updatingEventId == null ? 'Assign Event to Class' : 'Update Event'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    if (_selectedClassId != null) ...[
                      SizedBox(height: 20),
                      Text('Update/Delete Events for Selected Class', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 10),
                      ...selectedClassEvents.map((event) => Card(
                        margin: EdgeInsets.symmetric(vertical: 6),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.shade200,
                            child: Icon(Icons.event, color: Colors.white),
                          ),
                          title: Text(event['title'] ?? 'No Title', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${event['date']} at ${event['time']}${event['note'] != null ? "\nNote: ${event['note']}" : ""}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.orange),
                                onPressed: () => _populateForm(event),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCalendarEvent(event['userId'], event['eventId']),
                              ),
                            ],
                          ),
                        ),
                      ))
                    ]
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
