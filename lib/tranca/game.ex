defmodule Tranca.Game do
  @moduledoc """
  The pure data model and rule engine for Tranca com morto.

  A `Tranca.Game` struct holds the complete state of a match. All game
  actions return a new struct (or an error tuple), keeping the engine
  free of side effects and easy to test.
  """

  alias Tranca.Game.Card
  alias Tranca.Game.Player
  alias Tranca.Game.Team

  @type status :: :waiting | :playing | :finished
  @type player_count :: 2 | 4

  @type t :: %__MODULE__{
          id: String.t(),
          status: status(),
          player_count: player_count(),
          players: [Player.t()],
          teams: %{a: Team.t(), b: Team.t()},
          deck: [Card.t()],
          morto: [Card.t()],
          discard_pile: [Card.t()],
          turn: integer(),
          round: integer(),
          winner: Team.id() | nil
        }

  defstruct [
    :id,
    :status,
    :player_count,
    :players,
    :teams,
    :deck,
    :morto,
    :discard_pile,
    :turn,
    :round,
    :winner
  ]

  @doc """
  Creates a new game in the `:waiting` state.

  `player_count` must be 2 or 4. The game is initialized with empty
  players, teams, and piles. Cards are not dealt until the game starts.
  """
  @spec new(String.t(), player_count()) :: t()
  def new(id, player_count) when player_count in [2, 4] do
    %__MODULE__{
      id: id,
      status: :waiting,
      player_count: player_count,
      players: [],
      teams: %{a: Team.new(:a), b: Team.new(:b)},
      deck: [],
      morto: [],
      discard_pile: [],
      turn: 0,
      round: 1,
      winner: nil
    }
  end
end
