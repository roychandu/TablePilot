// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/offer_model.dart';
import '../../services/offer_service.dart';

class CustomerOffersScreen extends StatefulWidget {
  const CustomerOffersScreen({super.key});

  @override
  State<CustomerOffersScreen> createState() => _CustomerOffersScreenState();
}

class _CustomerOffersScreenState extends State<CustomerOffersScreen>
    with SingleTickerProviderStateMixin {
  final OfferService _offerService = OfferService();
  late TabController _tabController;
  List<OfferModel> _allOffers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Rebuild when tab animation completes
      }
    });
    _loadOffers();
    // Listen for real-time updates
    _offerService.getAllOffersForCustomersStream().listen((offers) {
      if (mounted) {
        setState(() {
          _allOffers = offers;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final offers = await _offerService.getAllOffersForCustomers();
      if (mounted) {
        setState(() {
          _allOffers = offers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<OfferModel> _getOffersForTab() {
    switch (_tabController.index) {
      case 0: // Active
        return _allOffers
            .where(
              (offer) =>
                  offer.status == OfferStatus.active &&
                  offer.visibleToCustomers,
            )
            .toList();
      case 1: // Inactive (Scheduled)
        return _allOffers
            .where(
              (offer) =>
                  offer.status == OfferStatus.scheduled &&
                  offer.visibleToCustomers,
            )
            .toList();
      case 2: // Past (Expired)
        return _allOffers
            .where(
              (offer) =>
                  offer.status == OfferStatus.expired &&
                  offer.visibleToCustomers,
            )
            .toList();
      default:
        return [];
    }
  }

  Color _getStatusColor(OfferStatus status) {
    switch (status) {
      case OfferStatus.active:
        return AppColors.success;
      case OfferStatus.scheduled:
        return AppColors.warning;
      case OfferStatus.expired:
        return AppColors.textSecondary;
    }
  }

  String _getStatusText(OfferStatus status) {
    switch (status) {
      case OfferStatus.active:
        return 'Active';
      case OfferStatus.scheduled:
        return 'Inactive';
      case OfferStatus.expired:
        return 'Past';
    }
  }

  String _getDiscountText(OfferModel offer) {
    switch (offer.offerType) {
      case OfferType.percentageDiscount:
        return '${offer.discountValue.toInt()}% OFF';
      case OfferType.fixedAmountOff:
        return 'AED ${offer.discountValue.toStringAsFixed(0)} OFF';
      case OfferType.buyOneGetOne:
        return 'BOGO';
      case OfferType.freeItemWithPurchase:
        return 'FREE ITEM';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final offers = _getOffersForTab();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text(
          'Special Offers',
          style: AppTextStyles.h3.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Inactive'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOffers,
              child: offers.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: offers.length,
                      itemBuilder: (context, index) {
                        return _buildOfferCard(offers[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No offers available',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new offers',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(OfferModel offer) {
    final statusColor = _getStatusColor(offer.status);
    final statusText = _getStatusText(offer.status);
    final discountText = _getDiscountText(offer);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image
          if (offer.bannerImageUrl != null && offer.bannerImageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.network(
                offer.bannerImageUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: AppColors.surface,
                  child: Icon(
                    Icons.image_not_supported,
                    color: AppColors.textSecondary,
                    size: 48,
                  ),
                ),
              ),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.9),
                    AppColors.primary.withOpacity(0.7),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Discount Badge and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        discountText,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Text(
                        statusText,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  offer.title,
                  style: AppTextStyles.h5.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Description
                if (offer.description.isNotEmpty)
                  Text(
                    offer.description,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                // Valid Dates
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Valid: ${_formatDate(offer.validFrom)} - ${_formatDate(offer.validUntil)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                // Minimum Order Value
                if (offer.minimumOrderValue != null &&
                    offer.minimumOrderValue! > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_cart,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Min. order: AED ${offer.minimumOrderValue!.toStringAsFixed(0)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                // Terms & Conditions
                if (offer.termsAndConditions != null &&
                    offer.termsAndConditions!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    title: Text(
                      'Terms & Conditions',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      Text(
                        offer.termsAndConditions!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
