import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// test ids

/// production ids
const nonConsumableId = kDebugMode ? "com.test.bet" : "com.huelethi.memories";
const trophiesId = kDebugMode ? "com.zapp.testbuild.10006" : "";

/// nonConsumable  is non consumable
/// trophies  is consumable
enum ConsumItemName { nonConsumable, trophies }

Map<ConsumItemName, String> idsEnumToNameMap = {
  ConsumItemName.nonConsumable: nonConsumableId,
  ConsumItemName.trophies: trophiesId,
};

Map<String, ConsumItemName> nameToIdsMap = {
  nonConsumableId: ConsumItemName.nonConsumable,
  trophiesId: ConsumItemName.trophies,
};

List<ConsumItemName> consumableItems = [ConsumItemName.trophies];
List<ConsumItemName> nonConsumableItems = [ConsumItemName.nonConsumable];

class InAppPurchaseProvider extends ChangeNotifier {
  bool get serviceActive => _serviceActive;
  List<ProductDetails> get products => _products;

  // Compatibility getter for existing code

  // isPremiumMember;

  final Set<String> _itemIdentifiers = {
    nonConsumableId,
    // trophiesId // it is consumable id, mostly not used in our app
  };

  final InAppPurchase _paymentService = InAppPurchase.instance;
  bool _serviceActive = true;
  bool isPremiumMember = false;
  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _transactionStream;
  String? errorInfo;
  Set<ConsumItemName> purchasedItems = {};

