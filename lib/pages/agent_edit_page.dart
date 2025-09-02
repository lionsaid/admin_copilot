import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_agent.dart';
import '../models/system_log.dart';
import '../providers/theme_provider.dart';
import '../services/log_service.dart';
import '../services/ai_agent_service.dart';
import '../services/database_service.dart';

class AgentEditPage extends StatefulWidget {
  final AIAgent? agent;
  final AgentTemplate? template;

  const AgentEditPage({
    Key? key,
    this.agent,
    this.template,
  }) : super(key: key);

  @override
  State<AgentEditPage> createState() => _AgentEditPageState();
}

class _AgentEditPageState extends State<AgentEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _testMessageController = TextEditingController();
  
  AgentType _selectedType = AgentType.custom;
  AgentStatus _selectedStatus = AgentStatus.draft;
  String _selectedProvider = '';
  String _selectedModel = '';
  
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isTestRunning = false;
  AgentRunResult? _testResult;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.agent != null;
    _initializeForm();
    
            LogService.userAction(
          _isEditing ? '用户编辑AI代理' : '用户创建AI代理',
          details: _isEditing ? '编辑代理: ${widget.agent!.name}' : '创建新代理',
          userId: 'admin',
          userName: 'Admin',
        );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _systemPromptController.dispose();
    _testMessageController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (widget.agent != null) {
      // 编辑现有代理
      final agent = widget.agent!;
      _nameController.text = agent.name;
      _descriptionController.text = agent.description;
      _systemPromptController.text = agent.systemPrompt;
      _selectedType = agent.type;
      _selectedStatus = agent.status;
      _selectedProvider = agent.providerName;
      _selectedModel = agent.modelName;
    } else if (widget.template != null) {
      // 从模板创建
      final template = widget.template!;
      _nameController.text = template.name;
      _descriptionController.text = template.description;
      _systemPromptController.text = template.systemPrompt;
      _selectedType = template.type;
    }
  }

  Future<void> _saveAgent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 创建AI代理对象
      final agent = AIAgent(
        id: widget.agent?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        status: _selectedStatus,
        systemPrompt: _systemPromptController.text.trim(),
        // 供应商与模型不在此处指定
        providerName: '',
        modelName: '',
        modelConfig: {
          'max_tokens': 1000,
          'temperature': 0.7,
        },
      );

      if (_isEditing) {
        // 更新现有代理
        await DatabaseService.updateAIAgent(agent.id!, agent.toMap());
        LogService.info(
          'AI代理已更新',
          details: '代理: ${agent.name}',
          userId: 'admin',
          userName: 'Admin',
          category: LogCategory.workflow,
        );
      } else {
        // 创建新代理
        final id = await DatabaseService.insertAIAgent(agent.toMap());
        LogService.info(
          'AI代理已创建',
          details: '代理: ${agent.name}, ID: $id',
          userId: 'admin',
          userName: 'Admin',
          category: LogCategory.workflow,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? '代理已更新' : '代理已创建'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      LogService.error(
        '保存AI代理失败',
        details: '错误: $e',
        userId: 'admin',
        userName: 'Admin',
        category: LogCategory.workflow,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑AI代理' : '创建AI代理'),
        backgroundColor: themeProvider.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveAgent,
              child: Text(
                '保存',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Row(
        children: [
          // 左侧面板：核心定义
          Expanded(
            flex: 2,
            child: _buildLeftPanel(themeProvider),
          ),
          
          // 分隔线
          Container(
            width: 1,
            color: themeProvider.borderColor,
          ),
          
          // 右侧面板：预览和测试
          Expanded(
            flex: 1,
            child: _buildRightPanel(themeProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基本信息
            _buildSectionTitle('基本信息', Icons.info_outline),
            const SizedBox(height: 16),
            
            // 代理名称
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '代理名称 *',
                hintText: '输入代理名称',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入代理名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // 代理描述
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '代理描述 *',
                hintText: '简单描述这个代理的用途',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入代理描述';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // 代理类型和状态
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<AgentType>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: '代理类型',
                      border: OutlineInputBorder(),
                    ),
                    items: AgentType.values.map((type) => DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(type.icon, size: 16),
                          const SizedBox(width: 8),
                          Text(type.displayName),
                        ],
                      ),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<AgentStatus>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: '状态',
                      border: OutlineInputBorder(),
                    ),
                    items: AgentStatus.values.map((status) => DropdownMenuItem(
                      value: status,
                      child: Row(
                        children: [
                          Icon(status.icon, color: status.color, size: 16),
                          const SizedBox(width: 8),
                          Text(status.displayName),
                        ],
                      ),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // 系统提示词
            _buildSectionTitle('系统提示词', Icons.psychology),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _systemPromptController,
              decoration: const InputDecoration(
                labelText: '系统提示词 *',
                hintText: '定义代理的角色、目标、行为准则和响应风格',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入系统提示词';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 32),
            
            // 移除模型配置：模型供应商与模型将在其他位置统一指定
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('预览', Icons.preview),
          const SizedBox(height: 16),
          
          // 代理卡片预览
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_selectedType.icon, color: themeProvider.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _nameController.text.isNotEmpty ? _nameController.text : '代理名称',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _selectedStatus.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_selectedStatus.icon, color: _selectedStatus.color, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _selectedStatus.displayName,
                              style: TextStyle(
                                color: _selectedStatus.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _descriptionController.text.isNotEmpty 
                        ? _descriptionController.text 
                        : '代理描述',
                    style: TextStyle(
                      fontSize: 12,
                      color: themeProvider.textSecondaryColor,
                    ),
                  ),
                  // 预览中不再展示模型信息
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 测试区域
          _buildSectionTitle('测试', Icons.play_circle_outline),
          const SizedBox(height: 16),
          
          if (_isEditing || _nameController.text.isNotEmpty)
            _buildTestSection()
          else
            const Text(
              '保存代理后，您可以在这里进行测试对话。',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Row(
      children: [
        Icon(icon, color: themeProvider.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: themeProvider.textColor,
          ),
        ),
      ],
    );
  }

  void _updateModelOptions() {
    switch (_selectedProvider) {
      case 'OpenAI':
        _selectedModel = 'gpt-4o';
        break;
      case '阿里巴巴 (通义千问)':
        _selectedModel = 'qwen-max';
        break;
      case 'Anthropic Claude':
        _selectedModel = 'claude-3-sonnet';
        break;
      case 'Google Gemini':
        _selectedModel = 'gemini-pro';
        break;
      default:
        _selectedModel = '';
    }
  }

  List<DropdownMenuItem<String>> _getModelOptions() {
    switch (_selectedProvider) {
      case 'OpenAI':
        return const [
          DropdownMenuItem(value: 'gpt-4o', child: Text('GPT-4o')),
          DropdownMenuItem(value: 'gpt-4-turbo', child: Text('GPT-4 Turbo')),
          DropdownMenuItem(value: 'gpt-3.5-turbo', child: Text('GPT-3.5 Turbo')),
        ];
      case '阿里巴巴 (通义千问)':
        return const [
          DropdownMenuItem(value: 'qwen-max', child: Text('Qwen Max')),
          DropdownMenuItem(value: 'qwen-plus', child: Text('Qwen Plus')),
          DropdownMenuItem(value: 'qwen-turbo', child: Text('Qwen Turbo')),
        ];
      case 'Anthropic Claude':
        return const [
          DropdownMenuItem(value: 'claude-3-sonnet', child: Text('Claude 3 Sonnet')),
          DropdownMenuItem(value: 'claude-3-haiku', child: Text('Claude 3 Haiku')),
        ];
      case 'Google Gemini':
        return const [
          DropdownMenuItem(value: 'gemini-pro', child: Text('Gemini Pro')),
          DropdownMenuItem(value: 'gemini-pro-vision', child: Text('Gemini Pro Vision')),
        ];
      default:
        return const [];
    }
  }

  /// 构建测试区域
  Widget _buildTestSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 测试前选择模型供应商与模型
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedProvider.isEmpty ? null : _selectedProvider,
                decoration: const InputDecoration(
                  labelText: '模型供应商 (测试用)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'OpenAI', child: Text('OpenAI')),
                  DropdownMenuItem(value: '阿里巴巴 (通义千问)', child: Text('阿里巴巴 (通义千问)')),
                  DropdownMenuItem(value: 'Anthropic Claude', child: Text('Anthropic Claude')),
                  DropdownMenuItem(value: 'Google Gemini', child: Text('Google Gemini')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedProvider = value ?? '';
                    _updateModelOptions();
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedModel.isEmpty ? null : _selectedModel,
                decoration: const InputDecoration(
                  labelText: '模型 (测试用)',
                  border: OutlineInputBorder(),
                ),
                items: _getModelOptions(),
                onChanged: (value) {
                  setState(() {
                    _selectedModel = value ?? '';
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 测试输入框
        TextField(
          controller: _testMessageController,
          decoration: const InputDecoration(
            hintText: '输入测试消息...',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.send),
          ),
          maxLines: 2,
          onSubmitted: (_) => _runTest(),
        ),
        const SizedBox(height: 16),
        
        // 测试按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isTestRunning ? null : _runTest,
            icon: _isTestRunning 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_isTestRunning ? '运行中...' : '运行测试'),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        
        if (_testResult != null) ...[
          const SizedBox(height: 16),
          _buildTestResult(),
        ],
      ],
    );
  }

  /// 构建测试结果显示
  Widget _buildTestResult() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _testResult!.isSuccess ? Icons.check_circle : Icons.error,
                  color: _testResult!.isSuccess ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _testResult!.isSuccess ? '测试成功' : '测试失败',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _testResult!.isSuccess ? Colors.green : Colors.red,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_testResult!.responseTimeMs}ms',
                  style: TextStyle(
                    fontSize: 12,
                    color: themeProvider.textSecondaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_testResult!.isSuccess) ...[
              Text(
                '响应:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: themeProvider.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeProvider.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: themeProvider.borderColor),
                ),
                child: SelectableText(
                  _testResult!.responseText,
                  style: TextStyle(
                    fontSize: 14,
                    color: themeProvider.textColor,
                  ),
                ),
              ),
              if (_testResult!.tokenUsage != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Token使用: ${_testResult!.totalTokens}',
                  style: TextStyle(
                    fontSize: 12,
                    color: themeProvider.textSecondaryColor,
                  ),
                ),
              ],
            ] else ...[
              Text(
                '错误信息:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: themeProvider.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: SelectableText(
                  _testResult!.errorMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 运行测试
  Future<void> _runTest() async {
    if (_selectedProvider.isEmpty || _selectedModel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择模型供应商与模型'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_testMessageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入测试消息'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isTestRunning = true;
      _testResult = null;
    });

    try {
      // 创建临时代理对象进行测试
      final testAgent = AIAgent(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        status: _selectedStatus,
        systemPrompt: _systemPromptController.text.trim(),
        providerName: _selectedProvider,
        modelName: _selectedModel,
        modelConfig: {
          'max_tokens': 1000,
          'temperature': 0.7,
        },
      );

      final result = await AIAgentService.runAgent(
        testAgent,
        _testMessageController.text.trim(),
        userId: 'admin',
        userName: 'Admin',
      );

      if (mounted) {
        setState(() {
          _testResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testResult = AgentRunResult(
            success: false,
            error: '测试异常: $e',
            duration: Duration.zero,
          );
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('测试失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestRunning = false;
        });
      }
    }
  }
}
