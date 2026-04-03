
-- Fix process_game_week: cap interest to prevent exponential debt explosion
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
BEGIN
  FOR v_club IN SELECT * FROM public.clubs FOR UPDATE LOOP
    v_new_balance := v_club.balance;

    UPDATE public.patrimony
    SET construction_weeks_remaining = GREATEST(0, construction_weeks_remaining - 1)
    WHERE club_id = v_club.id AND construction_weeks_remaining > 0;

    UPDATE public.juniors
    SET weeks_to_reveal = GREATEST(0, weeks_to_reveal - 1),
        revealed = CASE WHEN weeks_to_reveal <= 1 THEN true ELSE revealed END
    WHERE club_id = v_club.id AND revealed = false;

    SELECT COALESCE(SUM(salary), 0) INTO v_salary_total
    FROM public.players WHERE club_id = v_club.id;
    v_new_balance := v_new_balance - v_salary_total;
    IF v_salary_total > 0 THEN
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_salary_total, v_new_balance, 'salarios', 'Pagamento semanal de salários');
    END IF;

    SELECT COALESCE(SUM(maintenance_cost), 0) INTO v_maintenance_total
    FROM public.patrimony WHERE club_id = v_club.id;
    v_new_balance := v_new_balance - v_maintenance_total;
    IF v_maintenance_total > 0 THEN
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_maintenance_total, v_new_balance, 'manutencao', 'Manutenção semanal do patrimônio');
    END IF;

    -- Interest with CAP to prevent exponential explosion
    IF v_new_balance < 0 THEN
      v_interest_rate := LEAST(5 + (ABS(v_new_balance) / 500000)::integer, 20);
      v_interest := ABS(v_new_balance) * v_interest_rate / 100;
      v_interest := LEAST(v_interest, 500000); -- max 500k interest per week
      v_new_balance := v_new_balance - v_interest;
      INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_club.id, -v_interest, v_new_balance, 'juros', 'Juros sobre saldo devedor (' || v_interest_rate || '%)');
    END IF;

    -- Training
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

-- Full round-robin season initialization for 20 teams
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
  v_rot_club uuid[];
  v_rot_npc uuid[];
  v_fixed_club uuid;
  v_temp_club uuid;
  v_temp_npc uuid;
  v_round integer;
  v_i integer;
  v_npc_names text[] := ARRAY[
    'Atlético Mineiro FC', 'Cruzeiro EC', 'América MG', 'Guarani FC',
    'Ponte Preta SC', 'XV de Piracicaba', 'Ferroviária SP', 'Noroeste FC',
    'Operário PR', 'Londrina EC', 'Coritiba FC', 'Paraná Clube',
    'Juventude RS', 'Novo Hamburgo', 'São José RS', 'Tombense MG',
    'Pouso Alegre', 'Caldense MG', 'Uberlândia EC'
  ];
  v_npc_abbrevs text[] := ARRAY[
    'ATL', 'CRU', 'AME', 'GUA', 'PON', 'XVP', 'FER', 'NOR',
    'OPE', 'LON', 'COR', 'PAR', 'JUV', 'NHB', 'SJR', 'TOM',
    'PAL', 'CAL', 'UBE'
  ];
  v_season_num integer;
