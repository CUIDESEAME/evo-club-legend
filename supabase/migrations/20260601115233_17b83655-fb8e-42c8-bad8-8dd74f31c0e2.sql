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
  v_store_level integer;
  v_social_level integer;
  v_marketing_level integer;
  v_psico_level integer;
  v_escola_level integer;
  v_func_level integer;
  v_store_revenue bigint;
  v_social_revenue bigint;
  v_marketing_revenue bigint;
  v_ct_level integer;
  v_junior_cost bigint;
  v_loan record;
  v_loan_payment bigint;
  v_func_cost bigint;
  v_inflation_factor numeric;
  v_wealth_surcharge bigint;
BEGIN
  FOR v_club IN SELECT * FROM public.clubs FOR UPDATE LOOP
    v_new_balance := v_club.balance;
    v_new_week := v_club.game_week + 1;
    UPDATE public.clubs SET game_week = v_new_week WHERE id = v_club.id;

    -- Inflation grows ~2% per week, capped at 4x
    v_inflation_factor := LEAST(1.0 + (v_new_week::numeric * 0.02), 4.0);

    UPDATE public.patrimony SET construction_weeks_remaining = GREATEST(0, construction_weeks_remaining - 1)
      WHERE club_id = v_club.id AND construction_weeks_remaining > 0;

    UPDATE public.juniors
      SET weeks_to_reveal = GREATEST(0, weeks_to_reveal - 1),
          revealed = CASE WHEN weeks_to_reveal <= 1 THEN true ELSE revealed END
      WHERE club_id = v_club.id AND revealed = false;
    UPDATE public.juniors SET quality = LEAST(quality + 1, 6)
      WHERE club_id = v_club.id AND revealed = false AND random() < 0.15;

    -- SALARIES
    SELECT COALESCE(SUM(salary), 0) INTO v_salary_total FROM public.players WHERE club_id = v_club.id;
    v_new_balance := v_new_balance - v_salary_total;
    IF v_salary_total > 0 THEN
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_salary_total, v_new_balance, 'salarios', 'Salários semanais');
    END IF;

    -- MAINTENANCE (inflated)
    SELECT COALESCE(SUM(maintenance_cost), 0) INTO v_maintenance_total FROM public.patrimony WHERE club_id = v_club.id;
    v_maintenance_total := (v_maintenance_total * v_inflation_factor)::bigint;
    v_new_balance := v_new_balance - v_maintenance_total;
    IF v_maintenance_total > 0 THEN
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_maintenance_total, v_new_balance, 'manutencao', 'Manutenção patrimônio');
    END IF;

    -- PATRIMONY REVENUE
    SELECT COALESCE(level, 0) INTO v_store_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'lojas' AND construction_weeks_remaining = 0;
    v_store_revenue := COALESCE(v_store_level, 0) * 5000 + COALESCE(v_store_level, 0) * v_club.members * 2;
    IF v_store_revenue > 0 THEN
      v_new_balance := v_new_balance + v_store_revenue;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, v_store_revenue, v_new_balance, 'lojas', 'Receita lojas');
    END IF;

    SELECT COALESCE(level, 0) INTO v_social_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'clube_social' AND construction_weeks_remaining = 0;
    v_social_revenue := COALESCE(v_social_level, 0) * 3000 + COALESCE(v_social_level, 0) * v_club.members * 5;
    IF v_social_revenue > 0 THEN
      v_new_balance := v_new_balance + v_social_revenue;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, v_social_revenue, v_new_balance, 'clube_social', 'Receita clube social');
    END IF;

    SELECT COALESCE(level, 0) INTO v_marketing_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'marketing' AND construction_weeks_remaining = 0;
    v_marketing_revenue := COALESCE(v_marketing_level, 0) * 8000;
    IF v_marketing_revenue > 0 THEN
      v_new_balance := v_new_balance + v_marketing_revenue;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, v_marketing_revenue, v_new_balance, 'patrocinio', 'Patrocínio marketing');
    END IF;

    -- NEW SECTORS COSTS & EFFECTS
    SELECT COALESCE(level, 0) INTO v_psico_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'psicologia' AND construction_weeks_remaining = 0;
    SELECT COALESCE(level, 0) INTO v_escola_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'escola' AND construction_weeks_remaining = 0;
    SELECT COALESCE(level, 0) INTO v_func_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'funcionarios' AND construction_weeks_remaining = 0;

    -- Funcionários: salário extra (R$3000/nível, inflated)
    v_func_cost := (v_func_level * 3000 * v_inflation_factor)::bigint;
    IF v_func_cost > 0 THEN
      v_new_balance := v_new_balance - v_func_cost;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_func_cost, v_new_balance, 'staff', 'Salário funcionários (Nv ' || v_func_level || ')');
    END IF;

    -- Psicologia: reduz agressividade
    IF v_psico_level > 0 THEN
      UPDATE public.players SET agressividade = GREATEST(1, agressividade - 1)
        WHERE club_id = v_club.id AND agressividade > 1 AND random() < (v_psico_level::float / 20.0);
    END IF;

    -- Escola: aumenta inteligência
    IF v_escola_level > 0 THEN
      UPDATE public.players SET inteligencia = LEAST(16, inteligencia + 1)
        WHERE club_id = v_club.id AND inteligencia < 16 AND random() < (v_escola_level::float / 20.0);
    END IF;

    -- Marketing
    v_marketing_cost := v_club.marketing_budget;
    IF v_marketing_cost > 0 THEN
      v_new_balance := v_new_balance - v_marketing_cost;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_marketing_cost, v_new_balance, 'marketing', 'Investimento marketing');
    END IF;

    v_member_revenue := v_club.members * 100;
    IF v_member_revenue > 0 THEN
      v_new_balance := v_new_balance + v_member_revenue;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, v_member_revenue, v_new_balance, 'socios', 'Sócios (' || v_club.members || ')');
    END IF;

    -- Member fluctuation
    SELECT COALESCE(SUM(CASE WHEN (m.home_club_id = v_club.id AND m.home_score > m.away_score) OR (m.away_club_id = v_club.id AND m.away_score > m.home_score) THEN 1 ELSE 0 END), 0),
      COALESCE(SUM(CASE WHEN (m.home_club_id = v_club.id AND m.home_score < m.away_score) OR (m.away_club_id = v_club.id AND m.away_score < m.home_score) THEN 1 ELSE 0 END), 0)
    INTO v_recent_wins, v_recent_losses
    FROM (SELECT * FROM public.matches WHERE (home_club_id = v_club.id OR away_club_id = v_club.id) AND status = 'played' ORDER BY played_at DESC LIMIT 5) m;

    v_league_bonus := CASE v_club.league WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3 WHEN 'D' THEN 2 WHEN 'E' THEN 1 ELSE 0 END;
    v_member_change := (v_recent_wins * 3) - (v_recent_losses * 2) + v_league_bonus + (v_club.marketing_budget / 5000)::integer + COALESCE(v_marketing_level, 0) * 2 + floor(random() * 3)::integer - 1;
    v_new_members := GREATEST(0, v_club.members + v_member_change);

    UPDATE public.clubs SET members = v_new_members, fans = GREATEST(fans + v_member_change * 5 + COALESCE(v_marketing_level, 0) * 10, 100) WHERE id = v_club.id;

    -- Junior maintenance (inflated)
    SELECT COALESCE(COUNT(*), 0) * 2000 INTO v_junior_cost FROM public.juniors WHERE club_id = v_club.id;
    v_junior_cost := (v_junior_cost * v_inflation_factor)::bigint;
    IF v_junior_cost > 0 THEN
      v_new_balance := v_new_balance - v_junior_cost;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_junior_cost, v_new_balance, 'juniores', 'Manutenção juniores');
    END IF;

    -- LOAN PAYMENTS
    FOR v_loan IN SELECT * FROM loans WHERE club_id = v_club.id AND status = 'active' FOR UPDATE LOOP
      v_loan_payment := v_loan.weekly_payment;
      v_new_balance := v_new_balance - v_loan_payment;
      INSERT INTO financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_loan_payment, v_new_balance, 'emprestimo', 'Parcela empréstimo (' || (v_loan.remaining_weeks - 1) || ' restantes)');

      UPDATE system_funds SET balance = balance + v_loan_payment WHERE fund_type = 'loan_system';

      UPDATE loans SET
        paid_amount = paid_amount + v_loan_payment,
        remaining_weeks = remaining_weeks - 1,
        status = CASE WHEN remaining_weeks - 1 <= 0 THEN 'paid' ELSE 'active' END,
        updated_at = now()
      WHERE id = v_loan.id;
    END LOOP;

    -- WEALTH TAX: drains excess capital to prevent billionaire clubs
    v_wealth_surcharge := 0;
    IF v_new_balance > 200000000 THEN
      v_wealth_surcharge := ((v_new_balance - 200000000) * 0.15)::bigint
                          + (150000000 * 0.08)::bigint
                          + (45000000 * 0.03)::bigint;
    ELSIF v_new_balance > 50000000 THEN
      v_wealth_surcharge := ((v_new_balance - 50000000) * 0.08)::bigint
                          + (45000000 * 0.03)::bigint;
    ELSIF v_new_balance > 5000000 THEN
      v_wealth_surcharge := ((v_new_balance - 5000000) * 0.03)::bigint;
    END IF;
    IF v_wealth_surcharge > 0 THEN
      v_new_balance := v_new_balance - v_wealth_surcharge;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_wealth_surcharge, v_new_balance, 'imposto', 'Imposto sobre patrimônio (anti-inflação)');
    END IF;

    -- Interest on overdraft
    IF v_new_balance < 0 THEN
      v_interest_rate := LEAST(5 + (ABS(v_new_balance) / 500000)::integer, 20);
      v_interest := ABS(v_new_balance) * v_interest_rate / 100;
      v_interest := LEAST(v_interest, 500000);
      v_new_balance := v_new_balance - v_interest;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_interest, v_new_balance, 'juros', 'Juros saldo devedor (' || v_interest_rate || '%)');
    END IF;

    -- TRAINING (boosted by funcionarios level)
    SELECT * INTO v_training FROM public.training_config WHERE club_id = v_club.id;
    IF v_training IS NOT NULL THEN
      SELECT COALESCE(level, 0) INTO v_ct_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'ct' AND construction_weeks_remaining = 0;
      IF v_training.physical_type = 'forca' THEN
        UPDATE public.players SET forca = LEAST(forca + 1, potencial_forca)
          WHERE club_id = v_club.id AND forca < potencial_forca AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct_level, 0) * 5 + v_func_level * 3) / 150.0);
      ELSIF v_training.physical_type = 'velocidade' THEN
        UPDATE public.players SET velocidade = LEAST(velocidade + 1, potencial_velocidade)
          WHERE club_id = v_club.id AND velocidade < potencial_velocidade AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct_level, 0) * 5 + v_func_level * 3) / 150.0);
      ELSIF v_training.physical_type = 'resistencia' THEN
        UPDATE public.players SET resistencia = LEAST(resistencia + 1, potencial_resistencia)
          WHERE club_id = v_club.id AND resistencia < potencial_resistencia AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct_level, 0) * 5 + v_func_level * 3) / 150.0);
      ELSIF v_training.physical_type = 'forma' THEN
        UPDATE public.players SET forma = LEAST(forma + 1, potencial_forma)
          WHERE club_id = v_club.id AND forma < potencial_forma AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct_level, 0) * 5 + v_func_level * 3) / 150.0);
      END IF;

      IF v_training.physical_intensity > 70 THEN
        UPDATE public.players SET is_injured = true, injury_weeks = GREATEST(1, (1 + floor(random() * 3)::int) - v_func_level / 3)
          WHERE club_id = v_club.id AND is_injured = false AND random() < ((v_training.physical_intensity - 70)::float / 300.0);
      END IF;

      UPDATE public.players SET injury_weeks = GREATEST(0, injury_weeks - 1 - (v_func_level / 4)),
          is_injured = CASE WHEN injury_weeks <= 1 THEN false ELSE true END
        WHERE club_id = v_club.id AND is_injured = true;
    END IF;

    UPDATE public.players SET fadiga = GREATEST(0, fadiga - 10) WHERE club_id = v_club.id;
    UPDATE public.players SET entrosamento = GREATEST(0, entrosamento - 5) WHERE club_id = v_club.id;

    -- Office expenses (inflated)
    v_new_balance := v_new_balance - (2000 * v_inflation_factor)::bigint;
    INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
    VALUES (v_club.id, -(2000 * v_inflation_factor)::bigint, v_new_balance, 'despesas', 'Despesas administrativas');

    UPDATE public.clubs SET balance = v_new_balance WHERE id = v_club.id;
    v_clubs_processed := v_clubs_processed + 1;
  END LOOP;

  RETURN jsonb_build_object('clubs_processed', v_clubs_processed);
END; $function$;