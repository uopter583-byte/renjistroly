import Foundation
import RenJistrolyModels
import Darwin

public actor TerminalTaskStore {
    private let store: FoundationStore
    private let fileName = "terminal-tasks.json"
    private let taskDirectory: URL

    public init(store: FoundationStore, taskDirectory: URL? = nil) {
        self.store = store
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Application Support")
        self.taskDirectory = taskDirectory ?? base
            .appending(path: "MacVoiceAssistant", directoryHint: .isDirectory)
            .appending(path: "TerminalTasks", directoryHint: .isDirectory)
    }

    public func all(limit: Int = 50) async -> [TerminalTaskRecord] {
        await refreshStatuses()
        let tasks = await store.load([TerminalTaskRecord].self, from: fileName, default: [])
        return Array(tasks.prefix(limit))
    }

    public func create(name: String, command: String, workingDirectory: String) async -> TerminalTaskRecord {
        var tasks = await store.load([TerminalTaskRecord].self, from: fileName, default: [])
        let id = UUID()
        let paths = taskPaths(for: id)
        let task = TerminalTaskRecord(
            id: id,
            name: name,
            command: command,
            workingDirectory: workingDirectory,
            status: .pending,
            lastMessage: "已创建，等待执行。",
            logPath: paths.log.path,
            exitCodePath: paths.exit.path,
            pidPath: paths.pid.path
        )
        tasks.insert(task, at: 0)
        await store.save(Array(tasks.prefix(200)), to: fileName)
        return task
    }

    public func start(id: UUID) async -> TerminalTaskRecord? {
        var tasks = await store.load([TerminalTaskRecord].self, from: fileName, default: [])
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return nil }
        var task = tasks[index]
        let paths = taskPaths(for: task.id)
        do {
            try FileManager.default.createDirectory(at: taskDirectory, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: paths.log.path, contents: nil)
            try? FileManager.default.removeItem(at: paths.exit)
            try? FileManager.default.removeItem(at: paths.pid)
            try task.command.write(toFile: paths.cmd.path, atomically: true, encoding: .utf8)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [
                "-lc",
                wrappedCommand(task.command, workingDirectory: task.workingDirectory, paths: paths)
            ]
            try process.run()

            task.status = .running
            task.pid = process.processIdentifier
            task.exitCode = nil
            task.logPath = paths.log.path
            task.exitCodePath = paths.exit.path
            task.pidPath = paths.pid.path
            task.outputTail = tail(path: paths.log.path)
            task.updatedAt = Date()
            task.lastMessage = "后台任务已启动，PID \(process.processIdentifier)。"
            tasks[index] = task
            await store.save(tasks, to: fileName)
            return task
        } catch {
            task.status = .failed
            task.updatedAt = Date()
            task.lastMessage = "启动失败：\(error.localizedDescription)"
            tasks[index] = task
            await store.save(tasks, to: fileName)
            return task
        }
    }

    public func restart(id: UUID) async -> TerminalTaskRecord? {
        _ = await stop(id: id)
        return await start(id: id)
    }

    public func stop(id: UUID) async -> TerminalTaskRecord? {
        var tasks = await store.load([TerminalTaskRecord].self, from: fileName, default: [])
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return nil }
        var task = tasks[index]
        if let pid = task.pid, isProcessAlive(pid) {
            _ = Darwin.kill(pid, SIGTERM)
            usleep(120_000)
            if isProcessAlive(pid) {
                _ = Darwin.kill(pid, SIGKILL)
            }
        }
        task.status = .cancelled
        task.updatedAt = Date()
        task.lastMessage = "已停止任务。"
        task.outputTail = task.logPath.flatMap(tail)
        tasks[index] = task
        await store.save(tasks, to: fileName)
        return task
    }

    public func markRunning(id: UUID, message: String) async {
        await update(id: id, status: .running, message: message)
    }

    public func markFailed(id: UUID, message: String) async {
        await update(id: id, status: .failed, message: message)
    }

    public func update(id: UUID, status: TerminalTaskStatus, message: String) async {
        var tasks = await store.load([TerminalTaskRecord].self, from: fileName, default: [])
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].status = status
        tasks[index].updatedAt = Date()
        tasks[index].lastMessage = message
        tasks[index].outputTail = tasks[index].logPath.flatMap(tail)
        await store.save(tasks, to: fileName)
    }

    public func refreshStatuses() async {
        var tasks = await store.load([TerminalTaskRecord].self, from: fileName, default: [])
        var changed = false
        for index in tasks.indices {
            var task = tasks[index]
            let paths = taskPaths(for: task.id)
            if let pidText = readTrimmed(paths.pid.path), let pid = Int32(pidText) {
                task.pid = pid
            }
            task.outputTail = tail(path: task.logPath ?? paths.log.path)
            if let codeText = readTrimmed(task.exitCodePath ?? paths.exit.path), let code = Int32(codeText) {
                task.exitCode = code
                task.status = code == 0 ? .succeeded : .failed
                task.lastMessage = code == 0 ? "任务完成，退出码 0。" : "任务失败，退出码 \(code)。"
                task.updatedAt = Date()
                changed = true
            } else if task.status == .running, let pid = task.pid, !isProcessAlive(pid) {
                task.status = .failed
                task.lastMessage = "进程已结束，但没有写入退出码。"
                task.updatedAt = Date()
                changed = true
            }
            if task != tasks[index] {
                tasks[index] = task
                changed = true
            }
        }
        if changed {
            await store.save(tasks, to: fileName)
        }
    }

    private func taskPaths(for id: UUID) -> (log: URL, exit: URL, pid: URL, cmd: URL) {
        let stem = id.uuidString
        return (
            taskDirectory.appending(path: "\(stem).log"),
            taskDirectory.appending(path: "\(stem).exit"),
            taskDirectory.appending(path: "\(stem).pid"),
            taskDirectory.appending(path: "\(stem).cmd")
        )
    }

    private func wrappedCommand(
        _ command: String,
        workingDirectory: String,
        paths: (log: URL, exit: URL, pid: URL, cmd: URL)
    ) -> String {
        let cwd = FileManager.default.fileExists(atPath: workingDirectory) ? workingDirectory : NSHomeDirectory()
        return """
        (
          echo $$ > \(shellQuoted(paths.pid.path))
          cd \(shellQuoted(cwd)) || exit 97
          {
            echo "[Mac Voice Assistant] cwd: \(cwd)"
            printf '[Mac Voice Assistant] command: '
            cat \(shellQuoted(paths.cmd.path))
            echo
            echo "[Mac Voice Assistant] started: $(date)"
            bash \(shellQuoted(paths.cmd.path))
            code=$?
            echo "[Mac Voice Assistant] exit: $code"
            echo "$code" > \(shellQuoted(paths.exit.path))
            exit $code
          } >> \(shellQuoted(paths.log.path)) 2>&1
        ) &
        """
    }

    private func isProcessAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return Darwin.kill(pid, 0) == 0
    }

    func tail(path: String) -> String? {
        guard FileManager.default.fileExists(atPath: path),
              let handle = FileHandle(forReadingAtPath: path)
        else { return nil }
        defer { try? handle.close() }
        let size = handle.seekToEndOfFile()
        let readSize = UInt64(min(4096, size))
        handle.seek(toFileOffset: size - readSize)
        let data = handle.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func readTrimmed(_ path: String) -> String? {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
