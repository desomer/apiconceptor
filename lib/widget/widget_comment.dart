import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/start_core.dart';

const List<String> commentColorNames = [
  'none',
  'red',
  'yellow',
  'orange',
  'green',
];

Color commentColorFromName(String name) {
  switch (name) {
    case 'none':
      return Colors.transparent;
    case 'red':
      return Colors.red;
    case 'yellow':
      return Colors.yellow;
    case 'green':
      return Colors.green;
    case 'orange':
    default:
      return Colors.orange;
  }
}

class Reaction {
  final String emoji;
  int count;
  bool reactedByMe;

  Reaction({required this.emoji, this.count = 0, this.reactedByMe = false});

  Map<String, dynamic> toJson() => {'emoji': emoji, 'count': count};

  factory Reaction.fromJson(Map<String, dynamic> json) => Reaction(
    emoji: json['emoji'] as String,
    count: (json['count'] as num?)?.toInt() ?? 0,
  );
}

class Comment {
  final String id;
  final String author;
  final String text;
  final DateTime date;
  final String color;
  final List<Reaction> reactions;
  final List<Comment> replies;

  Comment({
    required this.id,
    required this.author,
    required this.text,
    required this.date,
    this.color = 'none',
    this.reactions = const [],
    this.replies = const [],
  });

  Comment copyWith({
    String? text,
    String? color,
    List<Reaction>? reactions,
    List<Comment>? replies,
  }) {
    return Comment(
      id: id,
      author: author,
      text: text ?? this.text,
      date: date,
      color: color ?? this.color,
      reactions: reactions ?? this.reactions,
      replies: replies ?? this.replies,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': author,
    'text': text,
    'date': date.toIso8601String(),
    'color': color,
    'reactions': reactions.map((r) => r.toJson()).toList(),
    'replies': replies.map((r) => r.toJson()).toList(),
  };

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String,
    author: json['author'] as String,
    text: json['text'] as String,
    date: DateTime.parse(json['date'] as String),
    color: (json['color'] as String?) ?? 'none',
    reactions:
        (json['reactions'] as List? ?? [])
            .map((r) => Reaction.fromJson(r as Map<String, dynamic>))
            .toList(),
    replies:
        (json['replies'] as List? ?? [])
            .map((r) => Comment.fromJson(r as Map<String, dynamic>))
            .toList(),
  );
}

class ThreadCommentCell extends StatefulWidget {
  final Widget childOver;
  final Widget childIfComment;
  final List<Comment> initialComments;
  final String contextId;

  const ThreadCommentCell({
    super.key,
    required this.childOver,
    required this.childIfComment,
    this.initialComments = const [],
    required this.contextId,
  });

  @override
  State<ThreadCommentCell> createState() => _ThreadCommentCellState();
}

class _ThreadCommentCellState extends State<ThreadCommentCell> {
  late List<Comment> comments;

  @override
  void initState() {
    super.initState();
    comments = [...widget.initialComments];
    if (widget.contextId.isNotEmpty) {
      bddStorage.getComments(widget.contextId).then((loaded) {
        if (mounted) setState(() => comments = loaded);
      });
    }
  }

