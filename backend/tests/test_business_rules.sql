-- Run after schema+seed as a superuser: psql -v ON_ERROR_STOP=1 -f tests/test_business_rules.sql

DO $$
DECLARE
  demo_id uuid := '22222222-2222-2222-2222-222222222222';
  other_id uuid;
  plan uuid;
  q1 public.checkout_quote;
  q2 public.checkout_quote;
  p1 public.purchase_result;
  p2 public.purchase_result;
  e1 app.user_esims;
  e2 app.user_esims;
  usage_count int;
  wallet_tables int;
BEGIN
  SELECT count(*) INTO wallet_tables
  FROM information_schema.tables
  WHERE table_schema IN ('app', 'public')
    AND table_name IN ('wallets', 'user_wallets', 'wallet_balances', 'account_balances');
  IF wallet_tables <> 0 THEN
    RAISE EXCEPTION 'Global wallet table must not exist';
  END IF;

  INSERT INTO app.users (email, password_hash, full_name)
  VALUES ('second@esim.app', crypt('Demo12345!', gen_salt('bf')), 'Second')
  RETURNING id INTO other_id;

  SELECT id INTO plan FROM app.esim_plans WHERE country_id IS NOT NULL AND is_active LIMIT 1;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', demo_id, 'app_role', 'customer')::text, true);
  q1 := public.create_checkout(plan, 'USD', 'idem-test-1');
  q2 := public.create_checkout(plan, 'USD', 'idem-test-1');
  IF q1.order_id <> q2.order_id THEN
    RAISE EXCEPTION 'Checkout must be idempotent';
  END IF;
  IF q1.total IS NULL OR q1.total <= 0 THEN
    RAISE EXCEPTION 'Server must calculate a positive total';
  END IF;

  p1 := public.confirm_mock_payment(q1.order_id, true);
  p2 := public.confirm_mock_payment(q1.order_id, true);
  IF p1.esim_id IS NULL OR p1.esim_id <> p2.esim_id THEN
    RAISE EXCEPTION 'One payment must map to exactly one eSIM';
  END IF;

  SELECT * INTO e1 FROM app.user_esims WHERE id = p1.esim_id;
  IF e1.user_id <> demo_id THEN
    RAISE EXCEPTION 'eSIM assigned to wrong user';
  END IF;
  IF e1.remaining_balance <> e1.original_balance THEN
    RAISE EXCEPTION 'New eSIM balance must equal purchased allowance';
  END IF;
  IF e1.iccid NOT LIKE 'MOCK-%' THEN
    RAISE EXCEPTION 'Mock ICCID must be labeled MOCK-';
  END IF;

  q1 := public.create_checkout(plan, 'USD', 'idem-test-2');
  p1 := public.confirm_mock_payment(q1.order_id, true);
  SELECT * INTO e2 FROM app.user_esims WHERE id = p1.esim_id;
  IF e1.id = e2.id OR e1.remaining_balance IS NOT DISTINCT FROM NULL THEN
    RAISE EXCEPTION 'Each purchase must create an independent eSIM';
  END IF;

  PERFORM public.apply_esim_usage(e1.id, 100, 'test');
  SELECT remaining_balance INTO e1.remaining_balance FROM app.user_esims WHERE id = e1.id;
  SELECT remaining_balance INTO e2.remaining_balance FROM app.user_esims WHERE id = e2.id;
  IF e2.remaining_balance <> e2.original_balance THEN
    RAISE EXCEPTION 'Usage on one eSIM must not change another eSIM';
  END IF;

  SELECT count(*) INTO usage_count FROM app.esim_usage WHERE esim_id = e1.id;
  IF usage_count < 1 THEN
    RAISE EXCEPTION 'Usage history must be recorded';
  END IF;

  BEGIN
    UPDATE app.esim_usage SET usage_amount = 1 WHERE esim_id = e1.id;
    RAISE EXCEPTION 'Usage update should have failed';
  EXCEPTION
    WHEN insufficient_privilege THEN NULL;
    WHEN raise_exception THEN
      IF SQLERRM = 'Usage update should have failed' THEN RAISE;
      END IF;
  END;

  BEGIN
    UPDATE app.user_esims SET user_id = other_id WHERE id = e1.id;
    RAISE EXCEPTION 'Reassignment should have failed';
  EXCEPTION
    WHEN raise_exception THEN
      IF SQLERRM = 'Reassignment should have failed' THEN RAISE;
      END IF;
    WHEN check_violation THEN NULL;
    WHEN integrity_constraint_violation THEN NULL;
  END;

  q1 := public.create_checkout(plan, 'USD', 'idem-fail-pay');
  p1 := public.confirm_mock_payment(q1.order_id, false);
  IF p1.esim_id IS NOT NULL THEN
    RAISE EXCEPTION 'Failed payment must not create an eSIM';
  END IF;

  RAISE NOTICE 'Business rule tests passed';
END
$$;
