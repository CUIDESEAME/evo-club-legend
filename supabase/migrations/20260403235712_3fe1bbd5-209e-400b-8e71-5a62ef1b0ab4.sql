
-- Add marketing_budget to clubs (weekly marketing spend)
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS marketing_budget bigint NOT NULL DEFAULT 0;

-- Junior investment tracking table (max 1 investment per junior per week)
CREATE TABLE public.junior_investments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  junior_id uuid NOT NULL REFERENCES public.juniors(id) ON DELETE CASCADE,
  club_id uuid NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  week_number integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(junior_id, week_number)
);

ALTER TABLE public.junior_investments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Club owners can view investments" ON public.junior_investments
  FOR SELECT USING (EXISTS (SELECT 1 FROM clubs WHERE clubs.id = junior_investments.club_id AND clubs.user_id = auth.uid()));

CREATE POLICY "Club owners can insert investments" ON public.junior_investments
  FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM clubs WHERE clubs.id = junior_investments.club_id AND clubs.user_id = auth.uid()));

-- Add a week_counter to seasons or use a global counter
-- We'll track investment weeks via a simple counter on clubs
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS game_week integer NOT NULL DEFAULT 0;

-- Update process_game_week to handle marketing, members, revenue, junior training
CREATE OR REPLACE FUNCTION public.process_game_week()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_club record;
  v_training record;
  v_salary_total bigint;
  v_maintenance_total bigint;
  v_interest bigint;
  v_interest_rate integer;
  v_new_balance bigint;
  v_clubs_processed integer := 0;
  v_member_revenue bigint;
  v_marketing_cost bigint;
  v_member_change integer;
  v_recent_wins integer;
  v_recent_losses integer;
  v_league_bonus integer;
  v_new_members integer;
  v_new_week integer;
