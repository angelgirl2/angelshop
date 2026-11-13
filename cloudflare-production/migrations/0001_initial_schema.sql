PRAGMA foreign_keys = ON;

-- Customer accounts. Passwords are stored as salted PBKDF2 hashes only.
CREATE TABLE IF NOT EXISTS users (
  phone TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  password_salt TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

-- Only SHA-256 hashes of random bearer tokens are stored.
CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  phone TEXT NOT NULL REFERENCES users(phone) ON DELETE CASCADE,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sessions_phone ON sessions(phone);
CREATE INDEX IF NOT EXISTS idx_sessions_expiry ON sessions(expires_at);

-- IP/phone-based rolling windows for signup and login abuse protection.
CREATE TABLE IF NOT EXISTS rate_limits (
  rate_key TEXT PRIMARY KEY,
  attempts INTEGER NOT NULL,
  window_started_at INTEGER NOT NULL,
  blocked_until INTEGER
);
CREATE INDEX IF NOT EXISTS idx_rate_limits_window ON rate_limits(window_started_at);

-- base_json is the immutable seed catalog data; override_json stores admin edits.
-- stock is kept in dedicated columns so reservations can be atomic in SQL triggers.
CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY,
  base_json TEXT NOT NULL,
  override_json TEXT NOT NULL DEFAULT '{}',
  stock_remaining INTEGER CHECK(stock_remaining IS NULL OR stock_remaining >= 0),
  unlimited_stock INTEGER NOT NULL DEFAULT 1 CHECK(unlimited_stock IN (0, 1)),
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS orders (
  code TEXT PRIMARY KEY,
  phone TEXT NOT NULL REFERENCES users(phone),
  buyer_name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  date_label TEXT NOT NULL,
  total INTEGER NOT NULL CHECK(total >= 0),
  status TEXT NOT NULL CHECK(status IN ('pending', 'approved', 'rejected')),
  bale_message_id INTEGER,
  notification_status TEXT NOT NULL DEFAULT 'pending'
    CHECK(notification_status IN ('pending', 'sent', 'failed', 'not_configured'))
);
CREATE INDEX IF NOT EXISTS idx_orders_phone_created ON orders(phone, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_status_created ON orders(status, created_at DESC);

CREATE TABLE IF NOT EXISTS order_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_code TEXT NOT NULL REFERENCES orders(code) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(id),
  product_name TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK(quantity > 0),
  unit_price INTEGER NOT NULL CHECK(unit_price >= 0)
);
CREATE INDEX IF NOT EXISTS idx_order_items_code ON order_items(order_code);

CREATE TABLE IF NOT EXISTS order_status_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_code TEXT NOT NULL REFERENCES orders(code) ON DELETE CASCADE,
  old_status TEXT,
  new_status TEXT NOT NULL,
  source TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_order_events_code ON order_status_events(order_code, created_at);

-- Cart data follows the signed-in account and is synced across devices.
CREATE TABLE IF NOT EXISTS cart_items (
  phone TEXT NOT NULL REFERENCES users(phone) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(id),
  quantity INTEGER NOT NULL CHECK(quantity BETWEEN 1 AND 100),
  updated_at INTEGER NOT NULL,
  PRIMARY KEY(phone, product_id)
);
CREATE INDEX IF NOT EXISTS idx_cart_items_phone ON cart_items(phone);

CREATE TABLE IF NOT EXISTS app_settings (
  setting_key TEXT PRIMARY KEY,
  setting_value TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Reserving finite inventory happens in the same D1 transaction as order creation.
-- If any item cannot be reserved, the trigger aborts the whole D1 batch.
CREATE TRIGGER IF NOT EXISTS trg_reserve_stock_before_order_item
BEFORE INSERT ON order_items
BEGIN
  SELECT CASE
    WHEN NOT EXISTS (SELECT 1 FROM products WHERE id = NEW.product_id)
    THEN RAISE(ABORT, 'PRODUCT_NOT_FOUND')
  END;

  UPDATE products
  SET stock_remaining = stock_remaining - NEW.quantity,
      updated_at = CAST(strftime('%s', 'now') AS INTEGER) * 1000
  WHERE id = NEW.product_id
    AND unlimited_stock = 0
    AND stock_remaining >= NEW.quantity;

  SELECT CASE
    WHEN (SELECT unlimited_stock FROM products WHERE id = NEW.product_id) = 0
      AND changes() = 0
    THEN RAISE(ABORT, 'INSUFFICIENT_STOCK')
  END;
END;

-- If an administrator rejects a pending order, reserved units are returned once.
CREATE TRIGGER IF NOT EXISTS trg_restore_stock_on_rejection
AFTER UPDATE OF status ON orders
WHEN OLD.status = 'pending' AND NEW.status = 'rejected'
BEGIN
  UPDATE products
  SET stock_remaining = stock_remaining + (
        SELECT COALESCE(SUM(oi.quantity), 0)
        FROM order_items oi
        WHERE oi.order_code = NEW.code AND oi.product_id = products.id
      ),
      updated_at = CAST(strftime('%s', 'now') AS INTEGER) * 1000
  WHERE unlimited_stock = 0
    AND id IN (SELECT product_id FROM order_items WHERE order_code = NEW.code);
END;
