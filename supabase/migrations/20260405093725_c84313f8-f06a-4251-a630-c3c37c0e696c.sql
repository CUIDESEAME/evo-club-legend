-- Lineup system: store each club's starting 11 and formation
CREATE TABLE public.lineups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id uuid NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  formation text NOT NULL DEFAULT '4-4-2',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(club_id)
);

CREATE TABLE public.lineup_players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lineup_id uuid NOT NULL REFERENCES public.lineups(id) ON DELETE CASCADE,
  player_id uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
  position_slot integer NOT NULL, -- 1-11
  position_override text, -- optional override of player's natural position
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(lineup_id, position_slot),
  UNIQUE(lineup_id, player_id)
);

ALTER TABLE public.lineups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lineup_players ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lineups viewable by everyone" ON public.lineups FOR SELECT USING (true);
CREATE POLICY "Club owners can insert lineup" ON public.lineups FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM clubs WHERE clubs.id = lineups.club_id AND clubs.user_id = auth.uid())
);
CREATE POLICY "Club owners can update lineup" ON public.lineups FOR UPDATE USING (
  EXISTS (SELECT 1 FROM clubs WHERE clubs.id = lineups.club_id AND clubs.user_id = auth.uid())
);
CREATE POLICY "Club owners can delete lineup" ON public.lineups FOR DELETE USING (
  EXISTS (SELECT 1 FROM clubs WHERE clubs.id = lineups.club_id AND clubs.user_id = auth.uid())
);

CREATE POLICY "Lineup players viewable by everyone" ON public.lineup_players FOR SELECT USING (true);
CREATE POLICY "Club owners can manage lineup players" ON public.lineup_players FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM lineups l JOIN clubs c ON c.id = l.club_id WHERE l.id = lineup_players.lineup_id AND c.user_id = auth.uid())
);
CREATE POLICY "Club owners can update lineup players" ON public.lineup_players FOR UPDATE USING (
  EXISTS (SELECT 1 FROM lineups l JOIN clubs c ON c.id = l.club_id WHERE l.id = lineup_players.lineup_id AND c.user_id = auth.uid())
);
CREATE POLICY "Club owners can delete lineup players" ON public.lineup_players FOR DELETE USING (
  EXISTS (SELECT 1 FROM lineups l JOIN clubs c ON c.id = l.club_id WHERE l.id = lineup_players.lineup_id AND c.user_id = auth.uid())
);

-- Closed market: pre-generated players available for immediate purchase
CREATE TABLE public.market_closed (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  league text NOT NULL DEFAULT 'F',
  name text NOT NULL,
  age integer NOT NULL,
  position text NOT NULL,
  overall integer NOT NULL DEFAULT 30,
  price bigint NOT NULL DEFAULT 50000,
  salary bigint NOT NULL DEFAULT 5000,
  stats jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  purchased_by uuid REFERENCES public.clubs(id),
  purchased_at timestamptz
);

ALTER TABLE public.market_closed ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Market closed viewable by everyone" ON public.market_closed FOR SELECT USING (true);
CREATE POLICY "Authenticated can update market closed" ON public.market_closed FOR UPDATE TO authenticated USING (true);

-- Open market: auction system for player sales
CREATE TABLE public.market_open (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
  seller_club_id uuid NOT NULL REFERENCES public.clubs(id),
  min_price bigint NOT NULL DEFAULT 0,
  current_bid bigint DEFAULT 0,
  current_bidder_club_id uuid REFERENCES public.clubs(id),
  ends_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'active', -- active, sold, expired
  market_fee_pct integer NOT NULL DEFAULT 10,
  prize_reserve_pct integer NOT NULL DEFAULT 5,
  loan_system_pct integer NOT NULL DEFAULT 5,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.market_open ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Market open viewable by everyone" ON public.market_open FOR SELECT USING (true);
CREATE POLICY "Club owners can list players" ON public.market_open FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM clubs WHERE clubs.id = market_open.seller_club_id AND clubs.user_id = auth.uid())
);
CREATE POLICY "Authenticated can update market open" ON public.market_open FOR UPDATE TO authenticated USING (true);

-- Loan system fund: accumulates from market fees
CREATE TABLE public.system_funds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fund_type text NOT NULL UNIQUE, -- 'prize_reserve', 'loan_system'
  balance bigint NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.system_funds ENABLE ROW LEVEL SECURITY;
CREATE POLICY "System funds viewable by everyone" ON public.system_funds FOR SELECT USING (true);

INSERT INTO public.system_funds (fund_type, balance) VALUES ('prize_reserve', 0), ('loan_system', 1000000);
