-- Make simulate_matches use the team's lineup (11 players) when one exists,
-- falling back to average of all fit players otherwise.
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
  v_lineup_id uuid;
BEGIN
  FOR v_season IN SELECT * FROM public.seasons WHERE status = 'active' FOR UPDATE LOOP
    FOR v_match IN
      SELECT * FROM public.matches
      WHERE season_id = v_season.id AND round = v_season.current_round AND status = 'scheduled'
      FOR UPDATE
    LOOP
      -- Home strength (use lineup if set)
      IF v_match.home_club_id IS NOT NULL THEN
        SELECT id INTO v_lineup_id FROM public.lineups WHERE club_id = v_match.home_club_id LIMIT 1;
        IF v_lineup_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.lineup_players WHERE lineup_id = v_lineup_id) THEN
          SELECT COALESCE((AVG(
            (p.reflexos + p.posicionamento + p.jogo_aereo + p.desarme + p.armacao + p.passe + p.tecnica + p.chute) / 8.0 * 0.7 +
            (p.velocidade + p.forca + p.resistencia + p.forma) / 4.0 * 0.3
          ) * 10)::integer, 30)
          INTO v_home_strength
          FROM public.lineup_players lp
          JOIN public.players p ON p.id = lp.player_id
          WHERE lp.lineup_id = v_lineup_id AND p.is_injured = false;
        ELSE
          SELECT COALESCE(
            (SELECT (AVG(
              (reflexos + posicionamento + jogo_aereo + desarme + armacao + passe + tecnica + chute) / 8.0 * 0.7 +
              (velocidade + forca + resistencia + forma) / 4.0 * 0.3
            ) * 10)::integer
            FROM public.players WHERE club_id = v_match.home_club_id AND is_injured = false), 30
          ) INTO v_home_strength;
        END IF;
      ELSE
        SELECT strength INTO v_home_strength FROM public.npc_clubs WHERE id = v_match.home_npc_id;
      END IF;

      -- Away strength (use lineup if set)
      IF v_match.away_club_id IS NOT NULL THEN
        SELECT id INTO v_lineup_id FROM public.lineups WHERE club_id = v_match.away_club_id LIMIT 1;
        IF v_lineup_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.lineup_players WHERE lineup_id = v_lineup_id) THEN
          SELECT COALESCE((AVG(
            (p.reflexos + p.posicionamento + p.jogo_aereo + p.desarme + p.armacao + p.passe + p.tecnica + p.chute) / 8.0 * 0.7 +
            (p.velocidade + p.forca + p.resistencia + p.forma) / 4.0 * 0.3
          ) * 10)::integer, 30)
          INTO v_away_strength
          FROM public.lineup_players lp
          JOIN public.players p ON p.id = lp.player_id
          WHERE lp.lineup_id = v_lineup_id AND p.is_injured = false;
        ELSE
          SELECT COALESCE(
            (SELECT (AVG(
              (reflexos + posicionamento + jogo_aereo + desarme + armacao + passe + tecnica + chute) / 8.0 * 0.7 +
              (velocidade + forca + resistencia + forma) / 4.0 * 0.3
            ) * 10)::integer
            FROM public.players WHERE club_id = v_match.away_club_id AND is_injured = false), 30
          ) INTO v_away_strength;
        END IF;
      ELSE
        SELECT strength INTO v_away_strength FROM public.npc_clubs WHERE id = v_match.away_npc_id;
      END IF;

      v_home_strength := v_home_strength + 5;

      v_home_score := LEAST(GREATEST(0, floor(random() * (v_home_strength::float / 20.0 + 1.5))::int), 7);
      v_away_score := LEAST(GREATEST(0, floor(random() * (v_away_strength::float / 20.0 + 1.5))::int), 7);

      -- Revenue
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

      -- Standings (home)
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

      -- Standings (away)
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

      v_matches_played := v_matches_played + 1;
    END LOOP;

    UPDATE public.seasons SET current_round = current_round + 1
    WHERE id = v_season.id AND current_round < total_rounds;
  END LOOP;

  RETURN jsonb_build_object('matches_played', v_matches_played);
END;
$function$;

-- Sporadic events: random weekly events per club (donation/loss/material)
CREATE OR REPLACE FUNCTION public.process_sporadic_events()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_club record;
  v_roll integer;
  v_amount bigint;
  v_new_balance bigint;
  v_count integer := 0;
BEGIN
  FOR v_club IN SELECT id, balance FROM public.clubs LOOP
    -- 12% chance per week
    IF random() < 0.12 THEN
      v_roll := floor(random() * 4)::int;
      IF v_roll = 0 THEN
        v_amount := 5000 + floor(random() * 20000)::int;
        UPDATE public.clubs SET balance = balance + v_amount WHERE id = v_club.id;
        SELECT balance INTO v_new_balance FROM public.clubs WHERE id = v_club.id;
        INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
        VALUES (v_club.id, v_amount, v_new_balance, 'evento', 'Doação de torcedor');
      ELSIF v_roll = 1 THEN
        v_amount := 3000 + floor(random() * 12000)::int;
        UPDATE public.clubs SET balance = balance - v_amount WHERE id = v_club.id;
        SELECT balance INTO v_new_balance FROM public.clubs WHERE id = v_club.id;
        INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
        VALUES (v_club.id, -v_amount, v_new_balance, 'evento', 'Material esportivo extra');
      ELSIF v_roll = 2 THEN
        v_amount := 8000 + floor(random() * 25000)::int;
        UPDATE public.clubs SET balance = balance + v_amount WHERE id = v_club.id;
        SELECT balance INTO v_new_balance FROM public.clubs WHERE id = v_club.id;
        INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
        VALUES (v_club.id, v_amount, v_new_balance, 'evento', 'Patrocínio pontual');
      ELSE
        v_amount := 2000 + floor(random() * 8000)::int;
        UPDATE public.clubs SET balance = balance - v_amount WHERE id = v_club.id;
        SELECT balance INTO v_new_balance FROM public.clubs WHERE id = v_club.id;
        INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
        VALUES (v_club.id, -v_amount, v_new_balance, 'evento', 'Manutenção emergencial');
      END IF;
      v_count := v_count + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('events', v_count);
END;
$function$;