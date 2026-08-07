import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/local/tables/categories_table.dart';
import '../books/books_providers.dart' show categoryRepositoryProvider;
import 'categories_page.dart' show categoriesViewModelProvider;

/// 新建/编辑分类（Spec §3.3 / BK-P0-003）
class CategoryEditSheet extends ConsumerStatefulWidget {
  const CategoryEditSheet({super.key, this.category});

  final Category? category;

  static Future<void> show(BuildContext context, {Category? category}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CategoryEditSheet(category: category),
      ),
    );
  }

  @override
  ConsumerState<CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<CategoryEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late CategoryKind _kind;
  late int _colorIndex;
  bool _saving = false;

  static const _palette = [
    0xFFFF7043, 0xFFFFB300, 0xFF66BB6A, 0xFF26C6DA, //
    0xFF42A5F5, 0xFF7E57C2, 0xFFEC407A, 0xFF8D6E63,
  ];

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _kind = category?.kind ?? CategoryKind.expense;
    _colorIndex = _palette.indexWhere((c) => c == category?.color);
    if (_colorIndex < 0) _colorIndex = 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(categoryRepositoryProvider);
    try {
      if (widget.category == null) {
        await repo.createCategory(
          name: _nameController.text.trim(),
          icon: 'tag',
          color: _palette[_colorIndex],
          kind: _kind,
        );
      } else {
        await repo.updateCategory(widget.category!.id,
            name: _nameController.text.trim(), color: _palette[_colorIndex]);
      }
      ref.invalidate(categoriesViewModelProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.category == null ? '新建分类' : '编辑分类',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '分类名称'),
              validator: (v) {
                final name = v?.trim() ?? '';
                if (name.isEmpty) return '请输入分类名称';
                if (name.length > 20) return '名称不能超过 20 字';
                return null;
              },
            ),
            const SizedBox(height: 12),
            if (widget.category == null)
              SegmentedButton<CategoryKind>(
                segments: const [
                  ButtonSegment(value: CategoryKind.expense, label: Text('支出')),
                  ButtonSegment(value: CategoryKind.income, label: Text('收入')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
            const SizedBox(height: 12),
            // 审查 U-7：颜色选择触控目标 ≥48dp；小屏溢出改 Wrap 自动换行
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var i = 0; i < _palette.length; i++)
                  Semantics(
                    button: true,
                    label: '颜色 ${i + 1}',
                    selected: _colorIndex == i,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _colorIndex = i);
                      },
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(_palette[i]),
                            child: _colorIndex == i
                                ? const Icon(Icons.check, size: 18, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}
