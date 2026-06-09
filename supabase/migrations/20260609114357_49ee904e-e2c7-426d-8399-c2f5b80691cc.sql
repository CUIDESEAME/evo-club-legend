CREATE OR REPLACE FUNCTION public.build_division_season(p_league text, p_division integer, p_clubs uuid[])
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_size integer := 12;
  v_cities text[] := ARRAY['Toquio','Madri','Londres','Paris','Berlim','Roma','Lisboa','Cairo','Lima','Oslo','Doha','Seul','Quito','Acra','Dacar','Hanoi','Kyoto','Milao','Porto','Bogota','Atenas','Praga','Viena','Dublin','Nairobi','Baku','Manila','Tunes','Amsterda','Bruxelas','Helsinque','Varsovia','Bangcoc','Caracas','Montreal','Boston','Denver','Dallas','Calgari','Bremen'];
  v_season_id uuid;
  v_season_num integer;
  v_slots text[] := '{}';
  v_npc_id uuid;
  v_city text;
  v_offset integer;
  v_i integer; v_n integer; v_round integer; v_leg integer;
  v_arr text[]; v_tmp text; v_home text; v_away text;
  v_hc uuid; v_ac uuid; v_hn uuid; v_an uuid; v_rnum integer := 0;
  v_cid uuid;
BEGIN
  SELECT COALESCE(MAX(season_number),0)+1 INTO v_season_num FROM public.seasons;

  INSERT INTO public.seasons (league, division, season_number, total_rounds, current_round, status)
  VALUES (p_league, p_division, v_season_num, 2*(v_size-1), 1, 'active')
  RETURNING id INTO v_season_id;

  IF p_clubs IS NOT NULL THEN
    FOREACH v_cid IN ARRAY p_clubs LOOP
      UPDATE public.clubs SET league = p_league, division = p_division WHERE id = v_cid;
      v_slots := array_append(v_slots, 'C:' || v_cid::text);
      INSERT INTO public.league_standings (season_id, club_id) VALUES (v_season_id, v_cid);
    END LOOP;
  END IF;

  v_offset := floor(random() * array_length(v_cities,1))::int;
  WHILE COALESCE(array_length(v_slots,1),0) < v_size LOOP
    v_city := v_cities[1 + ((v_offset + COALESCE(array_length(v_slots,1),0)) % array_length(v_cities,1))];
    INSERT INTO public.npc_clubs (name, abbreviation, league, division, strength, fan_base, season_id)
    VALUES (v_city, UPPER(LEFT(v_city,3)), p_league, p_division, 22 + floor(random()*11)::int, 100, v_season_id)
    RETURNING id INTO v_npc_id;
    v_slots := array_append(v_slots, 'N:' || v_npc_id::text);
    INSERT INTO public.league_standings (season_id, npc_club_id) VALUES (v_season_id, v_npc_id);
  END LOOP;

  v_n := array_length(v_slots,1);
  FOR v_leg IN 1..2 LOOP
    v_arr := v_slots;
    FOR v_round IN 1..(v_n-1) LOOP
      v_rnum := v_rnum + 1;
      FOR v_i IN 1..(v_n/2) LOOP
        v_home := v_arr[v_i];
        v_away := v_arr[v_n+1-v_i];
        IF (v_round+v_i)%2 = 0 THEN v_tmp:=v_home; v_home:=v_away; v_away:=v_tmp; END IF;
        IF v_leg = 2 THEN v_tmp:=v_home; v_home:=v_away; v_away:=v_tmp; END IF;
        v_hc:=NULL; v_ac:=NULL; v_hn:=NULL; v_an:=NULL;
        IF left(v_home,2)='C:' THEN v_hc:=substr(v_home,3)::uuid; ELSE v_hn:=substr(v_home,3)::uuid; END IF;
        IF left(v_away,2)='C:' THEN v_ac:=substr(v_away,3)::uuid; ELSE v_an:=substr(v_away,3)::uuid; END IF;
        INSERT INTO public.matches (season_id, round, home_club_id, away_club_id, home_npc_id, away_npc_id, status)
        VALUES (v_season_id, v_rnum, v_hc, v_ac, v_hn, v_an, 'scheduled');
      END LOOP;
      v_tmp := v_arr[v_n];
      FOR v_i IN REVERSE v_n..3 LOOP v_arr[v_i] := v_arr[v_i-1]; END LOOP;
      v_arr[2] := v_tmp;
    END LOOP;
  END LOOP;

  RETURN v_season_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.setup_division_seasons()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_size integer := 12;
  v_leagues text[] := ARRAY['F','E','D','C','B','A'];
  v_league text;
  v_real uuid[];
  v_real_count integer;
  v_num_div integer;
  v_div integer;
  v_slice uuid[];
