# eSIM API contract (PostgreSQL + PostgREST)

Flutter talks only to PostgREST. There is no application server.

Base URL: `http://<host>:3000`

## Authentication

Anonymous RPCs:

| Method | Path | Body |
| --- | --- | --- |
| POST | `/rpc/register` | `{ email, password, full_name, locale, preferred_currency }` |
| POST | `/rpc/login` | `{ email, password }` |
| POST | `/rpc/refresh_session` | `{ refresh_token }` |
| POST | `/rpc/logout` | `{ refresh_token }` |
| POST | `/rpc/request_password_reset` | `{ email }` |
| POST | `/rpc/reset_password` | `{ reset_token, new_password }` |

Session response (`auth_session`):

```json
{
  "access_token": "jwt",
  "refresh_token": "opaque",
  "token_type": "bearer",
  "expires_in": 900,
  "user_id": "uuid",
  "email": "user@example.com",
  "full_name": "Name",
  "locale": "en",
  "preferred_currency": "USD",
  "app_role": "customer"
}
```

Send `Authorization: Bearer <access_token>` on every authenticated call.

JWT claims used by PostgREST:

- `role`: `authenticated` or `admin`
- `sub`: user UUID
- `aud`: `esim-app`
- `app_role`: `customer` or `admin`

Passwords are stored only as `pgcrypto` bcrypt hashes.

## Public marketplace

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/countries` | `order=sort_order.asc`, filter `is_popular=eq.true` |
| GET | `/regions` | |
| GET | `/country_regions` | |
| GET | `/marketplace_plans` | filter `country_id=eq.<uuid>`, `or=(name_en.ilike.*q*,country_name_en.ilike.*q*)` |
| GET | `/public_settings` | currencies, environment, mock flags |

Pagination: `Range: 0-19` and `Prefer: count=exact`.

Never send prices, user IDs, or entitlements as trusted input. Checkout re-reads the plan.

## Authenticated resources

| Method | Path |
| --- | --- |
| GET | `/me` |
| GET | `/my_esims` |
| GET | `/my_esims?id=eq.<uuid>` |
| GET | `/my_esim_usage?esim_id=eq.<uuid>&order=created_at.desc` |
| GET | `/my_orders?order=created_at.desc` |
| GET | `/my_notifications?order=created_at.desc` |

Row Level Security and view filters both restrict rows to `jwt.sub`.

## Privileged RPCs (JWT required)

| RPC | Purpose |
| --- | --- |
| `update_profile` | locale / currency / name |
| `create_checkout` | `{ plan_id, currency, idempotency_key }` — server calculates totals |
| `confirm_mock_payment` | `{ order_id, succeed }` — **explicit mock payment adapter** |
| `retry_provisioning` | recoverable provisioning, no duplicate eSIM |
| `activate_esim` | `ready` → `active` |
| `apply_esim_usage` | server-side balance change + immutable usage row |
| `expire_due_esims` | marks expired ready/active eSIMs |
| `mark_notification_read` | |
| `mark_all_notifications_read` | |

`create_checkout` is idempotent on `(user_id, idempotency_key)`.

`confirm_mock_payment` creates at most one `user_esims` row per order. Failed payment or failed provisioning does **not** create an active eSIM.

Installation fields (`iccid`, `smdp_address`, `activation_code`) are returned only for `ready` and `active` eSIMs owned by the caller.

## Admin RPCs (`app_role=admin`)

- `admin_list_users` — never returns `password_hash`
- `admin_set_plan_active`

## Business rules enforced in SQL

- 1 eSIM = 1 independent balance
- no user wallet table
- no balance transfer / merge functions
- eSIM cannot be reassigned
- terminal states cannot return to `ready`/`active`
- usage history is immutable
- balance updates only through `apply_esim_usage`

## Mock isolation

`payment_provider=mock` and `esim_provider=mock` in `public_settings`. ICCID and activation values use a `MOCK-` prefix. Flutter must label mock checkout as mock.
