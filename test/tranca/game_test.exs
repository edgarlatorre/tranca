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

  describe "add_player/4" do
    test "adds a player to the game" do
      game = Game.new("game-1", 2)
      assert {:ok, game} = Game.add_player(game, "user-1", 0, :a)

      assert length(game.players) == 1
      assert hd(game.players).seat == 0
      assert hd(game.players).team == :a
      assert game.teams.a.player_ids == ["player-0"]
    end

    test "rejects duplicate seats" do
      game = Game.new("game-1", 2)
      {:ok, game} = Game.add_player(game, "user-1", 0, :a)
      assert {:error, :seat_taken} = Game.add_player(game, "user-2", 0, :b)
    end

    test "rejects invalid seats" do
      game = Game.new("game-1", 2)
      assert {:error, :invalid_seat_or_team} = Game.add_player(game, "user-1", 2, :a)
      assert {:error, :invalid_seat_or_team} = Game.add_player(game, "user-1", 0, :c)
    end

    test "rejects players after the game has started" do
      game = Game.new("game-1", 2)
      {:ok, game} = Game.add_player(game, "user-1", 0, :a)
      {:ok, game} = Game.add_player(game, "user-2", 1, :b)
      {:ok, game} = Game.start(game, 42)

      assert {:error, :game_already_started} = Game.add_player(game, "user-3", 0, :a)
    end
  end

  describe "start/2" do
    test "deals 11 cards to each player" do
      game =
        Game.new("game-1", 2)
        |> add_players([{"user-1", 0, :a}, {"user-2", 1, :b}])

      assert {:ok, game} = Game.start(game, 42)
      assert game.status == :playing

      for player <- game.players do
        assert length(player.hand) == 11
      end
    end

    test "creates an 11-card morto" do
      game =
        Game.new("game-1", 2)
        |> add_players([{"user-1", 0, :a}, {"user-2", 1, :b}])

      assert {:ok, game} = Game.start(game, 42)
      assert length(game.morto) == 11
    end

    test "starts the discard pile with one card" do
      game =
        Game.new("game-1", 2)
        |> add_players([{"user-1", 0, :a}, {"user-2", 1, :b}])

      assert {:ok, game} = Game.start(game, 42)
      assert length(game.discard_pile) == 1
    end

    test "leaves the remaining cards in the deck" do
      game =
        Game.new("game-1", 2)
        |> add_players([{"user-1", 0, :a}, {"user-2", 1, :b}])

      assert {:ok, game} = Game.start(game, 42)
      # 108 cards - 22 dealt - 11 morto - 1 discard = 74
      assert length(game.deck) == 74
    end

    test "deals different hands to each player" do
      game =
        Game.new("game-1", 2)
        |> add_players([{"user-1", 0, :a}, {"user-2", 1, :b}])

      assert {:ok, game} = Game.start(game, 42)
      [player_0, player_1] = Enum.sort_by(game.players, & &1.seat)
      refute player_0.hand == player_1.hand
    end

    test "rejects starting with too few players" do
      game = Game.new("game-1", 2)
      {:ok, game} = Game.add_player(game, "user-1", 0, :a)

      assert {:error, :not_enough_players} = Game.start(game, 42)
    end

    test "rejects starting an already started game" do
      game =
        Game.new("game-1", 2)
        |> add_players([{"user-1", 0, :a}, {"user-2", 1, :b}])

      {:ok, game} = Game.start(game, 42)
      assert {:error, :game_already_started} = Game.start(game, 42)
    end
  end

  defp add_players(game, players) do
    Enum.reduce(players, game, fn {user_id, seat, team}, acc ->
      {:ok, updated} = Game.add_player(acc, user_id, seat, team)
      updated
    end)
  end
end
