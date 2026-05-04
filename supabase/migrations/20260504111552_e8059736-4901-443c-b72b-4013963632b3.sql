
-- ============ NOVOS SETORES DE PATRIMÔNIO ============
-- Adiciona linhas de patrimônio para clubes existentes
INSERT INTO public.patrimony (club_id, type, level, max_level, maintenance_cost, construction_weeks_remaining)
SELECT c.id, t.type, 0, 10, 0, 0
FROM public.clubs c
CROSS JOIN (VALUES ('psicologia'), ('escola'), ('funcionarios')) AS t(type)
WHERE NOT EXISTS (
  SELECT 1 FROM public.patrimony p WHERE p.club_id = c.id AND p.type = t.type
);

-- ============ TABELA DE COPAS ============
CREATE TABLE IF NOT EXISTS public.cups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  cup_type TEXT NOT NULL DEFAULT 'national', -- 'national' | 'u20'
  entry_fee BIGINT NOT NULL DEFAULT 50000,
  champion_prize BIGINT NOT NULL DEFAULT 1000000,
  runner_up_prize BIGINT NOT NULL DEFAULT 400000,
  semifinal_prize BIGINT NOT NULL DEFAULT 150000,
  status TEXT NOT NULL DEFAULT 'open', -- 'open' | 'in_progress' | 'finished'
  starts_at TIMESTAMPTZ NOT NULL DEFAULT now() + interval '2 days',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.cups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Cups viewable by everyone" ON public.cups FOR SELECT USING (true);

-- ============ INSCRIÇÕES EM COPAS ============
CREATE TABLE IF NOT EXISTS public.cup_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cup_id UUID NOT NULL REFERENCES public.cups(id) ON DELETE CASCADE,
  club_id UUID NOT NULL,
  status TEXT NOT NULL DEFAULT 'active', -- 'active' | 'eliminated' | 'champion' | 'runner_up'
  reached_phase TEXT,
  prize_received BIGINT NOT NULL DEFAULT 0,
  registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(cup_id, club_id)
);

ALTER TABLE public.cup_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Cup entries viewable by everyone" ON public.cup_entries FOR SELECT USING (true);
CREATE POLICY "Club owners can register" ON public.cup_entries FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM clubs WHERE clubs.id = cup_entries.club_id AND clubs.user_id = auth.uid()));

-- ============ EMPRÉSTIMOS ============
CREATE TABLE IF NOT EXISTS public.loans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL,
  principal BIGINT NOT NULL,
  interest_rate INTEGER NOT NULL DEFAULT 8, -- % per cycle
  total_weeks INTEGER NOT NULL DEFAULT 20,
  weekly_payment BIGINT NOT NULL,
  paid_amount BIGINT NOT NULL DEFAULT 0,
  remaining_weeks INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'active', -- 'active' | 'paid' | 'defaulted'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.loans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Loans viewable by club owner" ON public.loans FOR SELECT
  USING (EXISTS (SELECT 1 FROM clubs WHERE clubs.id = loans.club_id AND clubs.user_id = auth.uid()));

-- ============ FUNÇÃO: REQUEST LOAN ============
CREATE OR REPLACE FUNCTION public.request_loan(p_club_id UUID, p_amount BIGINT, p_weeks INTEGER)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club record;
  v_fund record;
  v_interest INTEGER := 8;
  v_total BIGINT;
  v_weekly BIGINT;
  v_loan_id UUID;
  v_new_balance BIGINT;
BEGIN
  SELECT * INTO v_club FROM clubs WHERE id = p_club_id FOR UPDATE;
  IF v_club IS NULL OR v_club.user_id != auth.uid() THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  IF p_amount < 50000 OR p_amount > 5000000 THEN RAISE EXCEPTION 'Valor entre R$50k e R$5M'; END IF;
  IF p_weeks < 5 OR p_weeks > 52 THEN RAISE EXCEPTION 'Prazo entre 5 e 52 semanas'; END IF;

  SELECT * INTO v_fund FROM system_funds WHERE fund_type = 'loan_system' FOR UPDATE;
  IF v_fund IS NULL OR v_fund.balance < p_amount THEN
    RAISE EXCEPTION 'Fundo de empréstimos sem recursos suficientes (disponível: R$%)', COALESCE(v_fund.balance, 0);
  END IF;

  -- Check existing active loans (max 2)
  IF (SELECT COUNT(*) FROM loans WHERE club_id = p_club_id AND status = 'active') >= 2 THEN
    RAISE EXCEPTION 'Limite de 2 empréstimos ativos atingido';
  END IF;

  v_total := p_amount + (p_amount * v_interest / 100);
  v_weekly := v_total / p_weeks;

  -- Take money from fund, give to club
  UPDATE system_funds SET balance = balance - p_amount WHERE fund_type = 'loan_system';
  v_new_balance := v_club.balance + p_amount;
  UPDATE clubs SET balance = v_new_balance WHERE id = p_club_id;

  INSERT INTO loans (club_id, principal, interest_rate, total_weeks, weekly_payment, remaining_weeks)
  VALUES (p_club_id, p_amount, v_interest, p_weeks, v_weekly, p_weeks)
  RETURNING id INTO v_loan_id;

  INSERT INTO financial_transactions (club_id, amount, balance_after, type, description)
  VALUES (p_club_id, p_amount, v_new_balance, 'emprestimo',
    'Empréstimo aprovado: R$' || p_amount || ' em ' || p_weeks || 'sem (juros ' || v_interest || '%)');

  RETURN jsonb_build_object('loan_id', v_loan_id, 'weekly_payment', v_weekly, 'total', v_total);
