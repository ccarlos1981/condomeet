-- ═══════════════════════════════════════════════════════
-- Lista Inteligente — Subscription & Coupon System
-- ═══════════════════════════════════════════════════════

-- 1) Subscription tracking per user
CREATE TABLE lista_user_subscription (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  trial_started_at TIMESTAMPTZ DEFAULT NOW(),
  trial_ends_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '45 days'),
  is_premium BOOLEAN DEFAULT FALSE,
  subscription_source TEXT DEFAULT 'trial', -- 'trial', 'revenuecat', 'cupom'
  coupon_code TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE lista_user_subscription ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own lista subscription"
  ON lista_user_subscription FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own lista subscription"
  ON lista_user_subscription FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own lista subscription"
  ON lista_user_subscription FOR UPDATE USING (auth.uid() = user_id);

-- 2) Coupon/promo code system for influencers
CREATE TABLE lista_subscription_coupons (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,              -- e.g. 'MARIA50', 'INFLUENCER2026'
  description TEXT,                       -- Internal note: "Cupom da Maria @maria_condo"
  discount_type TEXT DEFAULT 'trial_extension', -- 'trial_extension', 'full_access', 'percentage'
  discount_value INT DEFAULT 30,          -- days for trial_extension, percentage for percentage
  max_uses INT,                           -- NULL = unlimited
  current_uses INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  valid_from TIMESTAMPTZ DEFAULT NOW(),
  valid_until TIMESTAMPTZ,                -- NULL = never expires
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE lista_subscription_coupons ENABLE ROW LEVEL SECURITY;

-- Only admin can manage coupons (via service role), users can read active ones
CREATE POLICY "Anyone can view active coupons"
  ON lista_subscription_coupons FOR SELECT USING (is_active = TRUE);

-- 3) Coupon redemption log
CREATE TABLE lista_coupon_redemptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  coupon_id UUID REFERENCES lista_subscription_coupons(id) NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  redeemed_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(coupon_id, user_id) -- each user can only redeem each coupon once
);

ALTER TABLE lista_coupon_redemptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own redemptions"
  ON lista_coupon_redemptions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own redemptions"
  ON lista_coupon_redemptions FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 4) RPC to redeem coupon
CREATE OR REPLACE FUNCTION lista_redeem_coupon(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_coupon RECORD;
  v_user_id UUID := auth.uid();
  v_already_used BOOLEAN;
  v_sub RECORD;
BEGIN
  -- Find coupon
  SELECT * INTO v_coupon FROM lista_subscription_coupons
    WHERE UPPER(code) = UPPER(p_code) AND is_active = TRUE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Cupom não encontrado ou expirado');
  END IF;

  -- Check validity period
  IF v_coupon.valid_until IS NOT NULL AND v_coupon.valid_until < NOW() THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Cupom expirado');
  END IF;

  -- Check max uses
  IF v_coupon.max_uses IS NOT NULL AND v_coupon.current_uses >= v_coupon.max_uses THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Cupom esgotado');
  END IF;

  -- Check if already redeemed by this user
  SELECT EXISTS(SELECT 1 FROM lista_coupon_redemptions WHERE coupon_id = v_coupon.id AND user_id = v_user_id) INTO v_already_used;
  IF v_already_used THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Você já resgatou este cupom');
  END IF;

  -- Get or create subscription
  SELECT * INTO v_sub FROM lista_user_subscription WHERE user_id = v_user_id;
  IF NOT FOUND THEN
    INSERT INTO lista_user_subscription (user_id) VALUES (v_user_id);
    SELECT * INTO v_sub FROM lista_user_subscription WHERE user_id = v_user_id;
  END IF;

  -- Apply discount
  IF v_coupon.discount_type = 'trial_extension' THEN
    -- Extend trial by X days
    UPDATE lista_user_subscription
      SET trial_ends_at = GREATEST(trial_ends_at, NOW()) + (v_coupon.discount_value || ' days')::INTERVAL,
          coupon_code = v_coupon.code,
          updated_at = NOW()
      WHERE user_id = v_user_id;
  ELSIF v_coupon.discount_type = 'full_access' THEN
    -- Grant premium access for X days
    UPDATE lista_user_subscription
      SET is_premium = TRUE,
          subscription_source = 'cupom',
          trial_ends_at = GREATEST(trial_ends_at, NOW()) + (v_coupon.discount_value || ' days')::INTERVAL,
          coupon_code = v_coupon.code,
          updated_at = NOW()
      WHERE user_id = v_user_id;
  END IF;

  -- Record redemption
  INSERT INTO lista_coupon_redemptions (coupon_id, user_id) VALUES (v_coupon.id, v_user_id);

  -- Increment uses
  UPDATE lista_subscription_coupons SET current_uses = current_uses + 1 WHERE id = v_coupon.id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'discount_type', v_coupon.discount_type,
    'discount_value', v_coupon.discount_value,
    'message', CASE
      WHEN v_coupon.discount_type = 'trial_extension' THEN 'Trial estendido por ' || v_coupon.discount_value || ' dias!'
      WHEN v_coupon.discount_type = 'full_access' THEN 'Acesso premium por ' || v_coupon.discount_value || ' dias!'
      ELSE 'Cupom aplicado!'
    END
  );
END;
$$;
