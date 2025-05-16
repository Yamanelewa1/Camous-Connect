import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminSupportDashboard extends StatefulWidget {
  const AdminSupportDashboard({super.key});

  @override
  State<AdminSupportDashboard> createState() => _AdminSupportDashboardState();
}

class _AdminSupportDashboardState extends State<AdminSupportDashboard> {
  String? _role;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  Future<void> _checkAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _role = doc.data()?['role'];
        _loading = false;
      });
    } else {
      setState(() {
        _role = null;
        _loading = false;
      });
    }
  }

  bool get isAdmin => _role == 'admin' || _role == 'senior_admin';
  bool get isSeniorAdmin => _role == 'senior_admin';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text('Access Denied')),
        body: Center(child: Text('You are not authorized.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Support Requests'),
        backgroundColor: Colors.indigo,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0EAFc), Color(0xFFF3F6FD)], // Light blue-gray gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('support_requests')
              .where('completed', isEqualTo: false)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return Center(child: Text('No open support requests.'));

            return ListView.builder(
              itemCount: docs.length,
              padding: EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final id = doc.id;

                final subject = data['subject'] ?? 'No subject';
                final email = data['email'] ?? 'Unknown';
                final message = data['message'] ?? '';
                final response = data['response'] ?? '';
                final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                final formattedDate = timestamp != null
                    ? DateFormat('d MMM y – hh:mm a').format(timestamp)
                    : 'Unknown';

                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subject, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('From: $email', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                            Text(formattedDate, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                        Divider(height: 24),
                        Text('Message:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 6),
                        Text(message),
                        if (response.isNotEmpty) ...[
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Response:',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
                                SizedBox(height: 4),
                                Text(response, style: TextStyle(color: Colors.green[800])),
                              ],
                            ),
                          ),
                        ],
                        if (isSeniorAdmin) ...[
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                icon: Icon(Icons.reply, color: Colors.white),
                                label: Text('Reply', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _showResponseDialog(context, id, response),
                              ),
                              SizedBox(width: 12),
                              OutlinedButton.icon(
                                icon: Icon(Icons.check_circle, color: Colors.green),
                                label: Text('Done'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.green),
                                  foregroundColor: Colors.green[800],
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('support_requests')
                                      .doc(id)
                                      .update({'completed': true});
                                },
                              ),
                            ],
                          ),
                        ]
                      ],
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

  void _showResponseDialog(BuildContext context, String docId, String currentResponse) {
    final controller = TextEditingController(text: currentResponse);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Respond to Support Request'),
        content: TextFormField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Enter your response...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final response = controller.text.trim();
              if (response.isEmpty) return;

              await FirebaseFirestore.instance
                  .collection('support_requests')
                  .doc(docId)
                  .update({
                'response': response,
                'responseTimestamp': FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
            },
            child: Text('Send'),
          ),
        ],
      ),
    );
  }
}
