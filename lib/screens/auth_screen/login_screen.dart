import 'package:flutter/material.dart';
import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoginLoading = false;
  bool _isGuestLoading = false;
  bool _isAppleLoading = false;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoginLoading = true;
    });

    try {
      await _authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        // Show success confirmation before navigating away
        _showSnackBar('Login successful', backgroundColor: AppColors.success);
        // Navigate to home screen after successful login
        // Business setup will be checked when user tries to create an invoice
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          "We couldn't sign you in. Please check your details and try again.",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoginLoading = false;
        });
      }
    }
  }

  void _showSnackBar(
    String message, {
    Color backgroundColor = AppColors.error,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
      ),
    );
  }

  void _handleRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  void _handleGuestLogin() async {
    setState(() {
      _isGuestLoading = true;
    });

    try {
      // Use Firebase anonymous authentication for guest login
      await _authService.signInAnonymously();

      if (mounted) {
        // For guest users, we'll navigate directly to home
        // since they won't have business setup data
        _showSnackBar(
          'Guest session started',
          backgroundColor: AppColors.success,
        );
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Couldn't start a guest session. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGuestLoading = false;
        });
      }
    }
  }

  void _handleAppleSignIn() async {
    setState(() {
      _isAppleLoading = true;
    });

    try {
      await _authService.signInWithApple();

      if (mounted) {
        _showSnackBar(
          'Signed in with Apple successfully',
          backgroundColor: AppColors.success,
        );
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Apple sign-in didn't work. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAppleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, AppColors.surface],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10.0),
              child: Card(
                color: AppColors.cardBackground,
                elevation: 8,
                shadowColor: AppColors.shadow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        'Login',
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Email Input
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter Email',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.textFieldBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'Email',
                                hintStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: AppColors.textSecondary,
                                ),
                                filled: true,
                                fillColor: AppColors.textFieldBackground,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Password Input
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter Password',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.textFieldBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                hintText: 'Password',
                                hintStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: AppColors.textSecondary,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: _togglePasswordVisibility,
                                ),
                                filled: true,
                                fillColor: AppColors.textFieldBackground,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoginLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoginLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Login',
                                  style: AppTextStyles.buttonLarge.copyWith(
                                    color: AppColors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Register Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: _handleRegister,
                            child: Text(
                              'Register',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Separator
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: AppColors.divider,
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: AppColors.divider,
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Continue as Guest Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _isGuestLoading ? null : _handleGuestLogin,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isGuestLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Continue as a Guest',
                                  style: AppTextStyles.buttonLarge.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sign in with Apple Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isAppleLoading
                              ? null
                              : _handleAppleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.appleButtonColor,
                            foregroundColor: AppColors.appleButtonTextColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: _isAppleLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.appleButtonTextColor,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.apple,
                                  color: AppColors.appleButtonTextColor,
                                  size: 24,
                                ),
                          label: Text(
                            'Sign in with Apple',
                            style: AppTextStyles.buttonLarge.copyWith(
                              color: AppColors.appleButtonTextColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
