defmodule Tranca.Repo do
  use Ecto.Repo,
    otp_app: :tranca,
    adapter: Ecto.Adapters.SQLite3
end
