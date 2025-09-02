import 'package:flutter/material.dart';
import '../services/database_service.dart';

enum AppThemeMode {
  light,
  dark,
  system,
}

class ThemeProvider with ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.dark;
  String _language = 'en';
  // Clarity 主色：科技蓝 #3B82F6
  Color _primaryColor = const Color(0xFF3B82F6);
  
  bool get isDarkMode {
    switch (_themeMode) {
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.light:
        return false;
      case AppThemeMode.system:
        // 这里可以根据系统主题来判断，暂时返回true
        return true;
    }
  }
  
  AppThemeMode get themeMode => _themeMode;
  String get language => _language;
  Color get primaryColor => _primaryColor;
  
  // 深色主题颜色
  // Clarity 深色体系
  static const Color darkBackgroundColor = Color(0xFF1A1A1A); // 炭灰
  static const Color darkSurfaceColor = Color(0xFF252525);    // 次级面板
  static const Color darkBorderColor = Color(0xFF3A3A3A);
  static const Color darkTextColor = Colors.white;
  static const Color darkTextSecondaryColor = Colors.grey;
  
  // 浅色主题颜色
  static const Color lightBackgroundColor = Color(0xFFFFFFFF);
  static const Color lightSurfaceColor = Color(0xFFF5F5F5);
  static const Color lightBorderColor = Color(0xFFE0E0E0);
  static const Color lightTextColor = Color(0xFF1A1A1A);
  static const Color lightTextSecondaryColor = Color(0xFF666666);
  
  // 预定义的颜色选项
  static const List<Color> colorOptions = [
    Color(0xFF3B82F6), // Clarity 蓝
    Color(0xFF4CAF50), // 绿色
    Color(0xFFFF9800), // 橙色
    Color(0xFF9C27B0), // 紫色
    Color(0xFFF44336), // 红色
    Color(0xFF00BCD4), // 青色
    Color(0xFF795548), // 棕色
    Color(0xFF607D8B), // 蓝灰色
  ];
  
  ThemeProvider() {
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    try {
      final savedThemeMode = await DatabaseService.getSetting('theme_mode');
      final savedLanguage = await DatabaseService.getSetting('language');
      final savedPrimaryColor = await DatabaseService.getSetting('primary_color');
      
      // 安全地设置主题模式
      if (savedThemeMode != null) {
        switch (savedThemeMode) {
          case 'dark':
            _themeMode = AppThemeMode.dark;
            break;
          case 'light':
            _themeMode = AppThemeMode.light;
            break;
          case 'system':
            _themeMode = AppThemeMode.system;
            break;
          default:
            print('未知的主题模式: $savedThemeMode，使用默认深色模式');
            _themeMode = AppThemeMode.dark;
        }
      }
      
      // 安全地设置语言
      if (savedLanguage != null && ['en', 'zh'].contains(savedLanguage)) {
        _language = savedLanguage;
      } else if (savedLanguage != null) {
        print('不支持的语言: $savedLanguage，使用默认英语');
        _language = 'en';
      }
      
      // 安全地设置主色调
      if (savedPrimaryColor != null) {
        try {
          final colorValue = int.parse(savedPrimaryColor);
          final color = Color(colorValue);
          
          // 验证颜色是否在预定义选项中
          if (colorOptions.contains(color)) {
            _primaryColor = color;
          } else {
            print('颜色不在预定义选项中: $savedPrimaryColor，使用默认蓝色');
            _primaryColor = colorOptions.first;
          }
        } catch (e) {
          print('解析颜色值失败: $savedPrimaryColor，错误: $e');
          _primaryColor = colorOptions.first;
        }
      }
    } catch (e) {
      print('加载设置失败: $e');
      // 使用默认值
      _themeMode = AppThemeMode.dark;
      _language = 'en';
      _primaryColor = colorOptions.first;
    }
    
    notifyListeners();
  }
  
  Future<void> setThemeMode(AppThemeMode mode) async {
    try {
      _themeMode = mode;
      String modeString;
      switch (mode) {
        case AppThemeMode.dark:
          modeString = 'dark';
          break;
        case AppThemeMode.light:
          modeString = 'light';
          break;
        case AppThemeMode.system:
          modeString = 'system';
          break;
      }
      await DatabaseService.saveSetting('theme_mode', modeString);
      notifyListeners();
    } catch (e) {
      print('保存主题模式失败: $e');
      // 即使保存失败，也要更新UI
      notifyListeners();
    }
  }
  
  Future<void> setPrimaryColor(Color color) async {
    try {
      // 验证颜色是否在预定义选项中
      if (!colorOptions.contains(color)) {
        print('尝试设置无效的颜色: $color');
        return;
      }
      
      _primaryColor = color;
      await DatabaseService.saveSetting('primary_color', color.value.toString());
      notifyListeners();
    } catch (e) {
      print('保存主色调失败: $e');
      // 即使保存失败，也要更新UI
      notifyListeners();
    }
  }
  
  Future<void> setLanguage(String languageCode) async {
    try {
      // 验证语言代码
      if (!['en', 'zh'].contains(languageCode)) {
        print('不支持的语言代码: $languageCode');
        return;
      }
      
      _language = languageCode;
      await DatabaseService.saveSetting('language', languageCode);
      notifyListeners();
    } catch (e) {
      print('保存语言设置失败: $e');
      // 即使保存失败，也要更新UI
      notifyListeners();
    }
  }
  
  ThemeData get themeData {
    return isDarkMode ? _darkTheme : _lightTheme;
  }
  
  ThemeData get _darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: MaterialColor(_primaryColor.value, _generateSwatch(_primaryColor)),
      primaryColor: _primaryColor,
      scaffoldBackgroundColor: darkBackgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurfaceColor,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: darkTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardTheme(
        color: darkSurfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkTextColor),
        bodyMedium: TextStyle(color: darkTextColor),
        titleLarge: TextStyle(color: darkTextColor),
        titleMedium: TextStyle(color: darkTextColor),
        titleSmall: TextStyle(color: darkTextColor),
      ),
      iconTheme: const IconThemeData(color: darkTextColor),
      dividerTheme: const DividerThemeData(color: darkBorderColor),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkBorderColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: darkTextSecondaryColor),
      ),
    );
  }
  
  ThemeData get _lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: MaterialColor(_primaryColor.value, _generateSwatch(_primaryColor)),
      primaryColor: _primaryColor,
      scaffoldBackgroundColor: lightBackgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurfaceColor,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: lightTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardTheme(
        color: lightSurfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: lightTextColor),
        bodyMedium: TextStyle(color: lightTextColor),
        titleLarge: TextStyle(color: lightTextColor),
        titleMedium: TextStyle(color: lightTextColor),
        titleSmall: TextStyle(color: lightTextColor),
      ),
      iconTheme: const IconThemeData(color: lightTextColor),
      dividerTheme: const DividerThemeData(color: lightBorderColor),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightBorderColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: lightTextSecondaryColor),
      ),
    );
  }
  
  // 获取背景颜色
  Color get backgroundColor => isDarkMode ? darkBackgroundColor : lightBackgroundColor;
  
  // 获取表面颜色
  Color get surfaceColor => isDarkMode ? darkSurfaceColor : lightSurfaceColor;
  
  // 获取边框颜色
  Color get borderColor => isDarkMode ? darkBorderColor : lightBorderColor;
  
  // 获取文本颜色
  Color get textColor => isDarkMode ? darkTextColor : lightTextColor;
  
  // 获取次要文本颜色
  Color get textSecondaryColor => isDarkMode ? darkTextSecondaryColor : lightTextSecondaryColor;
  
  // 生成颜色色板
  Map<int, Color> _generateSwatch(Color color) {
    return {
      50: color.withOpacity(0.1),
      100: color.withOpacity(0.2),
      200: color.withOpacity(0.3),
      300: color.withOpacity(0.4),
      400: color.withOpacity(0.5),
      500: color,
      600: color.withOpacity(0.7),
      700: color.withOpacity(0.8),
      800: color.withOpacity(0.9),
      900: color,
    };
  }
}
