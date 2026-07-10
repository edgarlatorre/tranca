defmodule Tranca.Game.PlayerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Tranca.Game.Player

  describe "new/4" do
    test "creates a player with the correct defaults" do
      player = Player.new("player-1", "user-1", 0, :a)

      assert player.id == "player-1"
      assert player.user_id == "user-1"
      assert player.seat == 0
      assert player.team == :a
      assert player.hand == []
      assert player.status == :waiting
    end

    test "allows nil user_id" do
      player = Player.new("player-1", nil, 1, :b)
      assert player.user_id == nil
      assert player.team == :b
    end
  end
end
