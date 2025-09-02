# 知识库功能使用指南

## 概述

知识库功能是一个完整的 RAG (Retrieval-Augmented Generation) 系统，支持多种向量数据库提供商，允许您创建、管理和使用自定义知识库来增强 AI 对话的准确性和相关性。

## 核心功能

### 1. 知识库管理

#### 创建知识库
- 点击"创建新知识库"按钮
- 填写知识库名称和描述
- 选择引擎类型：
  - **OpenAI Assistants API**: 使用 OpenAI 的向量嵌入服务
  - **Google Vertex AI**: 使用 Google 的 AI 服务
  - **Google Vertex AI Search**: 企业级 RAG 一站式选择，与 Google Cloud 生态无缝集成
  - **Pinecone**: 领先的商业化向量数据库，极高的检索性能和低延迟
  - **Algolia**: 传统搜索巨头，强大的向量搜索能力，支持混合搜索
  - **Elasticsearch/OpenSearch**: 功能极其强大，支持自托管和云服务
  - **自定义后端**: 连接自己的 LangChain/LlamaIndex 服务
- 配置相应的 API Key 或服务器地址
- 设置对话模型和嵌入模型

#### 知识库列表
- 显示所有已创建的知识库
- 每个知识库显示：
  - 名称和描述
  - 引擎类型（带颜色标识）
  - 文档数量和分块数量
  - 向量化状态（进度条显示）

### 2. 支持的向量数据库

#### Google Vertex AI Search
- **优点**: 与 Google Cloud 生态无缝集成，对非结构化数据（PDF, HTML）的处理能力极强，设置相对简单
- **适用场景**: 构建企业级 RAG 的一站式选择
- **配置要求**: API Key, 项目 ID, 地区, 数据存储 ID

#### Pinecone
- **优点**: 领先的商业化向量数据库服务商，以极高的检索性能和低延迟著称
- **适用场景**: AI 初创公司，需要高性能向量搜索的应用
- **配置要求**: API Key, 环境, 索引名称

#### Algolia
- **优点**: 传统的关键词搜索巨头，现在也提供了强大的向量搜索能力，特别擅长需要"混合搜索"（关键词 + 语义）的场景
- **适用场景**: 需要结合关键词和语义搜索的应用
- **配置要求**: 应用 ID, 搜索 API Key, 索引名称

#### Elasticsearch/OpenSearch
- **优点**: 功能极其强大，不仅限于向量搜索。可以通过云服务商（如 AWS, Elastic Cloud）使用，也可以自托管，提供了最大的灵活性
- **适用场景**: 需要复杂搜索功能的企业，有技术团队维护
- **配置要求**: 服务器地址, 索引名称, 用户名/密码（可选）

### 3. 文档上传与处理

#### 支持的文件格式
- **文档**: PDF, DOCX, DOC, TXT, MD
- **表格**: CSV, XLSX, XLS
- **演示**: PPTX, PPT

#### 文档处理流程
1. **文件选择**: 支持多文件批量上传
2. **内容提取**: 自动提取文本内容
3. **智能分块**: 
   - 最大块大小: 1000 字符
   - 重叠大小: 200 字符
   - 在句子边界智能分割
4. **向量化**: 生成文本嵌入向量
5. **存储**: 根据选择的向量数据库进行存储

### 4. 向量化处理

#### 自动向量化
- 上传文档后自动开始向量化
- 支持批量处理多个文档
- 实时显示处理进度

#### 向量存储
- 支持多种向量数据库
- 自动管理向量索引
- 支持相似度搜索和混合搜索

### 5. AI 对话集成

#### 知识库选择
- 在聊天页面的"知识库"标签页中选择要使用的知识库
- 支持动态切换不同知识库
- 显示知识库状态和统计信息

#### RAG 工作流程
1. **用户提问**: 输入问题
2. **向量检索**: 在知识库中搜索相关内容
3. **上下文增强**: 将检索结果添加到 AI 提示中
4. **智能回答**: AI 基于知识库内容生成准确回答

## 使用方法

### 步骤 1: 创建知识库
1. 进入"知识库"页面
2. 点击"+ 创建新知识库"
3. 填写基本信息并选择引擎类型
4. 根据引擎类型配置相应参数：
   - **OpenAI/Google**: 配置 API Key 和模型
   - **Vertex AI Search**: 配置项目 ID、地区、数据存储 ID
   - **Pinecone**: 配置 API Key、环境、索引名称
   - **Algolia**: 配置应用 ID、搜索 API Key、索引名称
   - **Elasticsearch**: 配置服务器地址、索引名称、认证信息

