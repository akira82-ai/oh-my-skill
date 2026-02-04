import SwiftUI
import AppKit
import HotKey

// MARK: - Models

struct HotKeySetting: Codable {
    var key: String
    var modifiers: [String]

    static let `default` = HotKeySetting(key: "space", modifiers: ["option"])

    var description: String {
        let modSymbols = modifiers.map { $0.uppercased() }.joined(separator: "+")
        return "\(modSymbols)+\(key.uppercased())"
    }
}

struct Skill: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let directory: String

    var displayName: String {
        name.replacingOccurrences(of: "-", with: " ").capitalized
    }
}

// MARK: - Services

class SkillScanner {
    private let skillsURL: URL

    init() {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        self.skillsURL = homeURL.appendingPathComponent(".claude/skills")
    }

    func scanSkills() -> [Skill] {
        var skills: [Skill] = []

        // 首先列出所有子目录
        guard let subdirectories = try? FileManager.default.contentsOfDirectory(
            at: skillsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            NSLog("[SkillScanner] 无法访问 skills 目录: \(skillsURL.path)")
            return skills
        }

        for subdirectory in subdirectories {
            guard subdirectory.hasDirectoryPath else { continue }

            let skillFile = subdirectory.appendingPathComponent("skill.md")
            guard FileManager.default.fileExists(atPath: skillFile.path) else { continue }

            let directoryName = subdirectory.lastPathComponent
            if let skill = parseSkillFile(at: skillFile, directory: directoryName) {
                NSLog("[SkillScanner] 解析成功: \(skill.name)")
                skills.append(skill)
            } else {
                NSLog("[SkillScanner] 解析失败: \(skillFile.path)")
            }
        }

        NSLog("[SkillScanner] 共找到 \(skills.count) 个技能")
        return skills.sorted { $0.name < $1.name }
    }

