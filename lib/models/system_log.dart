enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

enum LogCategory {
  system,      // 系统操作
  user,        // 用户操作
  database,    // 数据库操作
  api,         // API调用
  security,    // 安全相关
  model,       // AI模型相关
  workflow,    // 工作流
  other,       // 其他
}

extension LogLevelExtension on LogLevel {
  String get displayName {
    switch (this) {
      case LogLevel.debug:
        return '调试';
      case LogLevel.info:
        return '信息';
      case LogLevel.warning:
        return '警告';
      case LogLevel.error:
        return '错误';
      case LogLevel.critical:
        return '严重';
    }
  }

  String get value {
    switch (this) {
      case LogLevel.debug:
        return 'debug';
      case LogLevel.info:
        return 'info';
      case LogLevel.warning:
        return 'warning';
      case LogLevel.error:
        return 'error';
      case LogLevel.critical:
        return 'critical';
    }
  }

  static LogLevel fromString(String value) {
    switch (value) {
      case 'debug':
        return LogLevel.debug;
      case 'info':
        return LogLevel.info;
      case 'warning':
        return LogLevel.warning;
      case 'error':
        return LogLevel.error;
      case 'critical':
        return LogLevel.critical;
      default:
        return LogLevel.info;
    }
  }
}

extension LogCategoryExtension on LogCategory {
  String get displayName {
    switch (this) {
      case LogCategory.system:
        return '系统';
      case LogCategory.user:
        return '用户';
      case LogCategory.database:
        return '数据库';
      case LogCategory.api:
        return 'API';
      case LogCategory.security:
        return '安全';
      case LogCategory.model:
        return 'AI模型';
      case LogCategory.workflow:
        return '工作流';
      case LogCategory.other:
        return '其他';
    }
  }

  String get value {
    switch (this) {
      case LogCategory.system:
        return 'system';
      case LogCategory.user:
        return 'user';
      case LogCategory.database:
        return 'database';
      case LogCategory.api:
        return 'api';
      case LogCategory.security:
        return 'security';
      case LogCategory.model:
        return 'model';
      case LogCategory.workflow:
        return 'workflow';
      case LogCategory.other:
        return 'other';
    }
  }

  static LogCategory fromString(String value) {
    switch (value) {
      case 'system':
        return LogCategory.system;
      case 'user':
        return LogCategory.user;
      case 'database':
        return LogCategory.database;
      case 'api':
        return LogCategory.api;
      case 'security':
        return LogCategory.security;
      case 'model':
        return LogCategory.model;
      case 'workflow':
        return LogCategory.workflow;
      case 'other':
        return LogCategory.other;
      default:
        return LogCategory.other;
    }
  }
}

class SystemLog {
  final int? id;
  final LogLevel level;
  final LogCategory category;
  final String message;
  final String? details;
  final String? userId;
  final String? userName;
  final String? ipAddress;
  final String? userAgent;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  SystemLog({
    this.id,
    required this.level,
    required this.category,
    required this.message,
    this.details,
    this.userId,
    this.userName,
    this.ipAddress,
    this.userAgent,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'level': level.value,
      'category': category.value,
      'message': message,
      'details': details,
      'user_id': userId,
      'user_name': userName,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata != null ? metadata.toString() : null,
    };
  }

  factory SystemLog.fromMap(Map<String, dynamic> map) {
    return SystemLog(
      id: map['id'] as int?,
      level: LogLevelExtension.fromString(map['level'] as String),
      category: LogCategoryExtension.fromString(map['category'] as String),
      message: map['message'] as String,
      details: map['details'] as String?,
      userId: map['user_id'] as String?,
      userName: map['user_name'] as String?,
      ipAddress: map['ip_address'] as String?,
      userAgent: map['user_agent'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      metadata: map['metadata'] != null 
          ? _parseMetadata(map['metadata'] as String)
          : null,
    );
  }

  static Map<String, dynamic>? _parseMetadata(String metadataStr) {
    try {
      // 简单的元数据解析，实际应用中可能需要更复杂的解析逻辑
      if (metadataStr.startsWith('{') && metadataStr.endsWith('}')) {
        // 这里可以添加更复杂的JSON解析逻辑
        return {'raw': metadataStr};
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  SystemLog copyWith({
    int? id,
    LogLevel? level,
    LogCategory? category,
    String? message,
    String? details,
    String? userId,
    String? userName,
    String? ipAddress,
    String? userAgent,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return SystemLog(
      id: id ?? this.id,
      level: level ?? this.level,
      category: category ?? this.category,
      message: message ?? this.message,
      details: details ?? this.details,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
}
