
-- Add fatigue column to players
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS fadiga integer NOT NULL DEFAULT 0;

-- Update stadium_sectors to have proper seat types for revenue calculation
-- Each stadium level = 10,000 total seats: 7,000 concrete(R$50), 2,000 chairs(R$100), 1,000 VIP(R$1000)
-- We'll restructure existing sectors via the upgrade function

-- Update upgrade_patrimony to handle stadium properly (10k seats per level, up to 100k)
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
  v_old_level integer;
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

  SELECT type, level INTO v_pat_type, v_old_level FROM public.patrimony WHERE id = p_patrimony_id AND club_id = p_club_id;

  UPDATE public.patrimony
  SET level = p_new_level,
      construction_weeks_remaining = p_build_weeks,
      maintenance_cost = p_new_maintenance
  WHERE id = p_patrimony_id AND club_id = p_club_id;

  -- Stadium upgrade: each level = 10,000 total seats
  -- Distribution: 70% concrete(geral), 20% chairs(cadeira), 10% VIP(camarote)
  IF v_pat_type = 'estadio' THEN
    DELETE FROM public.stadium_sectors WHERE club_id = p_club_id;
    INSERT INTO public.stadium_sectors (club_id, sector_name, capacity, seat_type, structure, ring) VALUES
      (p_club_id, 'Geral Norte', p_new_level * 1750, 'geral', 'concreto', 1),
      (p_club_id, 'Geral Sul', p_new_level * 1750, 'geral', 'concreto', 1),
      (p_club_id, 'Geral Leste', p_new_level * 1750, 'geral', 'concreto', 1),
      (p_club_id, 'Geral Oeste', p_new_level * 1750, 'geral', 'concreto', 1),
      (p_club_id, 'Cadeiras Norte', p_new_level * 500, 'cadeira', 'cadeira', 2),
      (p_club_id, 'Cadeiras Sul', p_new_level * 500, 'cadeira', 'cadeira', 2),
      (p_club_id, 'Cadeiras Leste', p_new_level * 500, 'cadeira', 'cadeira', 2),
      (p_club_id, 'Cadeiras Oeste', p_new_level * 500, 'cadeira', 'cadeira', 2),
      (p_club_id, 'Camarote VIP', p_new_level * 1000, 'camarote', 'camarote', 3);
  END IF;

  INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
  VALUES (p_club_id, -p_cost, v_new_balance, 'patrimonio', p_description);
END;
$function$;

-- Update simulate_matches for proper ticket revenue
CREATE OR REPLACE FUNCTION public.simulate_matches()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_season record;
  v_match record;
  v_home_strength integer;
  v_away_strength integer;
  v_home_score integer;
  v_away_score integer;
  v_revenue bigint;
  v_prize bigint;
  v_matches_played integer := 0;
  v_new_balance bigint;
