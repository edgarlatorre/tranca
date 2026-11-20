defmodule Tranca.Game.Team do
  @moduledoc """
  Represents a team in a Tranca game.

  `melds` holds the team's melds on the table, and `red_threes` holds red 3s
  placed on their own in the team's meld area. Each red 3 on the table
  (placed or inside a meld) is worth a +100 bonus at the end of the round.
  """

  @type id :: :a | :b

  @type t :: %__MODULE__{
          id: id(),
          player_ids: [String.t()],
          melds: [Tranca.Game.Meld.t()],
          red_threes: [Tranca.Game.Card.t()],
          score: integer(),
          first_meld_done: boolean()
        }

  defstruct [:id, player_ids: [], melds: [], red_threes: [], score: 0, first_meld_done: false]

  @doc """
  Creates a new team with the given ID.
  """
  @spec new(id()) :: t()
  def new(id) do
    %__MODULE__{id: id}
  end

  @doc """
  Adds a player ID to the team.
  """
  @spec add_player(t(), String.t()) :: t()
  def add_player(%__MODULE__{} = team, player_id) do
    %{team | player_ids: team.player_ids ++ [player_id]}
  end
end
