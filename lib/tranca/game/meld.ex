defmodule Tranca.Game.Meld do
  @moduledoc """
  Represents a meld (lay down) of cards in Tranca.

  A meld consists of three or more cards of the same rank. Wildcards
  (twos and jokers) can substitute for any rank, but a valid meld must
  contain at least one natural card.
  """

  alias Tranca.Game.Card

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
    %__MODULE__{cards: cards, type: classify(cards)}
  end

  @doc """
  Returns true if the meld is valid.

  A meld is valid when it has at least three cards, contains at least
  one natural (non-wildcard) card, all natural cards share the same rank,
  and the number of wildcards does not exceed the number of natural cards.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{cards: cards}) do
    naturals = Enum.reject(cards, &Card.wildcard?/1)
    wildcards = Enum.filter(cards, &Card.wildcard?/1)

    case {cards, naturals} do
      {[_a, _b, _c | _rest], [first | rest]} ->
        length(wildcards) <= length(naturals) and
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

  defp classify(cards) do
    naturals = Enum.reject(cards, &Card.wildcard?/1)

    case {cards, naturals} do
      {[_a, _b, _c, _d, _e, _f, _g | _rest], [first | rest]} ->
        if Enum.all?(rest, &(&1.rank == first.rank)) do
          if Enum.any?(cards, &Card.wildcard?/1) do
            :suja
          else
            :limpa
          end
        else
          :normal
        end

      _ ->
        :normal
    end
  end
end
