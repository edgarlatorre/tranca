defmodule TrancaWeb.GameLiveTest do
  @moduledoc false
  use TrancaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Tranca.Game.Card
  alias Tranca.Game.Meld
  alias Tranca.Games

  describe "GameLive" do
    test "renders the game table for a waiting game", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_waiting_game("waiting-game", 2, ["player-1", "player-2"])

      {:ok, view, _html} = live(conn, ~p"/games/waiting-game")

      assert has_element?(view, "h1", "Game waiting-game")
      assert has_element?(view, "p", "Waiting for players")
      assert has_element?(view, "p", "2 / 2 players joined")
    end

    test "auto-joins a waiting game when user is not seated", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "late-joiner"})
      setup_waiting_game("auto-join-game", 4, ["player-1"])

      {:ok, view, _html} = live(conn, ~p"/games/auto-join-game")

      assert has_element?(view, "span", "You")
      assert {:ok, game} = Games.get_game("auto-join-game")
      assert length(game.players) == 2
    end

    test "shows an error for a missing game", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})

      {:ok, view, _html} = live(conn, ~p"/games/missing-game")

      assert has_element?(view, "p", "Game not found")
    end

    test "shows a full game error when user is not seated", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "spectator"})
      setup_waiting_game("full-waiting-game", 2, ["player-1", "player-2"])

      {:ok, view, _html} = live(conn, ~p"/games/full-waiting-game")

      assert has_element?(view, "p", "This game is full")
    end

    test "renders playing game state", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("playing-game", 2, ["player-1", "player-2"])

      {:ok, view, _html} = live(conn, ~p"/games/playing-game")

      assert has_element?(view, "p", "Round 1")
      assert has_element?(view, "h3", "Team A")
      assert has_element?(view, "h3", "Team B")
    end

    test "re-renders when the game state is updated", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("pubsub-game", 2, ["player-1", "player-2"])

      {:ok, view, _html} = live(conn, ~p"/games/pubsub-game")

      assert has_element?(view, "#draw-deck", "74")

      {:ok, game} = Games.get_game("pubsub-game")

      Phoenix.PubSub.broadcast(
        Tranca.PubSub,
        "game:pubsub-game",
        {:game_updated, %{game | round: 2}}
      )

      assert has_element?(view, "p", "Round 2")
    end

    test "draws a card from the deck", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("draw-game", 2, ["player-1", "player-2"])

      {:ok, view, _html} = live(conn, ~p"/games/draw-game")

      assert {:ok, game_before} = Games.get_game("draw-game")
      hand_size = length(Enum.find(game_before.players, &(&1.user_id == "player-1")).hand)

      assert view |> element("#draw-deck") |> render_click()

      assert {:ok, game_after} = Games.get_game("draw-game")
      player = Enum.find(game_after.players, &(&1.user_id == "player-1"))
      assert length(player.hand) == hand_size + 1
      assert game_after.drawn_this_turn
    end

    test "discards a selected card", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("discard-game", 2, ["player-1", "player-2"])
      {:ok, game} = Games.draw_from_deck("discard-game", "player-0")
      current_player = Enum.at(game.players, game.turn)
      card_to_discard = hd(current_player.hand)

      {:ok, view, _html} = live(conn, ~p"/games/discard-game")

      view
      |> element("button[phx-value-card_id='#{card_to_discard.id}']")
      |> render_click()

      view
      |> element("#discard-selected")
      |> render_click()

      assert {:ok, updated_game} = Games.get_game("discard-game")
      assert updated_game.turn == 1
      assert hd(updated_game.discard_pile).id == card_to_discard.id
    end

    test "melds selected cards", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("meld-game", 2, ["player-1", "player-2"])

      meld_cards = [
        Card.new("meld-1", :ace, :hearts, 20),
        Card.new("meld-2", :ace, :diamonds, 20),
        Card.new("meld-3", :ace, :spades, 20),
        Card.new("meld-4", :ace, :clubs, 20)
      ]

      prepare_player_hand(
        "meld-game",
        "player-0",
        meld_cards ++ [Card.new("extra", :two, :hearts, 20)]
      )

      {:ok, _game} = Games.draw_from_deck("meld-game", "player-0")

      {:ok, view, _html} = live(conn, ~p"/games/meld-game")

      for card <- meld_cards do
        view
        |> element("button[phx-value-card_id='#{card.id}']")
        |> render_click()
      end

      view
      |> element("#meld-selected")
      |> render_click()

      assert {:ok, game} = Games.get_game("meld-game")
      assert length(game.teams.a.melds) == 1
    end

    test "adds a selected card to an existing meld", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("add-game", 2, ["player-1", "player-2"])

      base_meld =
        Meld.new([
          Card.new("seven-1", :seven, :hearts, 5),
          Card.new("seven-2", :seven, :diamonds, 5),
          Card.new("seven-3", :seven, :spades, 5)
        ])

      extra = Card.new("seven-4", :seven, :clubs, 5)

      {:ok, pid} = Tranca.Games.Supervisor.lookup("add-game")

      :sys.replace_state(pid, fn state ->
        game = state.game

        game =
          game
          |> put_in([Access.key(:teams), :a, Access.key(:melds)], [base_meld])
          |> put_in([Access.key(:teams), :a, Access.key(:first_meld_done)], true)
          |> update_player_hand("player-0", [extra])
          |> Map.put(:drawn_this_turn, true)

        %{state | game: game}
      end)

      {:ok, view, _html} = live(conn, ~p"/games/add-game")

      view
      |> element("button[phx-value-card_id='#{extra.id}']")
      |> render_click()

      view
      |> element("button", "Add selected card")
      |> render_click()

      assert {:ok, game} = Games.get_game("add-game")
      assert length(hd(game.teams.a.melds).cards) == 4
    end

    test "draws a card from the discard pile", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("draw-discard-game", 2, ["player-1", "player-2"])

      {:ok, view, _html} = live(conn, ~p"/games/draw-discard-game")

      assert {:ok, game_before} = Games.get_game("draw-discard-game")
      discard_top = hd(game_before.discard_pile)
      hand_size = length(Enum.find(game_before.players, &(&1.user_id == "player-1")).hand)

      view
      |> element("button[phx-click='draw_discard']")
      |> render_click()

      assert {:ok, game_after} = Games.get_game("draw-discard-game")
      player = Enum.find(game_after.players, &(&1.user_id == "player-1"))
      assert length(player.hand) == hand_size + 1
      assert discard_top in player.hand
      assert game_after.drawn_this_turn
    end

    test "shows an error when melding invalid cards", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("invalid-meld-game", 2, ["player-1", "player-2"])
      {:ok, game} = Games.draw_from_deck("invalid-meld-game", "player-0")
      player = Enum.at(game.players, game.turn)
      [card_1, card_2, card_3] = Enum.take(player.hand, 3)

      {:ok, view, _html} = live(conn, ~p"/games/invalid-meld-game")

      for card <- [card_1, card_2, card_3] do
        view
        |> element("button[phx-value-card_id='#{card.id}']")
        |> render_click()
      end

      html =
        view
        |> element("#meld-selected")
        |> render_click()

      assert html =~ "Invalid meld"
    end

    test "disables action buttons for the non-current player", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-2"})
      setup_playing_game("waiting-turn-game", 2, ["player-1", "player-2"])

      {:ok, view, _html} = live(conn, ~p"/games/waiting-turn-game")

      assert has_element?(view, "#meld-selected[disabled]")
      assert has_element?(view, "#discard-selected[disabled]")
      assert has_element?(view, "button[phx-click='draw_discard'][disabled]")
    end
  end

  defp setup_waiting_game(game_id, player_count, user_ids) do
    {:ok, _record} = Games.create_game_record(game_id, player_count)
    {:ok, _pid} = Games.new_game(game_id, player_count)

    Enum.each(user_ids, fn user_id ->
      {:ok, _game} = Games.join_game(game_id, user_id)
    end)
  end

  defp setup_playing_game(game_id, player_count, user_ids) do
    setup_waiting_game(game_id, player_count, user_ids)
    {:ok, _game} = Games.start_game(game_id)
  end

  defp prepare_player_hand(game_id, player_id, hand) do
    {:ok, pid} = Tranca.Games.Supervisor.lookup(game_id)

    :sys.replace_state(pid, fn state ->
      game = update_player_hand(state.game, player_id, hand)
      %{state | game: game}
    end)
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