    private func parseSkillFile(at url: URL, directory: String) -> Skill? {
        guard let content = try? String(contentsOf: url) else {
            NSLog("[SkillScanner] 无法读取文件: \(url.path)")
            return nil
        }

        // 查找 front matter 的开始和结束
        let lines = content.components(separatedBy: .newlines)
        guard lines.first == "---" else {
            NSLog("[SkillScanner] 文件格式错误（缺少开始 ---）: \(url.path)")
            return nil
        }

        var name = ""
        var description = ""

        // 解析 front matter 行
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { break } // 遇到结束标记

            if trimmed.hasPrefix("name:") {
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    let valueStart = trimmed.index(after: colonIndex)
                    name = String(trimmed[valueStart...]).trimmingCharacters(in: .whitespaces)
                }
            } else if trimmed.hasPrefix("description:") {
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    let valueStart = trimmed.index(after: colonIndex)
                    description = String(trimmed[valueStart...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        guard !name.isEmpty else {
            NSLog("[SkillScanner] 未找到 name 字段: \(url.path)")
            return nil
        }

        NSLog("[SkillScanner] 解析成功: \(name) - \(description)")
        return Skill(id: UUID(), name: name, description: description.isEmpty ? "无描述" : description, directory: directory)
    }
}

class HotKeyManager: ObservableObject {
    @Published var setting: HotKeySetting {
        didSet {
            saveSetting()
            updateHotKey()
        }
    }

    private var hotKey: HotKey?
    private let onKeyDown: () -> Void

    init(onKeyDown: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.setting = Self.loadSetting()
        setupHotKey()
    }

    private static func loadSetting() -> HotKeySetting {
        guard let data = UserDefaults.standard.data(forKey: "hotKeySetting"),
              let setting = try? JSONDecoder().decode(HotKeySetting.self, from: data) else {
            return .default
        }
        return setting
    }

    private func saveSetting() {
        if let data = try? JSONEncoder().encode(setting) {
            UserDefaults.standard.set(data, forKey: "hotKeySetting")
        }
    }

    private func setupHotKey() {
        updateHotKey()
    }

    private func updateHotKey() {
        hotKey = nil

        guard let key = parseKey(setting.key),
              let modifiers = parseModifiers(setting.modifiers) else {
            return
        }

        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = onKeyDown
    }

    private func parseKey(_ string: String) -> Key? {
        switch string.lowercased() {
        case "space": return .space
        case "return", "enter": return .return
        case "tab": return .tab
        case "escape", "esc": return .escape
        case "a": return .a
        case "b": return .b
        case "c": return .c
        case "d": return .d
        case "e": return .e
        case "f": return .f
        case "g": return .g
        case "h": return .h
        case "i": return .i
        case "j": return .j
        case "k": return .k
        case "l": return .l
        case "m": return .m
        case "n": return .n
        case "o": return .o
        case "p": return .p
        case "q": return .q
        case "r": return .r
        case "s": return .s
        case "t": return .t
        case "u": return .u
        case "v": return .v
        case "w": return .w
        case "x": return .x
        case "y": return .y
        case "z": return .z
        case "0": return .zero
        case "1": return .one
        case "2": return .two
        case "3": return .three
        case "4": return .four
        case "5": return .five
        case "6": return .six
        case "7": return .seven
        case "8": return .eight
        case "9": return .nine
        default:
            return Key(string: string)
        }
    }

    private func parseModifiers(_ array: [String]) -> NSEvent.ModifierFlags? {
        var flags: NSEvent.ModifierFlags = []
        for mod in array {
            switch mod.lowercased() {
            case "command", "cmd": flags.insert(.command)
            case "option", "opt", "alt": flags.insert(.option)
            case "control", "ctrl": flags.insert(.control)
            case "shift": flags.insert(.shift)
            default: break
            }
        }
        return flags.isEmpty ? nil : flags
    }
}

// MARK: - ViewModels

class AppViewModel: ObservableObject {
    let workDirectory: URL
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSkillPicker = false
    @Published var selectedSkillIndex: Int? = nil
    @Published var availableSkills: [Skill] = []

    private let claudeCLI: ClaudeCLI
    private let skillScanner = SkillScanner()

    init(workDirectory: URL) {
        self.workDirectory = workDirectory
        self.claudeCLI = ClaudeCLI(workDirectory: workDirectory)
        loadSkills()
    }

    private func loadSkills() {
        availableSkills = skillScanner.scanSkills()
    }

    var filteredSkills: [Skill] {
        if inputText.isEmpty || !inputText.hasPrefix("/") {
            return []
        }

        let query = String(inputText.dropFirst()).lowercased()
        if query.isEmpty {
            return availableSkills
        }

        return availableSkills.filter { skill in
            skill.name.lowercased().contains(query) ||
            skill.description.lowercased().contains(query)
        }
    }

    func selectSkill(_ skill: Skill) {
        inputText = "/\(skill.name) "
        showSkillPicker = false
        selectedSkillIndex = nil
    }

    func handleKeyPress(_ key: String) -> Bool {
        guard showSkillPicker, !filteredSkills.isEmpty else { return false }

        switch key {
        case "escape":
            showSkillPicker = false
            selectedSkillIndex = nil
            return true

        case "up", "uparrow":
            if let currentIndex = selectedSkillIndex {
                selectedSkillIndex = max(0, currentIndex - 1)
            } else {
                selectedSkillIndex = 0
            }
            return true

        case "down", "downarrow":
            if let currentIndex = selectedSkillIndex {
                selectedSkillIndex = min(filteredSkills.count - 1, currentIndex + 1)
            } else {
                selectedSkillIndex = 0
            }
            return true

        case "return", "enter":
            if let index = selectedSkillIndex, index < filteredSkills.count {
                selectSkill(filteredSkills[index])
                selectedSkillIndex = nil
                return true
            }
            return false

        case "0":
            if filteredSkills.count >= 10 {
                selectSkill(filteredSkills[9])
                return true
            }

        case "1", "2", "3", "4", "5", "6", "7", "8", "9":
            let index = Int(key)! - 1
            if index < filteredSkills.count {
                selectSkill(filteredSkills[index])
                return true
            }

        default:
            break
        }

        return false
    }

    func sendMessage() {
        guard !inputText.isEmpty else { return }

        let userMessage = ChatMessage(role: "user", content: inputText)
        messages.append(userMessage)

        let prompt = inputText
        inputText = ""
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await claudeCLI.sendPrompt(prompt, continueConversation: !messages.isEmpty)
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", content: response))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
}

class ClaudeCLI {
    private let workDirectory: URL
    private var process: Process?
    private let claudePath: String

    init(workDirectory: URL) {
        self.workDirectory = workDirectory
        self.claudePath = Self.findClaudePath()
    }

    private static func findClaudePath() -> String {
        let possiblePaths = [
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude-cli"
        ]

        // 尝试常见路径
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                NSLog("[ClaudeCLI] 找到 claude: \(path)")
                return path
            }
        }

        NSLog("[ClaudeCLI] 使用默认路径")
        return "/opt/homebrew/bin/claude"
    }

    func sendPrompt(_ prompt: String, continueConversation: Bool) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            var arguments = [String]()

            if continueConversation {
                arguments.append("-c")
            }

            arguments.append("-p")
            arguments.append(prompt)

            NSLog("[ClaudeCLI] 执行: \(claudePath) \(arguments.joined(separator: " "))")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: claudePath)
            process.arguments = arguments
            process.currentDirectoryURL = workDirectory

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                self.process = process

