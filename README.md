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
- **First meld minimum:** 75 points
- **Wildcards:** Jokers and 2s
- **Black 3:** Blocks the discard pile and costs -100 points if left in hand
- **Red 3:** +100 bonus when melded
- **Going out:** Empty hand + at least one canastra

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
