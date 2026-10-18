import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks for one line of text and returns it, or null if cancelled.
///
/// The dialog owns its controller and disposes it when the dialog itself is
/// gone. Disposing it as soon as showDialog returns, as callers used to, is
/// too early: the field is still on screen while the dialog animates away.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String confirm,
  String? message,
  String? hint,
  String? label,
  bool numeric = false,
  int? maxLength,
  TextDirection? textDirection,
  String? initialText,
  bool multiline = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      confirm: confirm,
      message: message,
      hint: hint,
      label: label,
      numeric: numeric,
      maxLength: maxLength,
      textDirection: textDirection,
      initialText: initialText,
      multiline: multiline,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.confirm,
    this.message,
    this.hint,
    this.label,
    this.numeric = false,
    this.maxLength,
    this.textDirection,
    this.initialText,
    this.multiline = false,
  });

  final String title;
  final String confirm;
  final String? message;
  final String? hint;
  final String? label;
  final bool numeric;
  final int? maxLength;
  final TextDirection? textDirection;
  final String? initialText;

  /// Several lines, with Enter starting a new one rather than confirming.
  final bool multiline;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxLength,
            textDirection: widget.textDirection,
            keyboardType: widget.numeric
                ? TextInputType.number
                : widget.multiline
                ? TextInputType.multiline
                : null,
            minLines: widget.multiline ? 3 : null,
            maxLines: widget.multiline ? 8 : 1,
            inputFormatters: widget.numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
            decoration: InputDecoration(
              hintText: widget.hint,
              labelText: widget.label,
              border: widget.label == null ? null : const OutlineInputBorder(),
            ),
            onSubmitted: widget.multiline ? null : (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirm)),
      ],
    );
  }
}
