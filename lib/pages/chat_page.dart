import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../providers/theme_provider.dart';
import '../models/ai_agent.dart';
import '../models/model_provider.dart';
import '../models/knowledge_base.dart';
import '../services/database_service.dart';
import '../services/ai_agent_service.dart';
import '../services/log_service.dart';
import '../services/rag_service.dart';

import '../services/conversation_title_service.dart';

/// 选中的文件信息
class SelectedFile {
  final String name;
  final String path;
  final int size;
  final String type;
  final DateTime selectedTime;

  SelectedFile({
    required this.name,
    required this.path,
    required this.size,
    required this.type,
    required this.selectedTime,
  });

  /// 获取文件扩展名
  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? '.${parts.last.toLowerCase()}' : '';
  }

  /// 检查是否是图片文件
  bool get isImage {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg'];
    return imageExtensions.contains(extension);
  }

  /// 检查是否是PDF文件
  bool get isPdf => extension == '.pdf';

  /// 检查是否是文档文件
  bool get isDocument {
    final docExtensions = ['.doc', '.docx', '.pdf', '.txt', '.rtf'];
    return docExtensions.contains(extension);
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  // 右侧覆盖式“AI配置与调试中心”
  late final AnimationController _panelAnimController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<Offset> _panelSlide = Tween<Offset>(
    begin: const Offset(1.0, 0.0),
    end: const Offset(0.0, 0.0),
  ).animate(CurvedAnimation(parent: _panelAnimController, curve: Curves.easeOutCubic));
  AIAgent? _selectedAgent;
  List<AIAgent> _availableAgents = [];
  List<ModelProvider> _modelProviders = [];
  bool _loadingProviders = true;
  ModelProvider? _selectedProvider;
  String? _selectedModel;
  String _customModelInput = '';
  bool _showRightPanel = false;
  
  // 知识库相关
  List<KnowledgeBase> _availableKnowledgeBases = [];
  KnowledgeBase? _selectedKnowledgeBase;
  
  // 对话管理
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  int _selectedTabIndex = 0;
  
  // 文件管理
  List<SelectedFile> _selectedFiles = [];
  
  // UI 控制
  bool _showTechnicalInfo = false; // 是否显示技术信息
  String? _selectedMessageId; // 当前选中的消息ID，用于在右侧面板显示技术信息

  @override
  void initState() {
    super.initState();
    _loadAvailableAgents();
    _loadModelProviders();
    _loadKnowledgeBases();
    _loadConversations(); // 使用新的数据库加载方法
    
    // 监听输入框变化，用于动态更新发送按钮状态
    _messageController.addListener(() {
      setState(() {});
    });
    
    LogService.userAction(
      '用户访问聊天页面',
      details: '用户进入AI对话界面',
      userId: 'admin',
      userName: 'Admin',
    );
  }

  /// 加载可用知识库
  Future<void> _loadKnowledgeBases() async {
    try {
      final data = await DatabaseService.getAllKnowledgeBases();
      if (mounted) {
        setState(() {
          _availableKnowledgeBases = data.map((json) => KnowledgeBase.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print('加载知识库失败: $e');
    }
  }

  /// 从本地设置加载已保存的对话记录
  Future<void> _loadSavedConversations() async {
    try {
      final jsonStr = await DatabaseService.getSetting('chat_conversations');
      if (jsonStr == null || jsonStr.isEmpty) return;
      final List<dynamic> list = jsonDecode(jsonStr);
      final loaded = <Conversation>[];
      for (final item in list) {
        final agent = AIAgent.fromMap((item['agent'] as Map).cast<String, dynamic>());
        final messages = (item['messages'] as List<dynamic>).map((m) {
          final mm = (m as Map).cast<String, dynamic>();
          return ChatMessage(
            content: mm['content'] as String,
            isUser: mm['isUser'] as bool,
            timestamp: DateTime.parse(mm['timestamp'] as String),
            agentName: mm['agentName'] as String?,
            metadata: (mm['metadata'] as Map?)?.cast<String, dynamic>(),
            isError: mm['isError'] as bool? ?? false,
          );
        }).toList();
        loaded.add(Conversation(
          id: item['id'] as String,
          title: item['title'] as String,
          agent: agent,
          createdAt: DateTime.parse(item['createdAt'] as String),
          lastUpdated: DateTime.parse(item['lastUpdated'] as String),
          messages: messages,
          isPinned: item['isPinned'] as bool? ?? false,
          metadata: (item['metadata'] as Map?)?.cast<String, dynamic>(),
        ));
      }
      if (mounted) {
        setState(() {
          _conversations = loaded;
          if (_conversations.isNotEmpty) {
            _currentConversation = _conversations.first;
            _selectedAgent = _currentConversation!.agent;
            _messages
              ..clear()
              ..addAll(_currentConversation!.messages);
          }
        });
      }
    } catch (e) {
      print('加载对话记录失败: $e');
    }
  }

  /// 加载对话列表
  Future<void> _loadConversations() async {
    try {
      final conversations = await DatabaseService.getAllConversations();
      final conversationList = <Conversation>[];
      
      for (final data in conversations) {
        // 获取对话的消息
        final messages = await DatabaseService.getConversationMessages(data['id']);
        final chatMessages = messages.map((msg) => ChatMessage(
          content: msg['content'] as String,
          isUser: (msg['is_user'] as int) == 1,
          timestamp: DateTime.parse(msg['timestamp'] as String),
          agentName: msg['agent_name'] as String?,
          metadata: msg['metadata'] as Map<String, dynamic>?,
          isError: (msg['is_error'] as int) == 1,
          canRetry: (msg['can_retry'] as int) == 1,
          attachedFiles: (msg['attached_files'] as List<dynamic>?)?.map((f) => File(f as String)).toList(),
          isEditing: (msg['is_editing'] as int) == 1,
          originalContent: msg['original_content'] as String?,
        )).toList();
        
        // 获取关联的代理信息
        AIAgent? agent;
        if (data['agent_id'] != null) {
          final agentData = await DatabaseService.getAIAgentById(data['agent_id'] as int);
          if (agentData != null) {
            agent = AIAgent.fromMap(agentData);
          }
        }
        
        final conversation = Conversation(
          id: data['id'] as String,
          title: data['title'] as String,
          agent: agent,
          createdAt: DateTime.parse(data['created_at'] as String),
          lastUpdated: DateTime.parse(data['last_updated'] as String),
          messages: chatMessages,
          isPinned: (data['is_pinned'] as int) == 1,
          metadata: data['metadata'] as Map<String, dynamic>?,
        );
        
        conversationList.add(conversation);
      }
      
      setState(() {
        _conversations = conversationList;
      });
    } catch (e) {
      print('加载对话列表失败: $e');
    }
  }

  /// 持久化当前对话列表到本地设置
  Future<void> _persistConversations() async {
    try {
      final data = _conversations.map((c) => c.toMap()).toList();
      await DatabaseService.saveSetting('chat_conversations', jsonEncode(data));
    } catch (e) {
      print('保存对话记录失败: $e');
    }
  }

  Map<ProviderType, List<ModelProvider>> _groupProvidersByType() {
    final map = <ProviderType, List<ModelProvider>>{};
    for (final p in _modelProviders) {
      map.putIfAbsent(p.providerType, () => []).add(p);
    }
    return map;
  }

  /// 根据右侧选择确保存在一个可用代理
  Future<bool> _ensureAgentFromSelection() async {
    if (_selectedProvider == null) return false;
    // 解析模型名
    String? modelName = _selectedModel?.trim();
    final customModel = _customModelInput.trim();
    if (modelName == null || modelName.isEmpty) {
      modelName = customModel.isEmpty ? null : customModel;
    }
    // 当所选模型与供应商类型不匹配时，自动采用该供应商的推荐第一个模型
    final suggestions = _getSuggestedModels(_selectedProvider!.providerType);
    final looksMismatched = () {
      if (suggestions.isEmpty || modelName == null || modelName!.isEmpty) return false;
      switch (_selectedProvider!.providerType) {
        case ProviderType.alibaba:
          return !modelName!.toLowerCase().startsWith('qwen');
        case ProviderType.openai:
          return !modelName!.toLowerCase().startsWith('gpt');
        default:
          return false;
      }
    }();
    if ((modelName == null || modelName.isEmpty) || looksMismatched) {
      modelName = suggestions.isNotEmpty ? suggestions.first : modelName;
    }
    if (modelName == null || modelName.isEmpty) return false;

    final agent = AIAgent(
      name: '临时代理 - ${_selectedProvider!.name}',
      description: '基于当前选择自动创建的临时代理',
      type: AgentType.custom,
      status: AgentStatus.active,
      systemPrompt: '你是一个通用AI助手。',
      providerName: _selectedProvider!.name,
      modelName: modelName,
      modelConfig: {
        'max_tokens': 1000,
        'temperature': 0.7,
      },
    );

    try {
      LogService.apiCall(
        '创建临时代理',
        details: 'provider: ${_selectedProvider!.name}, model: $modelName',
        metadata: {
          'provider_type': _selectedProvider!.providerType.displayName,
          'base_url': _selectedProvider!.baseUrl,
          'endpoint_url': _selectedProvider!.endpointUrl,
          'deployment_name': _selectedProvider!.deploymentName,
        },
      );
      final id = await DatabaseService.insertAIAgent(agent.toMap());
      final saved = await DatabaseService.getAIAgentById(id);
      if (saved != null) {
        setState(() {
          _selectedAgent = AIAgent.fromMap(saved);
          _availableAgents.insert(0, _selectedAgent!);
        });
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void _showProviderPickerDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择供应商'),
          content: SizedBox(
            width: 520,
            height: 420,
            child: ListView(
              children: _groupProvidersByType().entries.map((entry) {
                final type = entry.key;
                final providers = entry.value;
                return ExpansionTile(
                  title: Text(type.displayName),
                  children: providers.map((p) {
                    final isSelected = _selectedProvider?.id == p.id;
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? themeProvider.primaryColor : themeProvider.textSecondaryColor,
                      ),
                      title: Text(p.name),
                      subtitle: Text(p.providerType.displayName),
                      onTap: () {
                        setState(() {
                          _selectedProvider = p;
                          final suggestions = _getSuggestedModels(p.providerType);
                          _selectedModel = suggestions.isNotEmpty ? suggestions.first : null;
                          _customModelInput = '';
                        });
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          ],
        );
      },
    );
  }

  void _showModelPickerDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final suggestions = _getSuggestedModels(_selectedProvider!.providerType);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择模型'),
        content: SizedBox(
          width: 480,
          height: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (suggestions.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions.map((m) {
                    final isSel = _selectedModel == m;
                    return ChoiceChip(
                      label: Text(m),
                      selected: isSel,
                      onSelected: (_) => setState(() => _selectedModel = m),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: '自定义模型名称',
                  hintText: '例如 gpt-4o / qwen-max',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _customModelInput = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (_customModelInput.isNotEmpty) {
                  _selectedModel = _customModelInput.trim();
                }
              });
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadModelProviders() async {
    try {
      setState(() => _loadingProviders = true);
      final rows = await DatabaseService.getAllModelProviders();
      final list = rows.map((e) => ModelProvider.fromMap(e)).toList();
      if (mounted) {
        setState(() {
          _modelProviders = list;
          _loadingProviders = false;
          // 自动选中默认供应商
          _selectedProvider = list.isEmpty
              ? null
              : list.firstWhere(
                  (p) => p.isDefault,
                  orElse: () => list.first,
                );
          // 若存在默认供应商，为其选择第一个建议模型
          if (_selectedProvider != null) {
            final suggestions = _getSuggestedModels(_selectedProvider!.providerType);
            if (suggestions.isNotEmpty) {
              _selectedModel = suggestions.first;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingProviders = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载模型供应商失败: $e')),
        );
      }
    }
  }

  // 根据供应商类型给出常用模型建议
  List<String> _getSuggestedModels(ProviderType type) {
    switch (type) {
      case ProviderType.alibaba:
        return ['qwen-max', 'qwen-plus', 'qwen-turbo'];
      case ProviderType.openai:
        return ['gpt-4o', 'gpt-4', 'gpt-3.5-turbo'];
      case ProviderType.azureOpenai:
        return [
          if (_selectedProvider?.deploymentName != null) _selectedProvider!.deploymentName!,
          'chat/completions 部署名',
        ];
      case ProviderType.gemini:
        return ['gemini-pro', 'gemini-1.5-pro'];
      case ProviderType.claude:
        return ['claude-3-sonnet', 'claude-3-haiku'];
      case ProviderType.mistral:
        return ['mistral-large', 'mixtral-8x7b'];
      case ProviderType.meta:
        return ['llama3-70b', 'llama3-8b'];
      case ProviderType.ollama:
        return ['llama3', 'qwen2', 'mistral'];
      default:
        return [];
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _panelAnimController.dispose();
    super.dispose();
  }

  /// 加载可用的AI代理
  Future<void> _loadAvailableAgents() async {
    try {
      final agentsData = await DatabaseService.getAllAIAgents();
      final agents = agentsData.map((data) => AIAgent.fromMap(data)).toList();
      
      if (mounted) {
        setState(() {
          _availableAgents = agents;
          if (agents.isNotEmpty) {
            _selectedAgent = agents.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载AI代理失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 发送消息
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    print('=== 发送消息开始 ===');
    print('原始消息: "$message"');
    print('选中文件数量: ${_selectedFiles.length}');
    
    if (message.isEmpty && _selectedFiles.isEmpty) {
      print('消息和文件都为空，退出');
      return;
    }
    
    // 构建包含文件信息的消息
    String fullMessage = message;
    if (_selectedFiles.isNotEmpty) {
      print('开始处理文件...');
      for (int i = 0; i < _selectedFiles.length; i++) {
        final file = _selectedFiles[i];
        print('文件 $i: ${file.name}, 大小: ${file.size}, 路径: ${file.path}');
      }
      
      final fileList = _selectedFiles.map((file) => 
        '📎 ${file.name} (${_formatFileSize(file.size)})'
      ).join('\n');
      
      if (fullMessage.isNotEmpty) {
        fullMessage += '\n\n附件:\n$fileList';
      } else {
        fullMessage = '附件:\n$fileList';
      }
      
      print('构建后的完整消息: "$fullMessage"');
    }

    // 如果使用通用助手模式且右侧选择了提供商，则自动创建临时代理
    if (_selectedAgent == null && _selectedProvider != null) {
      LogService.userAction(
        '准备创建临时代理',
        details: 'selectedProvider: \'${_selectedProvider?.name}\', providerType: \'${_selectedProvider?.providerType.displayName}\', selectedModel: \'${_selectedModel}\', customModel: \'$_customModelInput\'',
        userId: 'admin',
        userName: 'Admin',
      );
      final created = await _ensureAgentFromSelection();
      if (!created) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先在右侧选择模型供应商与模型')),
        );
        return;
      }
    }

    // 如果没有当前对话，创建一个新的
    if (_currentConversation == null) {
      _createConversationWithAgent(_selectedAgent);
    }
    
    // 准备文件列表（在try块外部定义，以便catch块可以访问）
    List<File> filesToUpload = [];
    
    // 先处理文件列表，为生成标题做准备
    if (_selectedFiles.isNotEmpty) {
      for (int i = 0; i < _selectedFiles.length; i++) {
        final selectedFile = _selectedFiles[i];
        final file = File(selectedFile.path);
        final exists = await file.exists();
        if (exists) {
          filesToUpload.add(file);
        }
      }
    }
    
    // 检查是否需要生成对话标题（第一条用户消息）
    final isFirstUserMessage = _messages.where((m) => m.isUser).isEmpty;
    if (isFirstUserMessage && _currentConversation != null) {
      // 生成智能标题
      final generatedTitle = ConversationTitleService.generateTitle(message, filesToUpload);
      print('生成对话标题: $generatedTitle');
      
      // 更新数据库中的对话标题
      await DatabaseService.updateConversationTitle(_currentConversation!.id, generatedTitle);
      
      // 更新内存中的对话标题
      setState(() {
        _currentConversation = _currentConversation!.copyWith(title: generatedTitle);
        // 更新对话列表中的对应项
        final index = _conversations.indexWhere((c) => c.id == _currentConversation!.id);
        if (index != -1) {
          _conversations[index] = _currentConversation!;
        }
      });
    }

    final userMessage = ChatMessage(
      content: fullMessage,
      isUser: true,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    
    _messageController.clear();
    _scrollToBottom();
    
    // 保存用户消息到数据库
    if (_currentConversation != null) {
      await DatabaseService.addChatMessage(
        conversationId: _currentConversation!.id,
        content: fullMessage,
        isUser: true,
        attachedFiles: filesToUpload.map((f) => f.path).toList(),
      );
    }
    
    try {
      // 如果没有选择代理且没有配置提供商，显示提示信息
      if (_selectedAgent == null && _selectedProvider == null) {
        final aiMessage = ChatMessage(
          content: '抱歉，我需要配置AI模型才能回答您的问题。请在右侧面板中选择一个模型提供商和模型，或者切换到专业的AI代理。',
          isUser: false,
          timestamp: DateTime.now(),
          agentName: '通用助手',
        );
        
        setState(() {
          _messages.add(aiMessage);
          _isLoading = false;
        });
        return;
      }

      // 根据右侧面板选择，必要时覆盖当前代理的提供商/模型
      AIAgent? agentToUse = _selectedAgent;
      if (_selectedProvider != null) {
        // 解析模型名（优先选中值，其次自定义，其次推荐）
        String? modelName = _selectedModel?.trim();
        final customModel = _customModelInput.trim();
        if (modelName == null || modelName.isEmpty) {
          modelName = customModel.isEmpty ? null : customModel;
        }
        final suggestions = _getSuggestedModels(_selectedProvider!.providerType);
        final looksMismatched = () {
          if (suggestions.isEmpty || modelName == null || modelName!.isEmpty) return false;
          switch (_selectedProvider!.providerType) {
            case ProviderType.alibaba:
              return !modelName!.toLowerCase().startsWith('qwen');
            case ProviderType.openai:
              return !modelName!.toLowerCase().startsWith('gpt');
            default:
              return false;
          }
        }();
        if ((modelName == null || modelName.isEmpty) || looksMismatched) {
          modelName = suggestions.isNotEmpty ? suggestions.first : modelName;
        }

        agentToUse = (_selectedAgent ?? _createDefaultAgent()).copyWith(
          providerName: _selectedProvider!.name,
          modelName: modelName,
        );
      }

      // 确保有可用的代理
      agentToUse ??= _createDefaultAgent();

      // 文件列表已在前面处理完成
      print('最终上传文件数量: ${filesToUpload.length}');

      // 发送前记录本次使用的具体代理信息
      LogService.apiCall(
        '发送对话请求(预备)',
        details: 'agent: ${agentToUse!.name}',
        metadata: {
          'provider_name': agentToUse!.providerName,
          'model_name': agentToUse!.modelName,
          'model_config': agentToUse!.modelConfig,
        },
      );
      print('调用AI代理服务...');
      print('代理名称: ${agentToUse!.name}');
      print('消息内容: "$fullMessage"');
      print('文件数量: ${filesToUpload.length}');
      
      final result = await AIAgentService.runAgent(
        agentToUse!,
        fullMessage,
        userId: 'admin',
        userName: 'Admin',
        knowledgeBaseId: _selectedKnowledgeBase?.id,
        files: filesToUpload.isNotEmpty ? filesToUpload : null,
      );
      
      print('AI代理服务调用完成');
      print('结果成功: ${result.isSuccess}');
      if (!result.isSuccess) {
        print('错误信息: ${result.errorMessage}');
      }
      
      // 清空选中的文件
      setState(() {
        _selectedFiles.clear();
      });

      if (mounted) {
        if (result.isSuccess) {
          final aiMessage = ChatMessage(
            content: result.response ?? '抱歉，我没有收到有效的回复',
            isUser: false,
            timestamp: DateTime.now(),
            agentName: _selectedAgent?.name ?? '通用助手',
            metadata: {
              'responseTime': result.responseTimeMs,
              'tokenUsage': result.totalTokens,
              'cost': result.cost,
            },
          );
          
          setState(() {
            _messages.add(aiMessage);
          });
          
          // 更新对话记录
          _updateConversation();
        } else {
          final errorMessage = ChatMessage(
            content: '运行失败: ${result.errorMessage}',
            isUser: false,
            timestamp: DateTime.now(),
            agentName: _selectedAgent!.name,
            isError: true,
            canRetry: true, // 允许重试
            attachedFiles: filesToUpload.isNotEmpty ? filesToUpload : null, // 保存文件以便重试
          );
          
          setState(() {
            _messages.add(errorMessage);
          });
        }
        
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = ChatMessage(
          content: '运行异常: $e',
          isUser: false,
          timestamp: DateTime.now(),
          agentName: _selectedAgent!.name,
          isError: true,
          canRetry: true, // 允许重试
          attachedFiles: filesToUpload.isNotEmpty ? filesToUpload : null, // 保存文件以便重试
        );
        
        setState(() {
          _messages.add(errorMessage);
        });
        
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 更新对话记录
  void _updateConversation() {
    if (_currentConversation != null && _messages.isNotEmpty) {
      // 根据第一条用户消息生成对话标题
      String title = _currentConversation!.title;
      if (title == '新对话' && _messages.isNotEmpty) {
        final firstUserMessage = _messages.firstWhere(
          (msg) => msg.isUser,
          orElse: () => _messages.first,
        );
        title = firstUserMessage.content.length > 20 
            ? '${firstUserMessage.content.substring(0, 20)}...'
            : firstUserMessage.content;
      }

      final updatedConversation = _currentConversation!.copyWith(
        title: title,
        messages: List.from(_messages),
        lastUpdated: DateTime.now(),
      );

      setState(() {
        final index = _conversations.indexWhere((c) => c.id == _currentConversation!.id);
        if (index != -1) {
          _conversations[index] = updatedConversation;
        }
        _currentConversation = updatedConversation;
      });
      _persistConversations();
    }
  }

  /// 重发消息（AI错误消息）
  Future<void> _retryMessage(ChatMessage message) async {
    if (!message.canRetry || message.attachedFiles == null) return;
    
    print('开始重发消息...');
    
    // 移除错误消息
    setState(() {
      _messages.remove(message);
      _isLoading = true;
    });
    
    try {
      // 重新发送消息
      final agentToUse = _selectedAgent ?? _createDefaultAgent();
      
      final result = await AIAgentService.runAgent(
        agentToUse,
        message.content,
        userId: 'admin',
        userName: 'Admin',
        knowledgeBaseId: _selectedKnowledgeBase?.id,
        files: message.attachedFiles!.isNotEmpty ? message.attachedFiles : null,
      );
      
      if (result.isSuccess) {
        final aiMessage = ChatMessage(
          content: result.response ?? '抱歉，我没有收到有效的回复',
          isUser: false,
          timestamp: DateTime.now(),
          agentName: agentToUse.name,
          metadata: {
            'responseTime': result.responseTimeMs,
            'tokenUsage': result.totalTokens,
            'cost': result.cost,
          },
        );
        
        setState(() {
          _messages.add(aiMessage);
        });
        
        // 更新对话记录
        _updateConversation();
      } else {
        final errorMessage = ChatMessage(
          content: '重发失败: ${result.errorMessage}',
          isUser: false,
          timestamp: DateTime.now(),
          agentName: agentToUse.name,
          isError: true,
          canRetry: true,
          attachedFiles: message.attachedFiles,
        );
        
        setState(() {
          _messages.add(errorMessage);
        });
      }
    } catch (e) {
      final errorMessage = ChatMessage(
        content: '重发异常: $e',
        isUser: false,
        timestamp: DateTime.now(),
        agentName: _selectedAgent?.name ?? '通用助手',
        isError: true,
        canRetry: true,
        attachedFiles: message.attachedFiles,
      );
      
      setState(() {
        _messages.add(errorMessage);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  /// 重发用户消息
  Future<void> _resendUserMessage(ChatMessage message) async {
    if (!message.isUser) return;
    
    print('开始重发用户消息...');
    
    // 移除当前消息
    setState(() {
      _messages.remove(message);
      _isLoading = true;
    });
    
    // 重新发送消息
    await _sendMessageWithContent(message.content, message.attachedFiles);
  }

  /// 编辑用户消息
  void _editUserMessage(ChatMessage message) {
    if (!message.isUser) return;
    
    print('开始编辑用户消息...');
    
    // 设置编辑状态
    final index = _messages.indexOf(message);
    if (index != -1) {
      setState(() {
        _messages[index] = message.copyWith(
          isEditing: true,
          originalContent: message.content,
        );
      });
      
      // 将消息内容填入输入框
      _messageController.text = message.content;
      
      // 如果有文件附件，也添加到选中文件列表
      if (message.attachedFiles != null) {
        setState(() {
          _selectedFiles.clear();
          for (final file in message.attachedFiles!) {
            _selectedFiles.add(SelectedFile(
              name: path.basename(file.path),
              path: file.path,
              size: file.lengthSync(),
              type: path.extension(file.path),
              selectedTime: DateTime.now(),
            ));
          }
        });
      }
      
      // 滚动到底部并聚焦输入框
      _scrollToBottom();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(_focusNode);
        }
      });
    }
  }

  /// 保存编辑的消息
  Future<void> _saveEditedMessage(ChatMessage message) async {
    if (!message.isUser || !message.isEditing) return;
    
    print('保存编辑的消息...');
    
    // 移除编辑状态的消息
    setState(() {
      _messages.remove(message);
    });
    
    // 从 _selectedFiles 构建文件列表
    List<File> filesToSend = [];
    if (_selectedFiles.isNotEmpty) {
      for (final selectedFile in _selectedFiles) {
        final file = File(selectedFile.path);
        if (await file.exists()) {
          filesToSend.add(file);
        }
      }
    }
    
    print('编辑消息中的文件数量: ${filesToSend.length}');
    
    // 发送编辑后的消息
    await _sendMessageWithContent(_messageController.text.trim(), filesToSend.isNotEmpty ? filesToSend : null);
  }

  /// 取消编辑
  void _cancelEdit(ChatMessage message) {
    if (!message.isUser || !message.isEditing) return;
    
    print('取消编辑...');
    
    // 恢复原始消息
    final index = _messages.indexOf(message);
    if (index != -1) {
      setState(() {
        _messages[index] = message.copyWith(
          isEditing: false,
          originalContent: null,
        );
      });
    }
    
    // 清空输入框和选中文件
    _messageController.clear();
    setState(() {
      _selectedFiles.clear();
    });
  }

  /// 保存当前编辑的消息
  Future<void> _saveCurrentEdit() async {
    final editingMessage = _messages.firstWhere(
      (msg) => msg.isUser && msg.isEditing,
      orElse: () => throw Exception('没有找到正在编辑的消息'),
    );
    
    await _saveEditedMessage(editingMessage);
  }

  /// 发送消息的通用方法
  Future<void> _sendMessageWithContent(String content, List<File>? files) async {
    // 准备文件列表
    List<File> filesToUpload = [];
    
    if (files != null && files.isNotEmpty) {
      for (final file in files) {
        final exists = await file.exists();
        if (exists) {
          filesToUpload.add(file);
        }
      }
    }
    
    // 构建包含文件信息的消息
    String fullMessage = content;
    if (filesToUpload.isNotEmpty) {
      final fileList = <String>[];
      for (final file in filesToUpload) {
        final size = await file.length();
        fileList.add('📎 ${path.basename(file.path)} (${_formatFileSize(size)})');
      }
      
      final fileListText = fileList.join('\n');
      if (fullMessage.isNotEmpty) {
        fullMessage += '\n\n附件:\n$fileListText';
      } else {
        fullMessage = '附件:\n$fileListText';
      }
    }

    // 如果使用通用助手模式且右侧选择了提供商，则自动创建临时代理
    if (_selectedAgent == null && _selectedProvider != null) {
      final created = await _ensureAgentFromSelection();
      if (!created) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先在右侧选择模型供应商与模型')),
        );
        return;
      }
    }

    // 如果没有当前对话，创建一个新的
    if (_currentConversation == null) {
      _createConversationWithAgent(_selectedAgent);
    }

    final userMessage = ChatMessage(
      content: fullMessage,
      isUser: true,
      timestamp: DateTime.now(),
      attachedFiles: filesToUpload.isNotEmpty ? filesToUpload : null,
    );
    
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    
    _messageController.clear();
    _scrollToBottom();

    try {
      // 如果没有选择代理且没有配置提供商，显示提示信息
      if (_selectedAgent == null && _selectedProvider == null) {
        final aiMessage = ChatMessage(
          content: '抱歉，我需要配置AI模型才能回答您的问题。请在右侧面板中选择一个模型提供商和模型，或者切换到专业的AI代理。',
          isUser: false,
          timestamp: DateTime.now(),
          agentName: '通用助手',
        );
        
        setState(() {
          _messages.add(aiMessage);
          _isLoading = false;
        });
        return;
      }

      // 根据右侧面板选择，必要时覆盖当前代理的提供商/模型
      AIAgent? agentToUse = _selectedAgent;
      if (_selectedProvider != null) {
        // 解析模型名（优先选中值，其次自定义，其次推荐）
        String? modelName = _selectedModel?.trim();
        final customModel = _customModelInput.trim();
        if (modelName == null || modelName.isEmpty) {
          modelName = customModel.isEmpty ? null : customModel;
        }
        final suggestions = _getSuggestedModels(_selectedProvider!.providerType);
        final looksMismatched = () {
          if (suggestions.isEmpty || modelName == null || modelName!.isEmpty) return false;
          switch (_selectedProvider!.providerType) {
            case ProviderType.alibaba:
              return !modelName!.toLowerCase().startsWith('qwen');
            case ProviderType.openai:
              return !modelName!.toLowerCase().startsWith('gpt');
            default:
              return false;
          }
        }();
        if ((modelName == null || modelName.isEmpty) || looksMismatched) {
          modelName = suggestions.isNotEmpty ? suggestions.first : modelName;
        }

        agentToUse = (_selectedAgent ?? _createDefaultAgent()).copyWith(
          providerName: _selectedProvider!.name,
          modelName: modelName,
        );
      }

      // 确保有可用的代理
      agentToUse ??= _createDefaultAgent();

      // 发送前记录本次使用的具体代理信息
      LogService.apiCall(
        '发送对话请求(预备)',
        details: 'agent: ${agentToUse!.name}',
        metadata: {
          'provider_name': agentToUse!.providerName,
          'model_name': agentToUse!.modelName,
          'model_config': agentToUse!.modelConfig,
        },
      );
      
      final result = await AIAgentService.runAgent(
        agentToUse!,
        fullMessage,
        userId: 'admin',
        userName: 'Admin',
        knowledgeBaseId: _selectedKnowledgeBase?.id,
        files: filesToUpload.isNotEmpty ? filesToUpload : null,
      );
      
      if (mounted) {
        if (result.isSuccess) {
          final aiMessage = ChatMessage(
            content: result.response ?? '抱歉，我没有收到有效的回复',
            isUser: false,
            timestamp: DateTime.now(),
            agentName: _selectedAgent?.name ?? '通用助手',
            metadata: {
              'responseTime': result.responseTimeMs,
              'tokenUsage': result.totalTokens,
              'cost': result.cost,
            },
          );
          
          setState(() {
            _messages.add(aiMessage);
          });
          
          // 更新对话记录
          _updateConversation();
        } else {
          final errorMessage = ChatMessage(
            content: '运行失败: ${result.errorMessage}',
            isUser: false,
            timestamp: DateTime.now(),
            agentName: _selectedAgent!.name,
            isError: true,
            canRetry: true,
            attachedFiles: filesToUpload.isNotEmpty ? filesToUpload : null,
          );
          
          setState(() {
            _messages.add(errorMessage);
          });
        }
        
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = ChatMessage(
          content: '运行异常: $e',
          isUser: false,
          timestamp: DateTime.now(),
          agentName: _selectedAgent?.name ?? '通用助手',
          isError: true,
          canRetry: true,
          attachedFiles: filesToUpload.isNotEmpty ? filesToUpload : null,
        );
        
        setState(() {
          _messages.add(errorMessage);
        });
        
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 滚动到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 清空对话
  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空对话'),
        content: const Text('确定要清空所有对话记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _messages.clear();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      body: Stack(
        children: [
          Row(
            children: [
              _buildLeftPanel(themeProvider),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: _buildCenterPanel(themeProvider),
                  ),
                ),
              ),
            ],
          ),

          // 覆盖蒙层（点击关闭）
          if (_showRightPanel)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() {
                  _showRightPanel = false;
                  _panelAnimController.reverse();
                }),
                child: Container(color: Colors.black.withOpacity(0.35)),
              ),
            ),

          // 右侧滑入面板
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 320,
              height: double.infinity,
              child: SlideTransition(
                position: _panelSlide,
                child: _buildRightPanel(themeProvider),
              ),
            ),
          ),

          // 悬浮设置按钮
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: themeProvider.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: themeProvider.borderColor,
                  width: 1,
                ),
              ),
              child: IconButton(
                tooltip: _showRightPanel ? '关闭 AI 配置' : '打开 AI 配置',
                onPressed: () {
                  setState(() {
                    _showRightPanel = !_showRightPanel;
                    if (_showRightPanel) {
                      _panelAnimController.forward();
                    } else {
                      _panelAnimController.reverse();
                    }
                  });
                },
                icon: Icon(
                  Icons.settings,
                  color: _showRightPanel ? themeProvider.primaryColor : themeProvider.textSecondaryColor,
                  size: 20,
                ),
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
              ),
            ),
          ),


        ],
      ),
    );
  }

  /// 构建左栏：对话列表与管理
  Widget _buildLeftPanel(ThemeProvider themeProvider) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: themeProvider.surfaceColor,
        border: Border(
          right: BorderSide(
            color: themeProvider.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 头部
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode 
                  ? const Color(0xFF2A2A2A) 
                  : const Color(0xFFF8F9FA),
              border: Border(
                bottom: BorderSide(
                  color: themeProvider.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // 返回首页按钮
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_back,
                    color: themeProvider.textSecondaryColor,
                    size: 20,
                  ),
                  tooltip: '返回首页',
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chat_bubble_outline,
                  color: themeProvider.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'AI 对话',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
              ],
            ),
          ),
          
          // 新建对话按钮
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _createNewConversation,
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  '新建对话',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          
          // 搜索框
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索对话...',
                hintStyle: TextStyle(color: themeProvider.textSecondaryColor),
                prefixIcon: Icon(Icons.search, color: themeProvider.textSecondaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: themeProvider.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: themeProvider.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: themeProvider.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: themeProvider.isDarkMode 
                    ? const Color(0xFF2A2A2A) 
                    : const Color(0xFFF8F9FA),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 对话历史列表
          Expanded(
            child: _buildConversationList(themeProvider),
          ),
          
          // 底部操作
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: themeProvider.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearAllConversations,
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('删除所有历史'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[100],
                      foregroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建中栏：核心对话界面
  Widget _buildCenterPanel(ThemeProvider themeProvider) {
    return Column(
      children: [

        
        // 消息列表
        Expanded(
          child: _buildMessageList(themeProvider),
        ),
        
        // 输入区域
        _buildInputArea(themeProvider),
      ],
    );
  }

  /// 构建右栏：配置与上下文中心
  Widget _buildRightPanel(ThemeProvider themeProvider) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: themeProvider.surfaceColor,
        border: Border(
          left: BorderSide(
            color: themeProvider.borderColor,
            width: 1,
          ),
        ),
      ),
      child: _buildConfigurationTabs(themeProvider),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(ThemeProvider themeProvider) {
    if (_selectedAgent == null) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: themeProvider.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.psychology,
                  size: 40,
                  color: themeProvider.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '您正在使用通用助手 🤖',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '我可以帮您回答问题、处理任务和提供建议。您也可以在右上角切换到专业的AI代理来获得更专业的体验。',
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.textSecondaryColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeProvider.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: themeProvider.primaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: themeProvider.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '试试问我："帮我写一份会议总结"或"解释一下人工智能的原理"',
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: themeProvider.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getAgentIcon(_selectedAgent!.type),
              color: themeProvider.primaryColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '开始与 ${_selectedAgent!.name} 对话',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: themeProvider.textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedAgent!.description,
            style: TextStyle(
              fontSize: 16,
              color: themeProvider.textSecondaryColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            '在下方输入框中输入您的问题',
            style: TextStyle(
              fontSize: 14,
              color: themeProvider.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建消息列表
  Widget _buildMessageList(ThemeProvider themeProvider) {
    if (_messages.isEmpty) {
      return _buildEmptyState(themeProvider);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildLoadingMessage(themeProvider);
        }
        
        final message = _messages[index];
        return _buildMessageItem(message, themeProvider);
      },
    );
  }

  /// 构建加载消息
  Widget _buildLoadingMessage(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: themeProvider.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _selectedAgent != null ? _getAgentIcon(_selectedAgent!.type) : Icons.psychology,
              color: themeProvider.primaryColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode 
                    ? const Color(0xFF2A2A2A) 
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        themeProvider.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '正在思考中...',
                    style: TextStyle(
                      color: themeProvider.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建消息项
  Widget _buildMessageItem(ChatMessage message, ThemeProvider themeProvider) {
    if (message.isUser) {
      // 用户消息：右对齐
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Container(), // 占位空间
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 编辑和重发按钮
                      if (!message.isEditing) ...[
                        IconButton(
                          onPressed: () => _editUserMessage(message),
                          icon: Icon(
                            Icons.edit,
                            size: 16,
                            color: themeProvider.textSecondaryColor,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                        IconButton(
                          onPressed: () => _resendUserMessage(message),
                          icon: Icon(
                            Icons.refresh,
                            size: 16,
                            color: themeProvider.textSecondaryColor,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                      ] else ...[
                        // 编辑状态下的保存和取消按钮
                        IconButton(
                          onPressed: () => _saveEditedMessage(message),
                          icon: Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.green,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                        IconButton(
                          onPressed: () => _cancelEdit(message),
                          icon: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.red,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: themeProvider.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '您',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode 
                          ? const Color(0xFF1E3A8A) 
                          : const Color(0xFF3B82F6),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildMessageContent(message.content, themeProvider, message.isError, isUser: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      );
    } else {
      // AI消息：左对齐
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    themeProvider.primaryColor,
                    themeProvider.primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: themeProvider.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _getAgentIcon(_selectedAgent!.type),
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        message.agentName ?? 'AI',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: themeProvider.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode 
                          ? const Color(0xFF2A2A2A) 
                          : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(
                        color: themeProvider.isDarkMode 
                            ? const Color(0xFF404040)
                            : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildMessageContent(message.content, themeProvider, message.isError, isUser: false),
                  ),
                  
                  // 错误消息显示重发按钮
                  if (message.isError && message.canRetry)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _retryMessage(message),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('重试'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeProvider.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // 成功消息显示元数据
                  if (!message.isError && message.metadata != null)
                    Container(), // 技术信息已移动到右侧面板，这里不再显示
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  /// 构建消息内容（支持链接）
  Widget _buildMessageContent(String content, ThemeProvider themeProvider, bool isError, {bool isUser = false}) {
    // 检测Markdown格式的链接 [text](url)
    final linkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    final matches = linkRegex.allMatches(content);
    
    if (matches.isEmpty) {
      // 没有链接，返回普通文本
      return Text(
        content,
        style: TextStyle(
          fontSize: 16,
          color: isError 
              ? Colors.red 
              : (isUser ? Colors.white : themeProvider.textColor),
          height: 1.5,
        ),
      );
    }
    
    // 有链接，构建富文本
    List<TextSpan> spans = [];
    int lastEnd = 0;
    
    for (final match in matches) {
      // 添加链接前的文本
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: TextStyle(
            fontSize: 16,
            color: isError 
                ? Colors.red 
                : (isUser ? Colors.white : themeProvider.textColor),
            height: 1.5,
          ),
        ));
      }
      
      // 添加链接
      final linkText = match.group(1)!;
      final linkUrl = match.group(2)!;
      spans.add(TextSpan(
        text: linkText,
        style: TextStyle(
          fontSize: 16,
          color: isUser ? Colors.white : Colors.blue,
          decoration: TextDecoration.underline,
          height: 1.5,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _openLink(linkUrl),
      ));
      
      lastEnd = match.end;
    }
    
    // 添加最后一段文本
    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: TextStyle(
          fontSize: 16,
          color: isError 
              ? Colors.red 
              : (isUser ? Colors.white : themeProvider.textColor),
          height: 1.5,
        ),
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  /// 打开链接
  void _openLink(String url) async {
    try {
      final uri = Uri.parse(url);
      
      // 直接尝试打开链接，不先检查canLaunchUrl（避免macOS上的channel错误）
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        // 如果launchUrl返回false，尝试其他模式
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (e) {
      // 如果url_launcher失败，尝试使用系统命令（macOS）
      if (e.toString().contains('channel-error') || e.toString().contains('macos')) {
        try {
          await _openLinkWithSystemCommand(url);
        } catch (systemError) {
          _showLinkError('无法打开链接: $url\n系统错误: $systemError');
        }
      } else {
        _showLinkError('打开链接失败: $e');
      }
    }
  }

  /// 使用系统命令打开链接（macOS备用方案）
  Future<void> _openLinkWithSystemCommand(String url) async {
    try {
      // 在macOS上使用open命令
      final result = await Process.run('open', [url]);
      if (result.exitCode != 0) {
        throw Exception('系统命令执行失败: ${result.stderr}');
      }
    } catch (e) {
      throw Exception('系统命令打开链接失败: $e');
    }
  }

  /// 显示链接错误信息
  void _showLinkError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '复制链接',
          textColor: Colors.white,
          onPressed: () {
            // 复制链接到剪贴板
            Clipboard.setData(ClipboardData(text: _extractUrlFromMessage(message)));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('链接已复制到剪贴板'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 从错误消息中提取URL
  String _extractUrlFromMessage(String message) {
    final urlRegex = RegExp(r'https?://[^\s]+');
    final match = urlRegex.firstMatch(message);
    return match?.group(0) ?? '';
  }

  /// 构建元数据项
  Widget _buildMetadataItem(IconData icon, String text, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: themeProvider.textSecondaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: themeProvider.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建输入区域
  Widget _buildInputArea(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeProvider.surfaceColor,
        border: Border(
          top: BorderSide(
            color: themeProvider.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
                children: [
          // 文件展示区域
          if (_selectedFiles.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _selectedFiles.map((file) => _buildFileCard(file, themeProvider)).toList(),
                ),
              ),
            ),
          ],
          
          // 文本输入区域
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: themeProvider.borderColor,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: themeProvider.isDarkMode 
                  ? const Color(0xFF2A2A2A) 
                  : Colors.white,
            ),
            child: DragTarget<List<File>>(
              onWillAcceptWithDetails: (details) {
                return true; // 接受所有文件拖拽
              },
              onAcceptWithDetails: (details) {
                _handleDroppedFiles(details.data);
              },
              builder: (context, candidateData, rejectedData) {
                final isDragOver = candidateData.isNotEmpty;
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDragOver 
                          ? themeProvider.primaryColor 
                          : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isDragOver 
                        ? themeProvider.primaryColor.withOpacity(0.1)
                        : Colors.transparent,
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: '输入您的问题... (支持拖拽文件或 Ctrl+V 粘贴)',
                      hintStyle: TextStyle(
                        color: themeProvider.textSecondaryColor,
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: themeProvider.textColor,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => _sendMessage(),
                    onChanged: (text) {
                      // 监听粘贴事件
                      _handlePasteEvent();
                    },
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 功能工具栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode 
                  ? const Color(0xFF1A1A1A) 
                  : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: themeProvider.borderColor.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // 左侧功能按钮
                Row(
                  children: [
                    _buildToolbarButton(
                      icon: '📎',
                      label: '附件',
                              onTap: () => _pickFile(),
                      themeProvider: themeProvider,
                    ),
                    const SizedBox(width: 8),
                    _buildToolbarButton(
                      icon: '</>',
                      label: '代码',
                      onTap: () => _insertCodeBlock(),
                      themeProvider: themeProvider,
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // 右侧发送按钮
                _buildSendButton(themeProvider),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 提示信息
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: themeProvider.textSecondaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                '按 Enter 发送消息，Shift + Enter 换行，支持拖拽文件',
                style: TextStyle(
                  fontSize: 12,
                  color: themeProvider.textSecondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 选择文件
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false, // 不读取文件内容，避免大文件问题
        lockParentWindow: false, // 不锁定父窗口，避免macOS权限问题
        dialogTitle: '选择文件', // 添加对话框标题
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileName = file.name;
        final fileSize = file.size;
        final filePath = file.path ?? '';
        
        // 添加文件到选中列表
        _addFile(fileName, filePath, fileSize);
        
        // 显示文件信息
        final isImage = _isImageFile(fileName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已选择${isImage ? '图片' : '文件'}: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 处理macOS上的channel错误
      if (e.toString().contains('channel-error') || e.toString().contains('macos')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('文件选择功能暂时不可用，请尝试直接拖拽文件到输入框'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('文件选择失败: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }



  /// 插入代码块
  void _insertCodeBlock() {
    final currentText = _messageController.text;
    final selection = _messageController.selection;
    
    String codeBlock = '\n```\n// 在这里输入您的代码\n```\n';
    
    if (selection.isValid) {
      // 如果有选中文本，用代码块包围
      final selectedText = currentText.substring(selection.start, selection.end);
      codeBlock = '\n```\n$selectedText\n```\n';
    }
    
    final newText = currentText.replaceRange(
      selection.start,
      selection.end,
      codeBlock,
    );
    
    _messageController.text = newText;
    
    // 设置光标位置到代码块内部
    final newCursorPosition = selection.start + codeBlock.length - 4; // 减去最后的```\n
    _messageController.selection = TextSelection.collapsed(offset: newCursorPosition);
    
    // 聚焦到输入框
    FocusScope.of(context).requestFocus(FocusNode());
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

    /// 处理拖拽的文件
  void _handleDroppedFiles(List<File> files) {
    if (files.isNotEmpty) {
      final file = files.first;
      final fileName = file.path.split('/').last;
      final fileSize = file.lengthSync();
      final filePath = file.path;
      
      // 添加文件到选中列表
      _addFile(fileName, filePath, fileSize);
      
      // 显示文件信息
      final isImage = _isImageFile(fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已拖拽${isImage ? '图片' : '文件'}: $fileName'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 检查是否是图片文件
  bool _isImageFile(String fileName) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg'];
    final lowerFileName = fileName.toLowerCase();
    return imageExtensions.any((ext) => lowerFileName.endsWith(ext));
  }

  /// 处理粘贴事件
  void _handlePasteEvent() {
    // 这里可以添加粘贴文件检测逻辑
    // 暂时只是占位
  }



  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 构建文件卡片
  Widget _buildFileCard(SelectedFile file, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode 
            ? const Color(0xFF2A2A2A) 
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: themeProvider.borderColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 文件图标
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getFileTypeColor(file),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getFileTypeIcon(file),
              color: Colors.white,
              size: 16,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // 文件信息
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 文件名
              SizedBox(
                width: 120,
                child: Text(
                  file.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const SizedBox(height: 2),
              
              // 文件大小和类型
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatFileSize(file.size),
                    style: TextStyle(
                      fontSize: 10,
                      color: themeProvider.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: _getFileTypeColor(file).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      file.extension.toUpperCase(),
                      style: TextStyle(
                        fontSize: 8,
                        color: _getFileTypeColor(file),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(width: 4),
          
          // 删除按钮
          GestureDetector(
            onTap: () => _removeFile(file),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: themeProvider.textSecondaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.close,
                size: 10,
                color: themeProvider.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取文件类型图标
  IconData _getFileTypeIcon(SelectedFile file) {
    if (file.isImage) return Icons.image;
    if (file.isPdf) return Icons.picture_as_pdf;
    if (file.isDocument) return Icons.description;
    return Icons.insert_drive_file;
  }

  /// 获取文件类型颜色
  Color _getFileTypeColor(SelectedFile file) {
    if (file.isImage) return Colors.blue;
    if (file.isPdf) return Colors.red;
    if (file.isDocument) return Colors.green;
    return Colors.grey;
  }

  /// 移除文件
  void _removeFile(SelectedFile file) {
    setState(() {
      _selectedFiles.remove(file);
    });
  }

  /// 添加文件
  void _addFile(String name, String path, int size) {
    final file = SelectedFile(
      name: name,
      path: path,
      size: size,
      type: 'file',
      selectedTime: DateTime.now(),
    );
    
    setState(() {
      _selectedFiles.add(file);
    });
  }

  /// 构建工具栏按钮
  Widget _buildToolbarButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: themeProvider.textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建发送按钮
  Widget _buildSendButton(ThemeProvider themeProvider) {
    final hasText = _messageController.text.trim().isNotEmpty;
    final isEditing = _messages.any((msg) => msg.isUser && msg.isEditing);
    
    return Container(
      decoration: BoxDecoration(
        gradient: hasText 
            ? LinearGradient(
                colors: [
                  themeProvider.primaryColor,
                  themeProvider.primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: hasText ? null : themeProvider.borderColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: hasText ? [
          BoxShadow(
            color: themeProvider.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasText ? (isEditing ? _saveCurrentEdit : _sendMessage) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isEditing ? Icons.check : Icons.send_rounded,
                  color: hasText ? Colors.white : themeProvider.textSecondaryColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? '保存' : '发送',
                  style: TextStyle(
                    color: hasText ? Colors.white : themeProvider.textSecondaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
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

  /// 创建新对话
  void _createNewConversation() {
    _showAgentSelectionDialog();
  }

  /// 显示代理选择对话框
  void _showAgentSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => _AgentSelectionDialog(
        availableAgents: _availableAgents,
        onAgentSelected: (agent) {
          _createConversationWithAgent(agent);
        },
        onGeneralAssistant: () {
          _createConversationWithAgent(null);
        },
      ),
    );
  }

  /// 使用指定代理创建对话
  void _createConversationWithAgent(AIAgent? agent) async {
    // 创建临时对话，等待用户发送第一条消息时生成标题
    final conversationId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempTitle = agent?.name ?? '新对话';
    
    // 在数据库中创建对话
    await DatabaseService.createConversation(
      title: tempTitle,
      agentId: agent?.id,
      metadata: {
        'is_temp': true, // 标记为临时对话，等待第一条消息后更新标题
        'agent_name': agent?.name,
      },
    );

    final conversation = Conversation(
      id: conversationId,
      title: tempTitle,
      agent: agent,
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
      messages: [],
    );

    setState(() {
      _conversations.insert(0, conversation);
      _currentConversation = conversation;
      _selectedAgent = agent;
      _messages.clear();
    });
    
    // 加载对话列表
    _loadConversations();
  }

  /// 创建默认通用助手代理
  AIAgent _createDefaultAgent() {
    return AIAgent(
      name: '通用助手',
      description: '我是您的智能助手，可以帮助您解答问题和完成各种任务',
      type: AgentType.custom,
      systemPrompt: '你是一个友好、专业的AI助手。请以简洁明了的方式回答用户的问题，提供有用的信息和建议。',
      providerName: _selectedProvider?.name ?? 'openai',
      modelName: _selectedModel ?? 'gpt-3.5-turbo',
    );
  }

  /// 显示代理切换对话框
  void _showAgentSwitchDialog() {
    showDialog(
      context: context,
      builder: (context) => _AgentSwitchDialog(
        availableAgents: _availableAgents,
        currentAgent: _selectedAgent,
        onAgentSelected: (agent) {
          _switchAgent(agent);
        },
        onGeneralAssistant: () {
          _switchAgent(null);
        },
      ),
    );
  }

  /// 切换代理
  void _switchAgent(AIAgent? newAgent) {
    if (_messages.isNotEmpty) {
      // 如果有对话历史，询问是否继续上下文
      _showContextContinueDialog(newAgent);
    } else {
      // 没有对话历史，直接切换
      setState(() {
        _selectedAgent = newAgent;
        if (_currentConversation != null) {
          _currentConversation = _currentConversation!.copyWith(agent: newAgent);
        }
      });
    }
  }

  /// 显示上下文继续确认对话框
  void _showContextContinueDialog(AIAgent? newAgent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('切换代理'),
        content: Text(
          '你已切换为【${newAgent?.name ?? '通用助手'}】，是否要继续当前上下文？\n\n'
          '选择"继续"：保留当前对话历史\n'
          '选择"重新开始"：清空对话历史',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 清空对话历史，重新开始
              setState(() {
                _selectedAgent = newAgent;
                _messages.clear();
                if (_currentConversation != null) {
                  _currentConversation = _currentConversation!.copyWith(
                    agent: newAgent,
                    messages: [],
                  );
                }
              });
            },
            child: const Text('重新开始'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 继续当前上下文
              setState(() {
                _selectedAgent = newAgent;
                if (_currentConversation != null) {
                  _currentConversation = _currentConversation!.copyWith(agent: newAgent);
                }
              });
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  /// 构建对话列表
  Widget _buildConversationList(ThemeProvider themeProvider) {
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: themeProvider.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无对话记录',
              style: TextStyle(
                fontSize: 16,
                color: themeProvider.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击"新建对话"开始',
              style: TextStyle(
                fontSize: 14,
                color: themeProvider.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final isSelected = _currentConversation?.id == conversation.id;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _selectConversation(conversation),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? themeProvider.primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected 
                        ? themeProvider.primaryColor
                        : themeProvider.borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (conversation.isPinned)
                          Icon(
                            Icons.push_pin,
                            size: 16,
                            color: themeProvider.primaryColor,
                          ),
                        Expanded(
                          child: Text(
                            conversation.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            size: 20,
                            color: themeProvider.textSecondaryColor,
                          ),
                          onSelected: (value) => _handleConversationAction(value, conversation),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'pin',
                              child: Row(
                                children: [
                                  Icon(
                                    conversation.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(conversation.isPinned ? '取消置顶' : '置顶'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 18),
                                  const SizedBox(width: 8),
                                  const Text('删除'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: themeProvider.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            conversation.agent != null ? _getAgentIcon(conversation.agent!.type) : Icons.psychology,
                            color: themeProvider.primaryColor,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            conversation.agent?.name ?? '通用助手',
                            style: TextStyle(
                              fontSize: 14,
                              color: themeProvider.textSecondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(conversation.lastUpdated),
                      style: TextStyle(
                        fontSize: 12,
                        color: themeProvider.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 选择对话
  void _selectConversation(Conversation conversation) {
    setState(() {
      _currentConversation = conversation;
      _selectedAgent = conversation.agent;
      _messages.clear();
      _messages.addAll(conversation.messages);
    });
  }

  /// 处理对话操作
  void _handleConversationAction(String action, Conversation conversation) {
    switch (action) {
      case 'pin':
        setState(() {
          final index = _conversations.indexWhere((c) => c.id == conversation.id);
          if (index != -1) {
            _conversations[index] = conversation.copyWith(isPinned: !conversation.isPinned);
            // 重新排序：置顶的在前
            _conversations.sort((a, b) {
              if (a.isPinned && !b.isPinned) return -1;
              if (!a.isPinned && b.isPinned) return 1;
              return b.lastUpdated.compareTo(a.lastUpdated);
            });
          }
        });
        break;
      case 'delete':
        _deleteConversation(conversation);
        break;
    }
  }

  /// 删除对话
  void _deleteConversation(Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定要删除对话"${conversation.title}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _conversations.removeWhere((c) => c.id == conversation.id);
                if (_currentConversation?.id == conversation.id) {
                  _currentConversation = _conversations.isNotEmpty ? _conversations.first : null;
                  _selectedAgent = _currentConversation?.agent;
                  _messages.clear();
                  if (_currentConversation != null) {
                    _messages.addAll(_currentConversation!.messages);
                  }
                }
              });
              _persistConversations();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 删除所有对话
  void _clearAllConversations() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除所有历史'),
        content: const Text('确定要删除所有对话记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _conversations.clear();
                _currentConversation = null;
                _selectedAgent = null;
                _messages.clear();
              });
              _persistConversations();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 构建对话头部
  Widget _buildConversationHeader(ThemeProvider themeProvider) {
    if (_selectedAgent == null) {
      return Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: themeProvider.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.psychology,
              color: themeProvider.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

        ],
      );
    }

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: themeProvider.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getAgentIcon(_selectedAgent!.type),
            color: themeProvider.primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedAgent!.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
              ),
              Text(
                _selectedAgent!.description,
                style: TextStyle(
                  fontSize: 14,
                  color: themeProvider.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建技术信息卡片
  Widget _buildTechnicalInfoCard(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode 
            ? const Color(0xFF1A1A1A) 
            : const Color(0xFFF0F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: themeProvider.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: themeProvider.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                '当前配置',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 供应商信息
          if (_selectedProvider != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: themeProvider.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.apartment,
                    size: 16,
                    color: themeProvider.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedProvider!.providerType.displayName,
                      style: TextStyle(
                        color: themeProvider.primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // 模型信息
          if (_selectedModel != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: themeProvider.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: themeProvider.borderColor,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.model_training,
                    size: 16,
                    color: themeProvider.textSecondaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedModel!,
                      style: TextStyle(
                        color: themeProvider.textSecondaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // 如果没有选择任何配置，显示提示
          if (_selectedProvider == null && _selectedModel == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: themeProvider.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: themeProvider.borderColor,
                  width: 1,
                ),
              ),
              child: Text(
                '请在下方配置中选择模型提供商和模型',
                style: TextStyle(
                  color: themeProvider.textSecondaryColor,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建配置标签页
  Widget _buildConfigurationTabs(ThemeProvider themeProvider) {
    return Column(
      children: [
        // 技术信息显示区域
        _buildTechnicalInfoCard(themeProvider),
        
        // 标签页头部
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode 
                ? const Color(0xFF2A2A2A) 
                : const Color(0xFFF8F9FA),
            border: Border(
              bottom: BorderSide(
                color: themeProvider.borderColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.settings, color: themeProvider.primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI 配置与调试中心',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
              ),
              // 顶部收起按钮移除，保持面板头部更简洁
            ],
          ),
        ),
        
        // 标签页内容
        Expanded(
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                // 标签页导航
                Container(
                  color: themeProvider.surfaceColor,
                  child: TabBar(
                                         tabs: const [
                       Tab(text: '配置'),
                       Tab(text: 'AI代理'),
                       Tab(text: '知识库'),
                       Tab(text: '插件'),
                     ],
                    labelColor: themeProvider.primaryColor,
                    unselectedLabelColor: themeProvider.textSecondaryColor,
                    indicatorColor: themeProvider.primaryColor,
                  ),
                ),
                
                // 标签页内容
                Expanded(
                  child: TabBarView(
                                         children: [
                       _buildConfigurationTab(themeProvider),
                       _buildAIAgentsTab(themeProvider),
                       _buildKnowledgeBaseTab(themeProvider),
                       _buildPluginsTab(themeProvider),
                     ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建配置标签页
  Widget _buildConfigurationTab(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '模型选择',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: themeProvider.textColor,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_loadingProviders)
            const Center(child: CircularProgressIndicator())
          else if (_modelProviders.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: themeProvider.borderColor),
                borderRadius: BorderRadius.circular(12),
                color: themeProvider.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('尚未配置任何模型供应商', style: TextStyle(color: themeProvider.textColor)),
                  const SizedBox(height: 8),
                  Text('请在“模型供应商”页面添加后再来这里选择', style: TextStyle(color: themeProvider.textSecondaryColor)),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 供应商选择（弹出框）
                Text('选择供应商', style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _showProviderPickerDialog,
                  icon: const Icon(Icons.apartment),
                  label: Text(_selectedProvider != null
                      ? '${_selectedProvider!.providerType.displayName} · ${_selectedProvider!.name}'
                      : '请选择供应商'),
                ),

                const SizedBox(height: 16),

                // 模型选择（弹出框）
                if (_selectedProvider != null) ...[
                  Text('选择模型', style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _showModelPickerDialog,
                    icon: const Icon(Icons.model_training),
                    label: Text(_selectedModel == null
                        ? '请选择模型'
                        : (_selectedModel == '__custom__' && _customModelInput.isNotEmpty)
                            ? _customModelInput
                            : _selectedModel!),
                  ),
                ],
              ],
            ),
          
          const SizedBox(height: 24),
          
          Text(
            '模型参数',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: themeProvider.textColor,
            ),
          ),
          const SizedBox(height: 16),
          
          // Temperature 滑块
          _buildParameterSlider(
            'Temperature (随机性)',
            0.0,
            2.0,
            0.7,
            '控制输出的随机性，值越高越有创意',
            themeProvider,
          ),
          
          const SizedBox(height: 16),
          
          // Max Tokens 滑块
          _buildParameterSlider(
            'Max Tokens (最大输出长度)',
            100,
            4000,
            1000,
            '控制AI回复的最大长度',
            themeProvider,
          ),
        ],
      ),
    );
  }

  /// 构建模型卡片
  Widget _buildModelCard(String name, String provider, String description, 
      List<String> features, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: themeProvider.borderColor),
        borderRadius: BorderRadius.circular(12),
        color: themeProvider.isDarkMode 
            ? const Color(0xFF2A2A2A) 
            : const Color(0xFFF8F9FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.textColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: themeProvider.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  provider,
                  style: TextStyle(
                    fontSize: 12,
                    color: themeProvider.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: themeProvider.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: features.map((feature) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode 
                    ? Colors.grey[700] 
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                feature,
                style: TextStyle(
                  fontSize: 12,
                  color: themeProvider.textSecondaryColor,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建参数滑块
  Widget _buildParameterSlider(String label, double min, double max, double value, 
      String description, ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: themeProvider.textColor,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.help_outline,
                size: 16,
                color: themeProvider.textSecondaryColor,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(description)),
                );
              },
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) * 10).round(),
          onChanged: (newValue) {
            // TODO: 实现参数更新逻辑
          },
          activeColor: themeProvider.primaryColor,
        ),
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 12,
            color: themeProvider.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  /// 构建AI代理标签页
  Widget _buildAIAgentsTab(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部说明
          Row(
            children: [
              Icon(
                Icons.smart_toy,
                color: themeProvider.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'AI代理管理',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '管理您已配置的AI代理，查看状态和配置信息',
            style: TextStyle(
              fontSize: 14,
              color: themeProvider.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 24),
          
          // 搜索框
          TextField(
            decoration: InputDecoration(
              hintText: '搜索AI代理...',
              hintStyle: TextStyle(color: themeProvider.textSecondaryColor),
              prefixIcon: Icon(Icons.search, color: themeProvider.textSecondaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: themeProvider.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: themeProvider.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: themeProvider.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: themeProvider.isDarkMode 
                  ? const Color(0xFF2A2A2A) 
                  : const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // AI代理列表
          if (_availableAgents.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 64,
                    color: themeProvider.textSecondaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无AI代理',
                    style: TextStyle(
                      fontSize: 16,
                      color: themeProvider.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请先在AI代理管理页面创建代理',
                    style: TextStyle(
                      fontSize: 14,
                      color: themeProvider.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._availableAgents.map((agent) => _buildAgentCard(agent, themeProvider)),
          
          const SizedBox(height: 20),
          
          // 快速操作按钮
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // TODO: 导航到AI代理管理页面
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('即将跳转到AI代理管理页面')),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('创建新代理'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // TODO: 导航到模型供应商管理页面
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('即将跳转到模型供应商管理页面')),
                    );
                  },
                  icon: const Icon(Icons.api, size: 18),
                  label: const Text('管理供应商'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建知识库标签页
  Widget _buildKnowledgeBaseTab(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '知识库选择',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: themeProvider.textColor,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_availableKnowledgeBases.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode 
                    ? const Color(0xFF2A2A2A) 
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: themeProvider.borderColor),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.library_books,
                    size: 48,
                    color: themeProvider.textSecondaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '暂无可用知识库',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: themeProvider.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请先在知识库页面创建知识库',
                    style: TextStyle(
                      fontSize: 14,
                      color: themeProvider.textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              children: _availableKnowledgeBases.map((kb) {
                final isSelected = _selectedKnowledgeBase?.id == kb.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedKnowledgeBase = isSelected ? null : kb;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? themeProvider.primaryColor.withValues(alpha: 0.1)
                              : (themeProvider.isDarkMode 
                                  ? const Color(0xFF2A2A2A) 
                                  : const Color(0xFFF8F9FA)),
                          border: Border.all(
                            color: isSelected 
                                ? themeProvider.primaryColor
                                : themeProvider.borderColor,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    kb.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: themeProvider.textColor,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: themeProvider.primaryColor,
                                    size: 20,
                                  ),
                              ],
                            ),
                            if (kb.description != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                kb.description!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: themeProvider.textSecondaryColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getEngineColor(kb.engineConfig.engineType).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    kb.engineConfig.engineType.displayName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getEngineColor(kb.engineConfig.engineType),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                FutureBuilder<KnowledgeBaseStats>(
                                  future: RAGService.getKnowledgeBaseStats(kb.id!),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final stats = snapshot.data!;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: stats.isFullyProcessed 
                                              ? Colors.green.withValues(alpha: 0.1)
                                              : Colors.orange.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${stats.totalDocuments} 文档',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: stats.isFullyProcessed ? Colors.green : Colors.orange,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          
          if (_selectedKnowledgeBase != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeProvider.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: themeProvider.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: themeProvider.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '已选择知识库',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI 将基于 "${_selectedKnowledgeBase!.name}" 中的知识来回答您的问题',
                    style: TextStyle(
                      fontSize: 13,
                      color: themeProvider.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建插件标签页
  Widget _buildPluginsTab(ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.extension,
            size: 64,
            color: themeProvider.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            '插件功能',
            style: TextStyle(
              fontSize: 18,
              color: themeProvider.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '即将推出',
            style: TextStyle(
              fontSize: 14,
              color: themeProvider.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建AI代理卡片
  Widget _buildAgentCard(AIAgent agent, ThemeProvider themeProvider) {
    final isSelected = _selectedAgent?.id == agent.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              // 如果点击的是已选中的代理，则取消选中
              if (_selectedAgent?.id == agent.id) {
                _selectedAgent = null;
              } else {
                _selectedAgent = agent;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected 
                  ? themeProvider.primaryColor.withOpacity(0.1)
                  : (themeProvider.isDarkMode 
                      ? const Color(0xFF2A2A2A) 
                      : const Color(0xFFF8F9FA)),
              border: Border.all(
                color: isSelected 
                    ? themeProvider.primaryColor
                    : themeProvider.borderColor,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agent.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            agent.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: themeProvider.textSecondaryColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: themeProvider.primaryColor,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // 代理状态和统计信息
                Row(
                  children: [
                    // 状态指示器
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(agent.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getStatusText(agent.status),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(agent.status),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // 运行次数
                    Row(
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          size: 16,
                          color: themeProvider.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${agent.totalRuns ?? 0} 次',
                          style: TextStyle(
                            fontSize: 12,
                            color: themeProvider.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // 成功率
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: themeProvider.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_calculateSuccessRate(agent)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: themeProvider.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // 操作按钮
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: 编辑代理
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('编辑代理: ${agent.name}')),
                          );
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('编辑'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: 查看详情
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('查看详情: ${agent.name}')),
                          );
                        },
                        icon: const Icon(Icons.info_outline, size: 16),
                        label: const Text('详情'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 获取状态颜色
  Color _getStatusColor(AgentStatus status) {
    switch (status) {
      case AgentStatus.active:
        return Colors.green;
      case AgentStatus.inactive:
        return Colors.grey;
      case AgentStatus.error:
        return Colors.red;
      case AgentStatus.processing:
        return Colors.orange;
      case AgentStatus.draft:
        return Colors.blue;
    }
  }

  /// 获取状态文本
  String _getStatusText(AgentStatus status) {
    switch (status) {
      case AgentStatus.active:
        return '活跃';
      case AgentStatus.inactive:
        return '停用';
      case AgentStatus.error:
        return '错误';
      case AgentStatus.processing:
        return '运行中';
      case AgentStatus.draft:
        return '草稿';
    }
  }

  /// 计算成功率
  double _calculateSuccessRate(AIAgent agent) {
    if (agent.totalRuns == null || agent.totalRuns == 0) return 0.0;
    if (agent.successRuns == null) return 0.0;
    return ((agent.successRuns! / agent.totalRuns!) * 100).roundToDouble();
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return '${time.month}-${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  /// 获取引擎颜色
  Color _getEngineColor(KnowledgeBaseEngineType engineType) {
    switch (engineType) {
      case KnowledgeBaseEngineType.openai:
        return const Color(0xFF10A37F);
      case KnowledgeBaseEngineType.google:
        return const Color(0xFF4285F4);
      case KnowledgeBaseEngineType.vertexAiSearch:
        return const Color(0xFF34A853);
      case KnowledgeBaseEngineType.pinecone:
        return const Color(0xFF7C3AED);
      case KnowledgeBaseEngineType.algolia:
        return const Color(0xFF00B4D8);
      case KnowledgeBaseEngineType.elasticsearch:
        return const Color(0xFFFED766);
      case KnowledgeBaseEngineType.custom:
        return const Color(0xFF6366F1);
    }
  }
}

/// 聊天消息模型
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? agentName;
  final Map<String, dynamic>? metadata;
  final bool isError;
  final bool canRetry; // 是否可以重试
  final List<File>? attachedFiles; // 附加的文件
  final bool isEditing; // 是否正在编辑
  final String? originalContent; // 原始内容（用于编辑时恢复）

  ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.agentName,
    this.metadata,
    this.isError = false,
    this.canRetry = false,
    this.attachedFiles,
    this.isEditing = false,
    this.originalContent,
  });

  /// 复制并修改消息
  ChatMessage copyWith({
    String? content,
    bool? isUser,
    DateTime? timestamp,
    String? agentName,
    Map<String, dynamic>? metadata,
    bool? isError,
    bool? canRetry,
    List<File>? attachedFiles,
    bool? isEditing,
    String? originalContent,
  }) {
    return ChatMessage(
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      agentName: agentName ?? this.agentName,
      metadata: metadata ?? this.metadata,
      isError: isError ?? this.isError,
      canRetry: canRetry ?? this.canRetry,
      attachedFiles: attachedFiles ?? this.attachedFiles,
      isEditing: isEditing ?? this.isEditing,
      originalContent: originalContent ?? this.originalContent,
    );
  }
}

/// 对话模型
class Conversation {
  final String id;
  final String title;
  final AIAgent? agent;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final List<ChatMessage> messages;
  final bool isPinned;
  final Map<String, dynamic>? metadata;

  Conversation({
    required this.id,
    required this.title,
    this.agent,
    required this.createdAt,
    required this.lastUpdated,
    required this.messages,
    this.isPinned = false,
    this.metadata,
  });

  Conversation copyWith({
    String? id,
    String? title,
    AIAgent? agent,
    DateTime? createdAt,
    DateTime? lastUpdated,
    List<ChatMessage>? messages,
    bool? isPinned,
    Map<String, dynamic>? metadata,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      agent: agent ?? this.agent,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      messages: messages ?? this.messages,
      isPinned: isPinned ?? this.isPinned,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'agent': agent?.toMap(),
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'messages': messages.map((m) => {
        'content': m.content,
        'isUser': m.isUser,
        'timestamp': m.timestamp.toIso8601String(),
        'agentName': m.agentName,
        'metadata': m.metadata,
        'isError': m.isError,
      }).toList(),
      'isPinned': isPinned,
      'metadata': metadata,
    };
  }
}

/// 代理选择对话框
class _AgentSelectionDialog extends StatefulWidget {
  final List<AIAgent> availableAgents;
  final Function(AIAgent) onAgentSelected;
  final VoidCallback onGeneralAssistant;

  const _AgentSelectionDialog({
    required this.availableAgents,
    required this.onAgentSelected,
    required this.onGeneralAssistant,
  });

  @override
  State<_AgentSelectionDialog> createState() => _AgentSelectionDialogState();
}

class _AgentSelectionDialogState extends State<_AgentSelectionDialog> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        height: 500,
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
            // 头部
            Container(
              padding: const EdgeInsets.all(24),
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
                  Icon(
                    Icons.psychology,
                    color: themeProvider.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择AI代理',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '选择一个专业代理或使用通用助手开始对话',
                          style: TextStyle(
                            fontSize: 14,
                            color: themeProvider.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: themeProvider.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            
            // 选项列表
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // 通用助手选项
                    _buildGeneralAssistantOption(themeProvider),
                    
                    if (widget.availableAgents.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Divider(color: themeProvider.borderColor),
                      const SizedBox(height: 16),
                      
                      // 专业代理标题
                      Row(
                        children: [
                          Icon(
                            Icons.smart_toy,
                            color: themeProvider.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '专业代理',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // 代理列表
                      Expanded(
                        child: ListView.builder(
                          itemCount: widget.availableAgents.length,
                          itemBuilder: (context, index) {
                            final agent = widget.availableAgents[index];
                            return _buildAgentOption(agent, themeProvider);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralAssistantOption(ThemeProvider themeProvider) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        widget.onGeneralAssistant();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: themeProvider.primaryColor, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: themeProvider.primaryColor.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: themeProvider.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.psychology,
                color: themeProvider.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '通用助手',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: themeProvider.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '推荐',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '智能助手，可以回答各种问题，处理多样化任务',
                    style: TextStyle(
                      fontSize: 14,
                      color: themeProvider.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: themeProvider.primaryColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentOption(AIAgent agent, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          widget.onAgentSelected(agent);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: themeProvider.borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      agent.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: themeProvider.textSecondaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: themeProvider.textSecondaryColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
}

/// 代理切换对话框
class _AgentSwitchDialog extends StatefulWidget {
  final List<AIAgent> availableAgents;
  final AIAgent? currentAgent;
  final Function(AIAgent) onAgentSelected;
  final VoidCallback onGeneralAssistant;

  const _AgentSwitchDialog({
    required this.availableAgents,
    this.currentAgent,
    required this.onAgentSelected,
    required this.onGeneralAssistant,
  });

  @override
  State<_AgentSwitchDialog> createState() => _AgentSwitchDialogState();
}

class _AgentSwitchDialogState extends State<_AgentSwitchDialog> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        height: 400,
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
            // 头部
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
                  Icon(
                    Icons.swap_horiz,
                    color: themeProvider.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '切换代理',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: themeProvider.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),

            // 选项列表
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 通用助手选项
                    _buildSwitchOption(
                      icon: Icons.psychology,
                      title: '通用助手',
                      description: '智能助手，可以回答各种问题',
                      isSelected: widget.currentAgent == null,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onGeneralAssistant();
                      },
                      themeProvider: themeProvider,
                    ),
                    
                    const SizedBox(height: 12),
                    Divider(color: themeProvider.borderColor),
                    const SizedBox(height: 12),
                    
                    // 专业代理列表
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.availableAgents.length,
                        itemBuilder: (context, index) {
                          final agent = widget.availableAgents[index];
                          return _buildSwitchOption(
                            icon: _getAgentIcon(agent.type),
                            title: agent.name,
                            description: agent.description,
                            isSelected: widget.currentAgent?.id == agent.id,
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onAgentSelected(agent);
                            },
                            themeProvider: themeProvider,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchOption({
    required IconData icon,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? themeProvider.primaryColor : themeProvider.borderColor,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? themeProvider.primaryColor.withOpacity(0.05) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: themeProvider.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: themeProvider.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.textColor,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: themeProvider.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: themeProvider.primaryColor,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

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
}
