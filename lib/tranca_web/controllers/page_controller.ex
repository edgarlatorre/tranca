defmodule TrancaWeb.PageController do
  @moduledoc """
  Controller for the marketing/home page.
  """

  use TrancaWeb, :controller

  @doc """
  Renders the home page.
  """
  @spec home(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def home(conn, _params) do
    render(conn, :home)
  end
end
