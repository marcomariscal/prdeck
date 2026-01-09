import Foundation

enum ProcessRunnerError: Error, CustomStringConvertible {
    case nonZeroExit(code: Int, stderr: String)

    var description: String {
        switch self {
        case .nonZeroExit(let code, let stderr):
            if stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Process failed with exit code \(code)."
            }
            return "Process failed with exit code \(code): \(stderr)"
        }
    }
}

enum ProcessRunner {
    private final class LockedData: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()

        func append(_ chunk: Data) {
            lock.lock()
            data.append(chunk)
            lock.unlock()
        }

        func snapshot() -> Data {
            lock.lock()
            let snapshot = data
            lock.unlock()
            return snapshot
        }
    }

    static func findExecutable(named name: String) -> String? {
        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        var candidates = envPath.split(separator: ":").map { "\($0)/\(name)" }
        candidates.append("/opt/homebrew/bin/\(name)")
        candidates.append("/usr/local/bin/\(name)")
        candidates.append("/usr/bin/\(name)")

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    static func run(_ executablePath: String, arguments: [String]) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments
                process.environment = ProcessInfo.processInfo.environment.merging(
                    [
                        "GH_PAGER": "cat",
                        "PAGER": "cat",
                        "LESS": "FRSX",
                        "NO_COLOR": "1",
                    ],
                    uniquingKeysWith: { _, new in new }
                )

                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                let pipesDone = DispatchGroup()

                let stdoutState = LockedData()
                let stderrState = LockedData()

                pipesDone.enter()
                stdout.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    guard !chunk.isEmpty else {
                        handle.readabilityHandler = nil
                        pipesDone.leave()
                        return
                    }
                    stdoutState.append(chunk)
                }

                pipesDone.enter()
                stderr.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    guard !chunk.isEmpty else {
                        handle.readabilityHandler = nil
                        pipesDone.leave()
                        return
                    }
                    stderrState.append(chunk)
                }

                do {
                    try process.run()
                } catch {
                    stdout.fileHandleForReading.readabilityHandler = nil
                    stderr.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                    return
                }

                process.waitUntilExit()

                _ = pipesDone.wait(timeout: .now() + .seconds(1))
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil

                let outRemainder = stdout.fileHandleForReading.readDataToEndOfFile()
                let errRemainder = stderr.fileHandleForReading.readDataToEndOfFile()

                stdoutState.append(outRemainder)
                stderrState.append(errRemainder)

                if process.terminationStatus != 0 {
                    let stderrData = stderrState.snapshot()
                    continuation.resume(
                        throwing: ProcessRunnerError.nonZeroExit(
                            code: Int(process.terminationStatus),
                            stderr: String(data: stderrData, encoding: .utf8) ?? ""
                        )
                    )
                    return
                }

                continuation.resume(returning: stdoutState.snapshot())
            }
        }
    }
}
