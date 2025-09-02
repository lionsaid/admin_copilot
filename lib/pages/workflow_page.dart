import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import 'model_providers_page.dart';
import 'ai_agents_page.dart';
import 'knowledge_base_page.dart';
import 'plugins_page.dart';

class WorkflowPage extends StatefulWidget {
  const WorkflowPage({Key? key}) : super(key: key);

  @override
  State<WorkflowPage> createState() => _WorkflowPageState();
}

class _WorkflowPageState extends State<WorkflowPage> {
  bool _loading = true;
  int _providers = 0;
  int _agents = 0;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final providers = await DatabaseService.getAllModelProviders();
      final agents = await DatabaseService.getAllAIAgents();
      if (mounted) {
        setState(() {
          _providers = providers.length;
          _agents = agents.length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('工作流程向导'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStep(
                  context,
                  title: '选择模型供应商',
                  subtitle: _providers > 0 ? '已配置 $_providers 个' : '尚未配置',
                  icon: Icons.api,
                  status: _providers > 0,
                  actionLabel: '前往配置',
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ModelProvidersPage()),
                    );
                    _loadState();
                  },
                ),
                _buildStep(
                  context,
                  title: '选择供应商的相关模型',
                  subtitle: '在提供商详情中选择或填写模型',
                  icon: Icons.model_training,
                  status: _providers > 0,
                  actionLabel: '前往供应商',
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ModelProvidersPage()),
                    );
                    _loadState();
                  },
                ),
                _buildStep(
                  context,
                  title: '选择相关AI代理',
                  subtitle: _agents > 0 ? '已创建 $_agents 个' : '尚未创建',
                  icon: Icons.smart_toy,
                  status: _agents > 0,
                  actionLabel: '管理代理',
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AIAgentsPage()),
                    );
                    _loadState();
                  },
                ),
                _buildStep(
                  context,
                  title: '加入个人知识库',
                  subtitle: '上传文档、网页或笔记以增强上下文',
                  icon: Icons.folder_open,
                  status: false,
                  actionLabel: '打开知识库',
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const KnowledgeBasePage()),
                    );
                  },
                ),
                _buildStep(
                  context,
                  title: '加入相关的插件',
                  subtitle: '连接外部工具，如搜索、日历、工单等',
                  icon: Icons.extension,
                  status: false,
                  actionLabel: '打开插件中心',
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PluginsPage()),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildStep(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool status,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    final theme = Provider.of<ThemeProvider>(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: theme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (status ? Colors.green : Colors.orange).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(status ? '已完成' : '待完成', style: TextStyle(color: status ? Colors.green : Colors.orange, fontSize: 12)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: onTap, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}


