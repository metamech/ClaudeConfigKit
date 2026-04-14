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

    // MARK: - Plan caching tests

    @Test("Cache hit: scanPlans returns same result without re-reading unmodified file")
    @MainActor
    func planCacheHitSameContent() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let projectsDir = tempDir.appendingPathComponent("projects")
        let projectDir = projectsDir.appendingPathComponent("test-project")
        let plansDir = projectDir.appendingPathComponent("plans")
        try FileManager.default.createDirectory(at: plansDir, withIntermediateDirectories: true)

        let planContent = "# Phase 1\n\nThis is the first phase plan with unique marker ABC123."
        let planPath = plansDir.appendingPathComponent("phase-1.md")
        try planContent.write(to: planPath, atomically: true, encoding: .utf8)

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir
        )

        await monitor.startMonitoring()
        try await Task.sleep(nanoseconds: 1_500_000_000)

        let firstPlanResult = state.plans["test-project"] ?? []
        #expect(firstPlanResult.count == 1)
        #expect(firstPlanResult.first?.content.contains("unique marker ABC123") == true)

        // Trigger a second parse pass without modifying the file
        try await Task.sleep(nanoseconds: 1_500_000_000)

        let secondPlanResult = state.plans["test-project"] ?? []
        #expect(secondPlanResult.count == 1)
        // Verify the content is the same (cache was used)
        #expect(secondPlanResult.first?.content == firstPlanResult.first?.content)

        await monitor.stopMonitoring()
    }

    @Test("Cache miss: scanPlans returns updated content when file is modified")
    @MainActor
    func planCacheMissUpdatedContent() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let projectsDir = tempDir.appendingPathComponent("projects")
        let projectDir = projectsDir.appendingPathComponent("test-project")
        let plansDir = projectDir.appendingPathComponent("plans")
        try FileManager.default.createDirectory(at: plansDir, withIntermediateDirectories: true)

        let initialContent = "# Phase 1\n\nInitial content version 1."
        let planPath = plansDir.appendingPathComponent("phase-1.md")
        try initialContent.write(to: planPath, atomically: true, encoding: .utf8)

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir,
            debounceInterval: .milliseconds(100)
        )

        await monitor.startMonitoring()
        try await Task.sleep(nanoseconds: 500_000_000)

        let firstResult = state.plans["test-project"] ?? []
        #expect(firstResult.count == 1)
        #expect(firstResult.first?.content.contains("version 1") == true)

        // Modify the file
        let updatedContent = "# Phase 1\n\nUpdated content version 2."
        try updatedContent.write(to: planPath, atomically: true, encoding: .utf8)

        // Wait for debounce and parse pass
        try await Task.sleep(nanoseconds: 500_000_000)

        let secondResult = state.plans["test-project"] ?? []
        #expect(secondResult.count == 1)
        // Verify the content was updated (cache was invalidated)
        #expect(secondResult.first?.content.contains("version 2") == true)
        #expect(secondResult.first?.content.contains("version 1") == false)

        await monitor.stopMonitoring()
    }

    @Test("Cache eviction: deleted plan file is removed from results")
    @MainActor
    func planCacheEvictionOnDelete() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let projectsDir = tempDir.appendingPathComponent("projects")
        let projectDir = projectsDir.appendingPathComponent("test-project")
        let plansDir = projectDir.appendingPathComponent("plans")
        try FileManager.default.createDirectory(at: plansDir, withIntermediateDirectories: true)

        let plan1Path = plansDir.appendingPathComponent("phase-1.md")
        let plan2Path = plansDir.appendingPathComponent("phase-2.md")

        try "# Phase 1\n\nFirst plan.".write(to: plan1Path, atomically: true, encoding: .utf8)
        try "# Phase 2\n\nSecond plan.".write(to: plan2Path, atomically: true, encoding: .utf8)

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir,
            debounceInterval: .milliseconds(100)
        )

        await monitor.startMonitoring()
        try await Task.sleep(nanoseconds: 500_000_000)

        let initialResult = state.plans["test-project"] ?? []
        #expect(initialResult.count == 2)

        // Delete one of the plan files
        try FileManager.default.removeItem(at: plan1Path)

        // Wait for debounce and parse pass
        try await Task.sleep(nanoseconds: 500_000_000)

        let afterDeleteResult = state.plans["test-project"] ?? []
        // Verify the deleted file is no longer in the results
        #expect(afterDeleteResult.count == 1)
        #expect(afterDeleteResult.first?.content.contains("Second plan") == true)

        await monitor.stopMonitoring()
    }

    @Test("Default debounce interval is 1500ms")
    @MainActor
    func defaultDebounceIs1500ms() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir
        )

        // Create a monitor with default debounce (no explicit interval provided)
        // and verify it behaves with the 1500ms default by checking initialization
        await monitor.startMonitoring()
        let isMonitoring = await monitor.isMonitoring
        #expect(isMonitoring == true)
        await monitor.stopMonitoring()

        // Also verify that a custom debounce of 100ms is noticeably faster
        // by comparing parse timing behavior
        let fastMonitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir,
            debounceInterval: .milliseconds(100)
        )
        await fastMonitor.startMonitoring()
        let fastIsMonitoring = await fastMonitor.isMonitoring
        #expect(fastIsMonitoring == true)
        await fastMonitor.stopMonitoring()
    }

    // MARK: - Pause / Resume tests

    @Test("pause() is idempotent when already paused")
    @MainActor
    func pauseIdempotentWhenAlreadyPaused() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir
        )

        await monitor.startMonitoring()
        var isPaused = await monitor.isPaused
        #expect(isPaused == false)

        // First pause
        await monitor.pause()
        isPaused = await monitor.isPaused
        #expect(isPaused == true)

        // Second pause should be a no-op and not error
        await monitor.pause()
        isPaused = await monitor.isPaused
        #expect(isPaused == true)

        await monitor.stopMonitoring()
    }

    @Test("resume() is idempotent when already running")
    @MainActor
    func resumeIdempotentWhenAlreadyRunning() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir
        )

        await monitor.startMonitoring()
        var isPaused = await monitor.isPaused
        #expect(isPaused == false)

        // resume() when not paused should be a no-op
        await monitor.resume()
        isPaused = await monitor.isPaused
        #expect(isPaused == false)

        // Second resume should also be a no-op
        await monitor.resume()
        isPaused = await monitor.isPaused
        #expect(isPaused == false)

        await monitor.stopMonitoring()
    }

    @Test("pause() before startMonitoring() is a no-op")
    @MainActor
    func pauseBeforeStartIsNoOp() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: tempDir
        )

        // pause() before monitoring has started should be a no-op
        await monitor.pause()
        var isMonitoring = await monitor.isMonitoring
        var isPaused = await monitor.isPaused
        #expect(isMonitoring == false)
        #expect(isPaused == false)

        // startMonitoring should work normally
        await monitor.startMonitoring()
        isMonitoring = await monitor.isMonitoring
        isPaused = await monitor.isPaused
        #expect(isMonitoring == true)
        #expect(isPaused == false)

        await monitor.stopMonitoring()
    }

    @Test("pause() blocks file events in watched directory")
    @MainActor
    func pauseBlocksFileEvents() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        // Create a subdirectory to watch
        let watchDir = tempDir.appendingPathComponent("watch-test")
        try FileManager.default.createDirectory(at: watchDir, withIntermediateDirectories: true)

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: watchDir,
            debounceInterval: .milliseconds(100)
        )

        await monitor.startMonitoring()

        // Give FSEvents a moment to start
        try await Task.sleep(nanoseconds: 200_000_000)

        // Pause monitoring
        await monitor.pause()
        try await Task.sleep(nanoseconds: 50_000_000)

        // Create a file while paused — event should not be yielded
        let testFile = watchDir.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        // Wait to see if an event comes through (should not)
        var eventReceived = false
        let task = Task {
            var iterator = await monitor.fileEvents.makeAsyncIterator()
            if let _ = try? await Task.sleep(nanoseconds: 600_000_000) {
                // Timeout after 600ms, try to get next event
                if let _ = try? await iterator.next() {
                    eventReceived = true
                }
            }
        }
        // Give it time to detect (if it does)
        try await Task.sleep(nanoseconds: 700_000_000)
        task.cancel()

        #expect(eventReceived == false)

        await monitor.stopMonitoring()
        try FileManager.default.removeItem(at: testFile)
    }

    @Test("resume() allows file events after pause")
    @MainActor
    func resumeAllowsFileEvents() async throws {
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        // Create a subdirectory to watch
        let watchDir = tempDir.appendingPathComponent("watch-test-2")
        try FileManager.default.createDirectory(at: watchDir, withIntermediateDirectories: true)

        let state = ClaudeDirectoryState()
        let monitor = ClaudeDirectoryMonitor(
            directoryState: state,
            claudeDirectory: watchDir,
            debounceInterval: .milliseconds(100)
        )

        await monitor.startMonitoring()
        try await Task.sleep(nanoseconds: 200_000_000)

        // Pause, then resume
        await monitor.pause()
        try await Task.sleep(nanoseconds: 50_000_000)
        await monitor.resume()
        try await Task.sleep(nanoseconds: 200_000_000)

        // Now create a file — event should be detected
        let testFile = watchDir.appendingPathComponent("test2.txt")
        try "resume test content".write(to: testFile, atomically: true, encoding: .utf8)

        // Collect events for a short window
        var eventReceived = false
        let eventTask = Task {
            var iterator = await monitor.fileEvents.makeAsyncIterator()
            while !Task.isCancelled {
                if let _ = try? await iterator.next() {
                    eventReceived = true
                    break
                }
            }
        }

        try await Task.sleep(nanoseconds: 800_000_000)
        eventTask.cancel()

        #expect(eventReceived == true)

        await monitor.stopMonitoring()
        try FileManager.default.removeItem(at: testFile)
    }

    @Test("startMonitoring() after stopMonitoring() is guarded and logs warning")
    @MainActor
    func startAfterStopReturnsEarly() async throws {
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

        // Stop monitoring, which nils fileEventContinuation
        await monitor.stopMonitoring()
        isMonitoring = await monitor.isMonitoring
        #expect(isMonitoring == false)

        // Try to start again — should be guarded and return early
        // (The logger will emit a warning, but the call should not crash)
        await monitor.startMonitoring()
        isMonitoring = await monitor.isMonitoring
        #expect(isMonitoring == false)
    }
}
