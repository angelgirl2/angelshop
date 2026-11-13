import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'angel_notice.dart';
import 'store.dart';

const _adminGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF10091D), Color(0xFF29113F), Color(0xFF512078)]);

class AdminApi {
  AdminApi(this.token);
  final String token;
  Future<dynamic> call(String path, {String method = 'GET', Object? body}) async {
    final request = http.Request(method, Uri.parse(Cfg.api + path));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer ' + token;
    if (body != null) request.body = jsonEncode(body);
    final streamed = await request.send().timeout(const Duration(seconds: 35));
    final response = await http.Response.fromStream(streamed);
    dynamic data;
    try { data = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body); }
    catch (_) { throw Exception('پاسخ سرور قابل خواندن نیست'); }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map ? data['error'] : null;
      throw Exception(message?.toString() ?? 'خطای ارتباط با سرور (' + response.statusCode.toString() + ')');
    }
    return data;
  }
}

Widget _adminCard(Widget child) => Container(
  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(color: const Color(0xFF211331).withValues(alpha: .92), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: .13)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .16), blurRadius: 18, offset: const Offset(0, 7))]),
  child: child,
);

InputDecoration _adminInput(String label, {String? hint}) => InputDecoration(
  labelText: label, hintText: hint, filled: true, fillColor: Colors.white.withValues(alpha: .06),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: .12))),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: .12))),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD5A2FF), width: 1.4)),
);

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final password = TextEditingController();
  bool busy = false, hide = true;
  String? error;
  @override
  void dispose() { password.dispose(); super.dispose(); }

  Future<void> login() async {
    if (password.text.isEmpty || busy) return;
    setState(() { busy = true; error = null; });
    try {
      final response = await http.post(Uri.parse(Cfg.api + '/admin/login'), headers: const {'Content-Type': 'application/json'}, body: jsonEncode({'password': password.text})).timeout(const Duration(seconds: 25));
      final data = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(data is Map ? (data['error'] ?? 'ورود مدیر ناموفق بود') : 'ورود مدیر ناموفق بود');
      final token = (data as Map)['token']?.toString() ?? '';
      if (token.length != 64) throw Exception('توکن مدیر از سرور دریافت نشد');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AdminPanelPage(token: token)));
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: _adminGradient),
    child: Scaffold(backgroundColor: Colors.transparent, appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('ورود مدیریت')),
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430),
        child: _adminCard(Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.admin_panel_settings_rounded, size: 66, color: Color(0xFFE1B8FF)),
          const SizedBox(height: 12),
          const Text('ANGEL SHOP', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 5),
          const Text('ورود امن مدیر فروشگاه', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 22),
          TextField(controller: password, obscureText: hide, textDirection: TextDirection.ltr, onSubmitted: (_) => login(), decoration: _adminInput('رمز پنل مدیریت').copyWith(prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hide = !hide)))),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFA8B8)))),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(onPressed: busy ? null : login, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login_rounded), label: Text(busy ? 'در حال بررسی...' : 'ورود به پنل'))),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('بازگشت به فروشگاه')),
        ])),
      )),
    ),
  );
}

