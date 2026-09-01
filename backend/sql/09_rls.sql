ALTER TABLE app.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.refresh_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.password_reset_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.user_esims ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.esim_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.provider_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.config ENABLE ROW LEVEL SECURITY;

-- Direct table access is revoked. Policies exist so accidental grants cannot
-- leak another user's rows. user_id is always taken from the JWT, never the client.

CREATE POLICY users_self ON app.users
  FOR SELECT TO authenticated, admin
  USING (id = app.current_user_id());

CREATE POLICY users_admin ON app.users
  FOR ALL TO admin
  USING (app.current_app_role() = 'admin')
  WITH CHECK (app.current_app_role() = 'admin');

CREATE POLICY orders_self ON app.orders
  FOR SELECT TO authenticated, admin
  USING (user_id = app.current_user_id() OR app.current_app_role() = 'admin');

CREATE POLICY order_items_self ON app.order_items
  FOR SELECT TO authenticated, admin
  USING (
    EXISTS (
      SELECT 1 FROM app.orders o
      WHERE o.id = order_id
        AND (o.user_id = app.current_user_id() OR app.current_app_role() = 'admin')
    )
  );

CREATE POLICY payments_self ON app.payments
  FOR SELECT TO authenticated, admin
  USING (
    EXISTS (
      SELECT 1 FROM app.orders o
      WHERE o.id = order_id
        AND (o.user_id = app.current_user_id() OR app.current_app_role() = 'admin')
    )
  );

CREATE POLICY user_esims_self ON app.user_esims
  FOR SELECT TO authenticated, admin
  USING (user_id = app.current_user_id() OR app.current_app_role() = 'admin');

CREATE POLICY esim_usage_self ON app.esim_usage
  FOR SELECT TO authenticated, admin
  USING (
    EXISTS (
      SELECT 1 FROM app.user_esims e
      WHERE e.id = esim_id
        AND (e.user_id = app.current_user_id() OR app.current_app_role() = 'admin')
    )
  );

CREATE POLICY notifications_self ON app.notifications
  FOR SELECT TO authenticated, admin
  USING (user_id = app.current_user_id() OR app.current_app_role() = 'admin');

CREATE POLICY countries_read ON app.countries
  FOR SELECT TO anon, authenticated, admin
  USING (is_active OR app.current_app_role() = 'admin');

CREATE POLICY regions_read ON app.regions
  FOR SELECT TO anon, authenticated, admin
  USING (is_active OR app.current_app_role() = 'admin');

ALTER TABLE app.countries ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.regions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.esim_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.plan_prices ENABLE ROW LEVEL SECURITY;

CREATE POLICY plans_read ON app.esim_plans
  FOR SELECT TO anon, authenticated, admin
  USING (is_active OR app.current_app_role() = 'admin');

CREATE POLICY plan_prices_read ON app.plan_prices
  FOR SELECT TO anon, authenticated, admin
  USING (true);

ALTER VIEW public.me SET (security_barrier = true);
ALTER VIEW public.my_orders SET (security_barrier = true);
ALTER VIEW public.my_esims SET (security_barrier = true);
ALTER VIEW public.my_esim_usage SET (security_barrier = true);
ALTER VIEW public.my_notifications SET (security_barrier = true);
