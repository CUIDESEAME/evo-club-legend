
-- Seasons table
CREATE TABLE public.seasons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  league text NOT NULL DEFAULT 'F',
  division integer NOT NULL DEFAULT 1,
  season_number integer NOT NULL DEFAULT 1,
  current_round integer NOT NULL DEFAULT 1,
  total_rounds integer NOT NULL DEFAULT 38,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.seasons ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Seasons viewable by everyone" ON public.seasons FOR SELECT TO public USING (true);

-- NPC clubs table
CREATE TABLE public.npc_clubs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  abbreviation text NOT NULL,
  league text NOT NULL DEFAULT 'F',
  division integer NOT NULL DEFAULT 1,
  strength integer NOT NULL DEFAULT 30,
  fan_base integer NOT NULL DEFAULT 50,
  season_id uuid REFERENCES public.seasons(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.npc_clubs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "NPC clubs viewable by everyone" ON public.npc_clubs FOR SELECT TO public USING (true);

-- League standings
CREATE TABLE public.league_standings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id uuid REFERENCES public.seasons(id) ON DELETE CASCADE NOT NULL,
  club_id uuid REFERENCES public.clubs(id) ON DELETE CASCADE,
  npc_club_id uuid REFERENCES public.npc_clubs(id) ON DELETE CASCADE,
  played integer NOT NULL DEFAULT 0,
  wins integer NOT NULL DEFAULT 0,
  draws integer NOT NULL DEFAULT 0,
  losses integer NOT NULL DEFAULT 0,
  goals_for integer NOT NULL DEFAULT 0,
  goals_against integer NOT NULL DEFAULT 0,
  points integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT standings_has_team CHECK (club_id IS NOT NULL OR npc_club_id IS NOT NULL)
);
ALTER TABLE public.league_standings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Standings viewable by everyone" ON public.league_standings FOR SELECT TO public USING (true);

-- Matches table
CREATE TABLE public.matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id uuid REFERENCES public.seasons(id) ON DELETE CASCADE NOT NULL,
  round integer NOT NULL DEFAULT 1,
  home_club_id uuid REFERENCES public.clubs(id) ON DELETE CASCADE,
  home_npc_id uuid REFERENCES public.npc_clubs(id) ON DELETE CASCADE,
  away_club_id uuid REFERENCES public.clubs(id) ON DELETE CASCADE,
  away_npc_id uuid REFERENCES public.npc_clubs(id) ON DELETE CASCADE,
  home_score integer,
  away_score integer,
  status text NOT NULL DEFAULT 'scheduled',
  revenue bigint NOT NULL DEFAULT 0,
  played_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT match_has_home CHECK (home_club_id IS NOT NULL OR home_npc_id IS NOT NULL),
  CONSTRAINT match_has_away CHECK (away_club_id IS NOT NULL OR away_npc_id IS NOT NULL)
);
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Matches viewable by everyone" ON public.matches FOR SELECT TO public USING (true);

