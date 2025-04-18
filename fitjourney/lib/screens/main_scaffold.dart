/// MainScaffold serves as the primary navigation container for the app
/// Implements bottom navigation bar and manages screen transitions
import 'package:flutter/material.dart';
import 'dart:async';
import 'home_page.dart';
import 'workouts_page.dart';
import 'progress_page.dart';
import 'goals_page.dart';
import 'profile_page.dart';
import 'package:fitjourney/widgets/notification_badge.dart';
import 'package:fitjourney/screens/notification_screen.dart';

/// Main container widget that handles navigation between primary app screens
/// Features:
/// - Bottom navigation bar
/// - Screen management
/// - Notification badge updates
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

/// State management for MainScaffold
/// Handles:
/// - Screen selection and navigation
/// - Periodic notification checks
/// - Navigation bar state
class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  Timer? _notificationTimer;

  // List of screens to navigate between
  final List<Widget> _screens = [
    const HomePage(),
    const WorkoutsPage(),
    const ProgressPage(),
    const GoalsPage(),
    const ProfilePage(),
  ];

  // Navigation item icons and labels
  final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Home',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.fitness_center_outlined),
      activeIcon: Icon(Icons.fitness_center),
      label: 'Workouts',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.bar_chart_outlined),
      activeIcon: Icon(Icons.bar_chart),
      label: 'Progress',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.flag_outlined),
      activeIcon: Icon(Icons.flag),
      label: 'Goals',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Check for new notifications every minute
    _notificationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {
        // This will trigger a rebuild of any NotificationBadge widgets
      });
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get appBar title based on selected index
    final String appBarTitle =
        ['Home', 'Workouts', 'Progress', 'Goals', 'Profile'][_selectedIndex];

    return WillPopScope(
      // Prevent back button from navigating to previous screens
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
          automaticallyImplyLeading: false,
          actions: [
            NotificationBadge(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NotificationScreen()),
                );
              },
            ),
            // Add a little spacing
            const SizedBox(width: 8),
          ],
        ),
        body: _screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: _navItems,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
