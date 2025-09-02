enum ProviderType {
  // 国际主要供应商
  openai,
  claude,
  gemini,
  azureOpenai,
  meta,
  amazon,
  microsoft,
  xai,
  cohere,
  ai21,
  mistral,
  inflection,
  
  // 中国主要供应商
  alibaba,
  baidu,
  tencent,
  huawei,
  bytedance,
  zhipu,
  moonshot,
  zeroone,
  
  // 本地和自定义
  ollama,
  custom,
}

extension ProviderTypeExtension on ProviderType {
  String get displayName {
    switch (this) {
      // 国际主要供应商
      case ProviderType.openai:
        return 'OpenAI';
      case ProviderType.claude:
        return 'Anthropic Claude';
      case ProviderType.gemini:
        return 'Google Gemini';
      case ProviderType.azureOpenai:
        return 'Azure OpenAI';
      case ProviderType.meta:
        return 'Meta (Llama)';
      case ProviderType.amazon:
        return 'Amazon Bedrock';
      case ProviderType.microsoft:
        return 'Microsoft Copilot';
      case ProviderType.xai:
        return 'xAI (Grok)';
      case ProviderType.cohere:
        return 'Cohere';
      case ProviderType.ai21:
        return 'AI21 Labs';
      case ProviderType.mistral:
        return 'Mistral AI';
      case ProviderType.inflection:
        return 'Inflection AI';
      
      // 中国主要供应商
      case ProviderType.alibaba:
        return '阿里巴巴 (通义千问)';
      case ProviderType.baidu:
        return '百度 (文心一言)';
      case ProviderType.tencent:
        return '腾讯 (混元)';
      case ProviderType.huawei:
        return '华为 (盘古)';
      case ProviderType.bytedance:
        return '字节跳动 (豆包)';
      case ProviderType.zhipu:
        return '智谱AI (GLM)';
      case ProviderType.moonshot:
        return '月之暗面 (Kimi)';
      case ProviderType.zeroone:
        return '零一万物 (Yi)';
      
      // 本地和自定义
      case ProviderType.ollama:
        return 'Ollama (本地模型)';
      case ProviderType.custom:
        return '自定义 (OpenAI 兼容)';
    }
  }
  
  String get value {
    switch (this) {
      // 国际主要供应商
      case ProviderType.openai:
        return 'openai';
      case ProviderType.claude:
        return 'claude';
      case ProviderType.gemini:
        return 'gemini';
      case ProviderType.azureOpenai:
        return 'azure_openai';
      case ProviderType.meta:
        return 'meta';
      case ProviderType.amazon:
        return 'amazon';
      case ProviderType.microsoft:
        return 'microsoft';
      case ProviderType.xai:
        return 'xai';
      case ProviderType.cohere:
        return 'cohere';
      case ProviderType.ai21:
        return 'ai21';
      case ProviderType.mistral:
        return 'mistral';
      case ProviderType.inflection:
        return 'inflection';
      
      // 中国主要供应商
      case ProviderType.alibaba:
        return 'alibaba';
      case ProviderType.baidu:
        return 'baidu';
      case ProviderType.tencent:
        return 'tencent';
      case ProviderType.huawei:
        return 'huawei';
      case ProviderType.bytedance:
        return 'bytedance';
      case ProviderType.zhipu:
        return 'zhipu';
      case ProviderType.moonshot:
        return 'moonshot';
      case ProviderType.zeroone:
        return 'zeroone';
      
      // 本地和自定义
      case ProviderType.ollama:
        return 'ollama';
      case ProviderType.custom:
        return 'custom';
    }
  }
}

enum TestStatus {
  unknown,
  success,
  failed,
  testing,
}

extension TestStatusExtension on TestStatus {
  String get value {
    switch (this) {
      case TestStatus.unknown:
        return 'unknown';
      case TestStatus.success:
        return 'success';
      case TestStatus.failed:
        return 'failed';
      case TestStatus.testing:
        return 'testing';
    }
  }
  
