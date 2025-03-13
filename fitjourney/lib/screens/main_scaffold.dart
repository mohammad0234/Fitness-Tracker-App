import 'package:flutter/material.dart';
import 'home_page.dart';
import 'progress_page.dart';
import 'workouts_page.dart';
import 'goals_page.dart';
import 'profile_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  
  // List of screens to navigate between
  final List<Widget> _screens = [
    const HomePage(),
    const ProgressPage(),
    const WorkoutsPage(),
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
      icon: Icon(Icons.bar_chart_outlined),
      activeIcon: Icon(Icons.bar_chart),
      label: 'Progress',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.fitness_center_outlined),
      activeIcon: Icon(Icons.fitness_center),
      label: 'Workouts',
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}