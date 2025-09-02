import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../models/ai_agent.dart';
import '../models/system_log.dart';
import '../models/knowledge_base.dart';
import 'database_service.dart';
import 'log_service.dart';
import 'rag_service.dart';
import 'file_upload_service.dart';

/// AI代理服务类
class AIAgentService {
  static const Duration _timeout = Duration(seconds: 120); // 增加到2分钟
  static const int _maxRetries = 3; // 最大重试次数
  
  /// 运行AI代理
  static Future<AgentRunResult> runAgent(
    AIAgent agent,
    String userMessage, {
    String? userId,
    String? userName,
    int? knowledgeBaseId,
    List<File>? files,
  }) async {
    final startTime = DateTime.now();
    
    try {
      LogService.info(
        '开始运行AI代理',
        details: '代理: ${agent.name}, 用户消息: $userMessage',
        userId: userId,
        userName: userName,
        category: LogCategory.workflow,
      );
      
      // 如果指定了知识库，先进行检索增强
      String enhancedMessage = userMessage;
      if (knowledgeBaseId != null) {
        try {
          // 获取知识库配置
          final kbData = await DatabaseService.getKnowledgeBase(knowledgeBaseId);
          if (kbData != null) {
            final kb = KnowledgeBase.fromJson(kbData);
            final enhancedPrompt = await RAGService.enhanceResponseWithKnowledgeBase(
              userMessage,
              knowledgeBaseId,
              kb.engineConfig,
            );
            enhancedMessage = enhancedPrompt;
            
            LogService.info(
              '知识库检索增强完成',
              details: '知识库: ${kb.name}, 原始消息长度: ${userMessage.length}, 增强后长度: ${enhancedMessage.length}',
              userId: userId,
              userName: userName,
              category: LogCategory.workflow,
            );
          }
        } catch (e) {
          LogService.error(
            '知识库检索增强失败',
            details: '知识库ID: $knowledgeBaseId, 错误: $e',
            userId: userId,
            userName: userName,
            category: LogCategory.workflow,
          );
          // 继续使用原始消息
        }
      }
      
      // 处理文件内容
      List<String> fileContents = [];
      print('=== AI代理服务文件处理开始 ===');
      print('传入文件数量: ${files?.length ?? 0}');
      
      if (files != null && files.isNotEmpty) {
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          print('处理文件 $i: ${path.basename(file.path)}');
          print('文件路径: ${file.path}');
          print('文件大小: ${await file.length()} bytes');
          
          try {
            print('开始调用FileUploadService.processFile...');
            final processResult = await FileUploadService.processFile(
              file,
              agent.name,
            );
            
            print('文件处理结果:');
            print('- 成功: ${processResult.success}');
            print('- 错误: ${processResult.error}');
            print('- 内容长度: ${processResult.fileContent?.length ?? 0}');
            
            if (processResult.success && processResult.fileContent != null) {
              fileContents.add(processResult.fileContent!);
              print('文件内容已添加到列表');
              LogService.info(
                '文件处理成功',
                details: '文件: ${path.basename(file.path)}, 内容长度: ${processResult.fileContent!.length}',
                userId: userId,
                userName: userName,
                category: LogCategory.workflow,
              );
            } else {
              print('文件处理失败: ${processResult.error}');
              LogService.error(
                '文件处理失败',
                details: '文件: ${path.basename(file.path)}, 错误: ${processResult.error}',
                userId: userId,
                userName: userName,
                category: LogCategory.workflow,
              );
            }
          } catch (e) {
            print('文件处理异常: $e');
            LogService.error(
              '文件处理异常',
              details: '文件: ${path.basename(file.path)}, 异常: $e',
              userId: userId,
              userName: userName,
              category: LogCategory.workflow,
            );
          }
        }
      }
      
      print('文件处理完成，内容数量: ${fileContents.length}');
      
      // 根据提供商类型构建请求
      final requestInfo = await _buildRequest(agent, enhancedMessage, fileContents);
      
      final traceId = LogService.newTraceId();
      final spanId = LogService.newSpanId();
      LogService.apiCall(
        '发送AI代理请求',
        details: '代理: ${agent.name}, 提供商: ${agent.providerName}',
        userId: userId,
        userName: userName,
        metadata: LogService.withTrace(traceId: traceId, spanId: spanId, metadata: {
          'agent_id': agent.id,
          'agent_name': agent.name,
          'provider': agent.providerName,
          'model': agent.modelName,
          'request_url': requestInfo['url'],
          'request_headers': requestInfo['headers_preview'] ?? requestInfo['headers'],
          'request_body': requestInfo['body'],
        }),
      );
      
      // 发送HTTP请求（带重试机制）
      http.Response? response;
      Exception? lastException;
      
      for (int attempt = 1; attempt <= _maxRetries; attempt++) {
        try {
          print('发送HTTP请求，第 $attempt 次尝试...');
          response = await http.post(
            Uri.parse(requestInfo['url']),
            headers: requestInfo['headers'],
            body: jsonEncode(requestInfo['body']),
          ).timeout(_timeout);
          
          // 如果成功，跳出重试循环
          break;
        } catch (e) {
          lastException = e as Exception;
          print('第 $attempt 次请求失败: $e');
          
          if (attempt < _maxRetries) {
            // 等待一段时间后重试
            final delay = Duration(seconds: attempt * 2); // 递增延迟
            print('等待 ${delay.inSeconds} 秒后重试...');
            await Future.delayed(delay);
          }
        }
      }
      
      // 如果所有重试都失败了
      if (response == null) {
        throw lastException ?? Exception('所有重试都失败了');
      }
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      LogService.apiCall(
        'AI代理响应完成',
        details: '代理: ${agent.name}, 状态码: ${response.statusCode}, 耗时: ${duration.inMilliseconds}ms',
        userId: userId,
        userName: userName,
        metadata: LogService.withTrace(traceId: traceId, spanId: spanId, metadata: {
          'agent_id': agent.id,
          'agent_name': agent.name,
          'response_status': response.statusCode,
          'response_headers': response.headers,
          'response_body': response.body,
          'duration_ms': duration.inMilliseconds,
        }),
      );
      
      if (response.statusCode == 200) {
        // 解析响应
        final responseData = jsonDecode(response.body);
        final aiResponse = _parseResponse(responseData, agent.providerName);
        
        // 更新代理运行状态
        await _updateAgentRunStatus(agent, true, duration);
        
        LogService.info(
          'AI代理运行成功',
          details: '代理: ${agent.name}, 响应时间: ${duration.inMilliseconds}ms',
          userId: userId,
          userName: userName,
          category: LogCategory.workflow,
        );
        
        return AgentRunResult(
          success: true,
          response: aiResponse,
          duration: duration,
          tokenUsage: _extractTokenUsage(responseData),
          cost: _calculateCost(responseData, agent.providerName),
        );
      } else {
        // 处理错误响应
        final errorMessage = _parseErrorMessage(response.body, response.statusCode);
        
        LogService.error(
          'AI代理运行失败',
          details: '代理: ${agent.name}, 状态码: ${response.statusCode}, 错误: $errorMessage',
          userId: userId,
          userName: userName,
          category: LogCategory.workflow,
        );
        
        // 更新代理运行状态
        await _updateAgentRunStatus(agent, false, duration);
        
        return AgentRunResult(
          success: false,
          error: errorMessage,
          duration: duration,
        );
      }
    } catch (e) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      LogService.error(
        'AI代理运行异常',
        details: '代理: ${agent.name}, 异常: $e',
        userId: userId,
        userName: userName,
        category: LogCategory.workflow,
      );
      
