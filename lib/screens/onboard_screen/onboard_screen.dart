import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_pilot/common_widgets/app_colors.dart';
import 'package:table_pilot/services/app_flow_service.dart';

const Color _onboardPurple = Color(0xFF9B51E0);

class OnboardScreen extends StatefulWidget {
  const OnboardScreen({super.key});

  @override
  State<OnboardScreen> createState() => _OnboardScreenState();
}

class _OnboardScreenState extends State<OnboardScreen> {
  final PageController _pageController = PageController();
  final AppFlowService _appFlowService = AppFlowService();
  int _currentPage = 0;

  final List<OnboardData> _onboardPages = [
    OnboardData(
      imagePath: 'assets/onboard01.png',
      title: 'Manage Restaurant Operations',
      description:
          'Track orders, manage tables, handle reservation and restaurant operation',
    ),
    OnboardData(
      imagePath: 'assets/onboard02.png',
      title: 'Table and Reservations',
      description:
          'View table availability and accept reservations effortlessly.',
    ),
    OnboardData(
      imagePath: 'assets/onboard03.png',
      title: 'Staff management',
      description: 'Add, track and assign staff for restaurant operations',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() async {
    if (_currentPage < _onboardPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Mark intro as seen before navigating
      await _appFlowService.markIntroAsSeen();
      // Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  void _skipToLogin() async {
    // Mark intro as seen before navigating
    await _appFlowService.markIntroAsSeen();
    // Navigate to login screen
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.mainBackground,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Use LayoutBuilder to get actual available height
              final availableHeight = constraints.maxHeight;
              final responsiveImageHeight =
                  availableHeight - (availableHeight * 0.4);

              return Stack(
                children: [
                  // PageView for background images only
                  SizedBox(
                    height: availableHeight,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemCount: _onboardPages.length,
                      itemBuilder: (context, index) {
                        return SizedBox(
                          width: screenWidth,
                          height: responsiveImageHeight,
                          child: Image.asset(
                            _onboardPages[index].imagePath,
                            width: screenWidth,
                            height: responsiveImageHeight,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: AppColors.mainBackground,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  // Content overlay at the bottom (static)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 40),
                          // Title
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _onboardPages[_currentPage].title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 24 : 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Description
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _onboardPages[_currentPage].description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: isSmallScreen ? 13 : 15,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Pagination indicators
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _onboardPages.length,
                              (indicatorIndex) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: _buildIndicator(
                                  isActive: indicatorIndex == _currentPage,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Previous and Next buttons
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _currentPage > 0
                                ? Row(
                                    children: [
                                      // Previous button
                                      Expanded(
                                        child: SizedBox(
                                          height: isSmallScreen ? 50 : 56,
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                color: Colors.white.withOpacity(
                                                  0.5,
                                                ),
                                                width: 2,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(28),
                                              ),
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: _previousPage,
                                            child: Text(
                                              'Previous',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: isSmallScreen
                                                    ? 16
                                                    : 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Next or Get Started button
                                      Expanded(
                                        child: SizedBox(
                                          height: isSmallScreen ? 50 : 56,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.ctaPrimary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(28),
                                              ),
                                              foregroundColor: Colors.white,
                                              elevation: 4,
                                            ),
                                            onPressed: _nextPage,
                                            child: Text(
                                              _currentPage ==
                                                      _onboardPages.length - 1
                                                  ? 'Get Started'
                                                  : 'Next',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: isSmallScreen
                                                    ? 16
                                                    : 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : SizedBox(
                                    width: double.infinity,
                                    height: isSmallScreen ? 50 : 56,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.ctaPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                        ),
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                      ),
                                      onPressed: _nextPage,
                                      child: Text(
                                        _currentPage == _onboardPages.length - 1
                                            ? 'Get Started'
                                            : 'Next',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: isSmallScreen ? 16 : 18,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          // Skip button
                          TextButton(
                            onPressed: _skipToLogin,
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 40 : 20,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? _onboardPurple : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardData {
  final String imagePath;
  final String title;
  final String description;

  OnboardData({
    required this.imagePath,
    required this.title,
    required this.description,
  });
}
