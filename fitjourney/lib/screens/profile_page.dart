import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/user.dart';
import 'package:fitjourney/screens/signup_page.dart'; // For privacy and terms pages
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AppUser? _currentUser;
  bool _isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final firebase_auth.User? user = firebase_auth.FirebaseAuth.instance.currentUser;
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

  // Navigate to the Privacy Policy page
  void _navigateToPrivacyPolicy() async {
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const PrivacyPolicyPage())
    );
  }

  // Navigate to the Terms of Use page
  void _navigateToTermsOfUse() async {
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const TermsOfUsePage())
    );
  }

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

  Future<void> _deleteAccount() async {
    // Confirm deletion
    final bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'DELETE',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirmDelete) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final firebase_auth.User? user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null) {
        //final String uid = user.uid;
        
        // TODO: Also delete data from Firestore
        
        // Delete user data from SQLite (this would need to be expanded to delete all related data)
        // This is a placeholder for actual implementation
        // Need to implement cascade deletion for all user-related data
        
        // Delete the user from Firebase Authentication
        await user.delete();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
        
        Navigator.pushReplacementNamed(context, '/login');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      setState(() {
        _isDeleting = false;
      });
      
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in again before deleting your account for security reasons.'),
          ),
        );
        await _signOut();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: ${e.message}')),
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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
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
                        firebase_auth.FirebaseAuth.instance.currentUser?.email ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
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
                          : const Icon(Icons.delete_forever, color: Colors.red, size: 20),
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
        ),
      ),
    );
  }
}