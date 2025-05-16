import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _fullNameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  List<String> _notes = [];

  bool _loading = true;
  bool _editing = false;
  XFile? _pickedImage;
  String? _base64Image;
  late String uid;
  String? _role;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
      return;
    }
    uid = user.uid;
    _loadProfile();
    _loadNotes();
  }

  Future<void> _loadProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null) {
      _fullNameCtrl.text = data['full_name'] ?? '';
      _ageCtrl.text = data['age']?.toString() ?? '';
      _phoneCtrl.text = data['phone'] ?? '';
      _base64Image = data['profile_image'] as String?;
      _role = data['role'] ?? 'student';
    }
    setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      setState(() {
        _pickedImage = image;
        _base64Image = base64Encode(bytes);
      });
    }
  }

  Future<void> _saveProfile() async {
    final fullName = _fullNameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    final phone = _phoneCtrl.text.trim();

    Map<String, dynamic> updateData = {
      'full_name': fullName,
      'age': age,
      'phone': phone,
    };

    if (_pickedImage != null) {
      final bytes = await File(_pickedImage!.path).readAsBytes();
      updateData['profile_image'] = base64Encode(bytes);
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).set(updateData, SetOptions(merge: true));

    setState(() {
      _editing = false;
      _pickedImage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile updated')));
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('notes_${uid}') ?? [];
    setState(() => _notes = saved);
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notes_${uid}', _notes);
  }

  void _showNotesDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Your Notes'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _notes.length,
              itemBuilder: (context, index) => Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                color: Colors.grey[100],
                child: ListTile(
                  title: Text(_notes[index]),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.deepPurple),
                        onPressed: () async {
                          final edited = await _editNoteDialog(_notes[index]);
                          if (edited != null) {
                            setState(() => _notes[index] = edited);
                            setStateDialog(() {});
                            _saveNotes();
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => _notes.removeAt(index));
                          setStateDialog(() {});
                          _saveNotes();
                        },
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.note_add),
              label: Text("Add Note"),
              onPressed: () async {
                final newNote = await _editNoteDialog('');
                if (newNote != null && newNote.trim().isNotEmpty) {
                  setState(() => _notes.add(newNote.trim()));
                  setStateDialog(() {});
                  _saveNotes();
                }
              },
            ),
            TextButton(
              child: Text("Close"),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        ),
      ),
    );
  }

  Future<String?> _editNoteDialog(String initialText) async {
    final ctrl = TextEditingController(text: initialText);
    return await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit Note'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: 'Enter your note...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: Text('Save')),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value, style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _input(TextEditingController c, String label, TextInputType type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          fillColor: Colors.white,
          filled: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final email = FirebaseAuth.instance.currentUser!.email ?? '';
    ImageProvider? avatar;
    if (_pickedImage != null) {
      avatar = FileImage(File(_pickedImage!.path));
    } else if (_base64Image != null && _base64Image!.isNotEmpty) {
      avatar = MemoryImage(base64Decode(_base64Image!));
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(130),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade900, Colors.deepPurple.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          padding: EdgeInsets.only(left: 20, right: 20, top: 50, bottom: 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Your Profile", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
                  SizedBox(height: 4),
                  Text("Manage your information & settings", style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: avatar,
                            backgroundColor: Colors.grey.shade300,
                            child: avatar == null
                                ? Icon(Icons.person, size: 60, color: Colors.grey.shade700)
                                : null,
                          ),
                          if (_editing)
                            Positioned(
                              bottom: 0,
                              right: 4,
                              child: CircleAvatar(
                                backgroundColor: Colors.white,
                                child: IconButton(
                                  icon: Icon(Icons.camera_alt_rounded, color: Colors.deepPurple),
                                  onPressed: _pickPhoto,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 24),
                      _editing
                          ? Column(
                        children: [
                          _input(_fullNameCtrl, 'Full Name', TextInputType.text),
                          _input(_ageCtrl, 'Age', TextInputType.number),
                          _input(_phoneCtrl, 'Phone', TextInputType.phone),
                        ],
                      )
                          : Column(
                        children: [
                          _infoCard(Icons.person, 'Full Name', _fullNameCtrl.text),
                          _infoCard(Icons.cake, 'Age', _ageCtrl.text),
                          _infoCard(Icons.phone, 'Phone', _phoneCtrl.text),
                          _infoCard(Icons.email, 'Email', email),
                        ],
                      ),
                      SizedBox(height: 30),
                      ElevatedButton.icon(
                        icon: Icon(_editing ? Icons.save_rounded : Icons.edit_rounded),
                        label: Text(_editing ? 'Save Profile' : 'Edit Profile'),
                        onPressed: _editing ? _saveProfile : () => setState(() => _editing = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade700,
                          foregroundColor: Colors.white,
                          elevation: 5,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showNotesDialog,
                            icon: Icon(Icons.menu_book_rounded),
                            label: Text("Notes"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _logout,
                            icon: Icon(Icons.logout_rounded),
                            label: Text("Logout"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_role == 'admin' || _role == 'senior_admin')

                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/AdminDashboard'),
                          icon: Icon(Icons.dashboard_customize),
                          label: Text("Admin Dashboard"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
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