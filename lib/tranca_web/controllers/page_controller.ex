defmodule TrancaWeb.PageController do
  use TrancaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
