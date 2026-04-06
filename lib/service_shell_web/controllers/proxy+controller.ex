# lib/service_shell_web/controllers/proxy_controller.ex
defmodule ServiceShellWeb.ProxyController do
  use ServiceShellWeb, :controller

  def proxy(conn, %{"port" => port, "path" => path}) do
    target_url = "http://localhost:#{port}/#{Enum.join(path, "/")}"

    # Using :httpc (built-in) or Req to fetch the local app
    {:ok, {{_ver, 200, _msg}, headers, body}} = :httpc.request(to_charlist(target_url))

    # Filter out security headers that block iframing
    clean_headers =
      Enum.reject(headers, fn {k, _} ->
        k in [~c"content-security-policy", ~c"x-frame-options"]
      end)

    conn
    |> merge_resp_headers(clean_headers)
    |> send_resp(200, body)
  end
end
