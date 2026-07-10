defmodule TrancaWeb.LobbyLiveTest do
  @moduledoc false
  use TrancaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Tranca.Games

  describe "LobbyLive" do
    test "renders the lobby", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      assert has_element?(view, "h1", "Tranca Lobby")
      assert has_element?(view, "#create-game-2p", "2 Players")
      assert has_element?(view, "#create-game-4p", "4 Players")
      assert has_element?(view, "#join-game-form")
      assert has_element?(view, "h2", "Open Games")
    end

    test "lists open games", %{conn: conn} do
      {:ok, _record} = Games.create_game_record("open-game", 4)

      {:ok, view, _html} = live(conn, ~p"/lobby")

      assert has_element?(view, "#open-games", "open-game")
    end

    test "updates open games list when a game is created", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      refute has_element?(view, "#open-games", "broadcast-game")

      {:ok, _record} = Games.create_game_record("broadcast-game", 4)
      Phoenix.PubSub.broadcast(Tranca.PubSub, "lobby", :lobby_updated)

      assert has_element?(view, "#open-games", "broadcast-game")
    end

    test "creates a 2-player game and redirects", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      assert {:error, {:live_redirect, %{to: "/games/" <> game_id}}} =
               render_click(view, "create_game", %{"player_count" => "2"})

      assert String.length(game_id) == 6
      assert {:ok, game} = Games.get_game(game_id)
      assert game.player_count == 2
    end

    test "creates a 4-player game and redirects", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      assert {:error, {:live_redirect, %{to: "/games/" <> game_id}}} =
               render_click(view, "create_game", %{"player_count" => "4"})

      assert String.length(game_id) == 6
      assert {:ok, game} = Games.get_game(game_id)
      assert game.player_count == 4
    end

    test "joins a game with a valid code", %{conn: conn} do
      {:ok, _record} = Games.create_game_record("valid-code", 4)
      {:ok, _pid} = Games.new_game("valid-code", 4)

      {:ok, view, _html} = live(conn, ~p"/lobby")

      assert {:error, {:live_redirect, %{to: "/games/valid-code"}}} =
               render_submit(view, "join_game", %{"join_code" => "valid-code"})
    end

    test "shows an error for an invalid game code", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      html = render_submit(view, "join_game", %{"join_code" => "missing-code"})

      assert html =~ "Game not found"
      assert has_element?(view, "#join-error")
    end

    test "shows an error for a full game", %{conn: conn} do
      {:ok, _record} = Games.create_game_record("full-game", 2)
      {:ok, _pid} = Games.new_game("full-game", 2)
      {:ok, _game} = Games.join_game("full-game", "user-1")
      {:ok, _game} = Games.join_game("full-game", "user-2")

      {:ok, view, _html} = live(conn, ~p"/lobby")

      html = render_submit(view, "join_game", %{"join_code" => "full-game"})

      assert html =~ "full or no longer accepting"
      assert has_element?(view, "#join-error")
    end

    test "shows seated players in open games", %{conn: conn} do
      {:ok, _record} = Games.create_game_record("seated-game", 4)
      {:ok, _pid} = Games.new_game("seated-game", 4)
      {:ok, _game} = Games.join_game("seated-game", "user-1")

      {:ok, view, _html} = live(conn, ~p"/lobby")

      assert has_element?(view, "#open-games", "seated-game")
      assert has_element?(view, "#open-games", "user-1")
    end

    test "assigns alternating teams when joining a 4-player game", %{conn: conn} do
      {:ok, _record} = Games.create_game_record("team-game", 4)
      {:ok, _pid} = Games.new_game("team-game", 4)

      {:ok, view1, _html} = live(conn, ~p"/lobby")

      assert {:error, {:live_redirect, %{to: "/games/team-game"}}} =
               render_submit(view1, "join_game", %{"join_code" => "team-game"})

      assert {:ok, game} = Games.get_game("team-game")
      assert length(game.players) == 1
      assert hd(game.players).team == :a

      conn2 = Phoenix.ConnTest.build_conn()
      {:ok, view2, _html} = live(conn2, ~p"/lobby")

      assert {:error, {:live_redirect, %{to: "/games/team-game"}}} =
               render_submit(view2, "join_game", %{"join_code" => "team-game"})

      assert {:ok, game} = Games.get_game("team-game")
      [_, player2] = Enum.sort_by(game.players, & &1.seat)
      assert player2.team == :b
    end
  end
end
