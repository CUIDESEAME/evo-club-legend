-- Helper: real strength of a cup participant (club lineup/squad or NPC), with U20 filter
CREATE OR REPLACE FUNCTION public.cup_team_strength(p_id uuid, p_u20 boolean)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v integer;
  v_is_club boolean;
BEGIN
  SELECT EXISTS(SELECT 1 FROM clubs WHERE id = p_id) INTO v_is_club;
  IF v_is_club THEN
    SELECT COALESCE((AVG(
      (reflexos + posicionamento + jogo_aereo + desarme + armacao + passe + tecnica + chute) / 8.0 * 0.7 +
      (velocidade + forca + resistencia + forma) / 4.0 * 0.3
    ) * 10)::integer, 30)
    INTO v
    FROM players
    WHERE club_id = p_id AND is_injured = false AND (NOT p_u20 OR age <= 20);
    RETURN COALESCE(v, 30);
  ELSE
    -- NPC strength is on a smaller scale; normalise it to the club attribute scale
    SELECT (strength * 2) INTO v FROM npc_clubs WHERE id = p_id;
    RETURN COALESCE(v, 80);
  END IF;
END;
$$;

-- Auto-fill an open cup up to 8 participants following the cup rules.
-- National: the strongest clubs from across the leagues.
-- U20: youth squads (NPC) + clubs, scored later using only players up to 20.
CREATE OR REPLACE FUNCTION public.populate_cup(p_cup_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_cup record;
  v_count integer;
  v_needed integer;
  v_npc record;
BEGIN
  SELECT * INTO v_cup FROM cups WHERE id = p_cup_id;
  IF v_cup IS NULL OR v_cup.status <> 'open' THEN
    RETURN jsonb_build_object('status', 'not_open');
  END IF;

  SELECT count(*) INTO v_count FROM cup_entries WHERE cup_id = p_cup_id AND status = 'active';
  v_needed := 8 - v_count;
  IF v_needed <= 0 THEN
    RETURN jsonb_build_object('status', 'full');
  END IF;

  -- Pick the strongest distinct-named NPC clubs not yet entered
  FOR v_npc IN
    SELECT id FROM (
      SELECT DISTINCT ON (name) id, strength FROM npc_clubs ORDER BY name, strength DESC
    ) d
    WHERE NOT EXISTS (
      SELECT 1 FROM cup_entries e WHERE e.cup_id = p_cup_id AND e.club_id = d.id
    )
    ORDER BY d.strength DESC
    LIMIT v_needed
  LOOP
    INSERT INTO cup_entries (cup_id, club_id, status) VALUES (p_cup_id, v_npc.id, 'active');
  END LOOP;

  RETURN jsonb_build_object('status', 'populated', 'added', v_needed);
END;
$$;

-- Rewrite advance_cup_phase: real strength-based scores (no longer pure random)
CREATE OR REPLACE FUNCTION public.advance_cup_phase(p_cup_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  cup_rec RECORD;
  current_phase TEXT;
  next_phase TEXT;
  participants UUID[];
  i INTEGER;
  home_id UUID;
  away_id UUID;
  hs INTEGER;
  as_score INTEGER;
  hstr INTEGER;
  astr INTEGER;
  winner UUID;
  winners UUID[] := '{}';
  match_count INTEGER;
  v_u20 BOOLEAN;
BEGIN
  SELECT * INTO cup_rec FROM cups WHERE id = p_cup_id;
  IF cup_rec.status = 'finished' THEN RETURN jsonb_build_object('status', 'finished'); END IF;
  v_u20 := (cup_rec.cup_type = 'u20');

  SELECT phase INTO current_phase FROM cup_matches
  WHERE cup_id = p_cup_id AND status = 'scheduled' LIMIT 1;

  IF current_phase IS NULL THEN
    SELECT array_agg(club_id ORDER BY random()) INTO participants
    FROM cup_entries WHERE cup_id = p_cup_id AND status = 'active';

    IF participants IS NULL OR array_length(participants, 1) < 2 THEN
      RETURN jsonb_build_object('status', 'not_enough_participants');
    END IF;

    next_phase := CASE
      WHEN array_length(participants, 1) >= 8 THEN 'quartas'
      WHEN array_length(participants, 1) >= 4 THEN 'semi'
      ELSE 'final'
    END;

    FOR i IN 1..(array_length(participants, 1) / 2) LOOP
      INSERT INTO cup_matches (cup_id, phase, home_club_id, away_club_id)
      VALUES (p_cup_id, next_phase, participants[i*2-1], participants[i*2]);
    END LOOP;

    UPDATE cups SET status = 'in_progress' WHERE id = p_cup_id;
    RETURN jsonb_build_object('status', 'started', 'phase', next_phase);
  END IF;

  FOR home_id, away_id IN
    SELECT home_club_id, away_club_id FROM cup_matches
    WHERE cup_id = p_cup_id AND phase = current_phase AND status = 'scheduled'
  LOOP
    hstr := public.cup_team_strength(home_id, v_u20) + 5; -- home advantage
    astr := public.cup_team_strength(away_id, v_u20);

    hs := LEAST(GREATEST(0, floor(random() * (hstr::float / 22.0 + 1.0))::int), 7);
    as_score := LEAST(GREATEST(0, floor(random() * (astr::float / 22.0 + 1.0))::int), 7);

    -- No draws in knockout: stronger side edges it (with some luck)
    IF hs = as_score THEN
      IF random() < (hstr::float / GREATEST(hstr + astr, 1)) THEN
        hs := hs + 1;
      ELSE
        as_score := as_score + 1;
      END IF;
    END IF;

    winner := CASE WHEN hs > as_score THEN home_id ELSE away_id END;
    winners := array_append(winners, winner);

    UPDATE cup_matches SET home_score = hs, away_score = as_score, status = 'played', played_at = now()
    WHERE cup_id = p_cup_id AND phase = current_phase AND home_club_id = home_id AND away_club_id = away_id;
  END LOOP;

  match_count := array_length(winners, 1);

  IF match_count = 1 THEN
    UPDATE clubs SET balance = balance + cup_rec.champion_prize WHERE id = winners[1];
    INSERT INTO financial_transactions (club_id, type, description, amount, balance_after)
    SELECT winners[1], 'income', '🏆 Campeão ' || cup_rec.name, cup_rec.champion_prize, balance FROM clubs WHERE id = winners[1];
    UPDATE cup_entries SET reached_phase = 'campeao' WHERE cup_id = p_cup_id AND club_id = winners[1];
    UPDATE cups SET status = 'finished' WHERE id = p_cup_id;
    RETURN jsonb_build_object('status', 'finished', 'champion', winners[1]);
  END IF;

  next_phase := CASE
    WHEN match_count >= 4 THEN 'semi'
    ELSE 'final'
  END;

  IF current_phase = 'semi' THEN
    UPDATE clubs SET balance = balance + cup_rec.semifinal_prize
    WHERE id IN (
      SELECT CASE WHEN home_score > away_score THEN away_club_id ELSE home_club_id END
      FROM cup_matches WHERE cup_id = p_cup_id AND phase = 'semi'
    );
  END IF;

  -- Track phase reached for entries that just lost this round
  UPDATE cup_entries SET reached_phase = current_phase
  WHERE cup_id = p_cup_id AND status = 'active' AND club_id <> ALL(winners) AND reached_phase IS NULL;

  FOR i IN 1..(match_count / 2) LOOP
    INSERT INTO cup_matches (cup_id, phase, home_club_id, away_club_id)
    VALUES (p_cup_id, next_phase, winners[i*2-1], winners[i*2]);
  END LOOP;

  RETURN jsonb_build_object('status', 'advanced', 'phase', next_phase, 'remaining', match_count / 2);
END;
$$;