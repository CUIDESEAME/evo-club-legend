-- Reset all clubs to starting state
UPDATE public.clubs
SET balance = 500000,
    fans = 100,
    members = 10,
    game_week = 0,
    marketing_budget = 0,
    updated_at = now();

-- Wipe financial history & debts
DELETE FROM public.financial_transactions;
DELETE FROM public.loans;
DELETE FROM public.bank_deposits;
DELETE FROM public.disciplinary_events;

-- Reset league standings to zero
UPDATE public.league_standings
SET played = 0, wins = 0, draws = 0, losses = 0,
    goals_for = 0, goals_against = 0, points = 0;

-- Reset seasons to round 1 active
UPDATE public.seasons
SET current_round = 1, status = 'active';

-- Reset all matches back to scheduled
UPDATE public.matches
SET status = 'scheduled', home_score = NULL, away_score = NULL,
    revenue = 0, played_at = NULL;