BEGIN
  FOR v_season IN SELECT * FROM public.seasons WHERE status = 'active' FOR UPDATE LOOP
    FOR v_match IN
      SELECT * FROM public.matches
      WHERE season_id = v_season.id AND round = v_season.current_round AND status = 'scheduled'
      FOR UPDATE
    LOOP
      -- Home strength
      IF v_match.home_club_id IS NOT NULL THEN
        SELECT COALESCE(
          (SELECT (AVG(
            (reflexos + posicionamento + jogo_aereo + desarme + armacao + passe + tecnica + chute) / 8.0 * 0.7 +
            (velocidade + forca + resistencia + forma) / 4.0 * 0.3
          ) * 10)::integer
          FROM public.players WHERE club_id = v_match.home_club_id AND is_injured = false), 30
        ) INTO v_home_strength;
      ELSE
        SELECT strength INTO v_home_strength FROM public.npc_clubs WHERE id = v_match.home_npc_id;
      END IF;

      -- Away strength
      IF v_match.away_club_id IS NOT NULL THEN
        SELECT COALESCE(
          (SELECT (AVG(
            (reflexos + posicionamento + jogo_aereo + desarme + armacao + passe + tecnica + chute) / 8.0 * 0.7 +
            (velocidade + forca + resistencia + forma) / 4.0 * 0.3
          ) * 10)::integer
          FROM public.players WHERE club_id = v_match.away_club_id AND is_injured = false), 30
        ) INTO v_away_strength;
      ELSE
        SELECT strength INTO v_away_strength FROM public.npc_clubs WHERE id = v_match.away_npc_id;
      END IF;

      v_home_strength := v_home_strength + 5;

      v_home_score := LEAST(GREATEST(0, floor(random() * (v_home_strength::float / 20.0 + 1.5))::int), 7);
      v_away_score := LEAST(GREATEST(0, floor(random() * (v_away_strength::float / 20.0 + 1.5))::int), 7);

      -- Revenue for home real club: concrete=R$50, chairs=R$100, VIP=R$1000
      v_revenue := 0;
      IF v_match.home_club_id IS NOT NULL THEN
        SELECT COALESCE(SUM(
          CASE seat_type
            WHEN 'camarote' THEN capacity * 1000
            WHEN 'cadeira' THEN capacity * 100
            ELSE capacity * 50
          END
        ), 0) INTO v_revenue
        FROM public.stadium_sectors WHERE club_id = v_match.home_club_id;
      END IF;

      UPDATE public.matches
      SET home_score = v_home_score, away_score = v_away_score,
          status = 'played', revenue = v_revenue, played_at = now()
      WHERE id = v_match.id;

      -- Update standings (home)
      IF v_match.home_club_id IS NOT NULL THEN
        UPDATE public.league_standings SET
          played = played + 1, goals_for = goals_for + v_home_score, goals_against = goals_against + v_away_score,
          wins = wins + CASE WHEN v_home_score > v_away_score THEN 1 ELSE 0 END,
          draws = draws + CASE WHEN v_home_score = v_away_score THEN 1 ELSE 0 END,
          losses = losses + CASE WHEN v_home_score < v_away_score THEN 1 ELSE 0 END,
          points = points + CASE WHEN v_home_score > v_away_score THEN 3 WHEN v_home_score = v_away_score THEN 1 ELSE 0 END
        WHERE season_id = v_season.id AND club_id = v_match.home_club_id;
      ELSE
        UPDATE public.league_standings SET
          played = played + 1, goals_for = goals_for + v_home_score, goals_against = goals_against + v_away_score,
          wins = wins + CASE WHEN v_home_score > v_away_score THEN 1 ELSE 0 END,
          draws = draws + CASE WHEN v_home_score = v_away_score THEN 1 ELSE 0 END,
          losses = losses + CASE WHEN v_home_score < v_away_score THEN 1 ELSE 0 END,
          points = points + CASE WHEN v_home_score > v_away_score THEN 3 WHEN v_home_score = v_away_score THEN 1 ELSE 0 END
        WHERE season_id = v_season.id AND npc_club_id = v_match.home_npc_id;
      END IF;

      -- Update standings (away)
      IF v_match.away_club_id IS NOT NULL THEN
        UPDATE public.league_standings SET
          played = played + 1, goals_for = goals_for + v_away_score, goals_against = goals_against + v_home_score,
          wins = wins + CASE WHEN v_away_score > v_home_score THEN 1 ELSE 0 END,
          draws = draws + CASE WHEN v_away_score = v_home_score THEN 1 ELSE 0 END,
          losses = losses + CASE WHEN v_away_score < v_home_score THEN 1 ELSE 0 END,
          points = points + CASE WHEN v_away_score > v_home_score THEN 3 WHEN v_away_score = v_home_score THEN 1 ELSE 0 END
        WHERE season_id = v_season.id AND club_id = v_match.away_club_id;
      ELSE
        UPDATE public.league_standings SET
          played = played + 1, goals_for = goals_for + v_away_score, goals_against = goals_against + v_home_score,
          wins = wins + CASE WHEN v_away_score > v_home_score THEN 1 ELSE 0 END,
          draws = draws + CASE WHEN v_away_score = v_home_score THEN 1 ELSE 0 END,
          losses = losses + CASE WHEN v_away_score < v_home_score THEN 1 ELSE 0 END,
          points = points + CASE WHEN v_away_score > v_home_score THEN 3 WHEN v_away_score = v_home_score THEN 1 ELSE 0 END
        WHERE season_id = v_season.id AND npc_club_id = v_match.away_npc_id;
      END IF;

      -- Award revenue + prize
      IF v_match.home_club_id IS NOT NULL THEN
        v_prize := CASE WHEN v_home_score > v_away_score THEN 15000 WHEN v_home_score = v_away_score THEN 5000 ELSE 0 END;
        IF v_revenue + v_prize > 0 THEN
          UPDATE public.clubs SET balance = balance + v_revenue + v_prize WHERE id = v_match.home_club_id;
          SELECT balance INTO v_new_balance FROM public.clubs WHERE id = v_match.home_club_id;
          INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
          VALUES (v_match.home_club_id, v_revenue + v_prize, v_new_balance, 'partida',
            'Renda (' || v_revenue || ') + prêmio (' || v_prize || '): ' || v_home_score || 'x' || v_away_score);
        END IF;
      END IF;

      IF v_match.away_club_id IS NOT NULL THEN
        v_prize := CASE WHEN v_away_score > v_home_score THEN 15000 WHEN v_away_score = v_home_score THEN 5000 ELSE 0 END;
        IF v_prize > 0 THEN
          UPDATE public.clubs SET balance = balance + v_prize WHERE id = v_match.away_club_id;
          SELECT balance INTO v_new_balance FROM public.clubs WHERE id = v_match.away_club_id;
          INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
          VALUES (v_match.away_club_id, v_prize, v_new_balance, 'partida',
            'Prêmio fora: ' || v_away_score || 'x' || v_home_score);
        END IF;
      END IF;

      -- Update entrosamento (+12.5% per game, cap 100) and experience (+0.5%) for players who played
      IF v_match.home_club_id IS NOT NULL THEN
        UPDATE public.players SET
          entrosamento = LEAST(100, entrosamento + 13),
          experiencia = LEAST(16, experiencia + CASE WHEN random() < 0.5 THEN 1 ELSE 0 END),
          fadiga = LEAST(100, fadiga + 15)
        WHERE club_id = v_match.home_club_id AND is_injured = false;
        -- Captain gets leadership boost
        UPDATE public.players SET
          lideranca = LEAST(16, lideranca + CASE WHEN random() < 0.5 THEN 1 ELSE 0 END)
        WHERE club_id = v_match.home_club_id AND is_captain = true;
      END IF;

      IF v_match.away_club_id IS NOT NULL THEN
        UPDATE public.players SET
          entrosamento = LEAST(100, entrosamento + 13),
          experiencia = LEAST(16, experiencia + CASE WHEN random() < 0.5 THEN 1 ELSE 0 END),
          fadiga = LEAST(100, fadiga + 15)
        WHERE club_id = v_match.away_club_id AND is_injured = false;
        UPDATE public.players SET
          lideranca = LEAST(16, lideranca + CASE WHEN random() < 0.5 THEN 1 ELSE 0 END)
        WHERE club_id = v_match.away_club_id AND is_captain = true;
      END IF;

      v_matches_played := v_matches_played + 1;
    END LOOP;

    -- Advance round
    IF NOT EXISTS (
      SELECT 1 FROM public.matches
      WHERE season_id = v_season.id AND round = v_season.current_round AND status = 'scheduled'
    ) THEN
      IF v_season.current_round >= v_season.total_rounds THEN
        PERFORM public.end_season(v_season.id);
      ELSE
        UPDATE public.seasons SET current_round = v_season.current_round + 1 WHERE id = v_season.id;
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('matches_played', v_matches_played);
END;
$function$;