BEGIN
  DELETE FROM public.matches WHERE season_id IN (SELECT id FROM public.seasons WHERE status = 'active');
  DELETE FROM public.league_standings WHERE season_id IN (SELECT id FROM public.seasons WHERE status = 'active');
  DELETE FROM public.npc_clubs WHERE season_id IN (SELECT id FROM public.seasons WHERE status = 'active');
  UPDATE public.seasons SET status = 'completed' WHERE status = 'active';

  FOREACH v_league IN ARRAY v_leagues LOOP
    SELECT array_agg(id ORDER BY created_at) INTO v_real FROM public.clubs WHERE league = v_league;
    v_real_count := COALESCE(array_length(v_real,1),0);
    IF v_real_count = 0 THEN CONTINUE; END IF;
    v_num_div := CEIL(v_real_count::numeric / v_size);
    FOR v_div IN 1..v_num_div LOOP
      v_slice := v_real[((v_div-1)*v_size+1) : (v_div*v_size)];
      PERFORM public.build_division_season(v_league, v_div, v_slice);
    END LOOP;
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.end_season(p_season_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_season record;
  v_standing record;
  v_rank integer := 0;
  v_real_rank integer := 0;
  v_real_total integer;
  v_prize bigint;
  v_pos text;
  v_remaining integer;
  v_up text;
  v_down text;
BEGIN
  SELECT * INTO v_season FROM public.seasons WHERE id = p_season_id FOR UPDATE;
  IF v_season IS NULL OR v_season.status <> 'active' THEN RETURN; END IF;

  v_up := CASE v_season.league WHEN 'F' THEN 'E' WHEN 'E' THEN 'D' WHEN 'D' THEN 'C' WHEN 'C' THEN 'B' WHEN 'B' THEN 'A' ELSE 'A' END;
  v_down := CASE v_season.league WHEN 'A' THEN 'B' WHEN 'B' THEN 'C' WHEN 'C' THEN 'D' WHEN 'D' THEN 'E' WHEN 'E' THEN 'F' ELSE 'F' END;

  SELECT count(*) INTO v_real_total FROM public.league_standings WHERE season_id = p_season_id AND club_id IS NOT NULL;

  FOR v_standing IN
    SELECT * FROM public.league_standings WHERE season_id = p_season_id
    ORDER BY points DESC, (goals_for - goals_against) DESC, goals_for DESC
  LOOP
    v_rank := v_rank + 1;
    IF v_standing.club_id IS NOT NULL THEN
      v_real_rank := v_real_rank + 1;
      v_prize := CASE WHEN v_rank = 1 THEN 120000 WHEN v_rank = 2 THEN 70000 WHEN v_rank = 3 THEN 35000 ELSE 0 END;
      IF v_prize > 0 THEN
        UPDATE public.clubs SET balance = balance + v_prize WHERE id = v_standing.club_id;
        INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
        VALUES (v_standing.club_id, v_prize, (SELECT balance FROM public.clubs WHERE id = v_standing.club_id), 'premio', 'Prêmio de temporada: ' || v_rank || 'º lugar');
      END IF;

      IF v_rank <= 3 THEN
        v_pos := CASE v_rank WHEN 1 THEN 'champion' WHEN 2 THEN 'runner_up' ELSE 'third' END;
        IF NOT EXISTS (SELECT 1 FROM public.club_trophies WHERE club_id = v_standing.club_id AND trophy_type = 'league' AND position = v_pos AND season_number = v_season.season_number AND competition_name = 'Série ' || v_season.league) THEN
          INSERT INTO public.club_trophies (club_id, trophy_type, position, season_number, competition_name)
          VALUES (v_standing.club_id, 'league', v_pos, v_season.season_number, 'Série ' || v_season.league);
        END IF;
      END IF;

      IF v_real_rank <= 2 AND v_season.league <> 'A' THEN
        UPDATE public.clubs SET league = v_up WHERE id = v_standing.club_id;
      ELSIF v_real_rank > v_real_total - 2 AND v_season.league <> 'F' THEN
        UPDATE public.clubs SET league = v_down WHERE id = v_standing.club_id;
      END IF;

      UPDATE public.players SET age = LEAST(age + 1, 42), salary = GREATEST(1000, market_value / 160) WHERE club_id = v_standing.club_id;
      UPDATE public.players SET
        velocidade = GREATEST(1, velocidade - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        forca = GREATEST(1, forca - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        resistencia = GREATEST(1, resistencia - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        forma = GREATEST(1, forma - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        market_value = GREATEST(5000, (market_value * CASE WHEN age <= 25 THEN 1.04 WHEN age <= 28 THEN 1.0 WHEN age <= 32 THEN 0.85 ELSE 0.65 END)::bigint)
      WHERE club_id = v_standing.club_id AND age >= 28;
    END IF;
  END LOOP;

  UPDATE public.seasons SET status = 'completed' WHERE id = p_season_id;
  SELECT count(*) INTO v_remaining FROM public.seasons WHERE status = 'active';
  IF v_remaining = 0 THEN PERFORM public.setup_division_seasons(); END IF;
END;
$function$;

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
  v_capital_upkeep bigint;
BEGIN
  FOR v_club IN SELECT * FROM public.clubs FOR UPDATE LOOP
    v_new_balance := v_club.balance;
    v_new_week := v_club.game_week + 1;
    UPDATE public.clubs SET game_week = v_new_week WHERE id = v_club.id;
    v_inflation_factor := LEAST(1.0 + (v_new_week::numeric * 0.01), 2.0);

    UPDATE public.patrimony SET construction_weeks_remaining = GREATEST(0, construction_weeks_remaining - 1) WHERE club_id = v_club.id AND construction_weeks_remaining > 0;
    UPDATE public.juniors SET weeks_to_reveal = GREATEST(0, weeks_to_reveal - 1), revealed = CASE WHEN weeks_to_reveal <= 1 THEN true ELSE revealed END WHERE club_id = v_club.id AND revealed = false;
    UPDATE public.juniors SET quality = LEAST(quality + 1, 6) WHERE club_id = v_club.id AND revealed = false AND random() < 0.08;

    SELECT COALESCE(SUM(salary), 0) INTO v_salary_total FROM public.players WHERE club_id = v_club.id;
    v_new_balance := v_new_balance - v_salary_total;
    IF v_salary_total > 0 THEN INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description) VALUES (v_club.id, -v_salary_total, v_new_balance, 'salarios', 'Salários semanais'); END IF;

    SELECT COALESCE(SUM(maintenance_cost), 0) INTO v_maintenance_total FROM public.patrimony WHERE club_id = v_club.id;
    v_maintenance_total := (v_maintenance_total * v_inflation_factor)::bigint;
    v_new_balance := v_new_balance - v_maintenance_total;
    IF v_maintenance_total > 0 THEN INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description) VALUES (v_club.id, -v_maintenance_total, v_new_balance, 'manutencao', 'Manutenção patrimônio'); END IF;

    SELECT COALESCE(level, 0) INTO v_store_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'lojas' AND construction_weeks_remaining = 0;
    v_store_revenue := COALESCE(v_store_level, 0) * 2500 + COALESCE(v_store_level, 0) * LEAST(v_club.members, 2500);
    IF v_store_revenue > 0 THEN v_new_balance := v_new_balance + v_store_revenue; INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description) VALUES (v_club.id, v_store_revenue, v_new_balance, 'lojas', 'Receita lojas'); END IF;

    SELECT COALESCE(level, 0) INTO v_social_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'clube_social' AND construction_weeks_remaining = 0;
    v_social_revenue := COALESCE(v_social_level, 0) * 1500 + COALESCE(v_social_level, 0) * LEAST(v_club.members, 2500) * 2;
    IF v_social_revenue > 0 THEN v_new_balance := v_new_balance + v_social_revenue; INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description) VALUES (v_club.id, v_social_revenue, v_new_balance, 'clube_social', 'Receita clube social'); END IF;

    SELECT COALESCE(level, 0) INTO v_marketing_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'marketing' AND construction_weeks_remaining = 0;
    v_marketing_revenue := COALESCE(v_marketing_level, 0) * 3000;
    IF v_marketing_revenue > 0 THEN v_new_balance := v_new_balance + v_marketing_revenue; INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description) VALUES (v_club.id, v_marketing_revenue, v_new_balance, 'patrocinio', 'Patrocínio marketing'); END IF;

    SELECT COALESCE(level, 0) INTO v_psico_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'psicologia' AND construction_weeks_remaining = 0;
    SELECT COALESCE(level, 0) INTO v_escola_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'escola' AND construction_weeks_remaining = 0;
    SELECT COALESCE(level, 0) INTO v_func_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'funcionarios' AND construction_weeks_remaining = 0;

    v_func_cost := (v_func_level * 4500 * v_inflation_factor)::bigint;
    IF v_func_cost > 0 THEN v_new_balance := v_new_balance - v_func_cost; INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description) VALUES (v_club.id, -v_func_cost, v_new_balance, 'staff', 'Salário funcionários (Nv ' || v_func_level || ')'); END IF;
    IF v_psico_level > 0 THEN UPDATE public.players SET agressividade = GREATEST(1, agressividade - 1) WHERE club_id = v_club.id AND agressividade > 1 AND random() < (v_psico_level::float / 30.0); END IF;
    IF v_escola_level > 0 THEN UPDATE public.players SET inteligencia = LEAST(16, inteligencia + 1) WHERE club_id = v_club.id AND inteligencia < 16 AND random() < (v_escola_level::float / 30.0); END IF;

    v_marketing_cost := LEAST(COALESCE(v_club.marketing_budget, 0), 50000);
    IF COALESCE(v_club.marketing_budget, 0) <> v_marketing_cost THEN UPDATE public.clubs SET marketing_budget = v_marketing_cost WHERE id = v_club.id; END IF;
    IF v_marketing_cost > 0 THEN v_new_balance := v_new_balance - v_marketing_cost; INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description) VALUES (v_club.id, -v_marketing_cost, v_new_balance, 'marketing', 'Investimento marketing'); END IF;

    v_member_revenue := LEAST(v_club.members, 30000) * 35;
    IF v_member_revenue > 0 THEN v_new_balance := v_new_balance + v_member_revenue; INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description) VALUES (v_club.id, v_member_revenue, v_new_balance, 'socios', 'Sócios (' || v_club.members || ')'); END IF;

    SELECT COALESCE(SUM(CASE WHEN (m.home_club_id = v_club.id AND m.home_score > m.away_score) OR (m.away_club_id = v_club.id AND m.away_score > m.home_score) THEN 1 ELSE 0 END), 0), COALESCE(SUM(CASE WHEN (m.home_club_id = v_club.id AND m.home_score < m.away_score) OR (m.away_club_id = v_club.id AND m.away_score < m.home_score) THEN 1 ELSE 0 END), 0) INTO v_recent_wins, v_recent_losses FROM (SELECT * FROM public.matches WHERE (home_club_id = v_club.id OR away_club_id = v_club.id) AND status = 'played' ORDER BY played_at DESC LIMIT 5) m;
    v_league_bonus := CASE v_club.league WHEN 'A' THEN 4 WHEN 'B' THEN 3 WHEN 'C' THEN 2 WHEN 'D' THEN 1 ELSE 0 END;
    v_member_change := LEAST(12, GREATEST(-10, (v_recent_wins * 2) - (v_recent_losses * 2) + v_league_bonus + (v_marketing_cost / 10000)::integer + COALESCE(v_marketing_level, 0) + floor(random() * 3)::integer - 1));
    v_new_members := GREATEST(50, LEAST(30000, v_club.members + v_member_change));
    UPDATE public.clubs SET members = v_new_members, fans = GREATEST(100, LEAST(500000, fans + v_member_change * 3 + COALESCE(v_marketing_level, 0) * 5)) WHERE id = v_club.id;

    SELECT COALESCE(COUNT(*), 0) * 2500 INTO v_junior_cost FROM public.juniors WHERE club_id = v_club.id;
    v_junior_cost := (v_junior_cost * v_inflation_factor)::bigint;
    IF v_junior_cost > 0 THEN v_new_balance := v_new_balance - v_junior_cost; INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description) VALUES (v_club.id, -v_junior_cost, v_new_balance, 'juniores', 'Manutenção juniores'); END IF;

    FOR v_loan IN SELECT * FROM public.loans WHERE club_id = v_club.id AND status = 'active' FOR UPDATE LOOP
      v_loan_payment := v_loan.weekly_payment;
      v_new_balance := v_new_balance - v_loan_payment;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description) VALUES (v_club.id, -v_loan_payment, v_new_balance, 'emprestimo', 'Parcela empréstimo (' || (v_loan.remaining_weeks - 1) || ' restantes)');
      UPDATE public.system_funds SET balance = balance + v_loan_payment WHERE fund_type = 'loan_system';
      UPDATE public.loans SET paid_amount = paid_amount + v_loan_payment, remaining_weeks = remaining_weeks - 1, status = CASE WHEN remaining_weeks - 1 <= 0 THEN 'paid' ELSE 'active' END, updated_at = now() WHERE id = v_loan.id;
    END LOOP;

    IF v_new_balance > 10000000 THEN
      v_capital_upkeep := ((v_new_balance - 10000000) * 0.025)::bigint;
      v_new_balance := v_new_balance - v_capital_upkeep;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description) VALUES (v_club.id, -v_capital_upkeep, v_new_balance, 'custos', 'Custo de capital e gestão');
    END IF;

    v_wealth_surcharge := 0;
    IF v_new_balance > 200000000 THEN v_wealth_surcharge := ((v_new_balance - 200000000) * 0.25)::bigint + (150000000 * 0.12)::bigint + (45000000 * 0.05)::bigint;
    ELSIF v_new_balance > 50000000 THEN v_wealth_surcharge := ((v_new_balance - 50000000) * 0.12)::bigint + (45000000 * 0.05)::bigint;
    ELSIF v_new_balance > 5000000 THEN v_wealth_surcharge := ((v_new_balance - 5000000) * 0.05)::bigint; END IF;
    IF v_wealth_surcharge > 0 THEN v_new_balance := v_new_balance - v_wealth_surcharge; INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description) VALUES (v_club.id, -v_wealth_surcharge, v_new_balance, 'imposto', 'Imposto progressivo anti-acúmulo'); END IF;

    IF v_new_balance < 0 THEN
      v_interest_rate := LEAST(6 + (ABS(v_new_balance) / 500000)::integer, 22);
      v_interest := LEAST(ABS(v_new_balance) * v_interest_rate / 100, 750000);
      v_new_balance := v_new_balance - v_interest;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description) VALUES (v_club.id, -v_interest, v_new_balance, 'juros', 'Juros saldo devedor (' || v_interest_rate || '%)');
    END IF;

    SELECT * INTO v_training FROM public.training_config WHERE club_id = v_club.id;
    IF v_training IS NOT NULL THEN
      SELECT COALESCE(level, 0) INTO v_ct_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'ct' AND construction_weeks_remaining = 0;
      IF v_training.physical_type = 'forca' THEN UPDATE public.players SET forca = LEAST(forca + 1, potencial_forca) WHERE club_id = v_club.id AND forca < potencial_forca AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct_level, 0) * 4 + v_func_level * 2) / 190.0);
      ELSIF v_training.physical_type = 'velocidade' THEN UPDATE public.players SET velocidade = LEAST(velocidade + 1, potencial_velocidade) WHERE club_id = v_club.id AND velocidade < potencial_velocidade AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct_level, 0) * 4 + v_func_level * 2) / 190.0);
      ELSIF v_training.physical_type = 'resistencia' THEN UPDATE public.players SET resistencia = LEAST(resistencia + 1, potencial_resistencia) WHERE club_id = v_club.id AND resistencia < potencial_resistencia AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct_level, 0) * 4 + v_func_level * 2) / 190.0);
      ELSIF v_training.physical_type = 'forma' THEN UPDATE public.players SET forma = LEAST(forma + 1, potencial_forma) WHERE club_id = v_club.id AND forma < potencial_forma AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct_level, 0) * 4 + v_func_level * 2) / 190.0); END IF;
      IF v_training.physical_intensity > 70 THEN UPDATE public.players SET is_injured = true, injury_weeks = GREATEST(1, (1 + floor(random() * 3)::int) - v_func_level / 4) WHERE club_id = v_club.id AND is_injured = false AND random() < ((v_training.physical_intensity - 70)::float / 260.0); END IF;
      UPDATE public.players SET injury_weeks = GREATEST(0, injury_weeks - 1 - (v_func_level / 5)), is_injured = CASE WHEN injury_weeks <= 1 THEN false ELSE true END WHERE club_id = v_club.id AND is_injured = true;
    END IF;

    UPDATE public.players SET fadiga = GREATEST(0, fadiga - 10) WHERE club_id = v_club.id;
    UPDATE public.players SET entrosamento = GREATEST(0, entrosamento - 3) WHERE club_id = v_club.id;
    v_new_balance := v_new_balance - (3000 * v_inflation_factor)::bigint;
    INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description) VALUES (v_club.id, -(3000 * v_inflation_factor)::bigint, v_new_balance, 'despesas', 'Despesas administrativas');
    UPDATE public.clubs SET balance = v_new_balance WHERE id = v_club.id;
    v_clubs_processed := v_clubs_processed + 1;
  END LOOP;
  RETURN jsonb_build_object('clubs_processed', v_clubs_processed);
