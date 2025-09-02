import 'package:flutter/material.dart';
import '../models/knowledge_base.dart';
import '../services/database_service.dart';
import '../services/document_upload_service.dart';
import '../services/rag_service.dart';
import '../widgets/create_knowledge_base_sheet.dart';

class KnowledgeBasePage extends StatefulWidget {
  const KnowledgeBasePage({super.key});

  @override
  State<KnowledgeBasePage> createState() => _KnowledgeBasePageState();
}

class _KnowledgeBasePageState extends State<KnowledgeBasePage> {
  List<KnowledgeBase> _knowledgeBases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKnowledgeBases();
  }

  Future<void> _loadKnowledgeBases() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseService.getAllKnowledgeBases();
      setState(() {
        _knowledgeBases = data.map((json) => KnowledgeBase.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载知识库失败: $e')),
        );
      }
    }
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateKnowledgeBaseSheet(
        onCreated: _loadKnowledgeBases,
      ),
    );
  }

  Future<void> _deleteKnowledgeBase(KnowledgeBase kb) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除知识库 "${kb.name}" 吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService.deleteKnowledgeBase(kb.id!);
        await _loadKnowledgeBases();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('知识库 "${kb.name}" 已删除')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  // 上传文档到知识库
  Future<void> _uploadDocuments(KnowledgeBase kb) async {
    try {
      final files = await DocumentUploadService.pickDocuments();
      if (files.isEmpty) return;

      // 显示上传进度
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在处理文档...'),
            ],
          ),
        ),
      );

      int totalChunks = 0;
      for (final file in files) {
        final chunks = await DocumentUploadService.processDocument(file, kb.id!);
        totalChunks += chunks.length;
      }

      if (mounted) {
        Navigator.of(context).pop(); // 关闭进度对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功上传 ${files.length} 个文档，生成 $totalChunks 个分块')),
        );
        
        // 刷新知识库列表
        await _loadKnowledgeBases();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭进度对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    }
  }

  // 处理知识库向量化
  Future<void> _processVectorization(KnowledgeBase kb) async {
    try {
      // 显示向量化进度
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在生成向量嵌入...'),
            ],
          ),
        ),
      );

      await RAGService.processKnowledgeBaseVectorization(kb.id!, kb.engineConfig);

      if (mounted) {
        Navigator.of(context).pop(); // 关闭进度对话框
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('向量化处理完成！')),
        );
        
        // 刷新知识库列表
        await _loadKnowledgeBases();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭进度对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('向量化失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('知识库'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 头部区域
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '知识库管理',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '创建和管理您的专属知识库，让 AI 掌握专业领域知识',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _showCreateSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('创建新知识库'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 列表区域
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _knowledgeBases.isEmpty
                    ? _buildEmptyState()
                    : _buildKnowledgeBaseList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          const Text(
            '还没有知识库',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '创建您的第一个知识库，开始构建专业 AI 助手',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _showCreateSheet,
            icon: const Icon(Icons.add),
            label: const Text('创建知识库'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowledgeBaseList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _knowledgeBases.length,
      itemBuilder: (context, index) {
        final kb = _knowledgeBases[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: CircleAvatar(
              backgroundColor: _getEngineColor(kb.engineConfig.engineType),
              child: Icon(
                _getEngineIcon(kb.engineConfig.engineType),
                color: Colors.white,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    kb.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                                  Chip(
                    label: Text(
                      kb.engineConfig.engineType.displayName,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _getEngineColor(kb.engineConfig.engineType).withValues(alpha: 0.1),
                    labelStyle: TextStyle(
                      color: _getEngineColor(kb.engineConfig.engineType),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kb.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    kb.description!,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '创建于 ${_formatDate(kb.createdAt)}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.model_training,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      kb.engineConfig.llmModel ?? '未设置',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder<KnowledgeBaseStats>(
                  future: RAGService.getKnowledgeBaseStats(kb.id!),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final stats = snapshot.data!;
                      return Row(
                        children: [
                          Icon(
                            Icons.description,
                            size: 16,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${stats.totalDocuments} 文档, ${stats.totalChunks} 分块',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: stats.isFullyProcessed 
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              stats.statusText,
                              style: TextStyle(
                                color: stats.isFullyProcessed ? Colors.green : Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 上传文档按钮
                IconButton(
                  onPressed: () => _uploadDocuments(kb),
                  icon: const Icon(Icons.upload_file, color: Colors.blue),
                  tooltip: '上传文档',
                ),
                // 向量化按钮
                IconButton(
                  onPressed: () => _processVectorization(kb),
                  icon: const Icon(Icons.auto_awesome, color: Colors.green),
                  tooltip: '生成向量嵌入',
                ),
                // 更多操作菜单
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteKnowledgeBase(kb);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getEngineColor(KnowledgeBaseEngineType engineType) {
    switch (engineType) {
      case KnowledgeBaseEngineType.openai:
        return const Color(0xFF10A37F);
      case KnowledgeBaseEngineType.google:
        return const Color(0xFF4285F4);
      case KnowledgeBaseEngineType.vertexAiSearch:
        return const Color(0xFF34A853);
      case KnowledgeBaseEngineType.pinecone:
        return const Color(0xFF7C3AED);
      case KnowledgeBaseEngineType.algolia:
        return const Color(0xFF00B4D8);
      case KnowledgeBaseEngineType.elasticsearch:
        return const Color(0xFFFED766);
      case KnowledgeBaseEngineType.custom:
        return const Color(0xFF6366F1);
    }
  }

  IconData _getEngineIcon(KnowledgeBaseEngineType engineType) {
    switch (engineType) {
      case KnowledgeBaseEngineType.openai:
        return Icons.auto_awesome;
      case KnowledgeBaseEngineType.google:
        return Icons.cloud;
      case KnowledgeBaseEngineType.vertexAiSearch:
        return Icons.search;
      case KnowledgeBaseEngineType.pinecone:
        return Icons.storage;
      case KnowledgeBaseEngineType.algolia:
        return Icons.search;
      case KnowledgeBaseEngineType.elasticsearch:
        return Icons.data_usage;
      case KnowledgeBaseEngineType.custom:
        return Icons.settings;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return '今天';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}


