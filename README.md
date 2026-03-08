# ClaudeConfigKit

Swift package for monitoring and parsing Claude Code configuration files.

## Features

- **FSEvents-based directory monitoring** for `~/.claude/` with multi-path support, configurable debounce, and raw event stream
- **Config parsing** for `settings.json`, `stats-cache.json`, session histories, and plan files
- **Generic config parser** with pluggable `FileProvider`, file type detection, and size limits
- **Schema detection** with heading levels, recursive `SchemaNode` tree, YAML frontmatter detection, and structural fingerprinting
- **Change classification** — distinguishes schema changes from data changes, file additions, and removals
- **Baseline engine** — async capture/detect with batch processing, file discovery, and baseline update
- **Async I/O** throughout — `FileHasher`, `BaselineEngine`, and `ConfigParser` all use `async throws`

## Requirements

- macOS 15+
- Swift 6.0+

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/metamech/ClaudeConfigKit.git", from: "0.4.1"),
]
```

## License

BSD 3-Clause. See [LICENSE](LICENSE).
