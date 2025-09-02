# Admin Copilot - AI 智能助手管理平台

[![Flutter](https://img.shields.io/badge/Flutter-3.7.2+-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.7.2+-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🚀 项目简介

**Admin Copilot** 是一个基于 Flutter 构建的跨平台 AI 智能助手管理平台，专为企业级用户和管理员设计。该平台集成了多种主流 AI 模型提供商，支持智能对话、知识库管理、工作流自动化等核心功能。

## ✨ 核心特性

### 🤖 AI 智能代理
- **多类型代理**: 客户服务、内容创作、数据分析、代码助手、研究助手等
- **智能配置**: 支持自定义系统提示词、模型参数调优
- **状态管理**: 实时监控代理运行状态、性能指标
- **多模型支持**: 支持 OpenAI、Claude、Gemini、通义千问等主流模型

### 💬 智能对话系统
- **多模态输入**: 支持文本、文件上传、图片等多种输入方式
- **文件处理**: 自动解析 Word、PDF、JSON、代码文件等格式
- **对话管理**: 自动生成对话标题、支持消息编辑重发
- **历史记录**: 完整的对话历史保存和检索

### 🗄️ 知识库管理
- **多格式支持**: 支持文档、图片、代码等多种文件类型
- **智能向量化**: 基于嵌入技术的语义搜索
- **RAG 增强**: 检索增强生成，提升回答准确性
- **批量处理**: 支持大规模文档批量导入和处理

### 🔧 模型提供商管理
- **全球覆盖**: 支持国际主流 AI 服务商
- **中国本土**: 集成通义千问、文心一言、混元等国内服务
- **本地部署**: 支持 Ollama 等本地模型部署
- **统一接口**: 标准化的 API 调用接口

### 📊 系统监控
- **实时日志**: 完整的系统操作日志记录
- **性能监控**: API 调用时间、Token 消耗统计
- **错误追踪**: 详细的错误信息和异常处理
- **用户行为**: 用户操作行为分析和统计

## 🏗️ 技术架构

### 前端技术栈
- **Flutter 3.7.2+**: 跨平台 UI 框架
- **Dart 3.7.2+**: 现代化编程语言
- **Provider**: 状态管理解决方案
- **Material Design**: 现代化 UI 设计规范

### 后端服务
- **SQLite**: 本地数据存储
- **HTTP Client**: RESTful API 调用
- **文件处理**: 多格式文档解析
- **向量计算**: 语义相似度计算

### 核心服务
- **AI Agent Service**: AI 代理运行和管理
- **File Upload Service**: 文件上传和处理
- **RAG Service**: 检索增强生成
- **Database Service**: 数据持久化
- **Log Service**: 系统日志管理

## 📱 支持平台

- **macOS**: 原生支持，完整功能
- **Windows**: 跨平台兼容
- **Linux**: 跨平台兼容
- **iOS**: 移动端支持
- **Android**: 移动端支持
- **Web**: 浏览器端支持

## 🚀 快速开始

### 环境要求
- Flutter 3.7.2 或更高版本
- Dart 3.7.2 或更高版本
- 支持的操作系统（推荐 macOS）

### 安装步骤

1. **克隆项目**
```bash
git clone https://github.com/your-username/admin_copilot.git
cd admin_copilot
```

2. **安装依赖**
```bash
flutter pub get
```

3. **运行应用**
```bash
# macOS
flutter run -d macos

# Windows
flutter run -d windows

# Linux
flutter run -d linux

# iOS 模拟器
flutter run -d ios

# Android 模拟器
flutter run -d android
```

### 配置说明

1. **模型提供商配置**
   - 在"模型供应商"页面添加您的 API 密钥
   - 支持 OpenAI、Claude、Gemini、通义千问等

2. **AI 代理创建**
   - 在"AI 代理"页面创建自定义代理
   - 配置系统提示词和模型参数

3. **知识库设置**
   - 上传文档和资料
   - 配置向量化引擎参数

## 📖 使用指南

### 开始对话
1. 点击"开始对话"菜单
2. 选择要使用的 AI 代理
3. 输入问题或上传文件
4. 获得 AI 智能回答

### 管理 AI 代理
1. 进入"AI 代理"页面
2. 创建新的代理或编辑现有代理
3. 配置代理类型、提示词和模型
4. 测试代理功能

### 知识库管理
1. 访问"知识库"页面
2. 创建新的知识库
3. 上传相关文档
4. 等待向量化处理完成

## 🔧 开发指南

### 项目结构
```
lib/
├── main.dart                 # 应用入口
├── models/                   # 数据模型
│   ├── ai_agent.dart        # AI 代理模型
│   ├── model_provider.dart  # 模型提供商
│   └── knowledge_base.dart  # 知识库模型
├── pages/                    # 页面组件
│   ├── chat_page.dart       # 聊天页面
│   ├── ai_agents_page.dart  # AI 代理管理
│   └── settings_page.dart   # 设置页面
├── services/                 # 业务服务
│   ├── ai_agent_service.dart    # AI 代理服务
│   ├── file_upload_service.dart # 文件上传服务
│   └── rag_service.dart         # RAG 服务
└── widgets/                  # 通用组件
```

### 添加新功能
1. 在 `models/` 目录定义数据模型
2. 在 `services/` 目录实现业务逻辑
3. 在 `pages/` 目录创建用户界面
4. 更新路由和导航配置

### 代码规范
- 遵循 Flutter 官方代码规范
- 使用 Provider 进行状态管理
- 实现完整的错误处理
- 添加详细的代码注释

## 🤝 贡献指南

我们欢迎所有形式的贡献！请遵循以下步骤：

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [Flutter](https://flutter.dev/) - 跨平台 UI 框架
- [Provider](https://pub.dev/packages/provider) - 状态管理
- [SQLite](https://www.sqlite.org/) - 本地数据库
- 所有贡献者和用户的支持

## 📞 联系我们

- 项目主页: [GitHub Repository](https://github.com/your-username/admin_copilot)
- 问题反馈: [Issues](https://github.com/your-username/admin_copilot/issues)
- 功能建议: [Discussions](https://github.com/your-username/admin_copilot/discussions)

---

**Admin Copilot** - 让 AI 管理更简单，让智能助手更强大！ 🚀
