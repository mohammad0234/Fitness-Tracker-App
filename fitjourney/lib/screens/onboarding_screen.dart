import 'package:flutter/material.dart';

/// Model class representing the data structure for each onboarding page.
/// Each page consists of an image, title, and description.
class OnboardingPageData {
  final String image;
  final String title;
  final String description;

  /// Constructor for the OnboardingPageData model.
  /// The `required` keyword ensures that all fields must be provided when creating an instance.
  OnboardingPageData({
    required this.image,
    required this.title,
    required this.description,
  });
}

/// The main onboarding screen that displays a series of onboarding pages.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// The state class that manages the behavior and UI of the onboarding screen.
class _OnboardingScreenState extends State<OnboardingScreen> {
  /// PageController to handle page transitions within the PageView.
  final PageController _pageController = PageController();

  /// Tracks the index of the currently displayed onboarding page.
  int currentIndex = 0;

  /// List of onboarding pages containing their respective image, title, and description.
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

  /// Skips directly to the last onboarding page when "Skip" is pressed.
  void _onSkipPressed() {
    _pageController.animateToPage(
      pages.length - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Advances to the next onboarding page or navigates to the sign-up screen on the last page.
  void _onNextPressed() {
    if (currentIndex < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Navigates to the sign-up screen once onboarding is complete
      Navigator.pushReplacementNamed(context, '/signup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// Background color of the onboarding screen.
      backgroundColor: const Color(0xFFE0F7FA),
      body: SafeArea(
        child: Column(
          children: [
            /// Top row containing the "Skip" button.
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Only show the Skip button if we are not on the last page
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

            /// PageView to display onboarding pages with horizontal scrolling.
            Expanded(
              child: PageView.builder(
                controller: _pageController, // Controller for page transitions
                itemCount: pages.length, // Number of pages in onboarding
                onPageChanged: (index) {
                  setState(() {
                    currentIndex = index; // Updates the current index for indicators
                  });
                },
                itemBuilder: (context, index) {
                  return _buildOnboardingPage(pages[index]);
                },
              ),
            ),

            /// Page indicator dots and navigation button (Next / Get Started).
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  /// Dots to indicate the current page position.
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

                  /// Navigation button that changes behavior on the last page.
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
                      // Changes text to "Get Started" on the last page
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
            /// Circular container to display the onboarding image.
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

            /// Title of the onboarding page.
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

            /// Description of the onboarding page.
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
