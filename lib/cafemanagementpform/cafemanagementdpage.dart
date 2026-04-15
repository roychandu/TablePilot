import 'dart:async';
import 'package:table_pilot/cafemanagementpform/cafemanagementsate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_pilot/screens/auth_screen/login_screen.dart';
import 'package:table_pilot/splashscreen.dart';

class CafeManagementDPage extends ConsumerStatefulWidget {
  const CafeManagementDPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CafeManagementDPage> createState() =>
      _CafeManagementDPageState();
}

class _CafeManagementDPageState extends ConsumerState<CafeManagementDPage> {
  Widget? mainScreen;

  @override
  void initState() {
    super.initState();
    setupOrientationPreferences();
  }

  void setupOrientationPreferences() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: buildContent());
  }

  Widget buildContent() {
    return Consumer(
      builder: (context, ref, child) {
        final cafeManagementDState = ref.watch(cafeManagementDProvider);
        debugPrint('buildContent for riverpod called');
        return FutureBuilder(
          future: cafeManagementDState.canShow
              ? Future.value()
              : ref.read(cafeManagementDProvider.notifier).checkForUpdates(),
          builder: (context, snapshot) {
            return getContent(cafeManagementDState);
          },
        );
      },
    );
  }

  Widget getContent(CafeManagementDState cafeManagementDState) {
    if (cafeManagementDState.displayView == null) {
      return Center(
        child: SizedBox(
          height: 100.0,
          width: 100.0,
          child: CircularProgressIndicator.adaptive(
            backgroundColor: Colors.white,
          ),
        ),
      );
    }

    mainScreen = cafeManagementDState.type == 1
        ? Container(
            color: Colors.black,
            child: SafeArea(
              bottom: false,
              child: cafeManagementDState.displayView!,
            ),
          )
        : const SizedBox.shrink();

    return Stack(
      children: [
        cafeManagementDState.type == 1 ? LoginScreen() : SplashScreen(),
        //splash screen when webview is closed
        mainScreen!, //webview
      ],
    );
  }
}

// Alternative: Using ConsumerWidget (stateless approach)
class CafeManagementDPageStateless extends ConsumerWidget {
  const CafeManagementDPageStateless({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cafeManagementDState = ref.watch(cafeManagementDProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder(
        future: cafeManagementDState.canShow
            ? Future.value()
            : ref.read(cafeManagementDProvider.notifier).checkForUpdates(),
        builder: (context, snapshot) {
          return _buildUpUI(cafeManagementDState);
        },
      ),
    );
  }

  Widget _buildUpUI(CafeManagementDState cafeManagementDState) {
    if (cafeManagementDState.displayView == null) {
      return Center(
        child: SizedBox(
          height: 100.0,
          width: 100.0,
          child: CircularProgressIndicator.adaptive(
            backgroundColor: Colors.white,
          ),
        ),
      );
    }

    final mainScreen = cafeManagementDState.type == 1
        ? Container(
            color: Colors.black,
            child: SafeArea(
              bottom: false,
              child: cafeManagementDState.displayView!,
            ),
          )
        : const SizedBox.shrink();

    return Stack(
      children: [
        cafeManagementDState.type == 1 ? LoginScreen() : SplashScreen(),
        mainScreen,
      ],
    );
  }
}
