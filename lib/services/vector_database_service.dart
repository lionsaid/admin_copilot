import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/knowledge_base.dart';

/// 向量数据库服务接口
abstract class VectorDatabaseService {
  Future<void> initialize();
  Future<void> upsertVectors(List<VectorRecord> vectors);
  Future<List<SearchResult>> searchSimilar(String query, int limit);
  Future<void> deleteVectors(List<String> ids);
  Future<void> close();
}

/// 向量记录模型
class VectorRecord {
  final String id;
  final List<double> vector;
  final Map<String, dynamic> metadata;

  VectorRecord({
    required this.id,
    required this.vector,
    required this.metadata,
  });
}

/// 搜索结果模型
class SearchResult {
  final String id;
  final double score;
  final Map<String, dynamic> metadata;

  SearchResult({
    required this.id,
    required this.score,
    required this.metadata,
  });
}

/// Google Vertex AI Search 服务
class VertexAISearchService implements VectorDatabaseService {
  final KnowledgeBaseEngineConfig config;
  late http.Client _client;

  VertexAISearchService(this.config);

  @override
  Future<void> initialize() async {
    _client = http.Client();
    // 验证配置
    if (config.projectId == null || config.location == null || config.dataStoreId == null) {
      throw Exception('Vertex AI Search 配置不完整：需要 projectId, location, dataStoreId');
    }
  }

  @override
  Future<void> upsertVectors(List<VectorRecord> vectors) async {
    // Vertex AI Search 使用文档上传而不是直接的向量操作
    // 这里可以集成 Google Cloud Storage 和 Vertex AI Search API
    print('Vertex AI Search: 向量上传功能待实现');
  }

  @override
  Future<List<SearchResult>> searchSimilar(String query, int limit) async {
    try {
      final url = 'https://${config.location}-aiplatform.googleapis.com/v1/projects/${config.projectId}/locations/${config.location}/dataStores/${config.dataStoreId}:search';
      
      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': query,
          'pageSize': limit,
          'filter': '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = <SearchResult>[];
        
        for (final result in data['results'] ?? []) {
          results.add(SearchResult(
            id: result['id'] ?? '',
            score: (result['score'] ?? 0.0).toDouble(),
            metadata: result['document'] ?? {},
          ));
        }
        
        return results;
      } else {
        throw Exception('Vertex AI Search 请求失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Vertex AI Search 搜索失败: $e');
      return [];
    }
  }

  @override
  Future<void> deleteVectors(List<String> ids) async {
    // Vertex AI Search 删除功能待实现
    print('Vertex AI Search: 向量删除功能待实现');
  }

  @override
  Future<void> close() async {
    _client.close();
  }
}

/// Pinecone 向量数据库服务
class PineconeService implements VectorDatabaseService {
  final KnowledgeBaseEngineConfig config;
  late http.Client _client;

  PineconeService(this.config);

  @override
  Future<void> initialize() async {
    _client = http.Client();
    if (config.pineconeApiKey == null || config.pineconeEnvironment == null || config.pineconeIndexName == null) {
      throw Exception('Pinecone 配置不完整：需要 API Key, Environment, Index Name');
    }
  }

  @override
  Future<void> upsertVectors(List<VectorRecord> vectors) async {
    try {
      final url = 'https://${config.pineconeIndexName}-${config.pineconeEnvironment}.svc.pinecone.io/vectors/upsert';
      
      final upsertData = {
        'vectors': vectors.map((v) => {
          'id': v.id,
          'values': v.vector,
          'metadata': v.metadata,
        }).toList(),
      };

      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Api-Key': config.pineconeApiKey!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(upsertData),
      );

      if (response.statusCode != 200) {
        throw Exception('Pinecone 向量上传失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Pinecone 向量上传失败: $e');
      rethrow;
    }
  }

