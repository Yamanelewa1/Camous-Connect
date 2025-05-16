import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:campusconnect/contactsupport.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 900),
    );
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeInOutBack);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  void login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final credentials = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailCtrl.text.trim(),
          password: passwordCtrl.text.trim(),
        );

        final uid = credentials.user!.uid;
        final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();

        if (!snapshot.exists) {
          throw FirebaseAuthException(code: 'user-data-not-found', message: 'User data not found.');
        }

        final userData = snapshot.data()!;
        final role = userData['role'] ?? 'student';
        final isBanned = userData['banned'] ?? false;

        if (isBanned) {
          await FirebaseAuth.instance.signOut();
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('Access Denied'),
              content: Text('Your account has been banned. Contact the Administrator.'),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('OK'))],
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        Navigator.pushReplacementNamed(
          context,
          (role == 'admin' || role == 'senior_admin') ? '/AdminDashboard' : '/home',
        );
      } on FirebaseAuthException catch (e) {
        String message;
        switch (e.code) {
          case 'user-not-found':
          case 'wrong-password':
          case 'invalid-email':
            message = 'Invalid email or password.';
            break;
          case 'user-disabled':
            message = 'This account has been disabled.';
            break;
          case 'user-data-not-found':
            message = 'There is no account found.';
            break;
          default:
            message = 'Invalid email or password.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred.')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: screenHeight * 0.18,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade700, Colors.blue.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Center(
                child: Text(
                  'CampusConnect',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            SizedBox(height: 30),
            ScaleTransition(
              scale: _scaleAnimation,
              child: Image.asset('assets/CC+main+logo.png', width: 180, height: 180),
            ),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildInputField(
                      key: Key('email_field'), // ✅ For integration test
                      controller: emailCtrl,
                      label: 'Email',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                      (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    SizedBox(height: 16),
                    _buildInputField(
                      key: Key('password_field'), // ✅ For integration test
                      controller: passwordCtrl,
                      label: 'Password',
                      icon: Icons.lock,
                      obscure: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (value) =>
                      (value == null || value.length < 6) ? 'Min. 6 characters' : null,
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: Key('login_button'), // ✅ For integration test
                        onPressed: _isLoading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('Login', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup_page'),
                      child: Text(
                        'Don\'t have an account? Sign up',
                        style: TextStyle(
                            color: Colors.indigo, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/reset_password'),
                      child: Text(
                        'Forgot password? Reset here',
                        style: TextStyle(
                            color: Colors.indigo, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ContactSupportPage()),
        ),
        child: Icon(Icons.support_agent, color: Colors.white),
        tooltip: 'Contact Support',
      ),
    );
  }

  Widget _buildInputField({
    required Key key, // ✅ Accept key
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: TextFormField(
        key: key, // ✅ Apply key
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.indigo),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
