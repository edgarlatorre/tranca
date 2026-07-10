defmodule TrancaWeb.LobbyLive do
  @moduledoc """
  LiveView for the game lobby.

  Players can see open games, create a new game, or join an existing game by
  its code.
  """

  use TrancaWeb, :live_view

  alias Tranca.Games

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Tranca.PubSub, "lobby")
    end

    {:ok,
     assign(socket,
       games: Games.list_waiting_games(),
       join_code: "",
       error: nil,
       form: to_form(%{"join_code" => ""}),
       current_scope: nil
     )}
  end

  @impl true
  def handle_event("create_game", _params, socket) do
    game_id = generate_game_code()

    case Games.create_game_record(game_id, 4) do
      {:ok, _record} ->
        Phoenix.PubSub.broadcast(Tranca.PubSub, "lobby", :lobby_updated)
        {:noreply, push_navigate(socket, to: "/games/#{game_id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not create game. Please try again.")}
    end
  end

  def handle_event("validate_join", %{"join_code" => code}, socket) do
    {:noreply,
     assign(socket, join_code: String.trim(code), form: to_form(%{"join_code" => code}))}
  end

  def handle_event("join_game", %{"join_code" => code}, socket) do
    code = String.trim(code)

    case Games.get_game_record(code) do
      {:ok, _record} ->
        {:noreply, push_navigate(socket, to: "/games/#{code}")}

      {:error, :game_not_found} ->
        {:noreply, assign(socket, error: "Game not found. Check the code and try again.")}
    end
  end

  @impl true
  def handle_info(:lobby_updated, socket) do
    {:noreply, assign(socket, games: Games.list_waiting_games())}
  end

  defp generate_game_code do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end
