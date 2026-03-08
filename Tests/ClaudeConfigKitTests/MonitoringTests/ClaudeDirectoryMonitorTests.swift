import Foundation
import Testing

@testable import ClaudeConfigKit

// MARK: - Claude Directory Monitor Tests

@Suite("Claude Directory Monitor")
struct ClaudeDirectoryMonitorTests {

    // MARK: - Temp directory helper

    func createTempDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("cck-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        return testDir
    }

    func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Initial state tests

    @Test("Monitor initial state is not monitoring")
    @MainActor
    func initialStateNotMonitoring() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir
        )

        let isMonitoring = await monitor.isMonitoring
        #expect(isMonitoring == false)
    }

    // MARK: - Start/stop monitoring

    @Test("startMonitoring sets isMonitoring to true")
    @MainActor
    func startMonitoringSetsFlag() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir
        )

        var isMonitoring = await monitor.isMonitoring
        #expect(isMonitoring == false)

        await monitor.startMonitoring()
        isMonitoring = await monitor.isMonitoring
        #expect(isMonitoring == true)
    }

    @Test("stopMonitoring clears isMonitoring")
    @MainActor
    func stopMonitoringClearsFlag() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir
        )

        await monitor.startMonitoring()
        var isMonitoring = await monitor.isMonitoring
        #expect(isMonitoring == true)

        await monitor.stopMonitoring()
        isMonitoring = await monitor.isMonitoring
        #expect(isMonitoring == false)
    }

    // MARK: - File parsing tests

    @Test("Monitor parses settings.json from temp directory")
    @MainActor
    func parseSettingsFromTempDir() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let settingsJSON = """
        {
            "permissions": {
                "Bash": {"decision": "deny"}
            },
            "env": {
                "TEST_VAR": "test_value"
            }
        }
        """
        let settingsPath = tempDir.appendingPathComponent("settings.json")
        try settingsJSON.write(to: settingsPath, atomically: true, encoding: .utf8)

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir
        )

        await monitor.startMonitoring()
        try await Task.sleep(nanoseconds: 1_000_000_000)

        #expect(state.settings != nil)
        #expect(state.settings?.permissions?["Bash"]?.decision == "deny")
        #expect(state.settings?.env?["TEST_VAR"] == "test_value")

        await monitor.stopMonitoring()
    }

    @Test("Monitor parses stats-cache.json from temp directory")
    @MainActor
    func parseStatsCacheFromTempDir() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let statsJSON = """
        {
            "version": 2,
            "totalSessions": 10,
            "totalMessages": 500,
            "lastComputedDate": "2026-02-16"
        }
        """
        let statsPath = tempDir.appendingPathComponent("stats-cache.json")
        try statsJSON.write(to: statsPath, atomically: true, encoding: .utf8)

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir
        )

        await monitor.startMonitoring()
        try await Task.sleep(nanoseconds: 1_000_000_000)

        #expect(state.statsCache != nil)
        #expect(state.statsCache?.version == 2)
        #expect(state.statsCache?.totalSessions == 10)
        #expect(state.statsCache?.totalMessages == 500)

        await monitor.stopMonitoring()
    }

    @Test("Monitor parses history.jsonl from projects subdirectory")
    @MainActor
    func parseHistoryFromProjectsDir() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let projectsDir = tempDir.appendingPathComponent("projects")
        let projectDir = projectsDir.appendingPathComponent("test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let historyJSON = """
        {"session_id":"sess-001","timestamp":1708769160000,"type":"user","content":"Hello"}
        {"session_id":"sess-001","timestamp":1708769165000,"type":"assistant","model":"claude-opus-4-6"}
        """
        let historyPath = projectDir.appendingPathComponent("history.jsonl")
        try historyJSON.write(to: historyPath, atomically: true, encoding: .utf8)

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir
        )

        await monitor.startMonitoring()
        try await Task.sleep(nanoseconds: 1_000_000_000)

        #expect(state.sessionHistories.count > 0)
        let entries = state.sessionHistories["test-project"]
        #expect(entries != nil)
        #expect(entries?.count == 2)
        #expect(entries?[0].sessionId == "sess-001")
        #expect(entries?[0].type == "user")
        #expect(entries?[1].type == "assistant")

        await monitor.stopMonitoring()
    }

    // MARK: - Error handling

    @Test("Monitor handles missing directory gracefully")
    @MainActor
    func missingDirectoryHandledGracefully() async throws {
        let nonexistentDir = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString)")

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: nonexistentDir
        )

        await monitor.startMonitoring()
        let isMonitoring = await monitor.isMonitoring
        #expect(isMonitoring == false)
    }

    @Test("Monitor handles malformed JSON gracefully")
    @MainActor
    func malformedJSONHandledGracefully() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let malformedJSON = "{invalid json content"
        let settingsPath = tempDir.appendingPathComponent("settings.json")
        try malformedJSON.write(to: settingsPath, atomically: true, encoding: .utf8)

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir
        )

        await monitor.startMonitoring()
        try await Task.sleep(nanoseconds: 1_000_000_000)

        #expect(state.errors.count > 0)
        #expect(state.settings == nil)

        await monitor.stopMonitoring()
    }

    @Test("Monitor parses plan markdown files from projects subdirectory")
    @MainActor
    func parsePlansFromProjectsDir() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let projectsDir = tempDir.appendingPathComponent("projects")
        let projectDir = projectsDir.appendingPathComponent("test-project")
        let plansDir = projectDir.appendingPathComponent("plans")
        try FileManager.default.createDirectory(at: plansDir, withIntermediateDirectories: true)

        let plan1Content = "# Phase 1\n\nThis is the first phase plan."
        let plan2Content = "# Phase 2\n\nThis is the second phase plan."

        try plan1Content.write(
            to: plansDir.appendingPathComponent("phase-1.md"),
            atomically: true,
            encoding: .utf8
        )
        try plan2Content.write(
            to: plansDir.appendingPathComponent("phase-2.md"),
            atomically: true,
            encoding: .utf8
        )

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir
        )

        await monitor.startMonitoring()
        try await Task.sleep(nanoseconds: 1_000_000_000)

        #expect(state.plans.count > 0)
        let projectPlans = state.plans["test-project"]
        #expect(projectPlans != nil)
        #expect(projectPlans?.count == 2)

        let contents = (projectPlans ?? []).map { $0.content }.sorted()
        #expect(contents.contains { $0.contains("Phase 1") })
        #expect(contents.contains { $0.contains("Phase 2") })

        await monitor.stopMonitoring()
    }

    // MARK: - Configurable debounce

    @Test("Monitor accepts custom debounce interval")
    @MainActor
    func customDebounceInterval() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir,
            debounceInterval: .milliseconds(100)
        )

        await monitor.startMonitoring()
        let isMonitoring = await monitor.isMonitoring
        #expect(isMonitoring == true)
        await monitor.stopMonitoring()
    }

    // MARK: - Multi-path monitoring

    @Test("Monitor supports multi-path init")
    @MainActor
    func multiPathInit() async throws {
        let tempDir1 = createTempDirectory()
        let tempDir2 = createTempDirectory()
        defer {
            cleanupTempDirectory(tempDir1)
            cleanupTempDirectory(tempDir2)
        }

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            monitoredPaths: [tempDir1, tempDir2]
        )

        await monitor.startMonitoring()
        let isMonitoring = await monitor.isMonitoring
        #expect(isMonitoring == true)
        await monitor.stopMonitoring()
    }

    @Test("updatePaths reinstalls stream")
    @MainActor
    func updatePathsReinstallsStream() async throws {
        let tempDir1 = createTempDirectory()
        let tempDir2 = createTempDirectory()
        defer {
            cleanupTempDirectory(tempDir1)
            cleanupTempDirectory(tempDir2)
        }

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir1
        )

        await monitor.startMonitoring()
        var isMonitoring = await monitor.isMonitoring
        #expect(isMonitoring == true)

        await monitor.updatePaths([tempDir2])
        isMonitoring = await monitor.isMonitoring
        #expect(isMonitoring == true)

        await monitor.stopMonitoring()
    }

    // MARK: - Raw event stream

    @Test("fileEvents property is accessible")
    @MainActor
    func fileEventsAccessible() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir
        )

        // Just verify we can access the stream property without crashing
        let _: AsyncStream<[FileChangeEvent]> = monitor.fileEvents
        await monitor.startMonitoring()
        await monitor.stopMonitoring()
    }
}
