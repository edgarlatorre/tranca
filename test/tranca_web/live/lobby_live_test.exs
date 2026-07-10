defmodule TrancaWeb.LobbyLiveTest do
  @moduledoc false
  use TrancaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Tranca.Games

  describe "LobbyLive" do
    test "renders the lobby", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/lobby")

      assert html =~ "Tranca Lobby"
      assert html =~ "Create Game"
      assert html =~ "Join Game"
      assert html =~ "Open Games"
    end

    test "lists open games", %{conn: conn} do
      {:ok, _record} = Games.create_game_record("open-game", 4)

      {:ok, _view, html} = live(conn, ~p"/lobby")

      assert html =~ "open-game"
    end

    test "creates a 2-player game and redirects", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      assert {:error, {:live_redirect, %{to: "/games/" <> game_id}}} =
               render_click(view, "create_game", %{"player_count" => "2"})

      assert String.length(game_id) == 6
      assert {:ok, game} = Tranca.Games.get_game(game_id)
      assert game.player_count == 2
    end

    test "creates a 4-player game and redirects", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      assert {:error, {:live_redirect, %{to: "/games/" <> game_id}}} =
               render_click(view, "create_game", %{"player_count" => "4"})

      assert String.length(game_id) == 6
      assert {:ok, game} = Tranca.Games.get_game(game_id)
      assert game.player_count == 4
    end

    test "joins a game with a valid code", %{conn: conn} do
      {:ok, _record} = Games.create_game_record("valid-code", 4)

      {:ok, view, _html} = live(conn, ~p"/lobby")

      assert {:error, {:live_redirect, %{to: "/games/valid-code"}}} =
               render_submit(view, "join_game", %{"join_code" => "valid-code"})
    end

    test "shows an error for an invalid game code", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      html = render_submit(view, "join_game", %{"join_code" => "missing-code"})

      assert html =~ "Game not found"
    end
  end
end
