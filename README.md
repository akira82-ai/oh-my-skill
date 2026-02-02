# Oh My Skill

> 一个轻量级的 macOS SwiftUI App，作为 Claude Code Skills 的图形界面

## ✨ 特性

- 🎯 **两栏布局** - 左侧技能列表，右侧聊天界面
- 📁 **工作目录选择** - 启动时选择项目目录，Claude CLI 将在此目录下运行
- 💬 **多轮对话** - 支持连续对话，保持上下文
- ⚡ **流式响应** - 实时显示 AI 回复
- 🔍 **自动扫描** - 自动扫描 `~/.claude/skills` 目录

## 📸 截图

```
┌─────────────────┬──────────────────────────┐
│  Skills         │       Chat               │
│                 │                          │
│ • idea-to-post  │ AI: 你想写什么主题？     │
│ • code-review   │                          │
│ • explain-code  │ User: AI 技术趋势        │
│ ...             │                          │
│                 │ AI: 好的，技术趋势...     │
└─────────────────┴──────────────────────────┘
```

## 🚀 快速开始

### 前置要求

- macOS 13+
- Swift 5.9+
- Claude CLI 已安装
- `~/.claude/skills` 目录存在

### 构建

```bash
# 克隆仓库
git clone https://github.com/akira82-ai/oh-my-skill.git
cd oh-my-skill

# 构建项目
./build.sh

# 运行
open build/OhMySkill.app
```

## 📖 使用方法

1. **启动 App** → 弹出目录选择器
2. **选择项目目录** → Claude CLI 将在此目录下运行
3. **选择 Skill** → 从左侧列表中选择
4. **开始对话** → 多轮对话，保持上下文

## 📁 项目结构

```
oh-my-skill/
├── src/
│   └── main.swift       # 所有源代码（单文件，约580行）
├── Package.swift         # SPM 配置
├── build.sh             # 构建脚本
└── README.md
```

## 🔧 技术栈

- **语言**: Swift
- **框架**: SwiftUI
- **依赖**: Yams (YAML 解析)
- **构建**: Swift Package Manager
- **CLI 调用**: Process API

## 💡 工作原理

### 多轮对话实现

```bash
# 第一轮：创建新会话
claude -p "query"

# 第二轮及以后：继续会话
claude -c -p "query"
```

### Skills 解析

扫描 `~/.claude/skills/` 目录，解析 `SKILL.md` 中的 YAML Frontmatter：

```yaml
---
name: idea-to-post
description: 将零散灵感扩展为深度推文...
---
```

## 🐛 已知问题

- AskUserQuestion 在 CLI 模式下会自动降级为纯文本对话
- 关闭 App 后会清空聊天历史（暂不持久化）

## 📄 License

MIT

## 🙏 致谢

- [Claude Code](https://code.claude.com) - AI 编程助手
- [Yams](https://github.com/jpsim/Yams) - YAML 解析库