BEGIN
  FOR v_club IN SELECT * FROM public.clubs FOR UPDATE LOOP
    v_new_balance := v_club.balance;
    v_new_week := v_club.game_week + 1;

    -- Update game week
    UPDATE public.clubs SET game_week = v_new_week WHERE id = v_club.id;

    -- === CONSTRUCTION ===
    UPDATE public.patrimony
    SET construction_weeks_remaining = GREATEST(0, construction_weeks_remaining - 1)
    WHERE club_id = v_club.id AND construction_weeks_remaining > 0;

    -- === JUNIORS: reduce weeks, reveal, train ===
    UPDATE public.juniors
    SET weeks_to_reveal = GREATEST(0, weeks_to_reveal - 1),
        revealed = CASE WHEN weeks_to_reveal <= 1 THEN true ELSE revealed END
    WHERE club_id = v_club.id AND revealed = false;

    -- Junior training: improve quality slightly during wait
    UPDATE public.juniors
    SET quality = LEAST(quality + 1, 6)
    WHERE club_id = v_club.id AND revealed = false AND random() < 0.15;

    -- === SALARIES ===
    SELECT COALESCE(SUM(salary), 0) INTO v_salary_total
    FROM public.players WHERE club_id = v_club.id;
    v_new_balance := v_new_balance - v_salary_total;
    IF v_salary_total > 0 THEN
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_salary_total, v_new_balance, 'salarios', 'Pagamento semanal de salários');
    END IF;

    -- === MAINTENANCE ===
    SELECT COALESCE(SUM(maintenance_cost), 0) INTO v_maintenance_total
    FROM public.patrimony WHERE club_id = v_club.id;
    v_new_balance := v_new_balance - v_maintenance_total;
    IF v_maintenance_total > 0 THEN
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_maintenance_total, v_new_balance, 'manutencao', 'Manutenção semanal do patrimônio');
    END IF;

    -- === MARKETING COST ===
    v_marketing_cost := v_club.marketing_budget;
    IF v_marketing_cost > 0 THEN
      v_new_balance := v_new_balance - v_marketing_cost;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_marketing_cost, v_new_balance, 'marketing', 'Investimento semanal em marketing');
    END IF;

    -- === MEMBER REVENUE (R$100 per member per week) ===
    v_member_revenue := v_club.members * 100;
    IF v_member_revenue > 0 THEN
      v_new_balance := v_new_balance + v_member_revenue;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, v_member_revenue, v_new_balance, 'socios', 'Receita semanal de sócios (' || v_club.members || ' sócios)');
    END IF;

    -- === MEMBER FLUCTUATION based on performance, league, marketing ===
    -- Get recent results (last 5 matches)
    SELECT COALESCE(SUM(CASE
      WHEN (m.home_club_id = v_club.id AND m.home_score > m.away_score) OR
           (m.away_club_id = v_club.id AND m.away_score > m.home_score) THEN 1 ELSE 0 END), 0),
      COALESCE(SUM(CASE
      WHEN (m.home_club_id = v_club.id AND m.home_score < m.away_score) OR
           (m.away_club_id = v_club.id AND m.away_score < m.home_score) THEN 1 ELSE 0 END), 0)
    INTO v_recent_wins, v_recent_losses
    FROM (SELECT * FROM public.matches
      WHERE (home_club_id = v_club.id OR away_club_id = v_club.id) AND status = 'played'
      ORDER BY played_at DESC LIMIT 5) m;

    -- League bonus: F=0, E=1, D=2, C=3, B=4, A=5
    v_league_bonus := CASE v_club.league
      WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3
      WHEN 'D' THEN 2 WHEN 'E' THEN 1 ELSE 0 END;

    -- Member change formula: wins attract, losses repel, marketing attracts, league matters
    v_member_change := (v_recent_wins * 3) - (v_recent_losses * 2) + v_league_bonus
      + (v_club.marketing_budget / 5000)::integer  -- each 5k marketing = +1 member/week
      + floor(random() * 3)::integer - 1;  -- random -1 to +1

    -- Ensure minimum 0 members
    v_new_members := GREATEST(0, v_club.members + v_member_change);
    UPDATE public.clubs SET members = v_new_members WHERE id = v_club.id;

    IF v_member_change != 0 THEN
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, 0, v_new_balance, 'socios_variacao',
        CASE WHEN v_member_change > 0
          THEN '+' || v_member_change || ' novos sócios (total: ' || v_new_members || ')'
          ELSE v_member_change || ' sócios saíram (total: ' || v_new_members || ')' END);
    END IF;

    -- === INTEREST (capped) ===
    IF v_new_balance < 0 THEN
      v_interest_rate := LEAST(5 + (ABS(v_new_balance) / 500000)::integer, 20);
      v_interest := ABS(v_new_balance) * v_interest_rate / 100;
      v_interest := LEAST(v_interest, 500000);
      v_new_balance := v_new_balance - v_interest;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_interest, v_new_balance, 'juros', 'Juros sobre saldo devedor (' || v_interest_rate || '%)');
    END IF;

    -- === TRAINING ===
    SELECT * INTO v_training FROM public.training_config WHERE club_id = v_club.id;
    IF v_training IS NOT NULL THEN
      IF v_training.physical_type = 'forca' THEN
        UPDATE public.players SET forca = LEAST(forca + 1, potencial_forca)
        WHERE club_id = v_club.id AND forca < potencial_forca AND random() < (v_training.physical_intensity::float / 150.0);
      ELSIF v_training.physical_type = 'velocidade' THEN
        UPDATE public.players SET velocidade = LEAST(velocidade + 1, potencial_velocidade)
        WHERE club_id = v_club.id AND velocidade < potencial_velocidade AND random() < (v_training.physical_intensity::float / 150.0);
      ELSIF v_training.physical_type = 'resistencia' THEN
        UPDATE public.players SET resistencia = LEAST(resistencia + 1, potencial_resistencia)
        WHERE club_id = v_club.id AND resistencia < potencial_resistencia AND random() < (v_training.physical_intensity::float / 150.0);
      ELSIF v_training.physical_type = 'forma' THEN
        UPDATE public.players SET forma = LEAST(forma + 1, potencial_forma)
        WHERE club_id = v_club.id AND forma < potencial_forma AND random() < (v_training.physical_intensity::float / 150.0);
      ELSE
        UPDATE public.players SET
          velocidade = CASE WHEN random() < 0.25 AND velocidade < potencial_velocidade THEN LEAST(velocidade + 1, potencial_velocidade) ELSE velocidade END,
          forca = CASE WHEN random() < 0.25 AND forca < potencial_forca THEN LEAST(forca + 1, potencial_forca) ELSE forca END,
          resistencia = CASE WHEN random() < 0.25 AND resistencia < potencial_resistencia THEN LEAST(resistencia + 1, potencial_resistencia) ELSE resistencia END,
          forma = CASE WHEN random() < 0.25 AND forma < potencial_forma THEN LEAST(forma + 1, potencial_forma) ELSE forma END
        WHERE club_id = v_club.id AND random() < (v_training.physical_intensity::float / 150.0);
      END IF;

      IF v_training.physical_intensity > 70 THEN
        UPDATE public.players
        SET is_injured = true, injury_weeks = 1 + floor(random() * 3)::int
        WHERE club_id = v_club.id AND is_injured = false
          AND random() < ((v_training.physical_intensity - 70)::float / 300.0);
      END IF;

      UPDATE public.players
      SET injury_weeks = GREATEST(0, injury_weeks - 1),
          is_injured = CASE WHEN injury_weeks <= 1 THEN false ELSE true END
      WHERE club_id = v_club.id AND is_injured = true;
    END IF;

    UPDATE public.clubs SET balance = v_new_balance WHERE id = v_club.id;
    v_clubs_processed := v_clubs_processed + 1;
  END LOOP;

  RETURN jsonb_build_object('clubs_processed', v_clubs_processed);
