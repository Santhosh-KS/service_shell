defmodule ServiceShell.RecordingManager do
  use GenServer
  require Logger

  # Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{port: nil, filename: nil}, name: __MODULE__)
  end

  def start_recording(filename) do
    GenServer.call(__MODULE__, {:start, filename})
  end

  def stop_recording do
    GenServer.call(__MODULE__, :stop)
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  # Add this to handle the process exiting automatically
  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.info("FFmpeg process exited with status: #{status}")
    {:noreply, %{state | port: nil}}
  end

  def handle_info(msg, state) do
    Logger.debug("Received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Server Callbacks
  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:start, filename}, _from, state) do
    if state.port && Port.info(state.port) do
      {:reply, {:error, :already_recording}, state}
    else
      {cmd, args} = ffmpeg_config(filename)
      executable = System.find_executable(cmd)

      if executable do
        # We use :exit_status and :use_stdio to monitor the process
        port =
          Port.open({:spawn_executable, executable}, [
            :binary,
            :exit_status,
            :use_stdio,
            :stderr_to_stdout,
            args: args
          ])

        Logger.info("Recording started: #{filename}")
        {:reply, :ok, %{state | port: port, filename: filename}}
      else
        {:reply, {:error, "FFmpeg not found in system PATH"}, state}
      end
    end
  end

  @impl true
  def handle_call(:stop, _from, %{port: port} = state) do
    # Check if the port is still valid before sending "q"
    if port && Port.info(port) do
      try do
        # "q" tells FFmpeg to finish the file and exit gracefully
        Port.command(port, "q")
        {:reply, :ok, %{state | port: nil}}
      rescue
        _ -> {:reply, {:error, :port_closed}, %{state | port: nil}}
      end
    else
      {:reply, :ok, %{state | port: nil}}
    end
  end

  @impl true
  def handle_call({:start, filename}, _from, state) do
    if state.port do
      {:reply, {:error, :already_recording}, state}
    else
      {cmd, args} = ffmpeg_config(filename)
      # We use Port.open to integrate the external OS process into the BEAM
      port =
        Port.open({:spawn_executable, System.find_executable(cmd)}, [
          :binary,
          :exit_status,
          args: args
        ])

      Logger.info("Recording started: #{filename}")
      {:reply, :ok, %{state | port: port, filename: filename}}
    end
  end

  @impl true
  def handle_call(:stop, _from, %{port: port} = state) do
    if port do
      # Sending 'q' to ffmpeg is the "clean" way to stop it
      Port.command(port, "q")
      {:reply, :ok, %{state | port: nil}}
    else
      {:reply, {:error, :not_recording}, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = if state.port, do: :recording, else: :idle
    {:reply, %{status: status, filename: state.filename}, state}
  end

  # Helper for OS-specific commands
  defp ffmpeg_config(filename) do
    # 1. Create the directory if it doesn't exist
    File.mkdir_p!("recordings")
    path = "recordings/#{filename}"

    # 2. Return the command and the list of arguments based on the OS
    case :os.type() do
      {:unix, :darwin} ->
        # macOS: "-i 1" usually grabs the main display.
        # ":none" tells ffmpeg not to look for an audio device.
        {"ffmpeg",
         [
           "-f",
           "avfoundation",
           "-i",
           # "2",
           "0",
           "-pix_fmt",
           "yuv420p",
           "-r",
           "30",
           "-y",
           path
         ]}

      {:win32, _} ->
        {"ffmpeg", ["-f", "gdigrab", "-framerate", "30", "-i", "desktop", "-y", path]}

      {:unix, :linux} ->
        {"ffmpeg", ["-f", "x11grab", "-s", "1280x720", "-i", ":0.0", "-y", path]}

      _ ->
        {"ffmpeg", ["-i", "pipe:0", "-y", path]}
    end
  end
end
