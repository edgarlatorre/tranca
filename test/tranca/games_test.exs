defmodule Tranca.GamesTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Tranca.Game.Card
  alias Tranca.Game.Meld
  alias Tranca.Games

  describe "new_game/2" do
    test "starts a supervised game server" do
      game_id = "game-#{System.unique_integer([:positive])}"
      assert {:ok, _pid} = Games.new_game(game_id, 2)
      assert {:ok, game} = Games.get_game(game_id)
      assert game.id == game_id
      assert game.player_count == 2
    end

    test "returns an error for an invalid player count" do
      game_id = "game-#{System.unique_integer([:positive])}"

      assert_raise FunctionClauseError, fn ->
        Games.new_game(game_id, 3)
      end
    end
  end

  describe "get_game/1" do
    test "returns an error for a non-existent game" do
      assert {:error, :game_not_found} = Games.get_game("missing-game")
    end
  end

  describe "game actions" do
    setup do
      game_id = "game-#{System.unique_integer([:positive])}"
      {:ok, _pid} = Games.new_game(game_id, 2)
      {:ok, game_id: game_id}
    end

    test "adds players and starts the game", %{game_id: game_id} do
      assert {:ok, _game} = Games.add_player(game_id, "user-1", 0, :a)
      assert {:ok, _game} = Games.add_player(game_id, "user-2", 1, :b)
      assert {:ok, game} = Games.start(game_id, 42)
      assert game.status == :playing
    end

    test "rejects invalid moves", %{game_id: game_id} do
      assert {:ok, _game} = Games.add_player(game_id, "user-1", 0, :a)
      assert {:ok, _game} = Games.add_player(game_id, "user-2", 1, :b)
      assert {:ok, game} = Games.start(game_id, 42)

      other_player = Enum.at(game.players, 1)
      assert {:error, :not_your_turn} = Games.draw_from_deck(game_id, other_player.id)
    end

    test "draw and discard update the game state", %{game_id: game_id} do
      {:ok, _game} = Games.add_player(game_id, "user-1", 0, :a)
      {:ok, _game} = Games.add_player(game_id, "user-2", 1, :b)
      {:ok, game} = Games.start(game_id, 42)

      current_player = Enum.at(game.players, game.turn)
      card_to_discard = hd(current_player.hand)

      assert {:ok, _game} = Games.draw_from_deck(game_id, current_player.id)
      assert {:ok, game} = Games.discard(game_id, current_player.id, card_to_discard.id)

      assert game.turn == 1
    end

    test "replaces a joker and scores a round", %{game_id: game_id} do
      {:ok, _game} = Games.add_player(game_id, "user-1", 0, :a)
      {:ok, _game} = Games.add_player(game_id, "user-2", 1, :b)
      {:ok, game} = Games.start(game_id, 42)

      current_player = Enum.at(game.players, game.turn)
      natural = Card.new("natural", :seven, :hearts, 5)
      joker = Card.new("joker", :joker, nil, 50)

      meld =
        Meld.new([
          Card.new("seven-1", :seven, :diamonds, 5),
          Card.new("seven-2", :seven, :spades, 5),
          joker
        ])

      prepared_game =
        game
        |> put_in([Access.key(:teams), :a, Access.key(:melds)], [meld])
        |> update_player_hand(current_player.id, [natural])
        |> Map.put(:drawn_this_turn, true)

      {:ok, pid} = Tranca.Games.Supervisor.lookup(game_id)
      :sys.replace_state(pid, fn state -> %{state | game: prepared_game} end)

      assert {:ok, game} = Games.replace_joker(game_id, current_player.id, 0, natural.id)
      refute Enum.any?(hd(game.teams.a.melds).cards, &(&1.rank == :joker))

      assert {:ok, _game} = Games.score_round(game_id)
    end
  end

  defp update_player_hand(game, player_id, hand) do
    players =
      Enum.map(game.players, fn player ->
        if player.id == player_id do
          %{player | hand: hand}
        else
          player
        end
      end)

    %{game | players: players}
  end
end