-- Update process_game_week with patrimony effects, fatigue recovery, age mechanics
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
  v_store_revenue bigint;
  v_social_revenue bigint;
  v_marketing_revenue bigint;
  v_ct_level integer;
  v_junior_cost bigint;
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
      VALUES (v_club.id, -v_salary_total, v_new_balance, 'salarios', 'Pagamento semanal de salários (' || (SELECT COUNT(*) FROM public.players WHERE club_id = v_club.id) || ' jogadores)');
    END IF;

    -- === MAINTENANCE ===
    SELECT COALESCE(SUM(maintenance_cost), 0) INTO v_maintenance_total
    FROM public.patrimony WHERE club_id = v_club.id;
    v_new_balance := v_new_balance - v_maintenance_total;
    IF v_maintenance_total > 0 THEN
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_maintenance_total, v_new_balance, 'manutencao', 'Manutenção semanal do patrimônio');
    END IF;

    -- === PATRIMONY REVENUE EFFECTS ===
    -- Store revenue: level * R$5000/week + level * members * R$2
    SELECT COALESCE(level, 0) INTO v_store_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'lojas' AND construction_weeks_remaining = 0;
    v_store_revenue := COALESCE(v_store_level, 0) * 5000 + COALESCE(v_store_level, 0) * v_club.members * 2;
    IF v_store_revenue > 0 THEN
      v_new_balance := v_new_balance + v_store_revenue;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, v_store_revenue, v_new_balance, 'lojas', 'Receita das lojas (Nível ' || v_store_level || ')');
    END IF;

    -- Social club revenue: level * R$3000/week + level * members * R$5
    SELECT COALESCE(level, 0) INTO v_social_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'clube_social' AND construction_weeks_remaining = 0;
    v_social_revenue := COALESCE(v_social_level, 0) * 3000 + COALESCE(v_social_level, 0) * v_club.members * 5;
    IF v_social_revenue > 0 THEN
      v_new_balance := v_new_balance + v_social_revenue;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, v_social_revenue, v_new_balance, 'clube_social', 'Receita do Clube Social (Nível ' || v_social_level || ')');
    END IF;

    -- Marketing revenue: increases fans/members but also generates sponsorship
    SELECT COALESCE(level, 0) INTO v_marketing_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'marketing' AND construction_weeks_remaining = 0;
    v_marketing_revenue := COALESCE(v_marketing_level, 0) * 8000;
    IF v_marketing_revenue > 0 THEN
      v_new_balance := v_new_balance + v_marketing_revenue;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, v_marketing_revenue, v_new_balance, 'patrocinio', 'Patrocínio (Marketing Nível ' || v_marketing_level || ')');
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

    -- === MEMBER/FAN FLUCTUATION ===
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
      + COALESCE(v_marketing_level, 0) * 2
      + floor(random() * 3)::integer - 1;

    v_new_members := GREATEST(0, v_club.members + v_member_change);

    -- Update fans too based on marketing level and wins
    UPDATE public.clubs SET
      members = v_new_members,
      fans = GREATEST(fans + v_member_change * 5 + COALESCE(v_marketing_level, 0) * 10, 100)
    WHERE id = v_club.id;

    -- === JUNIOR TRAINING COST ===
    SELECT COALESCE(level, 0) INTO v_ct_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'alojamento' AND construction_weeks_remaining = 0;
    SELECT COALESCE(COUNT(*), 0) * 2000 INTO v_junior_cost FROM public.juniors WHERE club_id = v_club.id;
    IF v_junior_cost > 0 THEN
      v_new_balance := v_new_balance - v_junior_cost;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_junior_cost, v_new_balance, 'juniores', 'Manutenção semanal de juniores (' || (SELECT COUNT(*) FROM public.juniors WHERE club_id = v_club.id) || ' juniores)');
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
      -- CT level boosts training effectiveness
      SELECT COALESCE(level, 0) INTO v_ct_level FROM public.patrimony WHERE club_id = v_club.id AND type = 'ct' AND construction_weeks_remaining = 0;

      IF v_training.physical_type = 'forca' THEN
        UPDATE public.players SET forca = LEAST(forca + 1, potencial_forca)
        WHERE club_id = v_club.id AND forca < potencial_forca AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct_level, 0) * 5) / 150.0);
      ELSIF v_training.physical_type = 'velocidade' THEN
        UPDATE public.players SET velocidade = LEAST(velocidade + 1, potencial_velocidade)
        WHERE club_id = v_club.id AND velocidade < potencial_velocidade AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct_level, 0) * 5) / 150.0);
      ELSIF v_training.physical_type = 'resistencia' THEN
        UPDATE public.players SET resistencia = LEAST(resistencia + 1, potencial_resistencia)
        WHERE club_id = v_club.id AND resistencia < potencial_resistencia AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct_level, 0) * 5) / 150.0);
      ELSIF v_training.physical_type = 'forma' THEN
        UPDATE public.players SET forma = LEAST(forma + 1, potencial_forma)
        WHERE club_id = v_club.id AND forma < potencial_forma AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct_level, 0) * 5) / 150.0);
      ELSE
        UPDATE public.players SET
          velocidade = CASE WHEN random() < 0.25 AND velocidade < potencial_velocidade THEN LEAST(velocidade + 1, potencial_velocidade) ELSE velocidade END,
          forca = CASE WHEN random() < 0.25 AND forca < potencial_forca THEN LEAST(forca + 1, potencial_forca) ELSE forca END,
          resistencia = CASE WHEN random() < 0.25 AND resistencia < potencial_resistencia THEN LEAST(resistencia + 1, potencial_resistencia) ELSE resistencia END,
          forma = CASE WHEN random() < 0.25 AND forma < potencial_forma THEN LEAST(forma + 1, potencial_forma) ELSE forma END
        WHERE club_id = v_club.id AND random() < ((v_training.physical_intensity::float + COALESCE(v_ct_level, 0) * 5) / 150.0);
      END IF;

      -- Injury risk
      IF v_training.physical_intensity > 70 THEN
        UPDATE public.players
        SET is_injured = true, injury_weeks = 1 + floor(random() * 3)::int
        WHERE club_id = v_club.id AND is_injured = false
          AND random() < ((v_training.physical_intensity - 70)::float / 300.0);
      END IF;

      -- Heal injuries
      UPDATE public.players
      SET injury_weeks = GREATEST(0, injury_weeks - 1),
          is_injured = CASE WHEN injury_weeks <= 1 THEN false ELSE true END
      WHERE club_id = v_club.id AND is_injured = true;
    END IF;

    -- === FADIGA RECOVERY (10% per week of rest) ===
    UPDATE public.players SET fadiga = GREATEST(0, fadiga - 10) WHERE club_id = v_club.id;

    -- === ENTROSAMENTO DECAY (5% if not playing) ===
    UPDATE public.players SET entrosamento = GREATEST(0, entrosamento - 5) WHERE club_id = v_club.id;

    -- === HONESTY: random events — dishonest players may cause fines ===
    UPDATE public.players SET honestidade = LEAST(16, honestidade + 1)
    WHERE club_id = v_club.id AND random() < 0.05 AND honestidade < 16;
    -- Low honesty players may get fined
    IF EXISTS (SELECT 1 FROM public.players WHERE club_id = v_club.id AND honestidade <= 2 AND random() < 0.1) THEN
      v_new_balance := v_new_balance - 5000;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -5000, v_new_balance, 'multa', 'Multa por comportamento antidesportivo de jogador');
    END IF;

    -- === RECURRING EXPENSES (office/materials) ===
    v_new_balance := v_new_balance - 2000;
    INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
    VALUES (v_club.id, -2000, v_new_balance, 'despesas', 'Despesas administrativas semanais');

    UPDATE public.clubs SET balance = v_new_balance WHERE id = v_club.id;
    v_clubs_processed := v_clubs_processed + 1;
  END LOOP;

  RETURN jsonb_build_object('clubs_processed', v_clubs_processed);
