defmodule Tranca.Game.Meld do
  @moduledoc """
  Represents a meld (lay down) of cards in Tranca.

  A meld consists of three or more cards forming either:

    * a **set** — natural cards that all share the same rank. Sets are
      only allowed for aces and 4s (A A A, 4 4 4), or
    * a **sequence** — natural cards of the same suit with distinct ranks
      that form a run (4♥ 5♥ 6♥). Aces can be low (A 2 3) or high (Q K A).

  Wildcards (twos and jokers) can stand in for any card: in a set they
  count as the set's rank, and in a sequence they fill gaps (4♥ 2♣ 6♥) or
  extend either end. A valid meld must contain at least one natural card,
  and wildcards may not outnumber natural cards.
  """

  alias Tranca.Game.Card

  @type kind :: :set | :sequence

  # The only ranks that may form a set.
  @set_ranks [:ace, :four]

  @type t :: %__MODULE__{
          cards: [Card.t()],
          type: :normal | :limpa | :suja
        }

  defstruct [:cards, type: :normal]

  @doc """
  Creates a new meld from a list of cards and classifies it.
  """
  @spec new([Card.t()]) :: t()
  def new(cards) when is_list(cards) do
    %__MODULE__{cards: arrange(cards), type: classify(cards)}
  end

  @doc """
  Returns true if the meld is valid.

  A meld is valid when it has at least three cards, its cards form a set
  or a sequence (see `kind/1`), and the number of wildcards does not
  exceed the number of natural cards.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = meld), do: validate(meld) == :ok

  @doc """
  Validates the meld, returning `:ok` or an error explaining why it is not
  valid.

  Returns `{:error, :same_rank_meld_not_allowed}` for a set of a rank other
  than aces or 4s that would otherwise be valid (for example K K K), and
  `{:error, :invalid_meld}` for any other invalid meld.
  """
  @spec validate(t()) :: :ok | {:error, :invalid_meld | :same_rank_meld_not_allowed}
  def validate(%__MODULE__{cards: cards} = meld) do
    {naturals, wildcards} = Enum.split_with(cards, &(not Card.wildcard?(&1)))
    sized? = length(cards) >= 3 and length(wildcards) <= length(naturals)

    cond do
      sized? and kind(meld) != nil -> :ok
      sized? and same_rank?(naturals) -> {:error, :same_rank_meld_not_allowed}
      true -> {:error, :invalid_meld}
    end
  end

  @doc """
  Returns the kind of meld the cards form, ignoring size and wildcard limits.

  Returns `:set` when all natural cards are aces or all are 4s, `:sequence`
  when the natural cards share a suit and, with the wildcards filling gaps,
  form a run of consecutive ranks, and `nil` otherwise (including when the
  meld has no natural cards).
  """
  @spec kind(t() | [Card.t()]) :: kind() | nil
  def kind(%__MODULE__{cards: cards}), do: kind(cards)

  def kind(cards) when is_list(cards) do
    {naturals, wildcards} = Enum.split_with(cards, &(not Card.wildcard?(&1)))

    cond do
      naturals == [] -> nil
      same_rank?(naturals) -> if hd(naturals).rank in @set_ranks, do: :set
      sequence_layout(naturals, length(wildcards)) != nil -> :sequence
      true -> nil
    end
  end

  @doc """
  Returns the rank of a set, determined by its natural cards.
  Returns nil for sequences and melds with only wildcards.
  """
  @spec rank(t()) :: Card.rank() | nil
  def rank(%__MODULE__{cards: cards} = meld) do
    case {kind(meld), Enum.reject(cards, &Card.wildcard?/1)} do
      {:set, [first | _]} -> first.rank
      _ -> nil
    end
  end

  @doc """
  Returns the list of natural (non-wildcard) cards in the meld.
  """
  @spec natural_cards(t()) :: [Card.t()]
  def natural_cards(%__MODULE__{cards: cards}) do
    Enum.reject(cards, &Card.wildcard?/1)
  end

  @doc """
  Returns the list of wildcard cards in the meld.
  """
  @spec wildcards(t()) :: [Card.t()]
  def wildcards(%__MODULE__{cards: cards}) do
    Enum.filter(cards, &Card.wildcard?/1)
  end

  @doc """
  Returns the list of red three cards in the meld.
  """
  @spec red_threes(t()) :: [Card.t()]
  def red_threes(%__MODULE__{cards: cards}) do
    Enum.filter(cards, &Card.red_three?/1)
  end

  @doc """
  Returns the total point value of the cards in the meld.
  """
  @spec points(t()) :: integer()
  def points(%__MODULE__{cards: cards}) do
    Enum.reduce(cards, 0, &(&1.value + &2))
  end

  @doc """
  Returns true if the meld is a canastra (7 or more cards).
  """
  @spec canastra?(t()) :: boolean()
  def canastra?(%__MODULE__{type: type}), do: type in [:limpa, :suja]

  # A meld of seven or more cards that forms a set or a sequence is a
  # canastra: limpa without wildcards, suja with them.
  defp classify(cards) do
    cond do
      length(cards) < 7 or kind(cards) == nil -> :normal
      Enum.any?(cards, &Card.wildcard?/1) -> :suja
      true -> :limpa
    end
  end

  defp same_rank?([]), do: false
  defp same_rank?([first | rest]), do: Enum.all?(rest, &(&1.rank == first.rank))

  # Sequence positions: ace low (1) or high (14), three through king 3..13.
  # Twos are always wildcards, so they never appear as naturals here.
  @positions %{
    three: 3,
    four: 4,
    five: 5,
    six: 6,
    seven: 7,
    eight: 8,
    nine: 9,
    ten: 10,
    jack: 11,
    queen: 12,
    king: 13
  }

  # A run covers at most 13 positions (A..K or 2..A).
  @max_sequence_length 13

  # Returns the natural cards sorted by position (as `{position, card}`
  # pairs) if they can form a sequence with `wildcard_count` wildcards,
  # or nil otherwise. Tries ace-low first, then ace-high.
  defp sequence_layout([first | _] = naturals, wildcard_count) do
    same_suit? = first.suit != nil and Enum.all?(naturals, &(&1.suit == first.suit))
    fits? = length(naturals) + wildcard_count <= @max_sequence_length

    if same_suit? and fits? do
      Enum.find_value([1, 14], fn ace_position ->
        layout =
          naturals
          |> Enum.map(&{position(&1, ace_position), &1})
          |> Enum.sort_by(&elem(&1, 0))

        positions = Enum.map(layout, &elem(&1, 0))
        gaps = List.last(positions) - hd(positions) + 1 - length(positions)

        if positions == Enum.uniq(positions) and gaps <= wildcard_count, do: layout
      end)
    end
  end

  defp position(%Card{rank: :ace}, ace_position), do: ace_position
  defp position(%Card{rank: rank}, _ace_position), do: Map.fetch!(@positions, rank)

  # Orders a sequence by rank with wildcards placed in the gaps they fill;
  # leftover wildcards extend the top of the run (or the bottom once the
  # top reaches the ace). Sets and invalid melds keep their given order.
  defp arrange(cards) do
    {naturals, wildcards} = Enum.split_with(cards, &(not Card.wildcard?(&1)))

    with false <- naturals == [] or same_rank?(naturals),
         layout when is_list(layout) <- sequence_layout(naturals, length(wildcards)) do
      {run, wildcards} = fill_gaps(layout, wildcards)
      top = layout |> List.last() |> elem(0)
      room_above = min(14 - top, length(wildcards))
      {above, below} = Enum.split(wildcards, room_above)
      below ++ run ++ above
    else
      _ -> cards
    end
  end

  defp fill_gaps([{_position, card}], wildcards), do: {[card], wildcards}

  defp fill_gaps([{position, card}, {next, _} | _] = [_ | rest], wildcards) do
    {fillers, wildcards} = Enum.split(wildcards, next - position - 1)
    {run, wildcards} = fill_gaps(rest, wildcards)
    {[card | fillers] ++ run, wildcards}
  end
end
