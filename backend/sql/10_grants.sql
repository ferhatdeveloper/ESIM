REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA app FROM PUBLIC;
REVOKE ALL ON SCHEMA app_private FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO anon, authenticated, admin;

GRANT USAGE ON TYPE public.auth_session TO anon, authenticated, admin;
GRANT USAGE ON TYPE public.checkout_quote TO anon, authenticated, admin;
GRANT USAGE ON TYPE public.purchase_result TO anon, authenticated, admin;

GRANT SELECT ON public.countries TO anon, authenticated, admin;
GRANT SELECT ON public.regions TO anon, authenticated, admin;
GRANT SELECT ON public.country_regions TO anon, authenticated, admin;
GRANT SELECT ON public.marketplace_plans TO anon, authenticated, admin;
GRANT SELECT ON public.public_settings TO anon, authenticated, admin;

GRANT SELECT ON public.me TO authenticated, admin;
GRANT SELECT ON public.my_orders TO authenticated, admin;
GRANT SELECT ON public.my_esims TO authenticated, admin;
GRANT SELECT ON public.my_esim_usage TO authenticated, admin;
GRANT SELECT ON public.my_notifications TO authenticated, admin;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.register(text, text, text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.login(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.refresh_session(text) TO anon, authenticated, admin;
GRANT EXECUTE ON FUNCTION public.logout(text) TO anon, authenticated, admin;
GRANT EXECUTE ON FUNCTION public.request_password_reset(text) TO anon;
GRANT EXECUTE ON FUNCTION public.reset_password(text, text) TO anon;

GRANT EXECUTE ON FUNCTION public.update_profile(text, text, text, text) TO authenticated, admin;
GRANT EXECUTE ON FUNCTION public.create_checkout(uuid, text, text) TO authenticated, admin;
GRANT EXECUTE ON FUNCTION public.confirm_mock_payment(uuid, boolean) TO authenticated, admin;
GRANT EXECUTE ON FUNCTION public.retry_provisioning(uuid) TO authenticated, admin;
GRANT EXECUTE ON FUNCTION public.activate_esim(uuid) TO authenticated, admin;
GRANT EXECUTE ON FUNCTION public.apply_esim_usage(uuid, numeric, text) TO authenticated, admin;
GRANT EXECUTE ON FUNCTION public.expire_due_esims() TO authenticated, admin;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO authenticated, admin;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated, admin;

GRANT EXECUTE ON FUNCTION public.admin_list_users() TO admin;
GRANT EXECUTE ON FUNCTION public.admin_set_plan_active(uuid, boolean) TO admin;

GRANT EXECUTE ON FUNCTION app.current_user_id() TO anon, authenticated, admin;
GRANT EXECUTE ON FUNCTION app.current_app_role() TO anon, authenticated, admin;
