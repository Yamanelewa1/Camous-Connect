import 'package:campusconnect/manage_eventpage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:campusconnect/manageclassespage.dart';
import 'package:campusconnect/managecalander.dart';
import 'package:campusconnect/home_page.dart';
import 'package:campusconnect/manageusers.dart';
import 'package:campusconnect/AdminSupportDashboard.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String username = "";

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  void _loadAdminData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() {
          username = doc.data()?['username'] ?? 'Admin';
        });
      }
    }
  }

  Widget _buildDashboardButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 26, color: Colors.white),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(label, style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        backgroundColor: Colors.indigo,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade700, Colors.indigo.shade200],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $username!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 10),
              Text(
                'Manage your campus data below:',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              SizedBox(height: 30),
              _buildDashboardButton(
                label: 'Manage Classes',
                icon: Icons.class_,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => ManageClassesPage()),
                  );
                },
              ),
              _buildDashboardButton(
                label: 'Manage Campus Events',
                icon: Icons.event,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => AdminManageEventsScreen()),
                  );
                },
              ),
              _buildDashboardButton(
                label: 'Manage Users',
                icon: Icons.people,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => ManageUsersPage()),
                  );
                },
              ),
              _buildDashboardButton(
                label: 'Create Semester Calendar',
                icon: Icons.calendar_today,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => AdminCreateCalendarScreen()),
                  );
                },
              ),
              _buildDashboardButton(
                label: 'Support Tickets',
                icon: Icons.support_agent,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => AdminSupportDashboard()),
                  );
                },
              ),
              _buildDashboardButton(
                label: 'Go to Home Page',
                icon: Icons.home,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => HomePage()),
                  );
                },
              ),
              SizedBox(height: 20),
              Divider(color: Colors.white70),
              _buildDashboardButton(
                label: 'Sign Out',
                icon: Icons.logout,
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushReplacementNamed('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
