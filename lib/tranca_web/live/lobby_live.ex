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
  def handle_event("create_game", %{"player_count" => count}, socket) do
    player_count = String.to_integer(count)
    game_id = generate_game_code()

    with {:ok, _record} <- Games.create_game_record(game_id, player_count),
         {:ok, _pid} <- Games.new_game(game_id, player_count) do
      Phoenix.PubSub.broadcast(Tranca.PubSub, "lobby", :lobby_updated)
      {:noreply, push_navigate(socket, to: "/games/#{game_id}")}
    else
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not create game. Please try again.")}
    end
  end

  def handle_event("validate_join", %{"join_code" => code}, socket) do
    {:noreply,
     assign(socket, join_code: String.trim(code), form: to_form(%{"join_code" => code}))}
  end

  def handle_event("join_game", %{"join_code" => code}, socket) do
    code = String.trim(code)
    user_id = generate_user_id()

    case Games.join_game(code, user_id) do
      {:ok, _game} ->
        {:noreply, push_navigate(socket, to: "/games/#{code}")}

      {:error, :game_not_found} ->
        {:noreply, assign(socket, error: "Game not found. Check the code and try again.")}

      {:error, :game_full_or_started} ->
        {:noreply, assign(socket, error: "This game is full or no longer accepting players.")}

      {:error, _reason} ->
        {:noreply, assign(socket, error: "Could not join the game. Please try again.")}
    end
  end

  @impl true
  def handle_info(:lobby_updated, socket) do
    {:noreply, assign(socket, games: Games.list_waiting_games())}
  end

  defp generate_game_code do
    bytes = :crypto.strong_rand_bytes(8)

    bytes
    |> Base.encode64()
    |> String.replace(~r/[^a-zA-Z0-9]/, "")
    |> String.slice(0, 6)
    |> String.downcase()
  end

  defp generate_user_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
