// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unused_element

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import 'restaurant_menu_screen.dart';

class RestaurantProfileScreen extends StatefulWidget {
  RestaurantProfileScreen({super.key});

  @override
  State<RestaurantProfileScreen> createState() =>
      _RestaurantProfileScreenState();
}

class _RestaurantProfileScreenState extends State<RestaurantProfileScreen> {
  // Restaurant location at Al Dhaheri Building - Al - Sheikh Zayed Bin Sultan St - Abu Dhabi
  // Google Maps link: https://maps.app.goo.gl/sGs6mxiv38xWQ4GT6
  // Coordinates for Abu Dhabi (approximate location for Sheikh Zayed Bin Sultan Street)

  static LatLng _restaurantLocation = LatLng(24.4539, 54.3773);

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _openGoogleMaps() async {
    // Use the direct Google Maps link (works on both Android and iOS)
    final String directGoogleMapsUrl =
        'https://maps.app.goo.gl/sGs6mxiv38xWQ4GT6';

    try {
      // Try the direct Google Maps link first (works on all platforms)
      final Uri directUri = Uri.parse(directGoogleMapsUrl);
      if (await canLaunchUrl(directUri)) {
        await launchUrl(directUri, mode: LaunchMode.externalApplication);
        return;
      }

      // Fallback to Google Maps web
      final Uri webUri = Uri.parse(directGoogleMapsUrl);
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }

      // If all else fails, show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps. Please install Google Maps.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening maps: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(context),
              _buildDetailsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return SizedBox(
      height: 360,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/restaurant-background.png', fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.black.withOpacity(0.05),
                  AppColors.mainBackground.withOpacity(0.85),
                  AppColors.mainBackground,
                ],
                stops: [0.55, 0.82, 1],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BackButton(onTap: () => Navigator.of(context).pop()),
                Spacer(),
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.white.withOpacity(0.25),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/restaurant-icon.png',
                                width: 44,
                                height: 44,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'SFC Plus - Southern\nFried Chicken',
                            textAlign: TextAlign.start,
                            style: AppTextStyles.h4.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _PrimaryButton(
                        label: 'View Menu',
                        background: AppColors.secondary,
                        foreground: AppColors.black,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RestaurantMenuScreen(),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBlock(
            icon: Icons.place_rounded,
            title: 'Address:',
            description:
                'Al Dhaheri Building - Al - Sheikh Zayed Bin Sultan St - Abu Dhabi - United Arab Emirates',
          ),
          SizedBox(height: 20),
          _infoBlock(
            icon: Icons.call_rounded,
            title: 'Call:',
            description: '+971600566004',
          ),
          SizedBox(height: 20),
          _buildMapCard(context),
          SizedBox(height: 16),
          _PrimaryButton(
            label: 'View Location',
            background: AppColors.primary,
            foreground: AppColors.black,
            onTap: _openGoogleMaps,
          ),
        ],
      ),
    );
  }

  Widget _infoBlock({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.h6.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                description,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            SizedBox(
              height: 260,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _restaurantLocation,
                  zoom: 16.0,
                ),
                onMapCreated: (GoogleMapController controller) {},
                markers: {
                  Marker(
                    markerId: MarkerId('restaurant'),
                    position: _restaurantLocation,
                    infoWindow: InfoWindow(
                      title: 'SFC Plus - Southern Fried Chicken',
                      snippet: 'Fast food · AED 50-100',
                    ),
                  ),
                },
                mapType: MapType.normal,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
                trafficEnabled: false,
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.18),
                      blurRadius: 10,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/restaurant-icon.png',
                          width: 40,
                          height: 40,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SFC Plus - Southern\nFried Chicken',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                          SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 16,
                                    color: AppColors.warning,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '4.4 (853)',
                                    style: TextStyle(
                                      color: AppColors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Restaurant · AED 50-100',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.black.withOpacity(0.35),
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

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  _PrimaryButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonLarge.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ChipIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ChipIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
