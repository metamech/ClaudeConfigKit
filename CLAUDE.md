# ClaudeConfigKit

## Purpose
Swift package for monitoring/parsing Claude Code configs + intelligence layer for schema detection and change classification.

## Tech Stack
| Component | Details |
|-----------|---------|
| Language | Swift 6.0 |
| Platform | macOS 15+ |
| Dependencies | swift-log |
| Testing | Swift Testing |
| Build | SPM |

## Structure
```
Sources/ClaudeConfigKit/
  Protocols/    — CodingAgentDirectoryMonitor, HookManagerProtocol
  Monitoring/   — ClaudeDirectoryMonitor (FSEvents)
  Parsing/      — ClaudeSettings, ClaudeStatsCache, ClaudeSessionHistory,
                  ClaudePlan, ClaudeDirectoryState, HookEvent
  Intelligence/ — FileHasher, SchemaStructure, SchemaExtractor,
                  ConfigChangeRecord, ChangeClassifier, BaselineEngine
```

## Commands
| Task | Command |
|------|---------|
| Build | `swift build` |
| Test | `swift test` |

## Rules
- All public API types must be `Sendable`
- FSEvents lifecycle in Monitoring/, never in consumers
- Config file reads are non-destructive — never modify scanned configs
- Use `async/await` for all I/O
- Test fixtures via `Bundle.module` with `.copy("Fixtures")`
