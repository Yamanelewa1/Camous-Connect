import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:campusconnect/sqllite/databasehelper.dart';
import 'package:campusconnect/sqllite/localstudygroup.dart';
import 'package:campusconnect/sqllite/localclass.dart';


class StudyGroupScreen extends StatefulWidget {
  @override
  _StudyGroupScreenState createState() => _StudyGroupScreenState();
}

class _StudyGroupScreenState extends State<StudyGroupScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final DatabaseReference usersRef = FirebaseDatabase.instance.ref('users');
  final _topicController = TextEditingController();
  final _sessionTimeController = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser?.uid;
  Set<String> canceledRSVPs = {};
  Map<String, String> _userMap = {};
  Set<String> rsvpedGroups = {};
  List<LocalStudyGroup> _localGroups = [];
  List<LocalClass> _userClasses = [];

  String? _selectedClassId;
  final TextEditingController _customTopicController = TextEditingController();
  String? _currentlyEditingGroupId; // null when not editing


  @override
  void initState() {
    super.initState();
    _loadUserClasses();
    _loadUsernames();
    _loadLocalStudyGroups();
    _fetchAndStoreUserClasses();
  }


  @override
  void dispose() {
    _topicController.dispose();
    _sessionTimeController.dispose();
    _customTopicController.dispose();
    super.dispose();
  }



  void _loadUsernames() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final Map<String, String> userMap = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final fullName = data['full_name']?.toString();
        final username = data['username']?.toString();
        userMap[doc.id] = fullName?.isNotEmpty == true ? fullName! : (username ?? doc.id);
      }

      setState(() {
        _userMap = userMap;
      });

      print('✅ Loaded user map: $_userMap');
    } catch (e) {
      print('❌ Failed to load usernames from Firestore: $e');
    }
  }


  Future<void> _loadUserClasses() async {
    if (uid == null) return; // Make sure uid is not null
    final classes = await DatabaseHelper.instance.fetchUserClasses(uid!);
    setState(() {
      _userClasses = classes;
    });
  }


  Future<void> _fetchAndStoreUserClasses() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userClassesRef = firestore.collection('users').doc(userId).collection('classes');

    try {
      final snapshot = await userClassesRef.get();

      for (var doc in snapshot.docs) {
        final data = doc.data();

        final localClass = LocalClass(
          id: doc.id,
          name: data['name'] ?? 'Unnamed Class',
          professor: data['professor'] ?? '',
          room: data['room'] ?? '',
          materials: data['materials'] ?? '',
          schedule: data['schedule'] ?? '',
          userId: userId,
        );

        await DatabaseHelper.instance.insertClass(localClass);
      }

      print('✅ Fetched and saved ${snapshot.docs.length} classes');
      await _loadUserClasses();

    } catch (e) {
      print('❌ Failed to fetch or save user classes: $e');
    }
  }







  Future<void> _loadLocalStudyGroups() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final groups = await DatabaseHelper.instance.fetchStudyGroups();
    setState(() {
      _localGroups = groups
          .where((g) => g.creatorId == uid && !g.synced)
          .toList(); // ✅ Show only current user's drafts
    });
  }




  DateTime? _selectedDateTime;

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }


  void _createStudyGroup() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final topic = _selectedClassId != null
        ? _userClasses.firstWhere((cls) => cls.id == _selectedClassId).name
        : _customTopicController.text.trim();
    final sessionTime = _selectedDateTime;

    if (topic.isEmpty || sessionTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter topic and session time')),
      );
      return;
    }

    final group = LocalStudyGroup(
      id: _currentlyEditingGroupId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      topic: topic,
      sessionTime: sessionTime,
      createdAt: DateTime.now(),
      classId: _selectedClassId,
      creatorId: userId,
      rsvps: [],
    );

    if (_currentlyEditingGroupId != null) {
      await DatabaseHelper.instance.updateStudyGroup(group);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Study group updated locally')));
    } else {
      await DatabaseHelper.instance.insertStudyGroup(group);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Study group saved locally')));
    }

    setState(() {
      _currentlyEditingGroupId = null;
      _selectedClassId = null;
      _customTopicController.clear();
      _sessionTimeController.clear();
      _selectedDateTime = null;
    });

    _loadLocalStudyGroups();
  }








  void _publishStudyGroup(LocalStudyGroup g) async {
    final docRef = await firestore.collection('study_groups').add({
      'topic': g.topic,
      'session_time': g.sessionTime.toIso8601String(),
      'timestamp': g.createdAt.toIso8601String(),
      'creator': g.creatorId,
      'rsvps': [],
      'class_id': g.classId,
    });

    // 🔔 Notify logic based on class assignment
    QuerySnapshot usersSnap;

    if (g.classId != null && g.classId!.isNotEmpty) {
      // 📘 Notify only students who have this class
      usersSnap = await firestore
          .collection('users')
          .where('classes', arrayContains: g.classId)
          .get();
    } else {
      // 🧠 Custom topic group → notify all users except creator
      usersSnap = await firestore.collection('users').get();
    }

    for (var user in usersSnap.docs) {
      if (user.id != uid) {
        await firestore.collection('notifications').add({
          'userId': user.id,
          'message': '📚 A new study group on "${g.topic}" has been created!',
          'createdAt': FieldValue.serverTimestamp(),
          'studyGroupId': docRef.id,
        });
      }
    }

    await DatabaseHelper.instance.markStudyGroupAsSynced(g.id);
    await _loadLocalStudyGroups();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Study group published and users notified.')),
    );
  }






  void _rsvpToGroup(String docId) async {
    if (uid == null) return;
    await firestore.collection('study_groups').doc(docId).update({
      'rsvps': FieldValue.arrayUnion([uid])
    });
    setState(() {
      canceledRSVPs.remove(docId);
      rsvpedGroups.add(docId);
    });
  }

  void _cancelRsvp(String docId) async {
    if (uid == null) return;
    await firestore.collection('study_groups').doc(docId).update({
      'rsvps': FieldValue.arrayRemove([uid])
    });
    setState(() {
      canceledRSVPs.add(docId);
      rsvpedGroups.remove(docId);
    });
  }

  void _deleteGroup(String docId) async {
    // Delete from Firestore
    await firestore.collection('study_groups').doc(docId).delete();

    // Delete local copy (if exists)
    await DatabaseHelper.instance.deleteStudyGroupByFirestoreId(docId);

    // Reload local state/UI
    await _loadLocalStudyGroups();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Group deleted.')));
  }


  void _showAttendees(BuildContext context, List<String> attendeeIds) {
    final usernames = attendeeIds.map((id) => _userMap[id] ?? id).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.people, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Attendees (${usernames.length})'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 300),
          child: usernames.isEmpty
              ? Center(
            child: Text(
              'No attendees yet.',
              style: TextStyle(color: Colors.grey),
            ),
          )
              : ListView.separated(
            shrinkWrap: true,
            itemCount: usernames.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade300),
            itemBuilder: (context, index) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.shade100,
                child: Icon(Icons.person, color: Colors.deepPurple),
              ),
              title: Text(
                usernames[index],
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.deepPurple)),
          ),
        ],
      ),
    );
  }


  void _openChat(String groupKey) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GroupChatScreen(groupKey: groupKey)),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return 'Unknown';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('MMM d, yyyy – h:mm a').format(dt);
    } catch (_) {
      return iso.length >= 16 ? iso.substring(0, 16) : iso;
    }
  }




  @override
  Widget build(BuildContext context) {
    Set<String> _userClassIds = _userClasses.map((c) => c.id).toSet();

    return Scaffold(
      extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight + 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                'Study Groups',
                style: TextStyle(color: Colors.white),
              ),

              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [



                AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedClassId,
                        hint: Text('Select Class (optional)'),
                        onChanged: (value) => setState(() => _selectedClassId = value),
                        items: _userClasses.map((cls) {
                          return DropdownMenuItem<String>(
                            value: cls.id,
                            child: Text(cls.name),
                          );
                        }).toList(),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Class',
                        ),
                      ),
                      SizedBox(height: 10),
                      _selectedClassId == null
                          ? TextField(
                        controller: _customTopicController,
                        decoration: InputDecoration(
                          labelText: 'Custom Topic (required if no class)',
                          border: OutlineInputBorder(),
                        ),
                      )
                          : Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Using class: ${_userClasses.firstWhere((c) => c.id == _selectedClassId).name}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                      ListTile(
                        title: Text(
                          _selectedDateTime != null
                              ? 'Session: ${DateFormat('MMM d, yyyy – h:mm a').format(_selectedDateTime!)}'
                              : 'Choose Session Time',
                        ),
                        trailing: Icon(Icons.calendar_today),
                        tileColor: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onTap: _pickDateTime,
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _createStudyGroup,
                        child: Text(
                          _currentlyEditingGroupId != null ? 'Update Study Group' : 'Create Study Group',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 5,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        if (_localGroups.isNotEmpty)
                          ..._localGroups.map((g) => Card(
                            margin: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g.topic, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 6),
                                  Text('Session: ${DateFormat('MMM d, yyyy – h:mm a').format(g.sessionTime)}'),
                                  Text('Created: ${DateFormat('MMM d, yyyy – h:mm a').format(g.createdAt)}'),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        icon: Icon(Icons.edit),
                                        label: Text('Edit'),
                                        onPressed: () {
                                          setState(() {
                                            _currentlyEditingGroupId = g.id;
                                            _selectedClassId = g.classId;
                                            _customTopicController.text = g.topic;
                                            _selectedDateTime = g.sessionTime;
                                          });
                                        },
                                      ),
                                      SizedBox(width: 12),
                                      ElevatedButton.icon(
                                          key: Key('publish_button'),
                                        icon: Icon(Icons.cloud_upload),
                                        label: Text('Publish'),
                                        onPressed: () => _publishStudyGroup(g),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          )),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: firestore.collection('study_groups').orderBy('timestamp', descending: true).snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                              final allDocs = snapshot.data!.docs;
                              final docs = allDocs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final classId = data['class_id'];
                                return classId == null || classId == "" || _userClassIds.contains(classId);
                              }).toList();

                              return ListView.builder(
                                padding: EdgeInsets.only(top: 8),
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final doc = docs[index];
                                  final data = doc.data() as Map<String, dynamic>;
                                  final docId = doc.id;
                                  final isCreator = data['creator'] == uid;
                                  final isRSVPed = (data['rsvps'] as List).contains(uid);
                                  final attendeeIds = List<String>.from(data['rsvps'] ?? []);
                                  return Card(
                                    elevation: 4,
                                    margin: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: isRSVPed ? Colors.green.shade400 : Colors.blue.shade300,
                                        width: 1.3,
                                      ),
                                    ),
                                    color: isRSVPed ? Colors.green.shade50 : Colors.blue.shade50,
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: isRSVPed ? Colors.green : Colors.indigo,
                                                child: Icon(Icons.group, color: Colors.white),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  data['topic'] ?? 'No Topic',
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Icon(Icons.schedule, size: 18, color: Colors.grey[600]),
                                              SizedBox(width: 6),
                                              Text(
                                                'Session: ${_formatDate(data['session_time'])}',
                                                style: TextStyle(color: Colors.grey[700]),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                                              SizedBox(width: 6),
                                              Text(
                                                'Created: ${_formatDate(data['timestamp'])}',
                                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              TextButton.icon(
                                                icon: Icon(Icons.people, color: Colors.deepPurple),
                                                label: Text('Attendees (${attendeeIds.length})'),
                                                onPressed: () => _showAttendees(context, attendeeIds),
                                              ),
                                              if (isRSVPed)
                                                IconButton(
                                                  icon: Icon(Icons.chat_bubble_outline, color: Colors.indigo),
                                                  onPressed: () => _openChat(docId),
                                                ),
                                            ],
                                          ),
                                          Divider(color: Colors.grey.shade300, thickness: 1, height: 20),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              if (!isCreator && isRSVPed)
                                                TextButton(
                                                  onPressed: () => _cancelRsvp(docId),
                                                  child: Text('Cancel RSVP', style: TextStyle(color: Colors.redAccent)),
                                                ),
                                              if (!isRSVPed)
                                                ElevatedButton(
                                                  onPressed: () => _rsvpToGroup(docId),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.deepPurple,
                                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  ),
                                                  child: Text(
                                                    'RSVP',
                                                    style: TextStyle(color: Colors.white), // ✅ always white
                                                  ),
                                                ),
                                              if (isCreator)
                                                TextButton(
                                                  onPressed: () => _deleteGroup(docId),
                                                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );


                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }




}

