import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'pages/settings_page.dart';
import 'pages/model_providers_page.dart';
import 'pages/console_page.dart';
import 'pages/ai_agents_page.dart';
import 'pages/chat_page.dart';
import 'pages/workflow_page.dart';
import 'services/database_service.dart';
import 'services/database_repair_service.dart';
import 'services/log_service.dart';
import 'models/system_log.dart';
import 'widgets/loading_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
    return MaterialApp(
              title: 'Admin Copilot',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            locale: Locale(themeProvider.language),
            supportedLocales: const [
              Locale('en'),
              Locale('zh'),
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const DashboardPage(),
          );
        },
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 初始化数据库
    _initDatabase();
  }
  
  Future<void> _initDatabase() async {
    try {
      // 启动前自检（失败会自动重建数据库）
      await DatabaseService.selfCheckAndRecreateIfNeeded();
      await DatabaseService.database;
      
      // 修复AI代理数据
      try {
        await DatabaseRepairService.repairAIAgentData();
      } catch (e) {
        print('修复AI代理数据时出错: $e');
        // 如果修复失败，尝试重置表
        try {
          await DatabaseRepairService.resetAIAgentTable();
        } catch (resetError) {
          print('重置AI代理表时出错: $resetError');
        }
      }
      
      // 记录应用启动日志
      await LogService.info(
        '应用启动成功',
        details: '数据库初始化完成，Admin Copilot 已准备就绪',
        category: LogCategory.system,
        userId: 'system',
        userName: 'System',
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Database initialization error: $e');
      
      // 记录初始化错误日志
      await LogService.error(
        '应用启动失败',
        details: '数据库初始化失败: $e',
        category: LogCategory.system,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '数据库初始化失败，某些功能可能无法正常使用';
        });
      }
    }
  }
  
  void _retryInit() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _initDatabase();
  }
  
  void _navigateToSettings() {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsPage()),
      ).catchError((error) {
        print('导航到设置页面失败: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法打开设置页面: $error'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } catch (e) {
      print('导航异常: $e');
    }
  }
  
  void _navigateToModelProviders() async {
    try {
      // 记录用户操作日志
      await LogService.userAction(
        '用户访问模型提供商管理',
        details: '用户点击模型提供商菜单项',
        userId: 'admin',
        userName: 'Admin',
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ModelProvidersPage()),
      ).catchError((error) {
        print('导航到模型供应商页面失败: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法打开模型供应商页面: $error'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } catch (e) {
      print('导航异常: $e');
    }
  }

  void _navigateToConsole() async {
    try {
      // 记录用户操作日志
      await LogService.userAction(
        '用户访问系统控制台',
        details: '用户点击系统控制台页面',
        userId: 'admin',
        userName: 'Admin',
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ConsolePage()),
      ).catchError((error) {
        print('导航到系统控制台页面失败: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法打开系统控制台页面: $error'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } catch (e) {
      print('导航异常: $e');
    }
  }

  void _navigateToAIAgents() async {
    try {
      // 记录用户操作日志
      await LogService.userAction(
        '用户访问AI代理管理',
        details: '用户点击AI代理菜单项',
        userId: 'admin',
        userName: 'Admin',
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AIAgentsPage()),
      ).catchError((error) {
        print('导航到AI代理页面失败: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法打开AI代理页面: $error'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } catch (e) {
      print('导航异常: $e');
    }
  }

  void _navigateToWorkflow() async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const WorkflowPage()),
      );
    } catch (e) {
      print('导航到工作流程页面失败: $e');
    }
  }

  void _navigateToChat() async {
    try {
      // 记录用户操作日志
      await LogService.userAction(
        '用户访问聊天页面',
        details: '用户点击开始对话菜单项',
        userId: 'admin',
        userName: 'Admin',
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChatPage()),
      ).catchError((error) {
        print('导航到聊天页面失败: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法打开聊天页面: $error'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } catch (e) {
      print('导航异常: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    
    // 显示加载状态
    if (_isLoading) {
      return Scaffold(
        backgroundColor: themeProvider.backgroundColor,
        body: const Center(
          child: LoadingWidget(message: '正在初始化...'),
        ),
      );
    }
    
    // 显示错误状态
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: themeProvider.backgroundColor,
        body: Center(
          child: AppErrorWidget(
            message: _errorMessage!,
            onRetry: _retryInit,
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 1200;
          final sidebarWidth = isWideScreen ? 280.0 : 260.0;
          
          return Row(
            children: [
              // 侧边栏
              Container(
                width: sidebarWidth,
            color: themeProvider.surfaceColor,
            child: Column(
              children: [
                // Logo区域
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'N',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                                             Text(
                         'Admin Copilot',
                         style: TextStyle(
                           color: themeProvider.textColor,
                           fontSize: 20,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                    ],
                  ),
                ),
                                 Divider(color: themeProvider.borderColor),
                
                // 导航菜单
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                         children: [
                       _buildSectionTitle(l10n.general),
                       _buildNavItem(l10n.dashboards, Icons.dashboard, 0, true),
                       _buildNavItem('开始对话', Icons.chat_bubble_outline, 12, false, _navigateToChat),
                       _buildNavItem('模型供应商', Icons.api, 10),
                       _buildNavItem('系统控制台', Icons.terminal, 11, false),
                       _buildNavItem(l10n.aiAgents, Icons.smart_toy, 1, false, _navigateToAIAgents),
                       _buildNavItem(l10n.workflows, Icons.account_tree, 2, false, _navigateToWorkflow),
                       _buildNavItem(l10n.documents, Icons.description, 3),
                       
                       const SizedBox(height: 24),
                       _buildSectionTitle(l10n.toolsResources),
                       _buildNavItem(l10n.assets, Icons.image, 4),
                       _buildNavItem(l10n.generator, Icons.settings, 5),
                       _buildNavItem(l10n.analytics, Icons.analytics, 6),
                       
                       const SizedBox(height: 24),
                       _buildSectionTitle(l10n.settingsSection),
                       _buildNavItem(l10n.helpCenter, Icons.help, 7),
                       _buildNavItem('主题设置', Icons.dark_mode, 8),
                       _buildNavItem(l10n.settings, Icons.settings, 9),
                     ],
                  ),
                ),
                
                // 用户信息
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.blue,
                                                       child: Text(
                             'FE',
                             style: TextStyle(
                               color: themeProvider.textColor,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                                                             children: [
                                 Text(
                                   'Franklin Eugene',
                                   style: TextStyle(
                                     color: themeProvider.textColor,
                                     fontWeight: FontWeight.w500,
                                   ),
                                 ),
                                 Text(
                                   'eug.frank01@lain.com',
                                   style: TextStyle(
                                     color: themeProvider.textSecondaryColor,
                                     fontSize: 12,
                                   ),
                                 ),
                               ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                                             SizedBox(
                         width: double.infinity,
                         child: TextButton.icon(
                           onPressed: () {},
                           icon: Icon(Icons.logout, color: themeProvider.textSecondaryColor),
                           label: Text(
                             l10n.signOut,
                             style: TextStyle(color: themeProvider.textSecondaryColor),
                           ),
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 主内容区域
          Expanded(
            child: Column(
              children: [
                // 顶部栏
                _buildTopBar(),
                
                // 主内容
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isWideScreen ? 24 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 欢迎横幅
                        _buildWelcomeBanner(),
                        const SizedBox(height: 32),
                        
                        // 统计卡片
                        _buildStatsCards(),
                        const SizedBox(height: 32),
                        
                        // 底部内容区域
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // AI代理列表
                            Expanded(
                              flex: 2,
                              child: _buildQuickLaunchAgents(),
                            ),
                            const SizedBox(width: 24),
                            // 最近活动
                            Expanded(
                              flex: 1,
                              child: _buildRecentActivity(),
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
        ],
      );
    },
    ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: themeProvider.textSecondaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem(String title, IconData icon, int index, [bool isSelected = false, VoidCallback? onTap]) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? themeProvider.borderColor : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? themeProvider.textColor : themeProvider.textSecondaryColor,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? themeProvider.textColor : themeProvider.textSecondaryColor,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
                 onTap: onTap ?? () {
           setState(() {
             _selectedIndex = index;
           });
           
           // 处理特殊页面导航
           if (index == 8) { // Theme toggle (Dark Mode)
             // 暂时不做任何操作，主题切换在设置页面进行
           } else if (index == 9) { // Settings
             _navigateToSettings();
           } else if (index == 10) { // Model Providers
             _navigateToModelProviders();
           } else if (index == 11) { // Console
             _navigateToConsole();
           }
         },
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        dense: true,
      ),
    );
  }

  Widget _buildTopBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: themeProvider.surfaceColor,
        border: Border(
          bottom: BorderSide(color: themeProvider.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 搜索栏
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF404040),
                borderRadius: BorderRadius.circular(8),
              ),
                             child: Row(
                 children: [
                   const SizedBox(width: 12),
                   Icon(Icons.search, color: themeProvider.textSecondaryColor, size: 20),
                   const SizedBox(width: 8),
                   Expanded(
                     child: TextField(
                       style: TextStyle(color: themeProvider.textColor),
                       decoration: InputDecoration(
                         hintText: l10n.search,
                         hintStyle: TextStyle(color: themeProvider.textSecondaryColor),
                         border: InputBorder.none,
                         contentPadding: EdgeInsets.zero,
                       ),
                     ),
                   ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF505050),
                      borderRadius: BorderRadius.circular(4),
                    ),
                                         child: Text(
                       '⌘F',
                       style: TextStyle(
                         color: themeProvider.textSecondaryColor,
                         fontSize: 12,
                       ),
                     ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // AI助手按钮
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
                         child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 const Icon(Icons.refresh, color: Colors.white, size: 16),
                 const SizedBox(width: 8),
                 Text(
                   l10n.aiAssistant,
                   style: const TextStyle(
                     color: Colors.white,
                     fontWeight: FontWeight.w500,
                   ),
                 ),
               ],
             ),
          ),
          const SizedBox(width: 16),
          
                     // 通知图标
           Icon(Icons.history, color: themeProvider.textSecondaryColor, size: 24),
           const SizedBox(width: 16),
           Icon(Icons.mail, color: themeProvider.textSecondaryColor, size: 24),
           const SizedBox(width: 16),
           Icon(Icons.notifications, color: themeProvider.textSecondaryColor, size: 24),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: themeProvider.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                                 Text(
                   l10n.welcomeTitle,
                   style: TextStyle(
                     color: themeProvider.textColor,
                     fontSize: 28,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                const SizedBox(height: 16),
                                 Text(
                   l10n.welcomeDescription,
                   style: TextStyle(
                     color: themeProvider.textSecondaryColor,
                     fontSize: 16,
                     height: 1.5,
                   ),
                 ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    // TODO: 添加获取开始功能
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: themeProvider.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IntrinsicWidth(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, color: themeProvider.textColor, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.gettingStarted,
                              style: TextStyle(
                                color: themeProvider.textColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // AI工具图标网格
          Container(
            width: 120,
            height: 120,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: themeProvider.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: themeProvider.primaryColor,
                    size: 24,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    final stats = [
      {'value': '150+', 'label': l10n.favoritePrompts, 'icon': Icons.star, 'color': themeProvider.primaryColor},
      {'value': '12+', 'label': l10n.aiAgentsCount, 'icon': Icons.smart_toy, 'color': themeProvider.primaryColor},
      {'value': '89', 'label': l10n.uploadedDocs, 'icon': Icons.description, 'color': themeProvider.primaryColor},
      {'value': '1.2K', 'label': l10n.flowsExecuted, 'icon': Icons.account_tree, 'color': themeProvider.primaryColor},
    ];

    return Row(
      children: stats.map((stat) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: themeProvider.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      stat['icon'] as IconData,
                      color: stat['color'] as Color,
                      size: 24,
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  stat['value'] as String,
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  stat['label'] as String,
                  style: TextStyle(
                    color: themeProvider.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickLaunchAgents() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.quickLaunchAgents,
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildAgentCard(
                l10n.smartEmailAssistant,
                l10n.emailAssistantDescription,
                '156 ${l10n.tokensRunning}',
                true,
              ),
              const SizedBox(height: 16),
              _buildAgentCard(
                l10n.contentGenerationBot,
                l10n.contentBotDescription,
                '89 ${l10n.tokensRunning}',
                true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgentCard(String title, String description, String status, bool isActive) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeProvider.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'May 25, 2025',
                      style: TextStyle(
                        color: themeProvider.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        color: themeProvider.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                 decoration: BoxDecoration(
                   color: isActive ? themeProvider.primaryColor.withOpacity(0.2) : themeProvider.borderColor.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Text(
                   isActive ? 'Active' : 'Inactive',
                   style: TextStyle(
                     color: isActive ? themeProvider.primaryColor : themeProvider.textSecondaryColor,
                     fontSize: 12,
                     fontWeight: FontWeight.w500,
                   ),
                 ),
              ),
            ],
          ),
          const SizedBox(height: 12),
            Text(
            description,
            style: TextStyle(
              color: themeProvider.textSecondaryColor,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
                       Text(
             status,
             style: TextStyle(
               color: isActive ? themeProvider.primaryColor : themeProvider.textSecondaryColor,
               fontSize: 12,
               fontWeight: FontWeight.w500,
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recentActivity,
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildActivityCard(
                l10n.marketingTrends,
                l10n.marketingMessage,
                l10n.deepseek,
              ),
              const SizedBox(height: 16),
              _buildActivityCard(
                l10n.projectAnalysis,
                l10n.projectMessage,
                l10n.gpt4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard(String title, String message, String tag) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeProvider.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'May 25, 2025',
                      style: TextStyle(
                        color: themeProvider.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        color: themeProvider.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chat_bubble_outline,
                color: themeProvider.textSecondaryColor,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: themeProvider.textSecondaryColor,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
                     Container(
             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
             decoration: BoxDecoration(
               color: themeProvider.primaryColor.withOpacity(0.2),
               borderRadius: BorderRadius.circular(12),
             ),
             child: Text(
               tag,
               style: TextStyle(
                 color: themeProvider.primaryColor,
                 fontSize: 12,
                 fontWeight: FontWeight.w500,
               ),
             ),
           ),
        ],
      ),
    );
  }
}