  @override
  Future<List<SearchResult>> searchSimilar(String query, int limit) async {
    try {
      final url = 'https://${config.pineconeIndexName}-${config.pineconeEnvironment}.svc.pinecone.io/query';
      
      // 这里需要先将查询文本转换为向量
      // 暂时使用占位向量
      final queryVector = List<double>.filled(1536, 0.1); // OpenAI 默认维度
      
      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Api-Key': config.pineconeApiKey!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'vector': queryVector,
          'topK': limit,
          'includeMetadata': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = <SearchResult>[];
        
        for (final match in data['matches'] ?? []) {
          results.add(SearchResult(
            id: match['id'] ?? '',
            score: (match['score'] ?? 0.0).toDouble(),
            metadata: match['metadata'] ?? {},
          ));
        }
        
        return results;
      } else {
        throw Exception('Pinecone 搜索失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Pinecone 搜索失败: $e');
      return [];
    }
  }

  @override
  Future<void> deleteVectors(List<String> ids) async {
    try {
      final url = 'https://${config.pineconeIndexName}-${config.pineconeEnvironment}.svc.pinecone.io/vectors/delete';
      
      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Api-Key': config.pineconeApiKey!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'ids': ids,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Pinecone 向量删除失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Pinecone 向量删除失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    _client.close();
  }
}

/// Algolia 向量搜索服务
class AlgoliaService implements VectorDatabaseService {
  final KnowledgeBaseEngineConfig config;
  late http.Client _client;

  AlgoliaService(this.config);

  @override
  Future<void> initialize() async {
    _client = http.Client();
    if (config.algoliaAppId == null || config.algoliaSearchKey == null || config.algoliaIndexName == null) {
      throw Exception('Algolia 配置不完整：需要 App ID, Search Key, Index Name');
    }
  }

  @override
  Future<void> upsertVectors(List<VectorRecord> vectors) async {
    try {
      final url = 'https://${config.algoliaAppId}.algolia.net/1/indexes/${config.algoliaIndexName}/batch';
      
      final batchData = vectors.map((v) => {
        'action': 'addObject',
        'body': {
          'objectID': v.id,
          'vector': v.vector,
          ...v.metadata,
        },
      }).toList();

      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'X-Algolia-API-Key': config.algoliaSearchKey!,
          'X-Algolia-Application-Id': config.algoliaAppId!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'requests': batchData,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Algolia 向量上传失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Algolia 向量上传失败: $e');
      rethrow;
    }
  }

  @override
  Future<List<SearchResult>> searchSimilar(String query, int limit) async {
    try {
      final url = 'https://${config.algoliaAppId}-dsn.algolia.net/1/indexes/${config.algoliaIndexName}/query';
      
      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'X-Algolia-API-Key': config.algoliaSearchKey!,
          'X-Algolia-Application-Id': config.algoliaAppId!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': query,
          'hitsPerPage': limit,
          'vector': [], // 这里需要查询向量
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = <SearchResult>[];
        
        for (final hit in data['hits'] ?? []) {
          results.add(SearchResult(
            id: hit['objectID'] ?? '',
            score: (hit['_score'] ?? 0.0).toDouble(),
            metadata: hit,
          ));
        }
        
        return results;
      } else {
        throw Exception('Algolia 搜索失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Algolia 搜索失败: $e');
      return [];
    }
  }

  @override
  Future<void> deleteVectors(List<String> ids) async {
    try {
      final url = 'https://${config.algoliaAppId}.algolia.net/1/indexes/${config.algoliaIndexName}/batch';
      
      final batchData = ids.map((id) => {
        'action': 'deleteObject',
        'body': {
          'objectID': id,
        },
      }).toList();

      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'X-Algolia-API-Key': config.algoliaSearchKey!,
          'X-Algolia-Application-Id': config.algoliaAppId!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'requests': batchData,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Algolia 向量删除失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Algolia 向量删除失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    _client.close();
  }
}

/// Elasticsearch/OpenSearch 服务
class ElasticsearchService implements VectorDatabaseService {
  final KnowledgeBaseEngineConfig config;
  late http.Client _client;

  ElasticsearchService(this.config);

  @override
  Future<void> initialize() async {
    _client = http.Client();
    if (config.elasticsearchUrl == null || config.elasticsearchIndexName == null) {
      throw Exception('Elasticsearch 配置不完整：需要 URL 和 Index Name');
    }
  }

