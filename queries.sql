-- =========================================================
-- League of Legends Worlds Championship SQL Analysis
-- Schema
-- =========================================================

CREATE TABLE tournaments (
  year INT PRIMARY KEY,
  event_name TEXT,
  start_date DATE,
  end_date DATE,
  host_country TEXT,
  prize_pool_usd NUMERIC,
  num_participants INT,
  winner TEXT,
  winner_region TEXT,
  runner_up TEXT,
  runner_up_region TEXT,
  format TEXT,
  finals_score TEXT,
  finals_mvp TEXT
);

CREATE TABLE group_stage_standings (
  year INT REFERENCES tournaments(year),
  stage TEXT,
  group_name TEXT,
  position INT,
  team TEXT,
  region TEXT,
  wins INT,
  losses INT,
  win_pct NUMERIC,
  advanced TEXT
);

CREATE TABLE knockout_bracket_results (
  year INT REFERENCES tournaments(year),
  round TEXT,
  team_1 TEXT,
  team_2 TEXT,
  score TEXT,
  winner TEXT,
  notes TEXT
);

CREATE TABLE final_placements (
  year INT REFERENCES tournaments(year),
  placement TEXT,
  team TEXT,
  region TEXT
);

CREATE TABLE grand_final_results (
  year INT REFERENCES tournaments(year),
  match_type TEXT,
  team_1 TEXT,
  team_2 TEXT,
  winner TEXT,
  score TEXT,
  best_of TEXT,
  venue TEXT,
  mvp TEXT
);

CREATE TABLE prize_pool_distribution (
  year INT REFERENCES tournaments(year),
  placement_tier TEXT,
  teams TEXT,
  prize_usd NUMERIC,
  prize_pct_of_total TEXT
);

CREATE TABLE calendar_venues (
  year INT REFERENCES tournaments(year),
  start_date DATE,
  end_date DATE,
  duration_days INT,
  host_country TEXT,
  final_city TEXT,
  final_venue TEXT
);

-- standalone table, no FK (no year column)
CREATE TABLE region_championship_summary (
  region TEXT,
  championships_won INT,
  runner_up_finishes INT,
  third_fourth_finishes INT,
  total_top4_appearances INT,
  championship_years TEXT
);

CREATE TABLE match_statistics (
  year INT REFERENCES tournaments(year),
  games_played INT,
  avg_game_duration TEXT,
  avg_kills_per_game NUMERIC,
  shortest_game TEXT,
  longest_game TEXT,
  most_kills_single_game TEXT,
  top_kda_leader TEXT,
  top_team_gpm_leader TEXT,
  top_csm_leader TEXT
);


-- =========================================================
-- Analysis Queries
-- =========================================================

-- Confirms schema is wired together correctly: winner + grand final venue/MVP per year
SELECT t.year, t.winner, gf.venue, gf.mvp
FROM tournaments t
JOIN grand_final_results gf
  ON t.year = gf.year
ORDER BY t.year;

-- Attempt to join final placements to knockout results on team name (pre-fix)
-- This undercounts due to inconsistent capitalization across source files
select fp.team, fp.placement, kb.round, kb.winner
from final_placements fp
JOIN knockout_bracket_results kb
  on fp.team = kb.winner
  and fp.year = kb.year
order by fp.year;

-- Diagnostic query: confirms the capitalization mismatch causing dropped rows
-- (e.g. "against All Authority" vs "against All authority")
select fp.team, fp.year
from final_placements fp
where fp.team ILIKE '%authority%'
	and not exists (
	select 1 from knockout_bracket_results kb
	where fp.team = kb.winner AND fp.year = kb.year
	);

-- Fixed version: normalizing case on both sides of the join recovers the missing rows
-- Row count went from 64 to 66 after this fix
SELECT fp.team, fp.placement, kb.round, kb.winner
FROM final_placements fp
JOIN knockout_bracket_results kb
  ON LOWER(fp.team) = LOWER(kb.winner)
  AND fp.year = kb.year
ORDER BY fp.year;

-- Championships won per region
select winner_region, count(*) as championships
from tournaments
group by winner_region
order by championships desc;

-- Regions with more than one championship, ranked by average prize pool
select winner_region, count(winner_region) as times_won, AVG(prize_pool_usd) as average_prize_pool
from tournaments
group by winner_region
having count(winner_region) > 1
order by average_prize_pool desc;

-- Total prize money won per placement tier, ordered by tier rank (not alphabetically)
select placement_tier, sum(prize_usd) as total_prize_money_won
from prize_pool_distribution
group by placement_tier
order by CAST(SUBSTRING(placement_tier FROM '^\d+') AS INT);

-- Tournaments with an above-average prize pool, using a CTE
with avg_prize AS (
	select AVG(prize_pool_usd) as avg_pool from tournaments
)
select year, winner, prize_pool_usd
from tournaments
where prize_pool_usd > (select avg_pool from avg_prize);

-- Key finding: teams that placed but never won a Grand Final
select fp.team, gfr.winner
from final_placements fp
left join grand_final_results gfr
  on fp.team = gfr.winner
where gfr.winner IS NULL;

-- Ranks tournaments by prize pool size, largest first
select t.year, t.prize_pool_usd,
	row_number() over (order by prize_pool_usd DESC) as prize_rank
from tournaments t;

-- Key finding: average kills-per-game by year
select year, avg_kills_per_game
from match_statistics
order by year;

-- Confirms which tournament years have no corresponding match_statistics data
select year from tournaments
where year not in (select year from match_statistics)
order by year;