  void showErrorDialogForPurchase([String? error]) {
    Get.dialog(
      Platform.isIOS
          ? CupertinoAlertDialog(
              title: const Text("Error"),
              content: Text(
                "Some error occurred${kDebugMode ? (error ?? errorInfo ?? "") : ""}",
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text("OK", style: TextStyle(color: Colors.blue)),
                  onPressed: () {
                    Get.back();
                  },
                ),
              ],
            )
          : AlertDialog(
              title: const Text("Error"),
              content: Text(
                "Some error occurred${kDebugMode ? (error ?? errorInfo ?? "") : ""}",
              ),
              actions: [
                TextButton(
                  child: const Text("OK", style: TextStyle(color: Colors.blue)),
                  onPressed: () {
                    Get.back();
                  },
                ),
              ],
            ),
    );
  }

  // Add a global navigator key that should be set in your main app
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  InAppPurchaseProvider() {
    setupStoreData();
    _transactionStream = _paymentService.purchaseStream.listen((
      purchaseDetailsList,
    ) {
      _processTransactionUpdates(purchaseDetailsList);
    });
  }

  updateUI() {
    notifyListeners();
  }

  Future<bool> restorePurchases() async {
    await _paymentService.restorePurchases();
    return Future.value(true);
  }

  // Compatibility method for existing code
  Future<bool> restoreItem() async {
    return await restorePurchases();
  }

  Future<void> setupStoreData() async {
    final bool serviceAvailable = await _paymentService.isAvailable();
    if (!serviceAvailable) {
      _serviceActive = serviceAvailable;
      return;
    }

    final ProductDetailsResponse productResponse = await _paymentService
        .queryProductDetails(_itemIdentifiers);
    _products = productResponse.productDetails;
    debugPrint("products ${products.length}");
    final prefs = await SharedPreferences.getInstance();
    isPremiumMember = prefs.getBool('is_purchased') ?? false;

    await _finalizePendingTransactions();
  }

  // Compatibility method for existing code
  Future<void> initStoreInfo() async {
    await setupStoreData();
  }

  Future<void> _finalizePendingTransactions() async {
    if (Platform.isIOS) {
      try {
        final transactions = await SKPaymentQueueWrapper().transactions();
        debugPrint(
          "_paymentService no of transactions   ${transactions.length}",
        );
        for (final transaction in transactions) {
          try {
            debugPrint(
              "transaction  ${transaction.payment.productIdentifier} ${transaction.error.toString()}",
            );
            await SKPaymentQueueWrapper().finishTransaction(transaction);
          } catch (e) {
            debugPrint("Error finalizing transactions in loop");
            debugPrint(e.toString());
          }
        }
      } catch (e) {
        debugPrint("Error processing pending transactions");
        debugPrint(e.toString());
      }
    }
  }

  void _processTransactionUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    debugPrint(
      "themeid len ${purchaseDetailsList.length} : ${purchaseDetailsList.map((e) => e.productID)}",
    );
    for (var purchase in purchaseDetailsList) {
      debugPrint(
        "themeid purchase status ${purchase.status}: err ${purchase.error?.toString()}",
      );
      String id = purchase.productID;
      if (purchase.status == PurchaseStatus.pending) {
        debugPrint("themeid pending ${purchase.productID}");
      } else {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          debugPrint("themeid purchased ${purchase.productID}");

          if (id == nonConsumableId) {
            await finalizePurchase();
            purchase.status == PurchaseStatus.purchased
                ? _showPurchaseDialog()
                : _showRestorePurchaseSuccessfulDialog();
          }
          if (purchase.status == PurchaseStatus.purchased) {
            int indexOfProductId = _products.indexWhere((e) => e.id == id);
            if (indexOfProductId >= 0) {
              ConsumItemName? item = nameToIdsMap[id];
              if (item != null && consumableItems.contains(item)) {
                /// for consumable items
                handleCodeAfterConsumablePurchase(item);
              }
            }
          }
          errorInfo = null;
          notifyListeners();
        } else if (purchase.status == PurchaseStatus.error) {
          errorInfo = purchase.error?.message.toString();
          debugPrint("Error occurred: ${purchase.error}");
          showErrorDialogForPurchase();
          notifyListeners();
        } else if (purchase.status == PurchaseStatus.canceled) {
          await _finalizePendingTransactions();
          errorInfo = null;
          notifyListeners();
        }
        if (purchase.pendingCompletePurchase) {
          await _paymentService.completePurchase(purchase);
        }
      }
    }
  }

  bool isIdConsumable(String id) {
    int indexOfProductId = _products.indexWhere((e) => e.id == id);
    return indexOfProductId >= 0;
  }

  Future<void> finalizePurchase() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('is_purchased', true);
    isPremiumMember = true;
  }

  // Compatibility method for existing code
  Future<void> deliverPurchase() async {
    await finalizePurchase();
  }

  Future<void> buyNonConsumableProduct(ProductDetails productDetails) async {
    final PurchaseParam purchaseParameter = PurchaseParam(
      productDetails: productDetails,
    );
    try {
      await _paymentService.buyNonConsumable(purchaseParam: purchaseParameter);
    } catch (e) {
      debugPrint("error on buyNONconsumed $e");
      _finalizePendingTransactions();
    }
  }

  // Compatibility method for existing code
  Future<void> buyProduct(ProductDetails product) async {
    await buyNonConsumableProduct(product);
  }

  Future<void> buyConsumableProduct(ProductDetails productDetails) async {
    final PurchaseParam purchaseParameter = PurchaseParam(
      productDetails: productDetails,
    );
    try {
      await _paymentService.buyConsumable(purchaseParam: purchaseParameter);
    } catch (e) {
      debugPrint("error on buyconsumed $e");
      _finalizePendingTransactions();
    }
  }

  Future buyItemBasedOnEnum(ConsumItemName item) async {
    String id = idsEnumToNameMap[item]!;

    int indexOfProductId = _products.indexWhere((e) => e.id == id);
    if (indexOfProductId >= 0) {
      if (consumableItems.contains(item)) {
        buyConsumableProduct(_products[indexOfProductId]);
      } else {
        buyNonConsumableProduct(_products[indexOfProductId]);
      }
    }
  }

  buyNONConsumableInAppPurchase() {
    buyItemBasedOnEnum(ConsumItemName.nonConsumable);
  }

  @override
  void dispose() {
    _transactionStream?.cancel();
    super.dispose();
  }

  void handleCodeAfterConsumablePurchase(ConsumItemName item) async {
    /// you need to addd your custom consumable purchase logic here
    /// like coin purchased, so add coins in database etc
    /// show dialog that you purchased some coins
  }

  void _showRestorePurchaseSuccessfulDialog() {
    Get.dialog(
      Platform.isIOS
          ? CupertinoAlertDialog(
              title: const Text("Purchase Restored"),
              content: const Text("Your purchases are restored."),
              actions: [
                CupertinoDialogAction(
                  child: const Text("OK", style: TextStyle(color: Colors.blue)),
                  onPressed: () {
                    Get.back();
                  },
                ),
              ],
            )
          : AlertDialog(
              title: const Text("Purchase Restored"),
              content: const Text("Your purchases are restored."),
              actions: [
                TextButton(
                  child: const Text("OK", style: TextStyle(color: Colors.blue)),
                  onPressed: () {
                    Get.back();
                  },
                ),
              ],
            ),
    );
  }

  void _showPurchaseDialog() {
    Get.dialog(
      Platform.isIOS
          ? CupertinoAlertDialog(
              title: const Text("Purchase Successful"),
              content: const Text("You have purchased the premium membership."),
              actions: [
                CupertinoDialogAction(
                  child: const Text("OK", style: TextStyle(color: Colors.blue)),
                  onPressed: () {
                    Get.back();
                  },
                ),
              ],
            )
          : AlertDialog(
              title: const Text("Purchase Successful"),
              content: const Text("You have purchased the premium membership."),
              actions: [
                TextButton(
                  child: const Text("OK", style: TextStyle(color: Colors.blue)),
                  onPressed: () {
                    Get.back();
                  },
                ),
              ],
            ),
    );
  }
}
