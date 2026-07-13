defmodule TrancaWeb.GameLive do
  @moduledoc """
  LiveView for an active Tranca game table.

  Subscribes to the game PubSub topic and re-renders whenever the game
  server broadcasts an update. Players who land here while a game is still
  waiting are automatically joined if a seat is available.
  """

  use TrancaWeb, :live_view

  import TrancaWeb.GameComponents

  alias Tranca.Game
  alias Tranca.Game.Card
  alias Tranca.Games

  @impl true
  def mount(%{"id" => game_id}, session, socket) do
    user_id = Map.get(session, "user_id")

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Tranca.PubSub, "game:#{game_id}")
    end

    socket =
      socket
      |> assign(:game_id, game_id)
      |> assign(:user_id, user_id)
      |> assign(:error, nil)
      |> assign(:message, nil)
      |> assign(:selected_card_ids, [])
      |> assign(:show_round_end, false)
      |> assign(:rounds, [])
      |> assign(:current_scope, nil)
      |> load_game()
      |> load_rounds()
      |> assign_helpers()

    {:ok, socket}
  end

  @impl true
  def handle_info({:game_updated, game}, socket) do
    socket =
      socket
      |> assign(:game, game)
      |> assign(:current_player, find_player(game, socket.assigns.user_id))
      |> assign_helpers()

    {:noreply, socket}
  end

  def handle_info({:rematch_created, new_game_id}, socket) do
    {:noreply, push_navigate(socket, to: "/games/#{new_game_id}")}
  end

  @impl true
  def handle_event("select_card", %{"card_id" => card_id}, socket) do
    selected =
      if card_id in socket.assigns.selected_card_ids do
        List.delete(socket.assigns.selected_card_ids, card_id)
      else
        [card_id | socket.assigns.selected_card_ids]
      end

    {:noreply, assign(socket, selected_card_ids: selected)}
  end

  def handle_event("draw_deck", _params, socket) do
    case Games.draw_from_deck(socket.assigns.game_id, player_id(socket)) do
      {:ok, _game} -> {:noreply, assign(socket, message: nil)}
      {:error, reason} -> {:noreply, assign(socket, message: format_error(reason))}
    end
  end

  def handle_event("draw_discard", _params, socket) do
    case Games.draw_from_discard(socket.assigns.game_id, player_id(socket)) do
      {:ok, _game} -> {:noreply, assign(socket, message: nil)}
      {:error, reason} -> {:noreply, assign(socket, message: format_error(reason))}
    end
  end

  def handle_event("meld_selected", _params, socket) do
    game_id = socket.assigns.game_id
    player_id = player_id(socket)
    card_ids = socket.assigns.selected_card_ids

    case Games.meld(game_id, player_id, card_ids) do
      {:ok, _game} ->
        {:noreply, assign(socket, selected_card_ids: [], message: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, message: format_error(reason))}
    end
  end

  def handle_event("discard_selected", _params, socket) do
    game_id = socket.assigns.game_id
    player_id = player_id(socket)

    case socket.assigns.selected_card_ids do
      [card_id] ->
        case Games.discard(game_id, player_id, card_id) do
          {:ok, _game} ->
            {:noreply, assign(socket, selected_card_ids: [], message: nil)}

          {:error, reason} ->
            {:noreply, assign(socket, message: format_error(reason))}
        end

      _ ->
        {:noreply, assign(socket, message: "Select a single card to discard.")}
    end
  end

  def handle_event("add_to_meld", %{"meld_index" => index}, socket) do
    game_id = socket.assigns.game_id
    player_id = player_id(socket)

    case socket.assigns.selected_card_ids do
      [card_id] ->
        case Games.add_to_meld(game_id, player_id, String.to_integer(index), card_id) do
          {:ok, _game} ->
            {:noreply, assign(socket, selected_card_ids: [], message: nil)}

          {:error, reason} ->
            {:noreply, assign(socket, message: format_error(reason))}
        end

      _ ->
        {:noreply, assign(socket, message: "Select a single card to add to a meld.")}
    end
  end

  def handle_event("replace_joker", %{"meld_index" => index}, socket) do
    game_id = socket.assigns.game_id
    player_id = player_id(socket)

    case socket.assigns.selected_card_ids do
      [card_id] ->
        case Games.replace_joker(game_id, player_id, String.to_integer(index), card_id) do
          {:ok, _game} ->
            {:noreply, assign(socket, selected_card_ids: [], message: nil)}

          {:error, reason} ->
            {:noreply, assign(socket, message: format_error(reason))}
        end

      _ ->
        {:noreply, assign(socket, message: "Select a single card to replace the joker.")}
    end
  end

  def handle_event("score_round", _params, socket) do
    case Games.score_round(socket.assigns.game_id) do
      {:ok, game} ->
        socket =
          socket
          |> assign(:game, game)
          |> assign(:show_round_end, game.status != :finished)
          |> assign(:round_breakdown, Game.round_breakdown(game))
          |> assign_helpers()

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, assign(socket, message: format_error(reason))}
    end
  end

  def handle_event("continue_round", _params, socket) do
    {:noreply, assign(socket, show_round_end: false)}
  end

  def handle_event("rematch", _params, socket) do
    game_id = socket.assigns.game_id
    user_id = socket.assigns.user_id

    with {:ok, game} <- Games.get_game(game_id),
         {:ok, new_record} <- Games.create_game_record(generate_game_code(), game.player_count),
         {:ok, _pid} <- Games.new_game(new_record.game_id, game.player_count),
         {:ok, _game} <- Games.join_game(new_record.game_id, user_id) do
      Phoenix.PubSub.broadcast(
        Tranca.PubSub,
        "game:#{game_id}",
        {:rematch_created, new_record.game_id}
      )

      {:noreply, push_navigate(socket, to: "/games/#{new_record.game_id}")}
    else
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not create rematch. Please try again.")}
    end
  end

  defp generate_game_code do
    bytes = :crypto.strong_rand_bytes(8)

    bytes
    |> Base.encode64()
    |> String.replace(~r/[^a-zA-Z0-9]/, "")
    |> String.slice(0, 6)
    |> String.downcase()
  end

  defp load_game(socket) do
    game_id = socket.assigns.game_id
    user_id = socket.assigns.user_id

    case Games.get_game(game_id) do
      {:ok, game} ->
        game = maybe_join_user(game, game_id, user_id)

        assign(socket,
          game: game,
          current_player: find_player(game, user_id)
        )

      {:error, :game_not_found} ->
        assign(socket, game: nil, error: "Game not found.")
    end
  end

  defp load_rounds(%{assigns: %{game: %{status: :finished}}} = socket) do
    case Games.list_rounds(socket.assigns.game_id) do
      {:ok, rounds} -> assign(socket, rounds: rounds)
      {:error, _} -> assign(socket, rounds: [])
    end
  end

  defp load_rounds(socket), do: assign(socket, rounds: [])

  defp assign_helpers(%{assigns: %{game: nil}} = socket) do
    assign(socket,
      my_turn: false,
      can_draw: false,
      can_act: false,
      discard_blocked: false
    )
  end

  defp assign_helpers(socket) do
    assign(socket,
      my_turn: my_turn?(socket),
      can_draw: can_draw?(socket),
      can_act: can_act?(socket),
      discard_blocked: discard_blocked?(socket)
    )
  end

  defp maybe_join_user(%Game{status: :waiting} = game, game_id, user_id) do
    if user_id && not seated?(game, user_id) do
      case Games.join_game(game_id, user_id) do
        {:ok, game} -> game
        {:error, _reason} -> game
      end
    else
      game
    end
  end

  defp maybe_join_user(%Game{} = game, _game_id, _user_id), do: game

  defp seated?(game, user_id) do
    Enum.any?(game.players, &(&1.user_id == user_id))
  end

  defp find_player(game, user_id) do
    Enum.find(game.players, &(&1.user_id == user_id))
  end

  defp player_id(socket) do
    socket.assigns.current_player && socket.assigns.current_player.id
  end

  defp my_turn?(socket) do
    game = socket.assigns.game
    current = Game.current_player(game)
    current && current.id == player_id(socket)
  end

  defp can_draw?(socket) do
    game = socket.assigns.game
    my_turn?(socket) && game.status == :playing && not game.drawn_this_turn
  end

  defp can_act?(socket) do
    game = socket.assigns.game
    my_turn?(socket) && game.status == :playing && game.drawn_this_turn
  end

  defp discard_blocked?(socket) do
    case socket.assigns.game.discard_pile do
      [top | _] -> Card.black_three?(top)
      _ -> false
    end
  end

  defp format_error(:not_your_turn), do: "It's not your turn."
  defp format_error(:already_drew), do: "You already drew this turn."
  defp format_error(:must_draw_first), do: "Draw a card first."
  defp format_error(:card_not_in_hand), do: "Selected card is not in your hand."
  defp format_error(:invalid_meld), do: "Invalid meld."

  defp format_error(:first_meld_minimum_not_met),
    do: "First meld must be worth at least 75 points."

  defp format_error(:discard_blocked_by_black_three),
    do: "Discard pile is blocked by a black three."

  defp format_error(:no_joker_in_meld), do: "That meld has no joker to replace."
  defp format_error(:invalid_replacement_card), do: "Selected card cannot replace the joker."
  defp format_error(:invalid_meld_index), do: "Invalid meld."
  defp format_error(_reason), do: "Could not perform that action."
end
