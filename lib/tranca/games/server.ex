defmodule Tranca.Games.Server do
  @moduledoc """
  A GenServer that wraps a single `Tranca.Game` state.

  The server exposes synchronous calls for every game action and stores the
  updated game state. It is registered by game ID via
  `Tranca.Games.Registry` so it can be discovered by the context module and
  LiveViews.
  """

  use GenServer

  alias Tranca.Game

  @type t :: %__MODULE__{
          game_id: String.t(),
          game: Game.t()
        }

  defstruct [:game_id, :game]

  @doc """
  Returns the child spec for this GenServer.
  """
  def child_spec(opts) do
    %{
      id: {__MODULE__, Keyword.fetch!(opts, :game_id)},
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient
    }
  end

  @doc """
  Starts a game server linked to the caller.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    game_id = Keyword.fetch!(opts, :game_id)
    player_count = Keyword.fetch!(opts, :player_count)

    GenServer.start_link(
      __MODULE__,
      {game_id, player_count},
      name: via_tuple(game_id)
    )
  end

  @doc """
  Returns the current game state.
  """
  @spec state(GenServer.server()) :: Game.t()
  def state(server) do
    GenServer.call(server, :state)
  end

  @impl true
  def init({game_id, player_count}) do
    {:ok, %__MODULE__{game_id: game_id, game: Game.new(game_id, player_count)}}
  end

  @impl true
  def handle_call(:state, _from, %__MODULE__{game: game} = state) do
    {:reply, game, state}
  end

  def handle_call({:add_player, user_id, seat, team}, _from, state) do
    case Game.add_player(state.game, user_id, seat, team) do
      {:ok, game} -> {:reply, {:ok, game}, %{state | game: game}}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:start, seed}, _from, state) do
    case Game.start(state.game, seed) do
      {:ok, game} -> {:reply, {:ok, game}, %{state | game: game}}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:draw_from_deck, player_id}, _from, state) do
    case Game.draw_from_deck(state.game, player_id) do
      {:ok, game} -> {:reply, {:ok, game}, %{state | game: game}}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:draw_from_discard, player_id}, _from, state) do
    case Game.draw_from_discard(state.game, player_id) do
      {:ok, game} -> {:reply, {:ok, game}, %{state | game: game}}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:discard, player_id, card_id}, _from, state) do
    case Game.discard(state.game, player_id, card_id) do
      {:ok, game} -> {:reply, {:ok, game}, %{state | game: game}}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:meld, player_id, card_ids}, _from, state) do
    case Game.meld(state.game, player_id, card_ids) do
      {:ok, game} -> {:reply, {:ok, game}, %{state | game: game}}
      error -> {:reply, error, state}
    end
  end

  defp via_tuple(game_id) do
    {:via, Registry, {Tranca.Games.Registry, game_id}}
  end
end