                DispatchQueue.global(qos: .userInitiated).async {
                    var output = ""
                    let handle = pipe.fileHandleForReading
                    let data = handle.readDataToEndOfFile()
                    if let str = String(data: data, encoding: .utf8) {
                        output = str
                    }

                    process.waitUntilExit()
                    DispatchQueue.main.async {
                        if process.terminationStatus == 0 {
                            continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                        } else {
                            continuation.resume(throwing: ClaudeError.runtimeError(output))
                        }
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func cancel() {
        process?.terminate()
    }
}

enum ClaudeError: LocalizedError {
    case runtimeError(String)

    var errorDescription: String? {
        switch self {
        case .runtimeError(let message):
            return message
        }
    }
}

// MARK: - Views

struct SettingsView: View {
    @ObservedObject var hotKeyManager: HotKeyManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedKey = HotKeySetting.default.key
    @State private var optionModifier = true
    @State private var commandModifier = false
    @State private var controlModifier = false
    @State private var shiftModifier = false

    private let availableKeys = ["space", "return", "tab", "escape"]

    var body: some View {
        VStack(spacing: 20) {
            Text("设置")
                .font(.title)
                .fontWeight(.bold)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("全局快捷键")
                    .font(.headline)

                HStack(spacing: 12) {
                    Menu(selectedKey.uppercased()) {
                        ForEach(availableKeys, id: \.self) { key in
                            Button(key.uppercased()) {
                                selectedKey = key
                            }
                        }
                    }
                    .frame(width: 100)

                    Text("+")

                    Toggle("Option", isOn: $optionModifier)
                    Toggle("Command", isOn: $commandModifier)
                    Toggle("Control", isOn: $controlModifier)
                    Toggle("Shift", isOn: $shiftModifier)
                }

                Text("当前: \(preview)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            Spacer()

            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    saveSetting()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400, height: 300)
        .onAppear {
            loadCurrentSetting()
        }
    }

    private var preview: String {
        var mods: [String] = []
        if optionModifier { mods.append("Option") }
        if commandModifier { mods.append("Command") }
        if controlModifier { mods.append("Control") }
        if shiftModifier { mods.append("Shift") }
        return (mods + [selectedKey.uppercased()]).joined(separator: "+")
    }

    private func loadCurrentSetting() {
        selectedKey = hotKeyManager.setting.key
        optionModifier = hotKeyManager.setting.modifiers.contains("option")
        commandModifier = hotKeyManager.setting.modifiers.contains("command")
        controlModifier = hotKeyManager.setting.modifiers.contains("control")
        shiftModifier = hotKeyManager.setting.modifiers.contains("shift")
    }

    private func saveSetting() {
        var modifiers: [String] = []
        if optionModifier { modifiers.append("option") }
        if commandModifier { modifiers.append("command") }
        if controlModifier { modifiers.append("control") }
        if shiftModifier { modifiers.append("shift") }

        hotKeyManager.setting = HotKeySetting(key: selectedKey, modifiers: modifiers)
        dismiss()
    }
}

struct SimpleSkillRowView: View {
    let skill: Skill
    let index: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 18, height: 18)

                Text("\(index)")
                    .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : .secondary)
            }

            Text(skill.name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .primary : .secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
    }
}