END; $$;

-- ============ FUNÇÃO: REPAY LOAN ============
CREATE OR REPLACE FUNCTION public.repay_loan(p_club_id UUID, p_loan_id UUID)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club record;
  v_loan record;
  v_remaining BIGINT;
  v_new_balance BIGINT;
BEGIN
  SELECT * INTO v_club FROM clubs WHERE id = p_club_id FOR UPDATE;
  IF v_club IS NULL OR v_club.user_id != auth.uid() THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT * INTO v_loan FROM loans WHERE id = p_loan_id AND club_id = p_club_id AND status = 'active' FOR UPDATE;
  IF v_loan IS NULL THEN RAISE EXCEPTION 'Empréstimo não encontrado'; END IF;

  v_remaining := v_loan.weekly_payment * v_loan.remaining_weeks;
  IF v_club.balance < v_remaining THEN RAISE EXCEPTION 'Sem fundos para quitar (precisa R$%)', v_remaining; END IF;

  v_new_balance := v_club.balance - v_remaining;
  UPDATE clubs SET balance = v_new_balance WHERE id = p_club_id;
  UPDATE system_funds SET balance = balance + v_remaining WHERE fund_type = 'loan_system';
  UPDATE loans SET status = 'paid', paid_amount = paid_amount + v_remaining, remaining_weeks = 0, updated_at = now()
    WHERE id = p_loan_id;

  INSERT INTO financial_transactions (club_id, amount, balance_after, type, description)
  VALUES (p_club_id, -v_remaining, v_new_balance, 'emprestimo', 'Quitação antecipada de empréstimo');

  RETURN jsonb_build_object('paid', v_remaining);
END; $$;

-- ============ FUNÇÃO: REGISTER CUP ============
CREATE OR REPLACE FUNCTION public.register_cup(p_club_id UUID, p_cup_id UUID)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_club record;
  v_cup record;
  v_new_balance BIGINT;
BEGIN
  SELECT * INTO v_club FROM clubs WHERE id = p_club_id FOR UPDATE;
  IF v_club IS NULL OR v_club.user_id != auth.uid() THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT * INTO v_cup FROM cups WHERE id = p_cup_id AND status = 'open';
  IF v_cup IS NULL THEN RAISE EXCEPTION 'Copa não disponível'; END IF;

  IF EXISTS (SELECT 1 FROM cup_entries WHERE cup_id = p_cup_id AND club_id = p_club_id) THEN
    RAISE EXCEPTION 'Já inscrito nesta copa';
  END IF;

  IF v_club.balance < v_cup.entry_fee THEN RAISE EXCEPTION 'Sem fundos para inscrição'; END IF;

  v_new_balance := v_club.balance - v_cup.entry_fee;
  UPDATE clubs SET balance = v_new_balance WHERE id = p_club_id;

  INSERT INTO cup_entries (cup_id, club_id) VALUES (p_cup_id, p_club_id);

  -- Entry fee goes to prize reserve
  UPDATE system_funds SET balance = balance + v_cup.entry_fee WHERE fund_type = 'prize_reserve';

  INSERT INTO financial_transactions (club_id, amount, balance_after, type, description)
  VALUES (p_club_id, -v_cup.entry_fee, v_new_balance, 'copa', 'Inscrição: ' || v_cup.name);

  RETURN jsonb_build_object('registered', true);
END; $$;

-- ============ ATUALIZA finalize_auctions COM SOLIDARIEDADE ============
CREATE OR REPLACE FUNCTION public.finalize_auctions()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_listing record;
  v_player record;
  v_total_fee BIGINT;
  v_seller_receives BIGINT;
  v_market_fee BIGINT;
  v_prize_fee BIGINT;
  v_loan_fee BIGINT;
  v_solidarity_fee BIGINT;
  v_buyer_balance BIGINT;
  v_seller_balance BIGINT;
  v_finalized INTEGER := 0;
