import 'package:flutter/material.dart';

/// Model class representing a single onboarding page.
class OnboardingPageData {
  final String image;
  final String title;
  final String description;

  /// Constructor for OnboardingPageData
  OnboardingPageData({
    required this.image,
    required this.title,
    required this.description,
  });
}

/// Stateful widget that manages the onboarding screen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController(); // Controller for PageView
  int currentIndex = 0; // Tracks the current page index

  /// List of onboarding pages with associated images, titles, and descriptions.
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

  /// Skips the onboarding flow by jumping directly to the last page.
  void _onSkipPressed() {
    _pageController.animateToPage(
      pages.length - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Moves to the next page or navigates to the sign-up screen if on the last page.
  void _onNextPressed() {
    if (currentIndex < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Last page => Navigate to the sign-up or home screen
      Navigator.pushReplacementNamed(context, '/signup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F7FA), // Light pastel background
      body: SafeArea(
        child: Column(
          children: [
            /// Top row with the 'Skip' button (only visible if not on the last page)
            Row(
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
                const SizedBox(width: 16),
              ],
            ),

            /// Main PageView widget for onboarding slides
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

            /// Page indicator (dots) and Next/Get Started button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  /// Dot indicators to represent current onboarding step
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
                          color: currentIndex == index
                              ? Colors.pinkAccent // Active dot color
                              : Colors.grey, // Inactive dot color
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  /// Next / Get Started button
                  ElevatedButton(
                    onPressed: _onNextPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent, // Button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 14,
                      ),
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

  /// Builds a single onboarding page with an image, title, and description.
  Widget _buildOnboardingPage(OnboardingPageData data) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// Circular container to display onboarding images
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
                ),
              ),
            ),
            const SizedBox(height: 24),

            /// Title text
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

            /// Description text
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
}
