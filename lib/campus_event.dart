/// FULL CampusEventScreen with Local Event Caching
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:campusconnect/sqllite/databasehelper.dart';
import 'package:campusconnect/sqllite/localevent.dart';
import 'package:intl/intl.dart';



import 'main.dart';


class CampusEventScreen extends StatefulWidget {
  @override
  _CampusEventScreenState createState() => _CampusEventScreenState();
}

class _CampusEventScreenState extends State<CampusEventScreen>
    with SingleTickerProviderStateMixin {
  final eventsRef = FirebaseFirestore.instance.collection('events');
  final uid = FirebaseAuth.instance.currentUser?.uid;
  Map<String, String> _userMap = {};

  late AnimationController _animController;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  List<LocalEvent> _localEvents = [];

  @override
  void initState() {

    super.initState();
    tz.initializeTimeZones();
    _loadUsernames();
    _animController = AnimationController(
        vsync: this, duration: Duration(milliseconds: 800))
      ..forward();
    _loadLocalEvents();
  }



  void _loadUsernames() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final map = <String, String>{};
    for (var d in snap.docs) {
      final data = d.data() as Map<String, dynamic>;
      map[d.id] = data['full_name'] ?? data['username'] ?? d.id;
    }
    setState(() => _userMap = map);
  }

  Future<void> _loadLocalEvents() async {
    final all = await DatabaseHelper.instance.fetchEvents();
    setState(() {
      _localEvents = all.where((e) => e.creatorId == uid).toList();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(Duration(days: 365)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _selectedTime = time);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showEventDialog,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add),
        label: Text("New Event"),
        tooltip: 'Add a new campus event',
      ),
      body: Stack(
        children: [
          // Background Gradient Animation
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.indigo.withOpacity(0.6 + 0.4 * _animController.value),
                    Colors.blueAccent.withOpacity(0.6 + 0.4 * (1 - _animController.value)),
                  ],
                ),
              ),
            ),
          ),
          // Custom Header with Back Button
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 32,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                IconButton(
                  key: Key('back_to_home_button'),
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // Title
                Text(
                  'Campus Events',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                // Optional trailing icon for symmetry
                Icon(Icons.event, color: Colors.white, size: 28),
              ],
            ),
          ),
          // Events List
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 110,
              bottom: 80,
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: eventsRef.orderBy('dateTime').snapshots(),
              builder: (ctx, snap) {
                final firestoreEvents = snap.data?.docs ?? [];
                final allEvents = [
                  ..._localEvents.map((e) => {'local': e}),
                  ...firestoreEvents.map((e) => {'remote': e}),
                ];

                if (allEvents.isEmpty) {
                  return Center(
                    child: Text(
                      '🎉 No upcoming events yet',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: allEvents.length,
                  itemBuilder: (c, i) {
                    final e = allEvents[i];
                    if (e.containsKey('local')) {
                      return _buildLocalCard(e['local'] as LocalEvent);
                    } else {
                      final doc = e['remote'] as DocumentSnapshot;
                      final d = doc.data()! as Map<String, dynamic>;
                      final dt = (d['dateTime'] as Timestamp).toDate().toLocal();
                      final rsvps = List<String>.from(d['rsvps'] ?? []);
                      final isCreator = d['creator'] == uid;
                      return _buildFirestoreCard(doc, d, dt, rsvps, isCreator);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildLocalCard(LocalEvent e) {
    final isDraft = true;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    e.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isDraft)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Draft',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),

            Text(e.description, style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: 12),
            Row(children: [
              Icon(Icons.calendar_today, size: 16),
              SizedBox(width: 4),
              Text('${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}'),
              SizedBox(width: 16),
              Icon(Icons.access_time, size: 16),
              SizedBox(width: 4),
              Text('${e.date.hour.toString().padLeft(2, '0')}:${e.date.minute.toString().padLeft(2, '0')}'),
            ]),
            SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: Icon(Icons.edit),
                  label: Text('Edit'),
                  onPressed: () => _editLocalEvent(e),
                ),
                SizedBox(width: 12),
                OutlinedButton.icon(
                  key: Key('publish_button'),
                  icon: Icon(Icons.cloud_upload),
                  label: Text('Publish'),
                  onPressed: () => _publishLocalEvent(e),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _editLocalEvent(LocalEvent e) async {
    _titleCtrl.text = e.title;
    _descCtrl.text = e.description;
    _selectedDate = e.date;
    _selectedTime = TimeOfDay(hour: e.date.hour, minute: e.date.minute);
    await _showEventDialog(localEvent: e, isEditing: true);
  }

  void _publishLocalEvent(LocalEvent e) async {
    final firestoreEvent = e.toMap(forFirestore: true);
    firestoreEvent['creator'] = uid;
    firestoreEvent['creatorId'] = uid;
    firestoreEvent['rsvps'] = [uid];
    firestoreEvent['user_reminders'] = {uid!: 5};

    String? newFirestoreId;

    if (e.firestoreId != null) {
      await eventsRef.doc(e.firestoreId!).set(firestoreEvent);
      newFirestoreId = e.firestoreId;
    } else {
      final docRef = await eventsRef.add(firestoreEvent);
      newFirestoreId = docRef.id;

      final updatedEvent = LocalEvent(
        id: e.id,
        title: e.title,
        description: e.description,
        date: e.date,
        creatorId: e.creatorId,
        firestoreId: docRef.id,
        userReminders: e.userReminders,
      );

      await DatabaseHelper.instance.deleteEvent(e.id);
      await DatabaseHelper.instance.insertEvent(updatedEvent);
    }

    // 🔔 Notify all users except the creator
    final usersSnap = await FirebaseFirestore.instance.collection('users').get();
    for (var user in usersSnap.docs) {
      if (user.id != uid) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': user.id,
          'message': '📢 New event "${e.title}" has been published!',
          'eventId': newFirestoreId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    try {
      await DatabaseHelper.instance.deleteEvent(e.id);
      await _loadLocalEvents();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event published to Firestore and users notified')),
      );
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting local copy: $err')),
      );
    }
  }


  Future<void> _showEventDialog({
    DocumentSnapshot? doc,
    LocalEvent? localEvent,
    bool isEditing = false,
  }) async {
    // Pre-fill or reset form fields
    if (doc != null) {
      final data = doc.data() as Map<String, dynamic>;
      _titleCtrl.text = data['title'] ?? '';
      _descCtrl.text = data['description'] ?? '';
      final dt = (data['dateTime'] as Timestamp).toDate();
      _selectedDate = dt;
      _selectedTime = TimeOfDay.fromDateTime(dt);
    } else if (localEvent != null) {
      _titleCtrl.text = localEvent.title;
      _descCtrl.text = localEvent.description;
      _selectedDate = localEvent.date;
      _selectedTime = TimeOfDay.fromDateTime(localEvent.date);
    } else {
      _titleCtrl.clear();
      _descCtrl.clear();
      _selectedDate = null;
      _selectedTime = null;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.calendar_today),
                    label: Text(_selectedDate == null
                        ? 'Pick Date'
                        : '${_selectedDate!.toLocal().toIso8601String().split("T")[0]}'),
                    onPressed: _pickDate,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.access_time),
                    label: Text(_selectedTime == null
                        ? 'Pick Time'
                        : _selectedTime!.format(context)),
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 48)),
              onPressed: () async {
                if (_selectedDate == null || _selectedTime == null || _titleCtrl.text.isEmpty) return;

                final dt = DateTime(
                  _selectedDate!.year,
                  _selectedDate!.month,
                  _selectedDate!.day,
                  _selectedTime!.hour,
                  _selectedTime!.minute,
                );
                if (doc != null) {
                  final docId = doc.id;
                  final newTitle = _titleCtrl.text.trim();
                  final newDescription = _descCtrl.text.trim();

                  final currentSnapshot = await eventsRef.doc(docId).get();
                  final currentData = currentSnapshot.data()!;
                  final oldTimestamp = (currentData['dateTime'] as Timestamp).toDate();

                  print('🔁 Old Time: $oldTimestamp');
                  print('🆕 New Time: $dt');

                  final timeChanged = oldTimestamp.compareTo(dt) != 0;

                  await eventsRef.doc(docId).update({
                    'title': newTitle,
                    'description': newDescription,
                    'dateTime': dt,
                  });

                  if (timeChanged) {
                    List<dynamic> rsvps = currentData['rsvps'] ?? [];
                    for (var userId in rsvps) {
                      await FirebaseFirestore.instance.collection('notifications').add({
                        'userId': userId,
                        'eventId': docId,
                        'message': '📅 The event "$newTitle" has been updated to ${DateFormat('MMM d – h:mm a').format(dt)}.',
                        'createdAt': Timestamp.now(),
                      });
                      print('✅ Notification added to Firestore for user: $userId');
                    }
                  } else {
                    print('ℹ️ Event time has not changed — no notification created.');
                  }

                  Navigator.pop(context);
                  return;
                }



                else {
                  // Local event creation
                  final eventToSave = LocalEvent(
                    id: localEvent?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    title: _titleCtrl.text.trim(),
                    description: _descCtrl.text.trim(),
                    date: dt,
                    creatorId: uid!,
                    firestoreId: localEvent?.firestoreId,
                  );

                  if (isEditing && localEvent != null) {
                    await DatabaseHelper.instance.deleteEvent(localEvent.id);
                  }

                  await DatabaseHelper.instance.insertEvent(eventToSave);
                  await _loadLocalEvents();
                  Navigator.pop(context);
                }
              },
              child: Text(doc != null ? 'Update' : 'Save Locally'),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }


  Widget _buildFirestoreCard(DocumentSnapshot doc, Map<String, dynamic> d, DateTime dt, List<String> rsvps, bool isCreator) {
    final bool isRSVPed = rsvps.contains(uid);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isRSVPed ? Colors.lightGreen[50] : Colors.white,
      elevation: isRSVPed ? 10 : 6,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    d['title'],
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isRSVPed ? Colors.green[900] : Colors.black87,
                    ),
                  ),
                ),
                if (isRSVPed)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('RSVP\'d',
                        style: TextStyle(
                            fontSize: 12, color: Colors.green[900], fontWeight: FontWeight.w500)),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) => _handleMenu(v, doc, d),
                  itemBuilder: (_) => [
                    if (isCreator)
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (isCreator)
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    PopupMenuItem(value: 'remind', child: Text('Set Reminder')),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              d['description'] ?? '',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.grey[700]),
            ),
            SizedBox(height: 12),
            Row(children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.blueGrey),
              SizedBox(width: 4),
              Text(
                '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.black87),
              ),
              SizedBox(width: 16),
              Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
              SizedBox(width: 4),
              Text(
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.black87),
              ),
            ]),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(isRSVPed ? Icons.cancel : Icons.check),
                    label: Text(isRSVPed ? 'Cancel RSVP' : 'RSVP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRSVPed ? Colors.redAccent : Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _toggleRSVP(doc),
                  ),
                ),
                SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: Icon(Icons.group),
                  label: Text('Attendees (${rsvps.length})'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    foregroundColor: Colors.deepPurple,
                  ),
                  onPressed: () => _showAttendeesDialog(rsvps),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }


  void _handleMenu(String v, DocumentSnapshot doc, Map<String, dynamic> d) async {
    if (v == 'edit') await _showEventDialog(doc: doc);
    if (v == 'delete') await eventsRef.doc(doc.id).delete();
    if (v == 'remind') await _showReminderDialog(doc);
  }

  Future<void> _showReminderDialog(DocumentSnapshot doc) async {
    final d = doc.data() as Map<String, dynamic>;
    final current = (d['user_reminders'] as Map<String, dynamic>? ?? {})[uid] ?? 5;
    int offset = current;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Your Reminder Time'),
        content: StatefulBuilder(
          builder: (context, setSB) => DropdownButton<int>(
            value: offset,
            items: [5, 10, 15, 30]
                .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                .toList(),
            onChanged: (v) => setSB(() => offset = v!),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
              onPressed: () async {
                await eventsRef.doc(doc.id).update({"user_reminders.$uid": offset});
                final dt = (doc.data()! as Map<String, dynamic>)['dateTime'].toDate();
                final sched = tz.TZDateTime.from(dt.subtract(Duration(minutes: offset)), tz.local);
                await flutterLocalNotificationsPlugin.zonedSchedule(
                  doc.id.hashCode ^ offset,
                  "Reminder: ${(doc.data()! as Map<String, dynamic>)['title']}",
                  "Starts in $offset min",
                  sched,
                  NotificationDetails(android: AndroidNotificationDetails('event_channel', 'Event Reminders', channelDescription: 'Reminder before event')),
                  androidAllowWhileIdle: true,
                  uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
                  matchDateTimeComponents: DateTimeComponents.dateAndTime,
                );
                Navigator.pop(context);
              },
              child: Text('Save'))
        ],
      ),
    );
  }

  void _toggleRSVP(DocumentSnapshot eventDoc) async {
    final data = eventDoc.data() as Map<String, dynamic>?;
    if (data == null) return;
    final rsvps = List<String>.from(data['rsvps'] ?? []);
    final has = rsvps.contains(uid);
    await eventsRef.doc(eventDoc.id).update({
      'rsvps': has ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid])
    });
    if (!has) {
      await _showReminderDialog(eventDoc);
    } else {
      final rem = (data['user_reminders'] as Map<String, dynamic>? ?? {});
      final off = rem[uid] ?? 0;
      await flutterLocalNotificationsPlugin.cancel(eventDoc.id.hashCode ^ off);
    }
  }

  void _showAttendeesDialog(List<String> ids) {
    final names = ids.map((id) => _userMap[id] ?? id).toList();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.group, color: Colors.deepPurple),
            SizedBox(width: 10),
            Text('Attendees (${names.length})', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          height: 250,
          child: names.isEmpty
              ? Center(
            child: Text('No attendees yet.',
                style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
          )
              : ListView.separated(
            itemCount: names.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[300]),
            itemBuilder: (_, i) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple[100],
                child: Text(names[i][0].toUpperCase(), style: TextStyle(color: Colors.deepPurple)),
              ),
              title: Text(names[i], style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: Colors.red),
            label: Text('Close', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

}
