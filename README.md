# Oh My Skill

一个轻量级的 macOS SwiftUI App，作为 Claude Code Skills 的图形界面。

## 特性

- 🎯 两栏布局：左侧技能列表，右侧聊天界面
- 📁 启动时选择项目目录
- 💬 多轮对话支持
- ⚡ 流式响应显示

## 构建

```bash
# 1. 构建项目
./build.sh

# 2. 运行
open build/OhMySkill.app
```

## 前置要求

- macOS 13+
- Swift 5.9+
- Claude CLI 已安装

## 项目结构

```
.
├── src/
│   └── main.swift      # 所有源代码（单文件）
├── Package.swift        # SPM 配置
├── build.sh             # 构建脚本
└── README.md
```

## 使用

1. 运行 App
2. 选择项目目录（Claude CLI 将在此目录下运行）
3. 从左侧选择一个 skill
4. 开始对话！
