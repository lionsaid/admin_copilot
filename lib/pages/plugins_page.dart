import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class PluginsPage extends StatelessWidget {
  const PluginsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('插件中心'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.extension, size: 64, color: theme.textSecondaryColor),
            const SizedBox(height: 12),
            Text('插件功能即将推出', style: TextStyle(color: theme.textColor)),
          ],
        ),
      ),
    );
  }
}


