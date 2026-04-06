defmodule ServiceShellWeb.PageController do
  use ServiceShellWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
