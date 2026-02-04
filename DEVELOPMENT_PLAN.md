# Oh My Skill - 状态栏集成实现计划

## 需求概述

将 Oh My Skill 从标准窗口应用改造为**菜单栏应用**，支持**可自定义的全局快捷键**呼出/隐藏。

## 当前状态

| 功能 | 状态 | 说明 |
|------|------|------|
| 多轮对话 | ✅ 已实现 | ClaudeCLI 使用 `-c` 参数继续会话 |
| macOS 打包 | ✅ 已实现 | build.sh 创建完整 .app bundle |
| 状态栏集成 | ❌ 需要实现 | 当前使用 WindowGroup |
| 工作目录选择 | ✅ 已实现 | DirectoryPickerView |

## 实现方案

### 核心改动

将 `WindowGroup` 改为 `NSStatusItem` + `NSPopover` 模式，参考 SkillLauncher 项目的实现。

### 需要修改的文件

**唯一需要修改的文件**: `/Users/agiray/Desktop/github/oh-my-skill/src/main.swift`

### 新增依赖

需要在 `Package.swift` 中添加 HotKey 库：
```swift
.package(url: "https://github.com/soffes/HotKey.git", from: "0.2.0")
```

---

## 详细修改步骤

### 步骤 1: 修改 Package.swift

在 `dependencies` 数组中添加 HotKey 依赖。

### 步骤 2: 修改 main.swift

#### 2.1 添加导入

在文件顶部添加：
```swift
import AppKit
import HotKey
```

#### 2.2 添加快捷键设置管理

在 `// MARK: - Models` 部分后添加：

```swift
struct HotKeySetting: Codable {
    var key: String
    var modifiers: [String]

    static let `default` = HotKeySetting(key: "space", modifiers: ["option"])

    var description: String {
        let modSymbols = modifiers.map { $0.uppercased() }.joined(separator: "+")
        return "\(modSymbols)+\(key.uppercased())"
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
        default:
            // 单字符按键
            if string.count == 1, let char = string.first {
                return Key(Character(char).asciiValue ?? 0)
            }
            return nil
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
```

#### 2.3 添加设置菜单视图

在 `// MARK: - Views` 部分添加：

```swift
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
```

#### 2.4 添加 MenuBarManager 类

在 `// MARK: - Services` 部分后添加：

```swift
class MenuBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsPopover: NSPopover?
    private let hotKeyManager: HotKeyManager
    let workDirectory: URL

    @Published var isPopoverShown = false

    init(workDirectory: URL) {
        self.workDirectory = workDirectory
        self.hotKeyManager = HotKeyManager { [weak self] in
            self?.togglePopover()
        }
        super.init()
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
            popover?.contentSize = NSSize(width: 800, height: 600)
            popover?.behavior = .transient
            popover?.contentViewController = NSHostingController(
                rootView: MainView(vm: AppViewModel(workDirectory: workDirectory))
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
```

#### 2.5 修改 App 入口

替换现有的 `@main` 结构：

```swift
@main
struct OhMySkillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 空场景 - 我们通过 AppKit 管理窗口
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置为 accessory 应用（无 Dock 图标）
        NSApp.setActivationPolicy(.accessory)

        // 显示目录选择器
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
```

### 步骤 3: 更新 build.sh（可选）

如果需要代码签名支持，可在构建脚本末尾添加：
```bash
# 可选：代码签名
if [ -n "$CODE_SIGN_IDENTITY" ]; then
    codesign --force --deep --sign "$CODE_SIGN_IDENTITY" "$APP_BUNDLE"
fi
```

---

## 验证步骤

1. **构建应用**
   ```bash
   ./build.sh
   ```

2. **运行应用**
   ```bash
   open build/OhMySkill.app
   ```

3. **测试功能**
   - [ ] 应用启动后无 Dock 图标
   - [ ] 菜单栏显示 "brain" 图标
   - [ ] 点击图标显示菜单
   - [ ] 按 `Option+Space` (默认快捷键) 弹出/隐藏窗口
   - [ ] 菜单中选择 "设置..." 打开设置面板
   - [ ] 修改快捷键并保存
   - [ ] 新快捷键生效
   - [ ] 点击窗口外部自动关闭
   - [ ] 多轮对话正常工作

---

## 关键技术点

1. **NSStatusItem** - 创建菜单栏图标
2. **NSPopover** - 浮动窗口，点击外部自动关闭
3. **HotKey 库** - 全局快捷键支持
4. **setActivationPolicy(.accessory)** - 隐藏 Dock 图标
5. **UserDefaults** - 保存用户快捷键设置

---

## 文件变更汇总

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `Package.swift` | 修改 | 添加 HotKey 依赖 |
| `src/main.swift` | 修改 | 添加 HotKeyManager、MenuBarManager、SettingsView，修改 App 入口 |
| `build.sh` | 可选 | 添加代码签名支持 |

---

## 预计代码量

- 新增代码: ~280 行
  - HotKeySetting + HotKeyManager: ~100 行
  - SettingsView: ~80 行
  - MenuBarManager: ~80 行
  - AppDelegate 修改: ~20 行
- 修改代码: ~10 行
- 删除代码: ~20 行 (原有 WindowGroup 入口)
