import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'package:archive/archive.dart';

/// 文本提取结果
class TextExtractionResult {
  final String text;
  final bool success;
  final String extractionMethod;
  final int lineCount;
  final int wordCount;
  final String? error;
  final Map<String, dynamic>? metadata;

  TextExtractionResult({
    required this.text,
    required this.success,
    required this.extractionMethod,
    required this.lineCount,
    required this.wordCount,
    this.error,
    this.metadata,
  });
}

/// 文本提取器接口
abstract class TextExtractor {
  String get name;
  Future<TextExtractionResult> extract(File file, String encoding, Map<String, dynamic> metadata);
}

/// 纯文本提取器
class PlainTextExtractor implements TextExtractor {
  @override
  String get name => 'PlainTextExtractor';

  @override
  Future<TextExtractionResult> extract(File file, String encoding, Map<String, dynamic> metadata) async {
    try {
      final content = await file.readAsString(encoding: _getEncoding(encoding));
      final lines = content.split('\n');
      final words = content.split(RegExp(r'\s+'));
      
      return TextExtractionResult(
        text: content,
        success: true,
        extractionMethod: 'PLAIN_TEXT',
        lineCount: lines.length,
        wordCount: words.length,
        metadata: {
          'encoding': encoding,
          'avgWordsPerLine': lines.isNotEmpty ? (words.length / lines.length).toStringAsFixed(1) : '0',
        },
      );
    } catch (e) {
      return TextExtractionResult(
        text: '纯文本提取失败: $e',
        success: false,
        extractionMethod: 'PLAIN_TEXT_FAILED',
        lineCount: 0,
        wordCount: 0,
        error: e.toString(),
      );
    }
  }
}

/// Markdown 提取器
class MarkdownExtractor implements TextExtractor {
  @override
  String get name => 'MarkdownExtractor';

  @override
  Future<TextExtractionResult> extract(File file, String encoding, Map<String, dynamic> metadata) async {
    try {
      final content = await file.readAsString(encoding: _getEncoding(encoding));
      final lines = content.split('\n');
      final words = content.split(RegExp(r'\s+'));
      
      // 分析 Markdown 结构
      final headers = content.split('\n').where((line) => line.trim().startsWith('#')).length;
      final codeBlocks = RegExp(r'```[\s\S]*?```').allMatches(content).length;
      final links = RegExp(r'\[([^\]]+)\]\(([^)]+)\)').allMatches(content).length;
      
      return TextExtractionResult(
        text: content,
        success: true,
        extractionMethod: 'MARKDOWN',
        lineCount: lines.length,
        wordCount: words.length,
        metadata: {
          'encoding': encoding,
          'headers': headers,
          'codeBlocks': codeBlocks,
          'links': links,
          'avgWordsPerLine': lines.isNotEmpty ? (words.length / lines.length).toStringAsFixed(1) : '0',
        },
      );
    } catch (e) {
      return TextExtractionResult(
        text: 'Markdown 提取失败: $e',
        success: false,
        extractionMethod: 'MARKDOWN_FAILED',
        lineCount: 0,
        wordCount: 0,
        error: e.toString(),
      );
    }
  }
}

/// JSON 提取器
class JsonExtractor implements TextExtractor {
  @override
  String get name => 'JsonExtractor';

  @override
  Future<TextExtractionResult> extract(File file, String encoding, Map<String, dynamic> metadata) async {
    try {
      print('🔍 JSON 提取器开始处理...');
      final content = await file.readAsString(encoding: _getEncoding(encoding));
      print('📄 读取到内容长度: ${content.length}');
      
      // 尝试解析 JSON
      dynamic jsonData;
      try {
        jsonData = jsonDecode(content);
        print('✅ JSON 解析成功');
      } catch (jsonError) {
        print('⚠️ JSON 解析失败，作为纯文本处理: $jsonError');
        // 如果 JSON 解析失败，作为纯文本处理
        final lines = content.split('\n');
        final words = content.split(RegExp(r'\s+'));
        
        return TextExtractionResult(
          text: content,
          success: true,
          extractionMethod: 'JSON_AS_TEXT',
          lineCount: lines.length,
          wordCount: words.length,
          metadata: {
            'encoding': encoding,
            'jsonType': 'invalid_json',
            'isValidJson': false,
            'jsonError': jsonError.toString(),
          },
        );
      }
      
      final lines = content.split('\n');
      final words = content.split(RegExp(r'\s+'));
      
      // 分析 JSON 结构
      final jsonType = _getJsonType(jsonData);
      final keys = jsonData is Map ? jsonData.keys.toList() : null;
      final length = jsonData is List ? jsonData.length : null;
      
      print('📊 JSON 分析结果:');
      print('  - 类型: $jsonType');
      print('  - 键数量: ${keys?.length ?? 0}');
      print('  - 数组长度: ${length ?? 0}');
      
      return TextExtractionResult(
        text: content,
        success: true,
        extractionMethod: 'JSON',
        lineCount: lines.length,
        wordCount: words.length,
        metadata: {
          'encoding': encoding,
          'jsonType': jsonType,
          'jsonKeys': keys,
          'jsonLength': length,
          'isValidJson': true,
        },
      );
    } catch (e) {
      print('❌ JSON 提取器异常: $e');
      return TextExtractionResult(
        text: 'JSON 提取失败: $e',
        success: false,
        extractionMethod: 'JSON_FAILED',
        lineCount: 0,
        wordCount: 0,
        error: e.toString(),
      );
    }
  }
}

/// XML 提取器
class XmlExtractor implements TextExtractor {
  @override
  String get name => 'XmlExtractor';

  @override
  Future<TextExtractionResult> extract(File file, String encoding, Map<String, dynamic> metadata) async {
    try {
      final content = await file.readAsString(encoding: _getEncoding(encoding));
      final lines = content.split('\n');
      final words = content.split(RegExp(r'\s+'));
      
      // 分析 XML 结构
      final tags = RegExp(r'<[^>]+>').allMatches(content).length;
      final elements = RegExp(r'<(\w+)').allMatches(content).map((m) => m.group(1)).toSet().length;
      
      return TextExtractionResult(
        text: content,
        success: true,
        extractionMethod: 'XML',
        lineCount: lines.length,
        wordCount: words.length,
        metadata: {
          'encoding': encoding,
          'tags': tags,
          'elements': elements,
          'avgWordsPerLine': lines.isNotEmpty ? (words.length / lines.length).toStringAsFixed(1) : '0',
        },
      );
    } catch (e) {
      return TextExtractionResult(
        text: 'XML 提取失败: $e',
        success: false,
        extractionMethod: 'XML_FAILED',
        lineCount: 0,
        wordCount: 0,
        error: e.toString(),
      );
    }
  }
}

