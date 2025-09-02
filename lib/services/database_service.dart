import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/system_log.dart';
import 'log_service.dart';

class DatabaseService {
  static Database? _database;
  static String? _cachedPath;
  
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  static Future<Database> _initDatabase() async {
    try {
      String path = join(await getDatabasesPath(), 'admin_copilot.db');
      _cachedPath = path;
      
      return await openDatabase(
        path,
        version: 6,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          print('数据库已成功打开: $path');
        },
      );
    } catch (e) {
      print('初始化数据库失败: $e');
      rethrow;
    }
  }

  // 启动自检：检查关键表与列；失败则删除并重建
  static Future<void> selfCheckAndRecreateIfNeeded() async {
    try {
      final db = await database;
      await _ensureTablesAndColumns(db);
    } catch (e) {
      print('数据库自检失败，尝试重建: $e');
      await _recreateDatabase();
    }
  }

  static Future<void> _recreateDatabase() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      final path = _cachedPath ?? join(await getDatabasesPath(), 'admin_copilot.db');
      await deleteDatabase(path);
      print('数据库已删除: $path');
      // 重新打开将自动创建
      await database;
      print('数据库已重建');
    } catch (e) {
      print('重建数据库失败: $e');
      rethrow;
    }
  }
  
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('数据库升级: $oldVersion -> $newVersion');
    
    if (oldVersion < 2) {
      // 添加模型提供商表
      await db.execute('''
        CREATE TABLE model_providers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          provider_type TEXT NOT NULL,
          api_key TEXT,
          base_url TEXT,
          server_url TEXT,
          endpoint_url TEXT,
          deployment_name TEXT,
          is_active INTEGER DEFAULT 1,
          is_default INTEGER DEFAULT 0,
          last_test_time TEXT,
          test_status TEXT DEFAULT 'unknown',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      print('模型提供商表已创建');
    }
    
    if (oldVersion < 3) {
      // 添加系统日志表
      await db.execute('''
        CREATE TABLE system_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          level TEXT NOT NULL,
          category TEXT NOT NULL,
          message TEXT NOT NULL,
          details TEXT,
          user_id TEXT,
          user_name TEXT,
          ip_address TEXT,
          user_agent TEXT,
          timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          metadata TEXT
        )
      ''');
      print('系统日志表已创建');
    }
    
    if (oldVersion < 4) {
    if (oldVersion < 5) {
      // 版本5: 为模型提供商添加 is_default 字段
      await db.execute('ALTER TABLE model_providers ADD COLUMN is_default INTEGER DEFAULT 0');
      print('已为 model_providers 添加 is_default 列');
    }
      // 添加AI代理表
      await db.execute('''
        CREATE TABLE ai_agents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          type TEXT NOT NULL,
          status TEXT NOT NULL,
          system_prompt TEXT NOT NULL,
          provider_name TEXT NOT NULL,
          model_name TEXT NOT NULL,
          model_config TEXT,
          knowledge_bases TEXT,
          tools TEXT,
          workflows TEXT,
          metadata TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          last_run_at TIMESTAMP,
          total_runs INTEGER DEFAULT 0,
          success_runs INTEGER DEFAULT 0,
          average_response_time REAL DEFAULT 0.0,
          total_token_cost REAL DEFAULT 0.0
        )
      ''');
      print('AI代理表已创建');
    }
    // 版本6: 知识库相关表
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE knowledge_bases (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT,
          engine_type TEXT NOT NULL,
          engine_config TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE kb_documents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          kb_id INTEGER NOT NULL,
          title TEXT,
          source_path TEXT,
          mime_type TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(kb_id) REFERENCES knowledge_bases(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE kb_chunks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          kb_id INTEGER NOT NULL,
          doc_id INTEGER,
          chunk_index INTEGER,
          content TEXT NOT NULL,
          embedding BLOB,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(kb_id) REFERENCES knowledge_bases(id) ON DELETE CASCADE,
          FOREIGN KEY(doc_id) REFERENCES kb_documents(id) ON DELETE CASCADE
        )
      ''');
      print('知识库相关表已创建');
    }
  }
  
  static Future<void> _onCreate(Database db, int version) async {
    // 创建设置表
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    // 创建主题表
    await db.execute('''
      CREATE TABLE themes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_dark BOOLEAN NOT NULL,
        primary_color TEXT NOT NULL,
        background_color TEXT NOT NULL,
        surface_color TEXT NOT NULL,
        is_active BOOLEAN DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    // 创建模型提供商表
    await db.execute('''
      CREATE TABLE model_providers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        provider_type TEXT NOT NULL,
        api_key TEXT,
        base_url TEXT,
        server_url TEXT,
        endpoint_url TEXT,
        deployment_name TEXT,
        is_active INTEGER DEFAULT 1,
        is_default INTEGER DEFAULT 0,
        last_test_time TEXT,
        test_status TEXT DEFAULT 'unknown',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    // 创建系统日志表
    await db.execute('''
      CREATE TABLE system_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        level TEXT NOT NULL,
        category TEXT NOT NULL,
        message TEXT NOT NULL,
        details TEXT,
        user_id TEXT,
        user_name TEXT,
        ip_address TEXT,
        user_agent TEXT,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        metadata TEXT
      )
    ''');
    
    // 插入默认设置
    await db.insert('settings', {
      'key': 'language',
      'value': 'en',
    });
    
    await db.insert('settings', {
      'key': 'theme_mode',
      'value': 'dark',
    });
    
    // 插入默认主题
    await db.insert('themes', {
      'name': 'Dark Theme',
      'is_dark': 1,
      'primary_color': '#2196F3',
      'background_color': '#1A1A1A',
      'surface_color': '#2A2A2A',
      'is_active': 1,
    });
    
    await db.insert('themes', {
      'name': 'Light Theme',
      'is_dark': 0,
      'primary_color': '#2196F3',
      'background_color': '#FFFFFF',
      'surface_color': '#F5F5F5',
      'is_active': 0,
    });

    // 知识库表（与版本6一致，初次安装直接创建）
    await db.execute('''
      CREATE TABLE knowledge_bases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        engine_type TEXT NOT NULL,
        engine_config TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE kb_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kb_id INTEGER NOT NULL,
        title TEXT,
        source_path TEXT,
        mime_type TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(kb_id) REFERENCES knowledge_bases(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE kb_chunks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kb_id INTEGER NOT NULL,
        doc_id INTEGER,
        chunk_index INTEGER,
        content TEXT NOT NULL,
        embedding BLOB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(kb_id) REFERENCES knowledge_bases(id) ON DELETE CASCADE,
        FOREIGN KEY(doc_id) REFERENCES kb_documents(id) ON DELETE CASCADE
      )
    ''');
  }
  
  // 获取设置
  static Future<String?> getSetting(String key) async {
    final start = DateTime.now();
    try {
      final db = await database;
      final result = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
      );
      final duration = DateTime.now().difference(start).inMilliseconds;
      await LogService.databaseOperation(
        '读取设置',
        details: 'key=$key, 耗时=${duration}ms',
        metadata: {'key': key, 'duration_ms': duration, 'rows': result.length},
      );
      if (result.isNotEmpty) {
        return result.first['value'] as String;
      }
      return null;
    } catch (e) {
      final duration = DateTime.now().difference(start).inMilliseconds;
      await LogService.error('读取设置失败', details: 'key=$key, $e', category: LogCategory.database, metadata: {'key': key, 'duration_ms': duration});
      return null;
    }
  }
  
  // 保存设置
  static Future<void> saveSetting(String key, String value) async {
    final start = DateTime.now();
    try {
      final db = await database;
      await db.insert(
        'settings',
        {
          'key': key,
          'value': value,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final duration = DateTime.now().difference(start).inMilliseconds;
      await LogService.databaseOperation(
        '写入设置',
        details: 'key=$key, size=${value.length}B, 耗时=${duration}ms',
        metadata: {'key': key, 'size': value.length, 'duration_ms': duration},
      );
    } catch (e) {
      final duration = DateTime.now().difference(start).inMilliseconds;
      await LogService.error('保存设置失败', details: 'key=$key, $e', category: LogCategory.database, metadata: {'key': key, 'duration_ms': duration});
      rethrow;
    }
  }
  
  // 获取当前主题
  static Future<Map<String, dynamic>?> getCurrentTheme() async {
    final db = await database;
    final result = await db.query(
      'themes',
      where: 'is_active = ?',
      whereArgs: [1],
    );
    
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }
  
  // 更新主题
  static Future<void> updateTheme(int themeId) async {
    final db = await database;
    
    // 先取消所有主题的激活状态
    await db.update(
      'themes',
      {'is_active': 0},
    );
    
    // 激活指定主题
    await db.update(
      'themes',
      {'is_active': 1},
      where: 'id = ?',
      whereArgs: [themeId],
    );
  }
  
  // 获取所有主题
  static Future<List<Map<String, dynamic>>> getAllThemes() async {
    final db = await database;
    return await db.query('themes', orderBy: 'created_at DESC');
  }
  
  // 关闭数据库
  static Future<void> close() async {
    final db = await database;
    await db.close();
  }
  
  // 模型提供商相关操作
  static Future<List<Map<String, dynamic>>> getAllModelProviders() async {
    try {
      final db = await database;
      final result = await db.query(
        'model_providers',
        orderBy: 'created_at DESC',
      );
      return result;
    } catch (e) {
      print('获取模型提供商列表失败: $e');
      return [];
    }
  }
  
  static Future<Map<String, dynamic>?> getModelProvider(int id) async {
    try {
      final db = await database;
      final result = await db.query(
        'model_providers',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      print('获取模型提供商失败: $e');
      return null;
    }
  }
  
  static Future<int> insertModelProvider(Map<String, dynamic> provider) async {
    try {
      final db = await database;
      await _ensureIsDefaultColumn(db);
      // 若设置为默认，则先清空其他默认
      if ((provider['is_default'] as int?) == 1) {
        await db.rawUpdate('UPDATE model_providers SET is_default = 0');
      }
      final id = await db.insert('model_providers', provider);
      print('模型提供商已添加: ${provider['name']}');
      return id;
    } catch (e) {
      print('添加模型提供商失败: $e');
      rethrow;
    }
  }
  
  static Future<int> updateModelProvider(int id, Map<String, dynamic> provider) async {
    try {
      final db = await database;
      await _ensureIsDefaultColumn(db);
      // 若本次更新设为默认，需先清空其他默认
      if ((provider['is_default'] as int?) == 1) {
        await db.rawUpdate('UPDATE model_providers SET is_default = 0');
      }
      final count = await db.update(
        'model_providers',
        provider,
        where: 'id = ?',
        whereArgs: [id],
      );
      print('模型提供商已更新: ${provider['name']}');
      return count;
    } catch (e) {
      print('更新模型提供商失败: $e');
      rethrow;
    }
  }

  // 设为全局默认模型提供商（全局只能有一个）
  static Future<void> setDefaultModelProvider(int id) async {
    try {
      final db = await database;
      await _ensureIsDefaultColumn(db);
      await db.transaction((txn) async {
        await _ensureIsDefaultColumn(txn);
        await txn.rawUpdate('UPDATE model_providers SET is_default = 0');
        await txn.rawUpdate(
          'UPDATE model_providers SET is_default = 1, updated_at = ? WHERE id = ?',
          [DateTime.now().toIso8601String(), id],
        );
      });
    } catch (e) {
      print('设置默认模型提供商失败: $e');
      // 尝试一次自愈后重试
      try {
        final db = await database;
        await _ensureIsDefaultColumn(db);
        await db.rawUpdate('UPDATE model_providers SET is_default = 0');
        await db.rawUpdate(
          'UPDATE model_providers SET is_default = 1, updated_at = ? WHERE id = ?',
          [DateTime.now().toIso8601String(), id],
        );
      } catch (_) {
        rethrow;
      }
    }
  }

  // 确保 model_providers 表包含 is_default 列
  static Future<void> _ensureIsDefaultColumn(DatabaseExecutor db) async {
    final info = await db.rawQuery('PRAGMA table_info(model_providers)');
    final hasColumn = info.any((row) => (row['name'] as String?) == 'is_default');
    if (!hasColumn) {
      await db.execute('ALTER TABLE model_providers ADD COLUMN is_default INTEGER DEFAULT 0');
    }
  }

  // 确保关键表和列存在
  static Future<void> _ensureTablesAndColumns(DatabaseExecutor db) async {
    // 检查 model_providers 表存在
    final tbl = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='model_providers'");
    if (tbl.isEmpty) {
      // 若不存在则创建表结构
      await _onCreate(await database, 5);
      return;
    }
    // 确保 is_default 列
    await _ensureIsDefaultColumn(db);

    // 确保知识库表存在
    await db.execute('''
      CREATE TABLE IF NOT EXISTS knowledge_bases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        engine_type TEXT NOT NULL,
        engine_config TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kb_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kb_id INTEGER NOT NULL,
        title TEXT,
        source_path TEXT,
        mime_type TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(kb_id) REFERENCES knowledge_bases(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kb_chunks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kb_id INTEGER NOT NULL,
        doc_id INTEGER,
        chunk_index INTEGER,
        content TEXT NOT NULL,
        embedding BLOB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(kb_id) REFERENCES knowledge_bases(id) ON DELETE CASCADE,
        FOREIGN KEY(doc_id) REFERENCES kb_documents(id) ON DELETE CASCADE
      )
    ''');
  }
  
  static Future<int> deleteModelProvider(int id) async {
    try {
      final db = await database;
      final count = await db.delete(
        'model_providers',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('模型提供商已删除: ID $id');
      return count;
    } catch (e) {
      print('删除模型提供商失败: $e');
      rethrow;
    }
  }
  
  static Future<void> updateModelProviderTestStatus(int id, String status, DateTime? testTime) async {
    try {
      final db = await database;
      await db.update(
        'model_providers',
        {
          'test_status': status,
          'last_test_time': testTime?.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      print('模型提供商测试状态已更新: ID $id, 状态 $status');
    } catch (e) {
      print('更新模型提供商测试状态失败: $e');
      rethrow;
    }
  }

  // ==================== 系统日志相关方法 ====================
  
  // 插入系统日志
  static Future<int> insertSystemLog(SystemLog log) async {
    try {
      final db = await database;
      return await db.insert('system_logs', log.toMap());
    } catch (e) {
      print('插入系统日志失败: $e');
      rethrow;
    }
  }

  // 获取所有系统日志
  static Future<List<Map<String, dynamic>>> getAllSystemLogs({
    int? limit,
    int? offset,
    LogLevel? level,
    LogCategory? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await database;
      
      String whereClause = '';
      List<dynamic> whereArgs = [];
      
      if (level != null) {
        whereClause += 'level = ?';
        whereArgs.add(level.value);
      }
      
      if (category != null) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += 'category = ?';
        whereArgs.add(category.value);
      }
      
      if (startDate != null) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += 'timestamp >= ?';
        whereArgs.add(startDate.toIso8601String());
      }
      
      if (endDate != null) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += 'timestamp <= ?';
        whereArgs.add(endDate.toIso8601String());
      }
      
      String query = 'SELECT * FROM system_logs';
      if (whereClause.isNotEmpty) {
        query += ' WHERE $whereClause';
      }
      query += ' ORDER BY timestamp DESC';
      
      if (limit != null) {
        query += ' LIMIT $limit';
        if (offset != null) {
          query += ' OFFSET $offset';
        }
      }
      
      final result = await db.rawQuery(query, whereArgs);
      return result;
    } catch (e) {
      print('获取系统日志失败: $e');
      rethrow;
    }
  }

  // 获取日志统计信息
  static Future<Map<String, dynamic>> getSystemLogStats() async {
    try {
      final db = await database;
      
      // 总日志数
      final totalResult = await db.rawQuery('SELECT COUNT(*) as total FROM system_logs');
      final total = totalResult.first['total'] as int;
      
      // 按级别统计
      final levelResult = await db.rawQuery('''
        SELECT level, COUNT(*) as count 
        FROM system_logs 
        GROUP BY level
      ''');
      
      // 按类别统计
      final categoryResult = await db.rawQuery('''
        SELECT category, COUNT(*) as count 
        FROM system_logs 
        GROUP BY category
      ''');
      
      // 今日日志数
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final todayResult = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM system_logs 
        WHERE timestamp >= ?
      ''', [startOfDay.toIso8601String()]);
      final todayCount = todayResult.first['count'] as int;
      
      return {
        'total': total,
        'today': todayCount,
        'byLevel': levelResult,
        'byCategory': categoryResult,
      };
    } catch (e) {
      print('获取日志统计失败: $e');
      rethrow;
    }
  }

  // 清理日志
  static Future<int> clearSystemLogs({
    LogLevel? level,
    LogCategory? category,
    DateTime? beforeDate,
  }) async {
    try {
      final db = await database;
      
      String whereClause = '';
      List<dynamic> whereArgs = [];
      
      if (level != null) {
        whereClause += 'level = ?';
        whereArgs.add(level.value);
      }
      
      if (category != null) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += 'category = ?';
        whereArgs.add(category.value);
      }
      
      if (beforeDate != null) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += 'timestamp < ?';
        whereArgs.add(beforeDate.toIso8601String());
      }
      
      String query = 'DELETE FROM system_logs';
      if (whereClause.isNotEmpty) {
        query += ' WHERE $whereClause';
      }
      
      return await db.rawDelete(query, whereArgs);
    } catch (e) {
      print('清理系统日志失败: $e');
      rethrow;
    }
  }

  // 删除单条日志
  static Future<int> deleteSystemLog(int id) async {
    try {
      final db = await database;
      return await db.delete(
        'system_logs',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('删除系统日志失败: $e');
      return 0;
    }
  }

  // ========== AI代理相关操作 ==========
  
  // 插入AI代理
  static Future<int> insertAIAgent(Map<String, dynamic> agent) async {
    try {
      final db = await database;
      agent['created_at'] = DateTime.now().toIso8601String();
      agent['updated_at'] = DateTime.now().toIso8601String();
      
      return await db.insert('ai_agents', agent);
    } catch (e) {
      print('插入AI代理失败: $e');
      rethrow;
    }
  }
  
  // 获取所有AI代理
  static Future<List<Map<String, dynamic>>> getAllAIAgents() async {
    try {
      final db = await database;
      return await db.query(
        'ai_agents',
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      print('获取AI代理列表失败: $e');
      rethrow;
    }
  }
  
  // 根据ID获取AI代理
  static Future<Map<String, dynamic>?> getAIAgentById(int id) async {
    try {
      final db = await database;
      final result = await db.query(
        'ai_agents',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      print('获取AI代理失败: $e');
      rethrow;
    }
  }
  
  // 更新AI代理
  static Future<int> updateAIAgent(int id, Map<String, dynamic> agent) async {
    try {
      final db = await database;
      agent['updated_at'] = DateTime.now().toIso8601String();
      
      return await db.update(
        'ai_agents',
        agent,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('更新AI代理失败: $e');
      rethrow;
    }
  }
  
  // 删除AI代理
  static Future<int> deleteAIAgent(int id) async {
    try {
      final db = await database;
      return await db.delete(
        'ai_agents',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('删除AI代理失败: $e');
      rethrow;
    }
  }
  
  // 更新AI代理运行状态
  static Future<int> updateAIAgentRunStatus(int id, {
    DateTime? lastRunAt,
    int? totalRuns,
    int? successRuns,
    double? averageResponseTime,
    double? totalTokenCost,
  }) async {
    try {
      final db = await database;
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (lastRunAt != null) updates['last_run_at'] = lastRunAt.toIso8601String();
      if (totalRuns != null) updates['total_runs'] = totalRuns;
      if (successRuns != null) updates['success_runs'] = successRuns;
      if (averageResponseTime != null) updates['average_response_time'] = averageResponseTime;
      if (totalTokenCost != null) updates['total_token_cost'] = totalTokenCost;
      
      return await db.update(
        'ai_agents',
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('更新AI代理运行状态失败: $e');
      rethrow;
    }
  }

  // 知识库相关操作
  static Future<List<Map<String, dynamic>>> getAllKnowledgeBases() async {
    try {
      final db = await database;
      final result = await db.query(
        'knowledge_bases',
        orderBy: 'created_at DESC',
      );
      return result;
    } catch (e) {
      print('获取知识库列表失败: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getKnowledgeBase(int id) async {
    try {
      final db = await database;
      final result = await db.query(
        'knowledge_bases',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      print('获取知识库失败: $e');
      return null;
    }
  }

  static Future<int> insertKnowledgeBase(Map<String, dynamic> knowledgeBase) async {
    try {
      final db = await database;
      final id = await db.insert('knowledge_bases', knowledgeBase);
      print('知识库已创建: ${knowledgeBase['name']}');
      return id;
    } catch (e) {
      print('创建知识库失败: $e');
      rethrow;
    }
  }

  static Future<int> updateKnowledgeBase(int id, Map<String, dynamic> knowledgeBase) async {
    try {
      final db = await database;
      knowledgeBase['updated_at'] = DateTime.now().toIso8601String();
      final count = await db.update(
        'knowledge_bases',
        knowledgeBase,
        where: 'id = ?',
        whereArgs: [id],
      );
      print('知识库已更新: ${knowledgeBase['name']}');
      return count;
    } catch (e) {
      print('更新知识库失败: $e');
      rethrow;
    }
  }

  static Future<int> deleteKnowledgeBase(int id) async {
    try {
      final db = await database;
      // 删除知识库会级联删除相关文档和分块
      final count = await db.delete(
        'knowledge_bases',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('知识库已删除: ID $id');
      return count;
    } catch (e) {
      print('删除知识库失败: $e');
      rethrow;
    }
  }

  // 知识库文档相关操作
  static Future<List<Map<String, dynamic>>> getDocumentsByKnowledgeBase(int kbId) async {
    try {
      final db = await database;
      final result = await db.query(
        'kb_documents',
        where: 'kb_id = ?',
        whereArgs: [kbId],
        orderBy: 'created_at DESC',
      );
      return result;
    } catch (e) {
      print('获取知识库文档失败: $e');
      return [];
    }
  }

  static Future<int> insertDocument(Map<String, dynamic> document) async {
    try {
      final db = await database;
      final id = await db.insert('kb_documents', document);
      print('文档已添加: ${document['title']}');
      return id;
    } catch (e) {
      print('添加文档失败: $e');
      rethrow;
    }
  }

  static Future<int> deleteDocument(int id) async {
    try {
      final db = await database;
      // 删除文档会级联删除相关分块
      final count = await db.delete(
        'kb_documents',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('文档已删除: ID $id');
      return count;
    } catch (e) {
      print('删除文档失败: $e');
      rethrow;
    }
  }

  // 知识库分块相关操作
  static Future<List<Map<String, dynamic>>> getChunksByDocument(int docId) async {
    try {
      final db = await database;
      final result = await db.query(
        'kb_chunks',
        where: 'doc_id = ?',
        whereArgs: [docId],
        orderBy: 'chunk_index ASC',
      );
      return result;
    } catch (e) {
      print('获取文档分块失败: $e');
      return [];
    }
  }

  static Future<int> insertChunk(Map<String, dynamic> chunk) async {
    try {
      final db = await database;
      final id = await db.insert('kb_chunks', chunk);
      print('分块已添加: 索引 ${chunk['chunk_index']}');
      return id;
    } catch (e) {
      print('添加分块失败: $e');
      rethrow;
    }
  }

  static Future<int> insertChunks(List<Map<String, dynamic>> chunks) async {
    try {
      final db = await database;
      int totalInserted = 0;
      await db.transaction((txn) async {
        for (final chunk in chunks) {
          await txn.insert('kb_chunks', chunk);
          totalInserted++;
        }
      });
      print('批量添加分块完成: $totalInserted 个');
      return totalInserted;
    } catch (e) {
      print('批量添加分块失败: $e');
      rethrow;
    }
  }

  static Future<int> deleteChunksByDocument(int docId) async {
    try {
      final db = await database;
      final count = await db.delete(
        'kb_chunks',
        where: 'doc_id = ?',
        whereArgs: [docId],
      );
      print('文档分块已删除: $count 个');
      return count;
    } catch (e) {
      print('删除文档分块失败: $e');
      rethrow;
    }
  }

  static Future<int> updateChunk(int id, Map<String, dynamic> chunk) async {
    try {
      final db = await database;
      final count = await db.update(
        'kb_chunks',
        chunk,
        where: 'id = ?',
        whereArgs: [id],
      );
      print('分块已更新: ID $id');
      return count;
    } catch (e) {
      print('更新分块失败: $e');
      rethrow;
    }
  }
}
