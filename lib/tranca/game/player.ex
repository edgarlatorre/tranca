defmodule Tranca.Game.Player do
  @moduledoc """
  Represents a player in a Tranca game.
  """

  alias Tranca.Game.Card

  @type team :: :a | :b
  @type status :: :waiting | :ready | :playing

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: String.t() | nil,
          seat: integer(),
          team: team(),
          hand: [Card.t()],
          status: status()
        }

  defstruct [:id, :user_id, :seat, :team, :hand, status: :waiting]

  @doc """
  Creates a new player.
  """
  @spec new(String.t(), String.t() | nil, integer(), team()) :: t()
  def new(id, user_id, seat, team) do
    %__MODULE__{
      id: id,
      user_id: user_id,
      seat: seat,
      team: team,
      hand: [],
      status: :waiting
    }
  end
end
