import '../models/offer_model.dart';
import '../models/menu_model.dart';
import '../models/reservation_model.dart';

class OfferHelper {
  // Check if an offer applies to a specific menu item
  static bool doesOfferApplyToItem(OfferModel offer, MenuItem item, String categoryName) {
    // Check if offer applies to reservations
    if (offer.applyTo.contains(OfferApplyTo.reservations)) {
      return true; // Reservations are separate, handled differently
    }

    // Check if offer applies to all items
    if (offer.applyTo.contains(OfferApplyTo.allItems)) {
      return true;
    }

    // Check if offer applies to specific category
    if (offer.applyTo.contains(OfferApplyTo.specificCategory)) {
      if (offer.categoryNames != null && offer.categoryNames!.contains(categoryName)) {
        return true;
      }
    }

    // Check if offer applies to specific items
    if (offer.applyTo.contains(OfferApplyTo.specificItems)) {
      if (offer.itemNames != null && offer.itemNames!.contains(item.itemName)) {
        return true;
      }
    }

    return false;
  }

  // Calculate discounted price for a menu item
  static double calculateDiscountedPrice(
    double originalPrice,
    OfferModel offer,
  ) {
    switch (offer.offerType) {
      case OfferType.percentageDiscount:
        final discount = originalPrice * (offer.discountValue / 100);
        return (originalPrice - discount).clamp(0.0, double.infinity);
      
      case OfferType.fixedAmountOff:
        return (originalPrice - offer.discountValue).clamp(0.0, double.infinity);
      
      case OfferType.buyOneGetOne:
        // BOGO: For every 2 items, one is free
        // This is typically handled at order level, not item level
        return originalPrice;
      
      case OfferType.freeItemWithPurchase:
        // Free item is typically handled separately
        return originalPrice;
    }
  }

  // Get the best applicable offer for an item
  static OfferModel? getBestOfferForItem(
    List<OfferModel> offers,
    MenuItem item,
    String categoryName,
  ) {
    OfferModel? bestOffer;
    double bestDiscount = 0.0;

    for (final offer in offers) {
      if (!doesOfferApplyToItem(offer, item, categoryName)) {
        continue;
      }

      // Check minimum order value if specified
      // (This would need to be checked at order level, not item level)
      
      double discount = 0.0;
      switch (offer.offerType) {
        case OfferType.percentageDiscount:
          discount = item.priceAed * (offer.discountValue / 100);
          break;
        case OfferType.fixedAmountOff:
          discount = offer.discountValue;
          break;
        case OfferType.buyOneGetOne:
        case OfferType.freeItemWithPurchase:
          // These are handled differently
          discount = item.priceAed; // Full price discount for free item
          break;
      }

      if (discount > bestDiscount) {
        bestDiscount = discount;
        bestOffer = offer;
      }
    }

    return bestOffer;
  }

  // Calculate order-level discount (for BOGO, minimum order value, etc.)
  static Map<String, dynamic> calculateOrderDiscount(
    List<OfferModel> offers,
    double subtotal,
    List<ReservationMenuItem> items,
    RestaurantMenu? menu,
  ) {
    double totalDiscount = 0.0;
    OfferModel? appliedOffer;
    String? discountDescription;

    for (final offer in offers) {
      // Check minimum order value
      if (offer.minimumOrderValue != null && subtotal < offer.minimumOrderValue!) {
        continue;
      }

      // Check if offer applies to reservations
      if (offer.applyTo.contains(OfferApplyTo.reservations)) {
        double discount = 0.0;
        String? description;

        switch (offer.offerType) {
          case OfferType.percentageDiscount:
            discount = subtotal * (offer.discountValue / 100);
            description = '${offer.discountValue.toInt()}% OFF';
            break;
          case OfferType.fixedAmountOff:
            discount = offer.discountValue;
            description = 'AED ${offer.discountValue.toStringAsFixed(0)} OFF';
            break;
          case OfferType.buyOneGetOne:
            // BOGO: For every 2 items, one is free (cheapest item)
            if (items.length >= 2) {
              final sortedItems = List<ReservationMenuItem>.from(items)
                ..sort((a, b) => a.priceAed.compareTo(b.priceAed));
              discount = sortedItems.first.priceAed;
              description = 'Buy One Get One';
            }
            break;
          case OfferType.freeItemWithPurchase:
            // Free item logic would be handled separately
            break;
        }

        if (discount > totalDiscount) {
          totalDiscount = discount;
          appliedOffer = offer;
          discountDescription = description;
        }
      }

      // Check item-level offers
      if (offer.applyTo.contains(OfferApplyTo.allItems) ||
          offer.applyTo.contains(OfferApplyTo.specificCategory) ||
          offer.applyTo.contains(OfferApplyTo.specificItems)) {
        double itemDiscount = 0.0;
        String? itemDescription;

        for (final orderItem in items) {
          if (menu != null) {
            MenuItem? menuItem;
            String? categoryName;

            // Find the menu item
            for (final category in menu.categories) {
              final found = category.items.firstWhere(
                (i) => i.itemName == orderItem.itemName,
                orElse: () => MenuItem(
                  itemName: '',
                  description: '',
                  priceAed: 0,
                ),
              );
              if (found.itemName.isNotEmpty) {
                menuItem = found;
                categoryName = category.categoryName;
                break;
              }
            }

            if (menuItem != null && doesOfferApplyToItem(offer, menuItem, categoryName ?? '')) {
              double itemPriceDiscount = 0.0;
              switch (offer.offerType) {
                case OfferType.percentageDiscount:
                  itemPriceDiscount = orderItem.priceAed * (offer.discountValue / 100) * orderItem.quantity;
                  break;
                case OfferType.fixedAmountOff:
                  itemPriceDiscount = offer.discountValue * orderItem.quantity;
                  break;
                case OfferType.buyOneGetOne:
                case OfferType.freeItemWithPurchase:
                  break;
              }
              itemDiscount += itemPriceDiscount;
            }
          }
        }

        if (itemDiscount > totalDiscount) {
          totalDiscount = itemDiscount;
          appliedOffer = offer;
          itemDescription = offer.title;
          discountDescription = itemDescription;
        }
      }
    }

    return {
      'discount': totalDiscount,
      'offer': appliedOffer,
      'description': discountDescription,
    };
  }
}

