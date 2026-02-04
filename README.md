# Oh My Skill

一个简单的 macOS 菜单栏应用，用于快速访问和运行 Claude CLI 技能。

## 功能

- 🧠 菜单栏快速访问：点击图标或使用全局快捷键
- ⌨️ 全局快捷键：默认 `Option+Space`，可在设置中自定义
- 📝 聊天界面：与 Claude CLI 进行交互
  - 固定 5 行高度的文本输入框，内容超出自动滚动
- 🔌 技能选择器：
  - 输入 `/` 快速浏览和选择可用技能
  - 由下至上滑入动画，列表显示在文本框上方
  - 键盘快捷键：`1-9,0` 直接选择，`↑↓` 导航，`Enter` 确认
- 📁 工作目录：启动时选择 Claude CLI 的工作目录

## 安装

```bash
# 克隆仓库
git clone https://github.com/yourusername/oh-my-skill.git
cd oh-my-skill

# 构建应用
swift build

# 或使用构建脚本
./build.sh
```

## 使用

1. 首次启动时，选择 Claude CLI 的工作目录
2. 菜单栏会出现 🧠 图标
3. 点击图标或按 `Option+Space` 打开聊天界面
4. 输入消息与 Claude 交互，或输入 `/` 查看可用技能

## 技能

应用会自动扫描 `~/.claude/skills/` 目录下的技能。每个技能需要一个 `skill.md` 文件：

```yaml
---
name: skill-name
description: 技能描述
---

技能详细说明...
```

## 系统要求

- macOS 13.0+
- Xcode Command Line Tools
- Claude CLI

## 快捷键

### 全局快捷键
- `Option+Space` - 打开/关闭聊天窗口
- `,` - 打开设置

### 技能选择器快捷键
- `/` - 打开技能选择器
- `1-9, 0` - 直接选择对应编号的技能
- `↑ / ↓` - 上下导航选择技能
- `Enter` - 确认选择当前高亮的技能
- `Esc` - 关闭技能选择器

## 许可证

MIT License