BEGIN
  SELECT * INTO v_club FROM public.clubs WHERE id = p_club_id;
  IF v_club IS NULL THEN RAISE EXCEPTION 'Club not found'; END IF;

  -- Determine season number
  SELECT COALESCE(MAX(season_number), 0) + 1 INTO v_season_num
  FROM public.seasons WHERE league = v_club.league;

  INSERT INTO public.seasons (league, division, season_number, total_rounds)
  VALUES (v_club.league, v_club.division, v_season_num, 38)
  RETURNING id INTO v_season_id;

  -- Fixed team = real club
  v_fixed_club := p_club_id;

  -- Create 19 NPCs and build rotation arrays
  v_rot_club := array_fill(NULL::uuid, ARRAY[19]);
  v_rot_npc := array_fill(NULL::uuid, ARRAY[19]);

  FOR v_i IN 1..19 LOOP
    INSERT INTO public.npc_clubs (name, abbreviation, league, division, strength, fan_base, season_id)
    VALUES (
      v_npc_names[v_i], v_npc_abbrevs[v_i], v_club.league, v_club.division,
      20 + floor(random() * 31)::int, 30 + floor(random() * 70)::int, v_season_id
    )
    RETURNING id INTO v_npc_id;
    v_rot_npc[v_i] := v_npc_id;
  END LOOP;

  -- Create standings
  INSERT INTO public.league_standings (season_id, club_id) VALUES (v_season_id, p_club_id);
  FOR v_i IN 1..19 LOOP
    INSERT INTO public.league_standings (season_id, npc_club_id) VALUES (v_season_id, v_rot_npc[v_i]);
  END LOOP;

  -- Generate all 38 rounds using circle method
  FOR v_round IN 1..19 LOOP
    -- Match: fixed club vs rot[19] (last in rotation)
    IF v_round % 2 = 1 THEN
      -- First half: fixed is home
      INSERT INTO public.matches (season_id, round, home_club_id, away_npc_id, status)
      VALUES (v_season_id, v_round, v_fixed_club, v_rot_npc[19], 'scheduled');
      -- Second half: reverse
      INSERT INTO public.matches (season_id, round, home_npc_id, away_club_id, status)
      VALUES (v_season_id, v_round + 19, v_rot_npc[19], v_fixed_club, 'scheduled');
    ELSE
      INSERT INTO public.matches (season_id, round, home_npc_id, away_club_id, status)
      VALUES (v_season_id, v_round, v_rot_npc[19], v_fixed_club, 'scheduled');
      INSERT INTO public.matches (season_id, round, home_club_id, away_npc_id, status)
      VALUES (v_season_id, v_round + 19, v_fixed_club, v_rot_npc[19], 'scheduled');
    END IF;

    -- Remaining 9 matches: pair from edges of rotation array
    FOR v_i IN 1..9 LOOP
      -- First half
      INSERT INTO public.matches (season_id, round, home_npc_id, away_npc_id, status)
      VALUES (v_season_id, v_round, v_rot_npc[v_i], v_rot_npc[19 - v_i], 'scheduled');
      -- Second half (reversed home/away)
      INSERT INTO public.matches (season_id, round, home_npc_id, away_npc_id, status)
      VALUES (v_season_id, v_round + 19, v_rot_npc[19 - v_i], v_rot_npc[v_i], 'scheduled');
    END LOOP;

    -- Rotate right: last element goes to first
    v_temp_npc := v_rot_npc[19];
    FOR v_i IN REVERSE 19..2 LOOP
      v_rot_npc[v_i] := v_rot_npc[v_i - 1];
    END LOOP;
    v_rot_npc[1] := v_temp_npc;
  END LOOP;

  RETURN v_season_id;
END;
$function$;

-- Simulate matches: process current round for all active seasons
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

      v_home_strength := v_home_strength + 5; -- home advantage

      v_home_score := LEAST(GREATEST(0, floor(random() * (v_home_strength::float / 20.0 + 1.5))::int), 7);
      v_away_score := LEAST(GREATEST(0, floor(random() * (v_away_strength::float / 20.0 + 1.5))::int), 7);

      -- Revenue for home real club
      v_revenue := 0;
      IF v_match.home_club_id IS NOT NULL THEN
        SELECT COALESCE(SUM(capacity), 0) * 10 INTO v_revenue
        FROM public.stadium_sectors WHERE club_id = v_match.home_club_id;
      END IF;

      UPDATE public.matches
      SET home_score = v_home_score, away_score = v_away_score,
          status = 'played', revenue = v_revenue, played_at = now()
      WHERE id = v_match.id;

      -- Update home standings
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

      -- Update away standings
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

      -- Award revenue + prize to real clubs
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

      v_matches_played := v_matches_played + 1;
    END LOOP;

    -- Advance round if all matches played
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

-- End season: promotion/relegation + new season
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

      IF v_rank <= 2 AND v_current_idx IS NOT NULL AND v_current_idx < array_length(v_leagues, 1) THEN
        v_new_league := v_leagues[v_current_idx + 1];
        UPDATE public.clubs SET league = v_new_league WHERE id = v_standing.club_id;
      ELSIF v_rank >= v_total - 1 AND v_current_idx IS NOT NULL AND v_current_idx > 1 THEN
        v_new_league := v_leagues[v_current_idx - 1];
        UPDATE public.clubs SET league = v_new_league WHERE id = v_standing.club_id;
      END IF;

      -- Initialize new season for this club
      PERFORM public.initialize_season_for_club(v_standing.club_id);
    END IF;
  END LOOP;
END;
$function$;