  void _openPopup() {
    showDialog(
      context: context,
      builder:
          (_) => CommentThreadPopup(
            comments: comments,
            contextId: widget.contextId,
            onUpdate: (updated) => setState(() => comments = updated),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastCommentColorName =
        comments.isNotEmpty ? comments.last.color : 'none';
    final hasLastCommentColor = lastCommentColorName != 'none';
    final lastCommentColor = commentColorFromName(lastCommentColorName);

    return GestureDetector(
      onTap: _openPopup,
      child: Container(
        color: hasLastCommentColor ? lastCommentColor : Colors.transparent,
        child: Stack(
          children: [
            if (comments.isEmpty) widget.childOver,
            if (comments.isNotEmpty) widget.childIfComment,
            // if (comments.isNotEmpty)
            //   Positioned(
            //     right: 2,
            //     top: 2,
            //     child: Container(
            //       width: 10,
            //       height: 10,
            //       decoration: const BoxDecoration(
            //         color: Colors.orange,
            //         shape: BoxShape.circle,
            //       ),
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }
}

class CommentThreadPopup extends StatefulWidget {
  final List<Comment> comments;
  final void Function(List<Comment>) onUpdate;
  final String contextId;

  const CommentThreadPopup({
    super.key,
    required this.comments,
    required this.onUpdate,
    this.contextId = '',
  });

  @override
  State<CommentThreadPopup> createState() => _CommentThreadPopupState();
}

class _CommentThreadPopupState extends State<CommentThreadPopup> {
  final newCommentCtrl = TextEditingController();
  String newCommentColor = 'none';

  bool get _canPublish =>
      newCommentCtrl.text.trim().isNotEmpty || newCommentColor != 'none';

  @override
  void initState() {
    super.initState();
    newCommentCtrl.addListener(_onDraftChanged);
  }

  @override
  void dispose() {
    newCommentCtrl.removeListener(_onDraftChanged);
    newCommentCtrl.dispose();
    super.dispose();
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  void _addComment() {
    if (!_canPublish) return;

    final newComment = Comment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: currentCompany.shortUserId,
      text: newCommentCtrl.text.trim(),
      date: DateTime.now(),
      color: newCommentColor,
      reactions: [
        Reaction(emoji: "👍"),
        Reaction(emoji: "❤️"),
        Reaction(emoji: "😂"),
      ],
      replies: [],
    );

    setState(() {
      widget.comments.add(newComment);
    });

    widget.onUpdate(widget.comments);
    if (widget.contextId.isNotEmpty) {
      bddStorage.saveComment(widget.contextId, newComment);
    }
    newCommentCtrl.clear();
    setState(() {
      newCommentColor = 'none';
    });
  }

  void _deleteComment(String id) {
    setState(() {
      widget.comments.removeWhere((c) => c.id == id);
    });
    widget.onUpdate(widget.comments);
    if (widget.contextId.isNotEmpty) {
      bddStorage.deleteComment(widget.contextId, id);
    }
  }

  Future<void> _handleClose() async {
    if (!_canPublish) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final shouldClose =
        await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text("Discard draft?"),
                content: const Text(
                  "You have a draft comment or selected color. Close anyway?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Close"),
                  ),
                ],
              ),
        ) ??
        false;

    if (shouldClose && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Comments"),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children:
                    widget.comments.map((c) {
                      return CommentThreadItem(
                        comment: c,
                        onUpdate: (updated) {
                          setState(() {
                            final index = widget.comments.indexWhere(
                              (x) => x.id == updated.id,
                            );
                            widget.comments[index] = updated;
                          });
                          widget.onUpdate(widget.comments);
                          if (widget.contextId.isNotEmpty) {
                            bddStorage.saveComment(widget.contextId, updated);
                          }
                        },
                        onDelete: () => _deleteComment(c.id),
                      );
                    }).toList(),
              ),
            ),
            TextField(
              controller: newCommentCtrl,
              decoration: const InputDecoration(
                hintText: "Add a comment...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children:
                  commentColorNames.map((name) {
                    final color = commentColorFromName(name);
                    return ChoiceChip(
                      label: Text(name == 'none' ? 'no color' : name),
                      selected: newCommentColor == name,
                      selectedColor:
                          name == 'none'
                              ? Colors.grey.shade700
                              : color.withValues(alpha: 0.35),
                      onSelected: (_) {
                        setState(() {
                          newCommentColor = name;
                        });
                      },
                    );
                  }).toList(),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: _canPublish ? _addComment : null,
          child: const Text("Publish"),
        ),
        TextButton(onPressed: _handleClose, child: const Text("Close")),
      ],
    );
  }
}

class CommentThreadItem extends StatefulWidget {
  final Comment comment;
  final void Function(Comment) onUpdate;
  final VoidCallback? onDelete;

  const CommentThreadItem({
    super.key,
    required this.comment,
    required this.onUpdate,
    this.onDelete,
  });

  @override
  State<CommentThreadItem> createState() => _CommentThreadItemState();
}

