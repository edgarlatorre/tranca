defmodule Tranca.Games.GameRecord do
  @moduledoc """
  Ecto schema for persisted game records.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Tranca.Games.GamePlayer
  alias Tranca.Games.GameRound

  @type t :: %__MODULE__{
          id: integer(),
          game_id: String.t(),
          status: String.t(),
          player_count: integer(),
          target_score: integer(),
          winner: String.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "games" do
    field :game_id, :string
    field :status, :string
    field :player_count, :integer
    field :target_score, :integer
    field :winner, :string

    has_many :players, GamePlayer, foreign_key: :game_id
    has_many :rounds, GameRound, foreign_key: :game_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(record, attrs) do
    record
    |> cast(attrs, [:game_id, :status, :player_count, :target_score, :winner])
    |> validate_required([:game_id, :status, :player_count, :target_score])
    |> validate_inclusion(:status, ["waiting", "playing", "finished"])
    |> validate_inclusion(:player_count, [2, 4])
    |> unique_constraint(:game_id)
  end
end
