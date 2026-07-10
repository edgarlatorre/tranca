defmodule Tranca.GameTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Tranca.Game
  alias Tranca.Game.Team

  describe "new/2" do
    test "creates a 2-player game with the correct defaults" do
      game = Game.new("game-1", 2)

      assert game.id == "game-1"
      assert game.status == :waiting
      assert game.player_count == 2
      assert game.players == []
      assert game.teams == %{a: Team.new(:a), b: Team.new(:b)}
      assert game.deck == []
      assert game.morto == []
      assert game.discard_pile == []
      assert game.turn == 0
      assert game.round == 1
      assert game.winner == nil
    end

    test "creates a 4-player game" do
      game = Game.new("game-1", 4)
      assert game.player_count == 4
    end

    test "rejects invalid player counts" do
      assert_raise FunctionClauseError, fn ->
        Game.new("game-1", 3)
      end
    end
  end
end
