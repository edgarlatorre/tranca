defmodule Tranca.Games.GameRound do
  @moduledoc """
  Ecto schema for persisted round results.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Tranca.Games.GameRecord

  @type t :: %__MODULE__{
          id: integer(),
          game_id: integer(),
          round_number: integer(),
          team_a_score: integer(),
          team_b_score: integer(),
          winner: String.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "game_rounds" do
    field :round_number, :integer
    field :team_a_score, :integer
    field :team_b_score, :integer
    field :winner, :string

    belongs_to :game, GameRecord

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(round, attrs) do
    round
    |> cast(attrs, [:game_id, :round_number, :team_a_score, :team_b_score, :winner])
    |> validate_required([:game_id, :round_number, :team_a_score, :team_b_score])
    |> validate_number(:round_number, greater_than: 0)
    |> foreign_key_constraint(:game_id)
    |> unique_constraint([:game_id, :round_number])
  end
end
