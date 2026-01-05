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
                    ],
                    uniquingKeysWith: { current, _ in current }
                )

                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                process.waitUntilExit()

                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()

                if process.terminationStatus != 0 {
                    continuation.resume(
                        throwing: ProcessRunnerError.nonZeroExit(
                            code: Int(process.terminationStatus),
                            stderr: String(data: errData, encoding: .utf8) ?? ""
                        )
                    )
                    return
                }

                continuation.resume(returning: outData)
            }
        }
    }
}