  @override
  Future<void> upsertVectors(List<VectorRecord> vectors) async {
    try {
      final url = '${config.elasticsearchUrl}/${config.elasticsearchIndexName}/_bulk';
      
      final bulkData = StringBuffer();
      for (final vector in vectors) {
        bulkData.writeln('{"index":{"_id":"${vector.id}"}}');
        bulkData.writeln(jsonEncode({
          'vector': vector.vector,
          ...vector.metadata,
        }));
      }

      final headers = <String, String>{
        'Content-Type': 'application/x-ndjson',
      };
      
      if (config.elasticsearchUsername != null && config.elasticsearchPassword != null) {
        final auth = base64Encode(utf8.encode('${config.elasticsearchUsername}:${config.elasticsearchPassword}'));
        headers['Authorization'] = 'Basic $auth';
      }

      final response = await _client.post(
        Uri.parse(url),
        headers: headers,
        body: bulkData.toString(),
      );

      if (response.statusCode != 200) {
        throw Exception('Elasticsearch 向量上传失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Elasticsearch 向量上传失败: $e');
      rethrow;
    }
  }

  @override
  Future<List<SearchResult>> searchSimilar(String query, int limit) async {
    try {
      final url = '${config.elasticsearchUrl}/${config.elasticsearchIndexName}/_search';
      
      // 这里需要先将查询文本转换为向量
      final queryVector = List<double>.filled(1536, 0.1); // 占位向量
      
      final searchBody = {
        'size': limit,
        'query': {
          'script_score': {
            'query': {'match_all': {}},
            'script': {
              'source': 'cosineSimilarity(params.query_vector, "vector") + 1.0',
              'params': {'query_vector': queryVector},
            },
          },
        },
      };

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (config.elasticsearchUsername != null && config.elasticsearchPassword != null) {
        final auth = base64Encode(utf8.encode('${config.elasticsearchUsername}:${config.elasticsearchPassword}'));
        headers['Authorization'] = 'Basic $auth';
      }

      final response = await _client.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(searchBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = <SearchResult>[];
        
        for (final hit in data['hits']['hits'] ?? []) {
          results.add(SearchResult(
            id: hit['_id'] ?? '',
            score: (hit['_score'] ?? 0.0).toDouble(),
            metadata: hit['_source'] ?? {},
          ));
        }
        
        return results;
      } else {
        throw Exception('Elasticsearch 搜索失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Elasticsearch 搜索失败: $e');
      return [];
    }
  }

  @override
  Future<void> deleteVectors(List<String> ids) async {
    try {
      final url = '${config.elasticsearchUrl}/${config.elasticsearchIndexName}/_bulk';
      
      final bulkData = StringBuffer();
      for (final id in ids) {
        bulkData.writeln('{"delete":{"_id":"$id"}}');
      }

      final headers = <String, String>{
        'Content-Type': 'application/x-ndjson',
      };
      
      if (config.elasticsearchUsername != null && config.elasticsearchPassword != null) {
        final auth = base64Encode(utf8.encode('${config.elasticsearchUsername}:${config.elasticsearchPassword}'));
        headers['Authorization'] = 'Basic $auth';
      }

      final response = await _client.post(
        Uri.parse(url),
        headers: headers,
        body: bulkData.toString(),
      );

      if (response.statusCode != 200) {
        throw Exception('Elasticsearch 向量删除失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Elasticsearch 向量删除失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    _client.close();
  }
}

/// 向量数据库服务工厂
class VectorDatabaseServiceFactory {
  static VectorDatabaseService createService(KnowledgeBaseEngineConfig config) {
    switch (config.engineType) {
      case KnowledgeBaseEngineType.vertexAiSearch:
        return VertexAISearchService(config);
      case KnowledgeBaseEngineType.pinecone:
        return PineconeService(config);
      case KnowledgeBaseEngineType.algolia:
        return AlgoliaService(config);
      case KnowledgeBaseEngineType.elasticsearch:
        return ElasticsearchService(config);
      default:
        throw Exception('不支持的向量数据库类型: ${config.engineType}');
    }
  }
}
