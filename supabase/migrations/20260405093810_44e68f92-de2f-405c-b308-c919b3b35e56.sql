-- Fix overly permissive RLS
DROP POLICY "Authenticated can update market closed" ON public.market_closed;
CREATE POLICY "Authenticated can buy from market" ON public.market_closed FOR UPDATE TO authenticated
  USING (purchased_by IS NULL);

DROP POLICY "Authenticated can update market open" ON public.market_open;
CREATE POLICY "Authenticated can bid on market" ON public.market_open FOR UPDATE TO authenticated
  USING (status = 'active');

-- Function: Buy from closed market
CREATE OR REPLACE FUNCTION public.buy_from_closed_market(p_club_id uuid, p_listing_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_club record;
  v_listing record;
  v_new_balance bigint;
  v_player_id uuid;
BEGIN
  SELECT * INTO v_club FROM clubs WHERE id = p_club_id FOR UPDATE;
  IF v_club IS NULL OR v_club.user_id != auth.uid() THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT * INTO v_listing FROM market_closed WHERE id = p_listing_id AND purchased_by IS NULL FOR UPDATE;
  IF v_listing IS NULL THEN RAISE EXCEPTION 'Listing not available'; END IF;

  IF v_club.balance < v_listing.price THEN RAISE EXCEPTION 'Insufficient funds'; END IF;

  v_new_balance := v_club.balance - v_listing.price;
  UPDATE clubs SET balance = v_new_balance WHERE id = p_club_id;

  -- Create actual player from listing stats
  INSERT INTO players (club_id, name, age, position, salary, market_value,
    reflexos, posicionamento, jogo_aereo, desarme, armacao, passe, tecnica, chute,
    velocidade, forca, resistencia, forma,
    potencial_velocidade, potencial_forca, potencial_resistencia, potencial_forma,
    talento, moral, entrosamento)
  VALUES (p_club_id, v_listing.name, v_listing.age, (v_listing.position)::player_position, v_listing.salary, v_listing.price,
    COALESCE((v_listing.stats->>'reflexos')::int, 3),
    COALESCE((v_listing.stats->>'posicionamento')::int, 3),
    COALESCE((v_listing.stats->>'jogo_aereo')::int, 3),
    COALESCE((v_listing.stats->>'desarme')::int, 3),
    COALESCE((v_listing.stats->>'armacao')::int, 3),
    COALESCE((v_listing.stats->>'passe')::int, 3),
    COALESCE((v_listing.stats->>'tecnica')::int, 3),
    COALESCE((v_listing.stats->>'chute')::int, 3),
    COALESCE((v_listing.stats->>'velocidade')::int, 3),
    COALESCE((v_listing.stats->>'forca')::int, 3),
    COALESCE((v_listing.stats->>'resistencia')::int, 3),
    COALESCE((v_listing.stats->>'forma')::int, 3),
    COALESCE((v_listing.stats->>'velocidade')::int, 3) + 2,
    COALESCE((v_listing.stats->>'forca')::int, 3) + 2,
    COALESCE((v_listing.stats->>'resistencia')::int, 3) + 2,
    COALESCE((v_listing.stats->>'forma')::int, 3) + 2,
    COALESCE((v_listing.stats->>'talento')::int, 3), 50, 0)
  RETURNING id INTO v_player_id;

  UPDATE market_closed SET purchased_by = p_club_id, purchased_at = now() WHERE id = p_listing_id;

  INSERT INTO financial_transactions (club_id, amount, balance_after, type, description)
  VALUES (p_club_id, -v_listing.price, v_new_balance, 'mercado', 'Compra: ' || v_listing.name || ' (Mercado Fechado)');

  RETURN jsonb_build_object('player_id', v_player_id, 'cost', v_listing.price);
END; $$;

-- Function: List player for auction (open market)
CREATE OR REPLACE FUNCTION public.list_player_for_sale(p_club_id uuid, p_player_id uuid, p_min_price bigint)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_club record;
  v_player record;
  v_listing_id uuid;
BEGIN
  SELECT * INTO v_club FROM clubs WHERE id = p_club_id;
  IF v_club IS NULL OR v_club.user_id != auth.uid() THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT * INTO v_player FROM players WHERE id = p_player_id AND club_id = p_club_id;
  IF v_player IS NULL THEN RAISE EXCEPTION 'Player not found'; END IF;

  IF EXISTS (SELECT 1 FROM market_open WHERE player_id = p_player_id AND status = 'active') THEN
    RAISE EXCEPTION 'Player already listed';
  END IF;

  INSERT INTO market_open (player_id, seller_club_id, min_price, ends_at)
  VALUES (p_player_id, p_club_id, p_min_price, now() + interval '8 hours')
  RETURNING id INTO v_listing_id;

  UPDATE players SET is_for_sale = true WHERE id = p_player_id;

  RETURN v_listing_id;
END; $$;

-- Function: Place bid on open market
CREATE OR REPLACE FUNCTION public.place_bid(p_club_id uuid, p_listing_id uuid, p_bid bigint)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_club record;
  v_listing record;
BEGIN
  SELECT * INTO v_club FROM clubs WHERE id = p_club_id;
  IF v_club IS NULL OR v_club.user_id != auth.uid() THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT * INTO v_listing FROM market_open WHERE id = p_listing_id AND status = 'active' FOR UPDATE;
  IF v_listing IS NULL THEN RAISE EXCEPTION 'Listing not available'; END IF;

  IF v_listing.seller_club_id = p_club_id THEN RAISE EXCEPTION 'Cannot bid on own listing'; END IF;
  IF p_bid < v_listing.min_price THEN RAISE EXCEPTION 'Bid below minimum'; END IF;
  IF p_bid <= v_listing.current_bid THEN RAISE EXCEPTION 'Bid must be higher than current'; END IF;
  IF v_club.balance < p_bid THEN RAISE EXCEPTION 'Insufficient funds'; END IF;

  UPDATE market_open SET current_bid = p_bid, current_bidder_club_id = p_club_id WHERE id = p_listing_id;
END; $$;

-- Function: Finalize expired auctions (called by game-loop)
CREATE OR REPLACE FUNCTION public.finalize_auctions()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_listing record;
  v_total_fee bigint;
  v_seller_receives bigint;
  v_market_fee bigint;
  v_prize_fee bigint;
  v_loan_fee bigint;
  v_buyer_balance bigint;
  v_seller_balance bigint;
  v_finalized integer := 0;
BEGIN
  FOR v_listing IN
    SELECT * FROM market_open WHERE status = 'active' AND ends_at <= now() FOR UPDATE
  LOOP
    IF v_listing.current_bid > 0 AND v_listing.current_bidder_club_id IS NOT NULL THEN
      -- Calculate fees: 10% market, 5% prize, 5% loan = 20% total
      v_total_fee := v_listing.current_bid * 20 / 100;
      v_market_fee := v_listing.current_bid * 10 / 100;
      v_prize_fee := v_listing.current_bid * 5 / 100;
      v_loan_fee := v_listing.current_bid * 5 / 100;
      v_seller_receives := v_listing.current_bid - v_total_fee;

      -- Deduct from buyer
      UPDATE clubs SET balance = balance - v_listing.current_bid WHERE id = v_listing.current_bidder_club_id;
      SELECT balance INTO v_buyer_balance FROM clubs WHERE id = v_listing.current_bidder_club_id;
      INSERT INTO financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_listing.current_bidder_club_id, -v_listing.current_bid, v_buyer_balance, 'mercado',
        'Compra em leilão (Mercado Aberto)');

      -- Pay seller (minus fees)
      UPDATE clubs SET balance = balance + v_seller_receives WHERE id = v_listing.seller_club_id;
      SELECT balance INTO v_seller_balance FROM clubs WHERE id = v_listing.seller_club_id;
      INSERT INTO financial_transactions (club_id, amount, balance_after, type, description)
      VALUES (v_listing.seller_club_id, v_seller_receives, v_seller_balance, 'mercado',
        'Venda em leilão (-20% taxas): ' || v_seller_receives);

      -- Transfer player
      UPDATE players SET club_id = v_listing.current_bidder_club_id, is_for_sale = false, entrosamento = 0
      WHERE id = v_listing.player_id;

      -- Fund system reserves
      UPDATE system_funds SET balance = balance + v_prize_fee WHERE fund_type = 'prize_reserve';
      UPDATE system_funds SET balance = balance + v_loan_fee WHERE fund_type = 'loan_system';

      UPDATE market_open SET status = 'sold' WHERE id = v_listing.id;
    ELSE
      -- No bids: return player
      UPDATE players SET is_for_sale = false WHERE id = v_listing.player_id;
      UPDATE market_open SET status = 'expired' WHERE id = v_listing.id;
    END IF;

    v_finalized := v_finalized + 1;
  END LOOP;

  RETURN jsonb_build_object('finalized', v_finalized);
END; $$;
