import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/monetization/domain/trial_logic.dart';

class AppSettingsStore {
  AppSettingsStore._();
  static final AppSettingsStore instance = AppSettingsStore._();
  static StreamController<void>? _changesController;

  static const _rateKey = 'settings_rate_per_kwh'; // in dollars, e.g., 0.15
  static const _budgetKey = 'settings_daily_budget'; // in dollars, e.g., 8.0
  static const _homeLabelKey = 'settings_home_label';
  static const _utilityCompanyKey = 'settings_utility_company';
  static const _homeTypeKey = 'settings_home_type';
  static const _networkStateKey = 'settings_network_state';
  static const _tdspCompanyKey = 'settings_tdsp_company';
  static const _retailProviderKey = 'settings_retail_provider';
  static const _onboardingCompletedKey = 'settings_onboarding_completed';
  static const _trialStartDateKey = 'settings_trial_start_date';
  static const _rememberMeKey = 'settings_remember_me';
  static const _savedUsernameKey = 'settings_saved_username';
  static const _savedPasswordKey = 'settings_saved_password';
  static const _savedEsiidKey = 'settings_saved_esiid';
  static const _alertCostLimitKey = 'settings_alert_cost_limit';
  static const _alertPeakHourKey = 'settings_alert_peak_hour';
  static const _alertWeeklySummaryKey = 'settings_alert_weekly_summary';

  double? _ratePerKwh;
  double? _dailyBudget;
  String? _homeLabel;
  String? _utilityCompany;
  String? _homeType;
  String? _networkState;
  String? _tdspCompany;
  String? _retailProvider;
  bool _hasCompletedOnboarding = false;
  DateTime? _trialStartDate;
  bool _rememberMe = false;
  String? _savedUsername;
  String? _savedPassword;
  String? _savedEsiid;
  bool _alertCostLimit = true;
  bool _alertPeakHour = true;
  bool _alertWeeklySummary = false;

  double get ratePerKwh => _ratePerKwh ?? 0.15;
  double get dailyBudget => _dailyBudget ?? 8.0;
  String? get homeLabel => _homeLabel;
  String? get utilityCompany => _utilityCompany;
  String? get homeType => _homeType;
  String? get networkState => _networkState;
  String? get tdspCompany => _tdspCompany;
  String? get retailProvider => _retailProvider;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  DateTime? get trialStartDate => _trialStartDate;
  bool get rememberMe => _rememberMe;
  String? get savedUsername => _savedUsername;
  String? get savedPassword => _savedPassword;
  String? get savedEsiid => _savedEsiid;
  bool get alertCostLimit => _alertCostLimit;
  bool get alertPeakHour => _alertPeakHour;
  bool get alertWeeklySummary => _alertWeeklySummary;

