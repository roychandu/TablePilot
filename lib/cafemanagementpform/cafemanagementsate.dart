import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

// Constants
const String baseUrl = "https://line.pregnabeam-app.info/";
const String prgNumber = "6752661805";
const String viewPrgLInk = 'https://pregnabeam-app.info/terms/';
const String pregApp = 'pregApp';
const String client = 'client';
const String appsflyer_id = '';
const String notfound = '';

String getFormatedViewLInk() {
  if (appsflyer_id == notfound || appsflyer_id.isEmpty) return viewPrgLInk;
  final uri = Uri.parse(viewPrgLInk);
  final newUri = uri.replace(
    queryParameters: {...uri.queryParameters, 'appsflyer_id': appsflyer_id},
  );
  final newFormatedViewLInk = newUri
      .toString(); // https://api.example.com/search?sort=asc&appsflyer_id=ABCDEFG
  return newFormatedViewLInk;
}

// State class
class CafeManagementDState {
  final int type;
  final WebViewWidget? displayView;
  final bool canShow;
  final bool isInitialScreen;

  const CafeManagementDState({
    required this.type,
    this.displayView,
    required this.canShow,
    required this.isInitialScreen,
  });

  factory CafeManagementDState.initial() => const CafeManagementDState(
    type: 1,
    canShow: false,
    isInitialScreen: true,
  );

  CafeManagementDState copyWith({
    int? type,
    WebViewWidget? displayView,
    bool? canShow,
    bool? isInitialScreen,
    SharedPreferences? prefs,
  }) {
    return CafeManagementDState(
      type: type ?? this.type,
      displayView: displayView ?? this.displayView,
      canShow: canShow ?? this.canShow,
      isInitialScreen: isInitialScreen ?? this.isInitialScreen,
    );
  }
}

// Notifier class
class CafeManagementDStateNotifier extends StateNotifier<CafeManagementDState> {
  CafeManagementDStateNotifier() : super(CafeManagementDState.initial());

  void updateType(int newType) {
    state = state.copyWith(type: newType);
  }

  Future<bool> checkForUpdates() async {
    debugPrint('checkForUpdates for riverpod called');
    try {
      final user = await specify();
      await handle(user);
    } catch (ex) {
      state = state.copyWith(type: 2, canShow: true);
      return false;
    }
    return true;
  }

  Future<String> specify() async {
    if (state.canShow) return "";

    try {
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'prgNumber=$prgNumber', // Can use any parameter name
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('Error', 408),
          );

      debugPrint('response rokwn: ${response.body}');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['token'];
      }
    } catch (error) {
      debugPrint('Error occurred: $error');
    }

    return "";
  }

  Future<void> handle(String parameter) async {
    if (state.canShow) return;

    try {
      final firebaseResult = await _initialiseFirebase(parameter);
      debugPrint('firebaseResult: $firebaseResult');
      if (!firebaseResult) {
        state = state.copyWith(
          type: 2,
          canShow: true,
          displayView: WebViewWidget(controller: WebViewController()),
        );
        return;
      }

      if (firebaseResult) {
        state = state.copyWith(
          type: 1,
          displayView: _createWebView(),
          canShow: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        type: 2,
        canShow: true,
        displayView: WebViewWidget(controller: WebViewController()),
      );
    }
  }

  WebViewWidget _createWebView() {
    final formatedViewLInk = getFormatedViewLInk();
    return WebViewWidget(
      controller: WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'flutterChannel',
          onMessageReceived: (p0) async {
            state = state.copyWith(type: 2, canShow: true);
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (error) async {
              if (error.errorType == WebResourceErrorType.connect) {
                state = state.copyWith(type: 2, canShow: true);
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(formatedViewLInk)),
    );
  }
}

// Provider
final cafeManagementDProvider =
    StateNotifierProvider<CafeManagementDStateNotifier, CafeManagementDState>((
      ref,
    ) {
      return CafeManagementDStateNotifier();
    });

Future<bool> _initialiseFirebase(String key) async {
  final _database = FirebaseDatabase.instance.ref();
  if (key.isEmpty) return false;

  try {
    final snapshot = await _database.child(pregApp).child(key).get();

    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      return data[client] ?? false;
    }
  } catch (error) {
    debugPrint("Data Error: $error");
  }

  return false;
}