-- NPC name pool for Brazilian clubs
CREATE OR REPLACE FUNCTION public.initialize_season_for_club(p_club_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_club record;
  v_season_id uuid;
  v_npc_ids uuid[];
  v_npc_id uuid;
  v_all_team_ids uuid[];
  v_i integer;
  v_j integer;
  v_round integer;
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
  v_strengths integer[];
BEGIN
  SELECT * INTO v_club FROM public.clubs WHERE id = p_club_id;
  IF v_club IS NULL THEN
    RAISE EXCEPTION 'Club not found';
  END IF;

  -- Create season
  INSERT INTO public.seasons (league, division, season_number)
  VALUES (v_club.league, v_club.division, 1)
  RETURNING id INTO v_season_id;

  -- Generate varied NPC strengths (20-50 range for Serie F)
  v_npc_ids := ARRAY[]::uuid[];
  FOR v_i IN 1..19 LOOP
    INSERT INTO public.npc_clubs (name, abbreviation, league, division, strength, fan_base, season_id)
    VALUES (
      v_npc_names[v_i],
      v_npc_abbrevs[v_i],
      v_club.league,
      v_club.division,
      20 + floor(random() * 31)::int,
      30 + floor(random() * 70)::int,
      v_season_id
    )
    RETURNING id INTO v_npc_id;
    v_npc_ids := array_append(v_npc_ids, v_npc_id);
  END LOOP;

  -- Create standings for real club
  INSERT INTO public.league_standings (season_id, club_id)
  VALUES (v_season_id, p_club_id);

  -- Create standings for NPCs
  FOR v_i IN 1..19 LOOP
    INSERT INTO public.league_standings (season_id, npc_club_id)
    VALUES (v_season_id, v_npc_ids[v_i]);
  END LOOP;

  -- Schedule round 1: player club plays first NPC at home
  INSERT INTO public.matches (season_id, round, home_club_id, away_npc_id, status)
  VALUES (v_season_id, 1, p_club_id, v_npc_ids[1], 'scheduled');

  -- Schedule NPC vs NPC for round 1 (9 matches for remaining 18 NPCs)
  FOR v_i IN 1..9 LOOP
    INSERT INTO public.matches (season_id, round, home_npc_id, away_npc_id, status)
    VALUES (v_season_id, 1, v_npc_ids[v_i * 2], v_npc_ids[v_i * 2 + 1], 'scheduled');
  END LOOP;

  RETURN v_season_id;
END;
$$;

-- Match simulation function (called by game loop)
CREATE OR REPLACE FUNCTION public.simulate_matches()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match record;
  v_home_strength integer;
  v_away_strength integer;
  v_home_score integer;
  v_away_score integer;
  v_home_club_id uuid;
  v_away_club_id uuid;
  v_home_npc_id uuid;
  v_away_npc_id uuid;
  v_revenue bigint;
  v_prize bigint;
  v_matches_played integer := 0;
  v_season record;
  v_next_round integer;
  v_npc_ids uuid[];
  v_club_id uuid;
  v_i integer;
BEGIN
  -- Process all scheduled matches
  FOR v_match IN
    SELECT * FROM public.matches WHERE status = 'scheduled' FOR UPDATE
  LOOP
    -- Calculate home strength
    IF v_match.home_club_id IS NOT NULL THEN
      SELECT COALESCE(
        (SELECT (AVG(
          (reflexos + posicionamento + jogo_aereo + desarme + armacao + passe + tecnica + chute) / 8.0 * 0.7 +
          (velocidade + forca + resistencia + forma) / 4.0 * 0.3
        ) * 10)::integer
        FROM public.players WHERE club_id = v_match.home_club_id AND is_injured = false),
        30
      ) INTO v_home_strength;
    ELSE
      SELECT strength INTO v_home_strength FROM public.npc_clubs WHERE id = v_match.home_npc_id;
    END IF;

    IF v_match.away_club_id IS NOT NULL THEN
      SELECT COALESCE(
        (SELECT (AVG(
          (reflexos + posicionamento + jogo_aereo + desarme + armacao + passe + tecnica + chute) / 8.0 * 0.7 +
          (velocidade + forca + resistencia + forma) / 4.0 * 0.3
        ) * 10)::integer
        FROM public.players WHERE club_id = v_match.away_club_id AND is_injured = false),
        30
      ) INTO v_away_strength;
    ELSE
      SELECT strength INTO v_away_strength FROM public.npc_clubs WHERE id = v_match.away_npc_id;
    END IF;

    -- Home advantage (+5)
    v_home_strength := v_home_strength + 5;

    -- Simulate score: strength determines average goals (0-4 range)
    v_home_score := GREATEST(0, floor(random() * (v_home_strength::float / 20.0 + 1.5))::int);
    v_away_score := GREATEST(0, floor(random() * (v_away_strength::float / 20.0 + 1.5))::int);

    -- Cap at 7 goals
    v_home_score := LEAST(v_home_score, 7);
    v_away_score := LEAST(v_away_score, 7);

    -- Calculate revenue for home real club
    v_revenue := 0;
    IF v_match.home_club_id IS NOT NULL THEN
      SELECT COALESCE(SUM(capacity), 0) * 10 INTO v_revenue
      FROM public.stadium_sectors WHERE club_id = v_match.home_club_id;
    END IF;

    -- Update match
    UPDATE public.matches
    SET home_score = v_home_score, away_score = v_away_score,
        status = 'played', revenue = v_revenue, played_at = now()
    WHERE id = v_match.id;

    -- Update home standings
    IF v_match.home_club_id IS NOT NULL THEN
      UPDATE public.league_standings SET
        played = played + 1,
        goals_for = goals_for + v_home_score,
        goals_against = goals_against + v_away_score,
        wins = wins + CASE WHEN v_home_score > v_away_score THEN 1 ELSE 0 END,
        draws = draws + CASE WHEN v_home_score = v_away_score THEN 1 ELSE 0 END,
        losses = losses + CASE WHEN v_home_score < v_away_score THEN 1 ELSE 0 END,
        points = points + CASE WHEN v_home_score > v_away_score THEN 3 WHEN v_home_score = v_away_score THEN 1 ELSE 0 END
      WHERE season_id = v_match.season_id AND club_id = v_match.home_club_id;
    ELSE
      UPDATE public.league_standings SET
        played = played + 1,
        goals_for = goals_for + v_home_score,
        goals_against = goals_against + v_away_score,
        wins = wins + CASE WHEN v_home_score > v_away_score THEN 1 ELSE 0 END,
        draws = draws + CASE WHEN v_home_score = v_away_score THEN 1 ELSE 0 END,
        losses = losses + CASE WHEN v_home_score < v_away_score THEN 1 ELSE 0 END,
        points = points + CASE WHEN v_home_score > v_away_score THEN 3 WHEN v_home_score = v_away_score THEN 1 ELSE 0 END
      WHERE season_id = v_match.season_id AND npc_club_id = v_match.home_npc_id;
    END IF;

    -- Update away standings
    IF v_match.away_club_id IS NOT NULL THEN
      UPDATE public.league_standings SET
        played = played + 1,
        goals_for = goals_for + v_away_score,
        goals_against = goals_against + v_home_score,
        wins = wins + CASE WHEN v_away_score > v_home_score THEN 1 ELSE 0 END,
        draws = draws + CASE WHEN v_away_score = v_home_score THEN 1 ELSE 0 END,
        losses = losses + CASE WHEN v_away_score < v_home_score THEN 1 ELSE 0 END,
        points = points + CASE WHEN v_away_score > v_home_score THEN 3 WHEN v_away_score = v_home_score THEN 1 ELSE 0 END
      WHERE season_id = v_match.season_id AND club_id = v_match.away_club_id;
    ELSE
      UPDATE public.league_standings SET
        played = played + 1,
        goals_for = goals_for + v_away_score,
        goals_against = goals_against + v_home_score,
        wins = wins + CASE WHEN v_away_score > v_home_score THEN 1 ELSE 0 END,
        draws = draws + CASE WHEN v_away_score = v_home_score THEN 1 ELSE 0 END,
        losses = losses + CASE WHEN v_away_score < v_home_score THEN 1 ELSE 0 END,
        points = points + CASE WHEN v_away_score > v_home_score THEN 3 WHEN v_away_score = v_home_score THEN 1 ELSE 0 END
      WHERE season_id = v_match.season_id AND npc_club_id = v_match.away_npc_id;
    END IF;

    -- Award revenue + prize to real clubs
    IF v_match.home_club_id IS NOT NULL THEN
      v_prize := CASE WHEN v_home_score > v_away_score THEN 15000 WHEN v_home_score = v_away_score THEN 5000 ELSE 0 END;
      UPDATE public.clubs SET balance = balance + v_revenue + v_prize WHERE id = v_match.home_club_id;
      IF v_revenue + v_prize > 0 THEN
        INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
        SELECT v_match.home_club_id, v_revenue + v_prize, balance, 'partida',
          'Renda + prêmio: ' || v_home_score || 'x' || v_away_score
        FROM public.clubs WHERE id = v_match.home_club_id;
      END IF;
    END IF;

    IF v_match.away_club_id IS NOT NULL THEN
      v_prize := CASE WHEN v_away_score > v_home_score THEN 15000 WHEN v_away_score = v_home_score THEN 5000 ELSE 0 END;
      UPDATE public.clubs SET balance = balance + v_prize WHERE id = v_match.away_club_id;
      IF v_prize > 0 THEN
        INSERT INTO public.financial_transactions (club_id, amount, balance_after, type, description)
        SELECT v_match.away_club_id, v_prize, balance, 'partida',
          'Prêmio fora: ' || v_away_score || 'x' || v_home_score
        FROM public.clubs WHERE id = v_match.away_club_id;
      END IF;
    END IF;

    v_matches_played := v_matches_played + 1;
  END LOOP;

  -- Schedule next round for each active season
  FOR v_season IN SELECT * FROM public.seasons WHERE status = 'active' FOR UPDATE LOOP
    -- Check if all matches of current round are played
    IF NOT EXISTS (
      SELECT 1 FROM public.matches
      WHERE season_id = v_season.id AND round = v_season.current_round AND status = 'scheduled'
    ) THEN
      v_next_round := v_season.current_round + 1;

      IF v_next_round > v_season.total_rounds THEN
        UPDATE public.seasons SET status = 'completed' WHERE id = v_season.id;
      ELSE
        UPDATE public.seasons SET current_round = v_next_round WHERE id = v_season.id;

        -- Find the real club in this season
        SELECT club_id INTO v_club_id FROM public.league_standings
        WHERE season_id = v_season.id AND club_id IS NOT NULL LIMIT 1;

        -- Get all NPC ids
        SELECT array_agg(id ORDER BY random()) INTO v_npc_ids
        FROM public.npc_clubs WHERE season_id = v_season.id;

        -- Schedule: real club vs NPC (alternating home/away)
        IF v_club_id IS NOT NULL AND array_length(v_npc_ids, 1) >= v_next_round THEN
          IF v_next_round % 2 = 1 THEN
            INSERT INTO public.matches (season_id, round, home_club_id, away_npc_id, status)
            VALUES (v_season.id, v_next_round, v_club_id, v_npc_ids[((v_next_round - 1) % 19) + 1], 'scheduled');
          ELSE
            INSERT INTO public.matches (season_id, round, home_npc_id, away_club_id, status)
            VALUES (v_season.id, v_next_round, v_npc_ids[((v_next_round - 1) % 19) + 1], v_club_id, 'scheduled');
          END IF;
        END IF;

        -- Schedule NPC vs NPC (pair remaining NPCs)
        -- Simple round-robin pairing for NPCs
        FOR v_i IN 1..9 LOOP
          IF v_i * 2 + 1 <= array_length(v_npc_ids, 1) THEN
            INSERT INTO public.matches (season_id, round, home_npc_id, away_npc_id, status)
            VALUES (v_season.id, v_next_round, v_npc_ids[v_i * 2], v_npc_ids[v_i * 2 + 1], 'scheduled');
          END IF;
        END LOOP;
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('matches_played', v_matches_played);
END;
$$;
