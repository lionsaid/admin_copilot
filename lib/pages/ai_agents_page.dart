import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_agent.dart';
import '../models/system_log.dart';
import '../providers/theme_provider.dart';
import '../services/log_service.dart';
import '../services/database_service.dart';
import '../services/ai_agent_service.dart';
import 'agent_edit_page.dart';

class AIAgentsPage extends StatefulWidget {
  const AIAgentsPage({Key? key}) : super(key: key);

  @override
  State<AIAgentsPage> createState() => _AIAgentsPageState();
}

class _AIAgentsPageState extends State<AIAgentsPage> {
  List<AIAgent> _agents = [];
  List<AIAgent> _filteredAgents = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // 搜索和筛选
  final TextEditingController _searchController = TextEditingController();
  AgentStatus? _selectedStatus;
  AgentType? _selectedType;
  bool _showTemplates = true;
  
  // 视图模式
  bool _isCardView = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
    
    LogService.userAction(
      '用户访问AI代理管理',
      details: '用户进入AI代理主页面',
      userId: 'admin',
      userName: 'Admin',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 应用搜索和筛选
  void _applyFilters() {
    setState(() {
      _filteredAgents = _agents.where((agent) {
        // 搜索过滤
        if (_searchController.text.isNotEmpty) {
          final searchTerm = _searchController.text.toLowerCase();
          if (!agent.name.toLowerCase().contains(searchTerm) &&
              !agent.description.toLowerCase().contains(searchTerm)) {
            return false;
          }
        }
        
        // 状态过滤
        if (_selectedStatus != null && agent.status != _selectedStatus) {
          return false;
        }
        
        // 类型过滤
        if (_selectedType != null && agent.type != _selectedType) {
          return false;
        }
        
        return true;
      }).toList();
    });
  }

  /// 加载代理数据
  Future<void> _loadAgents() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final agentsData = await DatabaseService.getAllAIAgents();
      final agents = agentsData.map((data) => AIAgent.fromMap(data)).toList();
      
      if (mounted) {
        setState(() {
          _agents = agents;
          _filteredAgents = List.from(agents);
          _isLoading = false;
        });
      }
      
      LogService.info(
        'AI代理列表加载完成',
        details: '成功加载 ${agents.length} 个代理',
        userId: 'admin',
        userName: 'Admin',
        category: LogCategory.workflow,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载代理列表失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
              LogService.error(
          '加载AI代理列表失败',
          details: '错误: $e',
          userId: 'admin',
          userName: 'Admin',
          category: LogCategory.workflow,
        );
    }
  }

  /// 处理代理操作
  void _handleAgentAction(String action, AIAgent agent) {
    switch (action) {
      case 'edit':
        _editAgent(agent);
        break;
      case 'view':
        _viewAgentDetails(agent);
        break;
      case 'clone':
        _cloneAgent(agent);
        break;
      case 'run':
        _runAgent(agent);
        break;
      case 'delete':
        _deleteAgent(agent);
        break;
    }
  }

