
-- 1. Junior scouting by tier
CREATE OR REPLACE FUNCTION public.scout_junior(p_club_id uuid, p_tier text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_club record;
  v_cost bigint;
  v_min_q int;
  v_max_q int;
  v_min_t int;
  v_max_t int;
  v_quality int;
  v_talent int;
  v_age int;
  v_pos text;
  v_positions text[] := ARRAY['goleiro','zagueiro','lateral','volante','meia','atacante'];
  v_first text[] := ARRAY['Lucas','Pedro','Gabriel','Felipe','Matheus','Bruno','Diego','André','Caio','Vinícius','Thiago','Gustavo','Igor','Leonardo','João','Marcos','Davi','Enzo','Heitor','Murilo'];
  v_last text[] := ARRAY['Silva','Santos','Oliveira','Souza','Lima','Pereira','Almeida','Ferreira','Rocha','Nascimento','Araújo','Ribeiro','Cardoso','Moreira','Mendes','Barbosa','Gomes','Martins'];
  v_name text;
  v_new_balance bigint;
  v_count int;
  v_weeks int;
BEGIN
  SELECT * INTO v_club FROM clubs WHERE id = p_club_id FOR UPDATE;
  IF v_club IS NULL OR v_club.user_id != auth.uid() THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT COUNT(*) INTO v_count FROM juniors WHERE club_id = p_club_id;
  IF v_count >= 8 THEN RAISE EXCEPTION 'Base de juniores cheia (máx 8)'; END IF;

  CASE p_tier
    WHEN 'basico' THEN v_cost := 10000; v_min_q := 1; v_max_q := 3; v_min_t := 1; v_max_t := 4; v_weeks := 8;
    WHEN 'regional' THEN v_cost := 50000; v_min_q := 2; v_max_q := 4; v_min_t := 2; v_max_t := 6; v_weeks := 6;
    WHEN 'nacional' THEN v_cost := 200000; v_min_q := 3; v_max_q := 5; v_min_t := 4; v_max_t := 9; v_weeks := 5;
    WHEN 'internacional' THEN v_cost := 800000; v_min_q := 4; v_max_q := 6; v_min_t := 6; v_max_t := 14; v_weeks := 4;
    ELSE RAISE EXCEPTION 'Tier inválido';
  END CASE;

  IF v_club.balance < v_cost THEN RAISE EXCEPTION 'Sem fundos (precisa R$%)', v_cost; END IF;

  v_new_balance := v_club.balance - v_cost;
  UPDATE clubs SET balance = v_new_balance WHERE id = p_club_id;

  v_quality := v_min_q + floor(random() * (v_max_q - v_min_q + 1))::int;
  v_talent := v_min_t + floor(random() * (v_max_t - v_min_t + 1))::int;
  v_age := 16 + floor(random() * 3)::int;
  v_pos := v_positions[1 + floor(random() * array_length(v_positions,1))::int];
  v_name := v_first[1 + floor(random() * array_length(v_first,1))::int] || ' ' || v_last[1 + floor(random() * array_length(v_last,1))::int];

  IF v_name = 'Rafael Costa' THEN v_name := 'Rafael Souza'; END IF;

  INSERT INTO juniors (club_id, name, position, age, quality, talento, weeks_to_reveal)
  VALUES (p_club_id, v_name, v_pos::player_position, v_age, v_quality, v_talent, v_weeks);

  INSERT INTO financial_transactions (club_id, amount, balance_after, type, description)
  VALUES (p_club_id, -v_cost, v_new_balance, 'juniores', 'Scouting ' || p_tier || ': ' || v_name);

  RETURN jsonb_build_object('name', v_name, 'quality', v_quality, 'talent', v_talent, 'cost', v_cost);
END; $$;

-- 2. NPC auto-bidding on open auctions
CREATE OR REPLACE FUNCTION public.npc_auto_bid()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_listing record;
  v_bid bigint;
  v_min_left interval;
  v_bids int := 0;
BEGIN
  FOR v_listing IN
    SELECT mo.*, p.market_value, p.age
    FROM market_open mo
    JOIN players p ON p.id = mo.player_id
    WHERE mo.status = 'active'
      AND mo.ends_at > now()
      AND random() < 0.35
  LOOP
    v_min_left := v_listing.ends_at - now();
    IF v_listing.current_bid >= v_listing.market_value * 1.2 THEN CONTINUE; END IF;

    IF v_listing.current_bid = 0 THEN
      v_bid := GREATEST(v_listing.min_price, v_listing.market_value * (60 + floor(random()*20)::int) / 100);
    ELSE
      v_bid := v_listing.current_bid + GREATEST(5000, v_listing.current_bid * (5 + floor(random()*10)::int) / 100);
    END IF;

    IF v_bid > v_listing.market_value * 1.3 THEN CONTINUE; END IF;

    UPDATE market_open
      SET current_bid = v_bid,
          current_bidder_club_id = NULL,
          ends_at = CASE WHEN v_min_left < interval '10 minutes' THEN now() + interval '10 minutes' ELSE ends_at END
      WHERE id = v_listing.id;
    v_bids := v_bids + 1;
  END LOOP;

  RETURN jsonb_build_object('npc_bids', v_bids);
END; $$;

-- Adjust finalize_auctions: when winner is NULL (NPC won), just remove player and pay seller
CREATE OR REPLACE FUNCTION public.finalize_auctions()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_listing record;
  v_player record;
  v_total_fee BIGINT;
  v_seller_receives BIGINT;
  v_market_fee BIGINT;
  v_prize_fee BIGINT;
  v_loan_fee BIGINT;
  v_solidarity_fee BIGINT;
  v_buyer_balance BIGINT;
  v_seller_balance BIGINT;
  v_finalized INTEGER := 0;
BEGIN
  FOR v_listing IN SELECT * FROM market_open WHERE status = 'active' AND ends_at <= now() FOR UPDATE LOOP
    IF v_listing.current_bid > 0 THEN
      SELECT * INTO v_player FROM players WHERE id = v_listing.player_id;

      v_market_fee := v_listing.current_bid * 10 / 100;
      v_prize_fee := v_listing.current_bid * 5 / 100;
      v_loan_fee := v_listing.current_bid * 5 / 100;
      v_solidarity_fee := CASE WHEN v_player.age <= 23 THEN v_listing.current_bid * 5 / 100 ELSE 0 END;
      v_total_fee := v_market_fee + v_prize_fee + v_loan_fee + v_solidarity_fee;
      v_seller_receives := v_listing.current_bid - v_total_fee;

      IF v_listing.current_bidder_club_id IS NOT NULL THEN
        UPDATE clubs SET balance = balance - v_listing.current_bid WHERE id = v_listing.current_bidder_club_id;
        SELECT balance INTO v_buyer_balance FROM clubs WHERE id = v_listing.current_bidder_club_id;
        INSERT INTO financial_transactions (club_id, amount, balance_after, type, description)
        VALUES (v_listing.current_bidder_club_id, -v_listing.current_bid, v_buyer_balance, 'mercado', 'Compra leilão: ' || v_player.name);
        UPDATE players SET club_id = v_listing.current_bidder_club_id, is_for_sale = false, entrosamento = 0 WHERE id = v_listing.player_id;
      ELSE
        -- NPC won: player leaves the system
        DELETE FROM players WHERE id = v_listing.player_id;
      END IF;

      UPDATE clubs SET balance = balance + v_seller_receives WHERE id = v_listing.seller_club_id;
      SELECT balance INTO v_seller_balance FROM clubs WHERE id = v_listing.seller_club_id;
      INSERT INTO financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_listing.seller_club_id, v_seller_receives, v_seller_balance, 'mercado',
        'Venda leilão (-' || (v_total_fee * 100 / v_listing.current_bid) || '% taxas): ' || v_player.name);

      UPDATE system_funds SET balance = balance + v_prize_fee + v_solidarity_fee WHERE fund_type = 'prize_reserve';
      UPDATE system_funds SET balance = balance + v_loan_fee WHERE fund_type = 'loan_system';

      UPDATE market_open SET status = 'sold' WHERE id = v_listing.id;
    ELSE
      UPDATE players SET is_for_sale = false WHERE id = v_listing.player_id;
      UPDATE market_open SET status = 'expired' WHERE id = v_listing.id;
    END IF;
    v_finalized := v_finalized + 1;
  END LOOP;
  RETURN jsonb_build_object('finalized', v_finalized);
