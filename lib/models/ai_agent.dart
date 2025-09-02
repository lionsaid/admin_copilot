import 'package:flutter/material.dart';
import 'dart:convert';

/// AI代理状态枚举
enum AgentStatus {
  active('活跃', 'Active', Colors.green, Icons.check_circle),
  inactive('停用', 'Inactive', Colors.grey, Icons.pause_circle),
  processing('运行中', 'Processing', Colors.orange, Icons.sync),
  error('错误', 'Error', Colors.red, Icons.error),
  draft('草稿', 'Draft', Colors.blue, Icons.edit);

  const AgentStatus(this.displayName, this.englishName, this.color, this.icon);
  
  final String displayName;
  final String englishName;
  final Color color;
  final IconData icon;
}

/// AI代理类型枚举
enum AgentType {
  customerService('客户服务', 'Customer Service', Icons.support_agent),
  contentCreator('内容创作', 'Content Creator', Icons.create),
  dataAnalyst('数据分析', 'Data Analyst', Icons.analytics),
  codeAssistant('代码助手', 'Code Assistant', Icons.code),
  researchAssistant('研究助手', 'Research Assistant', Icons.search),
  custom('自定义', 'Custom', Icons.build);

  const AgentType(this.displayName, this.englishName, this.icon);
  
  final String displayName;
  final String englishName;
  final IconData icon;
}

/// AI代理数据模型
class AIAgent {
  final int? id;
  final String name;
  final String description;
  final AgentType type;
  final AgentStatus status;
  final String systemPrompt;
  final String providerName;
  final String modelName;
  final Map<String, dynamic> modelConfig;
  final List<String> knowledgeBases;
  final List<String> tools;
  final List<String> workflows;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastRunAt;
  final int totalRuns;
  final int successRuns;
  final double averageResponseTime;
  final double totalTokenCost;

