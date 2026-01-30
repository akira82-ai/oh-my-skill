import SwiftUI
import Yams

// MARK: - Models

struct Skill: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
}

class Message: Identifiable {
    let id = UUID()
    let role: MessageRole
    var content: String
    let timestamp = Date()

    init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
    }
}

enum MessageRole {
    case user
    case assistant
}

// MARK: - Services

class SkillScanner {
    private let skillsDirectory: URL

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        skillsDirectory = homeDir.appendingPathComponent(".claude/skills")
    }

    func scan() -> [Skill] {
        guard FileManager.default.fileExists(atPath: skillsDirectory.path) else {
            return []
        }

        do {
            let subdirectories = try FileManager.default.contentsOfDirectory(
                at: skillsDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            var skills: [Skill] = []
            for subdir in subdirectories {
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: subdir.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    continue
                }

                let skillFile = subdir.appendingPathComponent("SKILL.md")
                guard FileManager.default.fileExists(atPath: skillFile.path) else {
                    continue
                }

                if let skill = parseSkill(from: skillFile) {
                    skills.append(skill)
                }
            }

            return skills.sorted { $0.name < $1.name }
        } catch {
            return []
        }
    }

    private func parseSkill(from file: URL) -> Skill? {
        guard let content = try? String(contentsOf: file, encoding: .utf8) else {
            return nil
        }

        guard let frontmatter = parseFrontmatter(from: content) else {
            return nil
        }

        let name = frontmatter["name"] ?? file.deletingLastPathComponent().lastPathComponent
        let description = frontmatter["description"] ?? "No description"

        return Skill(id: name, name: name, description: description)
    }

    private func parseFrontmatter(from content: String) -> [String: String]? {
        let pattern = "^---\\n([\\s\\S]*?)\\n---"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else {
            return nil
        }

        let range = NSRange(content.startIndex..., in: content)
        guard let match = regex.firstMatch(in: content, options: [], range: range),
              let frontmatterRange = Range(match.range(at: 1), in: content) else {
            return nil
        }

        let frontmatter = String(content[frontmatterRange])

        guard let yaml = try? Yams.compose(yaml: frontmatter),
              let mapping = yaml.mapping else {
            return nil
        }

        var result: [String: String] = [:]
        for (keyNode, valueNode) in mapping {
            if let keyName = keyNode.string,
               let keyValue = valueNode.string {
                result[keyName] = keyValue
            }
        }

        return result
    }
}

class ClaudeCLI: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isProcessing = false
    @Published var pendingQuestions: [String: String] = [:]  // 存储待回答的问题 {header: question}
    @Published var inputPlaceholder: String = ""  // 预填充的输入框文本

    private var sessionID = UUID().uuidString
    private let workDirectory: URL
    private var currentProcess: Process?
    private var outputBuffer = ""
    private var processedMessageIds = Set<String>()  // 跟踪已处理的 message id

    init(workDirectory: URL) {
        self.workDirectory = workDirectory
    }

    func send(_ text: String, skill: Skill?) {
        // 清空已处理的消息 id，准备接收新的响应
        processedMessageIds.removeAll()

        let userMessage = Message(role: .user, content: text)
        DispatchQueue.main.async {
            self.messages.append(userMessage)
            self.isProcessing = true
        }

        let arguments = buildArguments(skill: skill)
        guard let process = createProcess(arguments: arguments) else {
            DispatchQueue.main.async {
                self.isProcessing = false
            }
            return
        }

        currentProcess = process

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            if !data.isEmpty {
                self.processOutput(data: data)
            }
        }

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async {
                self.isProcessing = false
            }
            return
        }

        if let inputData = formatInput(text, skill: skill).data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(inputData)
            inputPipe.fileHandleForWriting.closeFile()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            process.waitUntilExit()
            DispatchQueue.main.async {
                self.isProcessing = false
                self.currentProcess = nil
            }
        }
    }

    private func buildArguments(skill: Skill?) -> [String] {
        return [
            "-p",
            "--output-format", "stream-json",
            "--verbose",
            "--session-id", sessionID
        ]
    }

    private func formatInput(_ text: String, skill: Skill?) -> String {
        if let skill = skill {
            return "/\(skill.name) \(text)"
        }
        return text
    }

    private func createProcess(arguments: [String]) -> Process? {
        let possiblePaths = [
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "~/.local/bin/claude"
        ]

        var executableURL: URL?
        for path in possiblePaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)
            if FileManager.default.fileExists(atPath: url.path) {
                executableURL = url
                break
            }
        }

        guard let executableURL = executableURL else {
            return nil
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = workDirectory

        return process
    }

    private func processOutput(data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }

        outputBuffer += text

        let lines = outputBuffer.components(separatedBy: "\n")
        outputBuffer = lines.last ?? ""

        for line in lines.dropLast() {
            parseAndHandleLine(line)
        }
    }

    private func parseAndHandleLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        // 调试：打印所有收到的 JSON 类型
        if type != "system" {
            print("📥 收到: \(type)")
        }

        switch type {
        case "assistant":
            // 解析 assistant 消息: {"type":"assistant","message":{"content":[...]}}
            if let message = json["message"] as? [String: Any],
               let messageId = message["id"] as? String {

                // 检查是否已经处理过这条消息
                if processedMessageIds.contains(messageId) {
                    return  // 跳过已处理的消息
                }
                processedMessageIds.insert(messageId)

                guard let content = message["content"] as? [[String: Any]] else {
                    return
                }

                // 检查是否有 AskUserQuestion
                var hasAskUserQuestion = false

                for item in content {
                    if let itemType = item["type"] as? String,
                       itemType == "tool_use",
                       let name = item["name"] as? String,
                       name == "AskUserQuestion",
                       let input = item["input"] as? [String: Any] {
                        hasAskUserQuestion = true
                        handleToolUse(name: name, input: input)
                        break  // 只处理第一个 AskUserQuestion
                    }
                }

                // 如果没有 AskUserQuestion，才显示普通文本
                if !hasAskUserQuestion {
                    for item in content {
                        if let itemType = item["type"] as? String,
                           itemType == "text",
                           let text = item["text"] as? String,
                           !text.isEmpty {  // 跳过空文本
                            appendAssistantMessage(text)
                        }
                    }
                }
            }

        case "result":
            // 解析最终结果: {"type":"result","result":"..."}
            if let result = json["result"] as? String {
                appendNewAssistantMessage(result)
            }

        case "content_delta":
            // 流式内容增量
            if let delta = json["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                appendAssistantMessage(text)
            }

        case "error":
            if let error = json["error"] as? String {
                print("Claude error: \(error)")
            }

        default:
            break
        }
    }

    private func handleToolUse(name: String, input: [String: Any]) {
        print("🔧 工具调用: \(name)")

        if name == "AskUserQuestion" {
            // AskUserQuestion 在 CLI 模式下无法得到有效响应
            // AI 会自动降级为纯文本对话
            // 我们需要清空待回答问题，等待下一个文本响应
            DispatchQueue.main.async {
                self.pendingQuestions = [:]
                self.inputPlaceholder = ""
            }
        }
    }

    private func appendAssistantMessage(_ content: String) {
        DispatchQueue.main.async {
            if let lastMessage = self.messages.last,
               lastMessage.role == .assistant {
                lastMessage.content += content
            } else {
                let assistantMessage = Message(role: .assistant, content: content)
                self.messages.append(assistantMessage)
            }
        }
    }

    private func appendNewAssistantMessage(_ content: String) {
        DispatchQueue.main.async {
            let assistantMessage = Message(role: .assistant, content: content)
            self.messages.append(assistantMessage)
        }
    }
}

