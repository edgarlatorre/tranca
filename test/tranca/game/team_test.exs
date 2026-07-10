defmodule Tranca.Game.TeamTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Tranca.Game.Team

  describe "new/1" do
    test "creates a team with the correct defaults" do
      team = Team.new(:a)

      assert team.id == :a
      assert team.player_ids == []
      assert team.melds == []
      assert team.score == 0
      refute team.first_meld_done
    end
  end

  describe "add_player/2" do
    test "appends a player id to the team" do
      team =
        Team.new(:b)
        |> Team.add_player("player-1")
        |> Team.add_player("player-2")

      assert team.player_ids == ["player-1", "player-2"]
    end
  end
end
