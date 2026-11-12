// Angel shop API — Cloudflare Worker + KV (بدون وابستگی خارجی)
// Secrets: BOT_TOKEN, ADMIN_CHAT_ID, WEBHOOK_SECRET   |   KV binding: DB

const json = (d, s = 200) => new Response(JSON.stringify(d), {
  status: s, headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
});
const bale = (env, m, b) => fetch(`https://tapi.bale.ai/bot${env.BOT_TOKEN}/${m}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(b),
}).then(r => r.json());
const digits = s => s.replace(/[۰-۹]/g, d => '۰۱۲۳۴۵۶۷۸۹'.indexOf(d)).replace(/[٠-٩]/g, d => '٠١٢٣٤٥٦٧٨٩'.indexOf(d));
const num = s => digits(s).replace(/[,٬،]/g, '');
const enc = new TextEncoder();
const hex = b => [...new Uint8Array(b)].map(x => x.toString(16).padStart(2, '0')).join('');
const kvJson = async (env, k, d) => JSON.parse((await env.DB.get(k)) || d);

// قیمت/موجودی/توضیحات: کاتالوگ از گیت‌هاب + تغییرات ربات (overrides) روی آن
const getProducts = async env => {
  const [cat, ov] = await Promise.all([kvJson(env, 'products', '[]'), kvJson(env, 'overrides', '{}')]);
  return cat.map(p => { const id = String(p.id); return { description: '', stock: null, ...p, ...ov[id], id }; });
};

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const path = url.pathname;
    const post = req.method === 'POST';
    try {
      if (post && path === `/bale/${env.WEBHOOK_SECRET}`) { await handleBale(await req.json(), env); return json({ ok: true }); }
      if (post && path === `/admin/catalog/${env.WEBHOOK_SECRET}`) {
        const arr = JSON.parse((await req.text()).replace(/,\s*([\]}])/g, '$1'));
        if (!Array.isArray(arr)) return json({ error: 'invalid' }, 400);
        await env.DB.put('products', JSON.stringify(arr));
        return json({ ok: true, count: arr.length });
      }
      if (path === '/products') return json(await getProducts(env));
      if (post && path === '/register') return await register(await req.json(), env);
      if (post && path === '/login') return await login(await req.json(), env);

      const me = await auth(req, env);
      if (!me) return json({ error: 'نشست منقضی شده؛ دوباره وارد شوید' }, 401);
      if (path === '/me') return json({ name: me.name, phone: me.phone });
      if (post && path === '/logout') { await env.DB.delete('s:' + me.token); return json({ ok: true }); }
      if (path === '/orders') return json(await getOrders(env, me.phone));
      if (post && path === '/order') return await createOrder(await req.json(), env, me);
    } catch (e) {
      return json({ error: 'خطای سرور' }, 500);
    }
    return json({ error: 'not found' }, 404);
  },
};

// ---------- احراز هویت ----------
async function hashPw(pw, salt) {
  const key = await crypto.subtle.importKey('raw', enc.encode(pw), 'PBKDF2', false, ['deriveBits']);
  return hex(await crypto.subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt: enc.encode(salt), iterations: 100000 }, key, 256));
}
async function newSession(env, u) {
  const token = hex(crypto.getRandomValues(new Uint8Array(32)));
  await env.DB.put('s:' + token, u.phone, { expirationTtl: 60 * 60 * 24 * 30 });
  return { token, user: { name: u.name, phone: u.phone } };
}
async function auth(req, env) {
  const t = (req.headers.get('Authorization') || '').replace('Bearer ', '');
  if (!/^[a-f0-9]{64}$/.test(t)) return null;
  const phone = await env.DB.get('s:' + t);
  const u = phone && (await env.DB.get('u:' + phone, 'json'));
  return u ? { phone, name: u.name, token: t } : null;
}
async function register(b, env) {
  const name = String(b.name || '').trim().slice(0, 60);
  const phone = digits(String(b.phone || '')).trim();
  const pw = String(b.password || '');
  if (name.length < 2) return json({ error: 'نام را وارد کنید' }, 400);
  if (!/^09\d{9}$/.test(phone)) return json({ error: 'شماره موبایل معتبر نیست (مثال: 09123456789)' }, 400);
  if (pw.length < 6 || pw.length > 100) return json({ error: 'رمز عبور حداقل ۶ کاراکتر باشد' }, 400);
  if (await env.DB.get('u:' + phone)) return json({ error: 'این شماره قبلاً ثبت‌نام کرده است' }, 409);
  const salt = hex(crypto.getRandomValues(new Uint8Array(16)));
  const user = { name, phone, salt, hash: await hashPw(pw, salt), created: Date.now() };
  await env.DB.put('u:' + phone, JSON.stringify(user));
  return json(await newSession(env, user));
}
async function login(b, env) {
  const phone = digits(String(b.phone || '')).trim();
  if (!/^09\d{9}$/.test(phone)) return json({ error: 'شماره موبایل معتبر نیست' }, 400);
  const fk = 'f:' + phone;
  const fails = parseInt((await env.DB.get(fk)) || '0');
  if (fails >= 5) return json({ error: 'تلاش‌های ناموفق زیاد بود؛ ۱۵ دقیقه بعد دوباره امتحان کنید' }, 429);
  const u = await env.DB.get('u:' + phone, 'json');
  if (!u || (await hashPw(String(b.password || ''), u.salt)) !== u.hash) {
    await env.DB.put(fk, String(fails + 1), { expirationTtl: 900 });
    return json({ error: 'شماره یا رمز عبور اشتباه است' }, 401);
  }
  await env.DB.delete(fk);
  return json(await newSession(env, u));
}

// ---------- سفارش‌ها ----------
async function getOrders(env, phone) {
  const { keys } = await env.DB.list({ prefix: `uo:${phone}:`, limit: 100 });
  const orders = await Promise.all(keys.map(k => env.DB.get(k.name, 'json')));
  return orders.filter(Boolean).sort((a, b) => b.ts - a.ts)
    .map(({ phone: _p, name: _n, msgId, ...o }) => o);
}

async function createOrder(body, env, me) {
  const items = body.items;
  if (!Array.isArray(items) || !items.length || items.length > 50) return json({ error: 'درخواست نامعتبر است' }, 400);
  const products = await getProducts(env);
  let total = 0;
  const lines = [];
  for (const it of items) {
    const p = products.find(x => x.id === String(it.id));
    const qty = parseInt(it.qty);
    if (!p || !(qty > 0) || qty > 100) return json({ error: 'محصول نامعتبر است' }, 400);
    if (p.stock !== null && p.stock <= 0) return json({ error: `«${p.name}» موجود نیست` }, 409);
    if (p.stock !== null && qty > p.stock) return json({ error: `موجودی «${p.name}» فقط ${p.stock} عدد است` }, 409);
    total += p.price * qty;
    lines.push({ name: p.name, qty, price: p.price });
  }
  let code;
  do { code = 'AG-' + (100000 + (crypto.getRandomValues(new Uint32Array(1))[0] % 900000)); }
  while (await env.DB.get('o:' + code));

  const date = new Date().toLocaleString('fa-IR', { timeZone: 'Asia/Tehran', dateStyle: 'short', timeStyle: 'short' });
  const text = `🛍 درخواست جدید Angel shop\n🔖 کد سفارش: ${code}\n👤 ${me.name} — ${me.phone}\n🕒 ${date}\n\n` +
    lines.map(l => `• ${l.name} × ${l.qty}`).join('\n') + `\n\n💰 جمع: ${total.toLocaleString('en')} تومان`;
  const sent = await bale(env, 'sendMessage', {
    chat_id: env.ADMIN_CHAT_ID, text,
    reply_markup: { inline_keyboard: [[
      { text: '✅ تأیید', callback_data: `ok:${code}` },
      { text: '❌ رد', callback_data: `no:${code}` },
    ]] },
  });
  if (!sent.ok) return json({ error: 'ارسال به ربات ناموفق بود' }, 502);

  const order = { code, phone: me.phone, name: me.name, date, ts: Date.now(), items: lines, total, status: 'pending', msgId: sent.result?.message_id };
  await env.DB.put(`uo:${me.phone}:${code}`, JSON.stringify(order));
  await env.DB.put('o:' + code, me.phone);
  return json({ ok: true, code });
}

// ---------- ربات بله ----------
const HELP = `دستورات مدیریت:
/list — لیست محصولات
/price 1,2,3 90000 — قیمت (all = همه)
/stock 5 12 — موجودی | /stock 5 off (اتمام) | /stock 5 on (نامحدود)
/name 5 نام جدید
/desc 5 متن توضیحات (چندخطی؛ حذف: -)
/cat 5 نام دسته
/img 5 لینک عکس
/reset 5 — برگشت به مقادیر فایل گیت‌هاب`;

async function handleBale(u, env) {
  const admin = String(env.ADMIN_CHAT_ID);
  const cq = u.callback_query;
  if (cq) {
    if (String(cq.message?.chat?.id) !== admin) return;
    const [act, code] = (cq.data || '').split(':');
    const phone = await env.DB.get('o:' + code);
    if (!phone) return bale(env, 'answerCallbackQuery', { callback_query_id: cq.id, text: 'سفارش پیدا نشد' });
    const key = `uo:${phone}:${code}`;
    const o = await env.DB.get(key, 'json');
    const ok = act === 'ok';
    o.status = ok ? 'approved' : 'rejected';
    await env.DB.put(key, JSON.stringify(o));
    await bale(env, 'answerCallbackQuery', { callback_query_id: cq.id, text: ok ? 'تأیید شد' : 'رد شد' });
    await bale(env, 'editMessageText', {
      chat_id: cq.message.chat.id, message_id: cq.message.message_id,
      text: `${cq.message.text}\n\n${ok ? '✅ تأیید شد' : '❌ رد شد'}`,
    });
    return;
  }
  const m = u.message;
  if (!m?.text || String(m.chat.id) !== admin) return;
  const mt = m.text.trim().match(/^\/(\w+)(?:@\w+)?(?:\s+(\S+))?(?:\s+([\s\S]*))?$/);
  if (!mt) return;
  const [, cmd, a1 = '', a2 = ''] = mt;
  const reply = text => bale(env, 'sendMessage', { chat_id: m.chat.id, text });
  const products = await getProducts(env);
  const ov = await kvJson(env, 'overrides', '{}');
  const save = () => env.DB.put('overrides', JSON.stringify(ov));
  const pick = ids => ids.trim() === 'all' ? products.map(p => p.id)
    : digits(ids).split(',').map(i => i.trim()).filter(i => products.some(p => p.id === i));
  const set = (ids, k, v) => ids.forEach(id => (ov[id] = { ...ov[id], [k]: v }));

  if (cmd === 'list')
    return reply(products.map(p => `${p.id}) ${p.name}\n   💰 ${p.price.toLocaleString('en')} | 📦 ${p.stock === null ? 'نامحدود' : p.stock}`).join('\n').slice(0, 4000) || 'لیست خالی است');

  const ids = pick(a1);
  if (['price', 'stock', 'name', 'desc', 'cat', 'img', 'reset'].includes(cmd) && !ids.length) return reply('❌ شناسه محصول پیدا نشد');

  if (cmd === 'reset') { ids.forEach(id => delete ov[id]); await save(); return reply(`✅ ${ids.length} محصول برگشت`); }
  if (cmd === 'price' || cmd === 'stock') {
    const v = num(a2.trim()).toLowerCase();
    if (cmd === 'price') {
      const n = parseInt(v);
      if (!(n >= 0)) return reply('❌ قیمت نامعتبر است');
      set(ids, 'price', n);
    } else {
      const n = v === 'on' ? null : v === 'off' ? 0 : parseInt(v);
      if (n !== null && !(n >= 0)) return reply('❌ عدد نامعتبر است');
      set(ids, 'stock', n);
    }
    await save();
    return reply(`✅ ${ids.length} محصول به‌روز شد`);
  }
  const F = { name: 'name', desc: 'description', cat: 'category', img: 'image' };
  if (F[cmd]) {
    const v = a2.trim();
    if (!v) return reply('❌ مقدار نامعتبر است');
    set(ids.slice(0, 1), F[cmd], cmd === 'desc' && v === '-' ? '' : v);
    await save();
    return reply('✅ ذخیره شد');
  }
  return reply(HELP);
}
