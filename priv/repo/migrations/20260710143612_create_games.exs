defmodule Tranca.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :game_id, :string, null: false
      add :status, :string, null: false
      add :player_count, :integer, null: false
      add :target_score, :integer, null: false
      add :winner, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:games, [:game_id])
  end
end
