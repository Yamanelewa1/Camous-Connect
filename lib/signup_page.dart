import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final adminCodeCtrl = TextEditingController();
  final fullNameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final ageCtrl = TextEditingController();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final String secretAdminCode = 'CCADMIN123';
  final String seniorAdminCode = 'CCSUPERADMIN999';


  File? _pickedImage;
  String? _base64Image;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedImage = file;
        _base64Image = base64Encode(bytes);
      });
    }
  }

  void signup() async {
    if (_formKey.currentState!.validate()) {
      if (passwordCtrl.text != confirmCtrl.text) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwords do not match')));
        return;
      }

      try {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailCtrl.text.trim(),
          password: passwordCtrl.text.trim(),
        );
        final uid = credential.user!.uid;

        final code = adminCodeCtrl.text.trim();
        final role = code == seniorAdminCode
            ? 'senior_admin'
            : code == secretAdminCode
            ? 'admin'
            : 'student';

        await firestore.collection('users').doc(uid).set({
          'email': emailCtrl.text.trim(),
          'username': emailCtrl.text.trim().split('@')[0],
          'role': role,
          'full_name': fullNameCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
          'age': int.tryParse(ageCtrl.text.trim()) ?? 0,
          'profile_image': _base64Image ?? '',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$role account created!')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signup failed: ${e.toString()}')),
        );
      }
    }
  }


  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmCtrl.dispose();
    adminCodeCtrl.dispose();
    fullNameCtrl.dispose();
    phoneCtrl.dispose();
    ageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade700, Colors.blue.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade700, Colors.blue.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'CampusConnect Sign Up',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      SizedBox(width: 48), // reserve space to balance the back icon
                    ],
                  ),
                ),


                SizedBox(height: 16),

                // Form Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6))
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.indigo.shade100,
                              backgroundImage: _pickedImage != null ? FileImage(_pickedImage!) : null,
                              child: _pickedImage == null
                                  ? Icon(Icons.person, size: 50, color: Colors.grey)
                                  : null,
                            ),
                          ),
                          TextButton(
                            onPressed: _pickImage,
                            child: Text("Upload Profile Picture"),
                          ),

                          _buildInput(fullNameCtrl, 'Full Name'),
                          _buildInput(ageCtrl, 'Age', keyboardType: TextInputType.number),
                          _buildInput(phoneCtrl, 'Phone Number', keyboardType: TextInputType.phone),
                          _buildInput(emailCtrl, 'Email', keyboardType: TextInputType.emailAddress),
                          _buildInput(passwordCtrl, 'Password', obscure: true),
                          _buildInput(confirmCtrl, 'Confirm Password', obscure: true),
                          _buildInput(adminCodeCtrl, 'Admin Code (optional)', hint: 'Enter if you are an admin'),

                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: signup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text('Sign Up',
                                  style: TextStyle(fontSize: 16, color: Colors.white)),
                            ),
                          ),
                          SizedBox(height: 10),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                            child: Text(
                              'Already have an account? Login',
                              style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildInput(TextEditingController controller, String label,
      {String? hint, bool obscure = false, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: (value) {
          if (label.contains('Password') && (value == null || value.length < 6)) {
            return 'Minimum 6 characters';
          }
          if ((label == 'Email' && (value == null || !value.contains('@'))) ||
              (label != 'Admin Code (optional)' && value!.isEmpty)) {
            return 'Please enter $label';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
      ),
    );
  }
}
