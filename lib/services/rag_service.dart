import '../models/knowledge_base.dart';
import '../services/embedding_service.dart';
import '../services/database_service.dart';

class RAGService {
  // 使用知识库增强 AI 响应
  static Future<String> enhanceResponseWithKnowledgeBase(
    String userQuery,
    int knowledgeBaseId,
    KnowledgeBaseEngineConfig engineConfig,
    {int maxChunks = 3}
  ) async {
    try {
      // 在知识库中搜索相关内容
      final searchResults = await EmbeddingService.searchSimilarContent(
        userQuery,
        knowledgeBaseId,
        engineConfig,
        limit: maxChunks,
      );

      if (searchResults.isEmpty) {
        return '我在知识库中没有找到与您问题直接相关的内容。';
      }

      // 构建增强的上下文
      final context = _buildContextFromSearchResults(searchResults);
      
      // 构建增强的提示词
      final enhancedPrompt = _buildEnhancedPrompt(userQuery, context);
      
      return enhancedPrompt;
    } catch (e) {
      print('知识库增强失败: $e');
      return '抱歉，我在检索知识库时遇到了问题。';
    }
  }

  // 从搜索结果构建上下文
  static String _buildContextFromSearchResults(List<SearchResult> results) {
    final contextBuilder = StringBuffer();
    contextBuilder.writeln('基于知识库中的相关信息：\n');
    
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      contextBuilder.writeln('${i + 1}. 相关内容 (相似度: ${(result.similarity * 100).toStringAsFixed(1)}%):');
      contextBuilder.writeln('${result.content}\n');
    }
    
    return contextBuilder.toString();
  }

  // 构建增强的提示词
  static String _buildEnhancedPrompt(String userQuery, String context) {
    return '''
请基于以下知识库信息回答用户的问题：

$context

用户问题：$userQuery

请确保回答准确、相关，并尽可能引用知识库中的具体信息。如果知识库中的信息不足以完全回答问题，请说明已知信息，并指出还需要哪些额外信息。
''';
  }

  // 获取知识库统计信息
  static Future<KnowledgeBaseStats> getKnowledgeBaseStats(int knowledgeBaseId) async {
    try {
      final documents = await DatabaseService.getDocumentsByKnowledgeBase(knowledgeBaseId);
      int totalChunks = 0;
      int chunksWithEmbeddings = 0;
      
      for (final doc in documents) {
        final chunks = await DatabaseService.getChunksByDocument(doc['id']);
        totalChunks += chunks.length;
        chunksWithEmbeddings += chunks.where((chunk) => chunk['embedding'] != null).length;
      }
      
      return KnowledgeBaseStats(
        totalDocuments: documents.length,
        totalChunks: totalChunks,
        chunksWithEmbeddings: chunksWithEmbeddings,
        embeddingProgress: totalChunks > 0 ? chunksWithEmbeddings / totalChunks : 0.0,
      );
    } catch (e) {
      print('获取知识库统计信息失败: $e');
      return KnowledgeBaseStats(
        totalDocuments: 0,
        totalChunks: 0,
        chunksWithEmbeddings: 0,
        embeddingProgress: 0.0,
      );
    }
  }

  // 批量处理知识库向量化
  static Future<void> processKnowledgeBaseVectorization(
    int knowledgeBaseId,
    KnowledgeBaseEngineConfig engineConfig,
  ) async {
    try {
      print('开始处理知识库 $knowledgeBaseId 的向量化...');
      
      // 更新所有分块的向量嵌入
      await EmbeddingService.updateKnowledgeBaseEmbeddings(knowledgeBaseId, engineConfig);
      
      print('知识库 $knowledgeBaseId 的向量化处理完成');
    } catch (e) {
      print('知识库向量化处理失败: $e');
      rethrow;
    }
  }

  // 搜索知识库内容
  static Future<List<SearchResult>> searchKnowledgeBase(
    String query,
    int knowledgeBaseId,
    KnowledgeBaseEngineConfig engineConfig,
    {int limit = 5, double similarityThreshold = 0.5}
  ) async {
    try {
      final results = await EmbeddingService.searchSimilarContent(
        query,
        knowledgeBaseId,
        engineConfig,
        limit: limit * 2, // 获取更多结果以便过滤
      );
      
      // 过滤相似度低于阈值的结果
      return results.where((result) => result.similarity >= similarityThreshold).toList();
    } catch (e) {
      print('搜索知识库失败: $e');
      return [];
    }
  }

  // 获取知识库建议问题
  static Future<List<String>> getSuggestedQuestions(int knowledgeBaseId) async {
    try {
      final documents = await DatabaseService.getDocumentsByKnowledgeBase(knowledgeBaseId);
      final suggestions = <String>[];
      
      for (final doc in documents) {
        final chunks = await DatabaseService.getChunksByDocument(doc['id']);
        if (chunks.isNotEmpty) {
          // 基于文档标题生成建议问题
          final title = doc['title'] as String;
          if (title.toLowerCase().contains('faq') || title.toLowerCase().contains('常见问题')) {
            suggestions.add('关于 ${title.replaceAll(RegExp(r'\.(faq|常见问题).*', caseSensitive: false), '')} 的常见问题有哪些？');
          } else {
            suggestions.add('请介绍一下 ${title.replaceAll(RegExp(r'\.[^.]+$'), '')} 的相关内容');
          }
        }
      }
      
      return suggestions.take(5).toList();
    } catch (e) {
      print('获取建议问题失败: $e');
      return [];
    }
  }
}

// 知识库统计信息
class KnowledgeBaseStats {
  final int totalDocuments;
  final int totalChunks;
  final int chunksWithEmbeddings;
  final double embeddingProgress;

  KnowledgeBaseStats({
    required this.totalDocuments,
    required this.totalChunks,
    required this.chunksWithEmbeddings,
    required this.embeddingProgress,
  });

  double get embeddingPercentage => embeddingProgress * 100;
  
  bool get isFullyProcessed => embeddingProgress >= 1.0;
  
  String get statusText {
    if (isFullyProcessed) {
      return '已完成向量化';
    } else if (embeddingProgress > 0) {
      return '向量化进度: ${embeddingPercentage.toStringAsFixed(1)}%';
    } else {
      return '未开始向量化';
    }
  }
}