class AdminPanelPage extends StatelessWidget {
  const AdminPanelPage({super.key, required this.token});
  final String token;
  @override
  Widget build(BuildContext context) {
    final api = AdminApi(token);
    return DefaultTabController(length: 6, child: Container(decoration: const BoxDecoration(gradient: _adminGradient),
      child: Scaffold(backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFF160D23).withValues(alpha: .92),
          title: const Text('پنل مدیریت Angel Shop', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          actions: [IconButton(tooltip: 'خروج از پنل', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.logout_rounded))],
          bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, indicatorColor: Color(0xFFE1B8FF), labelColor: Colors.white, unselectedLabelColor: Colors.white60, tabs: [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'محصولات'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'سفارش‌ها'),
            Tab(icon: Icon(Icons.category_outlined), text: 'دسته‌ها'),
            Tab(icon: Icon(Icons.discount_outlined), text: 'تخفیف‌ها'),
            Tab(icon: Icon(Icons.support_agent_rounded), text: 'پشتیبانی'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'تنظیمات'),
          ]),
        ),
        body: TabBarView(children: [AdminProductsPage(api: api), AdminOrdersPage(api: api), AdminCategoriesPage(api: api), AdminDiscountsPage(api: api), AdminTicketsPage(api: api), AdminSettingsPage(api: api)]),
      ),
    ));
  }
}

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}
class _AdminProductsPageState extends State<AdminProductsPage> {
  List<Map<String, dynamic>> products = [];
  bool loading = true;
  String query = '';
  Future<void> load() async {
    try { final data = await widget.api.call('/admin/products') as List; if (mounted) setState(() { products = data.map((e) => Map<String, dynamic>.from(e)).toList(); loading = false; }); }
    catch (e) { if (mounted) { setState(() => loading = false); AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); } }
  }
  Future<void> edit([Map<String, dynamic>? product]) async {
    final form = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _ProductEditor(product: product));
    if (form == null) return;
    try {
      final imageData = form.remove('imageData'), mime = form.remove('mime');
      final saved = Map<String, dynamic>.from(await widget.api.call('/admin/products', method: 'POST', body: form));
      if (imageData is String && imageData.isNotEmpty) await widget.api.call('/admin/product-image', method: 'POST', body: {'id': saved['id'], 'mime': mime, 'data': imageData});
      if (mounted) { AngelNotice.show(context, 'اطلاعات محصول ذخیره شد'); await load(); }
    } catch (e) { if (mounted) AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); }
  }
  Future<void> deleteProduct(String id) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('غیرفعال‌سازی محصول'), content: const Text('محصول از فروشگاه خارج می‌شود؛ سوابق و اطلاعات سفارش‌ها حذف نمی‌شوند.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأیید'))]));
    if (yes != true) return;
    try { await widget.api.call('/admin/products/' + id, method: 'DELETE'); await load(); if (mounted) AngelNotice.show(context, 'محصول غیرفعال شد'); }
    catch (e) { if (mounted) AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); }
  }
  @override
  void initState() { super.initState(); load(); }
  @override
  Widget build(BuildContext context) {
    final visible = products.where((p) => (p['name'].toString() + ' ' + p['id'].toString() + ' ' + p['category'].toString()).toLowerCase().contains(query.toLowerCase())).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 4), child: Row(children: [
        Expanded(child: TextField(decoration: _adminInput('جستجوی محصول').copyWith(prefixIcon: const Icon(Icons.search)), onChanged: (v) => setState(() => query = v))),
        const SizedBox(width: 8),
        IconButton.filledTonal(onPressed: load, icon: const Icon(Icons.refresh)),
        const SizedBox(width: 4),
        IconButton.filled(onPressed: () => edit(), icon: const Icon(Icons.add)),
      ])),
      Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: visible.isEmpty ? ListView(children: const [SizedBox(height: 140), Center(child: Text('محصولی پیدا نشد'))]) : ListView.builder(
        padding: const EdgeInsets.only(bottom: 18), itemCount: visible.length,
        itemBuilder: (_, index) {
          final p = visible[index]; final active = p['active'] != false;
          return _adminCard(Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.deepPurple.withValues(alpha: .35), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFE4C2FF))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text((p['category'] ?? 'بدون دسته').toString() + ' · ' + (p['price'] ?? 0).toString() + ' تومان', style: const TextStyle(fontSize: 11, color: Colors.white70)),
              Text(active ? 'فعال' : 'غیرفعال', style: TextStyle(fontSize: 11, color: active ? Colors.greenAccent : Colors.redAccent)),
            ])),
            IconButton(tooltip: 'ویرایش', onPressed: () => edit(p), icon: const Icon(Icons.edit_outlined)),
            IconButton(tooltip: 'غیرفعال‌سازی', onPressed: () => deleteProduct(p['id'].toString()), icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
          ]));
        },
      ))),
    ]);
  }
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({this.product});
  final Map<String, dynamic>? product;
  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}
