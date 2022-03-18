//  Copyright (c) 2022 Felipe Marino
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

public enum Shell {
    public struct Output: Equatable {
        public let succeeded: Bool
        public let data: Data
        public let errorData: Data
    }

    @discardableResult
    public static func run(
        workingDirectory: String? = FileManager.default.currentDirectoryPath,
        outputPipe: Pipe = .init(),
        errorPipe: Pipe = .init(),
        arguments: String...,
        verbose: Bool,
        timeout: TimeInterval? = 30
    ) throws -> Output {
        try runProcess(
            workingDirectory: workingDirectory,
            outputPipe: outputPipe,
            errorPipe: errorPipe,
            arguments: arguments,
            verbose: verbose,
            timeout: timeout
        )
    }

    @discardableResult
    public static func run(
        _ command: String,
        outputPipe: Pipe = .init(),
        errorPipe: Pipe = .init(),
        workingDirectory: String? = FileManager.default.currentDirectoryPath,
        verbose: Bool,
        timeout: TimeInterval? = 30
    ) throws -> Output {
        let commands = command.split(whereSeparator: \.isWhitespace)

        let arguments: [String]
        if commands.count > 1 {
            arguments = commands.map { String($0) }
        } else {
            arguments = command
                .split { [" -", " --"].contains(String($0)) }
                .map { String($0) }
        }

        return try runProcess(
            workingDirectory: workingDirectory,
            outputPipe: outputPipe,
            errorPipe: errorPipe,
            arguments: arguments,
            verbose: verbose,
            timeout: timeout
        )
    }
}

public extension Shell {
    @discardableResult
    static func performShallowGitClone(
        workingDirectory: String? = FileManager.default.currentDirectoryPath,
        repositoryURLString: String,
        branchOrTag: String,
        verbose: Bool,
        timeout: TimeInterval? = 15
    ) throws -> Output {
        try Shell.run(
            "git clone --branch \(branchOrTag) --depth 1 \(repositoryURLString)",
            workingDirectory: workingDirectory,
            verbose: verbose,
            timeout: timeout
        )
    }
}

// MARK: - Private

private extension Shell {
    static func runProcess(
        workingDirectory: String?,
        outputPipe: Pipe,
        errorPipe: Pipe,
        arguments: [String],
        verbose: Bool,
        timeout: TimeInterval?
    ) throws -> Output {
        let process = Process.make(
            workingDirectory: workingDirectory,
            outputPipe: outputPipe,
            errorPipe: errorPipe,
            arguments: arguments,
            verbose: verbose
        )

        if verbose {
            Console.default.lineBreakAndWrite(
                .init(
                    text: "Running Shell command",
                    color: .yellow
                )
            )
        }

        var outputData = Data()
        var errorData = Data()

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        readData(
            from: outputPipe,
            isError: false,
            verbose: verbose,
            availableDataHandler: { availableData in
                outputData.append(availableData)
            },
            hasFinishedHandler: {
                dispatchGroup.leave()
            }
        )

        dispatchGroup.enter()
        readData(
            from: errorPipe,
            isError: true,
            verbose: verbose,
            availableDataHandler: { availableData in
                errorData.append(availableData)
            },
            hasFinishedHandler: {
                dispatchGroup.leave()
            }
        )

        // TODO: Move to async await and re-implement timeout

        try process.run()
        process.waitUntilExit()

        dispatchGroup.wait()

        if verbose {
            Console.default.lineBreakAndWrite(
                .init(
                    text: "Finished Shell command",
                    color: .yellow
                )
            )
        }

        return .init(
            succeeded: process.terminationStatus == 0,
            data: outputData,
            errorData: errorData
        )
    }

    static func readData(
        from pipe: Pipe,
        isError: Bool,
        verbose: Bool,
        availableDataHandler: ((Data) -> Void)?,
        hasFinishedHandler: (() -> Void)?
    ) {
        pipe.fileHandleForReading.readabilityHandler = { fileHandle in
            // readData(ofLength:) is used here to avoid unwanted performance side effects,
            // as described in the findings from:
            // https://stackoverflow.com/questions/49184623/nstask-race-condition-with-readabilityhandler-block
            let data = fileHandle.readData(ofLength: .max)

            if data.isEmpty == false {
                String(data: data, encoding: .utf8).map {
                    availableDataHandler?(data)
                    guard verbose else { return }

                    if isError {
                        Console.default.lineBreakAndWrite(
                            .init(
                                text: $0,
                                color: .red
                            )
                        )
                    } else {
                        Console.default.write(
                            .init(
                                text: $0,
                                hasLineBreakAfter: false
                            )
                        )
                    }
                }
            } else {
                pipe.fileHandleForReading.readabilityHandler = nil
                hasFinishedHandler?()
            }
        }
    }
}

extension Process {
    static func make(
        launchPath: String = "/usr/bin/env",
        workingDirectory: String? = FileManager.default.currentDirectoryPath,
        outputPipe: Pipe,
        errorPipe: Pipe,
        arguments: [String],
        verbose: Bool
    ) -> Process {
        let process = Process()
        process.launchPath = launchPath
        process.arguments = arguments
        process.standardError = errorPipe
        process.standardOutput = outputPipe
        process.qualityOfService = .userInteractive
        if let workingDirectory = workingDirectory {
            process.currentDirectoryPath = workingDirectory
        }
        return process
    }
}
