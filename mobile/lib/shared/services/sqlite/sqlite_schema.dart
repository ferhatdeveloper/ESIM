import 'package:sqflite/sqflite.dart';

const esimSqliteSchema = [
  '''
  CREATE TABLE users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    phone TEXT,
    locale TEXT NOT NULL DEFAULT 'en',
    preferred_currency TEXT NOT NULL DEFAULT 'USD',
    app_role TEXT NOT NULL DEFAULT 'customer',
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE refresh_tokens (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    revoked_at TEXT
  )
  ''',
  '''
  CREATE TABLE password_reset_tokens (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    used_at TEXT
  )
  ''',
  '''
  CREATE TABLE countries (
    id TEXT PRIMARY KEY,
    iso2 TEXT NOT NULL UNIQUE,
    name_en TEXT NOT NULL,
    name_tr TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    flag_emoji TEXT NOT NULL,
    is_popular INTEGER NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 100
  )
  ''',
  '''
  CREATE TABLE regions (
    id TEXT PRIMARY KEY,
    slug TEXT NOT NULL UNIQUE,
    name_en TEXT NOT NULL,
    name_tr TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    is_popular INTEGER NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 100
  )
  ''',
  '''
  CREATE TABLE esim_plans (
    id TEXT PRIMARY KEY,
    country_id TEXT,
    region_id TEXT,
    name_en TEXT NOT NULL,
    name_tr TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    data_amount_mb INTEGER NOT NULL,
    validity_days INTEGER NOT NULL,
    is_featured INTEGER NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 100
  )
  ''',
  '''
  CREATE TABLE plan_prices (
    plan_id TEXT NOT NULL,
    currency TEXT NOT NULL,
    amount REAL NOT NULL,
    PRIMARY KEY (plan_id, currency)
  )
  ''',
  '''
  CREATE TABLE orders (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    status TEXT NOT NULL,
    currency TEXT NOT NULL,
    subtotal REAL NOT NULL,
    tax REAL NOT NULL,
    fees REAL NOT NULL,
    total REAL NOT NULL,
    idempotency_key TEXT NOT NULL,
    created_at TEXT NOT NULL,
    UNIQUE (user_id, idempotency_key)
  )
  ''',
  '''
  CREATE TABLE order_items (
    order_id TEXT PRIMARY KEY,
    plan_id TEXT NOT NULL,
    unit_price REAL NOT NULL,
    currency TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE payments (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL UNIQUE,
    provider TEXT NOT NULL DEFAULT 'mock',
    status TEXT NOT NULL,
    amount REAL NOT NULL,
    currency TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE user_esims (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    order_id TEXT NOT NULL UNIQUE,
    plan_id TEXT NOT NULL,
    iccid TEXT UNIQUE,
    smdp_address TEXT,
    activation_code TEXT,
    confirmation_code TEXT,
    original_balance REAL NOT NULL,
    remaining_balance REAL NOT NULL,
    balance_unit TEXT NOT NULL DEFAULT 'MB',
    status TEXT NOT NULL,
    activated_at TEXT,
    expires_at TEXT,
    is_mock INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    CHECK (remaining_balance >= 0),
    CHECK (remaining_balance <= original_balance)
  )
  ''',
  '''
  CREATE TABLE esim_usage (
    id TEXT PRIMARY KEY,
    esim_id TEXT NOT NULL,
    usage_amount REAL NOT NULL,
    balance_before REAL NOT NULL,
    balance_after REAL NOT NULL,
    source TEXT NOT NULL,
    created_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE notifications (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    type TEXT NOT NULL,
    title_en TEXT NOT NULL,
    title_tr TEXT NOT NULL,
    title_ar TEXT NOT NULL,
    body_en TEXT NOT NULL,
    body_tr TEXT NOT NULL,
    body_ar TEXT NOT NULL,
    is_read INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
  )
  ''',
];

Future<void> createEsimSchema(Database db) async {
  for (final stmt in esimSqliteSchema) {
    await db.execute(stmt);
  }
}