END;
$function$;

-- Function to invest in a junior
CREATE OR REPLACE FUNCTION public.invest_in_junior(p_club_id uuid, p_junior_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid;
  v_balance bigint;
  v_new_balance bigint;
  v_club record;
  v_junior record;
  v_cost bigint := 15000; -- same cost as recruiting a junior
  v_game_week integer;
  v_improved boolean := false;
BEGIN
  SELECT * INTO v_club FROM public.clubs WHERE id = p_club_id FOR UPDATE;
  IF v_club IS NULL OR v_club.user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_junior FROM public.juniors WHERE id = p_junior_id AND club_id = p_club_id;
  IF v_junior IS NULL THEN
    RAISE EXCEPTION 'Junior not found';
  END IF;

  v_game_week := v_club.game_week;

  -- Check if already invested this week
  IF EXISTS (SELECT 1 FROM public.junior_investments WHERE junior_id = p_junior_id AND week_number = v_game_week) THEN
    RAISE EXCEPTION 'Já investiu neste júnior esta semana';
  END IF;

  IF v_club.balance < v_cost THEN
    RAISE EXCEPTION 'Sem fundos suficientes';
  END IF;

  v_new_balance := v_club.balance - v_cost;
  UPDATE public.clubs SET balance = v_new_balance WHERE id = p_club_id;

  -- Record investment
  INSERT INTO public.junior_investments (junior_id, club_id, week_number)
  VALUES (p_junior_id, p_club_id, v_game_week);

  -- 40% chance of improving quality by 1
  IF random() < 0.4 THEN
    UPDATE public.juniors SET quality = LEAST(quality + 1, 6) WHERE id = p_junior_id;
    v_improved := true;
  END IF;

  INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
  VALUES (p_club_id, -v_cost, v_new_balance, 'juniores', 'Investimento no júnior ' || v_junior.name);

  RETURN jsonb_build_object('improved', v_improved, 'cost', v_cost);
END;
$function$;
