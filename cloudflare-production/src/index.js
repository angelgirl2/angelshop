// Angel Shop production API — Cloudflare Workers + D1.
// No KV namespace is used. Existing legacy Worker/KV resources are not modified.
// Secrets: WEBHOOK_SECRET (required), BOT_TOKEN (optional), ADMIN_CHAT_ID (optional), RATE_LIMIT_PEPPER (recommended).

const DAY_MS = 86_400_000;
const SESSION_DAYS = 30;
const MAX_BODY_BYTES = 1_048_576;
const PASSWORD_ITERATIONS = 120_000;
const encoder = new TextEncoder();

const HELP = `مدیریت Angel Shop:
/help — راهنما
/list — فهرست محصولات
/price 1,2,3 90000 — تغییر قیمت (all = همه)
/stock 5 12 — موجودی عددی | /stock 5 off — ناموجود | /stock 5 on — نامحدود
/name 5 نام جدید
/desc 5 متن توضیحات (حذف: -)
/cat 5 دسته جدید
/img 5 https://... — تصویر
/reset 5 — بازگردانی اطلاعات پایه همان محصول`;

function normalizeDigits(value) {
  return String(value ?? '')
    .replace(/[۰-۹]/g, d => String('۰۱۲۳۴۵۶۷۸۹'.indexOf(d)))
    .replace(/[٠-٩]/g, d => String('٠١٢٣٤٥٦٧٨٩'.indexOf(d)));
}

function hex(bytes) {
  return [...new Uint8Array(bytes)].map(v => v.toString(16).padStart(2, '0')).join('');
}

function randomHex(size = 32) {
  return hex(crypto.getRandomValues(new Uint8Array(size)));
}

async function sha256(value) {
  return hex(await crypto.subtle.digest('SHA-256', encoder.encode(String(value))));
}

async function hashPassword(password, salt) {
  const key = await crypto.subtle.importKey('raw', encoder.encode(password), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits({
    name: 'PBKDF2', hash: 'SHA-256', salt: encoder.encode(salt), iterations: PASSWORD_ITERATIONS,
  }, key, 256);
  return hex(bits);
}

function safeEqual(a, b) {
  const left = encoder.encode(String(a));
  const right = encoder.encode(String(b));
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let i = 0; i < left.length; i++) mismatch |= left[i] ^ right[i];
  return mismatch === 0;
}

function corsHeaders(request, env) {
  const origin = request.headers.get('Origin');
  const allowed = String(env.CORS_ORIGIN || '').split(',').map(v => v.trim()).filter(Boolean);
  const headers = new Headers({
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'no-referrer',
    'X-Frame-Options': 'DENY',
    'X-Robots-Tag': 'noindex, nofollow',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Max-Age': '86400',
  });
  if (origin && allowed.includes(origin)) {
    headers.set('Access-Control-Allow-Origin', origin);
    headers.set('Vary', 'Origin');
  }
  return headers;
}

function reply(request, env, body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders(request, env) });
}

async function readJson(request) {
  const declared = Number(request.headers.get('Content-Length') || 0);
  if (declared > MAX_BODY_BYTES) throw new Error('BODY_TOO_LARGE');
  const raw = await request.text();
  if (encoder.encode(raw).length > MAX_BODY_BYTES) throw new Error('BODY_TOO_LARGE');
  try {
    return JSON.parse(raw || '{}');
  } catch {
    throw new Error('INVALID_JSON');
  }
}

function digitsOnlyPhone(value) {
  return normalizeDigits(value).trim().replace(/[\s-]/g, '');
}

function validPhone(phone) {
  return /^09\d{9}$/.test(phone);
}

function dateLabel() {
  return new Intl.DateTimeFormat('fa-IR', {
    timeZone: 'Asia/Tehran', dateStyle: 'short', timeStyle: 'short',
  }).format(new Date());
}