class AppViewModel: ObservableObject {
    @Published var skills: [Skill] = []
    @Published var selectedSkill: Skill?
    @Published var claude: ClaudeCLI
    @Published var workDirectory: URL

    init(workDirectory: URL) {
        self.workDirectory = workDirectory
        self.claude = ClaudeCLI(workDirectory: workDirectory)
        self.skills = SkillScanner().scan()
    }
}

// MARK: - Views

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.role == .user ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(12)

                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 400, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer()
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ChatView: View {
    @ObservedObject var viewModel: ClaudeCLI
    var skill: Skill?
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            if let skill = skill {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(skill.name).font(.headline)
                        Text(skill.description).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    if viewModel.isProcessing {
                        ProgressView().scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
            } else {
                HStack {
                    Text("选择一个技能开始对话").foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
            }

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message).id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                TextEditor(text: $input)
                    .frame(minHeight: 60, maxHeight: 150)
                    .textFieldStyle(.plain)
                    .disabled(viewModel.isProcessing)
                    .font(.system(.body, design: .monospaced))

                VStack(spacing: 8) {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(input.isEmpty || viewModel.isProcessing ? .secondary : .blue)
                    }
                    .disabled(input.isEmpty || viewModel.isProcessing)

                    Button(action: clearInput) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private func sendMessage() {
        guard !input.isEmpty else { return }
        viewModel.send(input, skill: skill)
        input = ""
    }

    private func clearInput() {
        input = ""
    }
}

struct MainView: View {
    @StateObject var vm: AppViewModel

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Skills").font(.headline)
                    Spacer()
                    Text("\(vm.skills.count)").font(.caption).foregroundColor(.secondary)
                }
                .padding()

                Divider()

                List(vm.skills, selection: $vm.selectedSkill) { skill in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(skill.name).font(.headline)
                        Text(skill.description).font(.caption).foregroundColor(.secondary).lineLimit(2)
                    }
                    .padding(4)
                    .tag(skill)
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 200, maxWidth: 300)
        } detail: {
            ChatView(viewModel: vm.claude, skill: vm.selectedSkill)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct DirectoryPickerView: View {
    @State private var selectedDirectory: URL?
    @State private var showPicker = false
    let onDirectorySelected: (URL) -> Void

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("选择项目目录")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Claude CLI 将在此目录下运行")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            if let directory = selectedDirectory {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("已选择").foregroundColor(.secondary)
                    Text(directory.path)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                }
            }

            Button(action: { showPicker = true }) {
                HStack {
                    Image(systemName: "folder")
                    Text(selectedDirectory == nil ? "选择目录" : "更换目录")
                }
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(selectedDirectory == nil ? Color.blue : Color.accentColor)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()

            if let directory = selectedDirectory {
                Button(action: { onDirectorySelected(directory) }) {
                    HStack {
                        Text("开始使用").fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(40)
        .frame(width: 500, height: 400)
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                _ = url.startAccessingSecurityScopedResource()
                selectedDirectory = url
            }
        }
    }
}

// MARK: - App

@main
struct OhMySkillApp: App {
    @State private var workDirectory: URL?

    var body: some Scene {
        WindowGroup {
            RootView(workDirectory: $workDirectory)
        }
    }
}

struct RootView: View {
    @Binding var workDirectory: URL?

    var body: some View {
        if let workDirectory = workDirectory {
            MainView(vm: AppViewModel(workDirectory: workDirectory))
        } else {
            DirectoryPickerView { directory in
                self.workDirectory = directory
            }
            .frame(minWidth: 500, minHeight: 400)
        }
    }
}
