# ClaudeConfigKit

Swift package for monitoring and parsing Claude Code configuration files.

## Features

- **FSEvents-based directory monitoring** for `~/.claude/`
- **Config parsing** for `settings.json`, `stats-cache.json`, session histories, and plan files
- **Schema detection** and structural fingerprinting for JSON and Markdown configs
- **Change classification** — distinguishes schema changes from data changes, file additions, and removals
- **Baseline engine** — capture snapshots and detect changes against baselines

## Requirements

- macOS 15+
- Swift 6.0+

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/metamech/ClaudeConfigKit.git", from: "0.1.0"),
]
```

## License

BSD 3-Clause. See [LICENSE](LICENSE).
