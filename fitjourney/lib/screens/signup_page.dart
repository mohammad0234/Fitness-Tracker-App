import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // Controllers for text fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController  = TextEditingController();
  final TextEditingController _emailController     = TextEditingController();
  final TextEditingController _passwordController  = TextEditingController();

  // UI state variables
  bool _obscurePassword = true;
  bool _acceptTerms = false;

  // FirebaseAuth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Attempts to sign up the user using Firebase Authentication.
  Future<void> _signUp() async {
    final String firstName = _firstNameController.text.trim();
    final String lastName  = _lastNameController.text.trim();
    final String email     = _emailController.text.trim();
    final String password  = _passwordController.text.trim();

    // Basic validation checks.
    if (firstName.isEmpty || lastName.isEmpty) {
      _showError("Please enter your first and last name.");
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      _showError("Email and password cannot be empty.");
      return;
    }
    if (!_acceptTerms) {
      _showError("You must accept the Privacy Policy and Terms of Use.");
      return;
    }

    try {
      // Create a new user with email and password.
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Optionally update the user's displayName.
      await userCredential.user?.updateDisplayName("$firstName $lastName");

      // Inform the user and navigate to HomePage.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created successfully!")),
      );
      Navigator.pushReplacementNamed(context, '/home');
      
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "An error occurred during sign up.");
    } catch (e) {
      _showError(e.toString());
    }
  }

  /// Displays an error message in a SnackBar.
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
              // Header text
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
                'Create an Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 25),

              // First Name Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TextField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade600),
                    hintText: 'First Name',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Last Name Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TextField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade600),
                    hintText: 'Last Name',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Email Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
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
              const SizedBox(height: 20),

              // Privacy Policy & Terms Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _acceptTerms,
                      onChanged: (val) {
                        setState(() {
                          _acceptTerms = val ?? false;
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "By continuing you accept our Privacy Policy and Terms of Use",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 45),

              // Register Button
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
                  onPressed: () async {
                    await _signUp();
                  },
                  child: const Text(
                    'Register',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Login Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    child: const Text(
                      "Login",
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
