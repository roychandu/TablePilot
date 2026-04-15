class AppConfigService {
  static final AppConfigService _instance = AppConfigService._internal();
  factory AppConfigService() => _instance;
  AppConfigService._internal();

  // Memory limits configuration
  static const int freePlanMonthlyMemoryLimit =
      5; // Actual limit enforced in code
  static const int freePlanMonthlyMemoryLimitDisplay =
      5; // Displayed limit in UI
  static const bool premiumPlanUnlimitedMemories = true;

  // Premium features configuration
  static const bool premiumAllowsUnlimitedMemories = true;
  static const bool premiumAllowsAdvancedFeatures = true;

  /// Get the actual memory limit for free users (used in logic checks)
  int get freeUserMemoryLimit => freePlanMonthlyMemoryLimit;

  /// Get the displayed memory limit for free users (shown in UI)
  int get freeUserMemoryLimitDisplay => freePlanMonthlyMemoryLimitDisplay;

  /// Check if premium users have unlimited memory creation
  bool get premiumHasUnlimitedMemories => premiumPlanUnlimitedMemories;

  /// Get memory limit description for UI display
  String getFreePlanMemoryDescription() {
    return '$freePlanMonthlyMemoryLimitDisplay memories per month';
  }

  /// Get premium plan memory description for UI display
  String getPremiumPlanMemoryDescription() {
    return premiumHasUnlimitedMemories
        ? 'Unlimited memories'
        : 'Extended memory limits';
  }

  /// Check if a user has reached their monthly memory limit
  bool hasReachedMonthlyLimit(int monthlyMemoryCount, bool isPremium) {
    if (isPremium && premiumHasUnlimitedMemories) {
      return false;
    }
    return monthlyMemoryCount >= freeUserMemoryLimit;
  }

  /// Get the remaining memory count for free users
  int getRemainingMemories(int monthlyMemoryCount, bool isPremium) {
    if (isPremium && premiumHasUnlimitedMemories) {
      return -1; // Unlimited
    }
    final remaining = freeUserMemoryLimit - monthlyMemoryCount;
    return remaining > 0 ? remaining : 0;
  }
}
