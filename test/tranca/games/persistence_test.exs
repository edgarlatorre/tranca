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

  describe "get_game_record/1" do
    test "returns the persisted game" do
      {:ok, record} = Games.create_game_record("game-1", 2, 3000)
      assert {:ok, ^record} = Games.get_game_record("game-1")
    end

    test "returns an error when missing" do
      assert {:error, :game_not_found} = Games.get_game_record("missing")
    end
  end
end