class _ProductEditorState extends State<_ProductEditor> {
  late final TextEditingController id, name, price, category, stock, description;
  bool active = true, picking = false;
  String? imageData, mime;
  @override
  void initState() {
    super.initState(); final p = widget.product ?? {};
    id = TextEditingController(text: p['id']?.toString() ?? '');
    name = TextEditingController(text: p['name']?.toString() ?? '');
    price = TextEditingController(text: p['price']?.toString() ?? '');
    category = TextEditingController(text: p['category']?.toString() ?? '');
    stock = TextEditingController(text: p['stock']?.toString() ?? '');
    description = TextEditingController(text: p['description']?.toString() ?? '');
    active = p['active'] != false;
  }
  @override
  void dispose() { id.dispose(); name.dispose(); price.dispose(); category.dispose(); stock.dispose(); description.dispose(); super.dispose(); }
  Future<void> pickImage() async {
    setState(() => picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) throw Exception('خواندن تصویر ممکن نشد');
      if (bytes.length > 1500000) throw Exception('حجم تصویر باید کمتر از ۱.۵ مگابایت باشد');
      final ext = file.extension?.toLowerCase() ?? '';
      mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
      imageData = base64Encode(bytes);
      if (mounted) setState(() {});
    } catch (e) { if (mounted) AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); }
    finally { if (mounted) setState(() => picking = false); }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product == null ? 'افزودن محصول' : 'ویرایش محصول'),
    content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (widget.product != null) TextField(controller: id, readOnly: true, decoration: _adminInput('شناسه محصول')),
      TextField(controller: name, decoration: _adminInput('نام محصول')),
      const SizedBox(height: 9), TextField(controller: price, keyboardType: TextInputType.number, decoration: _adminInput('قیمت به تومان')),
      const SizedBox(height: 9), TextField(controller: category, decoration: _adminInput('دسته‌بندی')),
      const SizedBox(height: 9), TextField(controller: stock, keyboardType: TextInputType.number, decoration: _adminInput('موجودی (خالی = نامحدود)')),
      const SizedBox(height: 9), TextField(controller: description, minLines: 2, maxLines: 5, decoration: _adminInput('توضیحات محصول')),
      SwitchListTile(value: active, onChanged: (v) => setState(() => active = v), title: const Text('نمایش در فروشگاه'), contentPadding: EdgeInsets.zero),
      OutlinedButton.icon(onPressed: picking ? null : pickImage, icon: const Icon(Icons.image_outlined), label: Text(picking ? 'در حال خواندن...' : (imageData == null ? 'انتخاب تصویر محصول' : 'تصویر انتخاب شد'))),
      const Text('فرمت PNG، JPG یا WEBP · حداکثر ۱.۵ مگابایت', style: TextStyle(fontSize: 10, color: Colors.white60)),
    ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
      FilledButton(onPressed: () {
        if (name.text.trim().length < 2 || category.text.trim().isEmpty || int.tryParse(price.text.trim()) == null) { AngelNotice.show(context, 'نام، دسته‌بندی و قیمت معتبر را وارد کنید', error: true); return; }
        Navigator.pop(context, <String, dynamic>{if (id.text.isNotEmpty) 'id': id.text, 'name': name.text.trim(), 'price': price.text.trim(), 'category': category.text.trim(), 'stock': stock.text.trim(), 'description': description.text.trim(), 'active': active, 'imageData': imageData, 'mime': mime});
      }, child: const Text('ذخیره محصول')),
    ],
  );
}

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}
class _AdminOrdersPageState extends State<AdminOrdersPage> {
  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  Future<void> load() async {
    try { final result = await widget.api.call('/admin/orders') as List; if (mounted) setState(() { orders = result.map((e) => Map<String, dynamic>.from(e)).toList(); loading = false; }); }
    catch (e) { if (mounted) { setState(() => loading = false); AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); } }
  }
  Future<void> action(String code, String value) async {
    try { await widget.api.call('/admin/orders/' + code + '/' + value, method: 'POST', body: {}); await load(); if (mounted) AngelNotice.show(context, value == 'approve' ? 'سفارش تأیید شد' : 'سفارش رد شد'); }
    catch (e) { if (mounted) AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); }
  }
  @override
  void initState() { super.initState(); load(); }
  @override
  Widget build(BuildContext context) => loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: orders.isEmpty ? ListView(children: const [SizedBox(height: 150), Center(child: Text('هنوز سفارشی ثبت نشده است'))]) : ListView.builder(
    padding: const EdgeInsets.symmetric(vertical: 8), itemCount: orders.length,
    itemBuilder: (_, i) {
      final o = orders[i];
      final pending = o['status'] == 'pending';
      final lines = (o['items'] as List? ?? const []).map((x) => (x['name'] ?? x['id']).toString() + ' × ' + (x['qty'] ?? '').toString()).join('\n');
      return _adminCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('سفارش ' + (o['code'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold))), Text((o['status'] ?? '').toString(), style: TextStyle(color: pending ? Colors.amberAccent : Colors.greenAccent))]),
        const SizedBox(height: 5), Text('مشتری: ' + (o['phone'] ?? '').toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text('مبلغ: ' + (o['total'] ?? 0).toString() + ' تومان', style: const TextStyle(color: Color(0xFFE8C78F))),
        if (lines.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(lines, style: const TextStyle(height: 1.5))),
        if (pending) Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => action(o['code'].toString(), 'reject'), child: const Text('رد سفارش'))),
          const SizedBox(width: 9),
          Expanded(child: FilledButton(onPressed: () => action(o['code'].toString(), 'approve'), child: const Text('تأیید سفارش'))),
        ]),
      ]));
    },
  ));
}

