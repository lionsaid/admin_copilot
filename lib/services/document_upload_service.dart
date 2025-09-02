import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../models/knowledge_base.dart';
import '../services/database_service.dart';

class DocumentUploadService {
  // 支持的文件类型
  static const Map<String, List<String>> supportedFileTypes = {
    'document': ['.pdf', '.docx', '.doc', '.txt', '.md'],
    'spreadsheet': ['.csv', '.xlsx', '.xls'],
    'presentation': ['.pptx', '.ppt'],
  };

  // 选择并上传文档
  static Future<List<File>> pickDocuments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedFileTypes.values.expand((e) => e).toList(),
        allowMultiple: true,
      );

      if (result != null) {
        return result.paths
            .where((path) => path != null)
            .map((path) => File(path!))
            .toList();
      }
      return [];
    } catch (e) {
      print('选择文档失败: $e');
      return [];
    }
  }

  // 处理文档并分块
  static Future<List<DocumentChunk>> processDocument(
    File file,
    int knowledgeBaseId,
  ) async {
    try {
      final fileName = path.basename(file.path);
      final fileExtension = path.extension(fileName).toLowerCase();
      
      // 根据文件类型选择处理方法
      String content;
      switch (fileExtension) {
        case '.txt':
        case '.md':
          content = await file.readAsString();
          break;
        case '.csv':
          content = await _processCsvFile(file);
          break;
        case '.pdf':
        case '.docx':
        case '.doc':
        case '.xlsx':
        case '.xls':
        case '.pptx':
        case '.ppt':
          // 对于复杂格式，先保存文件路径，后续可以集成专门的解析库
          content = await _extractTextFromComplexFile(file);
          break;
        default:
          throw Exception('不支持的文件类型: $fileExtension');
      }

      // 保存文档记录
      final documentId = await DatabaseService.insertDocument({
        'kb_id': knowledgeBaseId,
        'title': fileName,
        'source_path': file.path,
        'mime_type': _getMimeType(fileExtension),
      });

      // 分块处理
      final chunks = _splitContentIntoChunks(content, documentId, knowledgeBaseId);
      
      // 批量保存分块
      await DatabaseService.insertChunks(chunks.map((chunk) => chunk.toJson()).toList());

      return chunks;
    } catch (e) {
      print('处理文档失败: $e');
      rethrow;
    }
  }

  // 处理 CSV 文件
  static Future<String> _processCsvFile(File file) async {
    final lines = await file.readAsLines();
    if (lines.isEmpty) return '';
    
    final headers = lines.first.split(',');
    final dataRows = lines.skip(1);
    
    final processedRows = dataRows.map((row) {
      final values = row.split(',');
      final rowMap = <String, String>{};
      for (int i = 0; i < headers.length && i < values.length; i++) {
        rowMap[headers[i].trim()] = values[i].trim();
      }
      return rowMap.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    });
    
    return '${headers.join(', ')}\n${processedRows.join('\n')}';
  }

  // 从复杂文件中提取文本（占位实现）
  static Future<String> _extractTextFromComplexFile(File file) async {
    // TODO: 集成专门的解析库
    // 例如：pdf_text for PDF, docx for Word, excel for Excel
    final fileName = path.basename(file.path);
    return '文件内容提取功能待实现: $fileName\n\n请等待后续版本更新，或先使用 .txt 格式的文档。';
  }

  // 获取 MIME 类型
  static String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.doc':
        return 'application/msword';
      case '.txt':
        return 'text/plain';
      case '.md':
        return 'text/markdown';
      case '.csv':
        return 'text/csv';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.ppt':
        return 'application/vnd.ms-powerpoint';
      default:
        return 'application/octet-stream';
    }
  }

  // 将内容分块
  static List<DocumentChunk> _splitContentIntoChunks(
    String content,
    int documentId,
    int knowledgeBaseId,
  ) {
    const int maxChunkSize = 1000; // 每个分块最大字符数
    const int overlapSize = 200; // 分块重叠字符数
    
    final chunks = <DocumentChunk>[];
    int startIndex = 0;
    int chunkIndex = 0;
    
    while (startIndex < content.length) {
      int endIndex = startIndex + maxChunkSize;
      
      // 如果不是最后一个分块，尝试在句子边界分割
      if (endIndex < content.length) {
        // 寻找最近的句子结束符
        final sentenceEndings = ['. ', '! ', '? ', '\n\n', '\n'];
        int bestEndIndex = endIndex;
        
        for (final ending in sentenceEndings) {
          final lastIndex = content.lastIndexOf(ending, endIndex);
          if (lastIndex > startIndex && lastIndex < endIndex) {
            bestEndIndex = lastIndex + ending.length;
            break;
          }
        }
        
        endIndex = bestEndIndex;
      }
      
      final chunkContent = content.substring(startIndex, endIndex).trim();
      if (chunkContent.isNotEmpty) {
        chunks.add(DocumentChunk(
          id: null,
          kbId: knowledgeBaseId,
          docId: documentId,
          chunkIndex: chunkIndex,
          content: chunkContent,
          embedding: null,
        ));
        chunkIndex++;
      }
      
      // 计算下一个分块的起始位置（考虑重叠）
      startIndex = endIndex - overlapSize;
      if (startIndex >= content.length) break;
    }
    
    return chunks;
  }
}

// 文档分块模型
class DocumentChunk {
  final int? id;
  final int kbId;
  final int docId;
  final int chunkIndex;
  final String content;
  final Uint8List? embedding;

  DocumentChunk({
    this.id,
    required this.kbId,
    required this.docId,
    required this.chunkIndex,
    required this.content,
    this.embedding,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kb_id': kbId,
      'doc_id': docId,
      'chunk_index': chunkIndex,
      'content': content,
      'embedding': embedding,
    };
  }

  factory DocumentChunk.fromJson(Map<String, dynamic> json) {
    return DocumentChunk(
      id: json['id'],
      kbId: json['kb_id'],
      docId: json['doc_id'],
      chunkIndex: json['chunk_index'],
      content: json['content'],
      embedding: json['embedding'] as Uint8List?,
    );
  }
}
