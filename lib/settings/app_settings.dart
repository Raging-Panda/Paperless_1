import 'package:shared_preferences/shared_preferences.dart';

enum SortOrder { dateDesc, dateAsc, amountDesc, amountAsc, merchantAsc }

class AppSettings {
  static final instance = AppSettings._();
  AppSettings._();

  static const _keyCurrency = 'currency_symbol';
  static const _keySort = 'sort_order';

  String _currencySymbol = r'$';
  String get currencySymbol => _currencySymbol;

  SortOrder _sortOrder = SortOrder.dateDesc;
  SortOrder get sortOrder => _sortOrder;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _currencySymbol = prefs.getString(_keyCurrency) ?? r'$';
    _sortOrder = SortOrder.values.firstWhere(
      (e) => e.name == prefs.getString(_keySort),
      orElse: () => SortOrder.dateDesc,
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
}
