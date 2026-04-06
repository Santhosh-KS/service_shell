defmodule ServiceShell.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ServiceShellWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:service_shell, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ServiceShell.PubSub},
      # Start a worker by calling: ServiceShell.Worker.start_link(arg)
      # {ServiceShell.Worker, arg},
      # Start to serve requests, typically the last entry
      ServiceShellWeb.Endpoint,
      ServiceShell.RecordingManager,
      # Add this line to launch the native window
      {Desktop.Window,
       [
         app: :service_shell,
         id: ServiceShell,
         title: "Service Shell",
         size: {1280, 720},
         url: &ServiceShellWeb.Endpoint.url/0
         # This flag disables the Same-Origin Policy and CSP checks for this window NOTE: Windows only
         # additional_browser_args: "--disable-web-security --user-data-dir=./webview_data"
       ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ServiceShell.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ServiceShellWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
