defmodule Tranca.GameTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Tranca.Game
  alias Tranca.Game.Card
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
      refute game.drawn_this_turn
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

  describe "draw_from_deck/2" do
    test "gives the top deck card to the current player" do
      game = started_game()
      current_player = Enum.at(game.players, game.turn)
      deck_top = hd(game.deck)

      assert {:ok, game} = Game.draw_from_deck(game, current_player.id)

      current_player = Enum.at(game.players, game.turn)
      assert deck_top in current_player.hand
      assert length(game.deck) == 73
      assert game.drawn_this_turn
    end

    test "rejects drawing out of turn" do
      game = started_game()
      other_player = Enum.at(game.players, 1)

      assert {:error, :not_your_turn} = Game.draw_from_deck(game, other_player.id)
    end

    test "rejects drawing twice in one turn" do
      game = started_game()
      current_player = Enum.at(game.players, game.turn)

      {:ok, game} = Game.draw_from_deck(game, current_player.id)
      assert {:error, :already_drew} = Game.draw_from_deck(game, current_player.id)
    end

    test "rejects drawing when the game has not started" do
      game = Game.new("game-1", 2)
      assert {:error, :game_not_playing} = Game.draw_from_deck(game, "player-0")
    end
  end

  describe "draw_from_discard/2" do
    test "gives the top discard card to the current player" do
      game = started_game()
      current_player = Enum.at(game.players, game.turn)
      discard_top = hd(game.discard_pile)

      assert {:ok, game} = Game.draw_from_discard(game, current_player.id)

      current_player = Enum.at(game.players, game.turn)
      assert discard_top in current_player.hand
      assert game.discard_pile == []
      assert game.drawn_this_turn
    end

    test "rejects drawing when the discard pile is blocked by a black three" do
      game = started_game()
      current_player = Enum.at(game.players, game.turn)
      black_three = Card.new("x", :three, :spades, 5)
      game = %{game | discard_pile: [black_three]}

      assert {:error, :discard_blocked_by_black_three} =
               Game.draw_from_discard(game, current_player.id)
    end

    test "rejects drawing out of turn" do
      game = started_game()
      other_player = Enum.at(game.players, 1)

      assert {:error, :not_your_turn} = Game.draw_from_discard(game, other_player.id)
    end
  end

  describe "discard/3" do
    test "moves a card from hand to discard pile and advances turn" do
      game = started_game()
      current_player = Enum.at(game.players, game.turn)
      card_to_discard = hd(current_player.hand)

      assert {:ok, game} = Game.draw_from_deck(game, current_player.id)
      assert {:ok, game} = Game.discard(game, current_player.id, card_to_discard.id)

      current_player = Enum.at(game.players, 0)
      refute card_to_discard.id in Enum.map(current_player.hand, & &1.id)
      assert hd(game.discard_pile).id == card_to_discard.id
      assert game.turn == 1
      refute game.drawn_this_turn
    end

    test "rejects discarding before drawing" do
      game = started_game()
      current_player = Enum.at(game.players, game.turn)
      card_to_discard = hd(current_player.hand)

      assert {:error, :must_draw_first} =
               Game.discard(game, current_player.id, card_to_discard.id)
    end

    test "rejects discarding a card not in hand" do
      game = started_game()
      current_player = Enum.at(game.players, game.turn)
      other_player = Enum.at(game.players, 1)
      card_from_other = hd(other_player.hand)

      {:ok, game} = Game.draw_from_deck(game, current_player.id)

      assert {:error, :card_not_in_hand} =
               Game.discard(game, current_player.id, card_from_other.id)
    end

    test "rejects discarding out of turn" do
      game = started_game()
      other_player = Enum.at(game.players, 1)

      assert {:error, :not_your_turn} =
               Game.discard(game, other_player.id, "nonexistent")
    end
  end

  defp add_players(game, players) do
    Enum.reduce(players, game, fn {user_id, seat, team}, acc ->
      {:ok, updated} = Game.add_player(acc, user_id, seat, team)
      updated
    end)
  end

  defp started_game do
    Game.new("game-1", 2)
    |> add_players([{"user-1", 0, :a}, {"user-2", 1, :b}])
    |> then(fn game ->
      {:ok, game} = Game.start(game, 42)
      game
    end)
  end
end