function parseProduct(row) {
  const base = JSON.parse(row.base_json || '{}');
  const overrides = JSON.parse(row.override_json || '{}');
  const item = { description: '', ...base, ...overrides, id: String(row.id) };
  item.name = String(item.name || '');
  item.price = Number.isSafeInteger(Number(item.price)) ? Number(item.price) : 0;
  item.image = String(item.image || '');
  item.category = String(item.category || '');
  item.description = String(item.description || '');
  item.stock = Number(row.unlimited_stock) === 1 ? null : Number(row.stock_remaining ?? 0);
  return item;
}

async function getProducts(env) {
  const result = await env.DB.prepare(
    'SELECT id, base_json, override_json, stock_remaining, unlimited_stock FROM products ORDER BY CAST(id AS INTEGER), id'
  ).all();
  return (result.results || []).map(parseProduct);
}

function publicUser(user) {
  return { name: user.name, phone: user.phone };
}

async function issueSession(env, user) {
  const token = randomHex(32);
  const tokenHash = await sha256(token);
  const now = Date.now();
  await env.DB.prepare(
    'INSERT INTO sessions (token_hash, phone, created_at, expires_at) VALUES (?, ?, ?, ?)'
  ).bind(tokenHash, user.phone, now, now + SESSION_DAYS * DAY_MS).run();
  return { token, user: publicUser(user), expires_at: now + SESSION_DAYS * DAY_MS };
}

async function authenticate(request, env) {
  const authorization = request.headers.get('Authorization') || '';
  const match = authorization.match(/^Bearer\s+([a-f0-9]{64})$/i);
  if (!match) return null;
  const tokenHash = await sha256(match[1].toLowerCase());
  const row = await env.DB.prepare(`
    SELECT s.phone, u.name, s.token_hash
    FROM sessions s JOIN users u ON u.phone = s.phone
    WHERE s.token_hash = ? AND s.expires_at > ?
    LIMIT 1
  `).bind(tokenHash, Date.now()).first();
  return row ? { phone: row.phone, name: row.name, tokenHash: row.token_hash } : null;
}

async function rateLimit(env, key, maxAttempts, windowMs) {
  const now = Date.now();
  const current = await env.DB.prepare(
    'SELECT blocked_until FROM rate_limits WHERE rate_key = ?'
  ).bind(key).first();
  if (current?.blocked_until && Number(current.blocked_until) > now) return false;

  // Atomic UPSERT avoids lost increments when multiple login attempts arrive together.
  await env.DB.prepare(`
    INSERT INTO rate_limits (rate_key, attempts, window_started_at, blocked_until)
    VALUES (?, 1, ?, NULL)
    ON CONFLICT(rate_key) DO UPDATE SET
      attempts = CASE WHEN ? - window_started_at >= ? THEN 1 ELSE attempts + 1 END,
      window_started_at = CASE WHEN ? - window_started_at >= ? THEN ? ELSE window_started_at END,
      blocked_until = CASE
        WHEN (CASE WHEN ? - window_started_at >= ? THEN 1 ELSE attempts + 1 END) >= ?
        THEN ? + ? ELSE NULL END
  `).bind(
    key, now,
    now, windowMs,
    now, windowMs, now,
    now, windowMs, maxAttempts,
    now, windowMs,
  ).run();

  const updated = await env.DB.prepare(
    'SELECT blocked_until FROM rate_limits WHERE rate_key = ?'
  ).bind(key).first();
  return !updated?.blocked_until || Number(updated.blocked_until) <= now;
}

async function requestKeys(request, env, phone = '') {
  const ip = request.headers.get('CF-Connecting-IP') || 'unknown-client';
  const pepper = String(env.RATE_LIMIT_PEPPER || env.WEBHOOK_SECRET || 'angelshop-rate-limit');
  const ipHash = (await sha256(`${pepper}:${ip}`)).slice(0, 32);
  const keys = [`ip:${ipHash}`];
  if (phone) keys.push(`phone-ip:${(await sha256(`${pepper}:${phone}:${ip}`)).slice(0, 32)}`);
  return keys;
}

