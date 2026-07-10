defmodule Tranca.Repo.Migrations.CreateGamePlayers do
  use Ecto.Migration

  def change do
    create table(:game_players) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :user_id, :string, null: false
      add :seat, :integer, null: false
      add :team, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:game_players, [:game_id, :seat])
    create index(:game_players, [:game_id, :user_id])
  end
end