END;
$function$;

CREATE OR REPLACE FUNCTION public.advance_cup_phase(p_cup_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  cup_rec RECORD; current_phase TEXT; next_phase TEXT; participants UUID[]; i INTEGER; home_id UUID; away_id UUID; hs INTEGER; as_score INTEGER; hstr INTEGER; astr INTEGER; winner UUID; winners UUID[] := '{}'; match_count INTEGER; v_u20 BOOLEAN; v_champion_prize bigint; v_semifinal_prize bigint;
BEGIN
  SELECT * INTO cup_rec FROM public.cups WHERE id = p_cup_id FOR UPDATE;
  IF cup_rec IS NULL THEN RETURN jsonb_build_object('status', 'missing'); END IF;
  IF cup_rec.status = 'finished' THEN RETURN jsonb_build_object('status', 'finished'); END IF;
  IF cup_rec.starts_at IS NOT NULL AND cup_rec.starts_at > now() THEN RETURN jsonb_build_object('status', 'waiting'); END IF;
  v_u20 := (cup_rec.cup_type = 'u20');
  v_champion_prize := LEAST(COALESCE(cup_rec.champion_prize, 0), 150000);
  v_semifinal_prize := LEAST(COALESCE(cup_rec.semifinal_prize, 0), 25000);
  SELECT phase INTO current_phase FROM public.cup_matches WHERE cup_id = p_cup_id AND status = 'scheduled' LIMIT 1;
  IF current_phase IS NULL THEN
    SELECT array_agg(club_id ORDER BY random()) INTO participants FROM public.cup_entries WHERE cup_id = p_cup_id AND status = 'active';
    IF participants IS NULL OR array_length(participants, 1) < 2 THEN RETURN jsonb_build_object('status', 'not_enough_participants'); END IF;
    next_phase := CASE WHEN array_length(participants, 1) >= 8 THEN 'quartas' WHEN array_length(participants, 1) >= 4 THEN 'semi' ELSE 'final' END;
    FOR i IN 1..(array_length(participants, 1) / 2) LOOP INSERT INTO public.cup_matches (cup_id, phase, home_club_id, away_club_id) VALUES (p_cup_id, next_phase, participants[i*2-1], participants[i*2]); END LOOP;
    UPDATE public.cups SET status = 'in_progress' WHERE id = p_cup_id;
    RETURN jsonb_build_object('status', 'started', 'phase', next_phase);
  END IF;
  FOR home_id, away_id IN SELECT home_club_id, away_club_id FROM public.cup_matches WHERE cup_id = p_cup_id AND phase = current_phase AND status = 'scheduled' LOOP
    hstr := public.cup_team_strength(home_id, v_u20) + 4; astr := public.cup_team_strength(away_id, v_u20);
    hs := LEAST(GREATEST(0, floor(random() * (hstr::float / 25.0 + 0.8))::int), 6);
    as_score := LEAST(GREATEST(0, floor(random() * (astr::float / 25.0 + 0.8))::int), 6);
    IF hs = as_score THEN IF random() < (hstr::float / GREATEST(hstr + astr, 1)) THEN hs := hs + 1; ELSE as_score := as_score + 1; END IF; END IF;
    winner := CASE WHEN hs > as_score THEN home_id ELSE away_id END; winners := array_append(winners, winner);
    UPDATE public.cup_matches SET home_score = hs, away_score = as_score, status = 'played', played_at = now() WHERE cup_id = p_cup_id AND phase = current_phase AND home_club_id = home_id AND away_club_id = away_id;
  END LOOP;
  match_count := array_length(winners, 1);
  IF match_count = 1 THEN
    IF EXISTS (SELECT 1 FROM public.clubs WHERE id = winners[1]) THEN
      UPDATE public.clubs SET balance = balance + v_champion_prize WHERE id = winners[1];
      INSERT INTO public.financial_transactions (club_id, type, description, amount, balance_after) SELECT winners[1], 'copa', 'Campeão ' || cup_rec.name, v_champion_prize, balance FROM public.clubs WHERE id = winners[1];
      IF NOT EXISTS (SELECT 1 FROM public.club_trophies WHERE club_id = winners[1] AND trophy_type = 'cup' AND position = 'champion' AND competition_name = cup_rec.name AND created_at > now() - interval '6 days') THEN INSERT INTO public.club_trophies (club_id, trophy_type, position, season_number, competition_name) VALUES (winners[1], 'cup', 'champion', 0, cup_rec.name); END IF;
    END IF;
    UPDATE public.cup_entries SET reached_phase = 'campeao' WHERE cup_id = p_cup_id AND club_id = winners[1];
    UPDATE public.cups SET status = 'finished', starts_at = now() + interval '7 days' WHERE id = p_cup_id;
    RETURN jsonb_build_object('status', 'finished', 'champion', winners[1]);
  END IF;
  next_phase := CASE WHEN match_count >= 4 THEN 'semi' ELSE 'final' END;
  IF current_phase = 'semi' AND v_semifinal_prize > 0 THEN UPDATE public.clubs SET balance = balance + v_semifinal_prize WHERE id IN (SELECT CASE WHEN home_score > away_score THEN away_club_id ELSE home_club_id END FROM public.cup_matches WHERE cup_id = p_cup_id AND phase = 'semi'); END IF;
  UPDATE public.cup_entries SET reached_phase = current_phase WHERE cup_id = p_cup_id AND status = 'active' AND club_id <> ALL(winners) AND reached_phase IS NULL;
  FOR i IN 1..(match_count / 2) LOOP INSERT INTO public.cup_matches (cup_id, phase, home_club_id, away_club_id) VALUES (p_cup_id, next_phase, winners[i*2-1], winners[i*2]); END LOOP;
  RETURN jsonb_build_object('status', 'advanced', 'phase', next_phase, 'remaining', match_count / 2);
END;
$function$;

CREATE OR REPLACE FUNCTION public.cleanup_old_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE v_seasons_removed integer := 0; v_txn_removed integer := 0; v_cups_recycled integer := 0;
BEGIN
  DELETE FROM public.matches WHERE season_id IN (SELECT id FROM public.seasons WHERE status <> 'active');
  DELETE FROM public.league_standings WHERE season_id IN (SELECT id FROM public.seasons WHERE status <> 'active');
  DELETE FROM public.npc_clubs WHERE season_id IS NULL OR season_id NOT IN (SELECT id FROM public.seasons WHERE status = 'active');
  DELETE FROM public.seasons WHERE status <> 'active'; GET DIAGNOSTICS v_seasons_removed = ROW_COUNT;
  DELETE FROM public.financial_transactions ft WHERE ft.id IN (SELECT id FROM (SELECT id, row_number() OVER (PARTITION BY club_id ORDER BY created_at DESC) AS rn FROM public.financial_transactions) t WHERE t.rn > 40); GET DIAGNOSTICS v_txn_removed = ROW_COUNT;
  DELETE FROM public.disciplinary_events WHERE created_at < now() - interval '7 days';
  DELETE FROM public.cup_matches WHERE cup_id IN (SELECT id FROM public.cups WHERE status = 'finished' AND starts_at <= now());
  DELETE FROM public.cup_entries WHERE cup_id IN (SELECT id FROM public.cups WHERE status = 'finished' AND starts_at <= now());
  UPDATE public.cups SET status = 'open' WHERE status = 'finished' AND starts_at <= now(); GET DIAGNOSTICS v_cups_recycled = ROW_COUNT;
  RETURN jsonb_build_object('seasons_cleaned', v_seasons_removed, 'transactions_trimmed', v_txn_removed, 'cups_recycled', v_cups_recycled);
END;
$function$;

CREATE OR REPLACE FUNCTION public.repair_game_progression()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE v_season record; v_ended integer := 0; v_active integer;
BEGIN
  FOR v_season IN SELECT s.* FROM public.seasons s WHERE s.status = 'active' AND s.current_round >= s.total_rounds AND NOT EXISTS (SELECT 1 FROM public.matches m WHERE m.season_id = s.id AND m.status = 'scheduled') LOOP
    PERFORM public.end_season(v_season.id); v_ended := v_ended + 1;
  END LOOP;
  SELECT count(*) INTO v_active FROM public.seasons WHERE status = 'active';
  IF v_active = 0 AND EXISTS (SELECT 1 FROM public.clubs) THEN PERFORM public.setup_division_seasons(); END IF;
  RETURN jsonb_build_object('ended_seasons', v_ended, 'active_seasons', (SELECT count(*) FROM public.seasons WHERE status = 'active'));
END;
$function$;