defmodule Tranca.Games do
  @moduledoc """
  The public API for managing Tranca game servers.

  Each game runs in its own supervised `Tranca.Games.Server` process,
  registered by game ID so players and LiveViews can interact with it.
  """

  import Ecto.Query

  alias Tranca.Game
  alias Tranca.Games.GamePlayer
  alias Tranca.Games.GameRecord
  alias Tranca.Games.GameRound
  alias Tranca.Games.Server
  alias Tranca.Games.Supervisor, as: GameSupervisor
  alias Tranca.Repo

  @doc """
  Starts a new game server with the given ID and player count.
  """
  @spec new_game(String.t(), Game.player_count()) :: DynamicSupervisor.on_start_child()
  def new_game(game_id, player_count) when player_count in [2, 4] do
    GameSupervisor.start_game(game_id, player_count)
  end

  @doc """
  Persists a new game record to the database.
  """
  @spec create_game_record(String.t(), Game.player_count(), integer()) ::
          {:ok, GameRecord.t()} | {:error, Ecto.Changeset.t()}
  def create_game_record(game_id, player_count, target_score \\ 3000) do
    %GameRecord{}
    |> GameRecord.changeset(%{
      game_id: game_id,
      status: "waiting",
      player_count: player_count,
      target_score: target_score
    })
    |> Repo.insert()
  end

  @doc """
  Persists a player joining a game.
  """
  @spec add_player_record(String.t(), String.t(), integer(), Game.Player.team()) ::
          {:ok, GamePlayer.t()} | {:error, Ecto.Changeset.t() | :game_not_found}
  def add_player_record(game_id, user_id, seat, team) when team in [:a, :b] do
    with {:ok, record} <- fetch_game_record(game_id) do
      %GamePlayer{}
      |> GamePlayer.changeset(%{
        game_id: record.id,
        user_id: user_id,
        seat: seat,
        team: to_string(team)
      })
      |> Repo.insert()
    end
  end

  @doc """
  Updates the persisted game status and winner.
  """
  @spec update_game_record(String.t(), keyword()) ::
          {:ok, GameRecord.t()} | {:error, Ecto.Changeset.t() | :game_not_found}
  def update_game_record(game_id, attrs) do
    with {:ok, record} <- fetch_game_record(game_id) do
      record
      |> GameRecord.changeset(Map.new(attrs))
      |> Repo.update()
    end
  end

  @doc """
  Persists the result of a finished round.
  """
  @spec save_round_result(String.t(), integer(), integer(), integer(), Game.Team.id() | nil) ::
          {:ok, GameRound.t()} | {:error, Ecto.Changeset.t() | :game_not_found}
  def save_round_result(game_id, round_number, team_a_score, team_b_score, winner) do
    with {:ok, record} <- fetch_game_record(game_id) do
      %GameRound{}
      |> GameRound.changeset(%{
        game_id: record.id,
        round_number: round_number,
        team_a_score: team_a_score,
        team_b_score: team_b_score,
        winner: winner && to_string(winner)
      })
      |> Repo.insert()
    end
  end

  @doc """
  Returns the persisted game record for the given game ID.
  """
  @spec get_game_record(String.t()) :: {:ok, GameRecord.t()} | {:error, :game_not_found}
  def get_game_record(game_id) do
    fetch_game_record(game_id)
  end

  @doc """
  Returns waiting game records preloaded with their players.
  """
  @spec list_waiting_games() :: [GameRecord.t()]
  def list_waiting_games do
    GameRecord
    |> where(status: "waiting")
    |> preload(:players)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  defp fetch_game_record(game_id) do
    case Repo.get_by(GameRecord, game_id: game_id) do
      nil -> {:error, :game_not_found}
      record -> {:ok, record}
    end
  end

  @doc """
  Returns the current state of the game, or an error if it is not running.
  """
  @spec get_game(String.t()) :: {:ok, Game.t()} | {:error, :game_not_found}
  def get_game(game_id) do
    case Registry.lookup(Tranca.Games.Registry, game_id) do
      [{pid, _}] -> {:ok, Server.state(pid)}
      [] -> {:error, :game_not_found}
    end
  end

  @doc """
  Adds a player to the game.
  """
  @spec add_player(String.t(), String.t(), integer(), Game.Player.team()) ::
          {:ok, Game.t()} | {:error, atom()}
  def add_player(game_id, user_id, seat, team) do
    with {:ok, pid} <- via(game_id) do
      GenServer.call(pid, {:add_player, user_id, seat, team})
    end
  end

  @doc """
  Starts the game with a deterministic shuffle seed.
  """
  @spec start(String.t(), integer()) :: {:ok, Game.t()} | {:error, atom()}
  def start(game_id, seed) do
    with {:ok, pid} <- via(game_id) do
      GenServer.call(pid, {:start, seed})
    end
  end

  @doc """
  Draws the top card from the deck for the given player.
  """
  @spec draw_from_deck(String.t(), String.t()) :: {:ok, Game.t()} | {:error, atom()}
  def draw_from_deck(game_id, player_id) do
    with {:ok, pid} <- via(game_id) do
      GenServer.call(pid, {:draw_from_deck, player_id})
    end
  end

  @doc """
  Draws the top card from the discard pile for the given player.
  """
  @spec draw_from_discard(String.t(), String.t()) :: {:ok, Game.t()} | {:error, atom()}
  def draw_from_discard(game_id, player_id) do
    with {:ok, pid} <- via(game_id) do
      GenServer.call(pid, {:draw_from_discard, player_id})
    end
  end

  @doc """
  Discards a card from the player's hand.
  """
  @spec discard(String.t(), String.t(), String.t()) :: {:ok, Game.t()} | {:error, atom()}
  def discard(game_id, player_id, card_id) do
    with {:ok, pid} <- via(game_id) do
      GenServer.call(pid, {:discard, player_id, card_id})
    end
  end

  @doc """
  Lays down a meld from the player's hand.
  """
  @spec meld(String.t(), String.t(), [String.t()]) :: {:ok, Game.t()} | {:error, atom()}
  def meld(game_id, player_id, card_ids) do
    with {:ok, pid} <- via(game_id) do
      GenServer.call(pid, {:meld, player_id, card_ids})
    end
  end

  @doc """
  Replaces a joker in one of the team's melds with a natural card from the
  player's hand.
  """
  @spec replace_joker(String.t(), String.t(), integer(), String.t()) ::
          {:ok, Game.t()} | {:error, atom()}
  def replace_joker(game_id, player_id, meld_index, card_id) do
    with {:ok, pid} <- via(game_id) do
      GenServer.call(pid, {:replace_joker, player_id, meld_index, card_id})
    end
  end

  @doc """
  Scores the current hand and updates team totals.
  """
  @spec score_round(String.t()) :: {:ok, Game.t()} | {:error, atom()}
  def score_round(game_id) do
    with {:ok, pid} <- via(game_id) do
      GenServer.call(pid, :score_round)
    end
  end

  defp via(game_id) do
    GameSupervisor.lookup(game_id)
  end
end
