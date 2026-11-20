# Tranca

A multiplayer web application for the Brazilian card game **Tranca com morto**.

Play with 2 individual players or 4 players in partnerships (2 vs 2) directly in the browser, with real-time gameplay powered by Phoenix LiveView.

## Tech Stack

- **Backend:** Elixir + Phoenix
- **Real-time:** Phoenix LiveView + PubSub
- **Frontend:** Tailwind CSS + HEEx
- **Database:** SQLite (via `ecto_sqlite3`)
- **Quality:** Credo, ExCoveralls, GitHub Actions CI

## Game Rules

This implementation follows **Tranca com morto**:

- **Deck:** 2 standard 52-card decks + 2 jokers = 108 cards
- **Players:** 2 individual or 4 in partnerships
- **Deal:** 11 cards per player
- **Morto:** Extra 11-card pile taken by the first team to go out
- **Melds:** 3+ cards, either a same-suit sequence (4♥ 5♥ 6♥; the ace can be low or high) or a set of the same rank. Sets are only allowed for aces and 4s (A A A, 4 4 4)
- **Wildcards:** Jokers and 2s stand in for any card in a meld, but may not outnumber the natural cards
- **Black 3:** Blocks the discard pile and costs -100 points if left in hand
- **Red 3:** +100 bonus when on the table. After drawing, a player can place a single red 3 on its own in their team's meld area and draw a replacement from the deck
- **Going out:** Empty hand + at least one canastra

## How to Play

1. Open the app and create a 2- or 4-player game from the lobby.
2. Share the 6-character game code so other players can join.
3. The match starts automatically as soon as every seat is filled. Players are identified per browser session, so each player needs their own browser (a private window works for testing on one machine).
4. On your turn:
   - Draw from the **Deck** or the **Discard** pile (if not blocked by a black 3).
   - Meld groups of 3+ cards, add cards to existing melds, or replace a joker.
   - Discard one card to end your turn.
5. The first team to empty a hand while their team has a canastra takes the **morto**.
6. Click **Score Round** when a hand ends to see the round breakdown, then **Continue** to play the next round.
7. The first team to reach the target score wins the match.

## Requirements

- Elixir 1.19+
- Erlang/OTP 27+

## Setup

Install dependencies and set up the database:

```bash
mix setup
```

This runs `deps.get`, `ecto.setup`, and builds the assets.

## Running the Application

Start the Phoenix server:

```bash
mix phx.server
```

Then visit [`http://localhost:4000`](http://localhost:4000).

## Running Tests

```bash
mix test
```

To run tests with coverage:

```bash
MIX_ENV=test mix coveralls
```

## Code Quality

Format the code:

```bash
mix format
```

Run the linter:

```bash
mix credo --strict
```

Run the full CI pipeline locally:

```bash
MIX_ENV=test mix format --check-formatted
MIX_ENV=test mix compile --warnings-as-errors
MIX_ENV=test mix credo --strict
MIX_ENV=test mix test
MIX_ENV=test mix coveralls
```

## CI

GitHub Actions runs the full pipeline on every push and pull request:

- Format check
- Compilation with `--warnings-as-errors`
- Credo strict analysis
- Tests
- Coverage check (minimum 85%)

## License

MIT
