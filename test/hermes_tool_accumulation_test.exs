defmodule HermesToolAccumulationTest do
  use ExUnit.Case, async: false

  require Logger

  # Test server that registers different tools based on client
  defmodule TestServer do
    use Hermes.Server,
      name: "Test Server",
      version: "1.0.0",
      capabilities: [:tools]

    @impl true
    def init(client_info, frame) do
      client_name = client_info["name"]
      Logger.info("TestServer init called for client: #{client_name}")

      # Register different tools based on client
      case client_name do
        "client_a" ->
          frame =
            frame
            |> Hermes.Server.Frame.register_tool("tool_a",
              description: "Tool A for Client A",
              input_schema: %{}
            )
            |> Hermes.Server.Frame.register_tool("tool_b",
              description: "Tool B for Client A",
              input_schema: %{}
            )

          {:ok, frame}

        "client_b" ->
          frame =
            frame
            |> Hermes.Server.Frame.register_tool("tool_x",
              description: "Tool X for Client B",
              input_schema: %{}
            )
            |> Hermes.Server.Frame.register_tool("tool_y",
              description: "Tool Y for Client B",
              input_schema: %{}
            )

          {:ok, frame}

        _ ->
          {:ok, frame}
      end
    end

    @impl true
    def handle_tool_call(tool_name, _args, frame) do
      # Simple echo response - must use Hermes response format
      response =
        Hermes.Server.Response.tool()
        |> Hermes.Server.Response.json(%{"result" => "Called tool: #{tool_name}"})

      {:reply, response, frame}
    end
  end

  describe "global frame state corruption" do
    test "demonstrates that tools accumulate globally across clients instead of being client-specific" do
      # Start the test server
      {:ok, server_pid} = start_test_server()

      # Simulate Client A connecting
      client_a_session = "session_a_#{System.unique_integer()}"
      client_a_info = %{"name" => "client_a", "version" => "1.0.0"}

      # Client A initializes
      {:ok, _} = initialize_client(server_pid, client_a_session, client_a_info)

      # Client A lists tools - should see tool_a and tool_b
      {:ok, tools_response_a} = list_tools(server_pid, client_a_session)
      tools_a = tools_response_a["result"]["tools"]
      tool_names_a = Enum.map(tools_a, & &1["name"]) |> Enum.sort()

      assert tool_names_a == ["tool_a", "tool_b"]
      Logger.info("Client A sees tools: #{inspect(tool_names_a)}")

      # Now Client B connects
      client_b_session = "session_b_#{System.unique_integer()}"
      client_b_info = %{"name" => "client_b", "version" => "1.0.0"}

      # Client B initializes - this adds tools to the global frame!
      {:ok, _} = initialize_client(server_pid, client_b_session, client_b_info)

      # Client B lists tools - should see all accumulated tools
      {:ok, tools_response_b} = list_tools(server_pid, client_b_session)
      tools_b = tools_response_b["result"]["tools"]
      tool_names_b = Enum.map(tools_b, & &1["name"]) |> Enum.sort()

      Logger.info("Client B sees tools: #{inspect(tool_names_b)}")

      # Check if tools are being accumulated rather than isolated
      if tool_names_b == ["tool_a", "tool_b", "tool_x", "tool_y"] do
        Logger.warning(
          "BUG CONFIRMED: Tools are being accumulated globally instead of being client-specific!"
        )
      end

      # THE BUG: Client A lists tools again - will now see Client B's tools too!
      {:ok, tools_response_a_after} = list_tools(server_pid, client_a_session)
      tools_a_after = tools_response_a_after["result"]["tools"]
      tool_names_a_after = Enum.map(tools_a_after, & &1["name"]) |> Enum.sort()

      Logger.info("Client A sees tools AFTER Client B connects: #{inspect(tool_names_a_after)}")

      # Check what actually happened
      cond do
        tool_names_a_after == ["tool_a", "tool_b"] ->
          Logger.info("No bug detected - Client A still sees only its own tools")

        tool_names_a_after == ["tool_x", "tool_y"] ->
          Logger.error("BUG: Client A's tools were completely replaced by Client B's tools!")
          assert false, "Client A's tools were replaced instead of accumulated!"

        tool_names_a_after == ["tool_a", "tool_b", "tool_x", "tool_y"] ->
          Logger.error(
            "BUG CONFIRMED: Tools are accumulating globally! Client A can see Client B's tools."
          )

          Logger.error("Expected Client A to see: [\"tool_a\", \"tool_b\"]")
          Logger.error("Client A actually sees: #{inspect(tool_names_a_after)}")
          assert false, "Tools are accumulating globally rather than being client-specific!"

        true ->
          Logger.error("Unexpected tool configuration: #{inspect(tool_names_a_after)}")
          assert false, "Unexpected tool configuration detected"
      end

      # Cleanup
      stop_test_server(server_pid)
    end
  end

  # Helper functions to interact with the server

  defp start_test_server do
    # Use a unique name for each test to avoid conflicts
    server_name = :"test_server_#{System.unique_integer([:positive])}"

    # Start with a stub transport for testing
    Hermes.Server.Supervisor.start_link(TestServer,
      name: server_name,
      # We'll interact via direct GenServer calls
      transport: :stdio
    )
  end

  defp stop_test_server(server_pid) do
    Supervisor.stop(server_pid, :normal)
  end

  defp initialize_client(server_pid, session_id, client_info) do
    # Simulate the initialization handshake
    request = %{
      "jsonrpc" => "2.0",
      "method" => "initialize",
      "params" => %{
        "protocolVersion" => "2024-11-05",
        "clientInfo" => client_info,
        "capabilities" => %{}
      },
      "id" => 1
    }

    # Get the actual server process from the supervisor
    [{_, base_pid, _, _}] =
      Supervisor.which_children(server_pid)
      |> Enum.filter(fn {_, _, _, [module]} -> module == Hermes.Server.Base end)

    # Send initialize request
    GenServer.call(base_pid, {:request, request, session_id, %{}})

    # Send initialized notification
    notification = %{
      "jsonrpc" => "2.0",
      "method" => "notifications/initialized"
    }

    GenServer.cast(base_pid, {:notification, notification, session_id, %{}})

    # Give it a moment to process
    Process.sleep(10)

    {:ok, session_id}
  end

  defp list_tools(server_pid, session_id) do
    request = %{
      "jsonrpc" => "2.0",
      "method" => "tools/list",
      "id" => 2
    }

    [{_, base_pid, _, _}] =
      Supervisor.which_children(server_pid)
      |> Enum.filter(fn {_, _, _, [module]} -> module == Hermes.Server.Base end)

    case GenServer.call(base_pid, {:request, request, session_id, %{}}) do
      {:ok, response} -> {:ok, JSON.decode!(response)}
      error -> error
    end
  end

  defp call_tool(server_pid, session_id, tool_name, args) do
    request = %{
      "jsonrpc" => "2.0",
      "method" => "tools/call",
      "params" => %{
        "name" => tool_name,
        "arguments" => args
      },
      "id" => 3
    }

    [{_, base_pid, _, _}] =
      Supervisor.which_children(server_pid)
      |> Enum.filter(fn {_, _, _, [module]} -> module == Hermes.Server.Base end)

    case GenServer.call(base_pid, {:request, request, session_id, %{}}) do
      {:ok, response} ->
        decoded = JSON.decode!(response)

        if decoded["error"] do
          {:error, decoded}
        else
          {:ok, decoded}
        end

      error ->
        error
    end
  end
end
