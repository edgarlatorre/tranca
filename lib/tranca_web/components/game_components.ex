defmodule TrancaWeb.GameComponents do
  @moduledoc """
  UI components for the Tranca game table.

  Includes cards, hands, the draw/discard table area, and team melds.
  """

  use Phoenix.Component

  alias Tranca.Game.Card

  @doc """
  Renders a single playing card.

  ## Examples

      <.card card={%Card{rank: :ace, suit: :hearts}} selected={true} />
  """
  attr :card, Card, required: true
  attr :selected, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def game_card(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "relative w-14 h-20 rounded-lg border-2 shadow-sm flex flex-col items-center justify-center",
        "transition-transform hover:-translate-y-1 focus:outline-hidden",
        red_suit?(@card) && "bg-red-50 border-red-200 text-red-700",
        black_suit?(@card) && "bg-slate-50 border-slate-300 text-slate-800",
        @selected && "ring-2 ring-primary border-primary -translate-y-2"
      ]}
      {@rest}
    >
      <span class="text-lg font-bold leading-none">{format_rank(@card.rank)}</span>
      <span class="text-xl">{format_suit(@card.suit)}</span>
      <%= if Card.wildcard?(@card) do %>
        <span class="absolute top-1 right-1 w-2 h-2 rounded-full bg-amber-400" />
      <% end %>
    </button>
    """
  end

  @doc """
  Renders a player's hand as a fanned row of selectable cards.
  """
  attr :cards, :list, required: true
  attr :selected_ids, :list, default: []
  attr :on_select, :string, required: true
  attr :disabled, :boolean, default: false

  def game_hand(assigns) do
    ~H"""
    <div class="flex flex-wrap justify-center gap-1">
      <%= for card <- @cards do %>
        <.game_card
          card={card}
          selected={card.id in @selected_ids}
          phx-click={@on_select}
          phx-value-card_id={card.id}
          disabled={@disabled}
        />
      <% end %>
    </div>
    """
  end

  @doc """
  Renders the game table: draw pile, discard pile, and morto indicator.
  """
  attr :deck_count, :integer, required: true
  attr :discard_top, Card, default: nil
  attr :morto_count, :integer, required: true
  attr :morto_taken_by, :atom, default: nil
  attr :on_draw_deck, :string, required: true
  attr :on_draw_discard, :string, required: true
  attr :discard_disabled, :boolean, default: false

  def game_table(assigns) do
    ~H"""
    <div class="grid grid-cols-3 gap-4">
      <button
        id="draw-deck"
        type="button"
        phx-click={@on_draw_deck}
        class="card bg-base-200 shadow p-4 flex flex-col items-center justify-center gap-2 hover:bg-base-300 transition"
      >
        <span class="text-sm opacity-75">Deck</span>
        <span class="text-2xl font-bold">{@deck_count}</span>
      </button>

      <button
        type="button"
        phx-click={@on_draw_discard}
        disabled={@discard_disabled}
        class={[
          "card shadow p-4 flex flex-col items-center justify-center gap-2 transition",
          @discard_disabled && "bg-base-300 opacity-60 cursor-not-allowed",
          not @discard_disabled && "bg-base-200 hover:bg-base-300"
        ]}
      >
        <span class="text-sm opacity-75">Discard</span>
        <%= if @discard_top do %>
          <span class="text-2xl font-bold">
            {format_rank(@discard_top.rank)} {format_suit(@discard_top.suit)}
          </span>
        <% else %>
          <span class="text-2xl font-bold">—</span>
        <% end %>
      </button>

      <div
        id="morto-indicator"
        class="card bg-base-200 shadow p-4 flex flex-col items-center justify-center gap-2"
      >
        <span class="text-sm opacity-75">Morto</span>
        <span class="text-2xl font-bold">
          <%= if @morto_taken_by do %>
            Taken
          <% else %>
            {@morto_count}
          <% end %>
        </span>
        <%= if @morto_taken_by do %>
          <span class="text-xs badge badge-sm badge-info">
            Team {String.upcase(to_string(@morto_taken_by))}
          </span>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders the melds for both teams.
  """
  attr :teams, :map, required: true
  attr :on_add_to_meld, :string, default: nil
  attr :selected_card_id, :string, default: nil

  def game_melds(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= for {team_id, team} <- @teams do %>
        <div class="card bg-base-200 shadow p-4 space-y-3">
          <h3 class="text-lg font-semibold">Team {String.upcase(to_string(team_id))}</h3>

          <%= if team.melds == [] do %>
            <p class="text-sm opacity-60">No melds yet.</p>
          <% else %>
            <ul class="space-y-3">
              <%= for {meld, index} <- Enum.with_index(team.melds) do %>
                <li class="space-y-1">
                  <div class="flex flex-wrap gap-1">
                    <%= for card <- meld.cards do %>
                      <.game_card card={card} />
                    <% end %>
                  </div>

                  <%= if @on_add_to_meld && @selected_card_id do %>
                    <button
                      type="button"
                      phx-click={@on_add_to_meld}
                      phx-value-meld_index={index}
                      class="text-xs btn btn-xs btn-ghost"
                    >
                      Add selected card
                    </button>
                  <% end %>

                  <%= if meld.type in [:limpa, :suja] do %>
                    <span class="badge badge-sm badge-success">
                      Canastra
                    </span>
                  <% end %>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp red_suit?(%Card{suit: :hearts}), do: true
  defp red_suit?(%Card{suit: :diamonds}), do: true
  defp red_suit?(%Card{}), do: false

  defp black_suit?(%Card{suit: :spades}), do: true
  defp black_suit?(%Card{suit: :clubs}), do: true
  defp black_suit?(%Card{}), do: true

  defp format_rank(:ace), do: "A"
  defp format_rank(:two), do: "2"
  defp format_rank(:three), do: "3"
  defp format_rank(:four), do: "4"
  defp format_rank(:five), do: "5"
  defp format_rank(:six), do: "6"
  defp format_rank(:seven), do: "7"
  defp format_rank(:eight), do: "8"
  defp format_rank(:nine), do: "9"
  defp format_rank(:ten), do: "10"
  defp format_rank(:jack), do: "J"
  defp format_rank(:queen), do: "Q"
  defp format_rank(:king), do: "K"
  defp format_rank(:joker), do: "★"

  defp format_suit(:hearts), do: "♥"
  defp format_suit(:diamonds), do: "♦"
  defp format_suit(:spades), do: "♠"
  defp format_suit(:clubs), do: "♣"
  defp format_suit(nil), do: ""
end
