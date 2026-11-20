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
          Card.new("four-1", :four, :hearts, 5),
          Card.new("four-2", :four, :diamonds, 5),
          Card.new("four-3", :four, :spades, 5)
        ])

      extra = Card.new("four-4", :four, :clubs, 5)

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

      safe_discard = Card.new("safe-discard", :five, :hearts, 5)

      {:ok, pid} = Tranca.Games.Supervisor.lookup("draw-discard-game")

      :sys.replace_state(pid, fn state ->
        %{state | game: %{state.game | discard_pile: [safe_discard]}}
      end)

      {:ok, view, _html} = live(conn, ~p"/games/draw-discard-game")

      assert {:ok, game_before} = Games.get_game("draw-discard-game")
      hand_size = length(Enum.find(game_before.players, &(&1.user_id == "player-1")).hand)

      view
      |> element("button[phx-click='draw_discard']")
      |> render_click()

      assert {:ok, game_after} = Games.get_game("draw-discard-game")
      player = Enum.find(game_after.players, &(&1.user_id == "player-1"))
      assert length(player.hand) == hand_size + 1
      assert safe_discard in player.hand
      assert game_after.drawn_this_turn
    end

    test "shows an error when melding invalid cards", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("invalid-meld-game", 2, ["player-1", "player-2"])

      invalid_cards = [
        Card.new("invalid-1", :ace, :hearts, 20),
        Card.new("invalid-2", :four, :diamonds, 5),
        Card.new("invalid-3", :king, :spades, 10)
      ]

      prepare_player_hand("invalid-meld-game", "player-0", invalid_cards)
      {:ok, _game} = Games.draw_from_deck("invalid-meld-game", "player-0")

      {:ok, view, _html} = live(conn, ~p"/games/invalid-meld-game")

      for card <- invalid_cards do
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

    test "explains that same-rank melds are only for aces and 4s", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("king-set-game", 2, ["player-1", "player-2"])

      kings = [
        Card.new("king-1", :king, :hearts, 10),
        Card.new("king-2", :king, :diamonds, 10),
        Card.new("king-3", :king, :spades, 10)
      ]

      prepare_player_hand("king-set-game", "player-0", kings)
      {:ok, _game} = Games.draw_from_deck("king-set-game", "player-0")

      {:ok, view, _html} = live(conn, ~p"/games/king-set-game")

      for card <- kings do
        view
        |> element("button[phx-value-card_id='#{card.id}']")
        |> render_click()
      end

      html =
        view
        |> element("#meld-selected")
        |> render_click()

      assert html =~ "only allowed for aces and 4s"
    end

    test "places a selected red 3 in the team's meld area", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("red-three-game", 2, ["player-1", "player-2"])

      red_three = Card.new("red-three", :three, :diamonds, 5)
      ace = Card.new("plain-ace", :ace, :spades, 15)

      prepare_player_hand("red-three-game", "player-0", [red_three, ace])
      {:ok, _game} = Games.draw_from_deck("red-three-game", "player-0")

      {:ok, view, _html} = live(conn, ~p"/games/red-three-game")

      view |> element("button[phx-value-card_id='plain-ace']") |> render_click()
      refute has_element?(view, "#place-red-three")
      view |> element("button[phx-value-card_id='plain-ace']") |> render_click()

      view |> element("button[phx-value-card_id='red-three']") |> render_click()
      view |> element("#place-red-three") |> render_click()

      assert has_element?(view, "#own-melds-red-threes #red-three-red-three")
      refute has_element?(view, "#player-hand button[phx-value-card_id='red-three']")

      {:ok, game} = Games.get_game("red-three-game")
      assert game.teams.a.red_threes == [red_three]
    end

    test "disables action buttons for the non-current player", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-2"})
      setup_playing_game("waiting-turn-game", 2, ["player-1", "player-2"])

      {:ok, view, _html} = live(conn, ~p"/games/waiting-turn-game")

      assert has_element?(view, "#meld-selected[disabled]")
      assert has_element?(view, "#discard-selected[disabled]")
      assert has_element?(view, "button[phx-click='draw_discard'][disabled]")
    end

    test "shows morto indicator when morto is available", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("morto-available-game", 2, ["player-1", "player-2"])

      {:ok, view, _html} = live(conn, ~p"/games/morto-available-game")

      assert has_element?(view, "#morto-indicator", "11")
      refute has_element?(view, "#morto-indicator", "Taken")
    end

    test "picks up morto automatically when player goes out with a canastra", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("morto-pickup-game", 2, ["player-1", "player-2"])

      last_card = Card.new("last-card", :four, :hearts, 5)

      limpa =
        Meld.new(
          for {suit, i} <-
                Enum.with_index([
                  :hearts,
                  :diamonds,
                  :spades,
                  :clubs,
                  :hearts,
                  :diamonds,
                  :spades
                ]) do
            Card.new("limpa-#{i}", :four, suit, 5)
          end
        )

      {:ok, pid} = Tranca.Games.Supervisor.lookup("morto-pickup-game")

      :sys.replace_state(pid, fn state ->
        game = state.game

        game =
          game
          |> put_in([Access.key(:teams), :a, Access.key(:melds)], [limpa])
          |> put_in([Access.key(:teams), :a, Access.key(:first_meld_done)], true)
          |> update_player_hand("player-0", [last_card])
          |> Map.put(:drawn_this_turn, true)

        %{state | game: game}
      end)

      {:ok, view, _html} = live(conn, ~p"/games/morto-pickup-game")

      view
      |> element("button[phx-value-card_id='#{last_card.id}']")
      |> render_click()

      view
      |> element("#discard-selected")
      |> render_click()

      assert has_element?(view, "#morto-indicator", "Taken")
      assert has_element?(view, "#morto-indicator", "Team A")

      assert {:ok, game} = Games.get_game("morto-pickup-game")
      assert game.morto == []
      assert game.morto_taken_by == :a
    end

    test "shows morto indicator with team when taken", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("morto-taken-game", 2, ["player-1", "player-2"])

      {:ok, pid} = Tranca.Games.Supervisor.lookup("morto-taken-game")

      :sys.replace_state(pid, fn state ->
        %{state | game: %{state.game | morto: [], morto_taken_by: :a}}
      end)

      {:ok, view, _html} = live(conn, ~p"/games/morto-taken-game")

      assert has_element?(view, "#morto-indicator", "Taken")
      assert has_element?(view, "#morto-indicator", "Team A")
    end

    test "replaces a joker in a meld with a selected card", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("replace-joker-game", 2, ["player-1", "player-2"])

      joker = Card.new("joker", :joker, nil, 50)
      natural = Card.new("natural", :four, :hearts, 5)

      meld =
        Meld.new([
          Card.new("four-1", :four, :diamonds, 5),
          Card.new("four-2", :four, :spades, 5),
          joker
        ])

      {:ok, pid} = Tranca.Games.Supervisor.lookup("replace-joker-game")

      :sys.replace_state(pid, fn state ->
        game = state.game

        game =
          game
          |> put_in([Access.key(:teams), :a, Access.key(:melds)], [meld])
          |> update_player_hand("player-0", [natural])
          |> Map.put(:drawn_this_turn, true)

        %{state | game: game}
      end)

      {:ok, view, _html} = live(conn, ~p"/games/replace-joker-game")

      view
      |> element("button[phx-value-card_id='#{natural.id}']")
      |> render_click()

      view
      |> element("button", "Replace joker")
      |> render_click()

      assert {:ok, game} = Games.get_game("replace-joker-game")
      [updated_meld] = game.teams.a.melds
      refute Enum.any?(updated_meld.cards, &(&1.rank == :joker))
      assert Enum.any?(updated_meld.cards, &(&1.id == natural.id))
    end

    test "shows black three discard block message", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("black-three-game", 2, ["player-1", "player-2"])

      black_three = Card.new("black-three", :three, :spades, 5)

      {:ok, pid} = Tranca.Games.Supervisor.lookup("black-three-game")

      :sys.replace_state(pid, fn state ->
        %{state | game: %{state.game | discard_pile: [black_three]}}
      end)

      {:ok, view, _html} = live(conn, ~p"/games/black-three-game")

      assert has_element?(view, "#black-three-block", "blocked by a black three")
      assert has_element?(view, "button[phx-click='draw_discard'][disabled]")
    end

    test "shows round end screen with breakdown", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("round-end-game", 2, ["player-1", "player-2"])

      {:ok, pid} = Tranca.Games.Supervisor.lookup("round-end-game")

      :sys.replace_state(pid, fn state ->
        game = state.game

        limpa =
          Meld.new(
            for {suit, i} <-
                  Enum.with_index([
                    :hearts,
                    :diamonds,
                    :spades,
                    :clubs,
                    :hearts,
                    :diamonds,
                    :spades
                  ]) do
              Card.new("limpa-#{i}", :four, suit, 5)
            end
          )

        game =
          game
          |> put_in([Access.key(:teams), :a, Access.key(:melds)], [limpa])
          |> update_player_hand("player-0", [])
          |> update_player_hand("player-1", [])

        %{state | game: game}
      end)

      {:ok, view, _html} = live(conn, ~p"/games/round-end-game")

      view
      |> element("#score-round")
      |> render_click()

      assert has_element?(view, "#round-end", "Round 1 Complete")
      assert has_element?(view, "#round-end", "Meld points")
      assert has_element?(view, "#round-end", "Canastra bonus")
    end

    test "shows game over screen with scores and round history", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("game-over-game", 2, ["player-1", "player-2"])
      {:ok, _} = Games.save_round_result("game-over-game", 1, 1500, 800, "a")

      {:ok, pid} = Tranca.Games.Supervisor.lookup("game-over-game")

      :sys.replace_state(pid, fn state ->
        game = state.game

        %{
          state
          | game: %{
              game
              | status: :finished,
                winner: :a,
                teams: %{a: %{game.teams.a | score: 1500}, b: %{game.teams.b | score: 800}}
            }
        }
      end)

      {:ok, view, _html} = live(conn, ~p"/games/game-over-game")

      assert has_element?(view, "#game-over", "Team A wins!")
      assert has_element?(view, "#game-over", "1500")
      assert has_element?(view, "#game-over", "800")
      assert has_element?(view, "#game-over", "Round History")
      assert has_element?(view, "#game-over", "Round 1")
    end

    test "creates a rematch and redirects", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("rematch-game", 2, ["player-1", "player-2"])

      {:ok, pid} = Tranca.Games.Supervisor.lookup("rematch-game")

      :sys.replace_state(pid, fn state ->
        game = state.game
        %{state | game: %{game | status: :finished, winner: :a}}
      end)

      {:ok, view, _html} = live(conn, ~p"/games/rematch-game")

      assert {:error, {:live_redirect, %{to: "/games/" <> new_game_id}}} =
               render_click(view, "rematch")

      assert String.length(new_game_id) == 6
      assert {:ok, game} = Games.get_game(new_game_id)
      assert game.player_count == 2
    end

    test "redirects when a rematch is broadcast via PubSub", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-2"})
      setup_playing_game("rematch-pubsub-game", 2, ["player-1", "player-2"])

      {:ok, view, _html} = live(conn, ~p"/games/rematch-pubsub-game")

      Phoenix.PubSub.broadcast(
        Tranca.PubSub,
        "game:rematch-pubsub-game",
        {:rematch_created, "rematch-new"}
      )

      assert_redirect(view, "/games/rematch-new")
    end

    test "rejoins a player on refresh during an active game", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("rejoin-game", 2, ["player-1", "player-2"])

      {:ok, pid} = Tranca.Games.Supervisor.lookup("rejoin-game")

      :sys.replace_state(pid, fn state ->
        [player_0] = Enum.filter(state.game.players, &(&1.user_id == "player-2"))
        %{state | game: %{state.game | players: [player_0]}}
      end)

      {:ok, view, _html} = live(conn, ~p"/games/rejoin-game")

      assert has_element?(view, "span", "You")

      assert {:ok, game} = Games.get_game("rejoin-game")
      assert length(game.players) == 2
      assert Enum.any?(game.players, &(&1.user_id == "player-1"))
    end

    test "shows the opponent's melds on top and the player's own team at the bottom", %{
      conn: conn
    } do
      setup_playing_game("meld-sides-game", 2, ["player-1", "player-2"])
      {:ok, game} = Games.get_game("meld-sides-game")

      for user_id <- ["player-1", "player-2"] do
        player = Enum.find(game.players, &(&1.user_id == user_id))
        own = player.team |> to_string() |> String.upcase()
        other = if player.team == :a, do: "B", else: "A"

        conn = Plug.Test.init_test_session(conn, %{"user_id" => user_id})
        {:ok, view, _html} = live(conn, ~p"/games/meld-sides-game")

        assert has_element?(view, "#own-melds", "Team #{own}")
        assert has_element?(view, "#opponent-melds", "Team #{other}")
      end
    end

    test "renders responsive layout for mobile", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, %{"user_id" => "player-1"})
      setup_playing_game("responsive-game", 2, ["player-1", "player-2"])

      {:ok, view, html} = live(conn, ~p"/games/responsive-game")

      # The hand wraps onto multiple rows instead of scrolling horizontally
      assert has_element?(view, "#player-hand.flex-wrap")
      refute html =~ "overflow-x-auto"
      assert html =~ "min-h-[2.75rem]"
      assert html =~ "w-full sm:w-auto"
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
