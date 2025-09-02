import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/model_provider.dart';
import '../services/log_service.dart';

class ApiTestService {
  static const Duration _timeout = Duration(seconds: 10);

  /// 测试模型提供商连接
  static Future<ApiTestResult> testProviderConnection(ModelProvider provider) async {
    final startTime = DateTime.now();
    
    try {
      // 根据提供商类型构建请求信息
      final requestInfo = _buildRequestInfo(provider);
      
      // 验证URL格式
      final url = requestInfo['url'] as String;
      if (url.isEmpty) {
        throw Exception('构建的URL为空');
      }
      
      // 检查URL是否包含重复路径
      if (url.contains('/chat/completions/chat/completions')) {
        print('⚠️ 警告: URL包含重复路径: $url');
        print('原始baseUrl: ${provider.baseUrl}');
      }
      
      // 记录API测试请求到系统日志
      final requestMethod = requestInfo['body'] != null && requestInfo['body'].isNotEmpty ? 'POST' : 'GET';
      final requestDetails = {
        'provider_name': provider.name,
        'provider_type': provider.providerType.displayName,
        'original_base_url': provider.baseUrl,
        'built_url': requestInfo['url'],
        'request_method': requestMethod,
        'request_headers': requestInfo['headers'],
        'request_body': requestInfo['body'],
        'api_key_preview': provider.apiKey?.substring(0, 8),
        'api_key_length': provider.apiKey?.length ?? 0,
      };
      
      LogService.apiCall(
        '开始API测试请求',
        details: '测试模型提供商连接: ${provider.name}',
        metadata: requestDetails,
      );
      
      // 打印详细的请求信息到控制台（调试用）
      print('');
      print('🚀 === API测试请求详情 === 🚀');
      print('📋 提供商信息:');
      print('   • 名称: ${provider.name}');
      print('   • 类型: ${provider.providerType.displayName} (${provider.providerType})');
      print('   • 原始baseUrl: ${provider.baseUrl}');
      print('   • 构建后URL: ${requestInfo['url']}');
      print('');
      print('📤 请求详情:');
      print('   • 方法: $requestMethod');
      print('   • 请求头: ${json.encode(requestInfo['headers'])}');
      if (requestInfo['body'] != null && requestInfo['body'].isNotEmpty) {
        print('   • 请求体: ${json.encode(requestInfo['body'])}');
      }
      print('');
      print('🔑 认证信息:');
      print('   • API密钥: ${provider.apiKey?.substring(0, 8)}...');
      print('   • 密钥长度: ${provider.apiKey?.length ?? 0} 字符');
      print('🚀 ================================ 🚀');
      print('');
      
      // 发送HTTP请求
      http.Response response;
      if (requestInfo['body'] != null && requestInfo['body'].isNotEmpty) {
        // POST请求（用于兼容模式）
        response = await http.post(
          Uri.parse(requestInfo['url']),
          headers: requestInfo['headers'],
          body: json.encode(requestInfo['body']),
        ).timeout(_timeout);
      } else {
        // GET请求（用于标准模式）
        response = await http.get(
          Uri.parse(requestInfo['url']),
          headers: requestInfo['headers'],
        ).timeout(_timeout);
      }
      
      final endTime = DateTime.now();
      final responseTime = endTime.difference(startTime).inMilliseconds;
      
      // 记录API测试响应到系统日志
      final responseDetails = {
        'status_code': response.statusCode,
        'response_time_ms': responseTime,
        'response_headers': response.headers.toString(),
        'response_body': response.body,
        'is_success': response.statusCode >= 200 && response.statusCode < 300,
      };
      
      LogService.apiCall(
        'API测试响应完成',
        details: '响应状态: ${response.statusCode}, 耗时: ${responseTime}ms',
        metadata: responseDetails,
      );
      
      // 打印响应信息到控制台（调试用）
      print('');
      print('📥 === API测试响应详情 === 📥');
      print('📊 响应状态:');
      print('   • 状态码: ${response.statusCode}');
      print('   • 响应时间: ${responseTime}ms');
      print('');
      print('📋 响应头:');
      print('   ${response.headers}');
      print('');
      print('📄 响应体:');
      print('   ${response.body}');
      print('📥 ================================ 📥');
      print('');
      
      // 解析响应
      final responseBody = _parseResponse(response);
      
      // 判断是否成功
      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      
      // 记录API测试最终结果到系统日志
      final resultDetails = {
        'success': isSuccess,
        'status_code': response.statusCode,
        'response_time_ms': responseTime,
        'request_url': requestInfo['url'],
        'error_message': isSuccess ? null : _getErrorMessage(responseBody),
        'provider_name': provider.name,
      };
      
      if (isSuccess) {
        LogService.info(
          'API测试成功',
          details: '模型提供商连接测试成功: ${provider.name}',
          metadata: resultDetails,
        );
      } else {
        LogService.warning(
          'API测试失败',
          details: '模型提供商连接测试失败: ${provider.name} - ${_getErrorMessage(responseBody)}',
          metadata: resultDetails,
        );
      }
      
      return ApiTestResult(
        success: isSuccess,
        statusCode: response.statusCode,
        responseBody: responseBody,
        responseTime: responseTime,
        requestUrl: requestInfo['url'],
        requestHeaders: requestInfo['headers'],
        errorMessage: isSuccess ? null : _getErrorMessage(responseBody),
      );
      
    } catch (e) {
      final endTime = DateTime.now();
      final responseTime = endTime.difference(startTime).inMilliseconds;
      
      // 记录API测试错误到系统日志
      final errorDetails = {
        'error_type': e.runtimeType.toString(),
        'error_message': e.toString(),
        'request_url': _buildRequestInfo(provider)['url'],
        'response_time_ms': responseTime,
        'provider_name': provider.name,
        'provider_type': provider.providerType.displayName,
      };
      
      LogService.error(
        'API测试失败',
        details: '测试模型提供商连接时发生错误: ${e.toString()}',
        metadata: errorDetails,
      );
      
      // 打印错误信息到控制台（调试用）
      print('');
      print('❌ === API测试错误详情 === ❌');
      print('🚨 错误信息:');
      print('   • 错误类型: ${e.runtimeType}');
      print('   • 错误详情: $e');
      print('');
      print('📍 请求信息:');
      print('   • 请求URL: ${_buildRequestInfo(provider)['url']}');
      print('   • 响应时间: ${responseTime}ms');
      print('❌ ================================ ❌');
      print('');
      
      return ApiTestResult(
        success: false,
        statusCode: 0,
        responseBody: null,
        responseTime: responseTime,
        requestUrl: _buildRequestInfo(provider)['url'],
        requestHeaders: _buildRequestInfo(provider)['headers'],
        errorMessage: e.toString(),
      );
    }
  }

