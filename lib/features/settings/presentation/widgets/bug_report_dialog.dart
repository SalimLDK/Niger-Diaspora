import 'package:flutter/material.dart';
import '../../../../core/services/support_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class BugReportDialog extends StatefulWidget {
  const BugReportDialog({super.key});

  @override
  State<BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<BugReportDialog> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  Future<void> _sendBugReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final supportService = SupportService();
    final success = await supportService.sendBugReportEmail(
      bugDescription: _descriptionController.text,
      stepsToReproduce:
          _stepsController.text.isNotEmpty ? _stepsController.text : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? l10n.bugReportEmailOpened
                : 'Impossible d\'ouvrir l\'application de messagerie',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.adaptivePrimaryColor.withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.bug_report,
                      color: context.adaptivePrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.reportBug,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.settingsBugDescLabel,
                  hintText: l10n.settingsBugDescHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.adaptivePrimaryColor),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.bugReportDescriptionRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stepsController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.stepsToReproduce,
                  hintText: '1. Ouvrir l\'application\n2. ...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.adaptivePrimaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: Text(l10n.undo),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendBugReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.adaptivePrimaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(l10n.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
