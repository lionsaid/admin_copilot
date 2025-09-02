enum KnowledgeBaseEngineType {
  openai('OpenAI Assistants API'),
  google('Google Vertex AI'),
  vertexAiSearch('Google Vertex AI Search'),
  pinecone('Pinecone'),
  algolia('Algolia'),
  elasticsearch('Elasticsearch/OpenSearch'),
  custom('自定义 (LangChain/LlamaIndex)');

  const KnowledgeBaseEngineType(this.displayName);
  final String displayName;
}

class KnowledgeBaseEngineConfig {
  final KnowledgeBaseEngineType engineType;
  final String? apiKey;
  final String? serverUrl;
  final String? llmModel;
  final String? embeddingModel;
  
  // Google Vertex AI Search 配置
  final String? projectId;
  final String? location;
  final String? dataStoreId;
  
  // Pinecone 配置
  final String? pineconeApiKey;
  final String? pineconeEnvironment;
  final String? pineconeIndexName;
  
  // Algolia 配置
  final String? algoliaAppId;
  final String? algoliaSearchKey;
  final String? algoliaIndexName;
  
  // Elasticsearch 配置
  final String? elasticsearchUrl;
  final String? elasticsearchUsername;
  final String? elasticsearchPassword;
  final String? elasticsearchIndexName;

  KnowledgeBaseEngineConfig({
    required this.engineType,
    this.apiKey,
    this.serverUrl,
    this.llmModel,
    this.embeddingModel,
    this.projectId,
    this.location,
    this.dataStoreId,
    this.pineconeApiKey,
    this.pineconeEnvironment,
    this.pineconeIndexName,
    this.algoliaAppId,
    this.algoliaSearchKey,
    this.algoliaIndexName,
    this.elasticsearchUrl,
    this.elasticsearchUsername,
    this.elasticsearchPassword,
    this.elasticsearchIndexName,
  });

  Map<String, dynamic> toJson() {
    return {
      'engine_type': engineType.name,
      'api_key': apiKey,
      'server_url': serverUrl,
      'llm_model': llmModel,
      'embedding_model': embeddingModel,
      'project_id': projectId,
      'location': location,
      'data_store_id': dataStoreId,
      'pinecone_api_key': pineconeApiKey,
      'pinecone_environment': pineconeEnvironment,
      'pinecone_index_name': pineconeIndexName,
      'algolia_app_id': algoliaAppId,
      'algolia_search_key': algoliaSearchKey,
      'algolia_index_name': algoliaIndexName,
      'elasticsearch_url': elasticsearchUrl,
      'elasticsearch_username': elasticsearchUsername,
      'elasticsearch_password': elasticsearchPassword,
      'elasticsearch_index_name': elasticsearchIndexName,
    };
  }

  factory KnowledgeBaseEngineConfig.fromJson(Map<String, dynamic> json) {
    return KnowledgeBaseEngineConfig(
      engineType: KnowledgeBaseEngineType.values.firstWhere(
        (e) => e.name == json['engine_type'],
        orElse: () => KnowledgeBaseEngineType.openai,
      ),
      apiKey: json['api_key'],
      serverUrl: json['server_url'],
      llmModel: json['llm_model'],
      embeddingModel: json['embedding_model'],
      projectId: json['project_id'],
      location: json['location'],
      dataStoreId: json['data_store_id'],
      pineconeApiKey: json['pinecone_api_key'],
      pineconeEnvironment: json['pinecone_environment'],
      pineconeIndexName: json['pinecone_index_name'],
      algoliaAppId: json['algolia_app_id'],
      algoliaSearchKey: json['algolia_search_key'],
      algoliaIndexName: json['algolia_index_name'],
      elasticsearchUrl: json['elasticsearch_url'],
      elasticsearchUsername: json['elasticsearch_username'],
      elasticsearchPassword: json['elasticsearch_password'],
      elasticsearchIndexName: json['elasticsearch_index_name'],
    );
  }
}

class KnowledgeBase {
  final int? id;
  final String name;
  final String? description;
  final KnowledgeBaseEngineConfig engineConfig;
  final DateTime createdAt;
  final DateTime updatedAt;

  KnowledgeBase({
    this.id,
    required this.name,
    this.description,
    required this.engineConfig,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'engine_type': engineConfig.engineType.name,
      'engine_config': engineConfig.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory KnowledgeBase.fromJson(Map<String, dynamic> json) {
    return KnowledgeBase(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      engineConfig: KnowledgeBaseEngineConfig.fromJson({
        'engine_type': json['engine_type'],
        ...json['engine_config'] ?? {},
      }),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  KnowledgeBase copyWith({
    int? id,
    String? name,
    String? description,
    KnowledgeBaseEngineConfig? engineConfig,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KnowledgeBase(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      engineConfig: engineConfig ?? this.engineConfig,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
