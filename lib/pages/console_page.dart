import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/system_log.dart';
import '../services/database_service.dart';
import '../services/log_service.dart';
import '../providers/theme_provider.dart';

class ConsolePage extends StatefulWidget {
  const ConsolePage({Key? key}) : super(key: key);

  @override
  State<ConsolePage> createState() => _ConsolePageState();
}

class _ConsolePageState extends State<ConsolePage> {
  List<SystemLog> _logs = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // 过滤选项
  LogLevel? _selectedLevel;
  LogCategory? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  
  // 分页
  int _currentPage = 0;
  static const int _pageSize = 50;
  bool _hasMore = true;
  
  // 统计信息
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadStats();
    
    // 记录控制台页面访问日志
    LogService.info(
      '系统控制台页面加载',
      details: '用户查看系统日志界面',
      category: LogCategory.user,
      userId: 'admin',
      userName: 'Admin',
    );
  }

  Future<void> _loadLogs({bool refresh = false}) async {
    try {
      setState(() {
        if (refresh) {
          _currentPage = 0;
          _hasMore = true;
        }
        _isLoading = true;
        _errorMessage = null;
      });

      final logsData = await DatabaseService.getAllSystemLogs(
        limit: _pageSize,
        offset: _currentPage * _pageSize,
        level: _selectedLevel,
        category: _selectedCategory,
        startDate: _startDate,
        endDate: _endDate,
      );

      final newLogs = logsData.map((data) => SystemLog.fromMap(data)).toList();
      
      setState(() {
        if (refresh) {
          _logs = newLogs;
        } else {
          _logs.addAll(newLogs);
        }
        _hasMore = newLogs.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载日志失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await DatabaseService.getSystemLogStats();
      setState(() {
        _stats = stats;
      });
    } catch (e) {
      print('加载统计信息失败: $e');
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清理'),
        content: const Text('确定要清理所有日志吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清理'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final deletedCount = await DatabaseService.clearSystemLogs(
          level: _selectedLevel,
          category: _selectedCategory,
          beforeDate: _endDate,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已清理 $deletedCount 条日志')),
          );
          _loadLogs(refresh: true);
          _loadStats();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清理日志失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteLog(SystemLog log) async {
    try {
      await DatabaseService.deleteSystemLog(log.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日志已删除')),
        );
        _loadLogs(refresh: true);
        _loadStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除日志失败: $e')),
        );
      }
    }
  }

  void _showLogDetails(SystemLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('日志详情 - ${log.level.displayName}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('级别', log.level.displayName),
              _buildDetailRow('类别', log.category.displayName),
              _buildDetailRow('消息', log.message),
              if (log.details != null) _buildDetailRow('详情', log.details!),
              if (log.userName != null) _buildDetailRow('用户', log.userName!),
              if (log.ipAddress != null) _buildDetailRow('IP地址', log.ipAddress!),
              if (log.userAgent != null) _buildDetailRow('用户代理', log.userAgent!),
              _buildDetailRow('时间', _formatDateTime(log.timestamp)),
              if (log.metadata != null) _buildMetadataSection(log.metadata!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection(Map<String, dynamic> metadata) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        
        // 提供商信息
        if (metadata.containsKey('provider_name')) ...[
          _buildSectionTitle('🏢 提供商信息', Colors.blue),
          const SizedBox(height: 8),
          _buildMetadataRow('提供商名称', metadata['provider_name']),
          if (metadata.containsKey('provider_type')) 
            _buildMetadataRow('提供商类型', metadata['provider_type']),
          if (metadata.containsKey('original_base_url')) 
            _buildMetadataRow('原始Base URL', metadata['original_base_url']),
          if (metadata.containsKey('api_key_preview')) 
            _buildMetadataRow('API密钥', metadata['api_key_preview']),
          if (metadata.containsKey('api_key_length')) 
            _buildMetadataRow('密钥长度', '${metadata['api_key_length']} 字符'),
        ],
        
        // 请求详情
        if (_hasRequestInfo(metadata)) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('📤 请求详情', Colors.green),
          const SizedBox(height: 8),
          if (metadata.containsKey('built_url') || metadata.containsKey('request_url')) 
            _buildMetadataRow('请求URL', metadata['built_url'] ?? metadata['request_url']),
          if (metadata.containsKey('request_method')) 
            _buildMetadataRow('请求方法', metadata['request_method']),
          if (metadata.containsKey('request_headers')) 
            _buildMetadataRow('请求头', metadata['request_headers']),
          if (metadata.containsKey('request_body') && metadata['request_body'] != null && metadata['request_body'].toString().isNotEmpty) 
            _buildMetadataRow('请求体', metadata['request_body']),
        ],
        
        // 响应详情
        if (_hasResponseInfo(metadata)) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('📥 响应详情', Colors.orange),
          const SizedBox(height: 8),
          if (metadata.containsKey('status_code')) 
            _buildMetadataRow('状态码', metadata['status_code']),
          if (metadata.containsKey('response_time_ms')) 
            _buildMetadataRow('响应时间', '${metadata['response_time_ms']} ms'),
          if (metadata.containsKey('response_headers')) 
            _buildMetadataRow('响应头', metadata['response_headers']),
          if (metadata.containsKey('response_body')) 
            _buildMetadataRow('响应体', metadata['response_body']),
          if (metadata.containsKey('is_success')) 
            _buildMetadataRow('是否成功', metadata['is_success'] ? '是' : '否'),
        ],
        
        // 错误信息
        if (_hasErrorInfo(metadata)) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('❌ 错误信息', Colors.red),
          const SizedBox(height: 8),
          if (metadata.containsKey('error_type')) 
            _buildMetadataRow('错误类型', metadata['error_type']),
          if (metadata.containsKey('error_message')) 
            _buildMetadataRow('错误详情', metadata['error_message']),
          if (metadata.containsKey('error')) 
            _buildMetadataRow('错误信息', metadata['error']),
        ],
        
        // 其他元数据
        if (_hasOtherMetadata(metadata)) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('📋 其他信息', Colors.grey),
          const SizedBox(height: 8),
          ...metadata.entries.where((entry) => !_isKnownMetadataKey(entry.key)).map((entry) {
            return _buildMetadataRow(entry.key, entry.value);
          }).toList(),
        ],
      ],
    );
  }
  
  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: color,
      ),
    );
  }
  
  bool _hasRequestInfo(Map<String, dynamic> metadata) {
    return metadata.containsKey('built_url') || 
           metadata.containsKey('request_url') || 
           metadata.containsKey('request_method') || 
           metadata.containsKey('request_headers') || 
           metadata.containsKey('request_body');
  }
  
  bool _hasResponseInfo(Map<String, dynamic> metadata) {
    return metadata.containsKey('status_code') || 
           metadata.containsKey('response_time_ms') || 
           metadata.containsKey('response_headers') || 
           metadata.containsKey('response_body') || 
           metadata.containsKey('is_success');
  }
  
  bool _hasErrorInfo(Map<String, dynamic> metadata) {
    return metadata.containsKey('error_type') || 
           metadata.containsKey('error_message') || 
           metadata.containsKey('error');
  }
  
  bool _hasOtherMetadata(Map<String, dynamic> metadata) {
    return metadata.entries.any((entry) => !_isKnownMetadataKey(entry.key));
  }
  
  bool _isKnownMetadataKey(String key) {
    const knownKeys = {
      'provider_name', 'provider_type', 'original_base_url', 'api_key_preview', 'api_key_length',
      'built_url', 'request_url', 'request_method', 'request_headers', 'request_body',
      'status_code', 'response_time_ms', 'response_headers', 'response_body', 'is_success',
      'error_type', 'error_message', 'error'
    };
    return knownKeys.contains(key);
  }

  Widget _buildMetadataRow(String label, dynamic value) {
    String displayValue = '';
    
    if (value is Map) {
      displayValue = _formatJsonString(value);
    } else if (value is List) {
      displayValue = _formatJsonString(value);
    } else {
      displayValue = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatMetadataLabel(label),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () => _copyToClipboard(displayValue, label),
                tooltip: '复制',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: SelectableText(
              displayValue,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatJsonString(dynamic value) {
    try {
      if (value is String) {
        // 尝试解析JSON字符串并格式化
        final decoded = json.decode(value);
        const encoder = JsonEncoder.withIndent('  ');
        return encoder.convert(decoded);
      } else {
        // 直接格式化对象
        const encoder = JsonEncoder.withIndent('  ');
        return encoder.convert(value);
      }
    } catch (e) {
      // 如果不是有效的JSON，返回原始字符串
      return value.toString();
    }
  }
  
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制 $label 到剪贴板'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatMetadataLabel(String label) {
    switch (label) {
      // 请求相关
      case 'request_url':
      case 'built_url':
        return '请求URL';
      case 'request_method':
        return '请求方法';
      case 'request_headers':
        return '请求头';
      case 'request_body':
        return '请求体';
      
      // 响应相关
      case 'response_status':
        return '响应状态';
      case 'status_code':
      case 'response_status_code':
        return '响应状态码';
      case 'response_body':
        return '响应体';
      case 'response_time_ms':
        return '响应时间(ms)';
      case 'response_headers':
        return '响应头';
      case 'is_success':
      case 'success':
        return '是否成功';
      
      // 提供商相关
      case 'provider_name':
        return '提供商名称';
      case 'provider_type':
        return '提供商类型';
      case 'original_base_url':
        return '原始Base URL';
      case 'api_key_preview':
        return 'API密钥预览';
      case 'api_key_length':
        return 'API密钥长度';
      
      // 错误相关
      case 'error':
        return '错误信息';
      case 'error_type':
        return '错误类型';
      case 'error_message':
        return '错误详情';
      
      default:
        // 将下划线转换为空格并首字母大写
        return label.split('_').map((word) => 
          word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统控制台'),
        backgroundColor: themeProvider.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _loadLogs(refresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
          IconButton(
            onPressed: _clearLogs,
            icon: const Icon(Icons.clear_all),
            tooltip: '清理日志',
          ),
        ],
      ),
      body: Column(
        children: [
          // 统计信息卡片
          _buildStatsCard(themeProvider),
          
          // 过滤选项
          _buildFilterSection(themeProvider),
          
          // 日志列表
          Expanded(
            child: _buildLogsList(themeProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeProvider.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem('总日志数', '${_stats['total'] ?? 0}', Icons.list),
          ),
          Expanded(
            child: _buildStatItem('今日日志', '${_stats['today'] ?? 0}', Icons.today),
          ),
          Expanded(
            child: _buildStatItem('错误日志', '${_getErrorCount()}', Icons.error),
          ),
          Expanded(
            child: _buildStatItem('警告日志', '${_getWarningCount()}', Icons.warning),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  int _getErrorCount() {
    try {
      final byLevel = _stats['byLevel'] as List?;
      if (byLevel != null) {
        final errorItem = byLevel.firstWhere(
          (item) => item['level'] == 'error',
          orElse: () => {'count': 0},
        );
        return errorItem['count'] as int;
      }
    } catch (e) {}
    return 0;
  }

  int _getWarningCount() {
    try {
      final byLevel = _stats['byLevel'] as List?;
      if (byLevel != null) {
        final warningItem = byLevel.firstWhere(
          (item) => item['level'] == 'warning',
          orElse: () => {'count': 0},
        );
        return warningItem['count'] as int;
      }
    } catch (e) {}
    return 0;
  }

  Widget _buildFilterSection(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeProvider.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '过滤选项',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: themeProvider.textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // 日志级别过滤
              Expanded(
                child: DropdownButtonFormField<LogLevel?>(
                  value: _selectedLevel,
                  decoration: const InputDecoration(
                    labelText: '日志级别',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部')),
                    ...LogLevel.values.map((level) => DropdownMenuItem(
                      value: level,
                      child: Text(level.displayName),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedLevel = value;
                    });
                    _loadLogs(refresh: true);
                  },
                ),
              ),
              const SizedBox(width: 16),
              // 日志类别过滤
              Expanded(
                child: DropdownButtonFormField<LogCategory?>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: '日志类别',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部')),
                    ...LogCategory.values.map((category) => DropdownMenuItem(
                      value: category,
                      child: Text(category.displayName),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                    _loadLogs(refresh: true);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(ThemeProvider themeProvider) {
    if (_isLoading && _logs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadLogs(refresh: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              '暂无日志',
              style: TextStyle(
                fontSize: 18,
                color: themeProvider.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _logs.length) {
          return _buildLoadMoreButton(themeProvider);
        }
        return _buildLogItem(_logs[index], themeProvider);
      },
    );
  }

  Widget _buildLogItem(SystemLog log, ThemeProvider themeProvider) {
    final levelColor = _getLevelColor(log.level);
    final categoryColor = _getCategoryColor(log.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: levelColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            _getLevelIcon(log.level),
            color: levelColor,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: levelColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                log.level.displayName,
                style: TextStyle(
                  color: levelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                log.category.displayName,
                style: TextStyle(
                  color: categoryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              log.message,
              style: TextStyle(color: themeProvider.textColor),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (log.userName != null) ...[
                  Icon(Icons.person, size: 14, color: themeProvider.textSecondaryColor),
                  const SizedBox(width: 4),
                  Text(
                    log.userName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: themeProvider.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Icon(Icons.schedule, size: 14, color: themeProvider.textSecondaryColor),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(log.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: themeProvider.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info),
                  SizedBox(width: 8),
                  Text('查看详情'),
                ],
              ),
            ),
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
          onSelected: (value) {
            if (value == 'details') {
              _showLogDetails(log);
            } else if (value == 'delete') {
              _deleteLog(log);
            }
          },
        ),
        onTap: () => _showLogDetails(log),
      ),
    );
  }

  Widget _buildLoadMoreButton(ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _hasMore ? () {
            setState(() {
              _currentPage++;
            });
            _loadLogs();
          } : null,
          child: Text(_hasMore ? '加载更多' : '没有更多了'),
        ),
      ),
    );
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.cyan;
      case LogLevel.info:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.critical:
        return Colors.purple;
    }
  }

  Color _getCategoryColor(LogCategory category) {
    switch (category) {
      case LogCategory.system:
        return Colors.blue;
      case LogCategory.user:
        return Colors.green;
      case LogCategory.database:
        return Colors.orange;
      case LogCategory.api:
        return Colors.cyan;
      case LogCategory.security:
        return Colors.red;
      case LogCategory.model:
        return Colors.purple;
      case LogCategory.workflow:
        return Colors.white;
      case LogCategory.other:
        return Colors.grey;
    }
  }

  IconData _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Icons.bug_report;
      case LogLevel.info:
        return Icons.info;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.error:
        return Icons.error;
      case LogLevel.critical:
        return Icons.error_outline;
    }
  }
}
