defmodule Tranca.Game.Card do
  @moduledoc """
  Represents a single playing card in Tranca.

  A Tranca deck is made of two standard 52-card decks plus two jokers,
  for a total of 108 cards. Each card has a unique ID so duplicate cards
  can be distinguished during play.
  """

  @type rank ::
          :ace
          | :two
          | :three
          | :four
          | :five
          | :six
          | :seven
          | :eight
          | :nine
          | :ten
          | :jack
          | :queen
          | :king
          | :joker

  @type suit :: :spades | :hearts | :diamonds | :clubs
  @type color :: :red | :black

  @type t :: %__MODULE__{
          id: String.t(),
          rank: rank(),
          suit: suit() | nil,
          value: integer(),
          wildcard: boolean()
        }

  defstruct [:id, :rank, :suit, :value, :wildcard]

  @suits [:spades, :hearts, :diamonds, :clubs]
  @ranks [
    ace: 10,
    two: 20,
    three: 5,
    four: 5,
    five: 5,
    six: 5,
    seven: 5,
    eight: 5,
    nine: 5,
    ten: 10,
    jack: 10,
    queen: 10,
    king: 10
  ]

  @doc """
  Returns a full 108-card Tranca deck with unique IDs.

  The deck contains two 54-card decks (52 standard cards plus 2 jokers
  each) for a total of 108 cards. Cards are returned in a deterministic
  order and should be shuffled before dealing.
  """
  @spec deck() :: [t()]
  def deck do
    standard_cards =
      for deck_index <- 1..2,
          {rank, value} <- @ranks,
          suit <- @suits do
        new("#{deck_index}-#{rank}-#{suit}", rank, suit, value)
      end

    jokers =
      for index <- 1..4 do
        new("joker-#{index}", :joker, nil, 50)
      end

    standard_cards ++ jokers
  end

  @doc """
  Creates a new card.
  """
  @spec new(String.t(), rank(), suit() | nil, integer()) :: t()
  def new(id, rank, suit, value) do
    %__MODULE__{
      id: id,
      rank: rank,
      suit: suit,
      value: value,
      wildcard: wildcard?(rank)
    }
  end

  @doc """
  Returns true if the card is a wildcard (a two or a joker).
  """
  @spec wildcard?(rank() | t()) :: boolean()
  def wildcard?(%__MODULE__{rank: rank}), do: wildcard?(rank)
  def wildcard?(:two), do: true
  def wildcard?(:joker), do: true
  def wildcard?(_rank), do: false

  @doc """
  Returns true if the card is a three of any suit.
  """
  @spec three?(t()) :: boolean()
  def three?(%__MODULE__{rank: :three}), do: true
  def three?(%__MODULE__{}), do: false

  @doc """
  Returns the color of the card's suit, or nil for jokers.
  """
  @spec color(t()) :: color() | nil
  def color(%__MODULE__{suit: :hearts}), do: :red
  def color(%__MODULE__{suit: :diamonds}), do: :red
  def color(%__MODULE__{suit: :spades}), do: :black
  def color(%__MODULE__{suit: :clubs}), do: :black
  def color(%__MODULE__{suit: nil}), do: nil

  @doc """
  Returns true if the card is a black three.
  """
  @spec black_three?(t()) :: boolean()
  def black_three?(%__MODULE__{rank: :three} = card), do: color(card) == :black
  def black_three?(%__MODULE__{}), do: false

  @doc """
  Returns true if the card is a red three.
  """
  @spec red_three?(t()) :: boolean()
  def red_three?(%__MODULE__{rank: :three} = card), do: color(card) == :red
  def red_three?(%__MODULE__{}), do: false
end
