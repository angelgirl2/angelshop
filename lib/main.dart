import 'dart:async';
import 'dart:ui';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:url_launcher/url_launcher.dart';
import 'store.dart';
import 'angel_notice.dart';
import 'admin.dart';

// ===================== تنظیمات (این بخش را پر کنید) =====================
const bg = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1A0B2E), Color(0xFF4A148C), Color(0xFF7B1FA2)],
);

class AppLogo extends StatelessWidget {
  final double size;
  final bool glow;
  const AppLogo({super.key, required this.size, this.glow = false});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: .35), width: 2),
      boxShadow: glow
          ? [
              BoxShadow(
                color: Colors.purpleAccent.withValues(alpha: .5),
                blurRadius: 30,
              ),
            ]
          : null,
    ),
    child: ClipOval(
      child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
    ),
  );
}

String money(int n) =>
    '${n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')} تومان';

String persianDateTime([DateTime? value]) {
  final d = (value ?? DateTime.now()).toUtc().add(const Duration(hours: 3, minutes: 30));
  final j = Jalali.fromDateTime(d);
  String two(int n) => n.toString().padLeft(2, '0');
  final raw = '\u200f${j.year}/${two(j.month)}/${two(j.day)}  ${two(d.hour)}:${two(d.minute)}';
  return raw.replaceAllMapped(RegExp(r'[0-9]'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);
}

// ===================== مدل‌ها =====================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  store.ready = store.init();
  runApp(const AngelApp());
}

