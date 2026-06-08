
-- Build a single 12-slot division season for a league, given real club ids.
CREATE OR REPLACE FUNCTION public.build_division_season(p_league text, p_division integer, p_clubs uuid[])
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
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

  -- Real clubs occupy the first slots
  IF p_clubs IS NOT NULL THEN
    FOREACH v_cid IN ARRAY p_clubs LOOP
      UPDATE public.clubs SET league = p_league, division = p_division WHERE id = v_cid;
      v_slots := array_append(v_slots, 'C:' || v_cid::text);
      INSERT INTO public.league_standings (season_id, club_id) VALUES (v_season_id, v_cid);
    END LOOP;
  END IF;

  -- Fill the rest with city-named bots (distinct names within this season)
  v_offset := floor(random() * array_length(v_cities,1))::int;
  WHILE COALESCE(array_length(v_slots,1),0) < v_size LOOP
    v_city := v_cities[1 + ((v_offset + COALESCE(array_length(v_slots,1),0)) % array_length(v_cities,1))];
    INSERT INTO public.npc_clubs (name, abbreviation, league, division, strength, fan_base, season_id)
    VALUES (v_city, UPPER(LEFT(v_city,3)), p_league, p_division,
            45 + floor(random()*20)::int, 100, v_season_id)
    RETURNING id INTO v_npc_id;
    v_slots := array_append(v_slots, 'N:' || v_npc_id::text);
    INSERT INTO public.league_standings (season_id, npc_club_id) VALUES (v_season_id, v_npc_id);
  END LOOP;

  -- Double round-robin via circle method
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
$$;

-- Build all division seasons from current club placements.
CREATE OR REPLACE FUNCTION public.setup_division_seasons()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
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
  FOREACH v_league IN ARRAY v_leagues LOOP
    SELECT array_agg(id ORDER BY created_at) INTO v_real
      FROM public.clubs WHERE league = v_league;
    v_real_count := COALESCE(array_length(v_real,1),0);
    IF v_real_count = 0 THEN CONTINUE; END IF;
    v_num_div := CEIL(v_real_count::numeric / v_size);
    FOR v_div IN 1..v_num_div LOOP
      v_slice := v_real[((v_div-1)*v_size+1) : (v_div*v_size)];
      PERFORM public.build_division_season(v_league, v_div, v_slice);
    END LOOP;
  END LOOP;
END;
$$;

-- New club joins league F: take a bot's spot, or open a new F division.
CREATE OR REPLACE FUNCTION public.initialize_season_for_club(p_club_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_standing record;
  v_season_id uuid;
  v_npc_id uuid;
  v_division integer;
BEGIN
  UPDATE public.clubs SET league = 'F' WHERE id = p_club_id;

  -- Find a bot slot in an active F-division season
  SELECT ls.npc_club_id, ls.season_id
    INTO v_npc_id, v_season_id
  FROM public.league_standings ls
  JOIN public.seasons s ON s.id = ls.season_id
  WHERE s.status = 'active' AND s.league = 'F'
    AND ls.npc_club_id IS NOT NULL
  ORDER BY s.division
  LIMIT 1;

  IF v_npc_id IS NOT NULL THEN
    SELECT division INTO v_division FROM public.seasons WHERE id = v_season_id;
    -- Swap the bot for the real club in all of this season's fixtures
    UPDATE public.matches SET home_club_id = p_club_id, home_npc_id = NULL
      WHERE season_id = v_season_id AND home_npc_id = v_npc_id;
    UPDATE public.matches SET away_club_id = p_club_id, away_npc_id = NULL
      WHERE season_id = v_season_id AND away_npc_id = v_npc_id;
    UPDATE public.league_standings
      SET club_id = p_club_id, npc_club_id = NULL,
          played = 0, wins = 0, draws = 0, losses = 0,
          goals_for = 0, goals_against = 0, points = 0
      WHERE season_id = v_season_id AND npc_club_id = v_npc_id;
    DELETE FROM public.npc_clubs WHERE id = v_npc_id;
    UPDATE public.clubs SET division = v_division WHERE id = p_club_id;
    RETURN v_season_id;
  END IF;

  -- No bot slot available: open a new F division for this club
  SELECT COALESCE(MAX(division),0)+1 INTO v_division
    FROM public.seasons WHERE status = 'active' AND league = 'F';
  RETURN public.build_division_season('F', v_division, ARRAY[p_club_id]);
END;
$$;

-- End a season: prizes, trophies, promotion/relegation; rebuild when all done.
CREATE OR REPLACE FUNCTION public.end_season(p_season_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
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
  SELECT * INTO v_season FROM public.seasons WHERE id = p_season_id;
  IF v_season IS NULL OR v_season.status <> 'active' THEN RETURN; END IF;
  UPDATE public.seasons SET status = 'completed' WHERE id = p_season_id;

  v_up := CASE v_season.league WHEN 'F' THEN 'E' WHEN 'E' THEN 'D' WHEN 'D' THEN 'C' WHEN 'C' THEN 'B' WHEN 'B' THEN 'A' ELSE 'A' END;
  v_down := CASE v_season.league WHEN 'A' THEN 'B' WHEN 'B' THEN 'C' WHEN 'C' THEN 'D' WHEN 'D' THEN 'E' WHEN 'E' THEN 'F' ELSE 'F' END;

  SELECT count(*) INTO v_real_total FROM public.league_standings
    WHERE season_id = p_season_id AND club_id IS NOT NULL;

  FOR v_standing IN
    SELECT * FROM public.league_standings
    WHERE season_id = p_season_id
    ORDER BY points DESC, (goals_for - goals_against) DESC, goals_for DESC
  LOOP
    v_rank := v_rank + 1;
    IF v_standing.club_id IS NOT NULL THEN
      v_real_rank := v_real_rank + 1;

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
        VALUES (v_standing.club_id, 'league', v_pos, v_season.season_number, 'Série ' || v_season.league);
      END IF;

      -- Promotion / relegation among REAL clubs only
      IF v_real_rank <= 2 AND v_season.league <> 'A' THEN
        UPDATE public.clubs SET league = v_up WHERE id = v_standing.club_id;
      ELSIF v_real_rank > v_real_total - 2 AND v_season.league <> 'F' THEN
        UPDATE public.clubs SET league = v_down WHERE id = v_standing.club_id;
      END IF;

      -- Aging / value adjustment
      UPDATE public.players SET age = age + 1, salary = GREATEST(1000, market_value / 100)
        WHERE club_id = v_standing.club_id;
      UPDATE public.players SET
        velocidade = GREATEST(1, velocidade - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        forca = GREATEST(1, forca - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        resistencia = GREATEST(1, resistencia - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        forma = GREATEST(1, forma - CASE WHEN age > 32 THEN 2 WHEN age > 28 THEN 1 ELSE 0 END),
        market_value = GREATEST(5000, (market_value * CASE
          WHEN age <= 25 THEN 1.1 WHEN age <= 28 THEN 1.0 WHEN age <= 32 THEN 0.8 ELSE 0.6 END)::bigint)
      WHERE club_id = v_standing.club_id AND age >= 28;
    END IF;
  END LOOP;

  -- Once every season is finished, rebuild all divisions with new placements
  SELECT count(*) INTO v_remaining FROM public.seasons WHERE status = 'active';
  IF v_remaining = 0 THEN
    PERFORM public.setup_division_seasons();
  END IF;
END;
$$;
