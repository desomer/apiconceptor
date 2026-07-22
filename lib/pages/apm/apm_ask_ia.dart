import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:jsonschema/widget/editor/mark_down_editor.dart';

import 'package:jsonschema/pages/router_generic_page.dart';

class ApmAskIA extends GenericPageStateless {
  const ApmAskIA({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ApmAskIAView();
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    GlobalKey keyPage,
    PageInit? pageInit,
  ) {
    return NavigationInfo();
  }
}

class _ApmAskIAView extends StatefulWidget {
  const _ApmAskIAView();

  @override
  State<_ApmAskIAView> createState() => _ApmAskIAViewState();
}

class _ApmAskIAViewState extends State<_ApmAskIAView> {
  static const String _endpoint = 'http://localhost:3128/rag/query';
  static const String _reindexEndpoint = 'http://localhost:3128/rag/reindex';

  final TextEditingController _questionController = TextEditingController();
  final FocusNode _questionFocusNode = FocusNode();
  final ScrollController _historyScrollController = ScrollController();

  bool _loading = false;
  bool _reindexLoading = false;
  String? _lastError;
  final List<_ChatTurn> _history = <_ChatTurn>[];

  @override
  void dispose() {
    _questionController.dispose();
    _questionFocusNode.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion() async {
    final rawQuestion = _questionController.text;
    final question = rawQuestion.trim();
    if (question.isEmpty || _loading) {
      return;
    }

    setState(() {
      _loading = true;
      _lastError = null;
    });

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 20),
          headers: const <String, String>{'Content-Type': 'application/json'},
        ),
      );

      final response = await dio.post<dynamic>(
        _endpoint,
        data: <String, dynamic>{'question': question},
      );

      final payload = response.data;
      if (payload is! Map) {
        throw const FormatException('La reponse IA n est pas un objet JSON');
      }

      final map = Map<String, dynamic>.from(payload);
      final answer = (map['answer'] ?? '').toString();
      final matchesRaw = map['matches'];
      final matches = matchesRaw is List
          ? List<dynamic>.from(matchesRaw)
          : <dynamic>[];

      setState(() {
        _history.add(
          _ChatTurn(
            question: question,
            answer: answer,
            matches: matches,
            timestamp: DateTime.now(),
          ),
        );
        _questionController.clear();
      });

      _scrollToBottom();
    } on DioException catch (e) {
      final serverMessage = e.response?.data;
      setState(() {
        _lastError = serverMessage == null
            ? (e.message ?? 'Erreur reseau')
            : 'HTTP ${e.response?.statusCode}: $serverMessage';
      });
    } catch (e) {
      setState(() {
        _lastError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _reindexKnowledge() async {
    if (_reindexLoading) {
      return;
    }

    setState(() {
      _reindexLoading = true;
      _lastError = null;
    });

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 20),
          headers: const <String, String>{'Content-Type': 'application/json'},
        ),
      );

      final response = await dio.post<dynamic>(_reindexEndpoint);
      final payload = response.data;
      if (payload is! Map) {
        throw const FormatException(
          'La reponse reindex n est pas un objet JSON',
        );
      }

      final map = Map<String, dynamic>.from(payload);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Reindex result'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildResultLine('status', map['status']),
                  _buildResultLine('files', map['files']),
                  _buildResultLine('changedFiles', map['changedFiles']),
                  _buildResultLine('removedFiles', map['removedFiles']),
                  _buildResultLine('indexedChunks', map['indexedChunks']),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } on DioException catch (e) {
      final serverMessage = e.response?.data;
      setState(() {
        _lastError = serverMessage == null
            ? (e.message ?? 'Erreur reseau pendant reindex')
            : 'HTTP ${e.response?.statusCode}: $serverMessage';
      });
    } catch (e) {
      setState(() {
        _lastError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _reindexLoading = false;
        });
      }
    }
  }

  Widget _buildResultLine(String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$key: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: '${value ?? '-'}'),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_historyScrollController.hasClients) return;
      _historyScrollController.animateTo(
        _historyScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text('Ask IA (RAG)', style: theme.textTheme.titleLarge),
              const SizedBox(width: 12),
              SelectableText(
                _endpoint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: (_loading || _reindexLoading)
                    ? null
                    : _reindexKnowledge,
                icon: _reindexLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Reindex'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: (_loading || _reindexLoading)
                    ? null
                    : () {
                        _questionController.clear();
                        setState(() {
                          _lastError = null;
                        });
                      },
                icon: const Icon(Icons.clear),
                label: const Text('Clear editor'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (_loading || _reindexLoading) ? null : _sendQuestion,
                icon: _loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Send'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 5, child: _buildEditorPanel(theme)),
                const SizedBox(width: 12),
                Expanded(flex: 7, child: _buildHistoryPanel(theme)),
              ],
            ),
          ),
          if (_lastError != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _lastError!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditorPanel(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: MarkDownEditor(
          controller: _questionController,
          focusNode: _questionFocusNode,
          context: context,
        ),
      ),
    );
  }

  Widget _buildHistoryPanel(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: _history.isEmpty
          ? Center(
              child: Text(
                'Aucun echange pour le moment',
                style: theme.textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              controller: _historyScrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final turn = _history[index];
                return _buildTurnCard(turn, theme);
              },
            ),
    );
  }

  Widget _buildTurnCard(_ChatTurn turn, ThemeData theme) {
    final matchesPretty = const JsonEncoder.withIndent(
      '  ',
    ).convert(turn.matches);
    final dateLabel =
        '${turn.timestamp.hour.toString().padLeft(2, '0')}:${turn.timestamp.minute.toString().padLeft(2, '0')}:${turn.timestamp.second.toString().padLeft(2, '0')}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Question', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(dateLabel, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            MarkdownWidget(
              data: turn.question,
              config: MarkdownConfig.darkConfig,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            ),
            const Divider(height: 18),
            Text('Answer', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            MarkdownWidget(
              data: turn.answer.isEmpty ? '_Aucune reponse_' : turn.answer,
              config: MarkdownConfig.darkConfig,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            ),
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text('matches (${turn.matches.length})'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.25,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(matchesPretty),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTurn {
  const _ChatTurn({
    required this.question,
    required this.answer,
    required this.matches,
    required this.timestamp,
  });

  final String question;
  final String answer;
  final List<dynamic> matches;
  final DateTime timestamp;
}