class AngelApp extends StatelessWidget {
  const AngelApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Angel shop',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB45BEA), brightness: Brightness.dark, primary: const Color(0xFFD2A1FF), secondary: const Color(0xFF9E67E8), surface: const Color(0xFF1C1029)),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: const Color(0xFF1B1027),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF311B46), contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white24)), insetPadding: const EdgeInsets.fromLTRB(14, 0, 14, 18)),
      appBarTheme: const AppBarTheme(foregroundColor: Colors.white, surfaceTintColor: Colors.transparent, elevation: 0),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9147C2), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))),
      inputDecorationTheme: const InputDecorationTheme(filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide.none)),
      dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF241532), surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
    ),
    builder: (c, w) =>
        Directionality(textDirection: TextDirection.rtl, child: w!),
    home: const Splash(),
  );
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    Future.wait([
      Future.delayed(const Duration(milliseconds: 1900)),
      store.ready,
    ]).then((_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Root()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: bg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .82, end: 1),
              duration: const Duration(milliseconds: 1050),
              curve: Curves.easeOutBack,
              builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
              child: const AppLogo(size: 130, glow: true),
            ),
            const SizedBox(height: 24),
            const Text(
              'Angel shop',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('angelgirlbrand', style: TextStyle(fontSize: 12, letterSpacing: 3, color: Colors.white70)),
            const SizedBox(height: 34),
            const SizedBox(width: 190, child: LinearProgressIndicator(minHeight: 3, borderRadius: BorderRadius.all(Radius.circular(8)), backgroundColor: Colors.white12, color: Color(0xFFE0B8FF))),
            const SizedBox(height: 17),
            const SizedBox(width: 38, height: 38, child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFE5C4FF))),
            const SizedBox(height: 12),
            const Text('در حال بارگذاری...', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: .3)),
          ],
        ),
      ),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  static const tabs = [
    [Icons.home_rounded, 'خانه'],
    [Icons.grid_view_rounded, 'دسته‌بندی'],
    [Icons.shopping_cart_rounded, 'سبد'],
    [Icons.receipt_long_rounded, 'سفارشات'],
    [Icons.support_agent_rounded, 'پشتیبانی'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: bg),
      child: Scaffold(
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: store,
            builder: (_, _) => IndexedStack(
              index: i,
              children: [
                HomePage(),
                CategoriesPage(),
                CartPage(),
                OrdersPage(),
                SupportPage(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .25),
                  ),
                ),
                child: ListenableBuilder(
                  listenable: store,
                  builder: (_, _) => Row(
                    children: List.generate(tabs.length, (n) {
                      final sel = n == i;
                      Widget icon = Icon(
                        tabs[n][0] as IconData,
                        color: sel ? Colors.white : Colors.white60,
                        size: sel ? 28 : 24,
                      );
                      if (n == 2 && store.cartCount > 0) {
                        icon = Badge(
                          label: Text('${store.cartCount}'),
                          child: icon,
                        );
                      }
                      return Expanded(
                        child: InkWell(
                          onTap: () => setState(() => i = n),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              icon,
                              const SizedBox(height: 3),
                              Text(
                                tabs[n][1] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: sel ? Colors.white : Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
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

// ===================== صفحات =====================
Widget glass({required Widget child, EdgeInsets? padding}) => ClipRRect(
  borderRadius: BorderRadius.circular(20),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .15)),
      ),
      child: child,
    ),
  ),
);

IconData catIcon(String c) {
  if (c.contains('آرایش')) return Icons.brush;
  if (c.contains('پروتئین')) return Icons.fitness_center;
  if (c.contains('دمنوش')) return Icons.emoji_food_beverage;
  if (c.contains('بهداشت')) return Icons.health_and_safety;
  if (c.contains('غذا')) return Icons.restaurant;
  if (c.contains('شوینده')) return Icons.clean_hands;
  return Icons.category;
}

Widget grayed(bool on, Widget c) => on
    ? ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
        child: Opacity(opacity: .55, child: c),
      )
    : c;

Widget priceText(Product p, {double size = 12}) => p.inStock
    ? Text(
        money(p.price),
        style: TextStyle(fontSize: size, color: Colors.amberAccent),
      )
    : Text(
        'اتمام موجودی',
        style: TextStyle(
          fontSize: size,
          color: Colors.redAccent.shade100,
          fontWeight: FontWeight.bold,
        ),
      );

Widget productImage(Product p, {double? height}) {
  final image = p.image.trim();
  Widget fallback() => SizedBox(
    height: height,
    child: const Center(child: Icon(Icons.image_not_supported_outlined)),
  );
  if (image.isNotEmpty) {
    final uri = image.startsWith('http') ? image : '${Cfg.api}$image';
    return Image.network(
      uri,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Image.asset(
        p.localAsset,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      ),
    );
  }
  return Image.asset(
    p.localAsset,
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => fallback(),
  );
}

class ProductGrid extends StatelessWidget {
  final List<Product> list;
  const ProductGrid(this.list, {super.key});
  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return const Center(child: Text('محصولی موجود نیست'));
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: .66,
      ),
      itemCount: list.length,
      itemBuilder: (_, n) {
        final p = list[n];
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProductPage(p.id)),
          ),
          child: glass(
            padding: const EdgeInsets.all(8),
            child: grayed(
              !p.inStock,
              Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: productImage(p),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  priceText(p),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: p.inStock ? () { store.add(p); AngelNotice.show(context, 'محصول به سبد خرید اضافه شد'); } : null,
                      child: Text(p.inStock ? 'افزودن به سبد' : 'ناموجود'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ProductPage extends StatelessWidget {
  final String id;
  const ProductPage(this.id, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: bg),
    child: Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: ListenableBuilder(
        listenable: store,
        builder: (_, _) {
          final i = store.products.indexWhere((p) => p.id == id);
          if (i < 0) {
            return const Center(child: Text('این محصول دیگر موجود نیست'));
          }
          final p = store.products[i];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: grayed(
                  !p.inStock,
                  productImage(p, height: 280),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                p.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              priceText(p, size: 16),
              const SizedBox(height: 16),
              glass(
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('توضیحات کامل محصول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE6C8FF))),
                      const SizedBox(height: 10),
                      SelectableText(
                        p.description.isEmpty
                            ? 'توضیحاتی برای این محصول ثبت نشده است.'
                            : p.description,
                        style: const TextStyle(height: 1.9),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: p.inStock
                    ? () {
                        store.add(p);
                        AngelNotice.show(context, 'محصول به سبد خرید اضافه شد');
                      }
                    : null,
                child: Text(p.inStock ? 'افزودن به سبد' : 'اتمام موجودی'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final list = store.products.where((p) => p.name.contains(q)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            HiddenAdminLogo(size: 38),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Angel Shop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: .3)),
              Text('انتخابی متفاوت، خریدی آسان', style: TextStyle(color: Colors.white60, fontSize: 11)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .09), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)), child: const Row(children: [Icon(Icons.auto_awesome, size: 15, color: Color(0xFFE3B8FF)), SizedBox(width: 5), Text('2027', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(
              hintText: 'جستجو در Angel shop',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(child: ProductGrid(list)),
      ],
    );
  }
}

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = store.categories;
    if (cs.isEmpty) {
      return const Center(child: Text('در حال دریافت دسته‌بندی‌ها...'));
    }
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: cs
          .map(
            (c) => InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CategoryPage(c)),
              ),
              child: glass(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      catIcon(c),
                      size: 46,
                      color: Colors.purpleAccent.shade100,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      c,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class CategoryPage extends StatelessWidget {
  final String cat;
  const CategoryPage(this.cat, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: bg),
    child: Scaffold(
      appBar: AppBar(title: Text(cat), backgroundColor: Colors.transparent),
      body: ListenableBuilder(
        listenable: store,
        builder: (_, _) => ProductGrid(
          store.products.where((p) => p.category == cat).toList(),
        ),
      ),
    ),
  );
}

class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final discount = TextEditingController();
  bool checking = false, submitting = false;
  @override
  void dispose() { discount.dispose(); super.dispose(); }

  Future<void> _applyDiscount() async {
    setState(() => checking = true);
    final error = await store.applyDiscount(discount.text.trim());
    if (mounted) {
      setState(() => checking = false);
      AngelNotice.show(context, error ?? 'کد تخفیف اعمال شد');
    }
  }

  void _showInvoice(Map<String, dynamic> order) {
    final key = GlobalKey();
    Uint8List? imageBytes;
    bool capturing = false;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      if (!capturing && imageBytes == null) {
        capturing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
            if (boundary == null) return;
            final image = await boundary.toImage(pixelRatio: 3);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            if (data != null && ctx.mounted) setDialogState(() => imageBytes = data.buffer.asUint8List());
            image.dispose();
          } catch (_) {}
        });
      }
      final invoice = Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF180D25), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFB66BE5), width: 1.5)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(child: Icon(Icons.auto_awesome, color: Color(0xFFD8A8FF), size: 34)),
          const Center(child: Text('ANGEL SHOP', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 20, color: Color(0xFFE6C8FF)))),
          const Center(child: Text('فاکتور ثبت سفارش', style: TextStyle(color: Colors.white70))),
          const Divider(height: 28, color: Colors.white30),
          Text('شماره سفارش: ${order['code']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('مشتری: ${store.userName ?? ''}'),
          Text('تاریخ: ${persianDateTime()}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
          const Divider(height: 24, color: Colors.white30),
          for (final item in (order['items'] as List? ?? const [])) _invoiceLine('${item['name']} × ${item['qty']}', money(((item['price'] as num?)?.toInt() ?? 0) * ((item['qty'] as num?)?.toInt() ?? 0))),
          const Divider(height: 24, color: Colors.white30),
          _invoiceLine('جمع کالاها', money((order['subtotal'] as num?)?.toInt() ?? 0)),
          _invoiceLine('تخفیف', money((order['discount'] as num?)?.toInt() ?? 0)),
          const Divider(color: Colors.white30),
          _invoiceLine('مبلغ نهایی', money((order['total'] as num?)?.toInt() ?? 0), strong: true),
          const SizedBox(height: 18),
          const Center(child: Text('با تشکر از خرید و اعتماد شما 💜', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFD8A8FF)))),
        ]),
      );
      return AlertDialog(
        backgroundColor: const Color(0xFF251535),
        title: const Text('فاکتور سفارش شما'),
        content: SingleChildScrollView(child: imageBytes == null ? RepaintBoundary(key: key, child: invoice) : Image.memory(imageBytes!, fit: BoxFit.contain)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))],
      );
    }));
  }

  Widget _invoiceLine(String label, String value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontWeight: strong ? FontWeight.bold : FontWeight.normal))), Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: strong ? const Color(0xFFE6C8FF) : Colors.white))]),
  );

  @override
  Widget build(BuildContext context) {
    if (store.cart.isEmpty) return const Center(child: Text('سبد خرید خالی است'));
    return Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 8), children: store.cart.entries.map((e) {
        final p = store.products.firstWhere((x) => x.id == e.key);
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: glass(child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset(p.localAsset, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 56, child: Icon(Icons.image)))),
          const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis), Text(money(p.price), style: const TextStyle(color: Colors.amberAccent, fontSize: 12))])),
          IconButton(onPressed: () => store.remove(p), icon: const Icon(Icons.remove_circle_outline)), Text('${e.value}'), IconButton(onPressed: () => store.add(p), icon: const Icon(Icons.add_circle_outline)),
        ])));
      }).toList())),
      Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 100), child: glass(child: Column(children: [
        Row(children: [Expanded(child: TextField(controller: discount, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(isDense: true, hintText: 'کد تخفیف', border: OutlineInputBorder()))), const SizedBox(width: 8), FilledButton(onPressed: checking ? null : _applyDiscount, child: checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('اعمال'))]),
        if (store.discountCode != null) Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16), const SizedBox(width: 6), Expanded(child: Text('کد ${store.discountCode} اعمال شد؛ تخفیف ${money(store.discountAmount)}')), TextButton(onPressed: () { store.clearDiscount(); discount.clear(); }, child: const Text('حذف'))])),
        if (store.discountError != null) Align(alignment: Alignment.centerRight, child: Text(store.discountError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
        const SizedBox(height: 12),
        _invoiceLine('جمع کل', money(store.cartTotal)),
        if (store.discountAmount > 0) _invoiceLine('تخفیف', money(store.discountAmount)),
        const Divider(), _invoiceLine('قابل پرداخت', money(store.cartFinalTotal), strong: true),
        const SizedBox(height: 10), SizedBox(width: double.infinity, child: FilledButton(onPressed: submitting ? null : () async {
          final messenger = ScaffoldMessenger.of(context);
          setState(() => submitting = true);
          final ok = await store.submit();
          if (!mounted) return;
          setState(() => submitting = false);
          if (ok && store.lastOrderInfo != null) {
            _showInvoice(store.lastOrderInfo!);
          } else {
            AngelNotice.show(context, store.lastError ?? 'ارسال ناموفق بود، دوباره تلاش کنید', error: true);
          }
        }, child: submitting ? const CircularProgressIndicator() : const Text('ثبت سفارش'))),
      ]))),
    ]);
  }
}

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});
  @override
  Widget build(BuildContext context) {
    if (store.orders.isEmpty) {
      return const Center(child: Text('هنوز سفارشی ثبت نکرده‌اید'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: store.orders.map((o) {
        final (color, label) = switch (o.status) {
          'approved' => (Colors.greenAccent.shade400, 'تأیید شد'),
          'rejected' => (Colors.redAccent, 'رد شد'),
          _ => (Colors.orangeAccent, 'در انتظار بررسی'),
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      o.code,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(color: color, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                ...o.items.map(
                  (i) => Text(
                    '• ${i['name']} × ${i['qty']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${o.date}  |  ${money(o.total)}',
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  Future<Map<String, dynamic>>? _tickets;
  @override
  void initState() { super.initState(); _load(); }
  void _load() => _tickets = store.supportTickets();
  Future<void> _newTicket() async {
    final message = TextEditingController();
    String selectedSubject = 'سوال درباره محصول';
    const subjects = ['سوال درباره محصول', 'پیگیری سفارش', 'پرداخت و تخفیف', 'ارسال و تحویل', 'مرجوعی و تعویض', 'سایر موارد'];
    final result = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: const Text('ثبت تیکت پشتیبانی'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: selectedSubject, decoration: const InputDecoration(labelText: 'موضوع تیکت'), items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) { if (v != null) setDialogState(() => selectedSubject = v); }),
        const SizedBox(height: 8),
        TextField(controller: message, minLines: 3, maxLines: 6, maxLength: 3000, decoration: const InputDecoration(labelText: 'شرح درخواست')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ثبت تیکت'))],
    )));
    if (result != true || message.text.trim().isEmpty) return;
    try {
      final data = await store.createSupportTicket(selectedSubject, message.text.trim());
      if (!mounted) return;
      AngelNotice.show(context, 'تیکت ${data['ticket']['id']} ثبت شد');
      setState(_load);
      Navigator.push(context, MaterialPageRoute(builder: (_) => SupportChatPage(ticket: Map<String, dynamic>.from(data['ticket'])))).then((_) { if (mounted) setState(_load); });
    } catch (e) { if (mounted) AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); }
  }
  @override
  Widget build(BuildContext context) {
    final items = [['روبیکا', Icons.chat_bubble, Cfg.rubika], ['تلگرام', Icons.send, Cfg.telegram], ['واتساپ', Icons.call_made, Cfg.whatsapp], ['بله', Icons.message, Cfg.bale], ['تماس', Icons.phone, Cfg.phone]];
    return RefreshIndicator(onRefresh: () async => setState(_load), child: ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: [
        glass(child: Row(children: [const Icon(Icons.account_circle, size: 38), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(store.userName ?? '', style: const TextStyle(fontWeight: FontWeight.bold)), Text(store.userPhone ?? '', style: const TextStyle(fontSize: 12, color: Colors.white60))])), IconButton(onPressed: store.logout, icon: const Icon(Icons.logout), tooltip: 'خروج از حساب')])),
        const SizedBox(height: 16),
        Row(children: [const Expanded(child: Text('پشتیبانی و تیکت‌ها', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), FilledButton.icon(onPressed: _newTicket, icon: const Icon(Icons.add), label: const Text('تیکت جدید'))]),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, dynamic>>(future: _tickets, builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
          if (snap.hasError) return glass(child: Text('دریافت تیکت‌ها ناموفق بود: ${snap.error}'));
          final data = snap.data ?? {};
          final list = List<Map>.from(data['tickets'] ?? const []);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (data['customer_id'] != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: glass(child: Row(children: [const Icon(Icons.badge_outlined), const SizedBox(width: 8), const Text('شناسه پشتیبانی شما:'), const Spacer(), SelectableText('${data['customer_id']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent))]))),
            if (list.isEmpty) glass(child: const Text('هنوز تیکتی ثبت نکرده‌اید. برای شروع، تیکت جدید را بزنید.')),
            ...list.map((t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupportChatPage(ticket: Map<String, dynamic>.from(t)))).then((_) { if (mounted) setState(_load); }), child: glass(child: Row(children: [const Icon(Icons.confirmation_number_outlined, color: Colors.purpleAccent), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${t['subject'] ?? 'تیکت'}', style: const TextStyle(fontWeight: FontWeight.bold)), Text('${t['id']}', style: const TextStyle(fontSize: 11, color: Colors.white60))])), Text(t['status'] == 'closed' ? 'بسته' : 'باز', style: TextStyle(color: t['status'] == 'closed' ? Colors.white54 : Colors.greenAccent)), const Icon(Icons.chevron_left)]))))),
          ]);
        }),
        const Divider(height: 28),
        const Text('راه‌های ارتباطی دیگر', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(onTap: () => launchUrl(Uri.parse(e[2] as String), mode: LaunchMode.externalApplication), child: glass(child: Row(children: [Icon(e[1] as IconData, color: Colors.purpleAccent.shade100), const SizedBox(width: 12), Text(e[0] as String), const Spacer(), const Icon(Icons.chevron_left)]))))),
        InkWell(onTap: () => launchUrl(Uri.parse(Cfg.baleChannel), mode: LaunchMode.externalApplication), child: glass(child: const Row(children: [Icon(Icons.campaign, color: Colors.amberAccent), SizedBox(width: 12), Text('ورود به کانال بله'), Spacer(), Icon(Icons.chevron_left)]))),
      ],
    ));
  }
}

class SupportChatPage extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const SupportChatPage({super.key, required this.ticket});
  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}
class _SupportChatPageState extends State<SupportChatPage> {
  final input = TextEditingController();
  List<Map> messages = [];
  bool busy = false;
  String ticketStatus = 'open';
  Timer? poll;
  @override
  void initState() { super.initState(); ticketStatus = '${widget.ticket['status'] ?? 'open'}'; _load(); poll = Timer.periodic(const Duration(seconds: 8), (_) => _load()); }
  @override
  void dispose() { poll?.cancel(); input.dispose(); super.dispose(); }
  Future<void> _load() async {
    try { final d = await store.supportMessages('${widget.ticket['id']}'); if (mounted) setState(() { messages = List<Map>.from(d['messages'] ?? []); ticketStatus = '${d['ticket']?['status'] ?? ticketStatus}'; }); } catch (_) {}
  }
  Future<void> _pickAttachment() async {
    if (busy) return;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg','jpeg','png','webp','gif','mp4','mov','webm','pdf','txt'], withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) throw Exception('خواندن فایل ممکن نشد');
      if (bytes.length > 5 * 1024 * 1024) throw Exception('حداکثر حجم فایل ۵ مگابایت است');
      final ext = (file.extension ?? '').toLowerCase();
      final mime = switch (ext) { 'jpg' || 'jpeg' => 'image/jpeg', 'png' => 'image/png', 'webp' => 'image/webp', 'gif' => 'image/gif', 'mp4' => 'video/mp4', 'mov' => 'video/quicktime', 'webm' => 'video/webm', 'pdf' => 'application/pdf', 'txt' => 'text/plain', _ => 'application/octet-stream' };
      setState(() => busy = true);
      final uploaded = await store.uploadSupportFile(file.name, mime, bytes);
      final data = await store.sendSupportMessage('${widget.ticket['id']}', '', attachments: [uploaded]);
      if (mounted) setState(() => messages = List<Map>.from(data['messages'] ?? messages));
    } catch (e) { if (mounted) AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _openAttachment(Map file) async {
    try {
      final bytes = await store.downloadSupportFile('${file['id']}');
      final dir = await getTemporaryDirectory();
      final safeName = '${file['name'] ?? 'attachment'}'.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = '${dir.path}/$safeName';
      await File(path).writeAsBytes(bytes, flush: true);
      await OpenFilex.open(path);
    } catch (e) { if (mounted) AngelNotice.show(context, 'باز کردن فایل ممکن نشد: $e', error: true); }
  }
  Future<void> _send() async {
    final value = input.text.trim(); if (value.isEmpty || busy || ticketStatus == 'closed') return;
    setState(() => busy = true); input.clear();
    try { final d = await store.sendSupportMessage('${widget.ticket['id']}', value); if (mounted) setState(() => messages = List<Map>.from(d['messages'] ?? messages)); }
    catch (e) { if (mounted) { input.text = value; AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); } }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Container(decoration: const BoxDecoration(gradient: bg), child: Scaffold(backgroundColor: Colors.transparent, appBar: AppBar(backgroundColor: Colors.transparent, title: Text('${widget.ticket['subject'] ?? 'گفت‌وگو'}'), actions: [Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('${widget.ticket['id']}', style: const TextStyle(fontSize: 10))))]), body: Column(children: [Expanded(child: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(14), children: [for (final m in messages) Align(alignment: m['sender'] == 'customer' ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: const BoxConstraints(maxWidth: 320), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: m['sender'] == 'customer' ? Colors.deepPurple.withValues(alpha: .75) : Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (m['sender'] != 'customer') Text(m['sender'] == 'ai' ? 'آنجی · دستیار هوشمند' : m['sender'] == 'admin' ? 'پشتیبانی' : 'سیستم', style: const TextStyle(fontSize: 11, color: Colors.amberAccent)), Text('${m['text'] ?? ''}'), if ((m['attachments'] as List?)?.isNotEmpty ?? false) ...List<Widget>.from((m['attachments'] as List).map((f) => TextButton.icon(onPressed: () => _openAttachment(Map.from(f)), icon: const Icon(Icons.attach_file, size: 16), label: Text('${f['name'] ?? 'پیوست'}', maxLines: 1, overflow: TextOverflow.ellipsis))))])))]))), if (ticketStatus == 'closed') const Padding(padding: EdgeInsets.all(16), child: Text('این تیکت بسته شده است')) else SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [IconButton(onPressed: busy ? null : _pickAttachment, icon: const Icon(Icons.attach_file), tooltip: 'افزودن فایل، تصویر یا ویدئو'), Expanded(child: TextField(controller: input, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'پیام خود را بنویسید', border: OutlineInputBorder()))), const SizedBox(width: 8), IconButton.filled(onPressed: busy ? null : _send, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send))])))])));
}