  /// 构建请求信息
  static Map<String, dynamic> _buildRequestInfo(ModelProvider provider) {
    String url = '';
    Map<String, String> headers = {};
    Map<String, dynamic> body = {};

    switch (provider.providerType) {
      case ProviderType.openai:
        url = '${provider.baseUrl ?? 'https://api.openai.com'}/v1/models';
        headers = {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
        };
        break;
        
      case ProviderType.claude:
        url = '${provider.baseUrl ?? 'https://api.anthropic.com'}/v1/models';
        headers = {
          'x-api-key': provider.apiKey!,
          'Content-Type': 'application/json',
          'anthropic-version': '2023-06-01',
        };
        break;
        
      case ProviderType.gemini:
        url = '${provider.baseUrl ?? 'https://generativelanguage.googleapis.com'}/v1beta/models';
        headers = {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
        };
        break;
        
      case ProviderType.azureOpenai:
        url = '${provider.endpointUrl}/openai/deployments/${provider.deploymentName}/models?api-version=2023-05-15';
        headers = {
          'api-key': provider.apiKey!,
          'Content-Type': 'application/json',
        };
        break;
        
      case ProviderType.ollama:
        url = '${provider.serverUrl ?? 'http://localhost:11434'}/api/tags';
        headers = {
          'Content-Type': 'application/json',
        };
        break;
        
      case ProviderType.alibaba:
        // 根据阿里巴巴通义千问官方文档，支持兼容OpenAI的API格式
        // 参考：https://bailian.console.aliyun.com/
        // 如果用户配置了兼容模式的URL，使用兼容模式；否则使用标准模式
        if (provider.baseUrl != null && provider.baseUrl!.contains('compatible-mode')) {
          // 兼容OpenAI格式 - 检查baseUrl是否已经包含chat/completions
          if (provider.baseUrl!.endsWith('/chat/completions')) {
            url = provider.baseUrl!;
          } else if (provider.baseUrl!.endsWith('/')) {
            url = '${provider.baseUrl}chat/completions';
          } else {
            url = '${provider.baseUrl}/chat/completions';
          }
          headers = {
            'Authorization': 'Bearer ${provider.apiKey}',
            'Content-Type': 'application/json',
          };
          // 为POST请求准备测试数据
          body = <String, dynamic>{
            'model': 'qwen3-30b-a3b-thinking-2507',
            'messages': [
              {
                'role': 'user',
                'content': 'Hello, this is a connection test.'
              }
            ],
            'max_tokens': 10,
          };
        } else {
          // 标准DashScope格式
          url = '${provider.baseUrl ?? 'https://dashscope.aliyuncs.com'}/api/v1/models';
          headers = {
            'Authorization': 'Bearer ${provider.apiKey}',
            'Content-Type': 'application/json',
            'X-DashScope-SSE': 'disable', // 禁用流式响应
          };
        }
        break;
        
      case ProviderType.baidu:
        // 百度文心一言需要特殊处理，这里测试模型列表接口
        url = '${provider.baseUrl ?? 'https://aip.baidubce.com'}/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/completions';
        headers = {
          'Content-Type': 'application/json',
        };
        break;
        
      case ProviderType.tencent:
        url = '${provider.baseUrl ?? 'https://hunyuan.tencentcloudapi.com'}/';
        headers = {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
        };
        break;
        
      case ProviderType.zhipu:
        url = '${provider.baseUrl ?? 'https://open.bigmodel.cn'}/api/paas/v4/models';
        headers = {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
        };
        break;
        
      case ProviderType.moonshot:
        url = '${provider.baseUrl ?? 'https://api.moonshot.cn'}/v1/models';
        headers = {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
        };
        break;
        
      default:
        url = '${provider.baseUrl ?? 'https://api.example.com'}/v1/models';
        headers = {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
        };
    }

    return {
      'url': url,
      'headers': headers,
      'body': body,
    };
  }