### 步骤 2: 上传文档
1. 在知识库列表中找到刚创建的知识库
2. 点击"上传文档"按钮（蓝色图标）
3. 选择要上传的文件
4. 等待文档处理和分块完成

### 步骤 3: 生成向量嵌入
1. 点击"生成向量嵌入"按钮（绿色图标）
2. 等待向量化处理完成
3. 查看处理状态和进度

### 步骤 4: 在对话中使用
1. 进入"聊天"页面
2. 在右侧面板的"知识库"标签页中选择知识库
3. 开始对话，AI 将自动使用知识库内容

## 技术架构

### 数据库设计
```sql
-- 知识库表
CREATE TABLE knowledge_bases (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  description TEXT,
  engine_type TEXT NOT NULL,
  engine_config TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 文档表
CREATE TABLE kb_documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kb_id INTEGER NOT NULL,
  title TEXT,
  source_path TEXT,
  mime_type TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(kb_id) REFERENCES knowledge_bases(id) ON DELETE CASCADE
);

-- 分块表
CREATE TABLE kb_chunks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kb_id INTEGER NOT NULL,
  doc_id INTEGER,
  chunk_index INTEGER,
  content TEXT NOT NULL,
  embedding BLOB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(kb_id) REFERENCES knowledge_bases(id) ON DELETE CASCADE,
  FOREIGN KEY(doc_id) REFERENCES kb_documents(id) ON DELETE CASCADE
);
```

### 服务架构
- **DocumentUploadService**: 文档上传和分块处理
- **EmbeddingService**: 向量嵌入生成和相似度计算
- **VectorDatabaseService**: 多种向量数据库的统一接口
- **RAGService**: RAG 工作流程管理
- **DatabaseService**: 数据持久化

### 支持的向量模型
- **OpenAI**: text-embedding-3-small, text-embedding-3-large
- **Google**: textembedding-gecko-001
- **自定义**: sentence-transformers/all-MiniLM-L6-v2

## 向量数据库选择指南

### 企业级应用
- **Google Vertex AI Search**: 如果已经在使用 Google Cloud，推荐选择
- **Elasticsearch**: 如果需要复杂的搜索功能和自托管能力

### 高性能要求
- **Pinecone**: 对检索性能和延迟有极高要求的应用
- **Algolia**: 需要混合搜索（关键词+语义）的场景

### 成本考虑
- **OpenAI**: 适合小规模应用，成本可控
- **自托管**: 适合有技术团队的企业，长期成本较低

### 易用性
- **Google Vertex AI Search**: 设置最简单，一站式服务
- **Pinecone**: 开发者友好，文档完善
- **Algolia**: 传统搜索巨头，生态成熟

## 最佳实践

### 文档准备
- 使用清晰的文档结构和标题
- 避免过于复杂的格式
- 确保文本内容的质量和准确性

### 分块策略
- 每个分块应包含完整的语义单元
- 避免在句子中间分割
- 适当的重叠有助于保持上下文连贯性

### 知识库管理
- 定期更新和维护知识库内容
- 监控向量化进度和状态
- 根据使用情况调整分块大小

### 向量数据库选择
- 根据应用规模和性能要求选择
- 考虑团队的技术能力和维护成本
- 评估与现有技术栈的集成难度

## 故障排除

### 常见问题
1. **文档上传失败**: 检查文件格式和大小
2. **向量化失败**: 验证 API 密钥和网络连接
3. **检索结果不准确**: 调整相似度阈值或重新向量化
4. **向量数据库连接失败**: 检查配置参数和网络设置

### 性能优化
- 合理设置分块大小
- 定期清理无用的向量数据
- 使用适当的相似度算法
- 根据数据量选择合适的向量数据库

## 未来计划

- [x] 支持多种向量数据库（OpenAI, Google, Pinecone, Algolia, Elasticsearch）
- [ ] 支持更多文件格式（图片、音频、视频）
- [ ] 集成更多向量数据库（Weaviate, Qdrant）
- [ ] 添加知识库版本管理
- [ ] 支持实时文档同步
- [ ] 添加知识库使用统计和分析
- [ ] 支持混合搜索（关键词+向量）
- [ ] 添加向量数据库性能监控

## 技术支持

如有问题或建议，请通过以下方式联系：
- 提交 Issue 到项目仓库
- 查看项目文档和示例
- 参与社区讨论