/// CSV 提取器
class CsvExtractor implements TextExtractor {
  @override
  String get name => 'CsvExtractor';

  @override
  Future<TextExtractionResult> extract(File file, String encoding, Map<String, dynamic> metadata) async {
    try {
      final content = await file.readAsString(encoding: _getEncoding(encoding));
      final lines = content.split('\n');
      final words = content.split(RegExp(r'\s+'));
      
      // 分析 CSV 结构
      final headers = lines.isNotEmpty ? lines.first.split(',') : [];
      final dataRows = lines.length > 1 ? lines.length - 1 : 0;
      
      return TextExtractionResult(
        text: content,
        success: true,
        extractionMethod: 'CSV',
        lineCount: lines.length,
        wordCount: words.length,
        metadata: {
          'encoding': encoding,
          'headers': headers,
          'dataRows': dataRows,
          'columnCount': headers.length,
          'avgWordsPerLine': lines.isNotEmpty ? (words.length / lines.length).toStringAsFixed(1) : '0',
        },
      );
    } catch (e) {
      return TextExtractionResult(
        text: 'CSV 提取失败: $e',
        success: false,
        extractionMethod: 'CSV_FAILED',
        lineCount: 0,
        wordCount: 0,
        error: e.toString(),
      );
    }
  }
}

/// DOCX 提取器
class DocxExtractor implements TextExtractor {
  @override
  String get name => 'DocxExtractor';

  @override
  Future<TextExtractionResult> extract(File file, String encoding, Map<String, dynamic> metadata) async {
    try {
      final extractedText = await _extractDocxText(file);
      final lines = extractedText.split('\n');
      final words = extractedText.split(RegExp(r'\s+'));
      
      return TextExtractionResult(
        text: extractedText,
        success: true,
        extractionMethod: 'DOCX_ZIP_PARSING',
        lineCount: lines.length,
        wordCount: words.length,
        metadata: {
          'encoding': encoding,
          'avgWordsPerLine': lines.isNotEmpty ? (words.length / lines.length).toStringAsFixed(1) : '0',
        },
      );
    } catch (e) {
      return TextExtractionResult(
        text: 'DOCX 提取失败: $e',
        success: false,
        extractionMethod: 'DOCX_FAILED',
        lineCount: 0,
        wordCount: 0,
        error: e.toString(),
      );
    }
  }
}

/// DOC 提取器
class DocExtractor implements TextExtractor {
  @override
  String get name => 'DocExtractor';

  @override
  Future<TextExtractionResult> extract(File file, String encoding, Map<String, dynamic> metadata) async {
    return TextExtractionResult(
      text: '暂不支持 .doc 格式的文本提取，需要专门的解析库',
      success: false,
      extractionMethod: 'DOC_NOT_SUPPORTED',
      lineCount: 1,
      wordCount: 0,
      error: '需要专门的 .doc 解析库',
    );
  }
}

/// 提取 DOCX 文档文本（基于 ZIP 格式解析）
Future<String> _extractDocxText(File file) async {
  try {
    print('🔍 开始解析 DOCX 文件结构...');
    
    // 读取整个文件
    final bytes = await file.readAsBytes();
    print('📊 文件字节数: ${bytes.length}');
    
    // 检查 ZIP 文件头
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw Exception('不是有效的 ZIP 文件格式');
    }
    print('✅ ZIP 文件头验证通过');
    
    // 使用 archive 包解析 ZIP 文件
    final archive = ZipDecoder().decodeBytes(bytes);
    print('📦 ZIP 文件解析成功，包含 ${archive.length} 个文件');
    
    String extractedText = '';
    
    // 查找并解析 word/document.xml
    for (final file in archive) {
      final fileName = file.name;
      print('📄 检查文件: $fileName');
      
      if (fileName == 'word/document.xml') {
        print('✅ 找到文档主体文件: $fileName');
        
        try {
          // 解压并读取 XML 内容
          final xmlContent = utf8.decode(file.content as List<int>);
          print('📄 XML 内容长度: ${xmlContent.length}');
          
          // 提取文本内容
          extractedText = _extractTextFromXml(xmlContent);
          break;
        } catch (e) {
          print('❌ 解析 XML 失败: $e');
        }
      }
    }
    
    // 如果没有找到 document.xml，尝试其他文件
    if (extractedText.isEmpty) {
      print('🔍 未找到 document.xml，尝试其他文件...');
      
      for (final file in archive) {
        final fileName = file.name;
        if (fileName.endsWith('.xml') && !fileName.contains('[')) {
          print('📄 尝试解析 XML 文件: $fileName');
          
          try {
            final xmlContent = utf8.decode(file.content as List<int>);
            final text = _extractTextFromXml(xmlContent);
            if (text.isNotEmpty) {
              extractedText = text;
              print('✅ 从 $fileName 提取到文本');
              break;
            }
          } catch (e) {
            print('❌ 解析 $fileName 失败: $e');
          }
        }
      }
    }
    
    // 清理和格式化文本
    if (extractedText.isNotEmpty) {
      extractedText = extractedText
          .replaceAll(RegExp(r'\s+'), ' ')  // 合并多个空格
          .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fff.,!?;:()\-]'), '')  // 保留基本标点和连字符
          .trim();
      
      print('📊 清理后文本长度: ${extractedText.length}');
      print('📄 文本预览: ${extractedText.substring(0, extractedText.length > 200 ? 200 : extractedText.length)}...');
      print('✅ 文本提取完成');
    } else {
      extractedText = '无法从 DOCX 文件中提取文本内容';
      print('⚠️ 无法提取文本内容');
    }
    
    return extractedText;
  } catch (e) {
    print('❌ DOCX 文本提取异常: $e');
    return 'DOCX 文本提取失败: $e';
  }
}

/// 从 XML 内容中提取文本
String _extractTextFromXml(String xmlContent) {
  String extractedText = '';
  
  // 提取 <w:t> 标签中的文本
  final wTextPattern = RegExp(r'<w:t[^>]*>([^<]*)</w:t>', dotAll: true);
  final matches = wTextPattern.allMatches(xmlContent);
  
  for (final match in matches) {
    final text = match.group(1)?.trim() ?? '';
    if (text.isNotEmpty) {
      extractedText += text + ' ';
    }
  }
  
  // 如果没有找到 <w:t> 标签，尝试 <t> 标签
  if (extractedText.isEmpty) {
    final tTextPattern = RegExp(r'<t[^>]*>([^<]*)</t>', dotAll: true);
    final tMatches = tTextPattern.allMatches(xmlContent);
    
    for (final match in tMatches) {
      final text = match.group(1)?.trim() ?? '';
      if (text.isNotEmpty) {
        extractedText += text + ' ';
      }
    }
  }
  
  return extractedText;
}

