import '../models/system_log.dart';
import 'database_service.dart';

class LogService {
  static const String _defaultUserId = 'system';
  static const String _defaultUserName = 'System';

  // ===== Trace/Span 工具 =====
  static String newTraceId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return now.toRadixString(16);
  }

  static String newSpanId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now.toRadixString(36);
  }

  static Map<String, dynamic> withTrace({
    String? traceId,
    String? spanId,
    Map<String, dynamic>? metadata,
  }) {
    final map = <String, dynamic>{};
    if (metadata != null) map.addAll(metadata);
    if (traceId != null) map['trace_id'] = traceId;
    if (spanId != null) map['span_id'] = spanId;
    return map;
  }

  // 记录调试日志
  static Future<void> debug(String message, {
    LogCategory category = LogCategory.system,
    String? details,
    String? userId,
    String? userName,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      LogLevel.debug,
      category,
      message,
      details: details,
      userId: userId,
      userName: userName,
      metadata: metadata,
    );
  }

  // 记录信息日志
  static Future<void> info(String message, {
    LogCategory category = LogCategory.system,
    String? details,
    String? userId,
    String? userName,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      LogLevel.info,
      category,
      message,
      details: details,
      userId: userId,
      userName: userName,
      metadata: metadata,
    );
  }

  // 记录警告日志
  static Future<void> warning(String message, {
    LogCategory category = LogCategory.system,
    String? details,
    String? userId,
    String? userName,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      LogLevel.warning,
      category,
      message,
      details: details,
      userId: userId,
      userName: userName,
      metadata: metadata,
    );
  }

  // 记录错误日志
  static Future<void> error(String message, {
    LogCategory category = LogCategory.system,
    String? details,
    String? userId,
    String? userName,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      LogLevel.error,
      category,
      message,
      details: details,
      userId: userId,
      userName: userName,
      metadata: metadata,
    );
  }

  // 记录严重错误日志
  static Future<void> critical(String message, {
    LogCategory category = LogCategory.system,
    String? details,
    String? userId,
    String? userName,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      LogLevel.critical,
      category,
      message,
      details: details,
      userId: userId,
      userName: userName,
      metadata: metadata,
    );
  }

  // 记录用户操作日志
  static Future<void> userAction(String message, {
    String? details,
    required String userId,
    required String userName,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      LogLevel.info,
      LogCategory.user,
      message,
      details: details,
      userId: userId,
      userName: userName,
      metadata: metadata,
    );
  }

  // 记录数据库操作日志
  static Future<void> databaseOperation(String message, {
    String? details,
    String? userId,
    String? userName,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      LogLevel.info,
      LogCategory.database,
      message,
      details: details,
      userId: userId,
      userName: userName,
      metadata: metadata,
    );
  }

  // 记录API调用日志
  static Future<void> apiCall(String message, {
    String? details,
    String? userId,
    String? userName,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      LogLevel.info,
      LogCategory.api,
      message,
      details: details,
      userId: userId,
      userName: userName,
      metadata: metadata,
    );
  }

  // 记录AI模型相关日志
  static Future<void> modelOperation(String message, {
    String? details,
    String? userId,
    String? userName,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      LogLevel.info,
      LogCategory.model,
      message,
      details: details,
      userId: userId,
      userName: userName,
      metadata: metadata,
    );
  }

  // 记录工作流日志
  static Future<void> workflowOperation(String message, {
    String? details,
    String? userId,
    String? userName,
    Map<String, dynamic>? metadata,
  }) async {
    await _log(
      LogLevel.info,
      LogCategory.workflow,
      message,
      details: details,
      userId: userId,
      userName: userName,
      metadata: metadata,
    );
  }

  // 内部日志记录方法
  static Future<void> _log(
    LogLevel level,
    LogCategory category,
    String message, {
    String? details,
    String? userId,
    String? userName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final log = SystemLog(
        level: level,
        category: category,
        message: message,
        details: details,
        userId: userId ?? _defaultUserId,
        userName: userName ?? _defaultUserName,
        metadata: metadata,
      );

      await DatabaseService.insertSystemLog(log);
      
      // 同时在控制台输出（开发环境）
      _printToConsole(log);
    } catch (e) {
      // 如果数据库记录失败，至少要在控制台输出
      print('日志记录失败: $e');
      print('[$level] [$category] $message');
      if (details != null) print('详情: $details');
    }
  }

  // 控制台输出（开发环境）
  static void _printToConsole(SystemLog log) {
    final levelColor = _getLevelColor(log.level);
    final categoryColor = _getCategoryColor(log.category);
    
    print('${levelColor}[${log.level.displayName}]${categoryColor}[${log.category.displayName}]${_resetColor} ${log.message}');
    if (log.details != null) {
      print('  ${_dimColor}详情: ${log.details}${_resetColor}');
    }
    if (log.userName != null && log.userName != _defaultUserName) {
      print('  ${_dimColor}用户: ${log.userName}${_resetColor}');
    }
    print('  ${_dimColor}时间: ${log.timestamp}${_resetColor}');
  }

  // 控制台颜色代码
  static const String _resetColor = '\x1B[0m';
  static const String _dimColor = '\x1B[2m';
  
  static String _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '\x1B[36m'; // 青色
      case LogLevel.info:
        return '\x1B[32m'; // 绿色
      case LogLevel.warning:
        return '\x1B[33m'; // 黄色
      case LogLevel.error:
        return '\x1B[31m'; // 红色
      case LogLevel.critical:
        return '\x1B[35m'; // 紫色
    }
  }
  
  static String _getCategoryColor(LogCategory category) {
    switch (category) {
      case LogCategory.system:
        return '\x1B[34m'; // 蓝色
      case LogCategory.user:
        return '\x1B[32m'; // 绿色
      case LogCategory.database:
        return '\x1B[33m'; // 黄色
      case LogCategory.api:
        return '\x1B[36m'; // 青色
      case LogCategory.security:
        return '\x1B[31m'; // 红色
      case LogCategory.model:
        return '\x1B[35m'; // 紫色
      case LogCategory.workflow:
        return '\x1B[37m'; // 白色
      case LogCategory.other:
        return '\x1B[90m'; // 灰色
    }
  }
}
