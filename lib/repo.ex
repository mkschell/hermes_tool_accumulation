defmodule HermesToolAccumulation.TestRepo do
  use Ecto.Repo,
    otp_app: :hermes_tool_accumulation,
    adapter: Ecto.Adapters.Postgres
end
