config :hermes_tool_accumulation, HermesToolAccumulation.TestRepo,
  username: "postgres",
  password: "postgres",
  database: "hermes_tool_accumulation_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