struct SkillPickerView: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(vm.filteredSkills.enumerated()), id: \.element.id) { index, skill in
                    SimpleSkillRowView(
                        skill: skill,
                        index: index + 1,
                        isSelected: vm.selectedSkillIndex == index
                    )
                    .onTapGesture {
                        vm.selectSkill(skill)
                    }
                    .id("skill-\(index)")  // 用于滚动定位
                }
            }
            .scrollPosition(id: Binding(
                get: { vm.selectedSkillIndex.map { "skill-\($0)" } },
                set: { _ in }
            ))
        }
        .frame(height: min(150, CGFloat(vm.filteredSkills.count * 28)))  // 动态高度，最大 150px
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(6)
        .shadow(radius: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

struct SkillRowView: View {
    let skill: Skill
    let index: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)

                Text("\(index % 10)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isSelected ? .white : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(skill.displayName)
                    .font(.system(size: 13, weight: .semibold))

                Text(skill.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

struct MainView: View {
    @StateObject var vm: AppViewModel
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.messages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        if let lastMessage = vm.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                VStack(spacing: 4) {
                    // 技能列表在上方
                    if vm.showSkillPicker && !vm.filteredSkills.isEmpty {
                        SkillPickerView(vm: vm)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // 文本输入区域在下方
                    HStack(spacing: 8) {
                        TextEditor(text: $vm.inputText)
                            .focused($isInputFocused)
                            .frame(height: 80)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .border(Color.black, width: 1)
                            .onChange(of: vm.inputText) { oldValue, newValue in
                                if newValue.hasPrefix("/") && !oldValue.hasPrefix("/") {
                                    vm.showSkillPicker = true
                                    vm.selectedSkillIndex = nil
                                } else if !newValue.hasPrefix("/") && vm.showSkillPicker {
                                    vm.showSkillPicker = false
                                    vm.selectedSkillIndex = nil
                                }
                            }
                            .onKeyPress { keyPress in
                                if vm.handleKeyPress(keyPress.characters) {
                                    return .handled
                                }
                                return .ignored
                            }
                            .padding(4)

                        if vm.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button(action: vm.sendMessage) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.inputText.isEmpty)
                        }
                    }
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.showSkillPicker)
            }
            .frame(minWidth: 500, minHeight: 400)
            .alert("错误", isPresented: Binding<Bool>(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            ), presenting: vm.errorMessage) { error in
                Button("确定") { }
            } message: { error in
                Text(error)
            }
        }
        .onAppear {
            isInputFocused = true
        }
    }
}

struct MessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: message.role == "user" ? "person.circle" : "brain")
                .font(.title3)
                .foregroundColor(message.role == "user" ? .blue : .purple)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == "user" ? "你" : "Claude")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text(message.content)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - MenuBarManager

class MenuBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsPopover: NSPopover?
    private var hotKeyManager: HotKeyManager!
    let workDirectory: URL

    @Published var isPopoverShown = false

    init(workDirectory: URL) {
        self.workDirectory = workDirectory
        super.init()
        self.hotKeyManager = HotKeyManager { [weak self] in
            self?.togglePopover()
        }
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "brain", accessibilityDescription: "Oh My Skill")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示", action: #selector(showPopover), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "隐藏", action: #selector(hidePopover), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
    }

    @objc func togglePopover() {
        if isPopoverShown {
            hidePopover()
        } else {
            showPopover()
        }
    }

    @objc func showPopover() {
        guard let button = statusItem?.button else { return }

        if popover == nil {
            popover = NSPopover()
            popover?.contentSize = NSSize(width: 600, height: 500)
            popover?.behavior = .transient
            let vm = AppViewModel(workDirectory: self.workDirectory)
            popover?.contentViewController = NSHostingController(
                rootView: MainView(vm: vm)
            )
        }

        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isPopoverShown = true
    }

    @objc func hidePopover() {
        popover?.performClose(nil)
        isPopoverShown = false
    }

    @objc func showSettings() {
        guard let button = statusItem?.button else { return }

        if settingsPopover == nil {
            settingsPopover = NSPopover()
            settingsPopover?.contentSize = NSSize(width: 400, height: 300)
            settingsPopover?.behavior = .transient
            settingsPopover?.contentViewController = NSHostingController(
                rootView: SettingsView(hotKeyManager: hotKeyManager)
            )
        }

        settingsPopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - App

@main
struct OhMySkillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        showDirectoryPicker()
    }

    func showDirectoryPicker() {
        let alert = NSAlert()
        alert.messageText = "选择项目目录"
        alert.informativeText = "请选择 Claude CLI 将要运行的工作目录"
        alert.addButton(withTitle: "选择")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false

            if panel.runModal() == .OK, let url = panel.url {
                menuBarManager = MenuBarManager(workDirectory: url)
            }
        }
    }
}
