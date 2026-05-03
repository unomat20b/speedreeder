import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/feedback_api.dart';

Future<void> showFeedbackDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => const _FeedbackDialogBody(),
  );
}

class _FeedbackDialogBody extends StatefulWidget {
  const _FeedbackDialogBody();

  @override
  State<_FeedbackDialogBody> createState() => _FeedbackDialogBodyState();
}

class _FeedbackDialogBodyState extends State<_FeedbackDialogBody> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    final result = await FeedbackApi.submit(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      message: _messageCtrl.text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!result.ok) {
      final m = result.message;
      final text = m != null && m.startsWith('http_')
          ? 'feedback_error_http'.tr(namedArgs: {'code': m.substring(5)})
          : 'feedback_error'.tr();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text('feedback_success'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('feedback_title'.tr()),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'feedback_name'.tr(),
                  hintText: 'feedback_name_hint'.tr(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: InputDecoration(
                  labelText: 'feedback_email'.tr(),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'feedback_email_required'.tr();
                  if (!t.contains('@')) return 'feedback_email_invalid'.tr();
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageCtrl,
                decoration: InputDecoration(
                  labelText: 'feedback_message'.tr(),
                  alignLabelWithHint: true,
                ),
                minLines: 4,
                maxLines: 8,
                validator: (v) {
                  if ((v?.trim() ?? '').isEmpty) {
                    return 'feedback_message_required'.tr();
                  }
                  return null;
                },
                textInputAction: TextInputAction.newline,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text('feedback_cancel'.tr()),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('feedback_send'.tr()),
        ),
      ],
    );
  }
}
