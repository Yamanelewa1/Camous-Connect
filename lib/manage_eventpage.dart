import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminManageEventsScreen extends StatefulWidget {
  @override
  _AdminManageEventsScreenState createState() => _AdminManageEventsScreenState();
}

class _AdminManageEventsScreenState extends State<AdminManageEventsScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final CollectionReference eventsRef = FirebaseFirestore.instance.collection('events');

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool isAdmin = false;
  String? editingEventId;
  String searchText = "";

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  void _checkAdminStatus() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await firestore.collection('users').doc(uid).get();
    if (userDoc.exists && ['admin', 'senior_admin'].contains(userDoc['role'])) {
      setState(() {
        isAdmin = true;
      });
    }
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now().add(Duration(days: 365 * 5)),
    );
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedTime ?? TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDate = pickedDate;
          _selectedTime = pickedTime;
          final formatted = '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')} ${pickedTime.format(context)}';
          _dateCtrl.text = formatted;
        });
      }
    }
  }

  void _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = auth.currentUser?.uid;
    if (uid == null || _selectedDate == null || _selectedTime == null) return;

    final DateTime fullDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final eventData = {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'dateTime': Timestamp.fromDate(fullDateTime),
      'creator': uid,
      'creatorId': uid,
      'created_by_admin': true,
      'rsvps': [uid],
      'user_reminders': {uid: 5},
    };

    if (editingEventId == null) {
      await eventsRef.add(eventData);
    } else {
      await eventsRef.doc(editingEventId).update(eventData);
    }

    _clearForm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(editingEventId == null ? '✅ Event created' : '✅ Event updated')),
    );
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _titleCtrl.clear();
    _descCtrl.clear();
    _dateCtrl.clear();
    setState(() {
      editingEventId = null;
      _selectedDate = null;
      _selectedTime = null;
    });
  }

  void _editEvent(DocumentSnapshot doc) {
    final timestamp = doc['dateTime'] as Timestamp;
    final dt = timestamp.toDate();

    setState(() {
      editingEventId = doc.id;
      _titleCtrl.text = doc['title'];
      _descCtrl.text = doc['description'];
      _selectedDate = DateTime(dt.year, dt.month, dt.day);
      _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      _dateCtrl.text = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')} ${_selectedTime!.format(context)}';
    });
  }

  void _deleteEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Event'),
        content: Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: TextStyle(color: Colors.red)))
        ],
      ),
    );

    if (confirm == true) {
      await eventsRef.doc(eventId).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Event deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text('Admin Events')),
        body: Center(child: Text('Access denied. Admins only.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Manage Events (Admin Only)'), backgroundColor: Colors.indigo),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade700, Colors.indigo.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search events by title...',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.indigo.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) => setState(() => searchText = val.toLowerCase()),
              ),
              SizedBox(height: 16),
              Card(
                color: Colors.white.withOpacity(0.95),
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleCtrl,
                          decoration: InputDecoration(labelText: 'Event Title', border: OutlineInputBorder()),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _descCtrl,
                          decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _dateCtrl,
                          readOnly: true,
                          decoration: InputDecoration(labelText: 'Date & Time', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                          onTap: _pickDateTime,
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _saveEvent,
                          child: Text(editingEventId == null ? 'Create Event' : 'Update Event', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30),
              Text('All Events', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: eventsRef.orderBy('dateTime', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();

                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['title'].toString().toLowerCase().contains(searchText);
                  }).toList();

                  return ListView.builder(
                    itemCount: docs.length,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final ts = doc['dateTime'] as Timestamp;
                      final date = ts.toDate();
                      final data = doc.data() as Map<String, dynamic>;

                      return Card(
                        color: Colors.white,
                        margin: EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(12),
                          title: Text(doc['title'], style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Text(doc['description'], maxLines: 2, overflow: TextOverflow.ellipsis),
                              SizedBox(height: 4),
                              Text('Date: ${DateFormat('yMMMd – h:mm a').format(date)}', style: TextStyle(color: Colors.grey[600])),
                              if (data.containsKey('created_by_admin') && data['created_by_admin'] == true)
                                Text('Created by Admin', style: TextStyle(color: Colors.indigo)),
                            ],
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editEvent(doc),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteEvent(doc.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
