defmodule TrancaWeb.Plugs.UserSession do
  @moduledoc """
  Ensures every browser session has a stable anonymous `user_id`.

  The ID is stored in the signed cookie session so it survives page
  refreshes and can be used to identify the current player in games.
  """

  import Plug.Conn

  @session_key "user_id"

  @doc """
  Initializes the plug options.
  """
  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @doc """
  Fetches or creates a `user_id` for the current session.
  """
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    case get_session(conn, @session_key) do
      nil ->
        user_id = generate_user_id()

        conn
        |> put_session(@session_key, user_id)
        |> assign(:current_user_id, user_id)

      user_id ->
        assign(conn, :current_user_id, user_id)
    end
  end

  defp generate_user_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
