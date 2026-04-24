import Foundation

struct CrashInfo {
    let signal: String
    let timestamp: Date
}

// Global file descriptor accessible from C signal handlers (no context capture)
private var gCrashFd: Int32 = -1

// C-compatible signal handler (free function, no captures)
private func crashSignalHandler(_ sig: Int32) {
    guard gCrashFd >= 0 else { return }

    // Map signal to a fixed-length ASCII name (signal-safe: no heap allocation)
    var buf: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0)
    let len: Int
    switch sig {
    case SIGABRT: buf = (0x53,0x49,0x47,0x41,0x42,0x52,0x54,0); len = 7  // "SIGABRT"
    case SIGSEGV: buf = (0x53,0x49,0x47,0x53,0x45,0x47,0x56,0); len = 7  // "SIGSEGV"
    case SIGBUS:  buf = (0x53,0x49,0x47,0x42,0x55,0x53,0,0);    len = 6  // "SIGBUS"
    case SIGFPE:  buf = (0x53,0x49,0x47,0x46,0x50,0x45,0,0);    len = 6  // "SIGFPE"
    case SIGILL:  buf = (0x53,0x49,0x47,0x49,0x4C,0x4C,0,0);    len = 6  // "SIGILL"
    case SIGTRAP: buf = (0x53,0x49,0x47,0x54,0x52,0x41,0x50,0); len = 7  // "SIGTRAP"
    default:      buf = (0x55,0x4E,0x4B,0x4E,0x4F,0x57,0x4E,0); len = 7  // "UNKNOWN"
    }

    lseek(gCrashFd, 0, SEEK_SET)
    withUnsafePointer(to: &buf) { ptr in
        _ = Darwin.write(gCrashFd, ptr, len)
    }
    fsync(gCrashFd)

    // Re-raise to get default behavior (core dump / termination)
    signal(sig, SIG_DFL)
    raise(sig)
}

enum CrashReporter {
    private static let markerURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(".polychat_crash_marker")
    }()

    static func install() {
        // Pre-open the crash marker file so the signal handler doesn't need to allocate
        gCrashFd = open(markerURL.path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)

        signal(SIGABRT, crashSignalHandler)
        signal(SIGSEGV, crashSignalHandler)
        signal(SIGBUS,  crashSignalHandler)
        signal(SIGFPE,  crashSignalHandler)
        signal(SIGILL,  crashSignalHandler)
        signal(SIGTRAP, crashSignalHandler)

        NSSetUncaughtExceptionHandler { exception in
            guard gCrashFd >= 0 else { return }
            let name = exception.name.rawValue
            name.withCString { ptr in
                lseek(gCrashFd, 0, SEEK_SET)
                _ = Darwin.write(gCrashFd, ptr, strlen(ptr))
                fsync(gCrashFd)
            }
        }
    }

    static func readAndClearCrashMarker() -> CrashInfo? {
        guard FileManager.default.fileExists(atPath: markerURL.path) else { return nil }

        do {
            // Read attrs before removing
            let attrs = try? FileManager.default.attributesOfItem(atPath: markerURL.path)
            let timestamp = attrs?[.modificationDate] as? Date ?? Date()

            let content = try String(contentsOf: markerURL, encoding: .ascii)
            try FileManager.default.removeItem(at: markerURL)

            guard !content.isEmpty else { return nil }

            return CrashInfo(signal: content.trimmingCharacters(in: .whitespacesAndNewlines), timestamp: timestamp)
        } catch {
            try? FileManager.default.removeItem(at: markerURL)
            return nil
        }
    }
}
