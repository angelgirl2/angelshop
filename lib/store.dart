// ignore_for_file: curly_braces_in_flow_control_structures, unused_field

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Cfg {
  // در گیت‌هاب از طریق --dart-define=API_URL تنظیم می‌شود
  static const api = String.fromEnvironment(
    'API_URL',
    defaultValue:
        'https://angel-shop.angelgirl2-bigsister-1383200784.workers.dev',
  );
  static const rubika = 'https://rubika.ir/angelgirlbrand';
  static const telegram = 'https://t.me/angelgirlbrand';
  static const whatsapp = 'https://wa.me/+989220423035';
  static const bale = 'https://ble.ir/angelgirlbrand';
  static const baleChannel = 'https://ble.ir/angelgirlshop';
  static const phone = 'tel:+989220423035';
}

class Product {
  final String id, name, image, category, description, localAsset;
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
    this.localAsset,
  );
  bool get inStock => stock == null || stock! > 0;
  factory Product.fromJson(Map j, {required int index}) => Product(
    '${j['id']}',
    '${j['name']}',
    int.tryParse('${j['price']}') ?? 0,
    '${j['image'] ?? ''}',
    '${j['category'] ?? ''}',
    '${j['description'] ?? ''}',
    j['stock'] == null ? null : int.tryParse('${j['stock']}'),
    'assets/product/${((int.tryParse('${j['catalog_index']}') ?? index) + 1).toString().padLeft(2, '0')}.png',
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
  String? discountCode, discountError;
  int discountAmount = 0;
  Map<String, dynamic>? lastOrderInfo;
  late Future<void> ready;
  Timer? _timer;
  WebSocketChannel? _liveChannel;
  StreamSubscription? _liveSubscription;
  Timer? _liveReconnect;

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
    _connectLive();
    _liveReconnect = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_liveChannel == null) _connectLive();
    });
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
  }

  void _connectLive() {
    try {
      final base = Cfg.api
          .replaceFirst(RegExp(r'^https:'), 'wss:')
          .replaceFirst(RegExp(r'^http:'), 'ws:');
      final channel = WebSocketChannel.connect(Uri.parse('$base/live'));
      _liveChannel = channel;
      _liveSubscription = channel.stream.listen(
        (event) async {
          if (event is! String || event.isEmpty) return;
          try {
            final data = Map<String, dynamic>.from(jsonDecode(event));
            if (data['products'] is List) {
              _setProducts(List.from(data['products']));
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('products', jsonEncode(data['products']));
              notifyListeners();
            }
            if (data['type'] == 'orders' || data['type'] == 'tickets')
              refresh();
          } catch (_) {
            refresh();
          }
        },
        onError: (_) {
          _liveChannel = null;
        },
        onDone: () {
          _liveChannel = null;
        },
      );
    } catch (_) {
      _liveChannel = null;
    }
  }

  void _setProducts(List l) {
    // ترتیب API دقیقاً از ترتیب worker/products.json می‌آید؛ تصویر محلی بر اساس همین ترتیب متصل می‌شود.
    products = List.generate(
      l.length,
      (index) => Product.fromJson(l[index], index: index),
    );
    cart.removeWhere((id, _) => !products.any((p) => p.id == id && p.inStock));
  }

  Future<void> refresh() async {
    try {
      final r = await http
          .get(_u('/products'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        _setProducts(_body(r));
        await (await SharedPreferences.getInstance()).setString(
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
      await p.setString('token', token!);
      await p.setString('name', userName!);
      await p.setString('phone', userPhone!);
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
      await p.remove(k);
    }
    notifyListeners();
  }

  int get cartCount => cart.values.fold(0, (a, b) => a + b);
  int get cartTotal => cart.entries.fold(
    0,
    (s, e) => s + products.firstWhere((p) => p.id == e.key).price * e.value,
  );
  int get cartFinalTotal => (cartTotal - discountAmount).clamp(0, cartTotal);

  Future<String?> applyDiscount(String code) async {
    discountError = null;
    try {
      final r = await http
          .post(
            _u('/discount/validate'),
            headers: _h,
            body: jsonEncode({'code': code, 'subtotal': cartTotal}),
          )
          .timeout(const Duration(seconds: 20));
      final j = Map<String, dynamic>.from(_body(r));
      if (r.statusCode != 200) {
        discountCode = null;
        discountAmount = 0;
        discountError = j['error'] ?? 'کد تخفیف نامعتبر است';
        notifyListeners();
        return discountError;
      }
      discountCode = '${j['code']}';
      discountAmount = int.tryParse('${j['discount']}') ?? 0;
      notifyListeners();
      return null;
    } catch (_) {
      discountError = 'بررسی کد تخفیف ممکن نشد';
      notifyListeners();
      return discountError;
    }
  }

  void clearDiscount() {
    discountCode = null;
    discountAmount = 0;
    discountError = null;
    notifyListeners();
  }

  void add(Product p) {
    if (!p.inStock) return;
    final n = (cart[p.id] ?? 0) + 1;
    if (p.stock != null && n > p.stock!) return;
    cart[p.id] = n;
    discountCode = null;
    discountAmount = 0;
    notifyListeners();
  }

  void remove(Product p) {
    final n = (cart[p.id] ?? 0) - 1;
    n <= 0 ? cart.remove(p.id) : cart[p.id] = n;
    discountCode = null;
    discountAmount = 0;
    notifyListeners();
  }

  Future<Map<String, dynamic>> supportTickets() async {
    final r = await http
        .get(_u('/support/tickets'), headers: _h)
        .timeout(const Duration(seconds: 20));
    final j = Map<String, dynamic>.from(_body(r));
    if (r.statusCode != 200)
      throw Exception(j['error'] ?? 'دریافت تیکت‌ها ناموفق بود');
    return j;
  }

  Future<Map<String, dynamic>> createSupportTicket(
    String subject,
    String message,
  ) async {
    final r = await http
        .post(
          _u('/support/tickets'),
          headers: _h,
          body: jsonEncode({'subject': subject, 'message': message}),
        )
        .timeout(const Duration(seconds: 30));
    final j = Map<String, dynamic>.from(_body(r));
    if (r.statusCode != 200)
      throw Exception(j['error'] ?? 'ثبت تیکت ناموفق بود');
    return j;
  }

  Future<Map<String, dynamic>> supportMessages(String id) async {
    final r = await http
        .get(_u('/support/tickets/$id/messages'), headers: _h)
        .timeout(const Duration(seconds: 20));
    final j = Map<String, dynamic>.from(_body(r));
    if (r.statusCode != 200 || j.containsKey('error'))
      throw Exception(j['error'] ?? 'دریافت پیام‌ها ناموفق بود');
    return j;
  }

  Future<Map<String, dynamic>> uploadSupportFile(
    String name,
    String mime,
    Uint8List bytes,
  ) async {
    final r = await http
        .post(
          _u('/support/upload'),
          headers: _h,
          body: jsonEncode({
            'name': name,
            'mime': mime,
            'data': base64Encode(bytes),
          }),
        )
        .timeout(const Duration(seconds: 60));
    final j = Map<String, dynamic>.from(_body(r));
    if (r.statusCode != 200)
      throw Exception(j['error'] ?? 'بارگذاری فایل ناموفق بود');
    return j;
  }

  Future<Uint8List> downloadSupportFile(String id) async {
    final r = await http
        .get(_u('/support/files/$id'), headers: _h)
        .timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) throw Exception('دریافت فایل ناموفق بود');
    return r.bodyBytes;
  }

  Future<Map<String, dynamic>> sendSupportMessage(
    String id,
    String message, {
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final r = await http
        .post(
          _u('/support/tickets/$id/messages'),
          headers: _h,
          body: jsonEncode({'message': message, 'attachments': attachments}),
        )
        .timeout(const Duration(seconds: 30));
    final j = Map<String, dynamic>.from(_body(r));
    if (r.statusCode != 200)
      throw Exception(j['error'] ?? 'ارسال پیام ناموفق بود');
    return j;
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
              if (discountCode != null) 'discount_code': discountCode,
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
      lastOrderInfo = Map<String, dynamic>.from(_body(r));
      cart.clear();
      discountCode = null;
      discountAmount = 0;
      discountError = null;
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _liveReconnect?.cancel();
    _liveSubscription?.cancel();
    _liveChannel?.sink.close();
    super.dispose();
  }
}

final store = Store();
