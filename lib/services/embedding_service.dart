import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/knowledge_base.dart';
import '../services/database_service.dart';

class EmbeddingService {
  // 为知识库分块生成向量嵌入
  static Future<Uint8List?> generateEmbedding(
    String text,
    KnowledgeBaseEngineConfig engineConfig,
  ) async {
    try {
      switch (engineConfig.engineType) {
        case KnowledgeBaseEngineType.openai:
          return await _generateOpenAIEmbedding(text, engineConfig);
        case KnowledgeBaseEngineType.google:
          return await _generateGoogleEmbedding(text, engineConfig);
        case KnowledgeBaseEngineType.vertexAiSearch:
          // Vertex AI Search 使用 Google 的嵌入服务
          return await _generateGoogleEmbedding(text, engineConfig);
        case KnowledgeBaseEngineType.pinecone:
          // Pinecone 本身不提供嵌入服务，使用 OpenAI 作为默认
          return await _generateOpenAIEmbedding(text, engineConfig);
        case KnowledgeBaseEngineType.algolia:
          // Algolia 本身不提供嵌入服务，使用 OpenAI 作为默认
          return await _generateOpenAIEmbedding(text, engineConfig);
        case KnowledgeBaseEngineType.elasticsearch:
          // Elasticsearch 本身不提供嵌入服务，使用 OpenAI 作为默认
          return await _generateOpenAIEmbedding(text, engineConfig);
        case KnowledgeBaseEngineType.custom:
          return await _generateCustomEmbedding(text, engineConfig);
      }
    } catch (e) {
      print('生成向量嵌入失败: $e');
      return null;
    }
  }

  // OpenAI 向量嵌入
  static Future<Uint8List?> _generateOpenAIEmbedding(
    String text,
    KnowledgeBaseEngineConfig engineConfig,
  ) async {
    if (engineConfig.apiKey == null) {
      throw Exception('OpenAI API Key 未配置');
    }

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/embeddings'),
      headers: {
        'Authorization': 'Bearer ${engineConfig.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'input': text,
        'model': engineConfig.embeddingModel ?? 'text-embedding-3-small',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final embedding = data['data'][0]['embedding'] as List<dynamic>;
      return Uint8List.fromList(
        embedding.map((e) => (e as double).toDouble()).toList().cast<double>().map((d) => (d * 255).round()).toList(),
      );
    } else {
      throw Exception('OpenAI API 请求失败: ${response.statusCode} - ${response.body}');
    }
  }

