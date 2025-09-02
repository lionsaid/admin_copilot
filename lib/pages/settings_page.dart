import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'model_providers_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      body: Column(
        children: [
          // 顶部栏
          Container(
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
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, color: themeProvider.textColor),
                ),
                const SizedBox(width: 16),
                Text(
                  l10n.settings,
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // 设置内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 主题设置
                  _buildSection(
                    context,
                    title: '主题设置',
                    children: [
                      _buildThemeToggle(context),
                      const SizedBox(height: 16),
                      _buildThemePreview(context),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 语言设置
                  _buildSection(
                    context,
                    title: '语言设置',
                    children: [
                      _buildLanguageSelector(context),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 其他设置
                  _buildSection(
                    context,
                    title: '其他设置',
                    children: [
                      _buildSettingItem(
                        context,
                        icon: Icons.notifications,
                        title: '通知设置',
                        subtitle: '管理应用通知',
                        onTap: () {},
                      ),
                      _buildSettingItem(
                        context,
                        icon: Icons.security,
                        title: '隐私设置',
                        subtitle: '管理隐私和安全选项',
                        onTap: () {},
                      ),
                      _buildSettingItem(
                        context,
                        icon: Icons.storage,
                        title: '存储管理',
                        subtitle: '查看和管理存储空间',
                        onTap: () {},
                      ),
                      _buildSettingItem(
                        context,
                        icon: Icons.api,
                        title: '模型提供商',
                        subtitle: '管理AI模型连接配置',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ModelProvidersPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeProvider.borderColor),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  Widget _buildThemeToggle(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.palette,
              color: themeProvider.textColor,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '主题模式',
                    style: TextStyle(
                      color: themeProvider.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '选择您偏好的主题模式',
                    style: TextStyle(
                      color: themeProvider.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child:                _buildThemeOption(
                 context,
                 mode: AppThemeMode.dark,
                 title: '深色模式',
                 subtitle: '适合夜间使用',
                 icon: Icons.dark_mode,
                 isSelected: themeProvider.themeMode == AppThemeMode.dark,
                 onTap: () => themeProvider.setThemeMode(AppThemeMode.dark),
               ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child:                _buildThemeOption(
                 context,
                 mode: AppThemeMode.light,
                 title: '浅色模式',
                 subtitle: '适合日间使用',
                 icon: Icons.light_mode,
                 isSelected: themeProvider.themeMode == AppThemeMode.light,
                 onTap: () => themeProvider.setThemeMode(AppThemeMode.light),
               ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child:                _buildThemeOption(
                 context,
                 mode: AppThemeMode.system,
                 title: '跟随系统',
                 subtitle: '自动切换',
                 icon: Icons.settings_system_daydream,
                 isSelected: themeProvider.themeMode == AppThemeMode.system,
                 onTap: () => themeProvider.setThemeMode(AppThemeMode.system),
               ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildThemeOption(
    BuildContext context, {
    required AppThemeMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? themeProvider.primaryColor.withOpacity(0.1)
              : themeProvider.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? themeProvider.primaryColor
                : themeProvider.borderColor,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? themeProvider.primaryColor
                  : themeProvider.textColor,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected 
                    ? themeProvider.primaryColor
                    : themeProvider.textColor,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected 
                    ? themeProvider.primaryColor.withOpacity(0.8)
                    : themeProvider.textSecondaryColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildThemePreview(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.color_lens,
              color: themeProvider.textColor,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '主题色彩',
                    style: TextStyle(
                      color: themeProvider.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '选择您喜欢的主题色彩',
                    style: TextStyle(
                      color: themeProvider.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 颜色选择器
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: ThemeProvider.colorOptions.length,
          itemBuilder: (context, index) {
            final color = ThemeProvider.colorOptions[index];
            final isSelected = themeProvider.primaryColor == color;
            
            return GestureDetector(
              onTap: () => themeProvider.setPrimaryColor(color),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? themeProvider.textColor : Colors.transparent,
                    width: isSelected ? 3 : 0,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      )
                    : null,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // 当前颜色信息
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: themeProvider.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: themeProvider.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: themeProvider.primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前主色调',
                      style: TextStyle(
                        color: themeProvider.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '#${themeProvider.primaryColor.value.toRadixString(16).substring(2).toUpperCase()}',
                      style: TextStyle(
                        color: themeProvider.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildLanguageSelector(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.language,
              color: themeProvider.textColor,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '应用语言',
                    style: TextStyle(
                      color: themeProvider.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '选择您偏好的语言',
                    style: TextStyle(
                      color: themeProvider.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildLanguageOption(
                context,
                languageCode: 'en',
                languageName: 'English',
                isSelected: themeProvider.language == 'en',
                onTap: () => themeProvider.setLanguage('en'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLanguageOption(
                context,
                languageCode: 'zh',
                languageName: '中文',
                isSelected: themeProvider.language == 'zh',
                onTap: () => themeProvider.setLanguage('zh'),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildLanguageOption(
    BuildContext context, {
    required String languageCode,
    required String languageName,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
                       color: isSelected 
                 ? themeProvider.primaryColor.withOpacity(0.1)
                 : themeProvider.backgroundColor,
           borderRadius: BorderRadius.circular(8),
           border: Border.all(
             color: isSelected 
                 ? themeProvider.primaryColor
                 : themeProvider.borderColor,
           ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
                         Text(
               languageName,
               style: TextStyle(
                 color: isSelected 
                     ? themeProvider.primaryColor
                     : themeProvider.textColor,
                 fontSize: 14,
                 fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
               ),
             ),
             if (isSelected) ...[
               const SizedBox(width: 8),
               Icon(
                 Icons.check,
                 color: themeProvider.primaryColor,
                 size: 16,
               ),
             ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return ListTile(
      leading: Icon(
        icon,
        color: themeProvider.textColor,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: themeProvider.textColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: themeProvider.textSecondaryColor,
          fontSize: 14,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: themeProvider.textSecondaryColor,
        size: 16,
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
