import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/database/database_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for email and password input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoggingIn = false;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  
  /// Attempts to sign in the user using Firebase Authentication
  /// and updates the user's last login timestamp in SQLite.
  Future<void> _login() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    
    if (email.isEmpty || password.isEmpty) {
      _showError("Email and password cannot be empty.");
      return;
    }
    
    setState(() {
      _isLoggingIn = true;
    });
    
    try {
      // Sign in with Firebase Authentication
      firebase_auth.UserCredential userCredential = 
          await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // Check if email is verified
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        _showError("Please verify your email before logging in.");
        // Navigate to verification pending page
        Navigator.pushReplacementNamed(
          context, 
          '/verification-pending', 
          arguments: email
        );
        return;
      }
      
      // Retrieve the Firebase UID
      String firebaseUID = userCredential.user!.uid;
      
      // Update the last login timestamp in the local SQLite database
      await DatabaseHelper.instance.updateUserLastLogin(firebaseUID);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login successful!")),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showError("No account found with this email.");
      } else if (e.code == 'wrong-password') {
        _showError("Incorrect password. Try again.");
      } else if (e.code == 'invalid-email') {
        _showError("Invalid email format.");
      } else {
        _showError(e.message ?? "Login failed. Please try again.");
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() {
        _isLoggingIn = false;
      });
    }
  }
  
  /// Sends a password reset email.
  void _resetPassword() async {
    final String email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError("Enter your email to reset password.");
      return;
    }
    
    try {
      await _auth.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent! Check your inbox.")),
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      _showError(e.message ?? "Password reset failed.");
    }
  }
  
  /// Displays an error message using a SnackBar.
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hey there,',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 25),
              
              // Email Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade600),
                    hintText: 'Email',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Password Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade600),
                    hintText: 'Password',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey.shade600,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
              ),
              
              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _resetPassword,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot your password?',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 120),
              
              // Login Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8AB4F8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: _isLoggingIn ? null : _login,
                  child: _isLoggingIn
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ),
              ),
              const SizedBox(height: 25),
              
              // "Don't have an account?" with Sign Up navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/signup');
                    },
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(
                        color: Color(0xFF8AB4F8),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}