  // Google Vertex AI 向量嵌入
  static Future<Uint8List?> _generateGoogleEmbedding(
    String text,
    KnowledgeBaseEngineConfig engineConfig,
  ) async {
    if (engineConfig.apiKey == null) {
      throw Exception('Google API Key 未配置');
    }

    // 这里使用 Google AI Studio 的 API
    final response = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${engineConfig.embeddingModel ?? 'textembedding-gecko-001'}:embedText'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'key': engineConfig.apiKey,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final embedding = data['embedding']['values'] as List<dynamic>;
      return Uint8List.fromList(
        embedding.map((e) => (e as double).toDouble()).toList().cast<double>().map((d) => (d * 255).round()).toList(),
      );
    } else {
      throw Exception('Google API 请求失败: ${response.statusCode} - ${response.body}');
    }
  }

  // 自定义后端向量嵌入
  static Future<Uint8List?> _generateCustomEmbedding(
    String text,
    KnowledgeBaseEngineConfig engineConfig,
  ) async {
    if (engineConfig.serverUrl == null) {
      throw Exception('自定义后端服务器地址未配置');
    }

    final response = await http.post(
      Uri.parse('${engineConfig.serverUrl}/embed'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'model': engineConfig.embeddingModel ?? 'sentence-transformers/all-MiniLM-L6-v2',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final embedding = data['embedding'] as List<dynamic>;
      return Uint8List.fromList(
        embedding.map((e) => (e as double).toDouble()).toList().cast<double>().map((d) => (d * 255).round()).toList(),
      );
    } else {
      throw Exception('自定义后端 API 请求失败: ${response.statusCode} - ${response.body}');
    }
  }

  // 计算两个向量的余弦相似度
  static double calculateCosineSimilarity(Uint8List vector1, Uint8List vector2) {
    if (vector1.length != vector2.length) {
      throw Exception('向量维度不匹配');
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < vector1.length; i++) {
      final v1 = vector1[i].toDouble();
      final v2 = vector2[i].toDouble();
      dotProduct += v1 * v2;
      norm1 += v1 * v1;
      norm2 += v2 * v2;
    }

    if (norm1 == 0.0 || norm2 == 0.0) {
      return 0.0;
    }

    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  // 计算欧几里得距离
  static double calculateEuclideanDistance(Uint8List vector1, Uint8List vector2) {
    if (vector1.length != vector2.length) {
      throw Exception('向量维度不匹配');
    }

    double sum = 0.0;
    for (int i = 0; i < vector1.length; i++) {
      final diff = vector1[i].toDouble() - vector2[i].toDouble();
      sum += diff * diff;
    }

    return sqrt(sum);
  }

  // 在知识库中搜索相似内容
  static Future<List<SearchResult>> searchSimilarContent(
    String query,
    int knowledgeBaseId,
    KnowledgeBaseEngineConfig engineConfig,
    {int limit = 5}
  ) async {
    try {
      // 生成查询向量
      final queryEmbedding = await generateEmbedding(query, engineConfig);
      if (queryEmbedding == null) {
        throw Exception('无法生成查询向量');
      }

      // 获取知识库中的所有分块
      final documents = await DatabaseService.getDocumentsByKnowledgeBase(knowledgeBaseId);
      final allChunks = <Map<String, dynamic>>[];
      
      for (final doc in documents) {
        final chunks = await DatabaseService.getChunksByDocument(doc['id']);
        allChunks.addAll(chunks);
      }

      // 计算相似度并排序
      final results = <SearchResult>[];
      for (final chunk in allChunks) {
        if (chunk['embedding'] != null) {
          final chunkEmbedding = chunk['embedding'] as Uint8List;
          final similarity = calculateCosineSimilarity(queryEmbedding, chunkEmbedding);
          
          results.add(SearchResult(
            chunkId: chunk['id'],
            documentId: chunk['doc_id'],
            content: chunk['content'],
            similarity: similarity,
            chunkIndex: chunk['chunk_index'],
          ));
        }
      }

      // 按相似度排序并限制结果数量
      results.sort((a, b) => b.similarity.compareTo(a.similarity));
      return results.take(limit).toList();
    } catch (e) {
      print('搜索相似内容失败: $e');
      return [];
    }
  }

  // 批量更新知识库分块的向量嵌入
  static Future<void> updateKnowledgeBaseEmbeddings(
    int knowledgeBaseId,
    KnowledgeBaseEngineConfig engineConfig,
  ) async {
    try {
      final documents = await DatabaseService.getDocumentsByKnowledgeBase(knowledgeBaseId);
      
      for (final doc in documents) {
        final chunks = await DatabaseService.getChunksByDocument(doc['id']);
        
        for (final chunk in chunks) {
          if (chunk['embedding'] == null) {
            // 生成向量嵌入
            final embedding = await generateEmbedding(chunk['content'], engineConfig);
            if (embedding != null) {
              // 更新分块的向量嵌入
              await DatabaseService.updateChunk(chunk['id'], {
                'embedding': embedding,
              });
            }
          }
        }
      }
      
      print('知识库 $knowledgeBaseId 的向量嵌入更新完成');
    } catch (e) {
      print('更新知识库向量嵌入失败: $e');
      rethrow;
    }
  }
}

// 搜索结果模型
class SearchResult {
  final int chunkId;
  final int documentId;
  final String content;
  final double similarity;
  final int chunkIndex;

  SearchResult({
    required this.chunkId,
    required this.documentId,
    required this.content,
    required this.similarity,
    required this.chunkIndex,
  });
}

// 数学函数
double sqrt(double x) {
  return sqrt(x);
}
