/// SignUpPage handles new user registration and account creation
/// Features:
/// - User information collection (name, email, password)
/// - Firebase Authentication integration
/// - Privacy policy and terms acceptance
/// - Email verification process
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/user.dart'; // This should define AppUser
import 'package:cloud_firestore/cloud_firestore.dart';

/// Main signup screen widget that manages user registration process
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

/// State management for SignUpPage
/// Handles:
/// - Form input validation
/// - Firebase user creation
/// - Local database user creation
/// - Navigation to verification
class _SignUpPageState extends State<SignUpPage> {
  // Controllers for form input fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // State variables
  bool _obscurePassword = true;
  bool _acceptTerms = false;
  bool _hasViewedPrivacyPolicy = false;
  bool _hasViewedTerms = false;
  bool _isRegistering = false;

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  /// Handles the user registration process
  /// Steps:
  /// 1. Validates user input
  /// 2. Creates Firebase account
  /// 3. Sends verification email
  /// 4. Creates local database entry
  /// 5. Navigates to verification screen
  Future<void> _signUp() async {
    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    // Basic validations
    if (firstName.isEmpty || lastName.isEmpty) {
      _showError("Please enter your first and last name.");
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      _showError("Email and password cannot be empty.");
      return;
    }

    // Check if user has viewed both documents
    if (!_hasViewedPrivacyPolicy || !_hasViewedTerms) {
      _showDialog("Please Review Documents",
          "You must review both the Privacy Policy and Terms of Use before continuing.");
      return;
    }

    if (!_acceptTerms) {
      _showError("You must accept the Privacy Policy and Terms of Use.");
      return;
    }

    // Show loading state
    setState(() {
      _isRegistering = true;
    });

    try {
      // Create user in Firebase
      final firebase_auth.UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Optionally update the display name
      await userCredential.user?.updateDisplayName("$firstName $lastName");

      // Send email verification
      await userCredential.user?.sendEmailVerification();

      // Retrieve the Firebase UID
      String firebaseUID = userCredential.user!.uid;

      // Create a new AppUser object for local storage
      final newUser = AppUser(
        userId: firebaseUID,
        firstName: firstName,
        lastName: lastName,
        heightCm: null, // Set if available
        registrationDate: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      // Insert the new user into SQLite
      await DatabaseHelper.instance.insertUser(newUser);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUID)
          .collection('profile')
          .doc(firebaseUID)
          .set(newUser.toMap());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Account created successfully! Please verify your email.")),
      );

      // Navigate to verification pending screen
      Navigator.pushReplacementNamed(context, '/verification-pending',
          arguments: email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showError("This email is already registered. Try logging in.");
      } else if (e.code == 'weak-password') {
        _showError("Choose a stronger password.");
      } else {
        _showError(e.message ?? "An error occurred during sign up.");
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      // Hide loading state
      setState(() {
        _isRegistering = false;
      });
    }
  }

