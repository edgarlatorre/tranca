defmodule Tranca.Games.SupervisorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Tranca.Games.Supervisor, as: GameSupervisor

  describe "start_game/2" do
    test "starts a game server under the supervisor" do
      game_id = "game-#{System.unique_integer([:positive])}"
      assert {:ok, pid} = GameSupervisor.start_game(game_id, 2)
      assert Process.alive?(pid)
      assert {:ok, ^pid} = GameSupervisor.lookup(game_id)
    end

    test "returns an error for duplicate game IDs" do
      game_id = "game-#{System.unique_integer([:positive])}"
      assert {:ok, _pid} = GameSupervisor.start_game(game_id, 2)
      assert {:error, {:already_started, _pid}} = GameSupervisor.start_game(game_id, 2)
    end
  end

  describe "lookup/1" do
    test "returns an error when the game is not found" do
      assert {:error, :game_not_found} = GameSupervisor.lookup("missing-game")
    end
  end
end
