
GRANT SELECT ON public.club_trophies TO anon, authenticated;
GRANT ALL ON public.club_trophies TO service_role;

-- Build a single shared season with all real clubs + minimal bots
CREATE OR REPLACE FUNCTION public.setup_shared_season()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_league text := 'A';
  v_season_id uuid;
  v_season_num integer;
  v_real_count integer;
  v_target integer;
  v_bots integer;
  v_slots text[] := '{}';
  v_npc_id uuid;
  v_i integer;
  v_n integer;
  v_round integer;
  v_leg integer;
  v_arr text[];
  v_tmp text;
  v_home text;
  v_away text;
  v_hc uuid; v_ac uuid; v_hn uuid; v_an uuid;
  v_rnum integer := 0;
  v_club record;
BEGIN
  -- Unify all real clubs into one league/division so they meet each other
  UPDATE public.clubs SET league = v_league, division = 1;

  SELECT count(*) INTO v_real_count FROM public.clubs;
  v_target := GREATEST(8, v_real_count);
  IF v_target % 2 = 1 THEN v_target := v_target + 1; END IF;
  v_bots := v_target - v_real_count;

  SELECT COALESCE(MAX(season_number), 0) + 1 INTO v_season_num FROM public.seasons;

  INSERT INTO public.seasons (league, division, season_number, total_rounds, current_round, status)
  VALUES (v_league, 1, v_season_num, 2 * (v_target - 1), 1, 'active')
  RETURNING id INTO v_season_id;

  -- Real clubs as slots + standings
  FOR v_club IN SELECT id FROM public.clubs LOOP
    v_slots := array_append(v_slots, 'C:' || v_club.id::text);
    INSERT INTO public.league_standings (season_id, club_id) VALUES (v_season_id, v_club.id);
  END LOOP;

  -- Minimal bots to fill remaining slots
  FOR v_i IN 1..v_bots LOOP
    INSERT INTO public.npc_clubs (name, abbreviation, league, division, strength, fan_base, season_id)
    VALUES ('Bot ' || LPAD(v_i::text, 2, '0'), 'B' || LPAD(v_i::text, 2, '0'),
            v_league, 1, 45 + floor(random() * 25)::int, 200 + floor(random() * 400)::int, v_season_id)
    RETURNING id INTO v_npc_id;
    v_slots := array_append(v_slots, 'N:' || v_npc_id::text);
    INSERT INTO public.league_standings (season_id, npc_club_id) VALUES (v_season_id, v_npc_id);
  END LOOP;

  v_n := array_length(v_slots, 1);

  -- Double round-robin via circle method
  FOR v_leg IN 1..2 LOOP
    v_arr := v_slots;
    FOR v_round IN 1..(v_n - 1) LOOP
      v_rnum := v_rnum + 1;
      FOR v_i IN 1..(v_n / 2) LOOP
        v_home := v_arr[v_i];
        v_away := v_arr[v_n + 1 - v_i];
        IF (v_round + v_i) % 2 = 0 THEN
          v_tmp := v_home; v_home := v_away; v_away := v_tmp;
        END IF;
        IF v_leg = 2 THEN
          v_tmp := v_home; v_home := v_away; v_away := v_tmp;
        END IF;
        v_hc := NULL; v_ac := NULL; v_hn := NULL; v_an := NULL;
        IF left(v_home, 2) = 'C:' THEN v_hc := substr(v_home, 3)::uuid; ELSE v_hn := substr(v_home, 3)::uuid; END IF;
        IF left(v_away, 2) = 'C:' THEN v_ac := substr(v_away, 3)::uuid; ELSE v_an := substr(v_away, 3)::uuid; END IF;
        INSERT INTO public.matches (season_id, round, home_club_id, away_club_id, home_npc_id, away_npc_id, status)
        VALUES (v_season_id, v_rnum, v_hc, v_ac, v_hn, v_an, 'scheduled');
      END LOOP;
      -- rotate slots 2..n, keep slot 1 fixed
      v_tmp := v_arr[v_n];
      FOR v_i IN REVERSE v_n..3 LOOP
        v_arr[v_i] := v_arr[v_i - 1];
      END LOOP;
      v_arr[2] := v_tmp;
    END LOOP;
  END LOOP;

  RETURN v_season_id;
END;
$function$;

-- Joining/creating a club rebuilds the shared season to include everyone
CREATE OR REPLACE FUNCTION public.initialize_season_for_club(p_club_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- Mark any active season completed so a fresh shared one is built
  UPDATE public.seasons SET status = 'completed' WHERE status = 'active';
  RETURN public.setup_shared_season();
END;
$function$;

-- End the shared season: prizes, trophies, aging, then start a new one
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
  v_prize bigint;
  v_pos text;
BEGIN
  SELECT * INTO v_season FROM public.seasons WHERE id = p_season_id;
  IF v_season IS NULL OR v_season.status <> 'active' THEN RETURN; END IF;
  UPDATE public.seasons SET status = 'completed' WHERE id = p_season_id;

  FOR v_standing IN
    SELECT * FROM public.league_standings
    WHERE season_id = p_season_id
    ORDER BY points DESC, (goals_for - goals_against) DESC, goals_for DESC
  LOOP
    v_rank := v_rank + 1;
    IF v_standing.club_id IS NOT NULL THEN
      v_prize := CASE
        WHEN v_rank = 1 THEN 500000
        WHEN v_rank = 2 THEN 300000
        WHEN v_rank = 3 THEN 150000
        WHEN v_rank <= 5 THEN 50000
        ELSE 0 END;
      IF v_prize > 0 THEN
        UPDATE public.clubs SET balance = balance + v_prize WHERE id = v_standing.club_id;
        INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
        VALUES (v_standing.club_id, v_prize, (SELECT balance FROM public.clubs WHERE id = v_standing.club_id),
          'premio', 'Prêmio de temporada: ' || v_rank || 'º lugar');
      END IF;

      IF v_rank <= 3 THEN
        v_pos := CASE v_rank WHEN 1 THEN 'champion' WHEN 2 THEN 'runner_up' ELSE 'third' END;
        INSERT INTO public.club_trophies (club_id, trophy_type, position, season_number, competition_name)
        VALUES (v_standing.club_id, 'league', v_pos, v_season.season_number, 'Liga Nacional');
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
          ELSE 0.6 END)::bigint)
      WHERE club_id = v_standing.club_id AND age >= 28;
    END IF;
  END LOOP;

  PERFORM public.setup_shared_season();
END;
$function$;

-- One-time reset: wipe old separate seasons and start a shared season now
DELETE FROM public.matches;
DELETE FROM public.league_standings;
DELETE FROM public.npc_clubs;
DELETE FROM public.seasons;
SELECT public.setup_shared_season();