  static TestStatus fromString(String value) {
    switch (value) {
      case 'success':
        return TestStatus.success;
      case 'failed':
        return TestStatus.failed;
      case 'testing':
        return TestStatus.testing;
      default:
        return TestStatus.unknown;
    }
  }
}

class ModelProvider {
  final int? id;
  final String name;
  final ProviderType providerType;
  final String? apiKey;
  final String? baseUrl;
  final String? serverUrl;
  final String? endpointUrl;
  final String? deploymentName;
  final bool isActive;
  final bool isDefault;
  final DateTime? lastTestTime;
  final TestStatus testStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  ModelProvider({
    this.id,
    required this.name,
    required this.providerType,
    this.apiKey,
    this.baseUrl,
    this.serverUrl,
    this.endpointUrl,
    this.deploymentName,
    this.isActive = true,
    this.isDefault = false,
    this.lastTestTime,
    this.testStatus = TestStatus.unknown,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'provider_type': providerType.value,
      'api_key': apiKey,
      'base_url': baseUrl,
      'server_url': serverUrl,
      'endpoint_url': endpointUrl,
      'deployment_name': deploymentName,
      'is_active': isActive ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
      'last_test_time': lastTestTime?.toIso8601String(),
      'test_status': testStatus.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ModelProvider.fromMap(Map<String, dynamic> map) {
    return ModelProvider(
      id: map['id'] as int?,
      name: map['name'] as String,
      providerType: _getProviderTypeFromString(map['provider_type'] as String),
      apiKey: map['api_key'] as String?,
      baseUrl: map['base_url'] as String?,
      serverUrl: map['server_url'] as String?,
      endpointUrl: map['endpoint_url'] as String?,
      deploymentName: map['deployment_name'] as String?,
      isActive: (map['is_active'] as int) == 1,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      lastTestTime: map['last_test_time'] != null 
          ? DateTime.parse(map['last_test_time'] as String)
          : null,
      testStatus: TestStatusExtension.fromString(map['test_status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  ModelProvider copyWith({
    int? id,
    String? name,
    ProviderType? providerType,
    String? apiKey,
    String? baseUrl,
    String? serverUrl,
    String? endpointUrl,
    String? deploymentName,
    bool? isActive,
    bool? isDefault,
    DateTime? lastTestTime,
    TestStatus? testStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ModelProvider(
      id: id ?? this.id,
      name: name ?? this.name,
      providerType: providerType ?? this.providerType,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      serverUrl: serverUrl ?? this.serverUrl,
      endpointUrl: endpointUrl ?? this.endpointUrl,
      deploymentName: deploymentName ?? this.deploymentName,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      lastTestTime: lastTestTime ?? this.lastTestTime,
      testStatus: testStatus ?? this.testStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static ProviderType _getProviderTypeFromString(String value) {
    switch (value) {
      // 国际主要供应商
      case 'openai':
        return ProviderType.openai;
      case 'claude':
        return ProviderType.claude;
      case 'gemini':
        return ProviderType.gemini;
      case 'azure_openai':
        return ProviderType.azureOpenai;
      case 'meta':
        return ProviderType.meta;
      case 'amazon':
        return ProviderType.amazon;
      case 'microsoft':
        return ProviderType.microsoft;
      case 'xai':
        return ProviderType.xai;
      case 'cohere':
        return ProviderType.cohere;
      case 'ai21':
        return ProviderType.ai21;
      case 'mistral':
        return ProviderType.mistral;
      case 'inflection':
        return ProviderType.inflection;
      
      // 中国主要供应商
      case 'alibaba':
        return ProviderType.alibaba;
      case 'baidu':
        return ProviderType.baidu;
      case 'tencent':
        return ProviderType.tencent;
      case 'huawei':
        return ProviderType.huawei;
      case 'bytedance':
        return ProviderType.bytedance;
      case 'zhipu':
        return ProviderType.zhipu;
      case 'moonshot':
        return ProviderType.moonshot;
      case 'zeroone':
        return ProviderType.zeroone;
      
      // 本地和自定义
      case 'ollama':
        return ProviderType.ollama;
      case 'custom':
        return ProviderType.custom;
      default:
        return ProviderType.openai;
    }
  }
}
