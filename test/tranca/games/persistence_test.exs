defmodule Tranca.Games.PersistenceTest do
  @moduledoc false
  use Tranca.DataCase, async: true

  alias Tranca.Games
  alias Tranca.Games.GamePlayer
  alias Tranca.Games.GameRecord
  alias Tranca.Games.GameRound

  describe "create_game_record/3" do
    test "creates a waiting game record" do
      assert {:ok, %GameRecord{}} = Games.create_game_record("game-1", 2, 3000)
    end

    test "rejects an invalid player count" do
      assert {:error, changeset} = Games.create_game_record("game-1", 3, 3000)
      assert "is invalid" in errors_on(changeset).player_count
    end
  end

  describe "add_player_record/4" do
    test "adds a player to a persisted game" do
      {:ok, record} = Games.create_game_record("game-1", 2, 3000)
      record_id = record.id

      assert {:ok, %GamePlayer{game_id: ^record_id}} =
               Games.add_player_record("game-1", "user-1", 0, :a)
    end

    test "returns an error when the game is missing" do
      assert {:error, :game_not_found} = Games.add_player_record("missing", "user-1", 0, :a)
    end
  end

  describe "update_game_record/2" do
    test "updates the game status and winner" do
      {:ok, _record} = Games.create_game_record("game-1", 2, 3000)

      assert {:ok, record} = Games.update_game_record("game-1", status: "finished", winner: "a")
      assert record.status == "finished"
      assert record.winner == "a"
    end
  end

  describe "save_round_result/5" do
    test "saves a round result" do
      {:ok, record} = Games.create_game_record("game-1", 2, 3000)
      record_id = record.id

      assert {:ok, %GameRound{game_id: ^record_id}} =
               Games.save_round_result("game-1", 1, 1500, 800, :a)
    end
  end

  describe "list_rounds/1" do
    test "returns saved rounds ordered by round number" do
      {:ok, _record} = Games.create_game_record("game-1", 2, 3000)

      {:ok, _} = Games.save_round_result("game-1", 2, 500, 300, :b)
      {:ok, _} = Games.save_round_result("game-1", 1, 1500, 800, :a)

      assert {:ok, [round_1, round_2]} = Games.list_rounds("game-1")
      assert round_1.round_number == 1
      assert round_1.team_a_score == 1500
      assert round_2.round_number == 2
      assert round_2.team_b_score == 300
    end

    test "returns an error when the game is missing" do
      assert {:error, :game_not_found} = Games.list_rounds("missing")
    end
  end

  describe "get_game_record/1" do
    test "returns the persisted game" do
      {:ok, record} = Games.create_game_record("game-1", 2, 3000)
      assert {:ok, ^record} = Games.get_game_record("game-1")
    end

    test "returns an error when missing" do
      assert {:error, :game_not_found} = Games.get_game_record("missing")
    end
  end

  describe "join_game/2" do
    test "assigns the next seat and team in a 4-player game" do
      game_id = "game-#{System.unique_integer([:positive])}"
      {:ok, _record} = Games.create_game_record(game_id, 4, 3000)
      {:ok, _pid} = Games.new_game(game_id, 4)

      assert {:ok, game} = Games.join_game(game_id, "user-1")
      player = Enum.find(game.players, &(&1.user_id == "user-1"))
      assert player.seat == 0
      assert player.team == :a

      assert {:ok, game} = Games.join_game(game_id, "user-2")
      player = Enum.find(game.players, &(&1.user_id == "user-2"))
      assert player.seat == 1
      assert player.team == :b
    end

    test "returns an error when the game is full" do
      game_id = "game-#{System.unique_integer([:positive])}"
      {:ok, _record} = Games.create_game_record(game_id, 2, 3000)
      {:ok, _pid} = Games.new_game(game_id, 2)
      {:ok, _game} = Games.join_game(game_id, "user-1")
      {:ok, _game} = Games.join_game(game_id, "user-2")

      assert {:error, :game_full_or_started} = Games.join_game(game_id, "user-3")
    end

    test "starts the match when the last seat is filled" do
      game_id = "game-#{System.unique_integer([:positive])}"
      {:ok, _record} = Games.create_game_record(game_id, 2, 3000)
      {:ok, _pid} = Games.new_game(game_id, 2)

      assert {:ok, %{status: :waiting}} = Games.join_game(game_id, "user-1")
      assert {:ok, game} = Games.join_game(game_id, "user-2")

      assert game.status == :playing
      assert Enum.all?(game.players, &(length(&1.hand) == 11))
      assert {:ok, record} = Games.get_game_record(game_id)
      assert record.status == "playing"
    end

    test "does not seat the same user twice" do
      game_id = "game-#{System.unique_integer([:positive])}"
      {:ok, _record} = Games.create_game_record(game_id, 2, 3000)
      {:ok, _pid} = Games.new_game(game_id, 2)

      {:ok, _game} = Games.join_game(game_id, "user-1")
      assert {:ok, game} = Games.join_game(game_id, "user-1")

      assert game.status == :waiting
      assert [%{user_id: "user-1", seat: 0}] = game.players
      assert {:ok, 1} = Games.open_seats(game_id)
    end

    test "returns the game for a seated user after the match started" do
      game_id = "game-#{System.unique_integer([:positive])}"
      {:ok, _record} = Games.create_game_record(game_id, 2, 3000)
      {:ok, _pid} = Games.new_game(game_id, 2)
      {:ok, _game} = Games.join_game(game_id, "user-1")
      {:ok, _game} = Games.join_game(game_id, "user-2")

      assert {:ok, %{status: :playing}} = Games.join_game(game_id, "user-1")
    end
  end
end
