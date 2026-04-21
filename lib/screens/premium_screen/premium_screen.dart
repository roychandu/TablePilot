// ignore_for_file: deprecated_member_use, unused_element

import 'package:table_pilot/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:table_pilot/provider/purchase_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';

class PremiumScreen extends StatefulWidget {
  PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InAppPurchaseProvider>(
      builder: (context, inAppPurchaseProvider, child) {
        return Scaffold(
          backgroundColor: AppColors.mainBackground,
          body: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _BackButton(
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      SizedBox(height: 24),
                      Center(
                        child: Text(
                          'Upgrade Now',
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w800,
                            fontSize: 26,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Go Pro. Remove Ads. Boost\nProductivity.',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 10),
                      Center(
                        child: SizedBox(
                          width: 260,
                          height: 240,
                          child: Image.asset(
                            'assets/premium.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Enjoy a faster, distraction-free\nmanagement experience',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.white,
                          height: 1.4,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'All in just....',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '\$0.99',
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.warning,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 24),
                      if (!inAppPurchaseProvider.isPremiumMember)
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                isLoading = true;
                              });
                              inAppPurchaseProvider
                                  .buyNONConsumableInAppPurchase();
                              setState(() {
                                isLoading = false;
                              });
                              // _handleUpgrade();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Upgrade Now',
                              style: AppTextStyles.buttonLarge.copyWith(
                                color: AppColors.black,
                              ),
                            ),
                          ),
                        ),
                      if (inAppPurchaseProvider.isPremiumMember)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'You are already a premium member',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                          });
                          inAppPurchaseProvider.restorePurchases();
                          setState(() {
                            isLoading = false;
                          });
                        },
                        child: Center(
                          child: Text(
                            'Restore Purchase',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.white,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 28),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: AppColors.primary, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleUpgrade() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        content: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
    );

    try {
      // Simulate purchase process
      await Future.delayed(Duration(seconds: 2));

      // Activate premium membership in both AuthService and InAppPurchaseProvider
      await AuthService().updatePremiumStatus(true);

      // Also update the InAppPurchaseProvider's SharedPreferences key
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_purchased', true);

      if (!mounted) return;

      Navigator.pop(context); // Close loading dialog

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text(
                'Premium \nActivated!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.star, color: AppColors.primary, size: 24),
            ],
          ),
          content: Text(
            'Congratulations! You now have access to unlimited memories and all premium features.',
            style: TextStyle(color: AppColors.text2),
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                // Close success dialog
                Navigator.pop(context);

                // Update the provider state and go back
                final provider = Provider.of<InAppPurchaseProvider>(
                  context,
                  listen: false,
                );
                provider.isPremiumMember = true;
                provider.finalizePurchase();

                Navigator.pop(context); // Go back to previous screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.text1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Get Started',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context); // Close loading dialog

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Upgrade Failed',
            style: TextStyle(
              color: AppColors.text1,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Failed to activate premium: $e',
            style: TextStyle(color: AppColors.text2),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close error dialog
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.black.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_back_ios_new,
          color: AppColors.white,
          size: 18,
        ),
      ),
    );
  }
}
