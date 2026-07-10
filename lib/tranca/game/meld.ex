defmodule Tranca.Game.Meld do
  @moduledoc """
  Represents a meld (lay down) of cards in Tranca.

  A meld consists of three or more cards of the same rank. Wildcards
  (twos and jokers) can substitute for any rank, but a valid meld must
  contain at least one natural card.
  """

  alias Tranca.Game.Card

  @type t :: %__MODULE__{
          cards: [Card.t()]
        }

  defstruct [:cards]

  @doc """
  Creates a new meld from a list of cards.
  """
  @spec new([Card.t()]) :: t()
  def new(cards) when is_list(cards) do
    %__MODULE__{cards: cards}
  end

  @doc """
  Returns true if the meld is valid.

  A meld is valid when it has at least three cards, contains at least
  one natural (non-wildcard) card, and all natural cards share the same
  rank.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{cards: cards}) do
    {naturals, _wildcards} = Enum.split_with(cards, &(!Card.wildcard?(&1)))

    case {cards, naturals} do
      {[_a, _b, _c | _rest], [first | rest]} ->
        Enum.all?(rest, &(&1.rank == first.rank))

      _ ->
        false
    end
  end

  @doc """
  Returns the rank of the meld, determined by its natural cards.
  Returns nil for invalid melds or melds with only wildcards.
  """
  @spec rank(t()) :: Card.rank() | nil
  def rank(%__MODULE__{cards: cards}) do
    naturals = Enum.reject(cards, &Card.wildcard?/1)

    case naturals do
      [first | _] -> first.rank
      [] -> nil
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
end
