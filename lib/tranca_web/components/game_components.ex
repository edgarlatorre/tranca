defmodule TrancaWeb.GameComponents do
  @moduledoc """
  UI components for the Tranca card table.

  Includes cards (face up and face down), the player's hand, the deck /
  discard / morto piles, team melds, player seats, and the table's action
  buttons. Components are styled to sit on the green felt table surface.
  """

  use Phoenix.Component

  alias Tranca.Game.Card

  @card_sizes [:xs, :sm, :md, :lg]

  @doc """
  Renders a single playing card as a button.

  ## Examples

      <.game_card card={%Card{rank: :ace, suit: :hearts}} selected={true} />
  """
  attr :card, Card, required: true
  attr :selected, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global

  def game_card(assigns) do
    ~H"""
    <button
      type="button"
      disabled={@disabled}
      class={[
        card_face_classes(@card, :md),
        "shadow-md transition-[translate,box-shadow] duration-150 focus:outline-hidden",
        "focus-visible:ring-2 focus-visible:ring-amber-300",
        not @disabled && "hover:-translate-y-1.5 active:scale-95",
        @selected && "-translate-y-3 ring-2 ring-amber-300 border-amber-300 shadow-lg z-10",
        @class
      ]}
      {@rest}
    >
      <.card_contents card={@card} size={:md} />
    </button>
    """
  end

  @doc """
  Renders a face-up card that is not interactive on its own, for use in
  melds or inside another clickable element such as the discard pile.
  """
  attr :card, Card, required: true
  attr :size, :atom, values: @card_sizes, default: :md
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
  Renders a face-down card (the card back), used for the deck, the morto
  and other players' hands.
  """
  attr :size, :atom, values: @card_sizes, default: :lg
  attr :class, :any, default: nil
  attr :rest, :global

  def card_back(assigns) do
    ~H"""
    <div
      class={[
        "card-back shadow-sm shrink-0",
        if(@size == :xs,
          do: "rounded-[0.3rem] border border-white/80",
          else: "rounded-lg border-2 border-white/80"
        ),
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

  # Card index (rank and suit) in the top-left corner, so it stays visible
  # when cards overlap, plus a large centre pip.
  defp card_contents(assigns) do
    ~H"""
    <span class={[
      "absolute flex flex-col items-center leading-none",
      if(@size in [:xs, :sm], do: "left-0.5 top-0.5", else: "left-1 top-1")
    ]}>
      <span class={["font-bold tracking-tight", rank_text_class(@size)]}>
        {format_rank(@card.rank)}
      </span>
      <span class={suit_text_class(@size)}>{format_suit(@card.suit)}</span>
    </span>
    <span class={["leading-none", centre_pip_class(@size)]}>{centre_pip(@card)}</span>
    <%= if Card.wildcard?(@card) do %>
      <span class="absolute top-1 right-1 w-1.5 h-1.5 sm:w-2 sm:h-2 rounded-full bg-amber-400" />
    <% end %>
    """
  end

  defp rank_text_class(:lg), do: "text-sm sm:text-lg"
  defp rank_text_class(:md), do: "text-xs sm:text-sm"
  defp rank_text_class(_size), do: "text-[0.6rem] sm:text-xs"

  defp suit_text_class(:lg), do: "text-xs sm:text-base"
  defp suit_text_class(:md), do: "text-[0.65rem] sm:text-xs"
  defp suit_text_class(_size), do: "text-[0.55rem] sm:text-[0.65rem]"

  defp centre_pip_class(:lg), do: "text-2xl sm:text-4xl mt-2"
  defp centre_pip_class(:md), do: "text-xl sm:text-3xl mt-2"
  defp centre_pip_class(_size), do: "text-base sm:text-xl mt-2"

  defp centre_pip(%Card{rank: :joker}), do: "★"
  defp centre_pip(%Card{suit: suit}), do: format_suit(suit)

  defp card_face_classes(card, size) do
    [
      "relative rounded-lg border-2 flex flex-col items-center justify-center shrink-0 select-none",
      card_size_classes(size),
      red_suit?(card) && "bg-red-50 border-red-200 text-red-700",
      black_suit?(card) && "bg-slate-50 border-slate-300 text-slate-800"
    ]
  end

  defp card_size_classes(:xs), do: "w-5 h-7 sm:w-6 sm:h-9"
  defp card_size_classes(:sm), do: "w-9 h-12 sm:w-11 sm:h-16"

  defp card_size_classes(:md),
    do: "w-11 h-15 sm:w-14 sm:h-20 min-w-[2.75rem] min-h-[3.75rem] sm:min-w-0 sm:min-h-0"

  defp card_size_classes(:lg), do: "w-14 h-20 sm:w-20 sm:h-28"

  @doc """
  Renders a player's hand as an overlapping row of selectable cards.

  Cards wrap onto more rows on narrow screens instead of scrolling.
  """
  attr :cards, :list, required: true
  attr :selected_ids, :list, default: []
  attr :on_select, :string, required: true
  attr :disabled, :boolean, default: false

  def game_hand(assigns) do
    ~H"""
    <div id="player-hand" class="flex flex-wrap justify-center gap-y-3 pl-4 sm:pl-5 pt-3">
      <%= for card <- @cards do %>
        <.game_card
          id={"hand-card-#{card.id}"}
          card={card}
          selected={card.id in @selected_ids}
          phx-click={@on_select}
          phx-value-card_id={card.id}
          disabled={@disabled}
          class="-ml-4 sm:-ml-5 motion-safe:animate-card-in"
        />
      <% end %>
    </div>
    """
  end

  @doc """
  Renders the centre of the table as three card piles: the deck (face
  down), the discard pile (top card face up), and the morto (face down
  until taken).

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
    <div id="game-table" class="flex items-start justify-center gap-4 sm:gap-8">
      <button
        id="draw-deck"
        type="button"
        phx-click={@on_draw_deck}
        aria-label={"Draw from the deck (#{@deck_count} cards left)"}
        class="group flex flex-col items-center gap-1.5 focus:outline-hidden"
      >
        <%= if @deck_count > 0 do %>
          <.card_back class={[
            "transition group-hover:-translate-y-1 group-active:scale-95",
            "group-focus-visible:ring-2 group-focus-visible:ring-amber-300",
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
          "group flex flex-col items-center gap-1.5 focus:outline-hidden",
          @discard_disabled && "cursor-not-allowed"
        ]}
      >
        <%= if @discard_top do %>
          <div id={"discard-card-#{@discard_top.id}"} class="motion-safe:animate-card-in">
            <.card_face
              id="discard-top"
              card={@discard_top}
              size={:lg}
              class={[
                "transition",
                pile_depth_class(@discard_count),
                @discard_disabled && "opacity-50 grayscale",
                not @discard_disabled &&
                  "group-hover:-translate-y-1 group-active:scale-95 group-focus-visible:ring-2 group-focus-visible:ring-amber-300"
              ]}
            />
          </div>
        <% else %>
          <.empty_slot />
        <% end %>
        <.pile_label label="Discard" count={@discard_count} />
      </button>

      <div id="morto-indicator" class="flex flex-col items-center gap-1.5">
        <%= if @morto_taken_by do %>
          <.empty_slot>
            <span class="text-xs font-semibold">Taken</span>
          </.empty_slot>
          <span class="flex flex-col items-center gap-0.5 leading-tight">
            <span class="text-[0.7rem] sm:text-xs font-medium uppercase tracking-wider text-white/70">
              Morto
            </span>
            <span class="rounded-full bg-sky-400/90 px-2 py-0.5 text-[0.7rem] font-semibold text-sky-950">
              Team {String.upcase(to_string(@morto_taken_by))}
            </span>
          </span>
        <% else %>
          <.card_back class={["rotate-6", pile_depth_class(@morto_count)]} />
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
      <span class="text-[0.7rem] sm:text-xs font-medium uppercase tracking-wider text-white/70">
        {@label}
      </span>
      <span class="text-sm sm:text-base font-bold tabular-nums text-white">{@count}</span>
    </span>
    """
  end

  slot :inner_block

  defp empty_slot(assigns) do
    ~H"""
    <div class={[
      "rounded-lg border-2 border-dashed border-white/30 flex items-center justify-center text-white/60",
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
  Renders one team's melds on its side of the table, with each meld's
  cards fanned like real cards.

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
    <div id={@id} class="space-y-2">
      <h3 class="text-center text-[0.7rem] sm:text-xs font-semibold uppercase tracking-[0.14em] text-white/60">
        {@label} · Team {String.upcase(to_string(@team_id))}
      </h3>

      <div class="flex flex-wrap items-end justify-center gap-x-5 gap-y-3 min-h-10 sm:min-h-14">
        <%= if @team.red_threes != [] do %>
          <div id={"#{@id}-red-threes"} class="flex flex-col items-center gap-1">
            <div class="flex pl-5 sm:pl-6">
              <%= for card <- @team.red_threes do %>
                <.card_face
                  id={"red-three-#{card.id}"}
                  card={card}
                  size={:sm}
                  class="-ml-5 sm:-ml-6 shadow motion-safe:animate-card-in"
                />
              <% end %>
            </div>
            <span class="rounded-full bg-rose-500/90 px-2 py-0.5 text-[0.65rem] font-semibold text-white">
              Red 3s +{length(@team.red_threes) * 100}
            </span>
          </div>
        <% end %>

        <%= if @team.melds == [] and @team.red_threes == [] do %>
          <p class="self-center text-xs italic text-white/40">No melds yet</p>
        <% end %>

        <%= for {meld, index} <- Enum.with_index(@team.melds) do %>
          <div id={"#{@id}-meld-#{index}"} class="flex flex-col items-center gap-1">
            <div class={[
              "flex pl-5 sm:pl-6 rounded-lg",
              meld.type in [:limpa, :suja] && "canastra-glow"
            ]}>
              <%= for card <- meld.cards do %>
                <.card_face
                  id={"table-card-#{card.id}"}
                  card={card}
                  size={:sm}
                  class="-ml-5 sm:-ml-6 shadow motion-safe:animate-card-in"
                />
              <% end %>
            </div>

            <div class="flex flex-wrap items-center justify-center gap-1">
              <%= if meld.type in [:limpa, :suja] do %>
                <span class="rounded-full bg-amber-300 px-2 py-0.5 text-[0.65rem] font-semibold text-amber-950">
                  Canastra {if(meld.type == :limpa, do: "limpa", else: "suja")}
                </span>
              <% end %>

              <%= if @on_add_to_meld && @selected_card_id do %>
                <button
                  type="button"
                  phx-click={@on_add_to_meld}
                  phx-value-meld_index={index}
                  class={chip_button_class()}
                >
                  Add selected card
                </button>
              <% end %>

              <%= if @on_replace_joker && @selected_card_id && joker_in_meld?(meld) do %>
                <button
                  type="button"
                  phx-click={@on_replace_joker}
                  phx-value-meld_index={index}
                  class={chip_button_class()}
                >
                  Replace joker
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp chip_button_class do
    "rounded-full bg-white/90 px-2.5 py-1 text-[0.7rem] font-semibold text-stone-900 shadow " <>
      "transition hover:bg-white active:scale-95 focus-visible:outline-2 focus-visible:outline-amber-300"
  end

  @doc """
  Renders a player's seat at the table: their seat number and team, their
  hand as face-down cards with a count, and a highlight when it is their
  turn.

  `position` is where the seat sits relative to the viewer: `:top`,
  `:left`, `:right` or `:bottom`.
  """
  attr :player, :map, required: true
  attr :position, :atom, values: [:top, :left, :right, :bottom], required: true
  attr :current_turn, :boolean, default: false

  def table_seat(assigns) do
    assigns = assign(assigns, :fan_count, min(length(assigns.player.hand), 6))

    ~H"""
    <div
      id={"seat-#{@player.seat}"}
      data-position={@position}
      class={[
        "flex items-center gap-1.5 sm:gap-2",
        if(@position in [:left, :right], do: "flex-col", else: "flex-col sm:flex-row")
      ]}
    >
      <.seat_badge seat={@player.seat} team={@player.team} current_turn={@current_turn} />

      <div class="flex items-center gap-1.5">
        <div class="flex pl-3.5 sm:pl-4" aria-hidden="true">
          <%= for _ <- 1..@fan_count//1 do %>
            <.card_back size={:xs} class="-ml-3.5 sm:-ml-4" />
          <% end %>
        </div>
        <span class="text-[0.7rem] sm:text-xs tabular-nums text-white/80">
          {length(@player.hand)}
        </span>
      </div>
    </div>
    """
  end

  @doc """
  Renders the label for a seat: seat number, team, a "You" marker, and a
  pulsing highlight when it is that seat's turn.
  """
  attr :seat, :integer, required: true
  attr :team, :atom, required: true
  attr :current_turn, :boolean, default: false
  attr :you, :boolean, default: false

  def seat_badge(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-1.5 whitespace-nowrap rounded-full px-2.5 py-1 text-[0.7rem] sm:text-xs font-semibold text-white ring-1 transition",
      if(@current_turn,
        do: "bg-amber-300/20 ring-amber-300 motion-safe:animate-turn-pulse",
        else: "bg-black/25 ring-white/15"
      )
    ]}>
      <span class={[
        "size-2 rounded-full",
        if(@current_turn, do: "bg-amber-300", else: "bg-white/30")
      ]} />
      <span>Seat {@seat + 1}</span>
      <span class="text-white/60">Team {String.upcase(to_string(@team))}</span>
      <%= if @you do %>
        <span class="rounded-full bg-amber-300 px-1.5 text-[0.65rem] text-amber-950">You</span>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a compact, pill-shaped action button for the table.

  Variants: `:primary` (gold), `:light`, `:danger` and `:ghost`.
  """
  attr :variant, :atom, values: [:primary, :light, :danger, :ghost], default: :ghost
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled)
  slot :inner_block, required: true

  def table_button(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "inline-flex items-center justify-center gap-1.5 rounded-full px-4 min-h-[2.75rem] sm:min-h-10",
        "text-sm font-semibold transition active:scale-95",
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-300",
        "disabled:opacity-40 disabled:cursor-not-allowed disabled:active:scale-100",
        table_button_variant(@variant),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp table_button_variant(:primary),
    do: "bg-amber-400 text-amber-950 shadow-md hover:bg-amber-300 disabled:hover:bg-amber-400"

  defp table_button_variant(:light),
    do: "bg-white/90 text-stone-900 shadow-md hover:bg-white disabled:hover:bg-white/90"

  defp table_button_variant(:danger),
    do: "bg-rose-500 text-white shadow-md hover:bg-rose-400 disabled:hover:bg-rose-500"

  defp table_button_variant(:ghost),
    do: "bg-black/25 text-white ring-1 ring-white/20 hover:bg-black/40 disabled:hover:bg-black/25"

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