class GroupChatScreen extends StatefulWidget {
  final String groupKey;
  GroupChatScreen({required this.groupKey});

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseReference usersRef = FirebaseDatabase.instance.ref('users');
  final DatabaseReference chatRef = FirebaseDatabase.instance.ref();
  late DatabaseReference groupChatRef;
  late StreamSubscription<DatabaseEvent> _chatSubscription;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    groupChatRef = chatRef.child('study_groups/${widget.groupKey}/chat');
    _listenToChat();
  }

  void _listenToChat() {
    _chatSubscription = groupChatRef.onValue.listen((DatabaseEvent event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data != null) {
        final rawMessages = Map<String, dynamic>.from(data as Map);
        final sortedMessages = rawMessages.values
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
          ..sort((a, b) => (a['timestamp'] as String).compareTo(b['timestamp'] as String));
        setState(() {
          _messages = sortedMessages;
          _loading = false;
        });
      } else {
        setState(() {
          _messages = [];
          _loading = false;
        });
      }
    });
  }

  void _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    final message = _messageController.text.trim();
    if (user != null && message.isNotEmpty) {
      final messageRef = groupChatRef.push();

      // Get full name from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final fullName = userDoc.data()?['full_name'] ?? user.uid;

      messageRef.set({
        'sender': fullName,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _messageController.clear();
    }
  }


  @override
  void dispose() {
    _messageController.dispose();
    _chatSubscription.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade700,
              Colors.indigo.shade600,
              Colors.blue.shade300,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Group Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? Center(
                  child: Text(
                    'No messages yet',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
                    : ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isCurrentUser =
                        msg['sender'] == FirebaseAuth.instance.currentUser?.uid;
                    return Align(
                      alignment: isCurrentUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? Colors.indigo.shade100
                              : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(isCurrentUser ? 16 : 0),
                            bottomRight: Radius.circular(isCurrentUser ? 0 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['sender'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              msg['message'] ?? '',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Enter message',
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: IconButton(
                        icon: Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

}


