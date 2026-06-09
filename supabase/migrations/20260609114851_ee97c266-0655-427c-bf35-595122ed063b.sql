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
  v_total_capacity bigint;
  v_full_gate bigint;
  v_home_fans integer;
  v_home_members integer;
  v_demand numeric;
  v_attend_pct numeric;
BEGIN
  FOR v_season IN SELECT * FROM public.seasons WHERE status = 'active' FOR UPDATE LOOP
    FOR v_match IN
      SELECT * FROM public.matches
      WHERE season_id = v_season.id AND round = v_season.current_round AND status = 'scheduled'
      FOR UPDATE
    LOOP
      IF v_match.home_club_id IS NOT NULL THEN
        SELECT id INTO v_lineup_id FROM public.lineups WHERE club_id = v_match.home_club_id LIMIT 1;
        IF v_lineup_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.lineup_players WHERE lineup_id = v_lineup_id) THEN
          SELECT COALESCE((AVG(((p.reflexos + p.posicionamento + p.jogo_aereo + p.desarme + p.armacao + p.passe + p.tecnica + p.chute) / 8.0 * 0.7) + ((p.velocidade + p.forca + p.resistencia + p.forma) / 4.0 * 0.3)) * 10)::integer, 30)
          INTO v_home_strength
          FROM public.lineup_players lp JOIN public.players p ON p.id = lp.player_id
          WHERE lp.lineup_id = v_lineup_id AND p.is_injured = false;
        ELSE
          SELECT COALESCE((AVG(((reflexos + posicionamento + jogo_aereo + desarme + armacao + passe + tecnica + chute) / 8.0 * 0.7) + ((velocidade + forca + resistencia + forma) / 4.0 * 0.3)) * 10)::integer, 30)
          INTO v_home_strength FROM public.players WHERE club_id = v_match.home_club_id AND is_injured = false;
        END IF;
      ELSE
        SELECT strength INTO v_home_strength FROM public.npc_clubs WHERE id = v_match.home_npc_id;
      END IF;

      IF v_match.away_club_id IS NOT NULL THEN
        SELECT id INTO v_lineup_id FROM public.lineups WHERE club_id = v_match.away_club_id LIMIT 1;
        IF v_lineup_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.lineup_players WHERE lineup_id = v_lineup_id) THEN
          SELECT COALESCE((AVG(((p.reflexos + p.posicionamento + p.jogo_aereo + p.desarme + p.armacao + p.passe + p.tecnica + p.chute) / 8.0 * 0.7) + ((p.velocidade + p.forca + p.resistencia + p.forma) / 4.0 * 0.3)) * 10)::integer, 30)
          INTO v_away_strength
          FROM public.lineup_players lp JOIN public.players p ON p.id = lp.player_id
          WHERE lp.lineup_id = v_lineup_id AND p.is_injured = false;
        ELSE
          SELECT COALESCE((AVG(((reflexos + posicionamento + jogo_aereo + desarme + armacao + passe + tecnica + chute) / 8.0 * 0.7) + ((velocidade + forca + resistencia + forma) / 4.0 * 0.3)) * 10)::integer, 30)
          INTO v_away_strength FROM public.players WHERE club_id = v_match.away_club_id AND is_injured = false;
        END IF;
      ELSE
        SELECT strength INTO v_away_strength FROM public.npc_clubs WHERE id = v_match.away_npc_id;
      END IF;

      v_home_strength := COALESCE(v_home_strength, 30) + 4;
      v_away_strength := COALESCE(v_away_strength, 30);

      v_home_score := LEAST(GREATEST(0, floor(random() * (v_home_strength::float / 35.0 + 1.1))::int), 5);
      v_away_score := LEAST(GREATEST(0, floor(random() * (v_away_strength::float / 35.0 + 1.0))::int), 5);

      v_revenue := 0;
      IF v_match.home_club_id IS NOT NULL THEN
        SELECT COALESCE(SUM(capacity), 0),
               COALESCE(SUM(CASE seat_type WHEN 'camarote' THEN capacity * 180 WHEN 'cadeira' THEN capacity * 70 ELSE capacity * 25 END), 0)
          INTO v_total_capacity, v_full_gate
        FROM public.stadium_sectors WHERE club_id = v_match.home_club_id;

        SELECT fans, members INTO v_home_fans, v_home_members FROM public.clubs WHERE id = v_match.home_club_id;

        IF v_total_capacity > 0 THEN
          v_demand := GREATEST(0, COALESCE(v_home_fans, 0) * 0.35 + COALESCE(v_home_members, 0) * 4);
          v_attend_pct := LEAST(0.85, (v_demand / GREATEST(v_total_capacity, 1)) * (0.65 + random() * 0.35));
          v_revenue := (v_full_gate * v_attend_pct)::bigint - (v_total_capacity * 5)::bigint;
          v_revenue := LEAST(GREATEST(v_revenue, 0), 250000);
        END IF;
      END IF;

      UPDATE public.matches
      SET home_score = v_home_score, away_score = v_away_score, status = 'played', revenue = v_revenue, played_at = now()
      WHERE id = v_match.id;

      IF v_match.home_club_id IS NOT NULL THEN
        UPDATE public.league_standings SET played = played + 1, goals_for = goals_for + v_home_score, goals_against = goals_against + v_away_score, wins = wins + CASE WHEN v_home_score > v_away_score THEN 1 ELSE 0 END, draws = draws + CASE WHEN v_home_score = v_away_score THEN 1 ELSE 0 END, losses = losses + CASE WHEN v_home_score < v_away_score THEN 1 ELSE 0 END, points = points + CASE WHEN v_home_score > v_away_score THEN 3 WHEN v_home_score = v_away_score THEN 1 ELSE 0 END WHERE season_id = v_season.id AND club_id = v_match.home_club_id;
      ELSE
        UPDATE public.league_standings SET played = played + 1, goals_for = goals_for + v_home_score, goals_against = goals_against + v_away_score, wins = wins + CASE WHEN v_home_score > v_away_score THEN 1 ELSE 0 END, draws = draws + CASE WHEN v_home_score = v_away_score THEN 1 ELSE 0 END, losses = losses + CASE WHEN v_home_score < v_away_score THEN 1 ELSE 0 END, points = points + CASE WHEN v_home_score > v_away_score THEN 3 WHEN v_home_score = v_away_score THEN 1 ELSE 0 END WHERE season_id = v_season.id AND npc_club_id = v_match.home_npc_id;
      END IF;

      IF v_match.away_club_id IS NOT NULL THEN
        UPDATE public.league_standings SET played = played + 1, goals_for = goals_for + v_away_score, goals_against = goals_against + v_home_score, wins = wins + CASE WHEN v_away_score > v_home_score THEN 1 ELSE 0 END, draws = draws + CASE WHEN v_away_score = v_home_score THEN 1 ELSE 0 END, losses = losses + CASE WHEN v_away_score < v_home_score THEN 1 ELSE 0 END, points = points + CASE WHEN v_away_score > v_home_score THEN 3 WHEN v_away_score = v_home_score THEN 1 ELSE 0 END WHERE season_id = v_season.id AND club_id = v_match.away_club_id;
      ELSE
        UPDATE public.league_standings SET played = played + 1, goals_for = goals_for + v_away_score, goals_against = goals_against + v_home_score, wins = wins + CASE WHEN v_away_score > v_home_score THEN 1 ELSE 0 END, draws = draws + CASE WHEN v_away_score = v_home_score THEN 1 ELSE 0 END, losses = losses + CASE WHEN v_away_score < v_home_score THEN 1 ELSE 0 END, points = points + CASE WHEN v_away_score > v_home_score THEN 3 WHEN v_away_score = v_home_score THEN 1 ELSE 0 END WHERE season_id = v_season.id AND npc_club_id = v_match.away_npc_id;
      END IF;

      IF v_match.home_club_id IS NOT NULL THEN
        v_prize := CASE WHEN v_home_score > v_away_score THEN 8000 WHEN v_home_score = v_away_score THEN 3000 ELSE 0 END;
        IF v_revenue + v_prize > 0 THEN
          UPDATE public.clubs SET balance = balance + v_revenue + v_prize WHERE id = v_match.home_club_id;
          SELECT balance INTO v_new_balance FROM public.clubs WHERE id = v_match.home_club_id;
          INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
          VALUES (v_match.home_club_id, v_revenue + v_prize, v_new_balance, 'partida', 'Renda (' || v_revenue || ') + prêmio (' || v_prize || '): ' || v_home_score || 'x' || v_away_score);
        END IF;
      END IF;

      IF v_match.away_club_id IS NOT NULL THEN
        v_prize := CASE WHEN v_away_score > v_home_score THEN 8000 WHEN v_away_score = v_home_score THEN 3000 ELSE 0 END;
        IF v_prize > 0 THEN
          UPDATE public.clubs SET balance = balance + v_prize WHERE id = v_match.away_club_id;
          SELECT balance INTO v_new_balance FROM public.clubs WHERE id = v_match.away_club_id;
          INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
          VALUES (v_match.away_club_id, v_prize, v_new_balance, 'partida', 'Prêmio fora: ' || v_away_score || 'x' || v_home_score);
        END IF;
      END IF;

      v_matches_played := v_matches_played + 1;
    END LOOP;

    UPDATE public.seasons SET current_round = current_round + 1 WHERE id = v_season.id AND current_round < total_rounds;
  END LOOP;

  RETURN jsonb_build_object('matches_played', v_matches_played);
END;
$function$;