class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}
class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  List<String> categories = [];
  bool loading = true;
  final name = TextEditingController();
  Future<void> load() async {
    try { final data = await widget.api.call('/admin/categories') as List; if (mounted) setState(() { categories = data.map((e) => e.toString()).toList(); loading = false; }); }
    catch (e) { if (mounted) { setState(() => loading = false); AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); } }
  }
  Future<void> save({String? old}) async {
    if (name.text.trim().length < 2) { AngelNotice.show(context, 'نام دسته‌بندی را وارد کنید', error: true); return; }
    try { await widget.api.call('/admin/categories', method: 'POST', body: {'name': name.text.trim(), if (old != null) 'renameFrom': old}); name.clear(); await load(); if (mounted) AngelNotice.show(context, 'دسته‌بندی ذخیره شد'); }
    catch (e) { if (mounted) AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); }
  }
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { name.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(14), child: Row(children: [Expanded(child: TextField(controller: name, decoration: _adminInput('نام دسته‌بندی جدید'))), const SizedBox(width: 8), IconButton.filled(onPressed: () => save(), icon: const Icon(Icons.add))])),
    Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: ListView(children: [
      for (final c in categories) _adminCard(Row(children: [
        const Icon(Icons.category_outlined, color: Color(0xFFDAB4FF)), const SizedBox(width: 10),
        Expanded(child: Text(c, style: const TextStyle(fontWeight: FontWeight.w600))),
        IconButton(onPressed: () async {
          final controller = TextEditingController(text: c);
          final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: const Text('تغییر نام دسته'), content: TextField(controller: controller, decoration: _adminInput('نام جدید')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('ذخیره'))]));
          controller.dispose();
          if (value != null && value.isNotEmpty && value != c) { name.text = value; await save(old: c); }
        }, icon: const Icon(Icons.edit_outlined)),
      ])),
    ]))),
  ]);
}

