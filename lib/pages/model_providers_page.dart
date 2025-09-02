import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin_copilot/providers/theme_provider.dart';
import 'package:admin_copilot/services/database_service.dart';
import 'package:admin_copilot/services/log_service.dart';
import 'package:admin_copilot/services/api_test_service.dart';
import 'package:admin_copilot/models/model_provider.dart';
import 'package:admin_copilot/models/system_log.dart';
import 'package:admin_copilot/widgets/loading_widget.dart';

class ModelProvidersPage extends StatefulWidget {
  const ModelProvidersPage({super.key});

  @override
  State<ModelProvidersPage> createState() => _ModelProvidersPageState();
}

class _ModelProvidersPageState extends State<ModelProvidersPage> {
  List<ModelProvider> _providers = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Master-Detail 布局状态
  ProviderType? _selectedProviderType;
  ModelProvider? _selectedProvider;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  // 列表状态颜色/文本
  Color _statusColor(TestStatus status) {
    switch (status) {
      case TestStatus.success:
        return Colors.green;
      case TestStatus.failed:
        return Colors.red;
      case TestStatus.testing:
        return Colors.orange;
      case TestStatus.unknown:
        return Colors.grey;
    }
  }

  String _statusText(TestStatus status) {
    switch (status) {
      case TestStatus.success:
        return '连接正常';
      case TestStatus.failed:
        return '连接异常';
      case TestStatus.testing:
        return '测试中';
      case TestStatus.unknown:
        return '未知';
    }
  }

  Future<void> _loadProviders() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final providersData = await DatabaseService.getAllModelProviders();
      final providers = providersData.map((data) => ModelProvider.fromMap(data)).toList();
      
      // 记录日志
      await LogService.info(
        '加载模型提供商列表',
        details: '成功加载 ${providers.length} 个提供商',
        category: LogCategory.model,
      );
      
