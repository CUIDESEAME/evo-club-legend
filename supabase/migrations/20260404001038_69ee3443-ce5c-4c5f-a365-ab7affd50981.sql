
-- Fix legacy juniors with age 15 → 16
UPDATE public.juniors SET age = 16 WHERE age < 16;

-- Update upgrade_patrimony to also scale stadium capacity
CREATE OR REPLACE FUNCTION public.upgrade_patrimony(p_patrimony_id uuid, p_club_id uuid, p_cost bigint, p_build_weeks integer, p_new_level integer, p_new_maintenance bigint, p_description text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid;
  v_balance bigint;
  v_new_balance bigint;
  v_pat_type text;
BEGIN
  SELECT user_id, balance INTO v_user_id, v_balance
  FROM public.clubs WHERE id = p_club_id FOR UPDATE;

  IF v_user_id IS NULL OR v_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF v_balance < p_cost THEN
    RAISE EXCEPTION 'Insufficient funds';
  END IF;

  v_new_balance := v_balance - p_cost;

  UPDATE public.clubs SET balance = v_new_balance WHERE id = p_club_id;

  SELECT type INTO v_pat_type FROM public.patrimony WHERE id = p_patrimony_id AND club_id = p_club_id;

  UPDATE public.patrimony
  SET level = p_new_level,
      construction_weeks_remaining = p_build_weeks,
      maintenance_cost = p_new_maintenance
  WHERE id = p_patrimony_id AND club_id = p_club_id;

  -- Stadium upgrade: scale all sector capacities
  IF v_pat_type = 'estadio' THEN
    UPDATE public.stadium_sectors
    SET capacity = 100 + (p_new_level * 150)
    WHERE club_id = p_club_id;
  END IF;

  INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
  VALUES (p_club_id, -p_cost, v_new_balance, 'patrimonio', p_description);
END;
$function$;

-- Remove socios_variacao noise (amount=0 transactions)
-- and update process_game_week to stop creating them
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

    UPDATE public.clubs SET game_week = v_new_week WHERE id = v_club.id;

    -- === CONSTRUCTION ===
    UPDATE public.patrimony
    SET construction_weeks_remaining = GREATEST(0, construction_weeks_remaining - 1)
    WHERE club_id = v_club.id AND construction_weeks_remaining > 0;

    -- === JUNIORS ===
    UPDATE public.juniors
    SET weeks_to_reveal = GREATEST(0, weeks_to_reveal - 1),
        revealed = CASE WHEN weeks_to_reveal <= 1 THEN true ELSE revealed END
    WHERE club_id = v_club.id AND revealed = false;

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

    -- === MEMBER FLUCTUATION ===
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

    v_league_bonus := CASE v_club.league
      WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3
      WHEN 'D' THEN 2 WHEN 'E' THEN 1 ELSE 0 END;

    v_member_change := (v_recent_wins * 3) - (v_recent_losses * 2) + v_league_bonus
      + (v_club.marketing_budget / 5000)::integer
      + floor(random() * 3)::integer - 1;

    v_new_members := GREATEST(0, v_club.members + v_member_change);
    UPDATE public.clubs SET members = v_new_members WHERE id = v_club.id;

    -- No longer log socios_variacao with amount=0

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

-- Clean up existing socios_variacao noise
DELETE FROM public.financial_transactions WHERE type = 'socios_variacao' AND amount = 0;
