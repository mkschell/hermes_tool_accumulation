# Hermes Tool Accumulation Bug Demonstration

This repository demonstrates a bug in the [Hermes MCP library](https://github.com/cloudwalk/hermes-mcp) where tools are accumulated globally across all clients instead of being isolated per client session.

## Running the Tests

To see the bug in action, run:

```bash
mix deps.get
mix test
```

The test will demonstrate the tool accumulation behavior.

