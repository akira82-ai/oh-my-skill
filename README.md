# Oh My Skill

一个简洁优雅的 macOS 菜单栏应用，用于快速访问和运行 Claude CLI 技能。

## 功能

- 🧠 菜单栏快速访问：点击图标或使用全局快捷键
- ⌨️ 全局快捷键：默认 `Option+Space`，可在设置中自定义
- 🎨 沉浸式界面：无边框设计，流畅的视觉体验
  - 简洁的消息展示，无多余装饰
  - 柔和的半透明输入区域
  - 无缝衔接的布局
- 📝 聊天界面：与 Claude CLI 进行多轮对话
  - `Command+Enter` 快捷发送消息
  - 自动滚动到最新消息
  - 消息内容可选中复制
- 🔌 技能选择器：
  - 输入 `/` 快速浏览和选择可用技能
  - 流畅的滑入动画，列表显示在文本框上方
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

### 聊天界面快捷键
- `Command+Enter` - 发送消息

### 技能选择器快捷键
- `/` - 打开技能选择器
- `1-9, 0` - 直接选择对应编号的技能
- `↑ / ↓` - 上下导航选择技能
- `Enter` - 确认选择当前高亮的技能
- `Esc` - 关闭技能选择器

## 许可证

MIT License