END; $$;

-- 3. Refill closed market — keep ~12 players per league
CREATE OR REPLACE FUNCTION public.refill_closed_market()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_league text;
  v_count int;
  v_target int := 12;
  v_to_add int;
  v_i int;
  v_first text[] := ARRAY['Carlos','Rafael','Eduardo','Júlio','Marcelo','Antônio','Roberto','Fernando','Henrique','Renato','Sérgio','Wagner','Cristiano','Daniel','Alex'];
  v_last text[] := ARRAY['Silva','Santos','Oliveira','Souza','Lima','Pereira','Almeida','Ferreira','Rocha','Costa','Mendes','Barbosa','Gomes','Martins','Carvalho'];
  v_positions text[] := ARRAY['goleiro','zagueiro','lateral','volante','meia','atacante'];
  v_name text;
  v_overall int;
  v_price bigint;
  v_added int := 0;
  v_base_overall int;
  v_stats jsonb;
BEGIN
  FOR v_league IN SELECT unnest(ARRAY['F','E','D','C','B','A']) LOOP
    SELECT COUNT(*) INTO v_count FROM market_closed WHERE league = v_league AND purchased_by IS NULL;
    v_to_add := v_target - v_count;
    IF v_to_add <= 0 THEN CONTINUE; END IF;

    v_base_overall := CASE v_league
      WHEN 'F' THEN 4 WHEN 'E' THEN 5 WHEN 'D' THEN 6
      WHEN 'C' THEN 7 WHEN 'B' THEN 9 WHEN 'A' THEN 11 END;

    FOR v_i IN 1..v_to_add LOOP
      v_name := v_first[1 + floor(random() * array_length(v_first,1))::int] || ' ' ||
                v_last[1 + floor(random() * array_length(v_last,1))::int];
      IF v_name = 'Rafael Costa' THEN v_name := 'Rafael Souza'; END IF;

      v_overall := v_base_overall + floor(random() * 3)::int;
      v_price := (v_overall * v_overall * 8000)::bigint + floor(random() * 30000)::bigint;

      v_stats := jsonb_build_object(
        'reflexos', v_overall, 'posicionamento', v_overall, 'jogo_aereo', v_overall,
        'desarme', v_overall, 'armacao', v_overall, 'passe', v_overall,
        'tecnica', v_overall, 'chute', v_overall,
        'velocidade', v_overall - 1, 'forca', v_overall - 1,
        'resistencia', v_overall, 'forma', v_overall + 1,
        'talento', LEAST(16, v_overall + floor(random()*3)::int)
      );

      INSERT INTO market_closed (league, name, age, position, overall, price, salary, stats)
      VALUES (v_league, v_name, 19 + floor(random()*10)::int,
        v_positions[1 + floor(random() * array_length(v_positions,1))::int],
        v_overall, v_price, GREATEST(2000, v_price / 100), v_stats);
      v_added := v_added + 1;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object('added', v_added);
END; $$;

-- 4. Player agents table
CREATE TABLE IF NOT EXISTS public.player_agents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL UNIQUE,
  agent_name text NOT NULL,
  fee_pct integer NOT NULL DEFAULT 5,
  signed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.player_agents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Agents viewable by everyone" ON public.player_agents FOR SELECT USING (true);
CREATE POLICY "Club owners can sign agents" ON public.player_agents FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM players p JOIN clubs c ON c.id = p.club_id WHERE p.id = player_agents.player_id AND c.user_id = auth.uid())
);