      // 更新代理运行状态
      await _updateAgentRunStatus(agent, false, duration);
      
      return AgentRunResult(
        success: false,
        error: '运行异常: $e',
        duration: duration,
      );
    }
  }
  
  /// 构建API请求
  static Future<Map<String, dynamic>> _buildRequest(
    AIAgent agent,
    String userMessage,
    List<String> fileContents,
  ) async {
    // 获取模型提供商的配置信息
    final providers = await DatabaseService.getAllModelProviders();
    Map<String, dynamic> provider = providers.firstWhere(
      (p) => p['name'] == agent.providerName,
      orElse: () => {},
    );
    
    // 若按名称未找到，回退到全局默认提供商
    if (provider.isEmpty) {
      provider = providers.firstWhere(
        (p) => (p['is_default'] as int? ?? 0) == 1,
        orElse: () => {},
      );
    }
    
    if (provider.isEmpty) {
      // 如果只有一个配置，直接使用它作为兜底
      if (providers.length == 1) {
        provider = providers.first;
      } else {
        final available = providers.map((p) => p['name']).join(', ');
        throw Exception('未找到模型提供商配置: ${agent.providerName}，可用配置: [$available]');
      }
    }
    
    final apiKey = provider['api_key'] as String?;
    final baseUrl = provider['base_url'] as String?;
    
    if (apiKey == null || baseUrl == null) {
      throw Exception('模型提供商配置不完整: ${agent.providerName}');
    }
    
    // 构建请求头
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    
    // 构建请求体
    var body = <String, dynamic>{
      'model': agent.modelName,
      'messages': [
        {
          'role': 'system',
          'content': agent.systemPrompt,
        },
        {
          'role': 'user',
          'content': userMessage,
        },
      ],
      'max_tokens': agent.modelConfig['max_tokens'] ?? 1000,
      'temperature': agent.modelConfig['temperature'] ?? 0.7,
    };

    // 如果有文件内容，添加到请求中
    print('=== 构建最终消息 ===');
    print('原始用户消息: "$userMessage"');
    print('文件内容数量: ${fileContents.length}');
    
    if (fileContents.isNotEmpty) {
      if (agent.providerName == '阿里巴巴 (通义千问)') {
        // 通义千问多模态格式
        print('使用通义千问多模态格式...');
        final content = <Map<String, dynamic>>[];
        
        // 添加文本内容
        if (userMessage.isNotEmpty) {
          content.add({'text': userMessage});
        }
        
        // 添加文件内容
        for (int i = 0; i < fileContents.length; i++) {
          final fileContent = fileContents[i];
          print('添加文件内容 $i, 长度: ${fileContent.length}');
          
          // 检查是否为base64格式
          if (fileContent.startsWith('data:')) {
            // 所有base64格式都作为图片处理（通义千问支持）
            content.add({'image': fileContent});
            print('添加base64文件内容');
          } else {
            // 文本内容
            content.add({'text': fileContent});
            print('添加文本内容');
          }
        }
        
        body['messages'][1]['content'] = content;
        print('通义千问多模态内容构建完成');
      } else {
        // 其他提供商使用文本格式
        print('使用文本格式...');
        String enhancedMessage = userMessage;
        
        // 添加文件内容到消息中
        for (int i = 0; i < fileContents.length; i++) {
          final fileContent = fileContents[i];
          print('添加文件内容 $i, 长度: ${fileContent.length}');
          enhancedMessage += '\n\n--- 文件内容 ${i + 1} ---\n$fileContent';
        }
        
        // 更新用户消息
        body['messages'][1]['content'] = enhancedMessage;
        print('最终消息长度: ${enhancedMessage.length}');
        print('最终消息预览: ${enhancedMessage.substring(0, enhancedMessage.length > 200 ? 200 : enhancedMessage.length)}...');
      }
    } else {
      print('没有文件内容，使用原始消息');
    }
    
    // 根据提供商类型调整请求格式
    String url = baseUrl;
    switch (agent.providerName) {
      case '阿里巴巴 (通义千问)':
        // 检查是否包含base64内容，决定使用哪个API
        bool hasBase64Content = false;
        if (body['messages'][1]['content'] is List) {
          final content = body['messages'][1]['content'] as List;
          hasBase64Content = content.any((item) => item is Map && item['image'] != null);
        }
        
        if (hasBase64Content) {
          // 使用多模态API
          print('检测到base64内容，使用多模态API');
          if (baseUrl.endsWith('/services/aigc/multimodal-generation/generation')) {
            url = baseUrl;
          } else if (baseUrl.endsWith('/')) {
            url = '${baseUrl}services/aigc/multimodal-generation/generation';
          } else {
            url = '$baseUrl/services/aigc/multimodal-generation/generation';
          }
          
          // 调整请求体格式为多模态格式
          body = {
            'model': agent.modelName,
            'input': {
              'messages': body['messages']
            }
          };
        } else {
          // 使用文本API
          print('使用文本API');
          if (baseUrl.endsWith('/chat/completions')) {
            url = baseUrl;
          } else if (baseUrl.endsWith('/')) {
            url = '${baseUrl}chat/completions';
          } else {
            url = '$baseUrl/chat/completions';
          }
        }
        break;
      case 'OpenAI':
        // OpenAI标准格式
        break;
      case 'Anthropic Claude':
        // Claude格式调整
        body['messages'] = [
          {
            'role': 'user',
            'content': '${agent.systemPrompt}\n\n用户: $userMessage\n\n助手:',
          },
        ];
        break;
      case 'Google Gemini':
        // Gemini格式调整
        body['contents'] = [
          {
            'parts': [
              {
                'text': '${agent.systemPrompt}\n\n用户: $userMessage',
              },
            ],
          },
        ];
        // 移除messages字段
        body.remove('messages');
        break;
    }
    
    // 构造脱敏后的headers输出（预览与实际分离，避免误用）
    final safeHeaders = <String, String>{
      'Content-Type': headers['Content-Type'] ?? 'application/json',
    };
    if (headers['Authorization'] != null) {
      final token = (headers['Authorization'] as String);
      final tail = token.length >= 8 ? token.substring(token.length - 8) : token;
      safeHeaders['Authorization'] = 'Bearer ****$tail';
    }

    final info = {
      'url': url,
      'headers': headers,
      'headers_preview': safeHeaders,
      'body': body,
    };
    // 关键请求信息记录日志
    LogService.apiCall(
      '构建请求信息完成',
      details: 'provider: ${agent.providerName}, model: ${agent.modelName}',
      metadata: info,
    );
    return info;
  }
  
  /// 解析API响应
  static String _parseResponse(Map<String, dynamic> responseData, String providerName) {
    switch (providerName) {
      case '阿里巴巴 (通义千问)':
      case 'OpenAI':
        return responseData['choices']?[0]?['message']?['content'] ?? '无响应内容';
      case 'Anthropic Claude':
        return responseData['content']?[0]?['text'] ?? '无响应内容';
      case 'Google Gemini':
        return responseData['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '无响应内容';
      default:
        return responseData['choices']?[0]?['message']?['content'] ?? '无响应内容';
    }
  }
  
  /// 解析错误信息
  static String _parseErrorMessage(String responseBody, int statusCode) {
    try {
      final errorData = jsonDecode(responseBody);
      return errorData['error']?['message'] ?? 'HTTP错误: $statusCode';
    } catch (e) {
      return 'HTTP错误: $statusCode - $responseBody';
    }
  }
  
  /// 提取Token使用量
  static Map<String, dynamic> _extractTokenUsage(Map<String, dynamic> responseData) {
    final usage = responseData['usage'];
    if (usage != null) {
      return {
        'prompt_tokens': usage['prompt_tokens'] ?? 0,
        'completion_tokens': usage['completion_tokens'] ?? 0,
        'total_tokens': usage['total_tokens'] ?? 0,
      };
    }
    return {
      'prompt_tokens': 0,
      'completion_tokens': 0,
      'total_tokens': 0,
    };
  }
  
  /// 计算成本
  static double _calculateCost(Map<String, dynamic> responseData, String providerName) {
    // 这里可以根据不同提供商的定价策略计算成本
    // 暂时返回0，后续可以扩展
    return 0.0;
  }
  
  /// 更新代理运行状态
  static Future<void> _updateAgentRunStatus(
    AIAgent agent,
    bool success,
    Duration duration,
  ) async {
    if (agent.id == null) return;
    
    try {
      final currentAgent = await DatabaseService.getAIAgentById(agent.id!);
      if (currentAgent == null) return;
      
      final totalRuns = (currentAgent['total_runs'] as int?) ?? 0;
      final successRuns = (currentAgent['success_runs'] as int?) ?? 0;
      final avgResponseTime = (currentAgent['average_response_time'] as num?)?.toDouble() ?? 0.0;
      
      // 计算新的平均值
      final newTotalRuns = totalRuns + 1;
      final newSuccessRuns = successRuns + (success ? 1 : 0);
      final newAvgResponseTime = (avgResponseTime * totalRuns + duration.inMilliseconds) / newTotalRuns;
      
      await DatabaseService.updateAIAgentRunStatus(
        agent.id!,
        lastRunAt: DateTime.now(),
        totalRuns: newTotalRuns,
        successRuns: newSuccessRuns,
        averageResponseTime: newAvgResponseTime,
      );
    } catch (e) {
      print('更新代理运行状态失败: $e');
    }
  }
  
  /// 获取代理运行统计
  static Future<Map<String, dynamic>> getAgentStats(int agentId) async {
    try {
      final agent = await DatabaseService.getAIAgentById(agentId);
      if (agent == null) return {};
      
      return {
        'total_runs': agent['total_runs'] ?? 0,
        'success_runs': agent['success_runs'] ?? 0,
        'success_rate': agent['total_runs'] != null && agent['total_runs']! > 0
            ? (agent['success_runs']! / agent['total_runs']!) * 100
            : 0.0,
        'average_response_time': agent['average_response_time'] ?? 0.0,
        'total_token_cost': agent['total_token_cost'] ?? 0.0,
        'last_run_at': agent['last_run_at'],
      };
    } catch (e) {
      print('获取代理统计失败: $e');
      return {};
    }
  }
  
  /// 批量运行代理
  static Future<List<AgentRunResult>> runAgentsBatch(
    List<AIAgent> agents,
    String userMessage, {
    String? userId,
    String? userName,
  }) async {
    final results = <AgentRunResult>[];
    
    for (final agent in agents) {
      try {
        final result = await runAgent(
          agent,
          userMessage,
          userId: userId,
          userName: userName,
        );
        results.add(result);
      } catch (e) {
        results.add(AgentRunResult(
          success: false,
          error: '运行失败: $e',
          duration: Duration.zero,
        ));
      }
    }
    
    return results;
  }
}

/// AI代理运行结果
class AgentRunResult {
  final bool success;
  final String? response;
  final String? error;
  final Duration duration;
  final Map<String, dynamic>? tokenUsage;
  final double? cost;
  
  AgentRunResult({
    required this.success,
    this.response,
    this.error,
    required this.duration,
    this.tokenUsage,
    this.cost,
  });
  
  /// 是否成功
  bool get isSuccess => success;
  
  /// 获取响应文本
  String get responseText => response ?? '';
  
  /// 获取错误信息
  String get errorMessage => error ?? '';
  
  /// 获取响应时间（毫秒）
  int get responseTimeMs => duration.inMilliseconds;
  
  /// 获取Token使用量
  int get totalTokens => tokenUsage?['total_tokens'] ?? 0;
}
