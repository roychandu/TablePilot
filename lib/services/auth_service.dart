import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_flow_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  static const String _userKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _userPhotoKey = 'user_photo';
  static const String _isLoggedInKey = 'is_logged_in';

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Save user data to SharedPreferences
  Future<void> saveUserData({
    required String userId,
    required String email,
    String? name,
    String? photoUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, userId);
    await prefs.setString(_userEmailKey, email);
    if (name != null && name.isNotEmpty) {
      await prefs.setString(_userNameKey, name);
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      await prefs.setString(_userPhotoKey, photoUrl);
    }
    await prefs.setBool(_isLoggedInKey, true);

    await _upsertUserProfile(
      userId: userId,
      email: email,
      name: name,
      photoUrl: photoUrl,
    );
  }

  Future<void> _upsertUserProfile({
    required String userId,
    String? email,
    String? name,
    String? photoUrl,
    bool? isPremiumMember,
  }) async {
    final Map<String, dynamic> data = {};

    if (name != null && name.isNotEmpty) {
      data['name'] = name;
    }
    if (email != null && email.isNotEmpty) {
      data['email'] = email;
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      data['photoUrl'] = photoUrl;
      data['profileImage'] = photoUrl;
    }
    if (isPremiumMember != null) {
      data['isPremiumMember'] = isPremiumMember;
    }

    if (data.isEmpty) {
      return;
    }

    data['updatedAt'] = ServerValue.timestamp;

    try {
      await _database.ref('users/$userId/profile').update(data);
    } catch (_) {}
  }

  // Get user data from SharedPreferences
  Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    bool isPremium = prefs.getBool('isPremiumMember') ?? false;
    String? userId = prefs.getString(_userKey) ?? currentUser?.uid;
    String? email = prefs.getString(_userEmailKey);
    String? name = prefs.getString(_userNameKey);
    String? photoUrl = prefs.getString(_userPhotoKey);

    if (userId != null) {
      try {
        final DataSnapshot snap =
            await _database.ref('users/$userId/profile').get();
        if (snap.exists && snap.value is Map) {
          final data =
              Map<String, dynamic>.from(snap.value as Map<dynamic, dynamic>);
          final dbName = data['name']?.toString();
          final dbEmail = data['email']?.toString();
          final dbPhoto =
              data['photoUrl'] ?? data['profileImage'] ?? data['photoURL'];
          final dbPremium = data['isPremiumMember'];

          if (dbName != null && dbName.isNotEmpty) {
            name = dbName;
            await prefs.setString(_userNameKey, dbName);
          }
          if (dbEmail != null && dbEmail.isNotEmpty) {
            email = dbEmail;
            await prefs.setString(_userEmailKey, dbEmail);
          }
          if (dbPhoto is String && dbPhoto.isNotEmpty) {
            photoUrl = dbPhoto;
            await prefs.setString(_userPhotoKey, dbPhoto);
          }
          if (dbPremium is bool) {
            isPremium = dbPremium;
            await prefs.setBool('isPremiumMember', isPremium);
          }
        }
      } catch (e) {}
    }

    return {
      'userId': userId,
      'email': email,
      'name': name,
      'isPremiumMember': isPremium,
      'photoUrl': photoUrl,
      'photoURL': photoUrl,
      'profileImage': photoUrl,
    };
  }

  // Update premium membership status
  Future<void> updatePremiumStatus(bool isPremium) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremiumMember', isPremium);
    final String? userId = prefs.getString(_userKey) ?? currentUser?.uid;
    if (userId != null) {
      await _upsertUserProfile(
        userId: userId,
        isPremiumMember: isPremium,
      );
    }
  }

  // Clear user data from SharedPreferences
  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userPhotoKey);
    await prefs.setBool(_isLoggedInKey, false);
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (name != null && credential.user != null) {
        await credential.user!.updateDisplayName(name);
      }

      // Save user data to SharedPreferences
      await saveUserData(
        userId: credential.user!.uid,
        email: email,
        name: name,
        photoUrl: credential.user?.photoURL,
      );

      // Sync premium from server into local after sign up/login
      try {
        final DataSnapshot snap = await _database
            .ref('users/${credential.user!.uid}/profile/isPremiumMember')
            .get();
        if (snap.exists) {
          final isPremium = (snap.value as bool? ?? false);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isPremiumMember', isPremium);
        }
      } catch (e) {}

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user data to SharedPreferences
      await saveUserData(
        userId: credential.user!.uid,
        email: email,
        name: credential.user!.displayName,
        photoUrl: credential.user?.photoURL,
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in anonymously
  Future<UserCredential?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();

      // Save user data to SharedPreferences for anonymous user
      await saveUserData(
        userId: credential.user!.uid,
        email: 'guest@anonymous.com', // Placeholder email for anonymous users
        name: 'Guest User',
        photoUrl: credential.user?.photoURL,
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await clearUserData();

      // Clear app flow data (intro status, etc.)
      final appFlowService = AppFlowService();
      await appFlowService.clearAppData();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      if (currentUser != null) {
        if (displayName != null && displayName.isNotEmpty) {
          await currentUser!.updateDisplayName(displayName);
        }
        if (photoURL != null && photoURL.isNotEmpty) {
          await currentUser!.updatePhotoURL(photoURL);
        }

        final prefs = await SharedPreferences.getInstance();
        if (displayName != null && displayName.isNotEmpty) {
          await prefs.setString(_userNameKey, displayName);
        }
        if (photoURL != null && photoURL.isNotEmpty) {
          await prefs.setString(_userPhotoKey, photoURL);
        }

        await _upsertUserProfile(
          userId: currentUser!.uid,
          name: displayName,
          photoUrl: photoURL,
        );
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Delete user account
  Future<void> deleteUserAccount() async {
    try {
      if (currentUser != null) {
        await currentUser!.delete();
        await clearUserData();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Delete account (alias for deleteUserAccount)
  Future<void> deleteAccount() async {
    await deleteUserAccount();
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  // Check if email is verified
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      if (currentUser != null && !currentUser!.emailVerified) {
        await currentUser!.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Re-authenticate user (required for sensitive operations)
  Future<void> reAuthenticateUser(String password) async {
    try {
      if (currentUser != null && currentUser!.email != null) {
        final credential = EmailAuthProvider.credential(
          email: currentUser!.email!,
          password: password,
        );
        await currentUser!.reauthenticateWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Apple
  Future<UserCredential?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Save user data
      await saveUserData(
        userId: userCredential.user!.uid,
        email: userCredential.user?.email ?? 'apple@user.com',
        name:
            userCredential.user?.displayName ??
            [
              appleCredential.givenName,
              appleCredential.familyName,
            ].whereType<String>().join(' ').trim(),
        photoUrl: userCredential.user?.photoURL,
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Apple Sign-In failed: $e');
      throw _handleAuthException(e);
    } catch (e) {
      print('Apple Sign-In failed: $e');
      throw Exception('Apple Sign-In failed: $e');
    }
  }
}