class AdminDiscountsPage extends StatefulWidget {
  const AdminDiscountsPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<AdminDiscountsPage> createState() => _AdminDiscountsPageState();
}
class _AdminDiscountsPageState extends State<AdminDiscountsPage> {
  List<Map<String, dynamic>> discounts = [];
  bool loading = true;
  Future<void> load() async {
    try { final data = await widget.api.call('/admin/discounts') as List; if (mounted) setState(() { discounts = data.map((e) => Map<String, dynamic>.from(e)).toList(); loading = false; }); }
    catch (e) { if (mounted) { setState(() => loading = false); AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); } }
  }
  Future<void> editor([Map<String, dynamic>? item]) async {
    final code = TextEditingController(text: item?['code']?.toString() ?? '');
    final val = TextEditingController(text: item?['value']?.toString() ?? '');
    final max = TextEditingController(text: item?['maxUses']?.toString() ?? '');
    String type = item?['type'] == 'fixed' ? 'fixed' : 'percent';
    bool active = item?['active'] != false;
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: Text(item == null ? 'کد تخفیف جدید' : 'ویرایش کد تخفیف'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: _adminInput('کد تخفیف')),
        const SizedBox(height: 8), TextField(controller: val, keyboardType: TextInputType.number, decoration: _adminInput('مقدار تخفیف')),
        const SizedBox(height: 8), DropdownButtonFormField<String>(value: type, decoration: _adminInput('نوع تخفیف'), items: const [DropdownMenuItem(value: 'percent', child: Text('درصدی')), DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت'))], onChanged: (v) => setDialog(() => type = v ?? 'percent')),
        const SizedBox(height: 8), TextField(controller: max, keyboardType: TextInputType.number, decoration: _adminInput('حداکثر استفاده (اختیاری)')),
        SwitchListTile(value: active, onChanged: (v) => setDialog(() => active = v), title: const Text('فعال'), contentPadding: EdgeInsets.zero),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(ctx, {'code': code.text.trim(), 'value': val.text.trim(), 'type': type, 'maxUses': max.text.trim(), 'active': active}), child: const Text('ذخیره'))],
    )));
    code.dispose(); val.dispose(); max.dispose();
    if (result == null) return;
    try { await widget.api.call('/admin/discounts', method: 'POST', body: result); await load(); if (mounted) AngelNotice.show(context, 'کد تخفیف ذخیره شد'); }
    catch (e) { if (mounted) AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); }
  }
  Future<void> remove(String code) async {
    try { await widget.api.call('/admin/discounts/' + code, method: 'DELETE'); await load(); if (mounted) AngelNotice.show(context, 'کد تخفیف حذف شد'); }
    catch (e) { if (mounted) AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); }
  }
  @override
  void initState() { super.initState(); load(); }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(14), child: Row(children: [const Expanded(child: Text('مدیریت کدهای تخفیف')), FilledButton.icon(onPressed: () => editor(), icon: const Icon(Icons.add), label: const Text('کد جدید'))])),
    Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: ListView(children: [
      for (final d in discounts) _adminCard(Row(children: [
        const Icon(Icons.discount_outlined, color: Color(0xFFE5C0FF)), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d['code']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text((d['type'] == 'fixed' ? (d['value'] ?? 0).toString() + ' تومان' : (d['value'] ?? 0).toString() + '٪') + ' · استفاده: ' + (d['used'] ?? 0).toString(), style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ])),
        IconButton(onPressed: () => editor(d), icon: const Icon(Icons.edit_outlined)),
        IconButton(onPressed: () => remove(d['code'].toString()), icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
      ])),
    ]))),
  ]);
}

class AdminTicketsPage extends StatefulWidget {
  const AdminTicketsPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<AdminTicketsPage> createState() => _AdminTicketsPageState();
}
class _AdminTicketsPageState extends State<AdminTicketsPage> {
  List<Map<String, dynamic>> tickets = [];
  bool loading = true;
  Future<void> load() async {
    try { final data = await widget.api.call('/admin/tickets') as List; if (mounted) setState(() { tickets = data.map((e) => Map<String, dynamic>.from(e)).toList(); loading = false; }); }
    catch (e) { if (mounted) { setState(() => loading = false); AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); } }
  }
  @override
  void initState() { super.initState(); load(); }
  @override
  Widget build(BuildContext context) => loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: tickets.isEmpty ? ListView(children: const [SizedBox(height: 150), Center(child: Text('تیکتی ثبت نشده است'))]) : ListView(children: [
    for (final t in tickets) _adminCard(ListTile(
      contentPadding: EdgeInsets.zero, leading: const CircleAvatar(backgroundColor: Color(0xFF543373), child: Icon(Icons.forum_outlined, color: Colors.white)),
      title: Text(t['subject']?.toString() ?? 'گفت‌وگو', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text((t['id'] ?? '').toString() + ' · ' + (t['status'] ?? '').toString() + ' · ' + (t['customerId'] ?? '').toString()),
      trailing: const Icon(Icons.chevron_left),
      onTap: () async { await showDialog(context: context, builder: (_) => _AdminTicketDialog(api: widget.api, ticket: t)); await load(); },
    )),
  ]));
}

