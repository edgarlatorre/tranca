defmodule Tranca.Repo do
  @moduledoc """
  Ecto repository for the Tranca application.
  """

  use Ecto.Repo,
    otp_app: :tranca,
    adapter: Ecto.Adapters.SQLite3
end
