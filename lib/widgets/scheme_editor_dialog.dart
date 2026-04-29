import 'package:flutter/material.dart';

import '../data/app_constants.dart';
import '../models/scheme.dart';

class SchemeEditorDialog extends StatefulWidget {
  final Scheme? initial;

  const SchemeEditorDialog({super.key, this.initial});

  @override
  State<SchemeEditorDialog> createState() => _SchemeEditorDialogState();
}

class _SchemeEditorDialogState extends State<SchemeEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late SchemeType _type;
  late String _name;
  late String _description;
  late String _applyLink;
  late String _deadline;
  late String _state;
  late String _benefitsText;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _type        = initial?.type ?? SchemeType.state;
    _name        = initial?.name ?? '';
    _description = initial?.description ?? '';
    _applyLink   = initial?.applyLink ?? '';
    _deadline    = initial?.deadline ?? '';
    // Default to first state if no initial value
    _state       = (initial?.state.trim().isNotEmpty == true)
        ? initial!.state
        : kIndianStates.first;
    _benefitsText = (initial?.benefits ?? const []).join('\n');
  }

  List<String> _parseBenefits(String raw) {
    final parts = raw.split(RegExp(r'[,\\n]'));
    return parts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Scheme' : 'Add Scheme'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              DropdownButtonFormField<SchemeType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Scheme Type',
                  prefixIcon: Icon(Icons.category),
                ),
                items: const [
                  DropdownMenuItem(
                    value: SchemeType.state,
                    child: Text('State'),
                  ),
                  DropdownMenuItem(
                    value: SchemeType.central,
                    child: Text('Central'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _type = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(
                  labelText: 'Scheme Name',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Scheme name is required';
                  return null;
                },
                onChanged: (v) => _name = v,
              ),
              const SizedBox(height: 12),
              if (_type == SchemeType.state) ...[
                DropdownButtonFormField<String>(
                  value: kIndianStates.contains(_state)
                      ? _state
                      : kIndianStates.first,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  items: kIndianStates
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'State is required for State schemes';
                    }
                    return null;
                  },
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _state = v);
                  },
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(
                  labelText: 'Description (Basic Info)',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Description is required';
                  return null;
                },
                onChanged: (v) => _description = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _benefitsText,
                decoration: const InputDecoration(
                  labelText: 'Benefits (one per line or comma-separated)',
                  prefixIcon: Icon(Icons.list_alt),
                ),
                maxLines: 4,
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Benefits are required';
                  return null;
                },
                onChanged: (v) => _benefitsText = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _applyLink,
                decoration: const InputDecoration(
                  labelText: 'Application Link (URL)',
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Application link is required';
                  return null;
                },
                onChanged: (v) => _applyLink = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _deadline,
                decoration: const InputDecoration(
                  labelText: 'Last Date',
                  prefixIcon: Icon(Icons.date_range),
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Last date is required';
                  return null;
                },
                onChanged: (v) => _deadline = v,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final ok = _formKey.currentState?.validate() ?? false;
            if (!ok) return;

            final initial = widget.initial;
            final id = initial?.id ??
                DateTime.now().microsecondsSinceEpoch.toString();

            final updated = Scheme(
              id: id,
              name: _name.trim(),
              type: _type,
              state: _type == SchemeType.state ? _state.trim() : '',
              category: initial?.category ?? 'subsidy', // Fallback for new schemes
              description: _description.trim(),
              benefits: _parseBenefits(_benefitsText),
              eligibility: initial?.eligibility ?? [],
              documents: initial?.documents ?? [],
              applyLink: _applyLink.trim(),
              deadline: _deadline.trim(),
              isAiGenerated: initial?.isAiGenerated ?? false,
              approved: initial?.approved ?? true,
            );
            Navigator.pop(context, updated);
          },
          child: Text(isEditing ? 'Save Changes' : 'Add Scheme'),
        ),
      ],
    );
  }
}

