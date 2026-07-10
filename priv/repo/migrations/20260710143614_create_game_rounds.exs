defmodule Tranca.Repo.Migrations.CreateGameRounds do
  use Ecto.Migration

  def change do
    create table(:game_rounds) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :round_number, :integer, null: false
      add :team_a_score, :integer, null: false
      add :team_b_score, :integer, null: false
      add :winner, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:game_rounds, [:game_id, :round_number])
  end
end
