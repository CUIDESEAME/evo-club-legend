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
  v_pos text;
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

      -- Trophies for top 3
      IF v_rank <= 3 THEN
        v_pos := CASE v_rank WHEN 1 THEN 'champion' WHEN 2 THEN 'runner_up' ELSE 'third' END;
        INSERT INTO public.club_trophies (club_id, trophy_type, position, season_number, competition_name)
        VALUES (v_standing.club_id, 'league', v_pos, v_season.season_number, 'Série ' || v_season.league);
      END IF;

      IF v_rank <= 2 AND v_current_idx IS NOT NULL AND v_current_idx < array_length(v_leagues, 1) THEN
        v_new_league := v_leagues[v_current_idx + 1];
        UPDATE public.clubs SET league = v_new_league WHERE id = v_standing.club_id;
      ELSIF v_rank >= v_total - 1 AND v_current_idx IS NOT NULL AND v_current_idx > 1 THEN
        v_new_league := v_leagues[v_current_idx - 1];
        UPDATE public.clubs SET league = v_new_league WHERE id = v_standing.club_id;
      END IF;

      UPDATE public.players SET
        age = age + 1,
        salary = GREATEST(1000, market_value / 100)
      WHERE club_id = v_standing.club_id;

      UPDATE public.players SET
        velocidade = GREATEST(1, velocidade - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        forca = GREATEST(1, forca - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        resistencia = GREATEST(1, resistencia - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        forma = GREATEST(1, forma - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        market_value = GREATEST(5000, (market_value * CASE
          WHEN age <= 25 THEN 1.1
          WHEN age <= 28 THEN 1.0
          WHEN age <= 32 THEN 0.8
          ELSE 0.6
        END)::bigint)
      WHERE club_id = v_standing.club_id AND age >= 28;

      PERFORM public.initialize_season_for_club(v_standing.club_id);
    END IF;
  END LOOP;
END;
$function$;