async function register(body, env, request) {
  const name = String(body.name || '').trim().slice(0, 60);
  const phone = digitsOnlyPhone(body.phone);
  const password = String(body.password || '');
  if (name.length < 2) return reply(request, env, { error: 'نام را وارد کنید' }, 400);
  if (!validPhone(phone)) return reply(request, env, { error: 'شماره موبایل معتبر نیست؛ نمونه: 09123456789' }, 400);
  if (password.length < 8 || password.length > 100) return reply(request, env, { error: 'رمز عبور باید بین ۸ تا ۱۰۰ کاراکتر باشد' }, 400);

  const [ipKey] = await requestKeys(request, env);
  if (!(await rateLimit(env, `register:${ipKey}`, 8, 60 * 60 * 1000))) {
    return reply(request, env, { error: 'تعداد ثبت‌نام از این اینترنت بیش از حد مجاز است؛ بعداً دوباره تلاش کنید' }, 429);
  }

  const salt = randomHex(16);
  const passwordHash = await hashPassword(password, salt);
  const token = randomHex(32);
  const tokenHash = await sha256(token);
  const now = Date.now();
  try {
    await env.DB.batch([
      env.DB.prepare('INSERT INTO users (phone, name, password_salt, password_hash, created_at) VALUES (?, ?, ?, ?, ?)')
        .bind(phone, name, salt, passwordHash, now),
      env.DB.prepare('INSERT INTO sessions (token_hash, phone, created_at, expires_at) VALUES (?, ?, ?, ?)')
        .bind(tokenHash, phone, now, now + SESSION_DAYS * DAY_MS),
    ]);
  } catch (error) {
    const existing = await env.DB.prepare('SELECT phone FROM users WHERE phone = ?').bind(phone).first();
    if (existing) return reply(request, env, { error: 'این شماره قبلاً ثبت‌نام کرده است' }, 409);
    throw error;
  }
  return reply(request, env, {
    token, user: { name, phone }, expires_at: now + SESSION_DAYS * DAY_MS,
  });
}

async function login(body, env, request) {
  const phone = digitsOnlyPhone(body.phone);
  const password = String(body.password || '');
  if (!validPhone(phone)) return reply(request, env, { error: 'شماره موبایل معتبر نیست' }, 400);
  if (password.length < 1 || password.length > 100) return reply(request, env, { error: 'رمز عبور نامعتبر است' }, 400);

  const [ipKey, phoneIpKey] = await requestKeys(request, env, phone);
  const ipAllowed = await rateLimit(env, `login:${ipKey}`, 60, 15 * 60 * 1000);
  const phoneAllowed = await rateLimit(env, `login:${phoneIpKey}`, 8, 15 * 60 * 1000);
  if (!ipAllowed || !phoneAllowed) {
    return reply(request, env, { error: 'تلاش‌های ورود بیش از حد مجاز است؛ ۱۵ دقیقه بعد دوباره امتحان کنید' }, 429);
  }

  const user = await env.DB.prepare('SELECT phone, name, password_salt, password_hash FROM users WHERE phone = ?')
    .bind(phone).first();
  const calculated = await hashPassword(password, user?.password_salt || 'angelshop-invalid-user-salt');
  if (!user || !safeEqual(calculated, user.password_hash)) {
    return reply(request, env, { error: 'شماره یا رمز عبور اشتباه است' }, 401);
  }

  await env.DB.prepare('DELETE FROM rate_limits WHERE rate_key = ?').bind(`login:${phoneIpKey}`).run();
  const session = await issueSession(env, user);
  return reply(request, env, session);
}

async function listOrders(env, phone) {
  const result = await env.DB.prepare(`
    SELECT code, date_label AS date, total, status, created_at
    FROM orders WHERE phone = ? ORDER BY created_at DESC LIMIT 100
  `).bind(phone).all();
  const orders = [];
  for (const row of result.results || []) {
    const rows = await env.DB.prepare(`
      SELECT product_name AS name, quantity AS qty, unit_price AS price
      FROM order_items WHERE order_code = ? ORDER BY id
    `).bind(row.code).all();
    orders.push({
      code: row.code,
      date: row.date,
      total: Number(row.total),
      status: row.status,
      items: (rows.results || []).map(item => ({ name: item.name, qty: Number(item.qty), price: Number(item.price) })),
    });
  }
  return orders;
}

