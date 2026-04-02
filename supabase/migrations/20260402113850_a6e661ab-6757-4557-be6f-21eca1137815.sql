
-- 1. Unique club per user constraint
ALTER TABLE public.clubs ADD CONSTRAINT clubs_user_id_unique UNIQUE (user_id);

-- 2. Atomic patrimony upgrade function
CREATE OR REPLACE FUNCTION public.upgrade_patrimony(
  p_patrimony_id uuid,
  p_club_id uuid,
  p_cost bigint,
  p_build_weeks integer,
  p_new_level integer,
  p_new_maintenance bigint,
  p_description text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_balance bigint;
  v_new_balance bigint;
BEGIN
  -- Verify ownership
  SELECT user_id, balance INTO v_user_id, v_balance
  FROM public.clubs WHERE id = p_club_id FOR UPDATE;

  IF v_user_id IS NULL OR v_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF v_balance < p_cost THEN
    RAISE EXCEPTION 'Insufficient funds';
  END IF;

  v_new_balance := v_balance - p_cost;

  -- Deduct balance
  UPDATE public.clubs SET balance = v_new_balance WHERE id = p_club_id;

  -- Update patrimony
  UPDATE public.patrimony
  SET level = p_new_level,
      construction_weeks_remaining = p_build_weeks,
      maintenance_cost = p_new_maintenance
  WHERE id = p_patrimony_id AND club_id = p_club_id;

  -- Record transaction
  INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
  VALUES (p_club_id, -p_cost, v_new_balance, 'patrimonio', p_description);
END;
$$;

-- 3. Atomic loan function
CREATE OR REPLACE FUNCTION public.take_loan(
  p_club_id uuid,
  p_amount bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_balance bigint;
  v_new_balance bigint;
BEGIN
  SELECT user_id, balance INTO v_user_id, v_balance
  FROM public.clubs WHERE id = p_club_id FOR UPDATE;

  IF v_user_id IS NULL OR v_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF v_balance <= -10000000 THEN
    RAISE EXCEPTION 'Bankrupt';
  END IF;

  v_new_balance := v_balance + p_amount;

  UPDATE public.clubs SET balance = v_new_balance WHERE id = p_club_id;

  INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
  VALUES (p_club_id, p_amount, v_new_balance, 'emprestimo', 'Empréstimo bancário de R$ ' || p_amount);
END;
$$;

-- 4. Game loop processing function (called by edge function)
CREATE OR REPLACE FUNCTION public.process_game_week()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_club record;
  v_training record;
  v_player record;
  v_salary_total bigint;
  v_maintenance_total bigint;
  v_interest bigint;
  v_new_balance bigint;
  v_clubs_processed integer := 0;
BEGIN
  FOR v_club IN SELECT * FROM public.clubs FOR UPDATE LOOP
    v_new_balance := v_club.balance;

    -- 1. Decrement construction weeks
    UPDATE public.patrimony
    SET construction_weeks_remaining = GREATEST(0, construction_weeks_remaining - 1)
    WHERE club_id = v_club.id AND construction_weeks_remaining > 0;

    -- 2. Reveal juniors
    UPDATE public.juniors
    SET weeks_to_reveal = GREATEST(0, weeks_to_reveal - 1),
        revealed = CASE WHEN weeks_to_reveal <= 1 THEN true ELSE revealed END
    WHERE club_id = v_club.id AND revealed = false;

    -- 3. Calculate and charge salaries
    SELECT COALESCE(SUM(salary), 0) INTO v_salary_total
    FROM public.players WHERE club_id = v_club.id;

    v_new_balance := v_new_balance - v_salary_total;

    IF v_salary_total > 0 THEN
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_salary_total, v_new_balance, 'salarios', 'Pagamento semanal de salários');
    END IF;

    -- 4. Charge maintenance
    SELECT COALESCE(SUM(maintenance_cost), 0) INTO v_maintenance_total
    FROM public.patrimony WHERE club_id = v_club.id;

    v_new_balance := v_new_balance - v_maintenance_total;

    IF v_maintenance_total > 0 THEN
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_maintenance_total, v_new_balance, 'manutencao', 'Manutenção semanal do patrimônio');
    END IF;

    -- 5. Charge interest if in debt
    IF v_new_balance < 0 THEN
      v_interest := ABS(v_new_balance) * (5 + (ABS(v_new_balance) / 500000)) / 100;
      v_new_balance := v_new_balance - v_interest;

      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_interest, v_new_balance, 'juros', 'Juros sobre saldo devedor');
    END IF;

    -- 6. Apply training to players
    SELECT * INTO v_training FROM public.training_config WHERE club_id = v_club.id;

    IF v_training IS NOT NULL THEN
      -- Physical training for all players
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
        -- geral: random physical stat
        UPDATE public.players SET
          velocidade = CASE WHEN random() < 0.25 AND velocidade < potencial_velocidade THEN LEAST(velocidade + 1, potencial_velocidade) ELSE velocidade END,
          forca = CASE WHEN random() < 0.25 AND forca < potencial_forca THEN LEAST(forca + 1, potencial_forca) ELSE forca END,
          resistencia = CASE WHEN random() < 0.25 AND resistencia < potencial_resistencia THEN LEAST(resistencia + 1, potencial_resistencia) ELSE resistencia END,
          forma = CASE WHEN random() < 0.25 AND forma < potencial_forma THEN LEAST(forma + 1, potencial_forma) ELSE forma END
        WHERE club_id = v_club.id AND random() < (v_training.physical_intensity::float / 150.0);
      END IF;

      -- Injury risk from high intensity
      IF v_training.physical_intensity > 70 THEN
        UPDATE public.players
        SET is_injured = true, injury_weeks = 1 + floor(random() * 3)::int
        WHERE club_id = v_club.id AND is_injured = false
          AND random() < ((v_training.physical_intensity - 70)::float / 300.0);
      END IF;

      -- Heal injured players
      UPDATE public.players
      SET injury_weeks = GREATEST(0, injury_weeks - 1),
          is_injured = CASE WHEN injury_weeks <= 1 THEN false ELSE true END
      WHERE club_id = v_club.id AND is_injured = true;
    END IF;

    -- 7. Update club balance
    UPDATE public.clubs SET balance = v_new_balance WHERE id = v_club.id;

    v_clubs_processed := v_clubs_processed + 1;
  END LOOP;

  RETURN jsonb_build_object('clubs_processed', v_clubs_processed);
END;
$$;