/// 代码提取器
class CodeExtractor implements TextExtractor {
  @override
  String get name => 'CodeExtractor';

  @override
  Future<TextExtractionResult> extract(File file, String encoding, Map<String, dynamic> metadata) async {
    try {
      final content = await file.readAsString(encoding: _getEncoding(encoding));
      final lines = content.split('\n');
      final words = content.split(RegExp(r'\s+'));
      
      // 分析代码结构
      final nonEmptyLines = lines.where((line) => line.trim().isNotEmpty).length;
      final commentLines = lines.where((line) => 
        line.trim().startsWith('//') || 
        line.trim().startsWith('/*') || 
        line.trim().startsWith('*') ||
        line.trim().startsWith('#') ||
        line.trim().startsWith('<!--')
      ).length;
      
      return TextExtractionResult(
        text: content,
        success: true,
        extractionMethod: 'CODE',
        lineCount: lines.length,
        wordCount: words.length,
        metadata: {
          'encoding': encoding,
          'nonEmptyLines': nonEmptyLines,
          'commentLines': commentLines,
          'codeLines': nonEmptyLines - commentLines,
          'commentRatio': lines.isNotEmpty ? (commentLines / lines.length * 100).toStringAsFixed(1) : '0',
          'avgWordsPerLine': lines.isNotEmpty ? (words.length / lines.length).toStringAsFixed(1) : '0',
        },
      );
    } catch (e) {
      return TextExtractionResult(
        text: '代码提取失败: $e',
        success: false,
        extractionMethod: 'CODE_FAILED',
        lineCount: 0,
        wordCount: 0,
        error: e.toString(),
      );
    }
  }
}

/// 通用文本提取器
class GenericTextExtractor implements TextExtractor {
  @override
  String get name => 'GenericTextExtractor';

  @override
  Future<TextExtractionResult> extract(File file, String encoding, Map<String, dynamic> metadata) async {
    try {
      final content = await file.readAsString(encoding: _getEncoding(encoding));
      final lines = content.split('\n');
      final words = content.split(RegExp(r'\s+'));
      
      return TextExtractionResult(
        text: content,
        success: true,
        extractionMethod: 'GENERIC_TEXT',
        lineCount: lines.length,
        wordCount: words.length,
        metadata: {
          'encoding': encoding,
          'avgWordsPerLine': lines.isNotEmpty ? (words.length / lines.length).toStringAsFixed(1) : '0',
        },
      );
    } catch (e) {
      return TextExtractionResult(
        text: '通用文本提取失败: $e',
        success: false,
        extractionMethod: 'GENERIC_TEXT_FAILED',
        lineCount: 0,
        wordCount: 0,
        error: e.toString(),
      );
    }
  }
}

/// 获取编码对象
Encoding _getEncoding(String encodingName) {
  switch (encodingName.toLowerCase()) {
    case 'utf-8':
      return utf8;
    case 'utf-16le':
      return utf8; // 简化处理，使用 UTF-8
    case 'utf-16be':
      return utf8; // 简化处理，使用 UTF-8
    case 'gbk':
      return latin1; // 简化处理，实际应该使用 GBK 编码
    default:
      return utf8;
  }
}

/// 获取 JSON 类型
String _getJsonType(dynamic jsonData) {
  if (jsonData is Map) return 'object';
  if (jsonData is List) return 'array';
  if (jsonData is String) return 'string';
  if (jsonData is num) return 'number';
  if (jsonData is bool) return 'boolean';
  return 'null';
}

/// 文件处理结果
class FileProcessResult {
  final bool success;
  final String? fileContent;
  final String? fileUrl;
  final String? error;
  final int? fileSize;
  final String? fileType;
  final String? fileName;
  final Map<String, dynamic>? metadata; // 新增：文件元数据

  FileProcessResult({
    required this.success,
    this.fileContent,
    this.fileUrl,
    this.error,
    this.fileSize,
    this.fileType,
    this.fileName,
    this.metadata,
  });
}

/// 文件上传服务 - 使用 Flutter 原生能力
class FileUploadService {
  // 支持的文件类型
  static const Map<String, List<String>> supportedFileTypes = {
    'image': ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg'],
    'document': ['.pdf', '.txt', '.doc', '.docx', '.rtf', '.md', '.json', '.xml', '.csv'],
    'code': ['.py', '.js', '.ts', '.java', '.cpp', '.c', '.h', '.html', '.css', '.php', '.rb', '.go', '.rs', '.swift', '.kt'],
    'data': ['.csv', '.json', '.xml', '.yaml', '.yml', '.sql', '.db', '.sqlite'],
    'archive': ['.zip', '.rar', '.7z', '.tar', '.gz'],
  };

  // 最大文件大小 (5MB)
  static const int maxFileSize = 5 * 1024 * 1024;

  /// 处理文件 - 使用 Flutter 原生能力
  static Future<FileProcessResult> processFile(File file, String agentName) async {
    try {
      print('=== FileUploadService.processFile 开始 ===');
      print('文件名: ${path.basename(file.path)}');
      print('文件扩展名: ${path.extension(file.path)}');
      print('文件路径: ${file.path}');
      print('代理名称: $agentName');

      // 1. 基础文件检查
      print('🔍 开始基础文件检查...');
      if (!await file.exists()) {
        print('❌ 文件不存在: ${path.basename(file.path)}');
        return FileProcessResult(
          success: false,
          error: '文件不存在: ${path.basename(file.path)}',
        );
      }
      print('✅ 文件存在性检查通过');

      final fileSize = await file.length();
      print('📏 文件大小: ${_formatFileSize(fileSize)} (${fileSize} bytes)');
      if (fileSize > maxFileSize) {
        print('❌ 文件过大: ${_formatFileSize(fileSize)} (最大 ${_formatFileSize(maxFileSize)})');
        return FileProcessResult(
          success: false,
          error: '文件过大: ${_formatFileSize(fileSize)} (最大 ${_formatFileSize(maxFileSize)})',
        );
      }
      print('✅ 文件大小检查通过');

      final extension = path.extension(file.path).toLowerCase();
      print('📋 文件扩展名: $extension');
      if (!_isFileTypeSupported(extension)) {
        print('❌ 不支持的文件类型: $extension');
        return FileProcessResult(
          success: false,
          error: '不支持的文件类型: $extension',
        );
      }
      print('✅ 文件类型检查通过');

      // 2. 提取文件元数据
      print('🔍 开始提取文件元数据...');
      final metadata = await _extractFileMetadata(file);
      print('📊 文件元数据提取完成:');
      _printMetadataDetails(metadata);

      // 3. 根据文件类型智能处理
      print('🔧 开始根据文件类型智能处理...');
      final result = await _processFileByType(file, extension, metadata);
      
      print('📋 文件处理结果:');
      print('- 成功: ${result.success}');
      print('- 错误: ${result.error}');
      print('- 内容长度: ${result.fileContent?.length ?? 0}');
      print('- 元数据: ${result.metadata}');

      return result;

    } catch (e) {
      print('❌ 文件处理异常: $e');
      return FileProcessResult(
        success: false,
        error: '文件处理异常: $e',
      );
    }
  }