async function getCart(env, phone) {
  const result = await env.DB.prepare(
    'SELECT product_id AS id, quantity AS qty FROM cart_items WHERE phone = ? ORDER BY updated_at, product_id'
  ).bind(phone).all();
  return (result.results || []).map(row => ({ id: String(row.id), qty: Number(row.qty) }));
}

async function saveCart(body, env, me, request) {
  const items = body.items;
  if (!Array.isArray(items) || items.length > 50) {
    return reply(request, env, { error: 'سبد خرید نامعتبر است' }, 400);
  }
  const products = await getProducts(env);
  const seen = new Set();
  const statements = [env.DB.prepare('DELETE FROM cart_items WHERE phone = ?').bind(me.phone)];
  for (const item of items) {
    const id = String(item?.id ?? '');
    const qty = Number(item?.qty);
    if (seen.has(id) || !Number.isInteger(qty) || qty < 1 || qty > 100) {
      return reply(request, env, { error: 'شناسه محصول یا تعداد در سبد خرید نامعتبر است' }, 400);
    }
    seen.add(id);
    const product = products.find(p => p.id === id);
    if (!product) return reply(request, env, { error: 'یکی از محصولات دیگر موجود نیست' }, 409);
    if (product.stock !== null && qty > product.stock) {
      return reply(request, env, { error: `موجودی «${product.name}» برای این تعداد کافی نیست` }, 409);
    }
    statements.push(env.DB.prepare(
      'INSERT INTO cart_items (phone, product_id, quantity, updated_at) VALUES (?, ?, ?, ?)'
    ).bind(me.phone, id, qty, Date.now()));
  }
  await env.DB.batch(statements);
  return reply(request, env, { ok: true, items: items.length });
}

