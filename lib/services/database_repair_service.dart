import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseRepairService {
  static Future<void> repairAIAgentData() async {
    try {
      final db = await _getDatabase();
      
      // 获取所有AI代理数据
      final List<Map<String, dynamic>> agents = await db.query('ai_agents');
      
      for (final agent in agents) {
        final id = agent['id'] as int;
        
        // 修复 model_config 字段
        if (agent['model_config'] != null) {
          final fixedModelConfig = _fixJsonField(agent['model_config']);
          if (fixedModelConfig != null) {
            await db.update(
              'ai_agents',
              {'model_config': fixedModelConfig},
              where: 'id = ?',
              whereArgs: [id],
            );
            print('已修复AI代理 $id 的 model_config 字段');
          }
        }
        
        // 修复 knowledge_bases 字段
        if (agent['knowledge_bases'] != null) {
          final fixedKnowledgeBases = _fixJsonField(agent['knowledge_bases']);
          if (fixedKnowledgeBases != null) {
            await db.update(
              'ai_agents',
              {'knowledge_bases': fixedKnowledgeBases},
              where: 'id = ?',
              whereArgs: [id],
            );
            print('已修复AI代理 $id 的 knowledge_bases 字段');
          }
        }
        
        // 修复 tools 字段
        if (agent['tools'] != null) {
          final fixedTools = _fixJsonField(agent['tools']);
          if (fixedTools != null) {
            await db.update(
              'ai_agents',
              {'tools': fixedTools},
              where: 'id = ?',
              whereArgs: [id],
            );
            print('已修复AI代理 $id 的 tools 字段');
          }
        }
        
        // 修复 workflows 字段
        if (agent['workflows'] != null) {
          final fixedWorkflows = _fixJsonField(agent['workflows']);
          if (fixedWorkflows != null) {
            await db.update(
              'ai_agents',
              {'workflows': fixedWorkflows},
              where: 'id = ?',
              whereArgs: [id],
            );
            print('已修复AI代理 $id 的 workflows 字段');
          }
        }
        
        // 修复 metadata 字段
        if (agent['metadata'] != null) {
          final fixedMetadata = _fixJsonField(agent['metadata']);
          if (fixedMetadata != null) {
            await db.update(
              'ai_agents',
              {'metadata': fixedMetadata},
              where: 'id = ?',
              whereArgs: [id],
            );
            print('已修复AI代理 $id 的 metadata 字段');
          }
        }
      }
      
      print('AI代理数据修复完成');
    } catch (e) {
      print('修复AI代理数据时出错: $e');
      rethrow;
    }
  }
  
  static String? _fixJsonField(dynamic value) {
    if (value == null) return null;
    
    String jsonString = value.toString();
    
    // 如果已经是有效的JSON，直接返回
    try {
      jsonDecode(jsonString);
      return jsonString;
    } catch (e) {
      // 不是有效JSON，尝试修复
    }
    
    // 修复常见的格式问题
    String fixed = jsonString;
    
    // 替换分号为逗号
    fixed = fixed.replaceAll(';', ',');
    
    // 替换等号为冒号
    fixed = fixed.replaceAll(' = ', ': ');
    
    // 移除末尾的逗号
    fixed = fixed.replaceAll(RegExp(r',$'), '');
    
    // 尝试解析修复后的JSON
    try {
      jsonDecode(fixed);
      print('成功修复JSON字段: $jsonString -> $fixed');
      return fixed;
    } catch (e) {
      print('无法修复JSON字段: $jsonString');
      print('修复尝试: $fixed');
      print('错误: $e');
      
      // 如果无法修复，返回一个空的JSON对象
      return '{}';
    }
  }
  
  static Future<Database> _getDatabase() async {
    String path = join(await getDatabasesPath(), 'admin_copilot.db');
    return await openDatabase(path);
  }
  
  static Future<void> resetAIAgentTable() async {
    try {
      final db = await _getDatabase();
      
      // 删除现有的AI代理表
      await db.execute('DROP TABLE IF EXISTS ai_agents');
      
      // 重新创建AI代理表
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
      
      print('AI代理表已重置');
    } catch (e) {
      print('重置AI代理表时出错: $e');
      rethrow;
    }
  }
}
