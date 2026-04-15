// ignore_for_file: empty_catches

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/offer_model.dart';

class OfferService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Get current user ID
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Create a new offer
  Future<String?> createOffer(OfferModel offer) async {
    if (_userId == null) {
      return null;
    }

    try {
      final offerRef = _database
          .child('users')
          .child(_userId!)
          .child('offers')
          .push();

      final offerWithId = offer.copyWith(
        id: offerRef.key,
        updatedAt: DateTime.now(),
      );

      await offerRef.set(offerWithId.toMap());
      return offerRef.key;
    } catch (e) {
      return null;
    }
  }

  // Update an existing offer
  Future<bool> updateOffer(OfferModel offer) async {
    if (_userId == null || offer.id == null) {
      return false;
    }

    try {
      final updatedOffer = offer.copyWith(
        updatedAt: DateTime.now(),
        status: OfferModel.calculateStatus(offer.validFrom, offer.validUntil),
      );

      await _database
          .child('users')
          .child(_userId!)
          .child('offers')
          .child(offer.id!)
          .update(updatedOffer.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete an offer
  Future<bool> deleteOffer(String offerId) async {
    if (_userId == null) {
      return false;
    }

    try {
      await _database
          .child('users')
          .child(_userId!)
          .child('offers')
          .child(offerId)
          .remove();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get offer by ID
  Future<OfferModel?> getOffer(String offerId) async {
    if (_userId == null) {
      return null;
    }

    try {
      final snapshot = await _database
          .child('users')
          .child(_userId!)
          .child('offers')
          .child(offerId)
          .get();

      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      return OfferModel.fromMap(offerId, data);
    } catch (e) {
      return null;
    }
  }

  // Get all offers stream (real-time updates)
  Stream<List<OfferModel>> getOffersStream() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _database.child('users').child(_userId!).child('offers').onValue.map(
      (event) {
        final data = event.snapshot.value;
        if (data == null) {
          return <OfferModel>[];
        }

        final List<OfferModel> offers = [];
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              try {
                final offer = OfferModel.fromMap(key.toString(), value);
                // Update status based on current time
                offers.add(offer.updateStatus());
              } catch (e) {
                // Skip invalid offers
              }
            }
          });
        }
        return offers;
      },
    );
  }

  // Get all offers
  Future<List<OfferModel>> getOffers() async {
    if (_userId == null) {
      return [];
    }

    try {
      final snapshot = await _database
          .child('users')
          .child(_userId!)
          .child('offers')
          .get();

      if (!snapshot.exists) {
        return [];
      }

      final data = snapshot.value;
      if (data == null) {
        return [];
      }

      final List<OfferModel> offers = [];
      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final offer = OfferModel.fromMap(key.toString(), value);
              // Update status based on current time
              offers.add(offer.updateStatus());
            } catch (e) {
              // Skip invalid offers
            }
          }
        });
      }
      return offers;
    } catch (e) {
      return [];
    }
  }

  // Get offers by status
  Future<List<OfferModel>> getOffersByStatus(OfferStatus status) async {
    final allOffers = await getOffers();
    return allOffers.where((offer) => offer.status == status).toList();
  }

  // Get admin user ID by email
  Future<String?> _getAdminUserId() async {
    try {
      // Search for user with test-admin@gmail.com email
      final usersSnapshot = await _database.child('users').get();
      if (usersSnapshot.exists && usersSnapshot.value is Map) {
        final users = usersSnapshot.value as Map<dynamic, dynamic>;
        for (final entry in users.entries) {
          final userId = entry.key.toString();
          final userData = entry.value;
          if (userData is Map) {
            final profile = userData['profile'];
            if (profile is Map) {
              final email = profile['email']?.toString();
              if (email == 'test-admin@gmail.com') {
                return userId;
              }
            }
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get active offers (visible to customers) - from admin user
  Future<List<OfferModel>> getActiveOffersForCustomers() async {
    try {
      final adminUserId = await _getAdminUserId();
      if (adminUserId == null) {
        return [];
      }

      final snapshot = await _database
          .child('users')
          .child(adminUserId)
          .child('offers')
          .get();

      if (!snapshot.exists) {
        return [];
      }

      final data = snapshot.value;
      if (data == null) {
        return [];
      }

      final List<OfferModel> offers = [];
      final now = DateTime.now();

      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final offer = OfferModel.fromMap(key.toString(), value);
              final updatedOffer = offer.updateStatus();
              
              // Filter for active, visible offers
              if (updatedOffer.visibleToCustomers &&
                  updatedOffer.status == OfferStatus.active &&
                  now.isAfter(updatedOffer.validFrom) &&
                  now.isBefore(updatedOffer.validUntil)) {
                offers.add(updatedOffer);
              }
            } catch (e) {
              // Skip invalid offers
            }
          }
        });
      }
      return offers;
    } catch (e) {
      return [];
    }
  }

  // Get all offers (active, scheduled, expired) for customers - from admin user
  Future<List<OfferModel>> getAllOffersForCustomers() async {
    try {
      final adminUserId = await _getAdminUserId();
      if (adminUserId == null) {
        return [];
      }

      final snapshot = await _database
          .child('users')
          .child(adminUserId)
          .child('offers')
          .get();

      if (!snapshot.exists) {
        return [];
      }

      final data = snapshot.value;
      if (data == null) {
        return [];
      }

      final List<OfferModel> offers = [];
      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final offer = OfferModel.fromMap(key.toString(), value);
              final updatedOffer = offer.updateStatus();
              
              // Only include offers visible to customers
              if (updatedOffer.visibleToCustomers) {
                offers.add(updatedOffer);
              }
            } catch (e) {
              // Skip invalid offers
            }
          }
        });
      }
      return offers;
    } catch (e) {
      return [];
    }
  }

  // Get all offers stream for customers (real-time updates) - from admin user
  Stream<List<OfferModel>> getAllOffersForCustomersStream() async* {
    try {
      final adminUserId = await _getAdminUserId();
      if (adminUserId == null) {
        yield [];
        return;
      }

      await for (final event in _database
          .child('users')
          .child(adminUserId)
          .child('offers')
          .onValue) {
        final data = event.snapshot.value;
        if (data == null) {
          yield [];
          continue;
        }

        final List<OfferModel> offers = [];
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              try {
                final offer = OfferModel.fromMap(key.toString(), value);
                final updatedOffer = offer.updateStatus();
                
                // Only include offers visible to customers
                if (updatedOffer.visibleToCustomers) {
                  offers.add(updatedOffer);
                }
              } catch (e) {
                // Skip invalid offers
              }
            }
          });
        }
        yield offers;
      }
    } catch (e) {
      yield [];
    }
  }

  // Toggle offer visibility
  Future<bool> toggleOfferVisibility(String offerId, bool visible) async {
    if (_userId == null) {
      return false;
    }

    try {
      await _database
          .child('users')
          .child(_userId!)
          .child('offers')
          .child(offerId)
          .update({'visibleToCustomers': visible});
      return true;
    } catch (e) {
      return false;
    }
  }
}

