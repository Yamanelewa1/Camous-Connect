import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'classschedulescreen.dart';
import 'StudyGroupSection.dart';
import 'campus_event.dart';
import 'profilepage.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final String? photoUrl = FirebaseAuth.instance.currentUser?.photoURL;

  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  Map<String, String> _classNames = {};

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  late FlutterLocalNotificationsPlugin _localNotif;
  final CollectionReference _notifRef =
  FirebaseFirestore.instance.collection('notifications');

  static const Map<String, int> _reminderOptions = {
    'At time': 0,
    '1 h before': 60,
    '3 h before': 180,
    '1 d before': 1440,
  };

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initNotifications();
    _loadClassNames();
    _loadCalendarEvents();
  }

  void _initNotifications() {
    _localNotif = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    _localNotif.initialize(
      InitializationSettings(android: android, iOS: ios),
    );
  }

  Future<void> _loadClassNames() async {
    final snap = await FirebaseFirestore.instance.collection('classes').get();
    setState(() {
      _classNames = {
        for (var d in snap.docs) d.id: d['name'] as String? ?? 'Unnamed'
      };
    });
  }

  void _loadCalendarEvents() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('calendar')
        .snapshots()
        .listen((snap) {
      final map = <DateTime, List<Map<String, dynamic>>>{};
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dateStr = data['date'] as String?;
        final timeStr = data['time'] as String?;
        final reminderOffset = data['reminderOffset'] as int? ?? 1440;
        if (dateStr != null && timeStr != null) {
          final datePart = DateTime.parse(dateStr);
          final parsedTime = DateFormat('h:mm a').parse(timeStr);
          final dt = DateTime(
            datePart.year,
            datePart.month,
            datePart.day,
            parsedTime.hour,
            parsedTime.minute,
          );
          final dayKey = DateTime(dt.year, dt.month, dt.day);
          map.putIfAbsent(dayKey, () => []).add({
            ...data,
            'parsedDate': dt,
            'id': doc.id,
          });

          // schedule user‑chosen reminder
          _scheduleBell(doc.id, data['title'] ?? '', reminderOffset, dt);
          // always also schedule 12 h before
          _scheduleBell(doc.id, data['title'] ?? '', 12 * 60, dt);
        }
      }
      setState(() => _events = map);
    });
  }

  void _scheduleBell(
      String eventId, String title, int minutesBefore, DateTime eventDt) {
    final now = DateTime.now();
    final bellTime = eventDt.subtract(Duration(minutes: minutesBefore));
    if (bellTime.isAfter(now)) {
      Timer(bellTime.difference(now), () {
        _notifRef.add({
          'userId': uid,
          'message':
          'Reminder: $title in ${minutesBefore >= 60 ? '${minutesBefore ~/ 60}h ' : ''}${minutesBefore % 60}m',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    }
    _scheduleLocalNotification(eventDt, title, minutesBefore);
  }

  Future<void> _scheduleLocalNotification(
      DateTime eventDate, String title, int minutesBefore) async {
    final dt = eventDate.subtract(Duration(minutes: minutesBefore));
    if (dt.isAfter(DateTime.now())) {
      final id = dt.millisecondsSinceEpoch.remainder(1 << 31);
      await _localNotif.zonedSchedule(
        id,
        'Reminder: $title',
        minutesBefore >= 60
            ? 'In ${minutesBefore ~/ 60}h ${minutesBefore % 60}m'
            : 'In $minutesBefore min',
        tz.TZDateTime.from(dt, tz.local),
        NotificationDetails(
            android: AndroidNotificationDetails(
                'cal_rem', 'Calendar Reminders',
                importance: Importance.high, priority: Priority.high),
            iOS: DarwinNotificationDetails()),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) =>
      _events[DateTime(day.year, day.month, day.day)] ?? [];

  void _showCalendarSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, ctl) => StatefulBuilder(
          builder: (ctx2, setMS) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(width: 40, height: 4, color: Colors.grey[300]),
                SizedBox(height: 12),
                TableCalendar(
                  firstDay: DateTime.now().subtract(Duration(days: 365)),
                  lastDay: DateTime.now().add(Duration(days: 365)),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                  selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                  eventLoader: _getEventsForDay,
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration:
                    BoxDecoration(color: Colors.indigo.shade200, shape: BoxShape.circle),
                    selectedDecoration:
                    BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                    markerDecoration:
                    BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  ),
                  onDaySelected: (sel, foc) {
                    setMS(() {
                      _selectedDay = sel;
                      _focusedDay = foc;
                    });
                  },
                ),
                SizedBox(height: 8),
                Expanded(child: _buildEventList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventList() {
    final evts = _getEventsForDay(_selectedDay);
    if (evts.isEmpty) {
      return Center(child: Text('No events', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: evts.length,
      itemBuilder: (_, i) {
        final e = evts[i];
        final dt = e['parsedDate'] as DateTime;
        final time = DateFormat('h:mm a').format(dt);
        final cname = _classNames[e['class_id']] ?? 'Unknown Class';
        final currOff = e['reminderOffset'] as int? ?? 1440;
        return Container(
          margin: EdgeInsets.symmetric(vertical: 6),
          decoration:
          BoxDecoration(border: Border(left: BorderSide(color: Colors.indigo, width: 4))),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Chip(
                      label: Text(cname, style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.indigo,
                      visualDensity: VisualDensity.compact,
                    ),
                    Spacer(),
                    Text(time, style: TextStyle(fontWeight: FontWeight.bold)),
                    PopupMenuButton<int>(
                      icon: Icon(Icons.notifications,
                          color: currOff == 0 ? Colors.grey : Colors.orange),
                      initialValue: currOff,
                      onSelected: (mins) {
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('calendar')
                            .doc(e['id'])
                            .set({'reminderOffset': mins}, SetOptions(merge: true));
                        _scheduleLocalNotification(dt, e['title'] ?? '', mins);
                        setState(() {});
                      },
                      itemBuilder: (_) => _reminderOptions.entries
                          .map((kv) =>
                          PopupMenuItem<int>(value: kv.value, child: Text(kv.key)))
                          .toList(),
                    ),
                  ]),
                  SizedBox(height: 8),
                  Text(e['title'] ?? '',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  if ((e['note'] ?? '').isNotEmpty) ...[
                    SizedBox(height: 6),
                    Text(e['note'], style: TextStyle(color: Colors.grey[700])),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('home_screen'),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.indigo.shade800,
              Colors.purple.shade300,
              Colors.pinkAccent.shade100,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned(
                      bottom: -20,
                      right: -20,
                      child: Icon(Icons.auto_awesome_rounded, size: 160, color: Colors.white12),
                    ),
                    SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 16),
                            AnimatedSwitcher(
                              duration: Duration(milliseconds: 800),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(opacity: animation, child: child),
                              child: Text(
                                "Let's organize your academic life!",
                                key: ValueKey('animated-message'),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                            SizedBox(height: 12),
                            _buildTopBar(),
                            SizedBox(height: 12),
                            _buildFeatureButtons(),
                            SizedBox(height: 24),
                            Center(
                              child: Container(
                                height: 160,
                                width: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.07),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                                  ],
                                ),
                                padding: EdgeInsets.all(12),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/dragon1.jpg', // 🦅 Replace with correct image
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                            Center(
                              child: ElevatedButton.icon(
                                icon: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 1.0, end: 1.1),
                                  duration: Duration(seconds: 2),
                                  curve: Curves.easeInOut,
                                  builder: (_, value, child) =>
                                      Transform.scale(scale: value, child: child),
                                  child: Icon(Icons.calendar_today_rounded),
                                ),
                                label: Text('View Calendar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.indigo.shade800,
                                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 28),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 6,
                                  textStyle: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                onPressed: _showCalendarSheet,
                              ),
                            ),
                            SizedBox(height: 60), // space before footer
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.white24, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Powered by CampusConnect ✨',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }






  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      Expanded(
          child: Text('Home Page',
              key: Key('home_screen_title'),
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
      // bell with badge
      StreamBuilder<QuerySnapshot>(
        stream: _notifRef.where('userId', isEqualTo: uid).snapshots(),
        builder: (context, snap) {
          int count = snap.hasData ? snap.data!.docs.length : 0;
          return Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications, color: Colors.white),
                onPressed: () => _showNotificationDialog(context),
              ),
              if (count > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      '$count',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      GestureDetector(
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage())),
        child: CircleAvatar(
          radius: 18,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
          backgroundColor: Colors.white24,
          child: photoUrl == null ? Icon(Icons.person, color: Colors.white) : null,
        ),
      ),
    ]),
  );

  Widget _buildFeatureButtons() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(children: [
      _buildFeatureButton(Icons.schedule, 'Class Schedule', ClassScheduleScreen()),
      _buildFeatureButton(Icons.groups, 'Study Groups', StudyGroupScreen()),
      _buildFeatureButton(Icons.event, 'Campus Events', CampusEventScreen()),
    ]),
  );

  Widget _buildFeatureButton(IconData icon, String label, Widget screen) => Container(
    margin: EdgeInsets.only(bottom: 12),
    width: double.infinity,
    child: ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 2,
      ),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
    ),
  );

  void _showNotificationDialog(BuildContext context) async {
    final snap = await _notifRef.where('userId', isEqualTo: uid).get();
    final items = snap.docs;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Notifications'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 350),
          child: items.isEmpty
              ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_off, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No notifications.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          )
              : ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(color: Colors.grey.shade300),
            itemBuilder: (_, i) => ListTile(
              leading: Icon(Icons.circle_notifications_rounded, color: Colors.deepPurple),
              title: Text(
                items[i]['message'] ?? '',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              child: Text('Clear All', style: TextStyle(color: Colors.redAccent)),
              onPressed: () async {
                for (var doc in items) {
                  await doc.reference.delete();
                }
                Navigator.pop(context);
              },
            ),
          TextButton(
            child: Text('Close', style: TextStyle(color: Colors.deepPurple)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }


  Widget _buildAnimatedGreeting() {
    final photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      tween: Tween(begin: 0, end: 1),
      builder: (_, value, child) => Opacity(opacity: value, child: child),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            backgroundColor: Colors.white24,
            child: photoUrl == null ? Icon(Icons.person, color: Colors.white) : null,
          ),
          SizedBox(width: 12),
          Text('Welcome back 👋',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

}
