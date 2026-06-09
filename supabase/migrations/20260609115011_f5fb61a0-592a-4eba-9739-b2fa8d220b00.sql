REVOKE EXECUTE ON FUNCTION public.simulate_matches() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.process_game_week() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.cleanup_old_data() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.repair_game_progression() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.setup_division_seasons() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.build_division_season(text, integer, uuid[]) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.end_season(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.populate_cup(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.advance_cup_phase(uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.simulate_matches() TO service_role;
GRANT EXECUTE ON FUNCTION public.process_game_week() TO service_role;
GRANT EXECUTE ON FUNCTION public.cleanup_old_data() TO service_role;
GRANT EXECUTE ON FUNCTION public.repair_game_progression() TO service_role;
GRANT EXECUTE ON FUNCTION public.setup_division_seasons() TO service_role;
GRANT EXECUTE ON FUNCTION public.build_division_season(text, integer, uuid[]) TO service_role;
GRANT EXECUTE ON FUNCTION public.end_season(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.populate_cup(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.advance_cup_phase(uuid) TO service_role;

REVOKE EXECUTE ON FUNCTION public.register_cup(uuid, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.take_loan(uuid, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.repay_loan(uuid, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_bank_deposit(uuid, bigint, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.place_bid(uuid, uuid, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_player_for_sale(uuid, uuid, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.scout_junior(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.invest_in_junior(uuid, uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.register_cup(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.take_loan(uuid, bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.repay_loan(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_bank_deposit(uuid, bigint, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.place_bid(uuid, uuid, bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.list_player_for_sale(uuid, uuid, bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.scout_junior(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.invest_in_junior(uuid, uuid) TO authenticated, service_role;