class _AdminTicketDialog extends StatefulWidget {
  const _AdminTicketDialog({required this.api, required this.ticket});
  final AdminApi api;
  final Map<String, dynamic> ticket;
  @override
  State<_AdminTicketDialog> createState() => _AdminTicketDialogState();
}
class _AdminTicketDialogState extends State<_AdminTicketDialog> {
  List<Map<String, dynamic>> messages = [];
  final input = TextEditingController();
  bool loading = true, sending = false;
  late String mode;
  String get id => widget.ticket['id'].toString();
  Future<void> load() async {
    try { final data = await widget.api.call('/admin/tickets/' + id + '/messages') as List; if (mounted) setState(() { messages = data.map((e) => Map<String, dynamic>.from(e)).toList(); loading = false; }); }
    catch (e) { if (mounted) { setState(() => loading = false); AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); } }
  }
  @override
  void initState() { super.initState(); mode = (widget.ticket['replyMode'] ?? 'auto').toString(); load(); }
  @override
  void dispose() { input.dispose(); super.dispose(); }
  Future<void> reply() async {
    if (input.text.trim().isEmpty || sending) return;
    setState(() => sending = true);
    try { await widget.api.call('/admin/tickets/' + id + '/reply', method: 'POST', body: {'message': input.text.trim()}); input.clear(); await load(); }
    catch (e) { if (mounted) AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); }
    finally { if (mounted) setState(() => sending = false); }
  }
  Future<void> setMode(String value) async {
    try { await widget.api.call('/admin/tickets/' + id + '/mode', method: 'POST', body: {'mode': value}); setState(() => mode = value); await load(); AngelNotice.show(context, 'مسئول پاسخ‌گویی تغییر کرد'); }
    catch (e) { if (mounted) AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); }
  }
  Future<void> closeTicket() async {
    try { await widget.api.call('/admin/tickets/' + id + '/close', method: 'POST', body: {}); if (mounted) Navigator.pop(context); }
    catch (e) { if (mounted) AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.ticket['subject']?.toString() ?? 'گفت‌وگو'),
    content: SizedBox(width: 480, height: 460, child: Column(children: [
      if (widget.ticket['status'] == 'open') DropdownButtonFormField<String>(value: mode, decoration: _adminInput('مسئول پاسخ‌گویی'), items: const [
        DropdownMenuItem(value: 'auto', child: Text('خودکار')), DropdownMenuItem(value: 'admin', child: Text('مدیر')), DropdownMenuItem(value: 'ai', child: Text('آنجی · هوش مصنوعی')),
      ], onChanged: (v) { if (v != null) setMode(v); }),
      const SizedBox(height: 8),
      Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : ListView(children: [
        for (final m in messages) Align(alignment: m['sender'] == 'customer' ? Alignment.centerRight : Alignment.centerLeft, child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(10), constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(color: m['sender'] == 'customer' ? const Color(0xFF553376) : Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(13)),
          child: Text((m['sender'] ?? 'پیام').toString() + '\n' + (m['text'] ?? '').toString(), style: const TextStyle(height: 1.5)),
        )),
      ])),
      if (widget.ticket['status'] == 'open') Row(children: [
        Expanded(child: TextField(controller: input, minLines: 1, maxLines: 3, decoration: _adminInput('پاسخ مدیر'))),
        const SizedBox(width: 7),
        IconButton.filled(onPressed: sending ? null : reply, icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
      ]),
    ])),
    actions: [if (widget.ticket['status'] == 'open') TextButton(onPressed: closeTicket, child: const Text('بستن تیکت')), TextButton(onPressed: () => Navigator.pop(context), child: const Text('بازگشت'))],
  );
}

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}
class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final prompt = TextEditingController(), startDate = TextEditingController(), endDate = TextEditingController(), startTime = TextEditingController(), endTime = TextEditingController(), temp = TextEditingController(), tokens = TextEditingController(), newPassword = TextEditingController();
  bool aiEnabled = true, scheduleEnabled = false, loading = true, saving = false;
  Future<void> load() async {
    try {
      final data = Map<String, dynamic>.from(await widget.api.call('/admin/settings'));
      final ai = Map<String, dynamic>.from(data['ai'] ?? {}), sc = Map<String, dynamic>.from(data['schedule'] ?? {});
      prompt.text = ai['prompt']?.toString() ?? ''; temp.text = (ai['temperature'] ?? .25).toString(); tokens.text = (ai['maxTokens'] ?? 500).toString();
      aiEnabled = ai['enabled'] != false; scheduleEnabled = sc['enabled'] == true;
      startDate.text = sc['startJalali']?.toString() ?? ''; endDate.text = sc['endJalali']?.toString() ?? '';
      startTime.text = sc['startTime']?.toString() ?? ''; endTime.text = sc['endTime']?.toString() ?? '';
      if (mounted) setState(() => loading = false);
    } catch (e) { if (mounted) { setState(() => loading = false); AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); } }
  }
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { prompt.dispose(); startDate.dispose(); endDate.dispose(); startTime.dispose(); endTime.dispose(); temp.dispose(); tokens.dispose(); newPassword.dispose(); super.dispose(); }
  Future<void> saveSettings() async {
    setState(() => saving = true);
    try {
      await widget.api.call('/admin/settings', method: 'POST', body: {'schedule': {'enabled': scheduleEnabled, 'startDate': startDate.text.trim(), 'startTime': startTime.text.trim(), 'endDate': endDate.text.trim(), 'endTime': endTime.text.trim()}, 'ai': {'enabled': aiEnabled, 'prompt': prompt.text, 'temperature': temp.text, 'maxTokens': tokens.text}});
      if (mounted) AngelNotice.show(context, 'تنظیمات ذخیره شد');
    } catch (e) { if (mounted) AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); }
    finally { if (mounted) setState(() => saving = false); }
  }
  Future<void> changePassword() async {
    try { await widget.api.call('/admin/password', method: 'POST', body: {'password': newPassword.text}); newPassword.clear(); if (mounted) AngelNotice.show(context, 'رمز پنل تغییر کرد'); }
    catch (e) { if (mounted) AngelNotice.show(context, e.toString().replaceFirst('Exception: ', ''), error: true); }
  }
  @override
  Widget build(BuildContext context) => loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
    _adminCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('پشتیبانی هوشمند آنجی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('فعال‌بودن هوش مصنوعی'), value: aiEnabled, onChanged: (v) => setState(() => aiEnabled = v)),
      TextField(controller: prompt, minLines: 3, maxLines: 7, decoration: _adminInput('دستورالعمل دستیار')),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: TextField(controller: temp, keyboardType: TextInputType.number, decoration: _adminInput('Temperature'))), const SizedBox(width: 8), Expanded(child: TextField(controller: tokens, keyboardType: TextInputType.number, decoration: _adminInput('حداکثر توکن')))]),
    ])),
    _adminCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ساعات پاسخ‌گویی انسانی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('فعال‌کردن بازه زمانی'), value: scheduleEnabled, onChanged: (v) => setState(() => scheduleEnabled = v)),
      Row(children: [Expanded(child: TextField(controller: startDate, decoration: _adminInput('تاریخ شروع شمسی'))), const SizedBox(width: 8), Expanded(child: TextField(controller: startTime, decoration: _adminInput('ساعت شروع')))]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: TextField(controller: endDate, decoration: _adminInput('تاریخ پایان شمسی'))), const SizedBox(width: 8), Expanded(child: TextField(controller: endTime, decoration: _adminInput('ساعت پایان')))]),
      const Text('قالب تاریخ: ۱۴۰۵/۰۸/۲۲ · قالب ساعت: 09:00', style: TextStyle(fontSize: 10, color: Colors.white60)),
    ])),
    _adminCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('امنیت پنل مدیریت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 10), TextField(controller: newPassword, obscureText: true, decoration: _adminInput('رمز جدید (حداقل ۱۲ کاراکتر)')),
      const SizedBox(height: 8), Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: changePassword, icon: const Icon(Icons.lock_reset), label: const Text('تغییر رمز پنل'))),
    ])),
    Padding(padding: const EdgeInsets.fromLTRB(14, 3, 14, 20), child: SizedBox(height: 48, child: FilledButton.icon(onPressed: saving ? null : saveSettings, icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('ذخیره همه تنظیمات')))),
  ]);
}
