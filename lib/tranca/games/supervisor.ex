defmodule Tranca.Games.Supervisor do
  @moduledoc """
  Supervises `Tranca.Games.Server` processes dynamically.

  Game servers are started under this supervisor and registered by game ID in
  `Tranca.Games.Registry`, allowing lookup and monitoring of running games.
  """

  use DynamicSupervisor

  alias Tranca.Games.Server

  @doc """
  Starts the dynamic supervisor.
  """
  @spec start_link(keyword()) :: DynamicSupervisor.on_start()
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Starts a new game server under the supervisor.
  """
  @spec start_game(String.t(), Tranca.Game.player_count()) :: DynamicSupervisor.on_start_child()
  def start_game(game_id, player_count) when player_count in [2, 4] do
    spec = {Server, game_id: game_id, player_count: player_count}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @doc """
  Looks up a running game server by game ID.
  """
  @spec lookup(String.t()) :: {:ok, pid()} | {:error, :game_not_found}
  def lookup(game_id) do
    case Registry.lookup(Tranca.Games.Registry, game_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :game_not_found}
    end
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
