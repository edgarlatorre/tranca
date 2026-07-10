defmodule Tranca.Games do
  @moduledoc """
  The public API for managing Tranca game servers.

  Each game runs in its own supervised `Tranca.Games.Server` process,
  registered by game ID so players and LiveViews can interact with it.
  """

  alias Tranca.Game
  alias Tranca.Games.Server
  alias Tranca.Games.Supervisor, as: GameSupervisor

  @doc """
  Starts a new game server with the given ID and player count.
  """
  @spec new_game(String.t(), Game.player_count()) :: DynamicSupervisor.on_start_child()
  def new_game(game_id, player_count) when player_count in [2, 4] do
    GameSupervisor.start_game(game_id, player_count)
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

  defp via(game_id) do
    GameSupervisor.lookup(game_id)
  end
end
