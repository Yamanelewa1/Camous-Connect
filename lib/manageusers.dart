import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageUsersPage extends StatefulWidget {
  @override
  _ManageUsersPageState createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String? _currentUserRole;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();
  }

  void _fetchCurrentUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _currentUserRole = data?['role'];
          _currentUserId = uid;
        });
      }
    }
  }

  Stream<QuerySnapshot> getUsersStream() {
    return FirebaseFirestore.instance.collection('users').snapshots();
  }

  void _updateRole(String uid, String newRole) async {
    if (uid == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You cannot change your own role.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'role': newRole,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role updated to $newRole')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _toggleBanStatus(String uid, bool currentStatus) async {
    if (uid == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You cannot ban or unban yourself.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'banned': !currentStatus,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(currentStatus ? 'User unbanned' : 'User banned')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Widget _buildRoleBadge(String role) {
    Color color = role == 'admin'
        ? Colors.orange
        : role == 'senior_admin'
        ? Colors.purple
        : Colors.green;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(role.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Users'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade400, Colors.blue.shade200],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or email',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _searchText = value.toLowerCase()),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: getUsersStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || _currentUserRole == null) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final users = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['full_name']?.toLowerCase() ?? '';
                      final email = data['email']?.toLowerCase() ?? '';
                      final role = data['role'] ?? 'student';
                      if (_currentUserRole == 'admin' && role == 'senior_admin') return false;
                      return name.contains(_searchText) || email.contains(_searchText);
                    }).toList();

                    if (users.isEmpty) {
                      return Center(child: Text('No users found.'));
                    }

                    return ListView.builder(
                      padding: EdgeInsets.all(12),
                      itemCount: users.length,
                      itemBuilder: (_, index) {
                        final user = users[index];
                        final data = user.data() as Map<String, dynamic>;
                        final uid = user.id;

                        final name = data['full_name'] ?? 'Unnamed';
                        final email = data['email'] ?? 'No email';
                        final role = data['role'] ?? 'student';
                        final phone = data['phone'] ?? 'N/A';
                        final username = data['username'] ?? 'N/A';
                        final banned = data['banned'] ?? false;

                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8),
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: banned ? Colors.red.shade50 : Colors.white,
                          child: ListTile(
                            contentPadding: EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: banned ? Colors.red : Colors.deepPurple,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.bold))),
                                _buildRoleBadge(role),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                Text("Email: $email"),
                                Text("Username: $username"),
                                Text("Phone: $phone"),
                                if (banned)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text("Status: BANNED",
                                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            trailing: (_currentUserRole == 'senior_admin')
                                ? PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'Promote to Admin') _updateRole(uid, 'admin');
                                else if (value == 'Promote to Senior') _updateRole(uid, 'senior_admin');
                                else if (value == 'Demote to Student') _updateRole(uid, 'student');
                                else if (value == 'Toggle Ban') _toggleBanStatus(uid, banned);
                              },
                              itemBuilder: (_) {
                                List<PopupMenuEntry<String>> items = [];

                                if (uid != _currentUserId) {
                                  if (role != 'admin') {
                                    items.add(PopupMenuItem(value: 'Promote to Admin', child: Text('Promote to Admin')));
                                  }
                                  if (role != 'senior_admin') {
                                    items.add(PopupMenuItem(value: 'Promote to Senior', child: Text('Promote to Senior')));
                                  }
                                  if (role != 'student') {
                                    items.add(PopupMenuItem(value: 'Demote to Student', child: Text('Demote to Student')));
                                  }
                                  if (role != 'senior_admin') {
                                    items.add(PopupMenuItem(value: 'Toggle Ban', child: Text(banned ? 'Unban User' : 'Ban User')));
                                  }
                                }

                                return items;
                              },
                            )
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}