  /// 编辑代理
  void _editAgent(AIAgent agent) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AgentEditPage(agent: agent),
      ),
    );
    
    if (result == true) {
      // 刷新列表
      _loadAgents();
    }
  }

  /// 查看代理详情
  void _viewAgentDetails(AIAgent agent) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('查看详情: ${agent.name}')),
    );
  }

  /// 克隆代理
  void _cloneAgent(AIAgent agent) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('克隆代理: ${agent.name}')),
    );
  }

  /// 运行代理
  void _runAgent(AIAgent agent) {
    _showRunAgentDialog(agent);
  }

  /// 显示运行代理对话框
  void _showRunAgentDialog(AIAgent agent) {
    final messageController = TextEditingController();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 700,
          height: 600,
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode 
                ? const Color(0xFF1E1E1E) 
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // 顶部标题栏
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode 
                      ? const Color(0xFF2A2A2A) 
                      : const Color(0xFFF8F9FA),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    // 代理图标
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: themeProvider.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getAgentIcon(agent.type),
                        color: themeProvider.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 代理信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agent.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode 
                                  ? Colors.white 
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            agent.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: themeProvider.isDarkMode 
                                  ? Colors.grey[400] 
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 关闭按钮
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: themeProvider.isDarkMode 
                            ? Colors.grey[400] 
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 主要内容区域
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 输入区域标签
                      Text(
                        '与 ${agent.name} 对话',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.isDarkMode 
                              ? Colors.white 
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '输入您想要询问的内容，AI代理将为您提供专业的回答',
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.isDarkMode 
                              ? Colors.grey[400] 
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // 消息输入框
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: themeProvider.isDarkMode 
                                  ? Colors.grey[700]! 
                                  : Colors.grey[300]!,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: themeProvider.isDarkMode 
                                ? const Color(0xFF2A2A2A) 
                                : const Color(0xFFF8F9FA),
                          ),
                          child: TextField(
                            controller: messageController,
                            decoration: InputDecoration(
                              hintText: '输入您想要询问的内容...',
                              hintStyle: TextStyle(
                                color: themeProvider.isDarkMode 
                                    ? Colors.grey[500] 
                                    : Colors.grey[400],
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(20),
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              color: themeProvider.isDarkMode 
                                  ? Colors.white 
                                  : Colors.black87,
                            ),
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            autofocus: true,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 底部工具栏
                      Row(
                        children: [
                          // 左侧工具按钮
                          Row(
                            children: [
                              _buildToolButton(
                                icon: Icons.attach_file,
                                label: '附件',
                                onTap: () {
                                  // TODO: 实现文件附件功能
                                },
                                themeProvider: themeProvider,
                              ),
                              const SizedBox(width: 12),
                              _buildToolButton(
                                icon: Icons.image,
                                label: '图片',
                                onTap: () {
                                  // TODO: 实现图片上传功能
                                },
                                themeProvider: themeProvider,
                              ),
                              const SizedBox(width: 12),
                              _buildToolButton(
                                icon: Icons.code,
                                label: '代码',
                                onTap: () {
                                  // TODO: 实现代码输入功能
                                },
                                themeProvider: themeProvider,
                              ),
                            ],
                          ),
                          
                          const Spacer(),
                          
                          // 右侧操作按钮
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  '取消',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: themeProvider.isDarkMode 
                                        ? Colors.grey[400] 
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  if (messageController.text.trim().isNotEmpty) {
                                    Navigator.of(context).pop();
                                    _executeAgent(agent, messageController.text.trim());
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeProvider.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.play_arrow,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '运行代理',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建工具按钮
  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: themeProvider.isDarkMode 
                  ? Colors.grey[400] 
                  : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: themeProvider.isDarkMode 
                    ? Colors.grey[400] 
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 获取代理类型对应的图标
  IconData _getAgentIcon(AgentType type) {
    switch (type) {
      case AgentType.customerService:
        return Icons.support_agent;
      case AgentType.contentCreator:
        return Icons.edit;
      case AgentType.dataAnalyst:
        return Icons.analytics;
      case AgentType.codeAssistant:
        return Icons.code;
      case AgentType.researchAssistant:
        return Icons.search;
      case AgentType.custom:
        return Icons.smart_toy;
    }
  }

  /// 执行代理
  Future<void> _executeAgent(AIAgent agent, String message) async {
    try {
      // 显示运行状态
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正在运行代理: ${agent.name}...'),
          duration: const Duration(seconds: 2),
        ),
      );

      // 运行代理
      final result = await AIAgentService.runAgent(
        agent,
        message,
        userId: 'admin',
        userName: 'Admin',
      );

      if (mounted) {
        if (result.isSuccess) {
          // 显示成功结果
          _showAgentResult(agent, result);
        } else {
          // 显示错误信息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('运行失败: ${result.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        
        // 刷新列表以更新统计数据
        _loadAgents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('运行异常: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 显示代理运行结果
  void _showAgentResult(AIAgent agent, AgentRunResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${agent.name} 运行结果'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 运行信息
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '运行成功',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '响应时间: ${result.responseTimeMs}ms',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 响应内容
              const Text(
                'AI响应:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      result.responseText,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
              
              // Token使用信息
              if (result.tokenUsage != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Token使用: ${result.totalTokens}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
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

  /// 删除代理
  void _deleteAgent(AIAgent agent) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除AI代理"${agent.name}"吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                if (agent.id != null) {
                  await DatabaseService.deleteAIAgent(agent.id!);
                  
                  if (mounted) {
                    setState(() {
                      _agents.remove(agent);
                      _applyFilters();
                    });
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已删除代理: ${agent.name}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    
                    LogService.info(
                      'AI代理已删除',
                      details: '代理: ${agent.name}',
                      userId: 'admin',
                      userName: 'Admin',
                      category: LogCategory.workflow,
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('删除失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                
                LogService.error(
                  '删除AI代理失败',
                  details: '代理: ${agent.name}, 错误: $e',
                  userId: 'admin',
                  userName: 'Admin',
                  category: LogCategory.workflow,
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 格式化时间差
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} 天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} 小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} 分钟前';
    } else {
      return '刚刚';
    }
  }

  /// 创建新代理
  void _createNewAgent() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AgentEditPage(),
      ),
    );
    
    if (result == true) {
      // 刷新列表
      _loadAgents();
    }
  }

  /// 显示模板选择对话框
  void _showTemplatesDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择AI代理模板'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: AgentTemplates.templates.length,
            itemBuilder: (context, index) {
              final template = AgentTemplates.templates[index];
              return Card(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    _createFromTemplate(template);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              template.icon,
                              color: themeProvider.primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                template.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Text(
                            template.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: themeProvider.textSecondaryColor,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            '点击使用',
                            style: TextStyle(
                              fontSize: 12,
                              color: themeProvider.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 从模板创建代理
  void _createFromTemplate(AgentTemplate template) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AgentEditPage(template: template),
      ),
    );
    
    if (result == true) {
      // 刷新列表
      _loadAgents();
    }
  }

  /// 视图切换按钮
  Widget _buildViewToggleButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? themeProvider.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : themeProvider.textColor,
          size: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 代理管理中心'),
        backgroundColor: themeProvider.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildTopActionBar(themeProvider),
          _buildSearchAndFilterSection(themeProvider),
          Expanded(
            child: _buildAgentsList(themeProvider),
          ),
        ],
      ),

    );
  }

  Widget _buildTopActionBar(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 代理管理中心',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '集中管理、搜索与筛选您的 AI 代理，支持卡片/列表视图',
                  style: TextStyle(
                    fontSize: 13,
                    color: themeProvider.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          // 视图切换按钮
          Container(
            decoration: BoxDecoration(
              color: themeProvider.surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: themeProvider.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewToggleButton(
                  icon: Icons.grid_view,
                  isSelected: _isCardView,
                  onTap: () => setState(() => _isCardView = true),
                  themeProvider: themeProvider,
                ),
                _buildViewToggleButton(
                  icon: Icons.view_list,
                  isSelected: !_isCardView,
                  onTap: () => setState(() => _isCardView = false),
                  themeProvider: themeProvider,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 创建新代理按钮
          ElevatedButton.icon(
            onPressed: _createNewAgent,
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.add),
            label: const Text('创建新代理'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 搜索框
          TextField(
            controller: _searchController,
            onChanged: (value) => _applyFilters(),
            decoration: InputDecoration(
              labelText: '按名称搜索',
              hintText: '输入代理名称或描述...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 筛选器
          Row(
            children: [
              // 状态筛选
              Expanded(
                child: DropdownButtonFormField<AgentStatus?>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: '按状态筛选',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部状态')),
                    ...AgentStatus.values.map((status) => DropdownMenuItem(
                      value: status,
                      child: Row(
                        children: [
                          Icon(status.icon, color: status.color, size: 16),
                          const SizedBox(width: 8),
                          Text(status.displayName),
                        ],
                      ),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 16),
              // 类型筛选
              Expanded(
                child: DropdownButtonFormField<AgentType?>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: '按类型筛选',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部类型')),
                    ...AgentType.values.map((type) => DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(type.icon, color: Colors.blue, size: 16),
                          Text(type.displayName),
                        ],
                      ),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgentsList(ThemeProvider themeProvider) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredAgents.isEmpty) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 插图区域
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: themeProvider.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  _agents.isEmpty ? Icons.psychology_outlined : Icons.search_off,
                  size: 60,
                  color: themeProvider.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              
              // 标题
              Text(
                _agents.isEmpty ? '开始创建您的AI代理' : '没有找到匹配的代理',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // 描述
              Text(
                _agents.isEmpty 
                    ? '您还没有任何AI代理。AI代理可以帮您自动处理各种任务，如客户服务、内容创作、数据分析等。点击下方按钮开始构建您的第一个AI助手吧！'
                    : '尝试调整搜索条件或筛选器，或者创建一个新的AI代理。',
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.textSecondaryColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // 操作按钮
              if (_agents.isEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _createNewAgent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text(
                      '创建我的第一个AI代理',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _showTemplatesDialog,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    side: BorderSide(color: themeProvider.primaryColor),
                  ),
                  icon: Icon(Icons.auto_awesome, color: themeProvider.primaryColor),
                  label: Text(
                    '从模板开始',
                    style: TextStyle(
                      color: themeProvider.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _selectedStatus = null;
                          _selectedType = null;
                        });
                        _applyFilters();
                      },
                      icon: const Icon(Icons.clear_all),
                      label: const Text('清除筛选'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _createNewAgent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeProvider.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('创建新代理'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    return _isCardView
        ? _buildCardView(themeProvider)
        : _buildListView(themeProvider);
  }

  /// 卡片视图
  Widget _buildCardView(ThemeProvider themeProvider) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredAgents.length,
      itemBuilder: (context, index) {
        return _buildAgentCard(_filteredAgents[index], themeProvider);
      },
    );
  }

  /// 列表视图
  Widget _buildListView(ThemeProvider themeProvider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredAgents.length,
      itemBuilder: (context, index) {
        return _buildAgentListItem(_filteredAgents[index], themeProvider);
      },
    );
  }

  /// 代理列表项
  Widget _buildAgentListItem(AIAgent agent, ThemeProvider themeProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: themeProvider.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            agent.typeIcon,
            color: themeProvider.primaryColor,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                agent.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: agent.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    agent.statusIcon,
                    color: agent.statusColor,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    agent.status.displayName,
                    style: TextStyle(
                      color: agent.statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              agent.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.analytics, size: 14, color: themeProvider.textSecondaryColor),
                const SizedBox(width: 4),
                Text('${agent.totalRuns}', style: TextStyle(fontSize: 12, color: themeProvider.textSecondaryColor)),
                const SizedBox(width: 8),
                Text('|', style: TextStyle(fontSize: 12, color: themeProvider.textSecondaryColor)),
                const SizedBox(width: 8),
                Icon(Icons.timer, size: 14, color: themeProvider.textSecondaryColor),
                const SizedBox(width: 4),
                Text(
                  '${agent.averageResponseTime.toStringAsFixed(1)}s',
                  style: TextStyle(fontSize: 12, color: themeProvider.textSecondaryColor),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: '更多',
          icon: const Icon(Icons.more_horiz),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'run',
              child: Row(
                children: [
                  Icon(Icons.play_arrow),
                  SizedBox(width: 8),
                  Text('运行'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('编辑'),
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
          onSelected: (value) => _handleAgentAction(value, agent),
        ),
        onTap: () => _handleAgentAction('edit', agent),
      ),
    );
  }

  Widget _buildAgentCard(AIAgent agent, ThemeProvider themeProvider) {
    return Stack(
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：图标、名称、状态标签、操作菜单
            Row(
              children: [
                Icon(agent.typeIcon, color: themeProvider.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    agent.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 状态标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: agent.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: agent.statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(agent.statusIcon, color: agent.statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        agent.status.displayName,
                        style: TextStyle(
                          color: agent.statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 操作菜单
                PopupMenuButton<String>(
                  tooltip: '更多',
                  icon: Icon(Icons.more_horiz, color: themeProvider.textSecondaryColor, size: 20),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility, size: 18),
                          SizedBox(width: 8),
                          Text('查看详情'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clone',
                      child: Row(
                        children: [
                          Icon(Icons.copy, size: 18),
                          SizedBox(width: 8),
                          Text('克隆'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'run',
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow, size: 18),
                          SizedBox(width: 8),
                          Text('运行'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) => _handleAgentAction(value, agent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 描述
            Text(
              agent.description,
              style: TextStyle(fontSize: 12, color: themeProvider.textSecondaryColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            

            
            // 运营指标
            Row(
              children: [
                Tooltip(
                  message: '总运行次数',
                  child: Icon(Icons.analytics, size: 14, color: themeProvider.textSecondaryColor),
                ),
                const SizedBox(width: 4),
                Text('${agent.totalRuns}', style: TextStyle(fontSize: 11, color: themeProvider.textSecondaryColor)),
                const SizedBox(width: 8),
                Text('|', style: TextStyle(fontSize: 11, color: themeProvider.textSecondaryColor)),
                const SizedBox(width: 8),
                Tooltip(
                  message: '平均响应时间',
                  child: Icon(Icons.timer, size: 14, color: themeProvider.textSecondaryColor),
                ),
                const SizedBox(width: 4),
                Text(
                  '${agent.averageResponseTime.toStringAsFixed(1)}s',
                  style: TextStyle(fontSize: 11, color: themeProvider.textSecondaryColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            
            // 上次运行时间
            if (agent.lastRunAt != null) ...[
              Row(
                children: [
                  Tooltip(
                    message: '上次运行时间',
                    child: Icon(Icons.schedule, size: 14, color: themeProvider.textSecondaryColor),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '上次运行: ${_formatTimeAgo(agent.lastRunAt!)}',
                    style: TextStyle(fontSize: 11, color: themeProvider.textSecondaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            // 主要操作按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _handleAgentAction('run', agent),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: themeProvider.primaryColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow, size: 18, color: themeProvider.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      '运行代理',
                      style: TextStyle(
                        fontSize: 14,
                        color: themeProvider.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
            ),
          ),
        ),
        if (agent.status == AgentStatus.draft)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '草稿',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}
