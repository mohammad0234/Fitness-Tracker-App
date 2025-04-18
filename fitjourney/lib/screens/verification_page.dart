/// VerificationPendingPage handles the email verification process
/// Features:
/// - Display verification instructions
/// - Resend verification email
/// - Navigation back to login
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// Screen shown while waiting for email verification
/// Provides options to resend verification email or return to login
class VerificationPendingPage extends StatefulWidget {
  const VerificationPendingPage({super.key});

  @override
  State<VerificationPendingPage> createState() =>
      _VerificationPendingPageState();
}

/// State management for VerificationPendingPage
/// Handles:
/// - Email verification status
/// - Resend email functionality
/// - Navigation control
class _VerificationPendingPageState extends State<VerificationPendingPage> {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  bool _isSendingEmail = false;

  /// Resends the verification email to the user
  /// Handles error cases and updates UI state during the process
  Future<void> _resendVerificationEmail() async {
    if (_isSendingEmail) return;

    setState(() {
      _isSendingEmail = true;
    });

    try {
      firebase_auth.User? user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification email resent.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Please log in to resend verification email.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() {
        _isSendingEmail = false;
      });
    }
  }

  /// Signs out the current user and returns to login screen
  /// Clears the authentication state before navigation
  void _backToLogin() async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    // Get the email from arguments
    final email = ModalRoute.of(context)?.settings.arguments as String? ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Email icon
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 80,
                  color: Colors.blue.shade300,
                ),
                const SizedBox(height: 30),

                // Title
                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'We\'ve sent a verification link to:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Email display
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // Instructions
                Text(
                  'Please check your inbox and click the verification link to complete your registration.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Resend button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.blue.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed:
                        _isSendingEmail ? null : _resendVerificationEmail,
                    child: _isSendingEmail
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Resend Verification Email',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Back to login button
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
                    onPressed: _backToLogin,
                    child: const Text(
                      'Back to Login',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
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
}
