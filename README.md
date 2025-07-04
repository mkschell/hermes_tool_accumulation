# Hermes Tool Accumulation Bug Demonstration

> **⚠️ DEPRECATED ⚠️**  
> This repository is preserved for historical purposes. Behavior explored herein is not a bug. 🤦‍♂️  
> 
> Sometimes you build the perfect reproduction by incorporating bad assumptions! 🏗️

---

~~This repository demonstrates a bug in the [Hermes MCP library](https://github.com/cloudwalk/hermes-mcp) where tools are accumulated globally across all clients instead of being isolated per client session.~~

## Running the Tests

To see the ~~bug~~ perfectly normal behavior in action, run:

```bash
mix deps.get
mix test
```

The test will demonstrate the tool accumulation behavior.

