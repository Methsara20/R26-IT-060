import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // In-memory data for Viva demo
  final List<Map<String, dynamic>> _cartItems = [];
  final List<Map<String, dynamic>> _favoriteItems = [];
  final List<Map<String, dynamic>> _orderHistory = [];

  List<Map<String, dynamic>> get cartItems => List.unmodifiable(_cartItems);
  List<Map<String, dynamic>> get favoriteItems => List.unmodifiable(_favoriteItems);
  List<Map<String, dynamic>> get orderHistory => List.unmodifiable(_orderHistory);

  double get cartTotal {
    double total = 0.0;
    for (var item in _cartItems) {
      final price = (item['price_lkr'] ?? 0.0) is int 
          ? (item['price_lkr'] as int).toDouble() 
          : item['price_lkr'] as double;
      total += price;
    }
    return total;
  }

  void addToCart(Map<String, dynamic> product) {
    _cartItems.add(Map.from(product)); // Add a copy
    notifyListeners();
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
    }
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  void toggleFavorite(Map<String, dynamic> product) {
    final existingIndex = _favoriteItems.indexWhere((p) => p['id'] == product['id']);
    if (existingIndex >= 0) {
      _favoriteItems.removeAt(existingIndex);
    } else {
      _favoriteItems.add(Map.from(product));
    }
    notifyListeners();
  }

  bool isFavorite(Map<String, dynamic> product) {
    return _favoriteItems.any((p) => p['id'] == product['id']);
  }

  void checkout(String paymentMethod) {
    if (_cartItems.isEmpty) return;

    final newOrder = {
      'order_id': 'ORD-\${DateTime.now().millisecondsSinceEpoch}',
      'date': DateTime.now().toIso8601String(),
      'total': cartTotal,
      'items': List.from(_cartItems),
      'payment_method': paymentMethod,
    };

    _orderHistory.insert(0, newOrder);
    _cartItems.clear();
    notifyListeners();
  }
}
