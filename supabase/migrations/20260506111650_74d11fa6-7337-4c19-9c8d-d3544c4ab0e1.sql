-- 1) Bank deposits (clube empresta dinheiro ao sistema e ganha juros)
CREATE TABLE IF NOT EXISTS public.bank_deposits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id uuid NOT NULL,
  principal bigint NOT NULL,
  interest_rate integer NOT NULL DEFAULT 4,
  weeks integer NOT NULL,
  weeks_remaining integer NOT NULL,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  matured_at timestamptz
);
ALTER TABLE public.bank_deposits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Deposits viewable by club owner" ON public.bank_deposits FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.clubs WHERE clubs.id = bank_deposits.club_id AND clubs.user_id = auth.uid()));

CREATE OR REPLACE FUNCTION public.create_bank_deposit(p_club_id uuid, p_amount bigint, p_weeks integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_balance bigint; v_rate integer; v_new_balance bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM clubs WHERE id=p_club_id AND user_id=auth.uid()) THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;
  IF p_amount < 10000 THEN RAISE EXCEPTION 'min 10000'; END IF;
  IF p_weeks < 4 OR p_weeks > 104 THEN RAISE EXCEPTION 'invalid weeks'; END IF;
  SELECT balance INTO v_balance FROM clubs WHERE id=p_club_id FOR UPDATE;
  IF v_balance < p_amount THEN RAISE EXCEPTION 'insufficient funds'; END IF;
  v_rate := CASE WHEN p_weeks >= 52 THEN 8 WHEN p_weeks >= 20 THEN 6 ELSE 4 END;
  UPDATE clubs SET balance = balance - p_amount WHERE id = p_club_id;
  SELECT balance INTO v_new_balance FROM clubs WHERE id = p_club_id;
  INSERT INTO bank_deposits (club_id, principal, interest_rate, weeks, weeks_remaining)
  VALUES (p_club_id, p_amount, v_rate, p_weeks, p_weeks);
  INSERT INTO financial_transactions (club_id, amount, balance_after, type, description)
  VALUES (p_club_id, -p_amount, v_new_balance, 'banco', 'Depósito bancário ' || p_weeks || 'sem @ ' || v_rate || '%');
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.process_bank_deposits()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_dep record; v_payout bigint; v_new_balance bigint; v_count integer := 0;
BEGIN
  FOR v_dep IN SELECT * FROM bank_deposits WHERE status='active' FOR UPDATE LOOP
    UPDATE bank_deposits SET weeks_remaining = weeks_remaining - 1 WHERE id = v_dep.id;
    IF v_dep.weeks_remaining - 1 <= 0 THEN
      v_payout := v_dep.principal + (v_dep.principal * v_dep.interest_rate * v_dep.weeks / 5200);
      UPDATE clubs SET balance = balance + v_payout WHERE id = v_dep.club_id;
      SELECT balance INTO v_new_balance FROM clubs WHERE id = v_dep.club_id;
      UPDATE bank_deposits SET status='matured', matured_at=now(), weeks_remaining=0 WHERE id = v_dep.id;
      INSERT INTO financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_dep.club_id, v_payout, v_new_balance, 'banco', 'Resgate depósito + juros');
      v_count := v_count + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('matured', v_count);
END;
$$;

-- 2) Club trophies (públicos)
CREATE TABLE IF NOT EXISTS public.club_trophies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id uuid NOT NULL,
  trophy_type text NOT NULL,
  competition_name text NOT NULL,
  season_number integer NOT NULL,
  position text NOT NULL DEFAULT 'champion',
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.club_trophies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Trophies viewable by everyone" ON public.club_trophies FOR SELECT USING (true);

-- 3) Lineup tactical styles
ALTER TABLE public.lineups
  ADD COLUMN IF NOT EXISTS passing_style text NOT NULL DEFAULT 'equilibrado',
  ADD COLUMN IF NOT EXISTS marking_style text NOT NULL DEFAULT 'zona',
  ADD COLUMN IF NOT EXISTS positioning_style text NOT NULL DEFAULT 'equilibrado';

-- 4) Season advance: ages players, recalcs salary=1% value, decline after 28, mark retire-eligible at 32
CREATE OR REPLACE FUNCTION public.advance_season(p_season_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_player record; v_decline integer; v_new_value bigint; v_aged integer := 0;
BEGIN
  FOR v_player IN SELECT * FROM players LOOP
    UPDATE players SET age = age + 1 WHERE id = v_player.id;
    IF v_player.age + 1 >= 28 THEN
      v_decline := GREATEST(1, ((v_player.age + 1) - 27));
      UPDATE players SET
        velocidade = GREATEST(1, velocidade - LEAST(v_decline, 1)),
        forca = GREATEST(1, forca - LEAST(v_decline, 1)),
        resistencia = GREATEST(1, resistencia - LEAST(v_decline, 1)),
        forma = GREATEST(1, forma - LEAST(v_decline, 1))
      WHERE id = v_player.id;
    END IF;
    -- Recalc market value from average tech+phys (simple)
    SELECT GREATEST(20000, ((reflexos+posicionamento+jogo_aereo+desarme+armacao+passe+tecnica+chute+velocidade+forca+resistencia+forma) * 8000)::bigint)
      INTO v_new_value FROM players WHERE id = v_player.id;
    UPDATE players SET market_value = v_new_value, salary = GREATEST(1000, (v_new_value / 100)) WHERE id = v_player.id;
    v_aged := v_aged + 1;
  END LOOP;
  RETURN jsonb_build_object('aged', v_aged);
END;
$$;

CREATE OR REPLACE FUNCTION public.retire_player(p_player_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_age integer;
BEGIN
  SELECT age INTO v_age FROM players p
    JOIN clubs c ON c.id = p.club_id
    WHERE p.id = p_player_id AND c.user_id = auth.uid();
  IF v_age IS NULL THEN RAISE EXCEPTION 'unauthorized'; END IF;
  IF v_age < 32 THEN RAISE EXCEPTION 'player must be 32+'; END IF;
  DELETE FROM players WHERE id = p_player_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

-- Restrict execute on internal admin/process functions
REVOKE EXECUTE ON FUNCTION public.process_bank_deposits() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.advance_season(uuid) FROM anon, authenticated;