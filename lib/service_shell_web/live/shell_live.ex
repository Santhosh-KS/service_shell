defmodule ServiceShellWeb.ShellLive do
  use ServiceShellWeb, :live_view
  alias ServiceShell.RecordingManager

  # def mount(_params, _session, socket) do
  #   # Check the actual status of the GenServer on mount
  #   # This ensures the UI stays in sync if the page reloads
  #   %{status: status} = RecordingManager.status()

  #   {:ok,
  #    assign(socket,
  #      # Default to our Satellite YT Player
  #      # current_url: "/proxy/9000/",
  #      current_url: "/proxy/4241/",
  #      active_tab: "Dashboard",
  #      is_recording: status == :recording,
  #      services: [
  #        %{name: "Dashboard", port: 4241, icon: "hero-play-circle"},
  #        %{name: "YT App", port: 8080, icon: "hero-cpu-chip"}
  #        # %{name: "Dashboard", port: 4000, icon: "hero-chart-bar"}
  #      ]
  #    )}
  # end

  @impl true
  def mount(_params, _session, socket) do
    services = [
      %{
        name: "Local App",
        host: "127.0.0.1",
        port: 9000,
        icon: "hero-device-tablet",
        status: :unknown
      },
      %{
        name: "Raspberry Pi",
        host: "192.168.1.50",
        port: 8080,
        icon: "hero-cpu-chip",
        status: :unknown
      },
      %{
        name: "Staging Server",
        host: "172.20.10.14",
        port: 4000,
        icon: "hero-server-stack",
        status: :unknown
      }
    ]

    # Start the "Heartbeat" timer
    if connected?(socket), do: :timer.send_interval(5000, :check_services)

    {:ok,
     assign(socket,
       # Default
       current_url: "/proxy/127.0.0.1/9000/",
       active_tab: "Local App",
       # ADD THESE TWO LINES TO FIX THE KEYERROR:
       is_recording: false,
       recording_seconds: 0,
       services: services
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen w-full bg-base-300 overflow-hidden">
      <aside class="w-72 bg-base-200 border-r border-base-100 flex flex-col shadow-lg">
        <div class="p-6 flex items-center gap-3">
          <div class="p-2 bg-primary rounded-lg text-primary-content">
            <.icon name="hero-command-line" class="h-6 w-6" />
          </div>
          <h1 class="font-bold text-xl tracking-tight">Service Shell</h1>
        </div>

        <ul class="menu menu-md px-4 flex-1">
          <li class="menu-title text-xs uppercase opacity-50 font-bold mb-2">Local Services</li>
          <%= for service <- @services do %>
            <%!-- <li>
              <button
                phx-click="switch_service"
                phx-value-host={service.host}
                phx-value-port={service.port}
                phx-value-name={service.name}
                class={"flex items-center gap-3 mb-1 #{if @active_tab == service.name, do: "active bg-primary text-primary-content"}"}
              >
                <.icon name={service.icon} class="h-5 w-5" />
                <span class="flex-1 text-left">{service.name}</span>
                <span class="opacity-40 text-xs font-mono">:{service.port}</span>
              </button>
            </li> --%>
            <li>
              <button
                phx-click="switch_service"
                phx-value-host={service.host}
                phx-value-port={service.port}
                phx-value-name={service.name}
                class={"flex items-center gap-3 mb-1 #{if @active_tab == service.name, do: "active bg-primary text-primary-content"}"}
              >
                <div class="relative">
                  <.icon name={service.icon} class="h-5 w-5" />
                  <span class={"absolute -bottom-1 -right-1 flex h-2.5 w-2.5 rounded-full border-2 border-base-200 #{case service.status do
                      :up -> "bg-success"
                      :down -> "bg-error"
                      _ -> "bg-base-content/20"
                    end}"}>
                  </span>
                </div>

                <span class="flex-1 text-left">{service.name}</span>

                <%= if service.status == :up do %>
                  <span class="relative flex h-2 w-2">
                    <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-success opacity-75">
                    </span>
                    <span class="relative inline-flex rounded-full h-2 w-2 bg-success"></span>
                  </span>
                <% end %>
              </button>
            </li>
          <% end %>

          <div class="divider"></div>
          <li class="menu-title text-xs uppercase opacity-50 font-bold mb-2">Controls</li>

          <li class="mt-2">
            <button
              phx-click="toggle_record"
              class={"btn btn-block justify-start gap-3 #{if @is_recording, do: "btn-error", else: "btn-outline"}"}
            >
              <div class="relative">
                <.icon
                  name={if @is_recording, do: "hero-stop-circle", else: "hero-video-camera"}
                  class="h-5 w-5"
                />
                <%= if @is_recording do %>
                  <span class="absolute -top-1 -right-1 flex h-2 w-2">
                    <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-white opacity-75">
                    </span>
                    <span class="relative inline-flex rounded-full h-2 w-2 bg-white"></span>
                  </span>
                <% end %>
              </div>
              {if @is_recording, do: "Stop Recording", else: "Start Capture"}
            </button>
          </li>

          <li class="mt-2">
            <button
              phx-click="open_recordings"
              class="btn btn-ghost btn-sm gap-2 opacity-70 hover:opacity-100"
            >
              <.icon name="hero-folder-open" class="h-4 w-4" /> Browse Recordings
            </button>
          </li>
        </ul>

        <div class="p-4 bg-base-300/50 text-[10px] font-mono opacity-50 truncate">
          Viewing: {@current_url}
        </div>
      </aside>

      <main class="flex-1 flex flex-col relative bg-white">
        <div class="bg-base-100 border-b border-base-200 px-4 py-2 flex items-center justify-between shadow-sm z-10">
          <span class="text-sm font-medium text-base-content/70">{@active_tab}</span>
          <div class="flex gap-2">
            <button
              class="btn btn-ghost btn-xs"
              onclick="document.getElementById('service-viewport').contentWindow.location.reload();"
            >
              <.icon name="hero-arrow-path" class="h-3 w-3" />
            </button>
          </div>
        </div>

        <iframe
          id="service-viewport"
          src={@current_url}
          class="w-full h-full border-none"
          allow="cross-origin-isolated"
        >
        </iframe>
      </main>
    </div>
    """
  end

  # @impl true
  # def handle_event("switch_service", %{"port" => port, "name" => name}, socket) do
  #   # We point to the local proxy path we created earlier
  #   proxy_url = "/proxy/#{port}/"
  #   {:noreply, assign(socket, current_url: proxy_url, active_tab: name)}
  # end

  @impl true
  def handle_event("switch_service", %{"host" => host, "port" => port, "name" => name}, socket) do
    proxy_url = "/proxy/#{host}/#{port}/"
    {:noreply, assign(socket, current_url: proxy_url, active_tab: name)}
  end

  @impl true
  def handle_event("toggle_record", _params, socket) do
    if socket.assigns.is_recording do
      RecordingManager.stop_recording()
      {:noreply, assign(socket, is_recording: false)}
    else
      # Format: capture_timestamp.mp4
      filename = "capture_#{System.system_time(:second)}.mp4"

      case RecordingManager.start_recording(filename) do
        :ok ->
          {:noreply, assign(socket, is_recording: true)}

        {:error, reason} ->
          # Add a flash message if recording fails (e.g. ffmpeg not found)
          {:noreply, put_flash(socket, :error, "Could not start recording: #{reason}")}
      end
    end
  end

  def handle_event("open_recordings", _params, socket) do
    # Determine the absolute path to the recordings folder
    path = Path.expand("recordings")

    # Trigger the OS-specific "Open Folder" command
    case :os.type() do
      {:unix, :darwin} -> System.cmd("open", [path])
      {:win32, _} -> System.cmd("explorer", [String.replace(path, "/", "\\")])
      {:unix, :linux} -> System.cmd("xdg-open", [path])
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:check_services, socket) do
    updated_services =
      Enum.map(socket.assigns.services, fn service ->
        # Attempt a quick 500ms connection check
        status =
          case :gen_tcp.connect(String.to_charlist(service.host), service.port, [], 500) do
            {:ok, socket} ->
              :gen_tcp.close(socket)
              :up

            _error ->
              :down
          end

        Map.put(service, :status, status)
      end)

    {:noreply, assign(socket, services: updated_services)}
  end
end