  /// 解析响应
  static Map<String, dynamic>? _parseResponse(http.Response response) {
    try {
      if (response.body.isNotEmpty) {
        return json.decode(response.body);
      }
    } catch (e) {
      // 如果JSON解析失败，返回原始响应
      return {'raw_response': response.body};
    }
    return null;
  }

  /// 获取错误信息
  static String _getErrorMessage(Map<String, dynamic>? responseBody) {
    if (responseBody == null) return '未知错误';
    
    // 尝试从不同提供商的错误格式中提取错误信息
    if (responseBody.containsKey('error')) {
      final error = responseBody['error'];
      if (error is Map) {
        if (error.containsKey('message')) {
          return error['message'];
        }
        if (error.containsKey('type')) {
          return error['type'];
        }
      }
      return error.toString();
    }
    
    if (responseBody.containsKey('message')) {
      return responseBody['message'];
    }
    
    if (responseBody.containsKey('msg')) {
      return responseBody['msg'];
    }
    
    return responseBody.toString();
  }
}

/// API测试结果
class ApiTestResult {
  final bool success;
  final int statusCode;
  final Map<String, dynamic>? responseBody;
  final int responseTime;
  final String requestUrl;
  final Map<String, String> requestHeaders;
  final String? errorMessage;

  ApiTestResult({
    required this.success,
    required this.statusCode,
    this.responseBody,
    required this.responseTime,
    required this.requestUrl,
    required this.requestHeaders,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'statusCode': statusCode,
      'responseBody': responseBody,
      'responseTime': responseTime,
      'requestUrl': requestUrl,
      'requestHeaders': requestHeaders,
      'errorMessage': errorMessage,
    };
  }
}
