import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_html/flutter_html.dart'; // flutter_htmlをインポート
import 'package:markdown/markdown.dart' as md; // markdownをインポート
import '../../components/app_theme.dart';

class LegalDocumentPage extends StatefulWidget {
  final String title;
  final String assetPath;
  final bool isMarkdown;

  const LegalDocumentPage({
    super.key,
    required this.title,
    required this.assetPath,
    this.isMarkdown = false,
  });

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  String _documentContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final rawContent = await rootBundle.loadString(widget.assetPath);
      setState(() {
        if (widget.isMarkdown) {
          // MarkdownをHTMLに変換
          _documentContent = md.markdownToHtml(rawContent);
        } else {
          // プレーンテキストはそのまま
          _documentContent = rawContent;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('アセットファイルの読み込みに失敗: $e');
      setState(() {
        _documentContent = 'ページの読み込みに失敗しました。';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: AppTextStyles.title,
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
        leadingWidth: 105,
        leading: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.small, vertical: 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.arrow_back,
                color: AppTheme.primaryColor,
                size: AppIconSizes.small,
              ),
              SizedBox(
                width: AppSpacing.small,
              ),
              Text('戻る'),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: widget.isMarkdown
                  // flutter_htmlを使用してHTMLを表示
                  ? Html(
                      data: _documentContent,
                      style: {
                        "body": Style(
                          fontSize: FontSize(AppTextStyles.bodyFontSize),
                          color: AppTheme.primaryTextColor,
                        ),
                        "h1": Style(
                          fontSize: FontSize(AppTextStyles.h5FontSize),
                          fontWeight: FontWeight.bold,
                        ),
                        "h2": Style(
                          fontSize: FontSize(AppTextStyles.titleFontSize),
                          fontWeight: FontWeight.bold,
                        ),
                      },
                    )
                  // プレーンテキストの場合はTextウィジェット
                  : Text(
                      _documentContent,
                      style: AppTextStyles.body,
                    ),
            ),
    );
  }
}
