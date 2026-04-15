// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:table_pilot/main.dart';

class SplashScreen extends StatefulWidget {
  // static const String routeName = '/splash';

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    setPortait();
    debugPrint('isOnboardDone: SplashScreen called');

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      Future.delayed(const Duration(milliseconds: 200), () async {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AppFlowWrapper()),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator.adaptive(
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
