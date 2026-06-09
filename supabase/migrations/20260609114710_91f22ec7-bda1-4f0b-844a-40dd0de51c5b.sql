CREATE OR REPLACE FUNCTION public.process_game_week()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_club record;
  v_training record;
  v_week integer;
  v_balance bigint;
  v_salary bigint;
  v_maintenance bigint;
  v_marketing bigint;
  v_member_income bigint;
  v_member_delta integer;
  v_wins integer;
  v_losses integer;
  v_store integer;
  v_social integer;
  v_marketing_level integer;
  v_staff integer;
  v_school integer;
  v_psy integer;
  v_ct integer;
  v_revenue bigint;
  v_junior_cost bigint;
  v_loan record;
  v_tax bigint;
  v_interest bigint;
  v_inflation numeric;
  v_processed integer := 0;
BEGIN
  FOR v_club IN SELECT * FROM public.clubs FOR UPDATE LOOP
    v_week := COALESCE(v_club.game_week, 0) + 1;
    v_balance := COALESCE(v_club.balance, 0);
    v_inflation := LEAST(1.0 + (v_week::numeric * 0.01), 2.0);

    UPDATE public.clubs SET game_week = v_week WHERE id = v_club.id;

    UPDATE public.patrimony
      SET construction_weeks_remaining = GREATEST(0, construction_weeks_remaining - 1)
      WHERE club_id = v_club.id AND construction_weeks_remaining > 0;

    UPDATE public.juniors
      SET weeks_to_reveal = GREATEST(0, weeks_to_reveal - 1),
          revealed = CASE WHEN weeks_to_reveal <= 1 THEN true ELSE revealed END
      WHERE club_id = v_club.id AND revealed = false;

    SELECT COALESCE(SUM(salary), 0) INTO v_salary FROM public.players WHERE club_id = v_club.id;
    v_balance := v_balance - v_salary;
    IF v_salary > 0 THEN
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_salary, v_balance, 'salarios', 'Salários semanais');
    END IF;

    SELECT COALESCE(SUM(maintenance_cost), 0) INTO v_maintenance FROM public.patrimony WHERE club_id = v_club.id;
    v_maintenance := (v_maintenance * v_inflation)::bigint;
    v_balance := v_balance - v_maintenance;
    IF v_maintenance > 0 THEN
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_maintenance, v_balance, 'manutencao', 'Manutenção patrimônio');
    END IF;

    SELECT COALESCE(level, 0) INTO v_store FROM public.patrimony WHERE club_id = v_club.id AND type = 'lojas' AND construction_weeks_remaining = 0;
    SELECT COALESCE(level, 0) INTO v_social FROM public.patrimony WHERE club_id = v_club.id AND type = 'clube_social' AND construction_weeks_remaining = 0;
    SELECT COALESCE(level, 0) INTO v_marketing_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'marketing' AND construction_weeks_remaining = 0;
    SELECT COALESCE(level, 0) INTO v_staff FROM public.patrimony WHERE club_id = v_club.id AND type = 'funcionarios' AND construction_weeks_remaining = 0;
    SELECT COALESCE(level, 0) INTO v_school FROM public.patrimony WHERE club_id = v_club.id AND type = 'escola' AND construction_weeks_remaining = 0;
    SELECT COALESCE(level, 0) INTO v_psy FROM public.patrimony WHERE club_id = v_club.id AND type = 'psicologia' AND construction_weeks_remaining = 0;
    SELECT COALESCE(level, 0) INTO v_ct FROM public.patrimony WHERE club_id = v_club.id AND type = 'ct' AND construction_weeks_remaining = 0;

    v_revenue := (COALESCE(v_store,0) * 2500)
               + (COALESCE(v_social,0) * 1500)
               + (COALESCE(v_marketing_level,0) * 3000)
               + (COALESCE(v_store,0) * LEAST(COALESCE(v_club.members,0), 2500))
               + (COALESCE(v_social,0) * LEAST(COALESCE(v_club.members,0), 2500) * 2);
    IF v_revenue > 0 THEN
      v_balance := v_balance + v_revenue;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, v_revenue, v_balance, 'patrimonio', 'Receita patrimônio');
    END IF;

    IF COALESCE(v_staff, 0) > 0 THEN
      v_balance := v_balance - (v_staff * 4500 * v_inflation)::bigint;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -(v_staff * 4500 * v_inflation)::bigint, v_balance, 'staff', 'Salário funcionários');
    END IF;

    v_marketing := LEAST(COALESCE(v_club.marketing_budget, 0), 50000);
    IF COALESCE(v_club.marketing_budget, 0) <> v_marketing THEN
      UPDATE public.clubs SET marketing_budget = v_marketing WHERE id = v_club.id;
    END IF;
    IF v_marketing > 0 THEN
      v_balance := v_balance - v_marketing;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_marketing, v_balance, 'marketing', 'Investimento marketing');
    END IF;

    v_member_income := LEAST(COALESCE(v_club.members, 0), 30000) * 35;
    IF v_member_income > 0 THEN
      v_balance := v_balance + v_member_income;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, v_member_income, v_balance, 'socios', 'Sócios (' || v_club.members || ')');
    END IF;

    SELECT COALESCE(SUM(CASE WHEN (home_club_id = v_club.id AND home_score > away_score) OR (away_club_id = v_club.id AND away_score > home_score) THEN 1 ELSE 0 END), 0),
           COALESCE(SUM(CASE WHEN (home_club_id = v_club.id AND home_score < away_score) OR (away_club_id = v_club.id AND away_score < home_score) THEN 1 ELSE 0 END), 0)
      INTO v_wins, v_losses
    FROM (SELECT * FROM public.matches WHERE (home_club_id = v_club.id OR away_club_id = v_club.id) AND status = 'played' ORDER BY played_at DESC LIMIT 5) recent;

    v_member_delta := LEAST(12, GREATEST(-10,
      (v_wins * 2) - (v_losses * 2)
      + CASE v_club.league WHEN 'A' THEN 4 WHEN 'B' THEN 3 WHEN 'C' THEN 2 WHEN 'D' THEN 1 ELSE 0 END
      + (v_marketing / 10000)::integer
      + COALESCE(v_marketing_level, 0)
      + floor(random() * 3)::integer - 1
    ));

    UPDATE public.clubs
      SET members = GREATEST(50, LEAST(30000, COALESCE(members, 50) + v_member_delta)),
          fans = GREATEST(100, LEAST(500000, COALESCE(fans, 100) + v_member_delta * 3 + COALESCE(v_marketing_level, 0) * 5))
      WHERE id = v_club.id;

    SELECT COALESCE(COUNT(*), 0) * 2500 INTO v_junior_cost FROM public.juniors WHERE club_id = v_club.id;
    v_junior_cost := (v_junior_cost * v_inflation)::bigint;
    IF v_junior_cost > 0 THEN
      v_balance := v_balance - v_junior_cost;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_junior_cost, v_balance, 'juniores', 'Manutenção juniores');
    END IF;

    FOR v_loan IN SELECT * FROM public.loans WHERE club_id = v_club.id AND status = 'active' FOR UPDATE LOOP
      v_balance := v_balance - v_loan.weekly_payment;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_loan.weekly_payment, v_balance, 'emprestimo', 'Parcela empréstimo');
      UPDATE public.system_funds SET balance = balance + v_loan.weekly_payment WHERE fund_type = 'loan_system';
      UPDATE public.loans
        SET paid_amount = paid_amount + v_loan.weekly_payment,
            remaining_weeks = remaining_weeks - 1,
            status = CASE WHEN remaining_weeks - 1 <= 0 THEN 'paid' ELSE 'active' END,
            updated_at = now()
        WHERE id = v_loan.id;
    END LOOP;

    IF v_balance > 10000000 THEN
      v_tax := ((v_balance - 10000000) * 0.025)::bigint;
      v_balance := v_balance - v_tax;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_tax, v_balance, 'custos', 'Custo de capital e gestão');
    END IF;
    IF v_balance > 5000000 THEN
      v_tax := ((v_balance - 5000000) * 0.05)::bigint;
      v_balance := v_balance - v_tax;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_tax, v_balance, 'imposto', 'Imposto progressivo anti-acúmulo');
    END IF;
    IF v_balance < 0 THEN
      v_interest := LEAST(ABS(v_balance) * LEAST(6 + (ABS(v_balance) / 500000)::integer, 22) / 100, 750000);
      v_balance := v_balance - v_interest;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_interest, v_balance, 'juros', 'Juros saldo devedor');
    END IF;

    SELECT * INTO v_training FROM public.training_config WHERE club_id = v_club.id;
    IF v_training IS NOT NULL THEN
      IF v_training.physical_type = 'forca' THEN
        UPDATE public.players SET forca = LEAST(forca + 1, potencial_forca, 9) WHERE club_id = v_club.id AND forca < LEAST(potencial_forca, 9) AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct,0) * 4 + COALESCE(v_staff,0) * 2) / 190.0);
      ELSIF v_training.physical_type = 'velocidade' THEN
        UPDATE public.players SET velocidade = LEAST(velocidade + 1, potencial_velocidade, 9) WHERE club_id = v_club.id AND velocidade < LEAST(potencial_velocidade, 9) AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct,0) * 4 + COALESCE(v_staff,0) * 2) / 190.0);
      ELSIF v_training.physical_type = 'resistencia' THEN
        UPDATE public.players SET resistencia = LEAST(resistencia + 1, potencial_resistencia, 9) WHERE club_id = v_club.id AND resistencia < LEAST(potencial_resistencia, 9) AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct,0) * 4 + COALESCE(v_staff,0) * 2) / 190.0);
      ELSIF v_training.physical_type = 'forma' THEN
        UPDATE public.players SET forma = LEAST(forma + 1, potencial_forma, 9) WHERE club_id = v_club.id AND forma < LEAST(potencial_forma, 9) AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct,0) * 4 + COALESCE(v_staff,0) * 2) / 190.0);
      END IF;

      IF v_training.physical_intensity > 70 THEN
        UPDATE public.players SET is_injured = true, injury_weeks = GREATEST(1, (1 + floor(random() * 3)::int) - COALESCE(v_staff,0) / 4)
        WHERE club_id = v_club.id AND is_injured = false AND random() < ((v_training.physical_intensity - 70)::float / 260.0);
      END IF;
    END IF;

    IF COALESCE(v_school,0) > 0 THEN
      UPDATE public.players SET inteligencia = LEAST(5, inteligencia + 1) WHERE club_id = v_club.id AND inteligencia < 5 AND random() < (v_school::float / 35.0);
    END IF;
    IF COALESCE(v_psy,0) > 0 THEN
      UPDATE public.players SET agressividade = GREATEST(1, agressividade - 1) WHERE club_id = v_club.id AND agressividade > 1 AND random() < (v_psy::float / 35.0);
    END IF;

    UPDATE public.players SET injury_weeks = GREATEST(0, injury_weeks - 1 - (COALESCE(v_staff,0) / 5)), is_injured = CASE WHEN injury_weeks <= 1 THEN false ELSE true END WHERE club_id = v_club.id AND is_injured = true;
    UPDATE public.players SET fadiga = GREATEST(0, fadiga - 10), entrosamento = GREATEST(0, entrosamento - 3) WHERE club_id = v_club.id;

    v_balance := v_balance - (3000 * v_inflation)::bigint;
    INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
    VALUES (v_club.id, -(3000 * v_inflation)::bigint, v_balance, 'despesas', 'Despesas administrativas');

    UPDATE public.clubs SET balance = v_balance WHERE id = v_club.id;
    v_processed := v_processed + 1;
  END LOOP;

  RETURN jsonb_build_object('clubs_processed', v_processed);
END;
$function$;