  /// 提取文件元数据
  static Future<Map<String, dynamic>> _extractFileMetadata(File file) async {
    final stat = await file.stat();
    final extension = path.extension(file.path).toLowerCase();
    
    return {
      'fileName': path.basename(file.path),
      'filePath': file.path,
      'fileSize': stat.size,
      'fileSizeFormatted': _formatFileSize(stat.size),
      'fileExtension': extension,
      'mimeType': _getMimeType(extension),
      'lastModified': stat.modified.toIso8601String(),
      'created': stat.changed.toIso8601String(),
      'fileType': _getFileTypeCategory(extension),
      'isReadable': await file.exists(),
    };
  }

  /// 根据文件类型智能处理
  static Future<FileProcessResult> _processFileByType(
    File file, 
    String extension, 
    Map<String, dynamic> metadata
  ) async {
    
    switch (_getFileTypeCategory(extension)) {
      case 'image':
        return await _processImageFile(file, metadata);
      case 'document':
        return await _processDocumentFile(file, metadata);
      case 'code':
        return await _processCodeFile(file, metadata);
      case 'data':
        return await _processDataFile(file, metadata);
      case 'archive':
        return await _processArchiveFile(file, metadata);
      default:
        return await _processGenericFile(file, metadata);
    }
  }

  /// 通用文本提取器
  static Future<TextExtractionResult> _extractTextFromFile(File file, Map<String, dynamic> metadata) async {
    final extension = metadata['fileExtension'] as String;
    final fileName = metadata['fileName'] as String;
    
    print('📄 开始通用文本提取...');
    print('📁 文件: $fileName');
    print('📋 扩展名: $extension');
    
    try {
      // 1. 检测文件编码
      final encoding = await _detectFileEncoding(file);
      print('🔍 检测到文件编码: $encoding');
      
      // 2. 根据文件类型选择提取策略
      final extractor = _getTextExtractor(extension);
      print('🔧 使用提取器: ${extractor.name}');
      
      // 3. 执行文本提取
      final result = await extractor.extract(file, encoding, metadata);
      
      print('✅ 文本提取完成');
      print('📊 提取统计:');
      print('  - 文本长度: ${result.text.length} 字符');
      print('  - 行数: ${result.lineCount}');
      print('  - 单词数: ${result.wordCount}');
      print('  - 提取方法: ${result.extractionMethod}');
      
      return result;
    } catch (e) {
      print('❌ 文本提取失败: $e');
      return TextExtractionResult(
        text: '文本提取失败: $e',
        success: false,
        extractionMethod: 'FAILED',
        lineCount: 0,
        wordCount: 0,
        error: e.toString(),
      );
    }
  }