      setState(() {
        _providers = providers;
        _isLoading = false;
      });
    } catch (e) {
      // 记录错误日志
      await LogService.error(
        '加载模型提供商列表失败',
        details: '错误: $e',
        category: LogCategory.model,
      );
      
      setState(() {
        _errorMessage = '获取模型提供商列表失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Provider.of<ThemeProvider>(context).backgroundColor,
      appBar: AppBar(
        title: const Text('模型提供商'),
        backgroundColor: Provider.of<ThemeProvider>(context).surfaceColor,
        foregroundColor: Provider.of<ThemeProvider>(context).textColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget(message: '加载中...'))
          : _errorMessage != null
              ? Center(
                  child: AppErrorWidget(
                    message: _errorMessage!,
                    onRetry: _loadProviders,
                  ),
                )
              : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Row(
      children: [
        // 左侧：Master列表 (提供商列表)
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: themeProvider.surfaceColor,
            border: Border(
              right: BorderSide(color: themeProvider.borderColor),
            ),
          ),
          child: _buildMasterPanel(),
        ),
        // 右侧：Detail面板 (详情/配置区域)
        Expanded(
          child: _buildDetailPanel(),
        ),
      ],
    );
  }

  Widget _buildMasterPanel() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      children: [
        // 头部：已配置的提供商
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: themeProvider.borderColor),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已配置 (${_providers.length})',
                    style: TextStyle(
                      color: themeProvider.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showAddProviderDialog(context),
                    icon: const Icon(Icons.add),
                    iconSize: 20,
                    tooltip: '添加提供商',
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // 已配置的提供商列表
        if (_providers.isNotEmpty) ...[
          Expanded(
            flex: _providers.length > 3 ? 2 : 1,
            child: ListView.builder(
              itemCount: _providers.length,
              itemBuilder: (context, index) {
                final provider = _providers[index];
                return _buildMasterListItem(provider, true);
              },
            ),
          ),
          Container(
            height: 1,
            color: themeProvider.borderColor,
          ),
        ],
        
        // 支持的提供商标题
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                '支持的提供商',
                style: TextStyle(
                  color: themeProvider.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // 支持的提供商列表
        Expanded(
          flex: 3,
          child: ListView.builder(
            itemCount: _getSupportedProviders().length,
            itemBuilder: (context, index) {
              final providerData = _getSupportedProviders()[index];
              return _buildMasterListItem(null, false, providerData: providerData);
            },
          ),
        ),
      ],
    );
  }

  // Master列表项
  Widget _buildMasterListItem(ModelProvider? provider, bool isConfigured, {Map<String, dynamic>? providerData}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    ProviderType providerType;
    String name;
    String description;
    IconData icon;
    Color color;
    bool isSelected = false;
    
    if (isConfigured && provider != null) {
      providerType = provider.providerType;
      name = provider.name;
      description = providerType.displayName;
      final supportedProvider = _getSupportedProviders().firstWhere((p) => p['type'] == providerType);
      icon = supportedProvider['icon'];
      color = supportedProvider['color'];
      isSelected = _selectedProvider?.id == provider.id;
    } else if (providerData != null) {
      providerType = providerData['type'];
      name = providerType.displayName;
      description = providerData['description'];
      icon = providerData['icon'];
      color = providerData['color'];
      isSelected = _selectedProviderType == providerType && _selectedProvider == null;
    } else {
      return const SizedBox.shrink();
    }
    
    final hasConfigured = isConfigured ? true : _providers.any((p) => p.providerType == providerType);
    
    return Material(
      color: isSelected ? themeProvider.primaryColor.withOpacity(0.1) : Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isConfigured && provider != null) {
              _selectedProvider = provider;
              _selectedProviderType = null;
            } else {
              _selectedProviderType = providerType;
              _selectedProvider = null;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              left: isSelected 
                  ? BorderSide(color: themeProvider.primaryColor, width: 3)
                  : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onDoubleTap: () {
                    if (isConfigured && provider != null) {
                      _showEditProviderDialog(context, provider);
                    }
                  },
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: themeProvider.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        color: themeProvider.textSecondaryColor,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  ),
                ),
              ),
              if (hasConfigured && !isConfigured)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              if (isConfigured)
                Row(
                  children: [
                    // 连接状态小圆点
                    if (provider != null)
                      Tooltip(
                        message: _statusText(provider.testStatus),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _statusColor(provider.testStatus),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // 默认单选按钮（唯一）
                    IconButton(
                      tooltip: provider!.isDefault ? '默认配置' : '设为默认',
                      onPressed: () async {
                        if (!provider.isDefault) {
                          try {
                            await DatabaseService.setDefaultModelProvider(provider.id!);
                            await _loadProviders();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('设置默认失败: $e')),
                              );
                            }
                          }
                        }
                      },
                      icon: Icon(
                        provider.isDefault ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: provider.isDefault ? themeProvider.primaryColor : themeProvider.textSecondaryColor,
                        size: 18,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Detail面板
  Widget _buildDetailPanel() {
    if (_selectedProvider != null) {
      return _buildConfiguredProviderDetail(_selectedProvider!);
    } else if (_selectedProviderType != null) {
      return _buildSupportedProviderDetail(_selectedProviderType!);
    } else {
      return _buildWelcomeDetail();
    }
  }

  // 欢迎界面
  Widget _buildWelcomeDetail() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 64,
              color: themeProvider.textSecondaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              '选择一个模型提供商',
              style: TextStyle(
                color: themeProvider.textColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '从左侧列表中选择一个提供商来查看详细信息或进行配置',
              style: TextStyle(
                color: themeProvider.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 已配置提供商详情
  Widget _buildConfiguredProviderDetail(ModelProvider provider) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final supportedProvider = _getSupportedProviders().firstWhere((p) => p['type'] == provider.providerType);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: supportedProvider['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  supportedProvider['icon'],
                  color: supportedProvider['color'],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.name,
                      style: TextStyle(
                        color: themeProvider.textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      provider.providerType.displayName,
                      style: TextStyle(
                        color: themeProvider.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // 状态指示器
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: provider.testStatus == TestStatus.success ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      provider.testStatus == TestStatus.success ? Icons.check_circle : Icons.error,
                      size: 16,
                      color: provider.testStatus == TestStatus.success ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      provider.testStatus == TestStatus.success ? '连接正常' : '连接异常',
                      style: TextStyle(
                        color: provider.testStatus == TestStatus.success ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // 配置信息
          _buildConfigurationInfo(provider),
          
          const SizedBox(height: 32),
          
          // 操作按钮
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showEditProviderDialog(context, provider),
                icon: const Icon(Icons.edit),
                label: const Text('编辑配置'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _testConnection(provider),
                icon: const Icon(Icons.wifi_protected_setup),
                label: const Text('测试连接'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _deleteProvider(provider),
                icon: const Icon(Icons.delete),
                label: const Text('删除'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 支持提供商详情
  Widget _buildSupportedProviderDetail(ProviderType providerType) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final providerData = _getSupportedProviders().firstWhere((p) => p['type'] == providerType);
    final hasConfigured = _providers.any((p) => p.providerType == providerType);
    final configuredCount = _providers.where((p) => p.providerType == providerType).length;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: providerData['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  providerData['icon'],
                  color: providerData['color'],
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerType.displayName,
                      style: TextStyle(
                        color: themeProvider.textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      providerData['description'],
                      style: TextStyle(
                        color: themeProvider.textSecondaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // 代表模型
          if (providerData['models'] != null) ...[
            Text(
              '代表模型',
              style: TextStyle(
                color: themeProvider.textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeProvider.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: themeProvider.borderColor),
              ),
              child: Text(
                providerData['models'],
                style: TextStyle(
                  color: themeProvider.textColor,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // 特性
          Text(
            '主要特性',
            style: TextStyle(
              color: themeProvider.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (providerData['features'] as List<String>).map((feature) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: providerData['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  feature,
                  style: TextStyle(
                    color: providerData['color'],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 32),
          
          // 配置状态和操作
          if (hasConfigured) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '已配置 $configuredCount 个连接',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddProviderDialog(context, providerType),
                icon: const Icon(Icons.add),
                label: const Text('添加另一个配置'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAddProviderDialog(context, providerType),
                icon: const Icon(Icons.add),
                label: const Text('添加配置'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getSupportedProviders() {
    return [
      // 国际主要供应商
      {
        'type': ProviderType.openai,
        'description': '全球领先的AI模型提供商',
        'features': ['GPT-4', 'GPT-3.5', '多模态'],
        'models': 'GPT-3, GPT-3.5, GPT-4, GPT-4 Turbo',
        'icon': Icons.smart_toy,
        'color': Color(0xFF10A37F),
      },
      {
        'type': ProviderType.claude,
        'description': '安全可靠的AI助手',
        'features': ['Claude-3', '长上下文', '安全性'],
        'models': 'Claude 2, Claude 3 (Haiku, Sonnet, Opus)',
        'icon': Icons.psychology_alt,
        'color': Color(0xFFDE7C3F),
      },
      {
        'type': ProviderType.gemini,
        'description': 'Google的下一代AI模型',
        'features': ['Gemini Pro', '多模态', '长上下文'],
        'models': 'PaLM 2, Gemini (Pro, Ultra), Codey',
        'icon': Icons.auto_awesome,
        'color': Color(0xFF4285F4),
      },
      {
        'type': ProviderType.azureOpenai,
        'description': '企业级OpenAI服务',
        'features': ['企业级', '安全', '合规'],
        'models': 'Azure OpenAI Service',
        'icon': Icons.cloud,
        'color': Color(0xFF0078D4),
      },
      {
        'type': ProviderType.meta,
        'description': '开源策略的先驱',
        'features': ['开源', 'Llama系列', '社区驱动'],
        'models': 'Llama, Llama 2, Llama 3',
        'icon': Icons.dynamic_feed,
        'color': Color(0xFF1877F2),
      },
      {
        'type': ProviderType.amazon,
        'description': '统一的模型平台',
        'features': ['多供应商', 'AWS集成', '企业级'],
        'models': 'Titan系列 + 第三方模型',
        'icon': Icons.cloud_queue,
        'color': Color(0xFFFF9900),
      },
      {
        'type': ProviderType.microsoft,
        'description': 'Microsoft的AI助手',
        'features': ['Office集成', 'Azure', 'Copilot'],
        'models': 'Microsoft Research + OpenAI',
        'icon': Icons.business_center,
        'color': Color(0xFF00BCF2),
      },
      {
        'type': ProviderType.xai,
        'description': '追求真相的AI',
        'features': ['实时数据', 'X集成', '真相导向'],
        'models': 'Grok (集成在X平台)',
        'icon': Icons.clear_all,
        'color': Color(0xFF000000),
      },
      {
        'type': ProviderType.cohere,
        'description': '企业级NLP服务',
        'features': ['文本生成', '分类', '嵌入'],
        'models': 'Command, Embed, Classify',
        'icon': Icons.scatter_plot,
        'color': Color(0xFFFF6B35),
      },
      {
        'type': ProviderType.ai21,
        'description': '可控性强的企业AI',
        'features': ['可控性', '企业应用', '高质量'],
        'models': 'Jurassic系列模型',
        'icon': Icons.precision_manufacturing,
        'color': Color(0xFF4A90E2),
      },
      {
        'type': ProviderType.mistral,
        'description': '欧洲的明星AI公司',
        'features': ['高效', '开源', '欧洲'],
        'models': 'Mistral 7B, Mixtral 8x7B',
        'icon': Icons.euro_symbol,
        'color': Color(0xFF7C3AED),
      },
      {
        'type': ProviderType.inflection,
        'description': '个人AI助手专家',
        'features': ['个人助手', '对话式', '友好'],
        'models': 'Pi (个人AI助手)',
        'icon': Icons.person_pin,
        'color': Color(0xFF06B6D4),
      },
      
      // 中国主要供应商
      {
        'type': ProviderType.alibaba,
        'description': '阿里云提供的大模型服务',
        'features': ['多模态', '开源版本', '生态活跃'],
        'models': 'Qwen系列 (1.8B-72B, VL, Audio)',
        'icon': Icons.cloud_circle,
        'color': Color(0xFFFF6A00),
      },
      {
        'type': ProviderType.baidu,
        'description': '基于ERNIE的大模型',
        'features': ['中文优化', '搜索集成', '知识图谱'],
        'models': '文心一言 (ERNIE Bot)',
        'icon': Icons.search_rounded,
        'color': Color(0xFF2932E1),
      },
      {
        'type': ProviderType.tencent,
        'description': '腾讯自研大模型',
        'features': ['微信集成', '游戏应用', '办公场景'],
        'models': '混元 (HunYuan)',
        'icon': Icons.forum,
        'color': Color(0xFF07C160),
      },
      {
        'type': ProviderType.huawei,
        'description': '全栈自研的行业模型',
        'features': ['全栈自研', '行业应用', '芯片优化'],
        'models': '盘古大模型 (Pangu)',
        'icon': Icons.hub,
        'color': Color(0xFFFF0000),
      },
      {
        'type': ProviderType.bytedance,
        'description': '内容创作优化的大模型',
        'features': ['内容创作', '推荐算法', '短视频'],
        'models': '豆包 (Doubao) 大模型',
        'icon': Icons.music_video,
        'color': Color(0xFF000000),
      },
      {
        'type': ProviderType.zhipu,
        'description': '清华背景的学术级AI',
        'features': ['学术声誉', 'API服务', '企业方案'],
        'models': 'GLM系列 (GLM-4)',
        'icon': Icons.school_outlined,
        'color': Color(0xFF722ED1),
      },
      {
        'type': ProviderType.moonshot,
        'description': '超长上下文处理专家',
        'features': ['超长上下文', '200万字符', '文档处理'],
        'models': 'Kimi Chat',
        'icon': Icons.nightlight_round,
        'color': Color(0xFF9C27B0),
      },
      {
        'type': ProviderType.zeroone,
        'description': '李开复创立的AI公司',
        'features': ['基准测试优异', '开源策略', '多语言'],
        'models': 'Yi系列大模型',
        'icon': Icons.insights,
        'color': Color(0xFF00BCD4),
      },
      
      // 本地和自定义
      {
        'type': ProviderType.ollama,
        'description': '本地运行的开源模型',
        'features': ['本地部署', '开源', '隐私保护'],
        'models': '支持多种开源模型',
        'icon': Icons.dns,
        'color': Color(0xFF8B5CF6),
      },
      {
        'type': ProviderType.custom,
        'description': 'OpenAI兼容的自定义服务',
        'features': ['灵活配置', '兼容接口', '自定义部署'],
        'models': '任何OpenAI兼容服务',
        'icon': Icons.build_circle,
        'color': Color(0xFF6B7280),
      },
    ];
  }

  // 配置信息展示
  Widget _buildConfigurationInfo(ModelProvider provider) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '配置信息',
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        if (provider.apiKey != null)
          _buildInfoRow('API Key', '${provider.apiKey!.length > 8 ? provider.apiKey!.substring(0, 8) + '...' : provider.apiKey!}', Icons.key),
        
        if (provider.baseUrl != null)
          _buildInfoRow('Base URL', provider.baseUrl!, Icons.link),
        
        if (provider.serverUrl != null)
          _buildInfoRow('服务器地址', provider.serverUrl!, Icons.dns),
        
        if (provider.endpointUrl != null)
          _buildInfoRow('端点地址', provider.endpointUrl!, Icons.api),
        
        if (provider.deploymentName != null)
          _buildInfoRow('部署名称', provider.deploymentName!, Icons.cloud),
        
        _buildInfoRow('创建时间', _formatDateTime(provider.createdAt), Icons.schedule),
        
        if (provider.lastTestTime != null)
          _buildInfoRow('最后测试', _formatDateTime(provider.lastTestTime!), Icons.check_circle),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: themeProvider.textSecondaryColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: themeProvider.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: themeProvider.textColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 编辑提供商对话框
  void _showEditProviderDialog(BuildContext context, ModelProvider provider) {
    showDialog(
      context: context,
      builder: (context) => ProviderDialog(
        provider: provider,
        onSave: (updatedProvider) async {
          try {
            await DatabaseService.updateModelProvider(updatedProvider.id!, updatedProvider.toMap());
            
            // 记录日志
            await LogService.modelOperation(
              '更新模型提供商',
              details: '提供商: ${updatedProvider.name}, 类型: ${updatedProvider.providerType.displayName}',
              userId: 'admin',
              userName: 'Admin',
            );
            
            await _loadProviders();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('提供商配置已更新')),
              );
            }
          } catch (e) {
            // 记录错误日志
            await LogService.error(
              '更新模型提供商失败',
              details: '提供商: ${updatedProvider.name}, 错误: $e',
              category: LogCategory.model,
            );
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('更新失败: $e')),
              );
            }
          }
        },
      ),
    );
  }

  // 测试连接
  void _testConnection(ModelProvider provider) async {
    try {
      setState(() {
        // 更新测试状态为正在测试
        final index = _providers.indexWhere((p) => p.id == provider.id);
        if (index != -1) {
          _providers[index] = provider.copyWith(testStatus: TestStatus.testing);
        }
      });

      // 记录请求开始日志
      await LogService.apiCall(
        '开始测试模型提供商连接',
        details: '开始API请求测试',
        userId: 'admin',
        userName: 'Admin',
        metadata: {
          'provider_name': provider.name,
          'provider_type': provider.providerType.displayName,
          'provider_id': provider.id,
          'api_key_preview': provider.apiKey != null ? '${provider.apiKey!.substring(0, 8)}...' : '未设置',
          'base_url': provider.baseUrl,
          'server_url': provider.serverUrl,
          'endpoint_url': provider.endpointUrl,
          'deployment_name': provider.deploymentName,
        },
      );

      // 执行真实的API测试
      final testResult = await ApiTestService.testProviderConnection(provider);
      
      // 记录测试结果日志
      await LogService.apiCall(
        '测试模型提供商连接完成',
        details: testResult.success ? 'API请求测试成功' : 'API请求测试失败',
        userId: 'admin',
        userName: 'Admin',
        metadata: {
          'provider_name': provider.name,
          'provider_type': provider.providerType.displayName,
          'provider_id': provider.id,
          'request_url': testResult.requestUrl,
          'request_method': testResult.requestUrl.contains('chat/completions') ? 'POST' : 'GET',
          'request_headers': testResult.requestHeaders,
          'response_status': testResult.success ? 'success' : 'error',
          'response_status_code': testResult.statusCode,
          'response_body': testResult.responseBody,
          'response_time_ms': testResult.responseTime,
          'success': testResult.success,
          'error_message': testResult.errorMessage,
          'api_key_preview': provider.apiKey != null ? '${provider.apiKey!.substring(0, 8)}...' : '未设置',
          'base_url': provider.baseUrl,
        },
      );
      
      // 更新数据库中的测试状态
      final testStatus = testResult.success ? TestStatus.success : TestStatus.failed;
      await DatabaseService.updateModelProviderTestStatus(
        provider.id!,
        testStatus.value,
        DateTime.now(),
      );
      
      // 重新加载提供商列表
      await _loadProviders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              testResult.success 
                ? '连接测试成功 (${testResult.responseTime}ms)' 
                : '连接测试失败: ${testResult.errorMessage ?? "未知错误"}'
            ),
            backgroundColor: testResult.success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      // 记录错误日志
      await LogService.error(
        '测试模型提供商连接失败',
        details: 'API请求异常: $e',
        category: LogCategory.api,
        userId: 'admin',
        userName: 'Admin',
        metadata: {
          'provider_name': provider.name,
          'provider_type': provider.providerType.displayName,
          'error': e.toString(),
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('测试连接失败: $e')),
        );
      }
    }
  }



  // 删除提供商
  void _deleteProvider(ModelProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除提供商 "${provider.name}" 吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
                          try {
              await DatabaseService.deleteModelProvider(provider.id!);
              
              // 记录日志
              await LogService.modelOperation(
                '删除模型提供商',
                details: '提供商: ${provider.name}, 类型: ${provider.providerType.displayName}',
                userId: 'admin',
                userName: 'Admin',
              );
              
              await _loadProviders();
              
              // 如果删除的是当前选中的提供商，清除选择
              if (_selectedProvider?.id == provider.id) {
                setState(() {
                  _selectedProvider = null;
                });
              }
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('提供商已删除')),
                );
              }
            } catch (e) {
              // 记录错误日志
              await LogService.error(
                '删除模型提供商失败',
                details: '提供商: ${provider.name}, 错误: $e',
                category: LogCategory.model,
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('删除失败: $e')),
                );
              }
            }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // 添加提供商对话框
  void _showAddProviderDialog(BuildContext context, [ProviderType? providerType]) {
    showDialog(
      context: context,
      builder: (context) => ProviderDialog(
        providerType: providerType,
        onSave: (provider) async {
          try {
            await DatabaseService.insertModelProvider(provider.toMap());
            
            // 记录日志
            await LogService.modelOperation(
              '添加模型提供商',
              details: '提供商: ${provider.name}, 类型: ${provider.providerType.displayName}',
              userId: 'admin',
              userName: 'Admin',
            );
            
            await _loadProviders();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('提供商配置已保存')),
              );
            }
          } catch (e) {
            // 记录错误日志
            await LogService.error(
              '添加模型提供商失败',
              details: '提供商: ${provider.name}, 错误: $e',
              category: LogCategory.model,
            );
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('保存失败: $e')),
              );
            }
          }
        },
      ),
    );
  }
}

// 提供商配置对话框
class ProviderDialog extends StatefulWidget {
  final ModelProvider? provider; // 编辑时传入
  final ProviderType? providerType; // 新增时传入
  final Function(ModelProvider) onSave;

  const ProviderDialog({
    Key? key,
    this.provider,
    this.providerType,
    required this.onSave,
  }) : super(key: key);

  @override
  State<ProviderDialog> createState() => _ProviderDialogState();
}

class _ProviderDialogState extends State<ProviderDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _serverUrlController;
  late TextEditingController _endpointUrlController;
  late TextEditingController _deploymentNameController;
  
  late ProviderType _selectedProviderType;
  bool _isActive = true;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    
    // 初始化控制器
    _nameController = TextEditingController();
    _apiKeyController = TextEditingController();
    _baseUrlController = TextEditingController();
    _serverUrlController = TextEditingController();
    _endpointUrlController = TextEditingController();
    _deploymentNameController = TextEditingController();
    
    // 设置初始值
    if (widget.provider != null) {
      // 编辑模式
      final provider = widget.provider!;
      _nameController.text = provider.name;
      _apiKeyController.text = provider.apiKey ?? '';
      _baseUrlController.text = provider.baseUrl ?? '';
      _serverUrlController.text = provider.serverUrl ?? '';
      _endpointUrlController.text = provider.endpointUrl ?? '';
      _deploymentNameController.text = provider.deploymentName ?? '';
      _selectedProviderType = provider.providerType;
      _isActive = provider.isActive;
      _isDefault = provider.isDefault;
    } else {
      // 新增模式
      _selectedProviderType = widget.providerType ?? ProviderType.openai;
      _nameController.text = _getDefaultName(_selectedProviderType);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _serverUrlController.dispose();
    _endpointUrlController.dispose();
    _deploymentNameController.dispose();
    super.dispose();
  }

  String _getDefaultName(ProviderType type) {
    return '${type.displayName} 配置';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(
                  widget.provider != null ? Icons.edit : Icons.add,
                  color: themeProvider.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.provider != null ? '编辑提供商' : '添加提供商',
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // 表单
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 提供商类型选择
                      if (widget.provider == null) ...[
                        Text(
                          '提供商类型',
                          style: TextStyle(
                            color: themeProvider.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<ProviderType>(
                          value: _selectedProviderType,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            filled: true,
                            fillColor: themeProvider.surfaceColor,
                          ),
                          items: ProviderType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedProviderType = value;
                                _nameController.text = _getDefaultName(value);
                              });
                            }
                          },
                          validator: (value) => value == null ? '请选择提供商类型' : null,
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // 配置名称
                      _buildTextField(
                        controller: _nameController,
                        label: '配置名称',
                        hint: '为这个配置起一个名字',
                        validator: (value) => value?.isEmpty ?? true ? '请输入配置名称' : null,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 动态字段
                      ..._buildProviderSpecificFields(),
                      
                      // 激活状态
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Switch(
                            value: _isActive,
                            onChanged: (value) => setState(() => _isActive = value),
                            activeColor: themeProvider.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '激活此配置',
                            style: TextStyle(
                              color: themeProvider.textColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Switch(
                            value: _isDefault,
                            onChanged: (value) => setState(() => _isDefault = value),
                            activeColor: themeProvider.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '设为默认',
                            style: TextStyle(
                              color: themeProvider.textColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saveProvider,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.primaryColor,
                  ),
                  child: Text(widget.provider != null ? '更新' : '保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: themeProvider.surfaceColor,
            suffixIcon: suffixIcon,
          ),
          validator: validator,
        ),
      ],
    );
  }

  List<Widget> _buildProviderSpecificFields() {
    switch (_selectedProviderType) {
      case ProviderType.openai:
      case ProviderType.claude:
      case ProviderType.gemini:
      case ProviderType.cohere:
      case ProviderType.ai21:
      case ProviderType.mistral:
      case ProviderType.inflection:
      case ProviderType.alibaba:
      case ProviderType.baidu:
      case ProviderType.tencent:
      case ProviderType.huawei:
      case ProviderType.bytedance:
      case ProviderType.zhipu:
      case ProviderType.moonshot:
      case ProviderType.zeroone:
        return [
          _buildTextField(
            controller: _apiKeyController,
            label: 'API Key',
            hint: '输入您的API密钥',
            obscureText: true,
            validator: (value) => value?.isEmpty ?? true ? '请输入API Key' : null,
            suffixIcon: IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showHelpDialog('API Key', '请访问提供商官网获取API密钥'),
            ),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _baseUrlController,
            label: 'Base URL (可选)',
            hint: '自定义API地址',
            suffixIcon: IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showHelpDialog('Base URL', '如果您使用代理或自定义端点，请填写此项'),
            ),
          ),
        ];
        
      case ProviderType.azureOpenai:
        return [
          _buildTextField(
            controller: _apiKeyController,
            label: 'API Key',
            hint: '输入您的Azure OpenAI API密钥',
            obscureText: true,
            validator: (value) => value?.isEmpty ?? true ? '请输入API Key' : null,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _endpointUrlController,
            label: 'Endpoint URL',
            hint: 'https://your-resource.openai.azure.com/',
            validator: (value) => value?.isEmpty ?? true ? '请输入Endpoint URL' : null,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _deploymentNameController,
            label: 'Deployment Name',
            hint: '您的部署名称',
            validator: (value) => value?.isEmpty ?? true ? '请输入部署名称' : null,
          ),
        ];
        
      case ProviderType.ollama:
        return [
          _buildTextField(
            controller: _serverUrlController,
            label: '服务器地址',
            hint: 'http://localhost:11434',
            validator: (value) => value?.isEmpty ?? true ? '请输入服务器地址' : null,
            suffixIcon: IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showHelpDialog('服务器地址', '请输入Ollama服务器的完整地址，默认为 http://localhost:11434'),
            ),
          ),
        ];
        
      case ProviderType.custom:
        return [
          _buildTextField(
            controller: _baseUrlController,
            label: 'Base URL',
            hint: 'https://api.example.com/v1',
            validator: (value) => value?.isEmpty ?? true ? '请输入Base URL' : null,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _apiKeyController,
            label: 'API Key (可选)',
            hint: '如果需要认证，请输入API密钥',
            obscureText: true,
          ),
        ];
        
      default:
        return [
          _buildTextField(
            controller: _apiKeyController,
            label: 'API Key',
            hint: '输入您的API密钥',
            obscureText: true,
            validator: (value) => value?.isEmpty ?? true ? '请输入API Key' : null,
          ),
        ];
    }
  }

  void _showHelpDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _saveProvider() {
    if (!_formKey.currentState!.validate()) return;

    final provider = ModelProvider(
      id: widget.provider?.id,
      name: _nameController.text.trim(),
      providerType: _selectedProviderType,
      apiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim().isEmpty ? null : _baseUrlController.text.trim(),
      serverUrl: _serverUrlController.text.trim().isEmpty ? null : _serverUrlController.text.trim(),
      endpointUrl: _endpointUrlController.text.trim().isEmpty ? null : _endpointUrlController.text.trim(),
      deploymentName: _deploymentNameController.text.trim().isEmpty ? null : _deploymentNameController.text.trim(),
      isActive: _isActive,
      isDefault: _isDefault,
      createdAt: widget.provider?.createdAt,
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop();
    widget.onSave(provider);
  }
}
