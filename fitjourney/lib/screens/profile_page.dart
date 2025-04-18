/// ProfilePage handles user profile management and account settings
/// Features:
/// - Display user profile information
/// - Data synchronization management
/// - Privacy policy and terms access
/// - Account management (sign out and deletion)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/user.dart';
import 'package:fitjourney/screens/signup_page.dart'; // For privacy and terms pages
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitjourney/widgets/sync_status_widget.dart';
import 'package:fitjourney/services/account_service.dart';

/// Main profile screen widget that displays user information and account settings
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

/// State management for ProfilePage
/// Handles:
/// - User data fetching from local and cloud storage
/// - Account operations (sign out, deletion)
/// - Navigation to settings pages
class _ProfilePageState extends State<ProfilePage> {
  AppUser? _currentUser;
  bool _isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  /// Fetches user data from SQLite first, then falls back to Firestore
  /// Updates the UI with user information when available
  Future<void> _fetchUserData() async {
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;

      // Try SQLite first
      final dbUser = await DatabaseHelper.instance.getUserById(uid);

      if (dbUser == null) {
        // If not in SQLite, try Firestore
        try {
          final docSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('profile')
              .doc(uid)
              .get();

          if (docSnapshot.exists) {
            final userData = docSnapshot.data();
            if (userData != null) {
              final appUser = AppUser(
                userId: uid,
                firstName: userData['first_name'] ?? userData['firstName'],
                lastName: userData['last_name'] ?? userData['lastName'],
                heightCm: userData['height_cm'] ?? userData['heightCm'],
                registrationDate: userData['registration_date'] != null
                    ? DateTime.parse(userData['registration_date'])
                    : (userData['registrationDate'] != null
                        ? DateTime.parse(userData['registrationDate'])
                        : null),
                lastLogin: userData['last_login'] != null
                    ? DateTime.parse(userData['last_login'])
                    : (userData['lastLogin'] != null
                        ? DateTime.parse(userData['lastLogin'])
                        : null),
              );

              // Save to SQLite for future use
              await DatabaseHelper.instance.insertUser(appUser);

              setState(() {
                _currentUser = appUser;
                _isLoading = false;
              });
              return;
            }
          }
        } catch (e) {
          print('Error fetching from Firestore: $e');
        }

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _currentUser = dbUser;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Navigates to the Privacy Policy screen
  /// Updates the UI to reflect policy acceptance
  void _navigateToPrivacyPolicy() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()));
  }

  /// Navigates to the Terms of Use screen
  /// Updates the UI to reflect terms acceptance
  void _navigateToTermsOfUse() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const TermsOfUsePage()));
  }

  /// Handles user sign out process
  /// Clears authentication state and navigates to login screen
  Future<void> _signOut() async {
    try {
      await firebase_auth.FirebaseAuth.instance.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  /// Manages the account deletion process
  /// Steps:
  /// 1. Prompts for password re-authentication
  /// 2. Verifies user identity
  /// 3. Confirms deletion intent
  /// 4. Deletes account and associated data
  Future<void> _deleteAccount() async {
    // Prompt for password re-authentication
    final bool proceedWithReauth = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Your Identity'),
              content: const Text(
                'For security reasons, please re-enter your password before deleting your account.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('CONTINUE'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!proceedWithReauth) return;

    // If proceeding, get current user and show password input
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logged in user found')),
      );
      return;
    }

    final TextEditingController passwordController = TextEditingController();
    final bool passwordEntered = await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Re-enter Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Please enter your password for ${user.email}'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('VERIFY'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!passwordEntered || passwordController.text.isEmpty) return;

    // Re-authenticate user
    try {
      // Create credential
      final firebase_auth.AuthCredential credential =
          firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: passwordController.text,
      );

      // Re-authenticate
      await user.reauthenticateWithCredential(credential);

      // Now prompt for final confirmation
      final bool confirmDelete = await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Delete Account Permanently'),
                content: const Text(
                  'WARNING: This action cannot be undone. All your data will be permanently deleted from both your device and our servers.\n\nAre you absolutely sure you want to delete your account?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'DELETE PERMANENTLY',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!confirmDelete) return;

      setState(() {
        _isDeleting = true;
      });

      // Use the account service to handle deletion
      final result = await AccountService.instance.deleteAccount();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );

      // Navigate to login screen
      Navigator.pushReplacementNamed(context, '/login');
    } on firebase_auth.FirebaseAuthException catch (e) {
      setState(() {
        _isDeleting = false;
      });

      if (e.code == 'wrong-password') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Incorrect password. Please try again.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication error: ${e.message}')),
        );
      }
    } catch (e) {
      setState(() {
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sync status indicator at the top
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const SyncStatusWidget(),
            ],
          ),
          const SizedBox(height: 24),

          if (_currentUser != null) ...[
            // Profile header with avatar and name
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      '${_currentUser!.firstName[0]}${_currentUser!.lastName[0]}',
                      style: const TextStyle(
                        fontSize: 30,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_currentUser!.firstName} ${_currentUser!.lastName}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    firebase_auth.FirebaseAuth.instance.currentUser?.email ??
                        '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Add sync status section before settings
            const SizedBox(height: 16),
            const Text(
              'Data Synchronization',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const SyncStatusWidget(showDetailedStatus: true),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Manage Data Sync'),
              onPressed: () => Navigator.pushNamed(context, '/sync-management'),
            ),

            // Settings section
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Privacy & Legal section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // Privacy Policy
                  ListTile(
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _navigateToPrivacyPolicy,
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),

                  // Terms of Use
                  ListTile(
                    title: const Text('Terms of Use'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _navigateToTermsOfUse,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Account section
            const Text(
              'Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Sign Out button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Sign Out'),
                    trailing: const Icon(Icons.logout, size: 20),
                    onTap: _signOut,
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),

                  // Delete Account
                  ListTile(
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.red),
                    ),
                    trailing: _isDeleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_forever,
                            color: Colors.red, size: 20),
                    onTap: _isDeleting ? null : _deleteAccount,
                  ),
                ],
              ),
            ),
          ] else ...[
            const Center(
              child: Text('User profile not available'),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
