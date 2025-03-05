import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:fitjourney/database/database_helper.dart';
import 'package:fitjourney/database_models/user.dart'; // This file defines AppUser

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppUser? _currentUser; // Holds the fetched user from SQLite
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  /// Fetches the current user's data from SQLite using the Firebase UID
  Future<void> _fetchUserData() async {
    final firebase_auth.User? user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final dbUser = await DatabaseHelper.instance.getUserById(uid);
      setState(() {
        _currentUser = dbUser;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      // In case no user data is found
      return Scaffold(
        appBar: AppBar(title: const Text("FitJourney")),
        body: const Center(child: Text("No user data found.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("FitJourney")),
      body: Center(
        child: Text(
          "Welcome to FitJourney, ${_currentUser!.firstName} ${_currentUser!.lastName}!",
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