END;
$function$;

-- Update end_season to age players, adjust salaries, handle decline
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
  v_total integer;
  v_leagues text[] := ARRAY['F', 'E', 'D', 'C', 'B', 'A'];
  v_current_idx integer;
  v_new_league text;
  v_prize bigint;
BEGIN
  SELECT * INTO v_season FROM public.seasons WHERE id = p_season_id;
  UPDATE public.seasons SET status = 'completed' WHERE id = p_season_id;

  SELECT COUNT(*) INTO v_total FROM public.league_standings WHERE season_id = p_season_id;

  FOR v_standing IN
    SELECT * FROM public.league_standings
    WHERE season_id = p_season_id
    ORDER BY points DESC, (goals_for - goals_against) DESC, goals_for DESC
  LOOP
    v_rank := v_rank + 1;

    IF v_standing.club_id IS NOT NULL THEN
      v_current_idx := array_position(v_leagues, v_season.league);

      -- Prize money based on position
      v_prize := CASE
        WHEN v_rank = 1 THEN 500000
        WHEN v_rank = 2 THEN 300000
        WHEN v_rank = 3 THEN 150000
        WHEN v_rank <= 5 THEN 50000
        ELSE 0
      END;

      IF v_prize > 0 THEN
        UPDATE public.clubs SET balance = balance + v_prize WHERE id = v_standing.club_id;
        INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
        VALUES (v_standing.club_id, v_prize, (SELECT balance FROM public.clubs WHERE id = v_standing.club_id),
          'premio', 'Prêmio de final de temporada: ' || v_rank || 'º lugar - Série ' || v_season.league);
      END IF;

      -- Promotion/relegation
      IF v_rank <= 2 AND v_current_idx IS NOT NULL AND v_current_idx < array_length(v_leagues, 1) THEN
        v_new_league := v_leagues[v_current_idx + 1];
        UPDATE public.clubs SET league = v_new_league WHERE id = v_standing.club_id;
      ELSIF v_rank >= v_total - 1 AND v_current_idx IS NOT NULL AND v_current_idx > 1 THEN
        v_new_league := v_leagues[v_current_idx - 1];
        UPDATE public.clubs SET league = v_new_league WHERE id = v_standing.club_id;
      END IF;

      -- Age all players +1 year, update salary = 1% of market_value
      UPDATE public.players SET
        age = age + 1,
        salary = GREATEST(1000, market_value / 100)
      WHERE club_id = v_standing.club_id;

      -- Players 28+ start losing physical attributes
      UPDATE public.players SET
        velocidade = GREATEST(1, velocidade - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        forca = GREATEST(1, forca - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        resistencia = GREATEST(1, resistencia - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        forma = GREATEST(1, forma - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        potencial_velocidade = GREATEST(1, potencial_velocidade - CASE WHEN age > 30 THEN 1 ELSE 0 END),
        potencial_forca = GREATEST(1, potencial_forca - CASE WHEN age > 30 THEN 1 ELSE 0 END),
        potencial_resistencia = GREATEST(1, potencial_resistencia - CASE WHEN age > 30 THEN 1 ELSE 0 END),
        potencial_forma = GREATEST(1, potencial_forma - CASE WHEN age > 30 THEN 1 ELSE 0 END),
        -- Update market value based on age and attributes
        market_value = GREATEST(5000, market_value * CASE
          WHEN age <= 25 THEN 1.1
          WHEN age <= 28 THEN 1.0
          WHEN age <= 32 THEN 0.8
          ELSE 0.6
        END)
      WHERE club_id = v_standing.club_id AND age >= 28;

      -- Initialize new season
      PERFORM public.initialize_season_for_club(v_standing.club_id);
    END IF;
  END LOOP;
END;
$function$;

-- Update initialize_season to use Bot names and scale difficulty
CREATE OR REPLACE FUNCTION public.initialize_season_for_club(p_club_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_club record;
  v_season_id uuid;
  v_npc_id uuid;
  v_rot_npc uuid[];
  v_temp_npc uuid;
  v_round integer;
  v_i integer;
  v_season_num integer;
  v_base_strength integer;
  v_strength integer;
BEGIN
  SELECT * INTO v_club FROM public.clubs WHERE id = p_club_id;
  IF v_club IS NULL THEN RAISE EXCEPTION 'Club not found'; END IF;

  SELECT COALESCE(MAX(season_number), 0) + 1 INTO v_season_num
  FROM public.seasons WHERE league = v_club.league;

  INSERT INTO public.seasons (league, division, season_number, total_rounds)
  VALUES (v_club.league, v_club.division, v_season_num, 38)
  RETURNING id INTO v_season_id;

  -- Base strength by league (F=very easy, A=hard)
  v_base_strength := CASE v_club.league
    WHEN 'F' THEN 10 WHEN 'E' THEN 20 WHEN 'D' THEN 30
    WHEN 'C' THEN 40 WHEN 'B' THEN 50 WHEN 'A' THEN 60
    ELSE 15 END;

  v_rot_npc := array_fill(NULL::uuid, ARRAY[19]);

  FOR v_i IN 1..19 LOOP
    v_strength := v_base_strength + floor(random() * 15)::int - 5;
    INSERT INTO public.npc_clubs (name, abbreviation, league, division, strength, fan_base, season_id)
    VALUES (
      'Bot ' || LPAD(v_i::text, 2, '0'),
      'B' || LPAD(v_i::text, 2, '0'),
      v_club.league, v_club.division,
      v_strength,
      30 + floor(random() * 70)::int, v_season_id
    )
    RETURNING id INTO v_npc_id;
    v_rot_npc[v_i] := v_npc_id;
  END LOOP;

  -- Create standings
  INSERT INTO public.league_standings (season_id, club_id) VALUES (v_season_id, p_club_id);
  FOR v_i IN 1..19 LOOP
    INSERT INTO public.league_standings (season_id, npc_club_id) VALUES (v_season_id, v_rot_npc[v_i]);
  END LOOP;

  -- Generate 38 rounds
  FOR v_round IN 1..19 LOOP
    IF v_round % 2 = 1 THEN
      INSERT INTO public.matches (season_id, round, home_club_id, away_npc_id, status)
      VALUES (v_season_id, v_round, p_club_id, v_rot_npc[19], 'scheduled');
      INSERT INTO public.matches (season_id, round, home_npc_id, away_club_id, status)
      VALUES (v_season_id, v_round + 19, v_rot_npc[19], p_club_id, 'scheduled');
    ELSE
      INSERT INTO public.matches (season_id, round, home_npc_id, away_club_id, status)
      VALUES (v_season_id, v_round, v_rot_npc[19], p_club_id, 'scheduled');
      INSERT INTO public.matches (season_id, round, home_club_id, away_npc_id, status)
      VALUES (v_season_id, v_round + 19, p_club_id, v_rot_npc[19], 'scheduled');
    END IF;

    FOR v_i IN 1..9 LOOP
      INSERT INTO public.matches (season_id, round, home_npc_id, away_npc_id, status)
      VALUES (v_season_id, v_round, v_rot_npc[v_i], v_rot_npc[19 - v_i], 'scheduled');
      INSERT INTO public.matches (season_id, round, home_npc_id, away_npc_id, status)
      VALUES (v_season_id, v_round + 19, v_rot_npc[19 - v_i], v_rot_npc[v_i], 'scheduled');
    END LOOP;

    v_temp_npc := v_rot_npc[19];
    FOR v_i IN REVERSE 19..2 LOOP
      v_rot_npc[v_i] := v_rot_npc[v_i - 1];
    END LOOP;
    v_rot_npc[1] := v_temp_npc;
  END LOOP;

  RETURN v_season_id;
END;
$function$;

-- Update patrimony max_level for stadium to 10 (= 100k seats)
UPDATE public.patrimony SET max_level = 10 WHERE type = 'estadio';
