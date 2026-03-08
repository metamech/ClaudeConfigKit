import Foundation
import CoreServices

// MARK: - EventFlags

/// FSEvents flags indicating the type of file system change.
public struct EventFlags: OptionSet, Sendable, Equatable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let created   = EventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemCreated))
    public static let modified  = EventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemModified))
    public static let removed   = EventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemRemoved))
    public static let renamed   = EventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemRenamed))
    public static let isDirectory = EventFlags(rawValue: UInt32(kFSEventStreamEventFlagItemIsDir))
}

// MARK: - FileChangeEvent

/// A raw file system change event from FSEvents.
public struct FileChangeEvent: Sendable, Equatable {
    /// The path that changed.
    public let path: String
    /// The FSEvents flags for this event.
    public let flags: EventFlags
    /// When the event was received.
    public let timestamp: Date

    public init(path: String, flags: EventFlags, timestamp: Date = Date()) {
        self.path = path
        self.flags = flags
        self.timestamp = timestamp
    }
}
