
-- Disciplinary events table
CREATE TABLE IF NOT EXISTS public.disciplinary_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL,
  player_id UUID NOT NULL,
  event_type TEXT NOT NULL,
  description TEXT NOT NULL,
  fine_amount BIGINT NOT NULL DEFAULT 0,
  weeks_suspended INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.disciplinary_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Disciplinary viewable by club owner"
ON public.disciplinary_events FOR SELECT
USING (EXISTS (SELECT 1 FROM clubs WHERE clubs.id = disciplinary_events.club_id AND clubs.user_id = auth.uid()));

-- Cup matches table
CREATE TABLE IF NOT EXISTS public.cup_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cup_id UUID NOT NULL,
  phase TEXT NOT NULL,
  home_club_id UUID,
  away_club_id UUID,
  home_score INTEGER,
  away_score INTEGER,
  status TEXT NOT NULL DEFAULT 'scheduled',
  played_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.cup_matches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Cup matches viewable by everyone"
ON public.cup_matches FOR SELECT USING (true);

-- Process weekly disciplinary events
CREATE OR REPLACE FUNCTION public.process_disciplinary_events()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  p RECORD;
  fine BIGINT;
  evt_type TEXT;
  evt_desc TEXT;
  weeks_sus INTEGER;
BEGIN
  FOR p IN
    SELECT pl.id, pl.club_id, pl.name, pl.agressividade, pl.salary
    FROM players pl
    JOIN clubs c ON c.id = pl.club_id
    WHERE pl.agressividade >= 10
  LOOP
    -- Probability scales with aggression: 10 = 5%, 16 = 20%
    IF random() < ((p.agressividade - 9) * 0.025) THEN
      IF random() < 0.5 THEN
        evt_type := 'agressao';
        evt_desc := p.name || ' se envolveu em briga em treino';
        fine := GREATEST(p.salary * 2, 20000);
        weeks_sus := 1 + floor(random() * 2)::int;
      ELSE
        evt_type := 'multa';
        evt_desc := p.name || ' recebeu multa por indisciplina';
        fine := GREATEST(p.salary, 10000);
        weeks_sus := 0;
      END IF;

      INSERT INTO disciplinary_events (club_id, player_id, event_type, description, fine_amount, weeks_suspended)
      VALUES (p.club_id, p.id, evt_type, evt_desc, fine, weeks_sus);

      UPDATE clubs SET balance = balance - fine WHERE id = p.club_id;
      INSERT INTO financial_transactions (club_id, type, description, amount, balance_after)
      SELECT p.club_id, 'expense', '⚠️ ' || evt_desc, -fine, balance FROM clubs WHERE id = p.club_id;

      IF weeks_sus > 0 THEN
        UPDATE players SET fadiga = LEAST(100, fadiga + 50), moral = GREATEST(0, moral - 10) WHERE id = p.id;
      ELSE
        UPDATE players SET moral = GREATEST(0, moral - 5) WHERE id = p.id;
      END IF;
    END IF;
  END LOOP;
END;
$$;

-- Cup phase progression
CREATE OR REPLACE FUNCTION public.advance_cup_phase(p_cup_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
  winner UUID;
  winners UUID[] := '{}';
  match_count INTEGER;
BEGIN
  SELECT * INTO cup_rec FROM cups WHERE id = p_cup_id;
  IF cup_rec.status = 'finished' THEN RETURN jsonb_build_object('status', 'finished'); END IF;

  -- Check current open phase
  SELECT phase INTO current_phase FROM cup_matches
  WHERE cup_id = p_cup_id AND status = 'scheduled' LIMIT 1;

  IF current_phase IS NULL THEN
    -- Start with quarterfinals from registered entries
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

  -- Simulate all matches in current phase
  FOR home_id, away_id IN
    SELECT home_club_id, away_club_id FROM cup_matches
    WHERE cup_id = p_cup_id AND phase = current_phase AND status = 'scheduled'
  LOOP
    hs := floor(random() * 4)::int;
    as_score := floor(random() * 4)::int;
    IF hs = as_score THEN
      IF random() < 0.5 THEN hs := hs + 1; ELSE as_score := as_score + 1; END IF;
    END IF;
    winner := CASE WHEN hs > as_score THEN home_id ELSE away_id END;
    winners := array_append(winners, winner);

    UPDATE cup_matches SET home_score = hs, away_score = as_score, status = 'played', played_at = now()
    WHERE cup_id = p_cup_id AND phase = current_phase AND home_club_id = home_id AND away_club_id = away_id;
  END LOOP;

  match_count := array_length(winners, 1);

  IF match_count = 1 THEN
    -- Final played, winner takes champion prize, loser runner-up
    UPDATE clubs SET balance = balance + cup_rec.champion_prize WHERE id = winners[1];
    INSERT INTO financial_transactions (club_id, type, description, amount, balance_after)
    SELECT winners[1], 'income', '🏆 Campeão ' || cup_rec.name, cup_rec.champion_prize, balance FROM clubs WHERE id = winners[1];

    UPDATE cups SET status = 'finished' WHERE id = p_cup_id;
    RETURN jsonb_build_object('status', 'finished', 'champion', winners[1]);
  END IF;

  -- Determine next phase
  next_phase := CASE
    WHEN match_count >= 4 THEN 'semi'
    WHEN match_count = 2 THEN 'final'
    ELSE 'final'
  END;

  -- If we just finished semis, pay semifinalist losers
  IF current_phase = 'semi' THEN
    -- Pay losers semifinal_prize
    PERFORM 1;
    UPDATE clubs SET balance = balance + cup_rec.semifinal_prize
    WHERE id IN (
      SELECT CASE WHEN home_score > away_score THEN away_club_id ELSE home_club_id END
      FROM cup_matches WHERE cup_id = p_cup_id AND phase = 'semi'
    );
  END IF;

  -- Pair winners for next phase
  FOR i IN 1..(match_count / 2) LOOP
    INSERT INTO cup_matches (cup_id, phase, home_club_id, away_club_id)
    VALUES (p_cup_id, next_phase, winners[i*2-1], winners[i*2]);
  END LOOP;

  RETURN jsonb_build_object('status', 'advanced', 'phase', next_phase, 'remaining', match_count / 2);
END;
$$;

-- Agent renegotiation logic
CREATE OR REPLACE FUNCTION public.process_agent_negotiations()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  a RECORD;
  weeks_since INTEGER;
  raise_amount BIGINT;
BEGIN
  FOR a IN
    SELECT pa.id, pa.player_id, pa.signed_at, pa.fee_pct, p.club_id, p.name, p.salary, p.moral
    FROM player_agents pa
    JOIN players p ON p.id = pa.player_id
  LOOP
    weeks_since := EXTRACT(EPOCH FROM (now() - a.signed_at))::int / (7 * 24 * 3600);
    IF weeks_since > 0 AND weeks_since % 8 = 0 THEN
      raise_amount := GREATEST(a.salary / 10, 1000);
      UPDATE players SET salary = salary + raise_amount WHERE id = a.player_id;
      INSERT INTO disciplinary_events (club_id, player_id, event_type, description, fine_amount, weeks_suspended)
      VALUES (a.club_id, a.player_id, 'renegociacao',
              'Agente de ' || a.name || ' exigiu reajuste salarial (+' || raise_amount || ')', 0, 0);
    END IF;
  END LOOP;
END;
$$;
