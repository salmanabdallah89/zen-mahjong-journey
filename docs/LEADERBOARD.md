# World rank and weekly competition

The rank on Level Complete comes from **Talo** (https://trytalo.com), through
`scripts/autoload/global_rank.gd` and its REST API. No plugin and no player sign-in: each install
gets a random id, so every player has a rank from their first clear. Free up to 10,000 players
(Talo pricing page, checked 2026-10-31); paid plans start at $24.99/month.

## Setup (done once, by the owner)
1. Create a Talo account and a game.
2. Create two leaderboards. Both: sort **descending**, **unique** entries.
   - Internal name `total-score`, no refresh.
   - Internal name `weekly-score`, refresh **weekly**.
3. Create an API key with `read:players`, `write:players`, `read:leaderboards`,
   `write:leaderboards`.
4. Put it in `data/leaderboard.json` (ignored by git, because the repository is public):
   `{"access_key": "..."}`. Builds made on this machine include it. Without the file the game
   simply shows no rank (web build, tests).

## What is sent
Random install id, total score (every level's best added up), points this week. Update
`site/privacy.html` and the Play Data safety form before release.

## Limits
- Scores are sent by the app and Talo's docs describe no score tamper protection, so a modified
  app could post a fake score. Remove cheaters from the Talo dashboard.
- Not yet tested against the real service: needs the key above.