BEGIN
  FOR v_listing IN SELECT * FROM market_open WHERE status = 'active' AND ends_at <= now() FOR UPDATE LOOP
    IF v_listing.current_bid > 0 AND v_listing.current_bidder_club_id IS NOT NULL THEN
      SELECT * INTO v_player FROM players WHERE id = v_listing.player_id;

      v_market_fee := v_listing.current_bid * 10 / 100;
      v_prize_fee := v_listing.current_bid * 5 / 100;
      v_loan_fee := v_listing.current_bid * 5 / 100;
      -- Solidarity: 5% extra if player <= 23
      v_solidarity_fee := CASE WHEN v_player.age <= 23 THEN v_listing.current_bid * 5 / 100 ELSE 0 END;
      v_total_fee := v_market_fee + v_prize_fee + v_loan_fee + v_solidarity_fee;
      v_seller_receives := v_listing.current_bid - v_total_fee;

      UPDATE clubs SET balance = balance - v_listing.current_bid WHERE id = v_listing.current_bidder_club_id;
      SELECT balance INTO v_buyer_balance FROM clubs WHERE id = v_listing.current_bidder_club_id;
      INSERT INTO financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_listing.current_bidder_club_id, -v_listing.current_bid, v_buyer_balance, 'mercado',
        'Compra leilão: ' || v_player.name);

      UPDATE clubs SET balance = balance + v_seller_receives WHERE id = v_listing.seller_club_id;
      SELECT balance INTO v_seller_balance FROM clubs WHERE id = v_listing.seller_club_id;
      INSERT INTO financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_listing.seller_club_id, v_seller_receives, v_seller_balance, 'mercado',
        'Venda leilão (-' || (v_total_fee * 100 / v_listing.current_bid) || '% taxas): ' || v_player.name);

      UPDATE players SET club_id = v_listing.current_bidder_club_id, is_for_sale = false, entrosamento = 0
        WHERE id = v_listing.player_id;

      UPDATE system_funds SET balance = balance + v_prize_fee + v_solidarity_fee WHERE fund_type = 'prize_reserve';
      UPDATE system_funds SET balance = balance + v_loan_fee WHERE fund_type = 'loan_system';

      UPDATE market_open SET status = 'sold' WHERE id = v_listing.id;
    ELSE
      UPDATE players SET is_for_sale = false WHERE id = v_listing.player_id;
      UPDATE market_open SET status = 'expired' WHERE id = v_listing.id;
    END IF;
    v_finalized := v_finalized + 1;
  END LOOP;
  RETURN jsonb_build_object('finalized', v_finalized);
END; $$;

-- ============ ATUALIZA process_game_week PARA COBRAR PARCELAS DE EMPRÉSTIMOS + EFEITOS DOS NOVOS SETORES ============
CREATE OR REPLACE FUNCTION public.process_game_week()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
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
BEGIN
  FOR v_club IN SELECT * FROM public.clubs FOR UPDATE LOOP
    v_new_balance := v_club.balance;
    v_new_week := v_club.game_week + 1;
    UPDATE public.clubs SET game_week = v_new_week WHERE id = v_club.id;

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

    -- MAINTENANCE
    SELECT COALESCE(SUM(maintenance_cost), 0) INTO v_maintenance_total FROM public.patrimony WHERE club_id = v_club.id;
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

    -- Funcionários: salário extra (R$3000/nível)
    v_func_cost := v_func_level * 3000;
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

    -- Junior maintenance
    SELECT COALESCE(COUNT(*), 0) * 2000 INTO v_junior_cost FROM public.juniors WHERE club_id = v_club.id;
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

      -- Heal (faster with funcionarios)
      UPDATE public.players SET injury_weeks = GREATEST(0, injury_weeks - 1 - (v_func_level / 4)),
          is_injured = CASE WHEN injury_weeks <= 1 THEN false ELSE true END
        WHERE club_id = v_club.id AND is_injured = true;
    END IF;

    UPDATE public.players SET fadiga = GREATEST(0, fadiga - 10) WHERE club_id = v_club.id;
    UPDATE public.players SET entrosamento = GREATEST(0, entrosamento - 5) WHERE club_id = v_club.id;

    -- Office expenses
    v_new_balance := v_new_balance - 2000;
    INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
    VALUES (v_club.id, -2000, v_new_balance, 'despesas', 'Despesas administrativas');

    UPDATE public.clubs SET balance = v_new_balance WHERE id = v_club.id;
    v_clubs_processed := v_clubs_processed + 1;
  END LOOP;

  RETURN jsonb_build_object('clubs_processed', v_clubs_processed);
END; $$;

-- ============ SEED DUAS COPAS INICIAIS ============
INSERT INTO public.cups (name, cup_type, entry_fee, champion_prize, runner_up_prize, semifinal_prize)
VALUES
  ('Copa Nacional 2026', 'national', 50000, 1000000, 400000, 150000),
  ('Copa U20 Juniores', 'u20', 20000, 300000, 120000, 50000)
ON CONFLICT DO NOTHING;
