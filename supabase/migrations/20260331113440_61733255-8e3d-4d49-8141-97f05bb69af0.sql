
-- Timestamp update function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Profiles table
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL UNIQUE,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles viewable by everyone" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = user_id);

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (user_id, username)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || LEFT(NEW.id::text, 8)));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Clubs table
CREATE TABLE public.clubs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  abbreviation TEXT NOT NULL CHECK (LENGTH(abbreviation) <= 4),
  balance BIGINT NOT NULL DEFAULT 500000,
  fans INTEGER NOT NULL DEFAULT 100,
  members INTEGER NOT NULL DEFAULT 10,
  league TEXT NOT NULL DEFAULT 'F',
  division INTEGER NOT NULL DEFAULT 1,
  founded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.clubs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Clubs viewable by everyone" ON public.clubs FOR SELECT USING (true);
CREATE POLICY "Users can insert own club" ON public.clubs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own club" ON public.clubs FOR UPDATE USING (auth.uid() = user_id);

CREATE TRIGGER update_clubs_updated_at BEFORE UPDATE ON public.clubs
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Position enum
CREATE TYPE public.player_position AS ENUM (
  'goleiro', 'libero', 'zagueiro', 'lateral', 'volante',
  'meia', 'ala', 'meia_atacante', 'ponteiro', 'atacante'
);

-- Players table
CREATE TABLE public.players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  age INTEGER NOT NULL CHECK (age >= 15 AND age <= 42),
  position public.player_position NOT NULL,
  is_captain BOOLEAN NOT NULL DEFAULT false,
  salary BIGINT NOT NULL DEFAULT 5000,
  market_value BIGINT NOT NULL DEFAULT 50000,
  reflexos INTEGER NOT NULL DEFAULT 1 CHECK (reflexos BETWEEN 1 AND 16),
  posicionamento INTEGER NOT NULL DEFAULT 1 CHECK (posicionamento BETWEEN 1 AND 16),
  jogo_aereo INTEGER NOT NULL DEFAULT 1 CHECK (jogo_aereo BETWEEN 1 AND 16),
  desarme INTEGER NOT NULL DEFAULT 1 CHECK (desarme BETWEEN 1 AND 16),
  armacao INTEGER NOT NULL DEFAULT 1 CHECK (armacao BETWEEN 1 AND 16),
  passe INTEGER NOT NULL DEFAULT 1 CHECK (passe BETWEEN 1 AND 16),
  tecnica INTEGER NOT NULL DEFAULT 1 CHECK (tecnica BETWEEN 1 AND 16),
  chute INTEGER NOT NULL DEFAULT 1 CHECK (chute BETWEEN 1 AND 16),
  velocidade INTEGER NOT NULL DEFAULT 1 CHECK (velocidade BETWEEN 1 AND 9),
  forca INTEGER NOT NULL DEFAULT 1 CHECK (forca BETWEEN 1 AND 9),
  resistencia INTEGER NOT NULL DEFAULT 1 CHECK (resistencia BETWEEN 1 AND 9),
  forma INTEGER NOT NULL DEFAULT 1 CHECK (forma BETWEEN 1 AND 9),
  experiencia INTEGER NOT NULL DEFAULT 1 CHECK (experiencia BETWEEN 1 AND 16),
  lideranca INTEGER NOT NULL DEFAULT 1 CHECK (lideranca BETWEEN 1 AND 5),
  inteligencia INTEGER NOT NULL DEFAULT 1 CHECK (inteligencia BETWEEN 1 AND 5),
  agressividade INTEGER NOT NULL DEFAULT 1 CHECK (agressividade BETWEEN 1 AND 5),
  honestidade INTEGER NOT NULL DEFAULT 1 CHECK (honestidade BETWEEN 1 AND 5),
  entrosamento INTEGER NOT NULL DEFAULT 0 CHECK (entrosamento BETWEEN 0 AND 100),
  moral INTEGER NOT NULL DEFAULT 50 CHECK (moral BETWEEN 0 AND 100),
  talento INTEGER NOT NULL DEFAULT 3 CHECK (talento BETWEEN 1 AND 10),
  potencial_velocidade INTEGER NOT NULL DEFAULT 5 CHECK (potencial_velocidade BETWEEN 1 AND 9),
  potencial_forca INTEGER NOT NULL DEFAULT 5 CHECK (potencial_forca BETWEEN 1 AND 9),
  potencial_resistencia INTEGER NOT NULL DEFAULT 5 CHECK (potencial_resistencia BETWEEN 1 AND 9),
  potencial_forma INTEGER NOT NULL DEFAULT 5 CHECK (potencial_forma BETWEEN 1 AND 9),
  is_injured BOOLEAN NOT NULL DEFAULT false,
  injury_weeks INTEGER NOT NULL DEFAULT 0,
  is_for_sale BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Players viewable by everyone" ON public.players FOR SELECT USING (true);
