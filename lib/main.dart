import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'store.dart';

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
      colorSchemeSeed: const Color(0xFF9C27B0),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
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
      Future.delayed(const Duration(milliseconds: 2800)),
      store.ready,
    ]).then((_) {
      if (mounted)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Root()),
        );
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
            const AppLogo(size: 130, glow: true),
            const SizedBox(height: 24),
            const Text(
              'Angel shop',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'angelgirlbrand',
              style: TextStyle(
                fontSize: 16,
                letterSpacing: 3,
                color: Colors.white70,
              ),
            ),
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
                      if (n == 2 && store.cartCount > 0)
                        icon = Badge(
                          label: Text('${store.cartCount}'),
                          child: icon,
                        );
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
                      child: Image.network(
                        p.image,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
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
                      onPressed: p.inStock ? () => store.add(p) : null,
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
          if (i < 0)
            return const Center(child: Text('این محصول دیگر موجود نیست'));
          final p = store.products[i];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: grayed(
                  !p.inStock,
                  Image.network(
                    p.image,
                    height: 280,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 280,
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
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
                  child: Text(
                    p.description.isEmpty
                        ? 'توضیحاتی برای این محصول ثبت نشده است.'
                        : p.description,
                    style: const TextStyle(height: 1.9),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: p.inStock
                    ? () {
                        store.add(p);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('به سبد اضافه شد')),
                        );
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
    if (cs.isEmpty)
      return const Center(child: Text('در حال دریافت دسته‌بندی‌ها...'));
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

class CartPage extends StatelessWidget {
  const CartPage({super.key});
  @override
  Widget build(BuildContext context) {
    if (store.cart.isEmpty)
      return const Center(child: Text('سبد خرید خالی است'));
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            children: store.cart.entries.map((e) {
              final p = store.products.firstWhere((x) => x.id == e.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: glass(
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          p.image,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(Icons.image),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              money(p.price),
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => store.remove(p),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('${e.value}'),
                      IconButton(
                        onPressed: () => store.add(p),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
          child: glass(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('جمع کل'),
                    Text(
                      money(store.cartTotal),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final ok = await store.submit();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'درخواست ارسال شد؛ وضعیت را در «سفارشات» ببینید'
                                  : store.lastError ??
                                        'ارسال ناموفق بود، دوباره تلاش کنید',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('درخواست'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});
  @override
  Widget build(BuildContext context) {
    if (store.orders.isEmpty)
      return const Center(child: Text('هنوز سفارشی ثبت نکرده‌اید'));
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

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});
  Future<void> _open(String u) =>
      launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
  @override
  Widget build(BuildContext context) {
    final items = [
      ['روبیکا', Icons.chat_bubble, Cfg.rubika],
      ['تلگرام', Icons.send, Cfg.telegram],
      ['واتساپ', Icons.call_made, Cfg.whatsapp],
      ['بله', Icons.message, Cfg.bale],
      ['تماس', Icons.phone, Cfg.phone],
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: [
        glass(
          child: Row(
            children: [
              const Icon(Icons.account_circle, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.userName ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      store.userPhone ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: store.logout,
                icon: const Icon(Icons.logout),
                tooltip: 'خروج از حساب',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'پشتیبانی',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...items.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _open(e[2] as String),
              child: glass(
                child: Row(
                  children: [
                    Icon(e[1] as IconData, color: Colors.purpleAccent.shade100),
                    const SizedBox(width: 12),
                    Text(e[0] as String),
                    const Spacer(),
                    const Icon(Icons.chevron_left),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => _open(Cfg.baleChannel),
          child: glass(
            child: const Row(
              children: [
                Icon(Icons.campaign, color: Colors.amberAccent),
                SizedBox(width: 12),
                Text('ورود به کانال بله'),
                Spacer(),
                Icon(Icons.chevron_left),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
    if (mounted)
      setState(() {
        busy = false;
        err = e;
      });
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
                  const AppLogo(size: 84),
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
