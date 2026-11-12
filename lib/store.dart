// ignore_for_file: curly_braces_in_flow_control_structures, unused_field

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Cfg {
  // در گیت‌هاب از طریق --dart-define=API_URL تنظیم می‌شود
  static const api = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://angel-shop.YOUR_SUBDOMAIN.workers.dev',
  );
  static const rubika = 'https://rubika.ir/angelgirlbrand';
  static const telegram = 'https://t.me/angelgirlbrand';
  static const whatsapp = 'https://wa.me/+989220423035';
  static const bale = 'https://ble.ir/angelgirlbrand';
  static const baleChannel = 'https://ble.ir/angelshop';
  static const phone = 'tel:+989220423035';
}

class Product {
  final String id, name, image, category, description;
  final int price;
  final int? stock; // null = نامحدود، 0 = اتمام موجودی
  Product(
    this.id,
    this.name,
    this.price,
    this.image,
    this.category,
    this.description,
    this.stock,
  );
  bool get inStock => stock == null || stock! > 0;
  factory Product.fromJson(Map j) => Product(
    '${j['id']}',
    '${j['name']}',
    int.tryParse('${j['price']}') ?? 0,
    '${j['image'] ?? ''}',
    '${j['category'] ?? ''}',
    '${j['description'] ?? ''}',
    j['stock'] == null ? null : int.tryParse('${j['stock']}'),
  );
}

class Order {
  final String code, date, status; // pending | approved | rejected
  final List<Map> items;
  final int total;
  Order(this.code, this.date, this.items, this.total, this.status);
  factory Order.fromJson(Map j) => Order(
    j['code'],
    '${j['date']}',
    List<Map>.from(j['items']),
    j['total'],
    j['status'],
  );
}

class Store extends ChangeNotifier {
  List<Product> products = [];
  List<Order> orders = [];
  final Map<String, int> cart = {};
  String? token, userName, userPhone, lastError;
  late Future<void> ready;
  Timer? _timer;

  Map<String, String> get _h => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
  Uri _u(String p) => Uri.parse('${Cfg.api}$p');
  dynamic _body(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes));

  List<String> get categories {
    final s = <String>[];
    for (final p in products) {
      if (p.category.isNotEmpty && !s.contains(p.category)) s.add(p.category);
    }
    return s;
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
    userName = p.getString('name');
    userPhone = p.getString('phone');
    final cached = p.getString('products');
    if (cached != null) _setProducts(jsonDecode(cached));
    notifyListeners();
    await refresh();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
  }

  void _setProducts(List l) {
    products = l.map((e) => Product.fromJson(e)).toList();
    cart.removeWhere((id, _) => !products.any((p) => p.id == id && p.inStock));
  }

  Future<void> refresh() async {
    try {
      final r = await http
          .get(_u('/products'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        _setProducts(_body(r));
        (await SharedPreferences.getInstance()).setString(
          'products',
          utf8.decode(r.bodyBytes),
        );
      }
      if (token != null) {
        final o = await http
            .get(_u('/orders'), headers: _h)
            .timeout(const Duration(seconds: 15));
        if (o.statusCode == 401) return _clear();
        if (o.statusCode == 200)
          orders = (_body(o) as List).map((e) => Order.fromJson(e)).toList();
      }
    } catch (_) {}
    notifyListeners();
  }

  // ثبت‌نام / ورود؛ در صورت خطا متن خطا را برمی‌گرداند
  Future<String?> auth(
    bool register, {
    String name = '',
    required String phone,
    required String password,
  }) async {
    try {
      final r = await http
          .post(
            _u(register ? '/register' : '/login'),
            headers: _h,
            body: jsonEncode({
              'name': name,
              'phone': phone,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));
      final j = _body(r);
      if (r.statusCode != 200) return j['error'] ?? 'خطای نامشخص';
      token = j['token'];
      userName = j['user']['name'];
      userPhone = j['user']['phone'];
      final p = await SharedPreferences.getInstance();
      p.setString('token', token!);
      p.setString('name', userName!);
      p.setString('phone', userPhone!);
      orders = [];
      cart.clear();
      notifyListeners();
      refresh();
      return null;
    } catch (_) {
      return 'اتصال به سرور برقرار نشد';
    }
  }

  Future<void> logout() async {
    try {
      await http
          .post(_u('/logout'), headers: _h)
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
    await _clear();
  }

  Future<void> _clear() async {
    token = userName = userPhone = null;
    orders = [];
    cart.clear();
    final p = await SharedPreferences.getInstance();
    for (final k in ['token', 'name', 'phone']) {
      p.remove(k);
    }
    notifyListeners();
  }

  int get cartCount => cart.values.fold(0, (a, b) => a + b);
  int get cartTotal => cart.entries.fold(
    0,
    (s, e) => s + products.firstWhere((p) => p.id == e.key).price * e.value,
  );

  void add(Product p) {
    if (!p.inStock) return;
    final n = (cart[p.id] ?? 0) + 1;
    if (p.stock != null && n > p.stock!) return;
    cart[p.id] = n;
    notifyListeners();
  }

  void remove(Product p) {
    final n = (cart[p.id] ?? 0) - 1;
    n <= 0 ? cart.remove(p.id) : cart[p.id] = n;
    notifyListeners();
  }

  Future<bool> submit() async {
    lastError = null;
    try {
      final r = await http
          .post(
            _u('/order'),
            headers: _h,
            body: jsonEncode({
              'items': cart.entries
                  .map((e) => {'id': e.key, 'qty': e.value})
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 401) {
        await _clear();
        return false;
      }
      if (r.statusCode != 200) {
        lastError = _body(r)['error'];
        await refresh();
        return false;
      }
      cart.clear();
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final store = Store();