CREATE POLICY "Club owners can insert players" ON public.players FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));
CREATE POLICY "Club owners can update players" ON public.players FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));
CREATE POLICY "Club owners can delete players" ON public.players FOR DELETE
  USING (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));

CREATE INDEX idx_players_club_id ON public.players(club_id);

CREATE TRIGGER update_players_updated_at BEFORE UPDATE ON public.players
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Patrimony table
CREATE TABLE public.patrimony (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  level INTEGER NOT NULL DEFAULT 0,
  max_level INTEGER NOT NULL DEFAULT 10,
  construction_weeks_remaining INTEGER NOT NULL DEFAULT 0,
  maintenance_cost BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(club_id, type)
);

ALTER TABLE public.patrimony ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patrimony viewable by everyone" ON public.patrimony FOR SELECT USING (true);
CREATE POLICY "Club owners can insert patrimony" ON public.patrimony FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));
CREATE POLICY "Club owners can update patrimony" ON public.patrimony FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));

CREATE INDEX idx_patrimony_club_id ON public.patrimony(club_id);

CREATE TRIGGER update_patrimony_updated_at BEFORE UPDATE ON public.patrimony
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Stadium sectors
CREATE TABLE public.stadium_sectors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  sector_name TEXT NOT NULL,
  structure TEXT NOT NULL DEFAULT 'geral',
  seat_type TEXT NOT NULL DEFAULT 'geral',
  capacity INTEGER NOT NULL DEFAULT 100,
  ring INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(club_id, sector_name, ring)
);

ALTER TABLE public.stadium_sectors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Stadium viewable by everyone" ON public.stadium_sectors FOR SELECT USING (true);
CREATE POLICY "Club owners can manage stadium" ON public.stadium_sectors FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));
CREATE POLICY "Club owners can update stadium" ON public.stadium_sectors FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));

CREATE INDEX idx_stadium_club_id ON public.stadium_sectors(club_id);

-- Training config
CREATE TABLE public.training_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL UNIQUE REFERENCES public.clubs(id) ON DELETE CASCADE,
  physical_type TEXT NOT NULL DEFAULT 'geral',
  physical_intensity INTEGER NOT NULL DEFAULT 50 CHECK (physical_intensity BETWEEN 0 AND 100),
  technical_type TEXT NOT NULL DEFAULT 'defesa',
  coach_level INTEGER NOT NULL DEFAULT 1 CHECK (coach_level BETWEEN 1 AND 10),
  fitness_coach_level INTEGER NOT NULL DEFAULT 1 CHECK (fitness_coach_level BETWEEN 1 AND 10),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.training_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Training viewable by club owner" ON public.training_config FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));
CREATE POLICY "Club owners can insert training" ON public.training_config FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));
CREATE POLICY "Club owners can update training" ON public.training_config FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));

CREATE TRIGGER update_training_updated_at BEFORE UPDATE ON public.training_config
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Financial transactions
CREATE TABLE public.financial_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  description TEXT NOT NULL,
  amount BIGINT NOT NULL,
  balance_after BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.financial_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Transactions viewable by club owner" ON public.financial_transactions FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));
CREATE POLICY "Club owners can insert transactions" ON public.financial_transactions FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));

CREATE INDEX idx_transactions_club_id ON public.financial_transactions(club_id);
CREATE INDEX idx_transactions_created_at ON public.financial_transactions(created_at);

-- Juniors
CREATE TABLE public.juniors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  age INTEGER NOT NULL DEFAULT 15 CHECK (age >= 14 AND age <= 19),
  position public.player_position NOT NULL,
  quality INTEGER NOT NULL DEFAULT 1 CHECK (quality BETWEEN 1 AND 100),
  weeks_to_reveal INTEGER NOT NULL DEFAULT 8,
  talento INTEGER NOT NULL DEFAULT 3 CHECK (talento BETWEEN 1 AND 10),
  revealed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.juniors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Juniors viewable by club owner" ON public.juniors FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));
CREATE POLICY "Club owners can manage juniors" ON public.juniors FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));
CREATE POLICY "Club owners can update juniors" ON public.juniors FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));
CREATE POLICY "Club owners can delete juniors" ON public.juniors FOR DELETE
  USING (EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND user_id = auth.uid()));

CREATE INDEX idx_juniors_club_id ON public.juniors(club_id);
