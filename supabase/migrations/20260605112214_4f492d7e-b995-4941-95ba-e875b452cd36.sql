-- Record a trophy when a real club wins a cup (kept permanently)
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
    hstr := public.cup_team_strength(home_id, v_u20) + 5;
    astr := public.cup_team_strength(away_id, v_u20);

    hs := LEAST(GREATEST(0, floor(random() * (hstr::float / 22.0 + 1.0))::int), 7);
    as_score := LEAST(GREATEST(0, floor(random() * (astr::float / 22.0 + 1.0))::int), 7);

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
    -- prize transaction + permanent trophy only for real clubs
    IF EXISTS (SELECT 1 FROM clubs WHERE id = winners[1]) THEN
      INSERT INTO financial_transactions (club_id, type, description, amount, balance_after)
      SELECT winners[1], 'income', '🏆 Campeão ' || cup_rec.name, cup_rec.champion_prize, balance FROM clubs WHERE id = winners[1];
      INSERT INTO club_trophies (club_id, trophy_type, position, season_number, competition_name)
      VALUES (winners[1], 'cup', 'champion', 0, cup_rec.name);
    END IF;
    UPDATE cup_entries SET reached_phase = 'campeao' WHERE cup_id = p_cup_id AND club_id = winners[1];
    UPDATE cups SET status = 'finished' WHERE id = p_cup_id;
    RETURN jsonb_build_object('status', 'finished', 'champion', winners[1]);
  END IF;

  next_phase := CASE WHEN match_count >= 4 THEN 'semi' ELSE 'final' END;

  IF current_phase = 'semi' THEN
    UPDATE clubs SET balance = balance + cup_rec.semifinal_prize
    WHERE id IN (
      SELECT CASE WHEN home_score > away_score THEN away_club_id ELSE home_club_id END
      FROM cup_matches WHERE cup_id = p_cup_id AND phase = 'semi'
    );
  END IF;

  UPDATE cup_entries SET reached_phase = current_phase
  WHERE cup_id = p_cup_id AND status = 'active' AND club_id <> ALL(winners) AND reached_phase IS NULL;

  FOR i IN 1..(match_count / 2) LOOP
    INSERT INTO cup_matches (cup_id, phase, home_club_id, away_club_id)
    VALUES (p_cup_id, next_phase, winners[i*2-1], winners[i*2]);
  END LOOP;

  RETURN jsonb_build_object('status', 'advanced', 'phase', next_phase, 'remaining', match_count / 2);
END;
$$;

-- Automatic housekeeping: removes irrelevant history, keeps trophies & active state
CREATE OR REPLACE FUNCTION public.cleanup_old_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_seasons_removed integer := 0;
  v_txn_removed integer := 0;
  v_cups_recycled integer := 0;
BEGIN
  -- 1. Drop everything tied to seasons that are no longer active (old league history)
  DELETE FROM matches WHERE season_id IN (SELECT id FROM seasons WHERE status <> 'active');
  DELETE FROM league_standings WHERE season_id IN (SELECT id FROM seasons WHERE status <> 'active');
  DELETE FROM npc_clubs
    WHERE season_id IS NULL
       OR season_id NOT IN (SELECT id FROM seasons WHERE status = 'active');
  DELETE FROM seasons WHERE status <> 'active';
  GET DIAGNOSTICS v_seasons_removed = ROW_COUNT;

  -- 2. Keep only the 50 most recent money movements per club
  DELETE FROM financial_transactions ft
  WHERE ft.id IN (
    SELECT id FROM (
      SELECT id, row_number() OVER (PARTITION BY club_id ORDER BY created_at DESC) AS rn
      FROM financial_transactions
    ) t WHERE t.rn > 50
  );
  GET DIAGNOSTICS v_txn_removed = ROW_COUNT;

  -- 3. Old disciplinary records are no longer relevant
  DELETE FROM disciplinary_events WHERE created_at < now() - interval '7 days';

  -- 4. Recycle finished cups into a fresh edition (trophies already saved).
  --    Clear all matches and NPC entries; keep any real-club entries re-activated.
  DELETE FROM cup_matches WHERE cup_id IN (SELECT id FROM cups WHERE status = 'finished');
  DELETE FROM cup_entries
    WHERE cup_id IN (SELECT id FROM cups WHERE status = 'finished')
      AND club_id NOT IN (SELECT id FROM clubs);
  UPDATE cup_entries SET reached_phase = NULL, status = 'active', prize_received = 0
    WHERE cup_id IN (SELECT id FROM cups WHERE status = 'finished');
  UPDATE cups SET status = 'open', starts_at = now() WHERE status = 'finished';
  GET DIAGNOSTICS v_cups_recycled = ROW_COUNT;

  RETURN jsonb_build_object(
    'seasons_cleaned', v_seasons_removed,
    'transactions_trimmed', v_txn_removed,
    'cups_recycled', v_cups_recycled
  );
END;
$$;