  /// Navigates to Privacy Policy page and tracks user review
  /// Updates state to reflect policy review status
  void _navigateToPrivacyPolicy() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()));

    // Update flag when returned from the page
    if (result == true) {
      setState(() {
        _hasViewedPrivacyPolicy = true;
      });
    }
  }

  /// Navigates to Terms of Use page and tracks user review
  /// Updates state to reflect terms review status
  void _navigateToTermsOfUse() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const TermsOfUsePage()));

    // Update flag when returned from the page
    if (result == true) {
      setState(() {
        _hasViewedTerms = true;
      });
    }
  }

  /// Displays error or information dialogs to the user
  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  /// Displays error messages using a SnackBar
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
                  autofillHints: const [AutofillHints.givenName],
                  decoration: InputDecoration(
                    prefixIcon:
                        Icon(Icons.person_outline, color: Colors.grey.shade600),
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
                  autofillHints: const [AutofillHints.familyName],
                  decoration: InputDecoration(
                    prefixIcon:
                        Icon(Icons.person_outline, color: Colors.grey.shade600),
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
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    prefixIcon:
                        Icon(Icons.email_outlined, color: Colors.grey.shade600),
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
                    prefixIcon:
                        Icon(Icons.lock_outline, color: Colors.grey.shade600),
                    hintText: 'Password',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
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

              // Privacy Policy & Terms Checkbox with Clickable Links
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
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        children: [
                          const TextSpan(text: "By continuing you accept our "),
                          TextSpan(
                            text: "Privacy Policy",
                            style: const TextStyle(
                              color: Color(0xFF8AB4F8),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = _navigateToPrivacyPolicy,
                          ),
                          const TextSpan(text: " and "),
                          TextSpan(
                            text: "Terms of Use",
                            style: const TextStyle(
                              color: Color(0xFF8AB4F8),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = _navigateToTermsOfUse,
                          ),
                        ],
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
                  onPressed: _isRegistering ? null : _signUp,
                  child: _isRegistering
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
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

              // "Already have an account?" with Login navigation
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
                      Navigator.pushReplacementNamed(context, '/login');
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

/// Privacy Policy screen that displays the app's privacy policy
/// Features:
/// - Scrollable policy content
/// - Tracks user review completion
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Return true value before allowing the pop
        Navigator.of(context).pop(true);
        return false; // We're handling the pop ourselves
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Privacy Policy"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Return true to indicate the user has viewed this page
              Navigator.of(context).pop(true);
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Privacy Policy for FitJourney",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Last Updated: April 12, 2025",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "1. Introduction",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Welcome to FitJourney. We respect your privacy and are committed to protecting your personal data. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "2. Information We Collect",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We collect the following information:\n\n• Personal Information: Name, email address, and optional height measurements.\n• Workout Data: Exercise types, repetitions, sets, weights used, and workout duration.\n• Fitness Goals: Your fitness targets and progress toward them.\n• Streak Data: Information about your workout consistency and streaks.\n• Usage Information: How you interact with the app, including features used and time spent.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "3. How We Use Your Information",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We use your information to:\n\n• Provide and improve our services\n• Track your fitness progress\n• Personalize your experience\n• Sync your data between devices\n• Communicate with you about app updates",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "4. Data Storage and Syncing",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your workout data is stored both locally on your device using SQLite and in the cloud using Firebase Firestore for synchronization purposes. Your authentication information is securely managed by Firebase Authentication. Cloud syncing allows you to access your fitness data across multiple devices using the same account.\n\nYou can manage your sync preferences through the Data Synchronization settings in the app.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "5. Data Security",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We implement appropriate technical and organizational measures to protect your personal data against unauthorized or unlawful processing, accidental loss, destruction, or damage. All data synchronized to the cloud is transmitted using secure connections.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "6. Your Data Rights",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You have the right to access, correct, or delete your personal data. You can manage most of this directly within the app. To delete all your data, including cloud data, you can use the account deletion feature. ",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Terms of Use screen that displays the app's terms of service
/// Features:
/// - Scrollable terms content
/// - Tracks user review completion
class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Return true value before allowing the pop
        Navigator.of(context).pop(true);
        return false; // We're handling the pop ourselves
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Terms of Use"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Return true to indicate the user has viewed this page
              Navigator.of(context).pop(true);
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Terms of Use for FitJourney",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Last Updated: April 12, 2025",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "1. Acceptance of Terms",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "By accessing or using FitJourney, you agree to be bound by these Terms of Use. If you do not agree to these Terms, you should not use the application.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "2. User Accounts",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. You agree to notify us immediately of any unauthorized use of your account.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "3. Fitness Disclaimer",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "FitJourney is designed for tracking fitness progress only. It is not a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "4. User Data",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You retain ownership of all workout and personal data you enter into the application. By using FitJourney, you grant us permission to store and process this data both locally on your device and in the cloud as described in our Privacy Policy. This includes the synchronization of data between your devices using the same account.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "5. Cloud Synchronization",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "FitJourney offers cloud synchronization features to enhance your experience across multiple devices. By using these features, you consent to the transfer and storage of your fitness data in our cloud services, powered by Firebase.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "6. Limitations of Liability",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "While we strive to maintain continuous access to our cloud synchronization services, we are not liable for any temporary disruptions, data synchronization errors, or loss of data resulting from technical issues, scheduled maintenance, or factors beyond our control.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
