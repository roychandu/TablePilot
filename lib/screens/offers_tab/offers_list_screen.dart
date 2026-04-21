// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/offer_model.dart';
import '../../services/offer_service.dart';
import 'create_edit_offer_screen.dart';

class OffersListScreen extends StatefulWidget {
  OffersListScreen({super.key});

  @override
  State<OffersListScreen> createState() => _OffersListScreenState();
}

class _OffersListScreenState extends State<OffersListScreen>
    with SingleTickerProviderStateMixin {
  final OfferService _offerService = OfferService();
  late TabController _tabController;
  List<OfferModel> _activeOffers = [];
  List<OfferModel> _scheduledOffers = [];
  List<OfferModel> _expiredOffers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOffers();
    _offerService.getOffersStream().listen((offers) {
      if (mounted) {
        _categorizeOffers(offers);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _categorizeOffers(List<OfferModel> offers) {
    setState(() {
      _activeOffers = offers
          .where((offer) => offer.status == OfferStatus.active)
          .toList();
      _scheduledOffers = offers
          .where((offer) => offer.status == OfferStatus.scheduled)
          .toList();
      _expiredOffers = offers
          .where((offer) => offer.status == OfferStatus.expired)
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final offers = await _offerService.getOffers();
      if (mounted) {
        _categorizeOffers(offers);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text(
          'Offers & Promotions',
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
          tabs: [
            Tab(text: 'Active'),
            Tab(text: 'Scheduled'),
            Tab(text: 'Expired'),
          ],
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOffersList(_activeOffers, 'No active offers'),
                _buildOffersList(_scheduledOffers, 'No scheduled offers'),
                _buildOffersList(_expiredOffers, 'No expired offers'),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => CreateEditOfferScreen()),
          );
          if (created == true) {
            _loadOffers();
          }
        },
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  Widget _buildOffersList(List<OfferModel> offers, String emptyMessage) {
    return RefreshIndicator(
      onRefresh: _loadOffers,
      child: offers.isEmpty
          ? SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: _buildEmptyState(emptyMessage),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              physics: AlwaysScrollableScrollPhysics(),
              itemCount: offers.length,
              itemBuilder: (context, index) {
                return _buildOfferCard(offers[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState([String message = 'No offers yet']) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap the + button to create your first offer',
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
    final statusText = getOfferStatusDisplayText(offer.status);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image
          if (offer.bannerImageUrl != null && offer.bannerImageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                offer.bannerImageUrl!,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, __, ___) => Container(
                  height: 150,
                  width: double.infinity,
                  color: AppColors.surface,
                  child: Icon(
                    Icons.image_not_supported,
                    color: AppColors.textSecondary,
                    size: 48,
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        offer.title,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
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
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // Description
                Text(
                  offer.description,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12),
                // Discount Details
                Row(
                  children: [
                    Icon(Icons.discount, size: 16, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      _getDiscountText(offer),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // Valid Dates
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${_formatDate(offer.validFrom)} - ${_formatDate(offer.validUntil)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Actions
                Row(
                  children: [
                    Text(
                      'Visible to customers',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: offer.visibleToCustomers,
                        onChanged: (value) async {
                          await _offerService.toggleOfferVisibility(
                            offer.id!,
                            value,
                          );
                          _loadOffers();
                        },
                        activeColor: AppColors.primary,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.edit, color: AppColors.primary),
                      onPressed: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateEditOfferScreen(offer: offer),
                          ),
                        );
                        if (updated == true) {
                          _loadOffers();
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: AppColors.error),
                      onPressed: () => _showDeleteDialog(offer),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDiscountText(OfferModel offer) {
    switch (offer.offerType) {
      case OfferType.percentageDiscount:
        return '${offer.discountValue.toInt()}% OFF';
      case OfferType.fixedAmountOff:
        return 'AED ${offer.discountValue.toStringAsFixed(0)} OFF';
      case OfferType.buyOneGetOne:
        return 'Buy One Get One';
      case OfferType.freeItemWithPurchase:
        return 'Free Item with Purchase';
    }
  }

  Color _getStatusColor(OfferStatus status) {
    switch (status) {
      case OfferStatus.active:
        return AppColors.success;
      case OfferStatus.scheduled:
        return AppColors.info;
      case OfferStatus.expired:
        return AppColors.error;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _showDeleteDialog(OfferModel offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Offer'),
        content: Text('Are you sure you want to delete "${offer.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && offer.id != null) {
      await _offerService.deleteOffer(offer.id!);
      if (mounted) {
        _loadOffers();
      }
    }
  }
}
