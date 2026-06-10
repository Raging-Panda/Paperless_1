import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SortOrder { dateDesc, dateAsc, amountDesc, amountAsc, merchantAsc }

class AppSettings {
  static final instance = AppSettings._();
  AppSettings._();

  static const _keyCurrency = 'currency_symbol';
  static const _keySort = 'sort_order';
  static const _keyBiometric = 'biometric_enabled';
  static const _keyTheme = 'theme_mode';
  static const _keyOnboarding = 'onboarding_complete';
  static const _keyBudgets = 'budgets';
  static const _keyDateFormat = 'date_format';
  static const _keyCompact = 'compact_mode';

  String _currencySymbol = r'$';
  String get currencySymbol => _currencySymbol;

  SortOrder _sortOrder = SortOrder.dateDesc;
  SortOrder get sortOrder => _sortOrder;

  bool _biometricEnabled = false;
  bool get biometricEnabled => _biometricEnabled;

  bool _onboardingComplete = false;
  bool get onboardingComplete => _onboardingComplete;

  Map<String, double> _budgets = {};
  Map<String, double> get budgets => Map.unmodifiable(_budgets);

  /// One of: 'YYYY-MM-DD'  'MM/DD/YYYY'  'DD/MM/YYYY'
  String _dateFormat = 'YYYY-MM-DD';
  String get dateFormat => _dateFormat;

  bool _compactMode = false;
  bool get compactMode => _compactMode;

  late ValueNotifier<ThemeMode> themeNotifier;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _currencySymbol = prefs.getString(_keyCurrency) ?? r'$';
    _sortOrder = SortOrder.values.firstWhere(
      (e) => e.name == prefs.getString(_keySort),
      orElse: () => SortOrder.dateDesc,
    );
    _biometricEnabled = prefs.getBool(_keyBiometric) ?? false;
    _onboardingComplete = prefs.getBool(_keyOnboarding) ?? false;
    _dateFormat = prefs.getString(_keyDateFormat) ?? 'YYYY-MM-DD';
    _compactMode = prefs.getBool(_keyCompact) ?? false;
    final budgetsJson = prefs.getString(_keyBudgets);
    if (budgetsJson != null) {
      final raw = jsonDecode(budgetsJson) as Map<String, dynamic>;
      _budgets = raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }
    themeNotifier = ValueNotifier(
      ThemeMode.values.firstWhere(
        (e) => e.name == prefs.getString(_keyTheme),
        orElse: () => ThemeMode.system,
      ),
    );
  }

  Future<void> setCurrencySymbol(String symbol) async {
    _currencySymbol = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, symbol);
  }

  Future<void> setSortOrder(SortOrder order) async {
    _sortOrder = order;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySort, order.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, mode.name);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometric, enabled);
  }

  Future<void> setDateFormat(String format) async {
    _dateFormat = format;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDateFormat, format);
  }

  Future<void> setCompactMode(bool compact) async {
    _compactMode = compact;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCompact, compact);
  }

  /// Formats an ISO-8601 date string using the active date format preference.
  String formatDate(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return isoDate;
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return switch (_dateFormat) {
      'MM/DD/YYYY' => '$m/$dd/$y',
      'DD/MM/YYYY' => '$dd/$m/$y',
      _ => '$y-$m-$dd',
    };
  }

  Future<void> setBudget(String category, double? limit) async {
    if (limit == null || limit <= 0) {
      _budgets.remove(category);
    } else {
      _budgets[category] = limit;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBudgets, jsonEncode(_budgets));
  }

  Future<void> setOnboardingComplete() async {
    _onboardingComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarding, true);
  }
}
