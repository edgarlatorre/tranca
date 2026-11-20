defmodule TrancaWeb.GameComponents do
  @moduledoc """
  UI components for the Tranca game table.

  Includes cards, hands, the draw/discard table area, and team melds.
  """

  use Phoenix.Component

  alias Tranca.Game.Card

  @doc """
  Renders a single playing card as a button.

  ## Examples

      <.game_card card={%Card{rank: :ace, suit: :hearts}} selected={true} />
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
        card_face_classes(@card, :md),
        "transition-transform hover:-translate-y-1 focus:outline-hidden active:scale-95",
        @selected && "ring-2 ring-primary border-primary -translate-y-2"
      ]}
      {@rest}
    >
      <.card_contents card={@card} size={:md} />
    </button>
    """
  end

  @doc """
  Renders a face-up card that is not interactive on its own, for use inside
  another clickable element such as the discard pile.
  """
  attr :card, Card, required: true
  attr :size, :atom, values: [:md, :lg], default: :md
  attr :class, :any, default: nil
  attr :rest, :global

  def card_face(assigns) do
    ~H"""
    <div class={[card_face_classes(@card, @size), @class]} {@rest}>
      <.card_contents card={@card} size={@size} />
    </div>
    """
  end

  @doc """
  Renders a face-down card (the card back), used for the deck and morto.
  """
  attr :size, :atom, values: [:md, :lg], default: :lg
  attr :class, :any, default: nil
  attr :rest, :global

  def card_back(assigns) do
    ~H"""
    <div
      class={[
        "card-back rounded-lg border-2 border-white/80 shadow-sm",
        card_size_classes(@size),
        @class
      ]}
      aria-hidden="true"
      {@rest}
    />
    """
  end

  attr :card, Card, required: true
  attr :size, :atom, required: true

  defp card_contents(assigns) do
    ~H"""
    <span class={[
      "font-bold leading-none",
      if(@size == :lg, do: "text-lg sm:text-2xl", else: "text-base sm:text-lg")
    ]}>
      {format_rank(@card.rank)}
    </span>
    <span class={if(@size == :lg, do: "text-xl sm:text-3xl", else: "text-lg sm:text-xl")}>
      {format_suit(@card.suit)}
    </span>
    <%= if Card.wildcard?(@card) do %>
      <span class="absolute top-1 right-1 w-1.5 h-1.5 sm:w-2 sm:h-2 rounded-full bg-amber-400" />
    <% end %>
    """
  end

  defp card_face_classes(card, size) do
    [
      "relative rounded-lg border-2 shadow-sm flex flex-col items-center justify-center shrink-0",
      card_size_classes(size),
      red_suit?(card) && "bg-red-50 border-red-200 text-red-700",
      black_suit?(card) && "bg-slate-50 border-slate-300 text-slate-800"
    ]
  end

  defp card_size_classes(:md),
    do: "w-11 h-15 sm:w-14 sm:h-20 min-w-[2.75rem] min-h-[3.75rem] sm:min-w-0 sm:min-h-0"

  defp card_size_classes(:lg), do: "w-14 h-20 sm:w-20 sm:h-28"

  @doc """
  Renders a player's hand as a fanned row of selectable cards.
  """
  attr :cards, :list, required: true
  attr :selected_ids, :list, default: []
  attr :on_select, :string, required: true
  attr :disabled, :boolean, default: false

  def game_hand(assigns) do
    ~H"""
    <div id="player-hand" class="flex flex-wrap justify-center gap-1 sm:gap-1.5 pt-2">
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
  Renders the game table as three card piles: the deck (face down), the
  discard pile (top card face up), and the morto (face down until taken).

  Clicking the deck or discard pile triggers the given draw events. The
  discard pile looks disabled when `discard_disabled` is true.
  """
  attr :deck_count, :integer, required: true
  attr :discard_top, Card, default: nil
  attr :discard_count, :integer, default: 0
  attr :morto_count, :integer, required: true
  attr :morto_taken_by, :atom, default: nil
  attr :on_draw_deck, :string, required: true
  attr :on_draw_discard, :string, required: true
  attr :discard_disabled, :boolean, default: false

  def game_table(assigns) do
    ~H"""
    <div
      id="game-table"
      class="grid grid-cols-3 gap-2 sm:gap-6 justify-items-center rounded-box bg-base-200 shadow px-2 py-4 sm:p-6"
    >
      <button
        id="draw-deck"
        type="button"
        phx-click={@on_draw_deck}
        aria-label={"Draw from the deck (#{@deck_count} cards left)"}
        class="group flex flex-col items-center gap-2 focus:outline-hidden"
      >
        <%= if @deck_count > 0 do %>
          <.card_back class={[
            "transition-transform group-hover:-translate-y-1 group-focus-visible:ring-2 group-focus-visible:ring-primary group-active:scale-95",
            pile_depth_class(@deck_count)
          ]} />
        <% else %>
          <.empty_slot />
        <% end %>
        <.pile_label label="Deck" count={@deck_count} />
      </button>

      <button
        id="draw-discard"
        type="button"
        phx-click={@on_draw_discard}
        disabled={@discard_disabled}
        aria-label="Draw from the discard pile"
        class={[
          "group flex flex-col items-center gap-2 focus:outline-hidden",
          @discard_disabled && "cursor-not-allowed"
        ]}
      >
        <%= if @discard_top do %>
          <.card_face
            id="discard-top"
            card={@discard_top}
            size={:lg}
            class={[
              "transition",
              pile_depth_class(@discard_count),
              @discard_disabled && "opacity-50 grayscale",
              not @discard_disabled &&
                "group-hover:-translate-y-1 group-focus-visible:ring-2 group-focus-visible:ring-primary group-active:scale-95"
            ]}
          />
        <% else %>
          <.empty_slot />
        <% end %>
        <.pile_label label="Discard" count={@discard_count} />
      </button>

      <div id="morto-indicator" class="flex flex-col items-center gap-2">
        <%= if @morto_taken_by do %>
          <.empty_slot>
            <span class="text-xs font-semibold">Taken</span>
          </.empty_slot>
          <span class="flex flex-col items-center leading-tight">
            <span class="text-xs sm:text-sm font-medium opacity-75">Morto</span>
            <span class="badge badge-sm badge-info">
              Team {String.upcase(to_string(@morto_taken_by))}
            </span>
          </span>
        <% else %>
          <.card_back class={pile_depth_class(@morto_count)} />
          <.pile_label label="Morto" count={@morto_count} />
        <% end %>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :count, :integer, required: true

  defp pile_label(assigns) do
    ~H"""
    <span class="flex flex-col items-center leading-tight">
      <span class="text-xs sm:text-sm font-medium opacity-75">{@label}</span>
      <span class="text-base sm:text-lg font-bold tabular-nums">{@count}</span>
    </span>
    """
  end

  slot :inner_block

  defp empty_slot(assigns) do
    ~H"""
    <div class={[
      "rounded-lg border-2 border-dashed border-base-content/25 flex items-center justify-center text-base-content/50",
      card_size_classes(:lg)
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # Stacked-card shadow that hints at how many cards are in a pile.
  defp pile_depth_class(count) when count > 10, do: "pile-deep"
  defp pile_depth_class(count) when count > 1, do: "pile-shallow"
  defp pile_depth_class(_count), do: nil

  @doc """
  Renders one team's melds.

  Action buttons (add a card, replace a joker) are only shown when the
  corresponding event names are given, so pass them only for the player's
  own team.
  """
  attr :id, :string, required: true
  attr :team_id, :atom, required: true
  attr :team, :map, required: true
  attr :label, :string, required: true
  attr :on_add_to_meld, :string, default: nil
  attr :on_replace_joker, :string, default: nil
  attr :selected_card_id, :string, default: nil

  def game_melds(assigns) do
    ~H"""
    <div id={@id} class="card bg-base-200 shadow p-3 sm:p-4 space-y-3">
      <h3 class="text-sm font-semibold uppercase tracking-wide opacity-70">
        {@label} · Team {String.upcase(to_string(@team_id))}
      </h3>

      <%= if @team.red_threes != [] do %>
        <div id={"#{@id}-red-threes"} class="flex flex-wrap items-center gap-2">
          <span class="text-xs font-medium uppercase tracking-wide opacity-60">Red 3s</span>
          <div class="flex flex-wrap gap-1">
            <%= for card <- @team.red_threes do %>
              <.game_card card={card} id={"red-three-#{card.id}"} />
            <% end %>
          </div>
          <span class="badge badge-sm badge-error badge-outline">
            +{length(@team.red_threes) * 100}
          </span>
        </div>
      <% end %>

      <%= if @team.melds == [] do %>
        <p class="text-sm opacity-60">No melds yet.</p>
      <% else %>
        <ul class="flex flex-wrap gap-x-6 gap-y-3">
          <%= for {meld, index} <- Enum.with_index(@team.melds) do %>
            <li class="space-y-1">
              <div class="flex flex-wrap gap-1">
                <%= for card <- meld.cards do %>
                  <.game_card card={card} />
                <% end %>
              </div>

              <div class="flex flex-wrap items-center gap-2">
                <%= if meld.type in [:limpa, :suja] do %>
                  <span class="badge badge-sm badge-success">Canastra</span>
                <% end %>

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

                <%= if @on_replace_joker && @selected_card_id && joker_in_meld?(meld) do %>
                  <button
                    type="button"
                    phx-click={@on_replace_joker}
                    phx-value-meld_index={index}
                    class="text-xs btn btn-xs btn-secondary"
                  >
                    Replace joker
                  </button>
                <% end %>
              </div>
            </li>
          <% end %>
        </ul>
      <% end %>
    </div>
    """
  end

  defp red_suit?(%Card{suit: :hearts}), do: true
  defp red_suit?(%Card{suit: :diamonds}), do: true
  defp red_suit?(%Card{}), do: false

  # Spades, clubs and jokers (nil suit) use the dark card style.
  defp black_suit?(%Card{} = card), do: not red_suit?(card)

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

  defp joker_in_meld?(meld) do
    Enum.any?(meld.cards, &Card.wildcard?/1)
  end
end
