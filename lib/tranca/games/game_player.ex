defmodule Tranca.Games.GamePlayer do
  @moduledoc """
  Ecto schema for players in a persisted game.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Tranca.Games.GameRecord

  @type t :: %__MODULE__{
          id: integer(),
          game_id: integer(),
          user_id: String.t(),
          seat: integer(),
          team: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "game_players" do
    field :user_id, :string
    field :seat, :integer
    field :team, :string

    belongs_to :game, GameRecord

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:game_id, :user_id, :seat, :team])
    |> validate_required([:game_id, :user_id, :seat, :team])
    |> validate_inclusion(:seat, 0..3)
    |> validate_inclusion(:team, ["a", "b"])
    |> foreign_key_constraint(:game_id)
    |> unique_constraint([:game_id, :seat])
  end
end
