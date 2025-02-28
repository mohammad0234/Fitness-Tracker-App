import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model class representing the data for each onboarding page.
class OnboardingPageData {
  final String image;
  final String title;
  final String description;

  OnboardingPageData({
    required this.image,
    required this.title,
    required this.description,
  });
}

/// The main onboarding screen that displays a series of pages.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  /// Controller for handling page transitions.
  final PageController _pageController = PageController();

  /// Current index of the onboarding page.
  int currentIndex = 0;

  /// List of onboarding pages.
  final List<OnboardingPageData> pages = [
    OnboardingPageData(
      image: 'assets/images/onboarding1.png',
      title: 'Welcome To FitJourney',
      description: "Your all-in-one fitness companion. Let's get you started on a healthier, stronger path!",
    ),
    OnboardingPageData(
      image: 'assets/images/onboarding2.png',
      title: 'Track Your Progress',
      description: "Effortlessly log workouts, monitor results, celebrate milestones and watch your performance improve day by day.",
    ),
    OnboardingPageData(
      image: 'assets/images/onboarding3.png',
      title: 'Consistency is Key',
      description: "Set goals, build healthy habits, stay motivated and never lose momentum on your journey to peak fitness.",
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Navigates directly to the last onboarding page.
  void _onSkipPressed() {
    _pageController.animateToPage(
      pages.length - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Advances to the next onboarding page or completes onboarding.
  void _onNextPressed() async {
    if (currentIndex < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Set the flag indicating onboarding has been seen.
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seenOnboarding', true);
      // Navigate to the sign-up screen (or directly to home if desired)
      Navigator.pushReplacementNamed(context, '/signup');
    }
  }

  /// Builds a single onboarding page.
  Widget _buildOnboardingPage(OnboardingPageData data) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular container with the onboarding image.
            Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.asset(
                  data.image,
                  fit: BoxFit.contain,
                  semanticLabel: data.title, // Accessibility support
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Title text.
            Text(
              data.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Description text.
            Text(
              data.description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top row with the "Skip" button.
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (currentIndex < pages.length - 1)
                    TextButton(
                      onPressed: _onSkipPressed,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // PageView for displaying onboarding pages.
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildOnboardingPage(pages[index]);
                },
              ),
            ),
            // Dots indicator and navigation button.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  // Dots indicator.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: currentIndex == index ? 12 : 8,
                        height: currentIndex == index ? 12 : 8,
                        decoration: BoxDecoration(
                          color: currentIndex == index ? Colors.pinkAccent : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Next/Get Started button.
                  ElevatedButton(
                    onPressed: _onNextPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    ),
                    child: Text(
                      currentIndex == pages.length - 1 ? 'Get Started' : 'Next',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
