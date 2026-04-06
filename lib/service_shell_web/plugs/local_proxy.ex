defmodule ServiceShellWeb.LocalProxy do
  require Logger
  import Plug.Conn
  # import Logger

  def init(opts), do: opts

  # def call(conn, _opts) do
  #   # We expect a path like /proxy/:port/rest/of/path
  #   case conn.path_info do
  #     ["proxy", port_str | rest] ->
  #       # target_url = "http://localhost:#{port_str}/#{Enum.join(rest, "/")}"
  #       # target_url = "http://127.0.0.1:#{port_str}/#{Enum.join(rest, "/")}"
  #       target_url = "http://172.16.250.248:#{port_str}/#{Enum.join(rest, "/")}"
  #       proxy_request(conn, target_url)

  #     _ ->
  #       conn
  #   end
  # end

  def call(conn, _opts) do
    # Pull host and port from the router's assigned path_params
    %{path_params: %{"host" => host, "port" => port_str, "path" => path_list}} = conn

    path = "/" <> Enum.join(path_list, "/")
    query = if conn.query_string != "", do: "?" <> conn.query_string, else: ""

    # Dynamically build the target based on the provided host
    target_url = "http://#{host}:#{port_str}#{path}#{query}"

    proxy_request(conn, target_url, host, port_str)
  end

  defp proxy_request(conn, url, host, port_str) do
    proxy_base = "/proxy/#{host}/#{port_str}"
    original_base = "http://#{host}:#{port_str}"

    case Req.get(url,
           headers: Enum.into(conn.req_headers, %{}),
           decode_body: false,
           retry: false,
           connect_options: [timeout: 2000]
         ) do
      {:ok, %{status: status, headers: headers, body: body}} ->
        content_type = get_header(headers, "content-type")

        # Rewrite Body
        processed_body =
          if should_rewrite?(content_type) do
            rewrite_body(body, original_base, proxy_base)
          else
            body
          end

        # Rewrite Redirects
        location = get_header(headers, "location")
        final_headers = clean_headers(headers)

        final_headers =
          if location do
            new_loc = String.replace(location, original_base, proxy_base)
            List.keystore(final_headers, "location", 0, {"location", new_loc})
          else
            final_headers
          end

        conn
        |> merge_resp_headers(final_headers)
        |> send_resp(status, processed_body)
        |> halt()

      {:error, reason} ->
        Logger.error("Proxy failed to reach #{url}: #{inspect(reason)}")
        send_resp(conn, 502, "Target #{host}:#{port_str} is Unreachable")
    end
  end

  defp clean_headers(headers) do
    forbidden = [
      "content-security-policy",
      "x-frame-options",
      "transfer-encoding",
      "content-length"
    ]

    headers
    |> Enum.reject(fn {k, _} -> String.downcase(k) in forbidden end)
    |> Enum.map(fn {k, v} -> {String.downcase(k), List.wrap(v) |> List.first()} end)
  end

  # Helper to identify text/assets
  defp should_rewrite?(nil), do: false
  defp should_rewrite?(ct), do: String.contains?(ct, ["html", "javascript", "css", "json"])

  # The Search & Replace logic
  defp rewrite_body(body, original, proxy) do
    body
    |> String.replace(original, proxy)
    # Also handle absolute paths that start with / (e.g. href="/system")
    # We look for strings starting with "/" but not followed by "proxy"
    |> String.replace(~r/(href|src)="\/((?!proxy).*?)"/, "\\1=\"#{proxy}/\\2\"")
  end

  defp get_header(headers, key) do
    headers |> Map.get(key, []) |> List.wrap() |> List.first()
  end
end