async function baleCall(env, method, payload) {
  if (!env.BOT_TOKEN) return { ok: false, notConfigured: true };
  try {
    const response = await fetch(`https://tapi.bale.ai/bot${env.BOT_TOKEN}/${method}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(10_000),
    });
    const result = await response.json();
    return response.ok ? result : { ok: false, description: result?.description || 'Bale API error' };
  } catch {
    return { ok: false, description: 'Bale request failed' };
  }
}

async function createOrder(body, env, me, request) {
  const sourceItems = body.items;
  if (!Array.isArray(sourceItems) || sourceItems.length < 1 || sourceItems.length > 50) {
    return reply(request, env, { error: 'سبد خرید خالی یا نامعتبر است' }, 400);
  }
  const products = await getProducts(env);
  const lines = [];
  const seen = new Set();
  let total = 0;

  for (const source of sourceItems) {
    const id = String(source?.id ?? '');
    const quantity = Number(source?.qty);
    if (seen.has(id)) return reply(request, env, { error: 'محصول تکراری در سبد خرید' }, 400);
    seen.add(id);
    const product = products.find(item => item.id === id);
    if (!product || !Number.isInteger(quantity) || quantity < 1 || quantity > 100) {
      return reply(request, env, { error: 'محصول یا تعداد نامعتبر است' }, 400);
    }
    if (product.stock !== null && quantity > product.stock) {
      return reply(request, env, { error: `موجودی «${product.name}» فقط ${product.stock} عدد است` }, 409);
    }
    if (!Number.isSafeInteger(product.price) || product.price < 0) {
      return reply(request, env, { error: `قیمت «${product.name}» نامعتبر است` }, 409);
    }
    total += product.price * quantity;
    if (!Number.isSafeInteger(total)) return reply(request, env, { error: 'مبلغ سفارش بیش از حد مجاز است' }, 400);
    lines.push({ id, name: product.name, quantity, price: product.price });
  }

  const code = `AG-${randomHex(6).toUpperCase()}`;
  const now = Date.now();
  const date = dateLabel();
  const statements = [
    env.DB.prepare(`INSERT INTO orders (code, phone, buyer_name, created_at, date_label, total, status, notification_status)
      VALUES (?, ?, ?, ?, ?, ?, 'pending', 'pending')`)
      .bind(code, me.phone, me.name, now, date, total),
    ...lines.map(line => env.DB.prepare(`INSERT INTO order_items (order_code, product_id, product_name, quantity, unit_price)
      VALUES (?, ?, ?, ?, ?)`)
      .bind(code, line.id, line.name, line.quantity, line.price)),
    env.DB.prepare(`INSERT INTO order_status_events (order_code, old_status, new_status, source, created_at)
      VALUES (?, NULL, 'pending', 'customer', ?)`)
      .bind(code, now),
    env.DB.prepare('DELETE FROM cart_items WHERE phone = ?').bind(me.phone),
  ];

  try {
    // D1 batch is transactional; SQL triggers reserve finite stock and roll back the whole order on a race.
    await env.DB.batch(statements);
  } catch (error) {
    const message = String(error?.message || '');
    if (message.includes('INSUFFICIENT_STOCK')) {
      return reply(request, env, { error: 'موجودی یکی از محصولات هم‌زمان تغییر کرد؛ سبد خرید را تازه‌سازی کنید' }, 409);
    }
    if (message.includes('PRODUCT_NOT_FOUND')) {
      return reply(request, env, { error: 'یکی از محصولات دیگر موجود نیست' }, 409);
    }
    throw error;
  }

  const text = `🛍 سفارش جدید Angel Shop\n🔖 کد سفارش: ${code}\n👤 ${me.name} — ${me.phone}\n🕒 ${date}\n\n` +
    lines.map(line => `• ${line.name} × ${line.quantity}`).join('\n') +
    `\n\n💰 جمع: ${total.toLocaleString('en')} تومان`;

  let notificationStatus = 'not_configured';
  if (env.BOT_TOKEN && env.ADMIN_CHAT_ID) {
    const sent = await baleCall(env, 'sendMessage', {
      chat_id: env.ADMIN_CHAT_ID,
      text,
      reply_markup: { inline_keyboard: [[
        { text: '✅ تأیید', callback_data: `ok:${code}` },
        { text: '❌ رد', callback_data: `no:${code}` },
      ]] },
    });
    notificationStatus = sent?.ok ? 'sent' : 'failed';
    await env.DB.prepare('UPDATE orders SET notification_status = ?, bale_message_id = ? WHERE code = ?')
      .bind(notificationStatus, sent?.result?.message_id ?? null, code).run();
  } else {
    await env.DB.prepare("UPDATE orders SET notification_status = 'not_configured' WHERE code = ?").bind(code).run();
  }

  return reply(request, env, { ok: true, code, total, notification_status: notificationStatus });
}

async function answerCallback(env, callbackId, text) {
  await baleCall(env, 'answerCallbackQuery', { callback_query_id: callbackId, text });
}

async function setProductOverride(env, id, key, value) {
  const row = await env.DB.prepare('SELECT override_json FROM products WHERE id = ?').bind(id).first();
  if (!row) return false;
  const overrides = JSON.parse(row.override_json || '{}');
  overrides[key] = value;
  const statements = [env.DB.prepare('UPDATE products SET override_json = ?, updated_at = ? WHERE id = ?')
    .bind(JSON.stringify(overrides), Date.now(), id)];
  if (key === 'stock') {
    statements.push(value === null
      ? env.DB.prepare('UPDATE products SET unlimited_stock = 1, stock_remaining = NULL, updated_at = ? WHERE id = ?').bind(Date.now(), id)
      : env.DB.prepare('UPDATE products SET unlimited_stock = 0, stock_remaining = ?, updated_at = ? WHERE id = ?').bind(value, Date.now(), id));
  }
  await env.DB.batch(statements);
  return true;
}

async function resetProduct(env, id) {
  const row = await env.DB.prepare('SELECT base_json FROM products WHERE id = ?').bind(id).first();
  if (!row) return false;
  const base = JSON.parse(row.base_json || '{}');
  const stock = base.stock === undefined || base.stock === null ? null : Number(base.stock);
  if (stock !== null && (!Number.isSafeInteger(stock) || stock < 0)) return false;
  await env.DB.batch([
    env.DB.prepare("UPDATE products SET override_json = '{}', updated_at = ? WHERE id = ?").bind(Date.now(), id),
    stock === null
      ? env.DB.prepare('UPDATE products SET unlimited_stock = 1, stock_remaining = NULL, updated_at = ? WHERE id = ?').bind(Date.now(), id)
      : env.DB.prepare('UPDATE products SET unlimited_stock = 0, stock_remaining = ?, updated_at = ? WHERE id = ?').bind(stock, Date.now(), id),
  ]);
  return true;
}

async function handleBale(update, env) {
  const admin = String(env.ADMIN_CHAT_ID || '');
  const callback = update.callback_query;
  if (callback) {
    if (!admin || String(callback.message?.chat?.id) !== admin) return;
    const [action, code] = String(callback.data || '').split(':');
    if (!['ok', 'no'].includes(action) || !/^AG-[A-F0-9]{12}$/.test(code || '')) {
      return answerCallback(env, callback.id, 'درخواست نامعتبر است');
    }
    const nextStatus = action === 'ok' ? 'approved' : 'rejected';
    const now = Date.now();
    const result = await env.DB.batch([
      env.DB.prepare("UPDATE orders SET status = ? WHERE code = ? AND status = 'pending'").bind(nextStatus, code),
      env.DB.prepare(`INSERT INTO order_status_events (order_code, old_status, new_status, source, created_at)
        SELECT ?, 'pending', ?, 'bale_admin', ?
        WHERE changes() = 1`)
        .bind(code, nextStatus, now),
    ]);
    if (!result?.[0]?.meta?.changes) return answerCallback(env, callback.id, 'سفارش پیدا نشد یا قبلاً تعیین وضعیت شده است');
    await answerCallback(env, callback.id, nextStatus === 'approved' ? 'سفارش تأیید شد' : 'سفارش رد شد؛ موجودی بازگشت داده شد');
    if (callback.message?.chat?.id && callback.message?.message_id) {
      const suffix = nextStatus === 'approved' ? '✅ تأیید شد' : '❌ رد شد و موجودی آزاد شد';
      await baleCall(env, 'editMessageText', {
        chat_id: callback.message.chat.id,
        message_id: callback.message.message_id,
        text: `${callback.message.text || `سفارش ${code}`}\n\n${suffix}`,
      });
    }
    return;
  }

  const message = update.message;
  if (!message?.text || !admin || String(message.chat?.id) !== admin) return;
  const match = message.text.trim().match(/^\/(\w+)(?:@\w+)?(?:\s+(\S+))?(?:\s+([\s\S]*))?$/);
  if (!match) return;
  const [, command, arg1 = '', arg2 = ''] = match;
  const send = text => baleCall(env, 'sendMessage', { chat_id: message.chat.id, text });
  if (command === 'help') return send(HELP);
  const products = await getProducts(env);
  if (command === 'list') {
    const lines = products.map(p => `${p.id}) ${p.name}\n   💰 ${p.price.toLocaleString('en')} تومان | 📦 ${p.stock === null ? 'نامحدود' : p.stock}`);
    return send(lines.join('\n').slice(0, 3900) || 'محصولی ثبت نشده است');
  }

  const ids = arg1.trim().toLowerCase() === 'all'
    ? products.map(p => p.id)
    : normalizeDigits(arg1).split(',').map(value => value.trim()).filter(id => products.some(p => p.id === id));
  if (['price', 'stock', 'name', 'desc', 'cat', 'img', 'reset'].includes(command) && !ids.length) {
    return send('❌ شناسه محصول معتبر نیست');
  }
  if (command === 'reset') {
    let done = 0;
    for (const id of ids) if (await resetProduct(env, id)) done++;
    return send(`✅ اطلاعات پایه ${done} محصول بازگردانی شد`);
  }

  const value = arg2.trim();
  if (command === 'price') {
    const price = Number(normalizeDigits(value).replace(/[,٬،\s]/g, ''));
    if (!Number.isSafeInteger(price) || price < 0) return send('❌ قیمت باید عدد صحیح و غیرمنفی باشد');
    for (const id of ids) await setProductOverride(env, id, 'price', price);
    return send(`✅ قیمت ${ids.length} محصول ذخیره شد`);
  }
  if (command === 'stock') {
    const normalized = normalizeDigits(value).toLowerCase();
    const stock = normalized === 'on' ? null : normalized === 'off' ? 0 : Number(normalized);
    if (stock !== null && (!Number.isSafeInteger(stock) || stock < 0)) return send('❌ موجودی نامعتبر است');
    for (const id of ids) await setProductOverride(env, id, 'stock', stock);
    return send(`✅ موجودی ${ids.length} محصول به‌روز شد`);
  }
  const fields = { name: 'name', desc: 'description', cat: 'category', img: 'image' };
  const field = fields[command];
  if (field) {
    if (!value && command !== 'desc') return send('❌ مقدار وارد نشده است');
    const finalValue = command === 'desc' && value === '-' ? '' : value;
    if (command === 'img') {
      try {
        const image = new URL(finalValue);
        if (!['https:', 'http:'].includes(image.protocol)) return send('❌ لینک تصویر معتبر نیست');
      } catch { return send('❌ لینک تصویر معتبر نیست'); }
    }
    if (command === 'name' && finalValue.length > 200) return send('❌ نام محصول بیش از حد طولانی است');
    if (command === 'desc' && finalValue.length > 5000) return send('❌ توضیحات بیش از حد طولانی است');
    if (command === 'cat' && finalValue.length > 120) return send('❌ نام دسته بیش از حد طولانی است');
    await setProductOverride(env, ids[0], field, finalValue);
    return send('✅ تغییرات ذخیره شد');
  }
  return send(HELP);
}

async function importCatalog(request, env) {
  const list = await readJson(request);
  if (!Array.isArray(list) || list.length < 1 || list.length > 5000) {
    return { error: 'فهرست محصولات نامعتبر است؛ آرایه‌ای با ۱ تا ۵۰۰۰ محصول بفرستید' };
  }
  const seen = new Set();
  const now = Date.now();
  const statements = [];
  for (const item of list) {
    const id = String(item?.id ?? '').trim();
    const name = String(item?.name || '').trim().slice(0, 200);
    const price = Number(item?.price);
    if (!id || id.length > 80 || seen.has(id) || !name || !Number.isSafeInteger(price) || price < 0) {
      return { error: `اطلاعات محصول ${id || '(بدون شناسه)'} نامعتبر یا تکراری است` };
    }
    seen.add(id);
    const image = String(item.image || '').slice(0, 2048);
    if (image) {
      try {
        const parsed = new URL(image);
        if (!['https:', 'http:'].includes(parsed.protocol)) return { error: `لینک تصویر محصول ${id} نامعتبر است` };
      } catch { return { error: `لینک تصویر محصول ${id} نامعتبر است` }; }
    }
    const stock = item.stock === undefined || item.stock === null ? null : Number(item.stock);
    if (stock !== null && (!Number.isSafeInteger(stock) || stock < 0)) return { error: `موجودی محصول ${id} نامعتبر است` };
    const product = {
      id, name, price, image,
      category: String(item.category || '').slice(0, 120),
      description: String(item.description || '').slice(0, 5000), stock,
    };
    statements.push(env.DB.prepare(`
      INSERT INTO products (id, base_json, override_json, stock_remaining, unlimited_stock, updated_at)
      VALUES (?, ?, '{}', ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET base_json = excluded.base_json, updated_at = excluded.updated_at
    `).bind(id, JSON.stringify(product), stock, stock === null ? 1 : 0, now));
  }
  // Intentionally do not delete rows absent from the import file or overwrite live stock/admin overrides.
  if (statements.length) await env.DB.batch(statements);
  return { ok: true, count: statements.length, note: 'محصولات افزوده/به‌روزرسانی شدند؛ محصولات حذف نشده‌اند و تغییرات مدیریتی/موجودی حفظ شده‌اند.' };
}

async function scheduledCleanup(env) {
  const now = Date.now();
  await env.DB.batch([
    env.DB.prepare('DELETE FROM sessions WHERE expires_at <= ?').bind(now),
    env.DB.prepare('DELETE FROM rate_limits WHERE window_started_at < ? AND (blocked_until IS NULL OR blocked_until <= ?)')
      .bind(now - 24 * 60 * 60 * 1000, now),
  ]);
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: corsHeaders(request, env) });
    const url = new URL(request.url);
    const path = url.pathname;
    try {
      if (request.method === 'GET' && path === '/health') {
        const db = await env.DB.prepare('SELECT 1 AS healthy').first();
        return reply(request, env, { ok: Number(db?.healthy) === 1, service: 'angelshop-api-production', database: Number(db?.healthy) === 1 ? 'connected' : 'error' });
      }
      if (request.method === 'POST' && env.WEBHOOK_SECRET && path === `/bale/${env.WEBHOOK_SECRET}`) {
        await handleBale(await readJson(request), env);
        return reply(request, env, { ok: true });
      }
      if (request.method === 'POST' && path === '/admin/catalog' && env.WEBHOOK_SECRET &&
          safeEqual(request.headers.get('X-Setup-Secret') || '', env.WEBHOOK_SECRET)) {
        const result = await importCatalog(request, env);
        return reply(request, env, result, result.error ? 400 : 200);
      }
      if (request.method === 'GET' && path === '/products') return reply(request, env, await getProducts(env));
      if (request.method === 'POST' && path === '/register') return await register(await readJson(request), env, request);
      if (request.method === 'POST' && path === '/login') return await login(await readJson(request), env, request);

      const me = await authenticate(request, env);
      if (!me) return reply(request, env, { error: 'نشست منقضی شده یا معتبر نیست؛ دوباره وارد شوید' }, 401);
      if (request.method === 'GET' && path === '/me') return reply(request, env, publicUser(me));
      if (request.method === 'POST' && path === '/logout') {
        await env.DB.prepare('DELETE FROM sessions WHERE token_hash = ?').bind(me.tokenHash).run();
        return reply(request, env, { ok: true });
      }
      if (request.method === 'GET' && path === '/orders') return reply(request, env, await listOrders(env, me.phone));
      if (request.method === 'GET' && path === '/cart') return reply(request, env, await getCart(env, me.phone));
      if (request.method === 'POST' && path === '/cart') return await saveCart(await readJson(request), env, me, request);
      if (request.method === 'POST' && path === '/order') return await createOrder(await readJson(request), env, me, request);
      return reply(request, env, { error: 'مسیر درخواست پیدا نشد' }, 404);
    } catch (error) {
      const requestId = request.headers.get('cf-ray') || crypto.randomUUID();
      const code = error?.message === 'BODY_TOO_LARGE' ? 'BODY_TOO_LARGE'
        : error?.message === 'INVALID_JSON' ? 'INVALID_JSON' : 'INTERNAL';
      console.error('Angel Shop API error', { requestId, code, message: code === 'INTERNAL' ? 'internal_error' : code });
      const status = code === 'BODY_TOO_LARGE' ? 413 : code === 'INVALID_JSON' ? 400 : 500;
      const message = code === 'BODY_TOO_LARGE' ? 'حجم درخواست بیش از حد مجاز است'
        : code === 'INVALID_JSON' ? 'ساختار JSON درخواست معتبر نیست' : 'خطای داخلی سرور؛ شناسه پیگیری: ' + requestId;
      return reply(request, env, { error: message, requestId }, status);
    }
  },
  async scheduled(_controller, env, ctx) {
    ctx.waitUntil(scheduledCleanup(env));
  },
};