  AIAgent({
    this.id,
    required this.name,
    required this.description,
    required this.type,
    this.status = AgentStatus.draft,
    required this.systemPrompt,
    required this.providerName,
    required this.modelName,
    this.modelConfig = const {},
    this.knowledgeBases = const [],
    this.tools = const [],
    this.workflows = const [],
    this.metadata = const {},
    DateTime? createdAt,
    this.updatedAt,
    this.lastRunAt,
    this.totalRuns = 0,
    this.successRuns = 0,
    this.averageResponseTime = 0.0,
    this.totalTokenCost = 0.0,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 从Map创建对象
  factory AIAgent.fromMap(Map<String, dynamic> map) {
    return AIAgent(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String,
      type: AgentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AgentType.custom,
      ),
      status: AgentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AgentStatus.draft,
      ),
      systemPrompt: map['system_prompt'] as String,
      providerName: map['provider_name'] as String,
      modelName: map['model_name'] as String,
      modelConfig: map['model_config'] != null 
          ? _parseJsonField<Map<String, dynamic>>(map['model_config'])
          : {},
      knowledgeBases: map['knowledge_bases'] != null 
          ? _parseJsonField<List<String>>(map['knowledge_bases'])
          : [],
      tools: map['tools'] != null 
          ? _parseJsonField<List<String>>(map['tools'])
          : [],
      workflows: map['workflows'] != null 
          ? _parseJsonField<List<String>>(map['workflows'])
          : [],
      metadata: map['metadata'] != null 
          ? _parseJsonField<Map<String, dynamic>>(map['metadata'])
          : {},
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      lastRunAt: map['last_run_at'] != null 
          ? DateTime.parse(map['last_run_at'] as String)
          : null,
      totalRuns: map['total_runs'] as int? ?? 0,
      successRuns: map['success_runs'] as int? ?? 0,
      averageResponseTime: (map['average_response_time'] as num?)?.toDouble() ?? 0.0,
      totalTokenCost: (map['total_token_cost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'status': status.name,
      'system_prompt': systemPrompt,
      'provider_name': providerName,
      'model_name': modelName,
      'model_config': _toJsonString(modelConfig),
      'knowledge_bases': _toJsonString(knowledgeBases),
      'tools': _toJsonString(tools),
      'workflows': _toJsonString(workflows),
      'metadata': _toJsonString(metadata),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_run_at': lastRunAt?.toIso8601String(),
      'total_runs': totalRuns,
      'success_runs': successRuns,
      'average_response_time': averageResponseTime,
      'total_token_cost': totalTokenCost,
    };
  }

  /// 复制并更新
  AIAgent copyWith({
    int? id,
    String? name,
    String? description,
    AgentType? type,
    AgentStatus? status,
    String? systemPrompt,
    String? providerName,
    String? modelName,
    Map<String, dynamic>? modelConfig,
    List<String>? knowledgeBases,
    List<String>? tools,
    List<String>? workflows,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastRunAt,
    int? totalRuns,
    int? successRuns,
    double? averageResponseTime,
    double? totalTokenCost,
  }) {
    return AIAgent(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      providerName: providerName ?? this.providerName,
      modelName: modelName ?? this.modelName,
      modelConfig: modelConfig ?? this.modelConfig,
      knowledgeBases: knowledgeBases ?? this.knowledgeBases,
      tools: tools ?? this.tools,
      workflows: workflows ?? this.workflows,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      totalRuns: totalRuns ?? this.totalRuns,
      successRuns: successRuns ?? this.successRuns,
      averageResponseTime: averageResponseTime ?? this.averageResponseTime,
      totalTokenCost: totalTokenCost ?? this.totalTokenCost,
    );
  }

  /// 获取成功率
  double get successRate {
    if (totalRuns == 0) return 0.0;
    return (successRuns / totalRuns) * 100;
  }

  /// 获取状态颜色
  Color get statusColor => status.color;

  /// 获取状态图标
  IconData get statusIcon => status.icon;

  /// 获取类型图标
  IconData get typeIcon => type.icon;

  /// 解析JSON字段
  static T _parseJsonField<T>(dynamic value) {
    if (value == null) {
      if (T == Map<String, dynamic>) return {} as T;
      if (T == List<String>) return <String>[] as T;
      return value as T;
    }
    
    if (value is String) {
      try {
        if (T == Map<String, dynamic>) {
          final Map<String, dynamic> parsed = jsonDecode(value);
          return parsed as T;
        } else if (T == List<String>) {
          final List<dynamic> parsed = jsonDecode(value);
          return parsed.cast<String>() as T;
        }
      } catch (e) {
        print('解析JSON字段失败: $e, 值: $value');
        // 对于无效的JSON，返回默认值
      }
    }
    
    // 如果value已经是正确的类型，直接返回
    if (value is Map && T == Map<String, dynamic>) {
      // 安全地转换为Map<String, dynamic>
      try {
        final Map<String, dynamic> converted = Map<String, dynamic>.from(value);
        return converted as T;
      } catch (e) {
        print('Map类型转换失败: $e');
        return {} as T;
      }
    }
    if (value is List && T == List<String>) {
      // 安全地转换为List<String>
      try {
        final List<String> converted = value.cast<String>();
        return converted as T;
      } catch (e) {
        print('List类型转换失败: $e');
        return <String>[] as T;
      }
    }
    
    // 返回默认值
    if (T == Map<String, dynamic>) return {} as T;
    if (T == List<String>) return <String>[] as T;
    return value as T;
  }



  /// 转换为JSON字符串
  static String _toJsonString(dynamic value) {
    if (value == null) return '';
    try {
      return jsonEncode(value);
    } catch (e) {
      print('转换为JSON字符串失败: $e, 值: $value');
      return '';
    }
  }
}

/// 预设的AI代理模板
class AgentTemplate {
  final String name;
  final String description;
  final AgentType type;
  final String systemPrompt;
  final List<String> suggestedTools;
  final IconData icon;

  const AgentTemplate({
    required this.name,
    required this.description,
    required this.type,
    required this.systemPrompt,
    required this.suggestedTools,
    required this.icon,
  });
}

/// 预设模板列表
class AgentTemplates {
  static const List<AgentTemplate> templates = [
    AgentTemplate(
      name: '客户服务机器人',
      description: '专业的客户服务助手，能够回答常见问题并提供帮助',
      type: AgentType.customerService,
      systemPrompt: '''你是一个专业的客户服务代表，你的职责是：

1. 友好、耐心地回答客户问题
2. 提供准确的产品和服务信息
3. 帮助解决客户遇到的问题
4. 保持专业和礼貌的态度
5. 如果无法解决问题，及时转接人工客服

请用简洁明了的语言回答，确保客户能够理解。''',
      suggestedTools: ['知识库查询', '订单查询', 'FAQ搜索'],
      icon: Icons.support_agent,
    ),
    AgentTemplate(
      name: '内容创作助手',
      description: '创意内容创作专家，帮助生成高质量的文章、文案等',
      type: AgentType.contentCreator,
      systemPrompt: '''你是一个专业的内容创作专家，擅长：

1. 撰写各种类型的文章和文案
2. 创意写作和故事创作
3. 营销文案和广告语
4. 内容编辑和优化建议
5. 多语言内容创作

请根据用户需求，创作出有吸引力、有价值的内容。注意语言的流畅性和逻辑性。''',
      suggestedTools: ['网络搜索', '图片生成', '内容分析'],
      icon: Icons.create,
    ),
    AgentTemplate(
      name: '数据分析师',
      description: '数据分析专家，帮助解读数据并提供洞察',
      type: AgentType.dataAnalyst,
      systemPrompt: '''你是一个专业的数据分析师，具备以下能力：

1. 数据解读和分析
2. 统计分析和趋势识别
3. 数据可视化建议
4. 业务洞察和决策建议
5. 报告撰写和演示

请用通俗易懂的语言解释复杂的数据概念，并提供实用的建议。''',
      suggestedTools: ['数据查询', '图表生成', '统计分析'],
      icon: Icons.analytics,
    ),
    AgentTemplate(
      name: '代码助手',
      description: '编程专家，帮助编写、调试和优化代码',
      type: AgentType.codeAssistant,
      systemPrompt: '''你是一个专业的程序员和代码专家，擅长：

1. 多种编程语言的代码编写
2. 代码审查和优化建议
3. 调试和问题排查
4. 最佳实践和设计模式
5. 技术架构建议

请提供清晰、可读的代码，并解释关键概念。确保代码符合最佳实践。''',
      suggestedTools: ['代码解释器', 'API文档查询', '版本控制'],
      icon: Icons.code,
    ),
    AgentTemplate(
      name: '研究助手',
      description: '研究专家，帮助收集信息、分析资料和总结发现',
      type: AgentType.researchAssistant,
      systemPrompt: '''你是一个专业的研究助手，具备以下能力：

1. 信息收集和整理
2. 文献综述和总结
3. 研究方法和设计建议
4. 数据分析和解释
5. 研究报告撰写

请提供准确、全面的信息，并帮助用户更好地理解研究主题。''',
      suggestedTools: ['网络搜索', '学术数据库', '文献管理'],
      icon: Icons.search,
    ),
  ];
}