class _CommentThreadItemState extends State<CommentThreadItem> {
  final replyCtrl = TextEditingController();
  final editCtrl = TextEditingController();
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    editCtrl.text = widget.comment.text;
  }

  @override
  void didUpdateWidget(covariant CommentThreadItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isEditing && oldWidget.comment.text != widget.comment.text) {
      editCtrl.text = widget.comment.text;
    }
  }

  @override
  void dispose() {
    replyCtrl.dispose();
    editCtrl.dispose();
    super.dispose();
  }

  void _updateCommentColor(String color) {
    widget.onUpdate(widget.comment.copyWith(color: color));
  }

  void _startEdit() {
    setState(() {
      editCtrl.text = widget.comment.text;
      isEditing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      editCtrl.text = widget.comment.text;
      isEditing = false;
    });
  }

  void _saveEdit() {
    final updatedText = editCtrl.text.trim();
    if (updatedText.isEmpty) return;
    widget.onUpdate(widget.comment.copyWith(text: updatedText));
    setState(() {
      isEditing = false;
    });
  }

  void _toggleReaction(Reaction r) {
    setState(() {
      if (r.reactedByMe) {
        r.count--;
      } else {
        r.count++;
      }
      r.reactedByMe = !r.reactedByMe;
    });

    widget.onUpdate(widget.comment.copyWith());
  }

  void _addReply() {
    if (replyCtrl.text.trim().isEmpty) return;

    final reply = Comment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: currentCompany.shortUserId,
      text: replyCtrl.text.trim(),
      date: DateTime.now(),
      color: 'none',
      reactions: [
        Reaction(emoji: "👍"),
        Reaction(emoji: "❤️"),
        Reaction(emoji: "😂"),
      ],
      replies: [],
    );

    final updatedReplies = [...widget.comment.replies, reply];

    widget.onUpdate(widget.comment.copyWith(replies: updatedReplies));
    replyCtrl.clear();
  }

  void _deleteReply(String replyId) {
    final updatedReplies =
        widget.comment.replies.where((r) => r.id != replyId).toList();
    widget.onUpdate(widget.comment.copyWith(replies: updatedReplies));
  }

  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final hasColor = c.color != 'none';
    final commentColor = commentColorFromName(c.color);
    final commentBackground =
        hasColor ? commentColor.withOpacity(0.12) : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: commentBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              hasColor ? commentColor.withOpacity(0.7) : Colors.grey.shade700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${c.author} • ${dateFormat.format(c.date)}"),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isEditing)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: Colors.blue.shade300,
                      tooltip: "Edit",
                      onPressed: _startEdit,
                    ),
                  if (isEditing)
                    TextButton(onPressed: _saveEdit, child: const Text("Save")),
                  if (isEditing)
                    TextButton(
                      onPressed: _cancelEdit,
                      child: const Text("Cancel"),
                    ),
                  if (widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: Colors.red.shade300,
                      tooltip: "Delete",
                      onPressed: widget.onDelete,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (!isEditing) Text(c.text),
          if (isEditing)
            TextField(
              controller: editCtrl,
              minLines: 1,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: "Edit comment...",
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children:
                commentColorNames.map((name) {
                  final color = commentColorFromName(name);
                  return ChoiceChip(
                    label: Text(name == 'none' ? 'no color' : name),
                    selected: c.color == name,
                    selectedColor:
                        name == 'none'
                            ? Colors.grey.shade700
                            : color.withOpacity(0.35),
                    onSelected: (_) => _updateCommentColor(name),
                  );
                }).toList(),
          ),

          // Réactions
          Row(
            children:
                c.reactions.map((r) {
                  return GestureDetector(
                    onTap: () => _toggleReaction(r),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6, top: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            r.reactedByMe
                                ? Colors.blue.shade400
                                : Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("${r.emoji} ${r.count}"),
                    ),
                  );
                }).toList(),
          ),

          // Réponses
          if (c.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 10),
              child: Column(
                children:
                    c.replies.map((reply) {
                      return CommentThreadItem(
                        comment: reply,
                        onUpdate: (updatedReply) {
                          final updatedReplies =
                              c.replies.map((r) {
                                return r.id == updatedReply.id
                                    ? updatedReply
                                    : r;
                              }).toList();
                          widget.onUpdate(c.copyWith(replies: updatedReplies));
                        },
                        onDelete: () => _deleteReply(reply.id),
                      );
                    }).toList(),
              ),
            ),

          // Champ de réponse
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 10),
            child: Column(
              children: [
                TextField(
                  controller: replyCtrl,
                  decoration: const InputDecoration(
                    hintText: "Reply...",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: _addReply,
                  child: const Text("Reply"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