class HiddenAdminLogo extends StatefulWidget {
  const HiddenAdminLogo({super.key, required this.size});
  final double size;
  @override
  State<HiddenAdminLogo> createState() => _HiddenAdminLogoState();
}
class _HiddenAdminLogoState extends State<HiddenAdminLogo> {
  int taps = 0;
  Timer? reset;
  void hit() {
    reset?.cancel();
    taps++;
    if (taps >= 5) {
      taps = 0;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminLoginPage()));
    } else {
      reset = Timer(const Duration(seconds: 3), () { if (mounted) setState(() => taps = 0); });
    }
  }
  @override
  void dispose() { reset?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => GestureDetector(behavior: HitTestBehavior.opaque, onTap: hit, child: AppLogo(size: widget.size, glow: true));
}

// ===================== ورود / ثبت‌نام =====================
class Root extends StatelessWidget {
  const Root({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (_, _) => store.token == null ? const AuthPage() : const Shell(),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool reg = false, busy = false, hide = true;
  String? err;
  final name = TextEditingController(),
      phone = TextEditingController(),
      pass = TextEditingController();

  Future<void> go() async {
    setState(() {
      busy = true;
      err = null;
    });
    final e = await store.auth(
      reg,
      name: name.text.trim(),
      phone: phone.text.trim(),
      password: pass.text,
    );
    if (mounted) {
      setState(() {
        busy = false;
        err = e;
      });
    }
  }

  Widget field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool pw = false,
    bool ltr = false,
    TextInputType? kb,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      obscureText: pw && hide,
      keyboardType: kb,
      textDirection: ltr ? TextDirection.ltr : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: pw
            ? IconButton(
                icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => hide = !hide),
              )
            : null,
        filled: true,
        fillColor: Colors.white12,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: bg),
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: glass(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HiddenAdminLogo(size: 84),
                  const SizedBox(height: 12),
                  const Text(
                    'Angel shop',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reg ? 'ساخت حساب جدید' : 'ورود به حساب',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  if (reg) field(name, 'نام و نام خانوادگی', Icons.person),
                  field(
                    phone,
                    'شماره موبایل (09...)',
                    Icons.phone_android,
                    ltr: true,
                    kb: TextInputType.phone,
                  ),
                  field(pass, 'رمز عبور', Icons.lock, pw: true, ltr: true),
                  if (err != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        err!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.redAccent.shade100),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: busy ? null : go,
                      child: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(reg ? 'ثبت‌نام' : 'ورود'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      reg = !reg;
                      err = null;
                    }),
                    child: Text(
                      reg
                          ? 'حساب دارید؟ وارد شوید'
                          : 'حساب ندارید؟ ثبت‌نام کنید',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