  bool get isFreeTrialActive {
    return TrialLogic.isTrialActive(_trialStartDate);
  }
  int get freeTrialDaysRemaining {
    return TrialLogic.daysRemaining(_trialStartDate);
  }
  Stream<void> get changes =>
      (_changesController ??= StreamController<void>.broadcast()).stream;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ratePerKwh = prefs.getDouble(_rateKey);
    _dailyBudget = prefs.getDouble(_budgetKey);
    _homeLabel = prefs.getString(_homeLabelKey);
    _utilityCompany = prefs.getString(_utilityCompanyKey);
    _homeType = prefs.getString(_homeTypeKey);
    _networkState = prefs.getString(_networkStateKey);
    _tdspCompany = prefs.getString(_tdspCompanyKey);
    _retailProvider = prefs.getString(_retailProviderKey);
    _hasCompletedOnboarding = prefs.getBool(_onboardingCompletedKey) ?? false;
    final trialRaw = prefs.getString(_trialStartDateKey);
    _trialStartDate = trialRaw != null ? DateTime.tryParse(trialRaw) : null;
    _rememberMe = prefs.getBool(_rememberMeKey) ?? false;
    _savedUsername = prefs.getString(_savedUsernameKey);
    _savedPassword = prefs.getString(_savedPasswordKey);
    _savedEsiid = prefs.getString(_savedEsiidKey);
    _alertCostLimit = prefs.getBool(_alertCostLimitKey) ?? true;
    _alertPeakHour = prefs.getBool(_alertPeakHourKey) ?? true;
    _alertWeeklySummary = prefs.getBool(_alertWeeklySummaryKey) ?? false;
  }

  Future<void> setRatePerKwh(double dollarsPerKwh) async {
    _ratePerKwh = dollarsPerKwh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rateKey, dollarsPerKwh);
    _changesController?.add(null);
  }

  Future<void> setDailyBudget(double dollars) async {
    _dailyBudget = dollars;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, dollars);
    _changesController?.add(null);
  }

  Future<void> setHomeLabel(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      _homeLabel = null;
      await prefs.remove(_homeLabelKey);
    } else {
      _homeLabel = trimmed;
      await prefs.setString(_homeLabelKey, trimmed);
    }
    _changesController?.add(null);
  }

  Future<void> setUtilityCompany(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      _utilityCompany = null;
      await prefs.remove(_utilityCompanyKey);
    } else {
      _utilityCompany = trimmed;
      await prefs.setString(_utilityCompanyKey, trimmed);
    }
    _changesController?.add(null);
  }

  Future<void> setHomeType(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      _homeType = null;
      await prefs.remove(_homeTypeKey);
    } else {
      _homeType = trimmed;
      await prefs.setString(_homeTypeKey, trimmed);
    }
    _changesController?.add(null);
  }

  Future<void> setNetworkState(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      _networkState = null;
      await prefs.remove(_networkStateKey);
    } else {
      _networkState = trimmed;
      await prefs.setString(_networkStateKey, trimmed);
    }
    _changesController?.add(null);
  }

  Future<void> setTdspCompany(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      _tdspCompany = null;
      await prefs.remove(_tdspCompanyKey);
    } else {
      _tdspCompany = trimmed;
      await prefs.setString(_tdspCompanyKey, trimmed);
    }
    _changesController?.add(null);
  }

  Future<void> setRetailProvider(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      _retailProvider = null;
      await prefs.remove(_retailProviderKey);
    } else {
      _retailProvider = trimmed;
      await prefs.setString(_retailProviderKey, trimmed);
    }
    _changesController?.add(null);
  }

  Future<void> setHasCompletedOnboarding(bool value) async {
    _hasCompletedOnboarding = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, value);
    _changesController?.add(null);
  }

  Future<void> ensureTrialStarted() async {
    if (_trialStartDate != null) return;
    _trialStartDate = DateTime.now().toUtc();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trialStartDateKey, _trialStartDate!.toIso8601String());
    _changesController?.add(null);
  }

  Future<void> clearTrial() async {
    _trialStartDate = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_trialStartDateKey);
    _changesController?.add(null);
  }

  Future<void> setRememberMe(bool value) async {
    _rememberMe = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
    if (!value) {
      // Clear saved credentials when remember-me is turned off.
      _savedUsername = null;
      _savedPassword = null;
      _savedEsiid = null;
      await prefs.remove(_savedUsernameKey);
      await prefs.remove(_savedPasswordKey);
      await prefs.remove(_savedEsiidKey);
    }
  }

  Future<void> saveLoginCredentials({
    required String username,
    required String password,
    required String esiid,
  }) async {
    _savedUsername = username;
    _savedPassword = password;
    _savedEsiid = esiid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedUsernameKey, username);
    await prefs.setString(_savedPasswordKey, password);
    await prefs.setString(_savedEsiidKey, esiid);
  }

  Future<void> setAlertCostLimit(bool value) async {
    _alertCostLimit = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alertCostLimitKey, value);
    _changesController?.add(null);
  }

  Future<void> setAlertPeakHour(bool value) async {
    _alertPeakHour = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alertPeakHourKey, value);
    _changesController?.add(null);
  }

  Future<void> setAlertWeeklySummary(bool value) async {
    _alertWeeklySummary = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alertWeeklySummaryKey, value);
    _changesController?.add(null);
  }

  Future<void> clearSavedCredentials() async {
    _savedUsername = null;
    _savedPassword = null;
    _savedEsiid = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedUsernameKey);
    await prefs.remove(_savedPasswordKey);
    await prefs.remove(_savedEsiidKey);
  }
}

