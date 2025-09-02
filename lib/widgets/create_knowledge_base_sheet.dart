import 'package:flutter/material.dart';
import '../models/knowledge_base.dart';
import '../services/database_service.dart';

class CreateKnowledgeBaseSheet extends StatefulWidget {
  final VoidCallback? onCreated;

  const CreateKnowledgeBaseSheet({super.key, this.onCreated});

  @override
  State<CreateKnowledgeBaseSheet> createState() => _CreateKnowledgeBaseSheetState();
}

class _CreateKnowledgeBaseSheetState extends State<CreateKnowledgeBaseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _llmModelController = TextEditingController();
  final _embeddingModelController = TextEditingController();
  
  // Google Vertex AI Search 配置
  final _projectIdController = TextEditingController();
  final _locationController = TextEditingController();
  final _dataStoreIdController = TextEditingController();
  
  // Pinecone 配置
  final _pineconeApiKeyController = TextEditingController();
  final _pineconeEnvironmentController = TextEditingController();
  final _pineconeIndexNameController = TextEditingController();
  
  // Algolia 配置
  final _algoliaAppIdController = TextEditingController();
  final _algoliaSearchKeyController = TextEditingController();
  final _algoliaIndexNameController = TextEditingController();
  
  // Elasticsearch 配置
  final _elasticsearchUrlController = TextEditingController();
  final _elasticsearchUsernameController = TextEditingController();
  final _elasticsearchPasswordController = TextEditingController();
  final _elasticsearchIndexNameController = TextEditingController();

  KnowledgeBaseEngineType _selectedEngine = KnowledgeBaseEngineType.openai;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _llmModelController.text = 'gpt-4o';
    _embeddingModelController.text = 'text-embedding-3-small';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _apiKeyController.dispose();
    _serverUrlController.dispose();
    _llmModelController.dispose();
    _embeddingModelController.dispose();
    _projectIdController.dispose();
    _locationController.dispose();
    _dataStoreIdController.dispose();
    _pineconeApiKeyController.dispose();
    _pineconeEnvironmentController.dispose();
    _pineconeIndexNameController.dispose();
    _algoliaAppIdController.dispose();
    _algoliaSearchKeyController.dispose();
    _algoliaIndexNameController.dispose();
    _elasticsearchUrlController.dispose();
    _elasticsearchUsernameController.dispose();
    _elasticsearchPasswordController.dispose();
    _elasticsearchIndexNameController.dispose();
    super.dispose();
  }

  void _onEngineChanged(KnowledgeBaseEngineType? value) {
    if (value != null) {
      setState(() {
        _selectedEngine = value;
        // 清空相关字段
        _apiKeyController.clear();
        _serverUrlController.clear();
        _projectIdController.clear();
        _locationController.clear();
        _dataStoreIdController.clear();
        _pineconeApiKeyController.clear();
        _pineconeEnvironmentController.clear();
        _pineconeIndexNameController.clear();
        _algoliaAppIdController.clear();
        _algoliaSearchKeyController.clear();
        _algoliaIndexNameController.clear();
        _elasticsearchUrlController.clear();
        _elasticsearchUsernameController.clear();
        _elasticsearchPasswordController.clear();
        _elasticsearchIndexNameController.clear();
        
        // 设置默认值
        switch (value) {
          case KnowledgeBaseEngineType.openai:
            _llmModelController.text = 'gpt-4o';
            _embeddingModelController.text = 'text-embedding-3-small';
            break;
          case KnowledgeBaseEngineType.google:
            _llmModelController.text = 'gemini-pro';
            _embeddingModelController.text = 'textembedding-gecko-001';
            break;
          case KnowledgeBaseEngineType.vertexAiSearch:
            _llmModelController.text = 'gemini-pro';
            _embeddingModelController.text = 'textembedding-gecko-001';
            _locationController.text = 'us-central1';
            break;
          case KnowledgeBaseEngineType.pinecone:
            _llmModelController.text = 'gpt-4o';
            _embeddingModelController.text = 'text-embedding-3-small';
            _pineconeEnvironmentController.text = 'gcp-starter';
            break;
          case KnowledgeBaseEngineType.algolia:
            _llmModelController.text = 'gpt-4o';
            _embeddingModelController.text = 'text-embedding-3-small';
            break;
          case KnowledgeBaseEngineType.elasticsearch:
            _llmModelController.text = 'gpt-4o';
            _embeddingModelController.text = 'text-embedding-3-small';
            _elasticsearchUrlController.text = 'http://localhost:9200';
            break;
          case KnowledgeBaseEngineType.custom:
            _llmModelController.text = 'llama-2-7b';
            _embeddingModelController.text = 'sentence-transformers/all-MiniLM-L6-v2';
            break;
        }
      });
    }
  }

  Future<void> _createKnowledgeBase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final engineConfig = KnowledgeBaseEngineConfig(
        engineType: _selectedEngine,
        apiKey: _apiKeyController.text.isNotEmpty ? _apiKeyController.text : null,
        serverUrl: _serverUrlController.text.isNotEmpty ? _serverUrlController.text : null,
        llmModel: _llmModelController.text,
        embeddingModel: _embeddingModelController.text,
        projectId: _projectIdController.text.isNotEmpty ? _projectIdController.text : null,
        location: _locationController.text.isNotEmpty ? _locationController.text : null,
        dataStoreId: _dataStoreIdController.text.isNotEmpty ? _dataStoreIdController.text : null,
        pineconeApiKey: _pineconeApiKeyController.text.isNotEmpty ? _pineconeApiKeyController.text : null,
        pineconeEnvironment: _pineconeEnvironmentController.text.isNotEmpty ? _pineconeEnvironmentController.text : null,
        pineconeIndexName: _pineconeIndexNameController.text.isNotEmpty ? _pineconeIndexNameController.text : null,
        algoliaAppId: _algoliaAppIdController.text.isNotEmpty ? _algoliaAppIdController.text : null,
        algoliaSearchKey: _algoliaSearchKeyController.text.isNotEmpty ? _algoliaSearchKeyController.text : null,
        algoliaIndexName: _algoliaIndexNameController.text.isNotEmpty ? _algoliaIndexNameController.text : null,
        elasticsearchUrl: _elasticsearchUrlController.text.isNotEmpty ? _elasticsearchUrlController.text : null,
        elasticsearchUsername: _elasticsearchUsernameController.text.isNotEmpty ? _elasticsearchUsernameController.text : null,
        elasticsearchPassword: _elasticsearchPasswordController.text.isNotEmpty ? _elasticsearchPasswordController.text : null,
        elasticsearchIndexName: _elasticsearchIndexNameController.text.isNotEmpty ? _elasticsearchIndexNameController.text : null,
      );

      final knowledgeBase = KnowledgeBase(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        engineConfig: engineConfig,
      );

      await DatabaseService.insertKnowledgeBase(knowledgeBase.toJson());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('知识库 "${knowledgeBase.name}" 创建成功！')),
        );
        widget.onCreated?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 头部
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Text(
                  '创建新知识库',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // 表单内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 知识库名称
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '知识库名称 *',
                        hintText: '请输入知识库名称',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return '请输入知识库名称';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    // 描述
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: '描述',
                        hintText: '请输入知识库描述（可选）',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    
                    // 选择引擎
                    const Text(
                      '选择引擎 *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<KnowledgeBaseEngineType>(
                      value: _selectedEngine,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: KnowledgeBaseEngineType.values.map((engine) {
                        return DropdownMenuItem(
                          value: engine,
                          child: Text(engine.displayName),
                        );
                      }).toList(),
                      onChanged: _onEngineChanged,
                    ),
                    const SizedBox(height: 20),
                    
                    // 引擎配置（动态显示）
                    _buildEngineConfig(),
                    const SizedBox(height: 20),
                    
                    // 创建按钮
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createKnowledgeBase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                '创建知识库',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineConfig() {
    switch (_selectedEngine) {
      case KnowledgeBaseEngineType.openai:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OpenAI 配置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key *',
                hintText: '请输入 OpenAI API Key',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入 API Key';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _llmModelController,
              decoration: const InputDecoration(
                labelText: '对话模型',
                hintText: 'gpt-4o, gpt-4-turbo 等',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _embeddingModelController,
              decoration: const InputDecoration(
                labelText: '嵌入模型',
                hintText: 'text-embedding-3-small 等',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );
        
      case KnowledgeBaseEngineType.google:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Google Vertex AI 配置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key *',
                hintText: '请输入 Google API Key',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入 API Key';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _llmModelController,
              decoration: const InputDecoration(
                labelText: '对话模型',
                hintText: 'gemini-pro, gemini-1.5-pro 等',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _embeddingModelController,
              decoration: const InputDecoration(
                labelText: '嵌入模型',
                hintText: 'textembedding-gecko-001 等',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );
        
      case KnowledgeBaseEngineType.vertexAiSearch:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Google Vertex AI Search 配置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key *',
                hintText: '请输入 Google Cloud API Key',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入 API Key';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _projectIdController,
              decoration: const InputDecoration(
                labelText: '项目 ID *',
                hintText: 'your-project-id',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入项目 ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '地区 *',
                hintText: 'us-central1, asia-northeast1 等',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入地区';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dataStoreIdController,
              decoration: const InputDecoration(
                labelText: '数据存储 ID *',
                hintText: 'your-data-store-id',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入数据存储 ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _llmModelController,
              decoration: const InputDecoration(
                labelText: '对话模型',
                hintText: 'gemini-pro, gemini-1.5-pro 等',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _embeddingModelController,
              decoration: const InputDecoration(
                labelText: '嵌入模型',
                hintText: 'textembedding-gecko-001 等',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );
        
      case KnowledgeBaseEngineType.pinecone:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pinecone 配置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pineconeApiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key *',
                hintText: '请输入 Pinecone API Key',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入 API Key';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pineconeEnvironmentController,
              decoration: const InputDecoration(
                labelText: '环境 *',
                hintText: 'gcp-starter, us-west1-gcp 等',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入环境';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pineconeIndexNameController,
              decoration: const InputDecoration(
                labelText: '索引名称 *',
                hintText: 'your-index-name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入索引名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _llmModelController,
              decoration: const InputDecoration(
                labelText: '对话模型',
                hintText: 'gpt-4o, gpt-4-turbo 等',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _embeddingModelController,
              decoration: const InputDecoration(
                labelText: '嵌入模型',
                hintText: 'text-embedding-3-small 等',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );
        
      case KnowledgeBaseEngineType.algolia:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Algolia 配置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _algoliaAppIdController,
              decoration: const InputDecoration(
                labelText: '应用 ID *',
                hintText: '请输入 Algolia 应用 ID',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入应用 ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _algoliaSearchKeyController,
              decoration: const InputDecoration(
                labelText: '搜索 API Key *',
                hintText: '请输入 Algolia 搜索 API Key',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入搜索 API Key';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _algoliaIndexNameController,
              decoration: const InputDecoration(
                labelText: '索引名称 *',
                hintText: 'your-index-name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入索引名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _llmModelController,
              decoration: const InputDecoration(
                labelText: '对话模型',
                hintText: 'gpt-4o, gpt-4-turbo 等',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _embeddingModelController,
              decoration: const InputDecoration(
                labelText: '嵌入模型',
                hintText: 'text-embedding-3-small 等',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );
        
      case KnowledgeBaseEngineType.elasticsearch:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Elasticsearch/OpenSearch 配置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _elasticsearchUrlController,
              decoration: const InputDecoration(
                labelText: '服务器地址 *',
                hintText: 'http://localhost:9200 或 https://your-es.com',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入服务器地址';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _elasticsearchUsernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                hintText: 'elastic 或您的用户名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _elasticsearchPasswordController,
              decoration: const InputDecoration(
                labelText: '密码',
                hintText: '您的密码',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _elasticsearchIndexNameController,
              decoration: const InputDecoration(
                labelText: '索引名称 *',
                hintText: 'your-index-name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入索引名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _llmModelController,
              decoration: const InputDecoration(
                labelText: '对话模型',
                hintText: 'gpt-4o, gpt-4-turbo 等',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _embeddingModelController,
              decoration: const InputDecoration(
                labelText: '嵌入模型',
                hintText: 'text-embedding-3-small 等',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );
        
      case KnowledgeBaseEngineType.custom:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '自定义后端配置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: '后端服务器地址 *',
                hintText: 'http://localhost:8000 或 https://your-api.com',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入服务器地址';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _llmModelController,
              decoration: const InputDecoration(
                labelText: '对话模型',
                hintText: 'llama-2-7b, qwen-7b 等',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _embeddingModelController,
              decoration: const InputDecoration(
                labelText: '嵌入模型',
                hintText: 'sentence-transformers/all-MiniLM-L6-v2 等',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );
    }
  }
}