  /// 检测文件编码
  static Future<String> _detectFileEncoding(File file) async {
    try {
      // 读取文件头部来检测编码
      final bytes = await file.openRead(0, 1024).first;
      
      // 检查 BOM (Byte Order Mark)
      if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        return 'utf-8';
      } else if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
        return 'utf-16le';
      } else if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
        return 'utf-16be';
      }
      
      // 尝试检测 UTF-8
      try {
        final content = String.fromCharCodes(bytes);
        if (content.contains('')) {
          // 包含替换字符，可能不是 UTF-8
          return 'gbk'; // 假设是 GBK
        }
        return 'utf-8';
      } catch (e) {
        return 'gbk'; // 默认使用 GBK
      }
    } catch (e) {
      return 'utf-8'; // 默认使用 UTF-8
    }
  }

  /// 获取文本提取器
  static TextExtractor _getTextExtractor(String extension) {
    switch (extension.toLowerCase()) {
      case '.txt':
        return PlainTextExtractor();
      case '.md':
        return MarkdownExtractor();
      case '.json':
        return JsonExtractor();
      case '.xml':
        return XmlExtractor();
      case '.csv':
        return CsvExtractor();
      case '.docx':
        return DocxExtractor();
      case '.doc':
        return DocExtractor();
      case '.py':
      case '.js':
      case '.ts':
      case '.java':
      case '.cpp':
      case '.c':
      case '.h':
      case '.html':
      case '.css':
      case '.php':
      case '.rb':
      case '.go':
      case '.rs':
      case '.swift':
      case '.kt':
        return CodeExtractor();
      default:
        return GenericTextExtractor();
    }
  }

  /// 处理图片文件
  static Future<FileProcessResult> _processImageFile(File file, Map<String, dynamic> metadata) async {
    try {
      print('🖼️ 开始处理图片文件...');
      print('📁 图片文件: ${metadata['fileName']}');
      print('🎯 MIME 类型: ${metadata['mimeType']}');
      
      // 读取图片文件为 base64
      print('📖 开始读取图片文件字节...');
      final bytes = await file.readAsBytes();
      print('📊 图片字节数: ${bytes.length}');
      
      print('🔄 开始转换为 Base64...');
      final base64String = base64Encode(bytes);
      print('📏 Base64 长度: ${base64String.length}');
      
      final mimeType = metadata['mimeType'] as String;
      print('🎯 最终 MIME 类型: $mimeType');
      
      // 尝试获取图片尺寸
      print('📐 尝试获取图片尺寸...');
      final dimensions = await _getImageDimensions(file);
      if (dimensions != null) {
        print('📐 图片尺寸: ${dimensions['width']} x ${dimensions['height']}');
      } else {
        print('⚠️ 无法获取图片尺寸');
      }
      
      final result = FileProcessResult(
        success: true,
        fileContent: 'data:$mimeType;base64,$base64String',
        fileSize: metadata['fileSize'] as int,
        fileType: metadata['fileType'] as String,
        fileName: metadata['fileName'] as String,
        metadata: {
          ...metadata,
          'contentType': 'image',
          'base64Length': base64String.length,
          'dimensions': dimensions,
        },
      );
      
      print('✅ 图片文件处理完成');
      print('📊 处理结果元数据:');
      _printProcessResultMetadata(result.metadata);
      
      return result;
    } catch (e) {
      print('❌ 图片处理失败: $e');
      return FileProcessResult(
        success: false,
        error: '图片处理失败: $e',
        metadata: metadata,
      );
    }
  }

  /// 处理文档文件
  static Future<FileProcessResult> _processDocumentFile(File file, Map<String, dynamic> metadata) async {
    try {
      print('📄 开始处理文档文件...');
      print('📁 文档文件: ${metadata['fileName']}');
      print('📋 文件扩展名: ${metadata['fileExtension']}');
      
      final extension = metadata['fileExtension'] as String;
      
      switch (extension) {
        case '.txt':
        case '.md':
        case '.json':
        case '.xml':
        case '.csv':
        case '.doc':
        case '.docx':
          print('📝 检测到文本文件，使用通用文本提取器...');
          // 使用通用文本提取器
          final extractionResult = await _extractTextFromFile(file, metadata);
          
          // 即使提取失败，也要返回内容（可能是错误信息，但至少不是空的）
          final result = FileProcessResult(
            success: true, // 总是返回成功，让内容传递给 LLM
            fileContent: extractionResult.text,
            fileSize: metadata['fileSize'] as int,
            fileType: metadata['fileType'] as String,
            fileName: metadata['fileName'] as String,
            metadata: {
              ...metadata,
              'contentType': 'text',
              'lineCount': extractionResult.lineCount,
              'wordCount': extractionResult.wordCount,
              'extractionMethod': extractionResult.extractionMethod,
              'extractionMetadata': extractionResult.metadata,
              'extractionSuccess': extractionResult.success,
              'extractionError': extractionResult.error,
            },
          );
          
          print('✅ 文档文件处理完成');
          print('📊 处理结果元数据:');
          _printProcessResultMetadata(result.metadata);
          
          return result;
          
        case '.pdf':
          print('📄 检测到 PDF 文件...');
          // PDF 文件提取文本信息
          return await _processPdfFile(file, metadata);
          
        default:
          print('📄 未知文档类型，使用通用处理...');
          return await _processGenericFile(file, metadata);
      }
    } catch (e) {
      print('❌ 文档处理失败: $e');
      return FileProcessResult(
        success: false,
        error: '文档处理失败: $e',
        metadata: metadata,
      );
    }
  }

  /// 处理代码文件
  static Future<FileProcessResult> _processCodeFile(File file, Map<String, dynamic> metadata) async {
    try {
      print('💻 开始处理代码文件...');
      print('📁 代码文件: ${metadata['fileName']}');
      print('📋 文件扩展名: ${metadata['fileExtension']}');
      
      // 使用通用文本提取器
      final extractionResult = await _extractTextFromFile(file, metadata);
      
      final result = FileProcessResult(
        success: true, // 总是返回成功，让内容传递给 LLM
        fileContent: extractionResult.text,
        fileSize: metadata['fileSize'] as int,
        fileType: metadata['fileType'] as String,
        fileName: metadata['fileName'] as String,
        metadata: {
          ...metadata,
          'contentType': 'code',
          'language': _getProgrammingLanguage(metadata['fileExtension'] as String),
          'lineCount': extractionResult.lineCount,
          'wordCount': extractionResult.wordCount,
          'extractionMethod': extractionResult.extractionMethod,
          'extractionMetadata': extractionResult.metadata,
          'extractionSuccess': extractionResult.success,
          'extractionError': extractionResult.error,
        },
      );
      
      print('✅ 代码文件处理完成');
      print('📊 处理结果元数据:');
      _printProcessResultMetadata(result.metadata);
      
      return result;
    } catch (e) {
      print('❌ 代码文件处理失败: $e');
      return FileProcessResult(
        success: false,
        error: '代码文件处理失败: $e',
        metadata: metadata,
      );
    }
  }

  /// 处理数据文件
  static Future<FileProcessResult> _processDataFile(File file, Map<String, dynamic> metadata) async {
    try {
      print('📊 开始处理数据文件...');
      print('📁 数据文件: ${metadata['fileName']}');
      print('📋 文件扩展名: ${metadata['fileExtension']}');
      
      final extension = metadata['fileExtension'] as String;
      
      switch (extension) {
        case '.csv':
        case '.json':
        case '.xml':
          print('📊 检测到结构化数据文件，使用通用文本提取器...');
          // 使用通用文本提取器
          final extractionResult = await _extractTextFromFile(file, metadata);
          
          final result = FileProcessResult(
            success: true, // 总是返回成功，让内容传递给 LLM
            fileContent: extractionResult.text,
            fileSize: metadata['fileSize'] as int,
            fileType: metadata['fileType'] as String,
            fileName: metadata['fileName'] as String,
            metadata: {
              ...metadata,
              'contentType': 'data',
              'lineCount': extractionResult.lineCount,
              'wordCount': extractionResult.wordCount,
              'extractionMethod': extractionResult.extractionMethod,
              'extractionMetadata': extractionResult.metadata,
              'extractionSuccess': extractionResult.success,
              'extractionError': extractionResult.error,
            },
          );
          
          print('✅ 数据文件处理完成');
          print('📊 处理结果元数据:');
          _printProcessResultMetadata(result.metadata);
          
          return result;
          
        default:
          print('📊 未知数据文件类型，使用通用处理...');
          return await _processGenericFile(file, metadata);
      }
    } catch (e) {
      print('❌ 数据文件处理失败: $e');
      return FileProcessResult(
        success: false,
        error: '数据文件处理失败: $e',
        metadata: metadata,
      );
    }
  }

  /// 处理压缩文件
  static Future<FileProcessResult> _processArchiveFile(File file, Map<String, dynamic> metadata) async {
    try {
      // 对于压缩文件，我们提供文件信息而不是解压内容
      return FileProcessResult(
        success: true,
        fileContent: '压缩文件: ${metadata['fileName']} (${metadata['fileSizeFormatted']})',
        fileSize: metadata['fileSize'] as int,
        fileType: metadata['fileType'] as String,
        fileName: metadata['fileName'] as String,
        metadata: {
          ...metadata,
          'contentType': 'archive',
          'note': '压缩文件内容需要解压后才能查看',
        },
      );
    } catch (e) {
      return FileProcessResult(
        success: false,
        error: '压缩文件处理失败: $e',
        metadata: metadata,
      );
    }
  }

  /// 处理通用文件
  static Future<FileProcessResult> _processGenericFile(File file, Map<String, dynamic> metadata) async {
    try {
      // 尝试作为文本文件读取
      final content = await file.readAsString(encoding: utf8);
      return FileProcessResult(
        success: true,
        fileContent: content,
        fileSize: metadata['fileSize'] as int,
        fileType: metadata['fileType'] as String,
        fileName: metadata['fileName'] as String,
        metadata: {
          ...metadata,
          'contentType': 'text',
          'lineCount': content.split('\n').length,
        },
      );
    } catch (e) {
      // 如果无法作为文本读取，提供文件信息
      return FileProcessResult(
        success: true,
        fileContent: '二进制文件: ${metadata['fileName']} (${metadata['fileSizeFormatted']})',
        fileSize: metadata['fileSize'] as int,
        fileType: metadata['fileType'] as String,
        fileName: metadata['fileName'] as String,
        metadata: {
          ...metadata,
          'contentType': 'binary',
          'note': '无法读取二进制文件内容',
        },
      );
    }
  }

  /// 处理 CSV 文件
  static Future<FileProcessResult> _processCsvFile(File file, Map<String, dynamic> metadata) async {
    try {
      final content = await file.readAsString(encoding: utf8);
      final lines = content.split('\n');
      final headers = lines.isNotEmpty ? lines.first.split(',') : [];
      
      return FileProcessResult(
        success: true,
        fileContent: content,
        fileSize: metadata['fileSize'] as int,
        fileType: metadata['fileType'] as String,
        fileName: metadata['fileName'] as String,
        metadata: {
          ...metadata,
          'contentType': 'csv',
          'lineCount': lines.length,
          'columnCount': headers.length,
          'headers': headers,
          'dataPreview': lines.length > 1 ? lines.take(5).toList() : [],
        },
      );
    } catch (e) {
      return FileProcessResult(
        success: false,
        error: 'CSV 文件处理失败: $e',
        metadata: metadata,
      );
    }
  }

  /// 处理 JSON 文件
  static Future<FileProcessResult> _processJsonFile(File file, Map<String, dynamic> metadata) async {
    try {
      final content = await file.readAsString(encoding: utf8);
      final jsonData = jsonDecode(content);
      
      return FileProcessResult(
        success: true,
        fileContent: content,
        fileSize: metadata['fileSize'] as int,
        fileType: metadata['fileType'] as String,
        fileName: metadata['fileName'] as String,
        metadata: {
          ...metadata,
          'contentType': 'json',
          'jsonType': _getJsonType(jsonData),
          'jsonKeys': jsonData is Map ? jsonData.keys.toList() : null,
          'jsonLength': jsonData is List ? jsonData.length : null,
        },
      );
    } catch (e) {
      return FileProcessResult(
        success: false,
        error: 'JSON 文件处理失败: $e',
        metadata: metadata,
      );
    }
  }

  /// 处理 XML 文件
  static Future<FileProcessResult> _processXmlFile(File file, Map<String, dynamic> metadata) async {
    try {
      final content = await file.readAsString(encoding: utf8);
      
      return FileProcessResult(
        success: true,
        fileContent: content,
        fileSize: metadata['fileSize'] as int,
        fileType: metadata['fileType'] as String,
        fileName: metadata['fileName'] as String,
        metadata: {
          ...metadata,
          'contentType': 'xml',
          'lineCount': content.split('\n').length,
        },
      );
    } catch (e) {
      return FileProcessResult(
        success: false,
        error: 'XML 文件处理失败: $e',
        metadata: metadata,
      );
    }
  }

  /// 处理 PDF 文件（简化版本）
  static Future<FileProcessResult> _processPdfFile(File file, Map<String, dynamic> metadata) async {
    try {
      // 简化处理：提供文件信息
      return FileProcessResult(
        success: true,
        fileContent: 'PDF 文件: ${metadata['fileName']} (${metadata['fileSizeFormatted']})',
        fileSize: metadata['fileSize'] as int,
        fileType: metadata['fileType'] as String,
        fileName: metadata['fileName'] as String,
        metadata: {
          ...metadata,
          'contentType': 'pdf',
          'note': 'PDF 内容需要专门的解析库',
        },
      );
    } catch (e) {
      return FileProcessResult(
        success: false,
        error: 'PDF 文件处理失败: $e',
        metadata: metadata,
      );
    }
  }

  /// 处理 Word 文件（支持文本提取）
  static Future<FileProcessResult> _processWordFile(File file, Map<String, dynamic> metadata) async {
    try {
      print('📄 开始处理 Word 文档...');
      print('📁 Word 文件: ${metadata['fileName']}');
      print('📏 文件大小: ${metadata['fileSizeFormatted']}');
      print('📋 文件扩展名: ${metadata['fileExtension']}');
      
      // 尝试读取文件头部信息
      print('🔍 尝试读取文件头部信息...');
      final bytes = await file.openRead(0, 100).first;
      final header = String.fromCharCodes(bytes);
      print('📊 文件头部信息: ${header.substring(0, header.length > 50 ? 50 : header.length)}...');
      
      // 检查是否为有效的 Word 文档
      final isDocx = metadata['fileName'].toLowerCase().endsWith('.docx');
      final isDoc = metadata['fileName'].toLowerCase().endsWith('.doc');
      
      print('🔍 Word 文档类型检测:');
      print('  - 是否为 .docx: $isDocx');
      print('  - 是否为 .doc: $isDoc');
      
      String extractedText = '';
      bool canExtractText = false;
      Map<String, dynamic> extractionInfo = {};
      
      if (isDocx) {
        print('🔍 尝试提取 DOCX 文档文本...');
        try {
          extractedText = await _extractDocxText(file);
          canExtractText = extractedText.isNotEmpty;
          extractionInfo = {
            'extractionMethod': 'DOCX_ZIP_PARSING',
            'textLength': extractedText.length,
            'paragraphCount': extractedText.split('\n\n').length,
            'wordCount': extractedText.split(RegExp(r'\s+')).length,
          };
          print('✅ DOCX 文本提取成功');
          print('📊 提取统计:');
          print('  - 文本长度: ${extractedText.length} 字符');
          print('  - 段落数: ${extractionInfo['paragraphCount']}');
          print('  - 单词数: ${extractionInfo['wordCount']}');
        } catch (e) {
          print('⚠️ DOCX 文本提取失败: $e');
          extractedText = '无法提取 DOCX 文档文本内容';
          extractionInfo = {
            'extractionMethod': 'FAILED',
            'error': e.toString(),
          };
        }
      } else if (isDoc) {
        print('⚠️ .doc 格式暂不支持文本提取');
        extractedText = '暂不支持 .doc 格式的文本提取';
        extractionInfo = {
          'extractionMethod': 'NOT_SUPPORTED',
          'note': '需要专门的 .doc 解析库',
        };
      } else {
        print('⚠️ 未知 Word 文档格式');
        extractedText = '未知 Word 文档格式';
        extractionInfo = {
          'extractionMethod': 'UNKNOWN_FORMAT',
        };
      }
      
      // 构建最终内容
      final content = canExtractText 
          ? extractedText 
          : 'Word 文档: ${metadata['fileName']} (${metadata['fileSizeFormatted']})\n\n$extractedText';
      
      final result = FileProcessResult(
        success: true,
        fileContent: content,
        fileSize: metadata['fileSize'] as int,
        fileType: metadata['fileType'] as String,
        fileName: metadata['fileName'] as String,
        metadata: {
          ...metadata,
          'contentType': 'word',
          'wordFormat': isDocx ? 'DOCX' : isDoc ? 'DOC' : 'Unknown',
          'canExtractText': canExtractText,
          'extractionInfo': extractionInfo,
          'fileHeader': header.substring(0, header.length > 100 ? 100 : header.length),
          'suggestedLibraries': canExtractText ? [] : ['docx', 'msword', 'flutter_docx'],
        },
      );
      
      print('✅ Word 文档处理完成');
      print('📊 处理结果元数据:');
      _printProcessResultMetadata(result.metadata);
      
      return result;
    } catch (e) {
      print('❌ Word 文件处理失败: $e');
      return FileProcessResult(
        success: false,
        error: 'Word 文件处理失败: $e',
        metadata: metadata,
      );
    }
  }

  /// 提取 DOCX 文档文本（基于 ZIP 格式解析）
  static Future<String> _extractDocxText(File file) async {
    try {
      print('🔍 开始解析 DOCX 文件结构...');
      
      // 读取整个文件
      final bytes = await file.readAsBytes();
      print('📊 文件字节数: ${bytes.length}');
      
      // 检查 ZIP 文件头
      if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
        throw Exception('不是有效的 ZIP 文件格式');
      }
      print('✅ ZIP 文件头验证通过');
      
      // 简单的文本提取（基于常见的 DOCX 结构）
      String extractedText = '';
      
      // 尝试查找文档内容
      final content = String.fromCharCodes(bytes);
      
      // 查找可能的文本内容（简化方法）
      final textPatterns = [
        RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true),  // Word 文本标签
        RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true),      // 表格文本标签
        RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true),      // 段落标签
      ];
      
      for (final pattern in textPatterns) {
        final matches = pattern.allMatches(content);
        if (matches.isNotEmpty) {
          print('🔍 找到 ${matches.length} 个文本匹配');
          for (final match in matches) {
            final text = match.group(1)?.trim() ?? '';
            if (text.isNotEmpty && text.length > 1) {
              extractedText += text + ' ';
            }
          }
        }
      }
      
      // 如果没有找到结构化文本，尝试提取可读文本
      if (extractedText.isEmpty) {
        print('🔍 尝试提取可读文本...');
        final readablePattern = RegExp(r'[a-zA-Z\u4e00-\u9fff]{2,}', dotAll: true);
        final matches = readablePattern.allMatches(content);
        
        final words = <String>[];
        for (final match in matches) {
          final word = match.group(0)?.trim() ?? '';
          if (word.isNotEmpty && word.length > 1) {
            words.add(word);
          }
        }
        
        if (words.isNotEmpty) {
          extractedText = words.join(' ');
          print('📊 提取到 ${words.length} 个可读单词');
        }
      }
      
      // 清理和格式化文本
      if (extractedText.isNotEmpty) {
        extractedText = extractedText
            .replaceAll(RegExp(r'\s+'), ' ')  // 合并多个空格
            .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fff.,!?;:()]'), '')  // 保留基本标点
            .trim();
        
        print('📊 清理后文本长度: ${extractedText.length}');
        print('📄 文本预览: ${extractedText.substring(0, extractedText.length > 200 ? 200 : extractedText.length)}...');
      } else {
        extractedText = '无法从 DOCX 文件中提取文本内容';
        print('⚠️ 无法提取文本内容');
      }
      
      return extractedText;
    } catch (e) {
      print('❌ DOCX 文本提取异常: $e');
      return 'DOCX 文本提取失败: $e';
    }
  }

  /// 分析代码文件
  static Map<String, dynamic> _analyzeCodeFile(String content, String extension) {
    final lines = content.split('\n');
    final nonEmptyLines = lines.where((line) => line.trim().isNotEmpty).length;
    final commentLines = lines.where((line) => line.trim().startsWith('//') || line.trim().startsWith('/*') || line.trim().startsWith('*')).length;
    
    return {
      'totalLines': lines.length,
      'nonEmptyLines': nonEmptyLines,
      'commentLines': commentLines,
      'codeLines': nonEmptyLines - commentLines,
      'commentRatio': lines.isNotEmpty ? (commentLines / lines.length * 100).toStringAsFixed(1) : '0',
    };
  }

  /// 获取编程语言
  static String _getProgrammingLanguage(String extension) {
    final languageMap = {
      '.py': 'Python',
      '.js': 'JavaScript',
      '.ts': 'TypeScript',
      '.java': 'Java',
      '.cpp': 'C++',
      '.c': 'C',
      '.h': 'C/C++ Header',
      '.html': 'HTML',
      '.css': 'CSS',
      '.php': 'PHP',
      '.rb': 'Ruby',
      '.go': 'Go',
      '.rs': 'Rust',
      '.swift': 'Swift',
      '.kt': 'Kotlin',
    };
    
    return languageMap[extension] ?? 'Unknown';
  }

  /// 获取 JSON 类型
  static String _getJsonType(dynamic jsonData) {
    if (jsonData is Map) return 'object';
    if (jsonData is List) return 'array';
    if (jsonData is String) return 'string';
    if (jsonData is num) return 'number';
    if (jsonData is bool) return 'boolean';
    return 'null';
  }

  /// 获取图片尺寸（简化版本）
  static Future<Map<String, dynamic>?> _getImageDimensions(File file) async {
    try {
      // 这里可以集成图片处理库来获取实际尺寸
      // 目前返回 null 表示无法获取
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 检查文件类型是否支持
  static bool _isFileTypeSupported(String extension) {
    return supportedFileTypes.values.any((types) => types.contains(extension));
  }

  /// 检查文件大小是否有效
  static bool _isFileSizeValid(int size) {
    return size <= maxFileSize;
  }

  /// 获取 MIME 类型
  static String _getMimeType(String extension) {
    final mimeTypeMap = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.bmp': 'image/bmp',
      '.webp': 'image/webp',
      '.svg': 'image/svg+xml',
      '.pdf': 'application/pdf',
      '.txt': 'text/plain',
      '.json': 'application/json',
      '.xml': 'application/xml',
      '.csv': 'text/csv',
      '.md': 'text/markdown',
      '.py': 'text/x-python',
      '.js': 'application/javascript',
      '.ts': 'application/typescript',
      '.java': 'text/x-java-source',
      '.cpp': 'text/x-c++src',
      '.c': 'text/x-csrc',
      '.html': 'text/html',
      '.css': 'text/css',
      '.zip': 'application/zip',
    };
    
    return mimeTypeMap[extension] ?? 'application/octet-stream';
  }

  /// 获取文件类型分类
  static String _getFileTypeCategory(String extension) {
    for (final entry in supportedFileTypes.entries) {
      if (entry.value.contains(extension)) {
        return entry.key;
      }
    }
    return 'unknown';
  }

  /// 格式化文件大小
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 打印详细的元数据信息
  static void _printMetadataDetails(Map<String, dynamic> metadata) {
    print('📊 === 文件元数据详细信息 ===');
    print('📁 文件名: ${metadata['fileName']}');
    print('📂 文件路径: ${metadata['filePath']}');
    print('📏 文件大小: ${metadata['fileSizeFormatted']} (${metadata['fileSize']} bytes)');
    print('📋 文件扩展名: ${metadata['fileExtension']}');
    print('🎯 MIME 类型: ${metadata['mimeType']}');
    print('📅 最后修改: ${metadata['lastModified']}');
    print('📅 创建时间: ${metadata['created']}');
    print('🏷️ 文件类型分类: ${metadata['fileType']}');
    print('👁️ 是否可读: ${metadata['isReadable']}');
    print('📊 === 元数据详细信息结束 ===');
  }

  /// 打印处理结果的元数据信息
  static void _printProcessResultMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) {
      print('⚠️ 处理结果元数据为空');
      return;
    }
    
    print('📊 === 处理结果元数据 ===');
    print('📁 文件名: ${metadata['fileName']}');
    print('🏷️ 文件类型分类: ${metadata['fileType']}');
    print('📄 内容类型: ${metadata['contentType']}');
    
    // 根据内容类型打印特定信息
    switch (metadata['contentType']) {
      case 'image':
        print('🖼️ 图片信息:');
        print('  - Base64 长度: ${metadata['base64Length']}');
        if (metadata['dimensions'] != null) {
          print('  - 尺寸: ${metadata['dimensions']}');
        }
        break;
      case 'text':
        print('📝 文本信息:');
        print('  - 行数: ${metadata['lineCount']}');
        print('  - 字数: ${metadata['wordCount']}');
        break;
      case 'code':
        print('💻 代码信息:');
        print('  - 编程语言: ${metadata['language']}');
        print('  - 总行数: ${metadata['lineCount']}');
        if (metadata['codeAnalysis'] != null) {
          final analysis = metadata['codeAnalysis'] as Map<String, dynamic>;
          print('  - 代码分析:');
          print('    * 总行数: ${analysis['totalLines']}');
          print('    * 非空行: ${analysis['nonEmptyLines']}');
          print('    * 注释行: ${analysis['commentLines']}');
          print('    * 代码行: ${analysis['codeLines']}');
          print('    * 注释率: ${analysis['commentRatio']}%');
        }
        break;
      case 'csv':
        print('📊 CSV 信息:');
        print('  - 行数: ${metadata['lineCount']}');
        print('  - 列数: ${metadata['columnCount']}');
        if (metadata['headers'] != null) {
          print('  - 表头: ${metadata['headers']}');
        }
        break;
      case 'json':
        print('📋 JSON 信息:');
        print('  - JSON 类型: ${metadata['jsonType']}');
        if (metadata['jsonKeys'] != null) {
          print('  - 键列表: ${metadata['jsonKeys']}');
        }
        if (metadata['jsonLength'] != null) {
          print('  - 数组长度: ${metadata['jsonLength']}');
        }
        break;
      case 'pdf':
        print('📄 PDF 文档信息:');
        print('  - 备注: ${metadata['note']}');
        break;
      case 'word':
        print('📄 Word 文档信息:');
        print('  - 格式: ${metadata['wordFormat']}');
        print('  - 可提取文本: ${metadata['canExtractText']}');
        if (metadata['extractionInfo'] != null) {
          final info = metadata['extractionInfo'] as Map<String, dynamic>;
          print('  - 提取方法: ${info['extractionMethod']}');
          if (info['textLength'] != null) {
            print('  - 文本长度: ${info['textLength']} 字符');
          }
          if (info['paragraphCount'] != null) {
            print('  - 段落数: ${info['paragraphCount']}');
          }
          if (info['wordCount'] != null) {
            print('  - 单词数: ${info['wordCount']}');
          }
          if (info['error'] != null) {
            print('  - 提取错误: ${info['error']}');
          }
          if (info['note'] != null) {
            print('  - 备注: ${info['note']}');
          }
        }
        if (metadata['suggestedLibraries'] != null && (metadata['suggestedLibraries'] as List).isNotEmpty) {
          print('  - 建议库: ${metadata['suggestedLibraries']}');
        }
        if (metadata['fileHeader'] != null) {
          print('  - 文件头部: ${metadata['fileHeader']}');
        }
        break;
      case 'archive':
        print('📦 压缩文件信息:');
        print('  - 备注: ${metadata['note']}');
        break;
      case 'binary':
        print('🔧 二进制文件信息:');
        print('  - 备注: ${metadata['note']}');
        break;
    }
    print('📊 === 处理结果元数据结束 ===');
  }
}
