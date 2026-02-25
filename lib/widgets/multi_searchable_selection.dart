import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

class MultiSearchableSelection<T> extends StatefulWidget {
  final String label;
  final List<T> selectedItems;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String Function(T)? subLabelBuilder;
  final String? Function(T)? photoUrlBuilder;
  final void Function(List<T>) onChanged;
  final String hintText;
  final bool isLoading;

  const MultiSearchableSelection({
    super.key,
    required this.label,
    required this.selectedItems,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.subLabelBuilder,
    this.photoUrlBuilder,
    this.hintText = 'Selecionar alunos...',
    this.isLoading = false,
  });

  @override
  State<MultiSearchableSelection<T>> createState() =>
      _MultiSearchableSelectionState<T>();
}

class _MultiSearchableSelectionState<T>
    extends State<MultiSearchableSelection<T>> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.lato(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: widget.isLoading ? null : _openSelectionModal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.selectedItems.isNotEmpty
                        ? '${widget.selectedItems.length} selecionado(s)'
                        : widget.hintText,
                    style: TextStyle(
                      color: widget.selectedItems.isNotEmpty
                          ? Colors.black87
                          : Colors.grey[700],
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryRed),
                  )
                else
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _MultiSelectionSheet<T>(
        items: widget.items,
        labelBuilder: widget.labelBuilder,
        subLabelBuilder: widget.subLabelBuilder,
        photoUrlBuilder: widget.photoUrlBuilder,
        initialSelection: widget.selectedItems,
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _MultiSelectionSheet<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) labelBuilder;
  final String Function(T)? subLabelBuilder;
  final String? Function(T)? photoUrlBuilder;
  final List<T> initialSelection;
  final ValueChanged<List<T>> onChanged;

  const _MultiSelectionSheet({
    required this.items,
    required this.labelBuilder,
    this.subLabelBuilder,
    this.photoUrlBuilder,
    required this.initialSelection,
    required this.onChanged,
  });

  @override
  State<_MultiSelectionSheet<T>> createState() =>
      _MultiSelectionSheetState<T>();
}

class _MultiSelectionSheetState<T> extends State<_MultiSelectionSheet<T>> {
  late List<T> _filteredItems;
  late List<T> _tempSelectedItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _tempSelectedItems = List.from(widget.initialSelection);
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          final label = widget.labelBuilder(item).toLowerCase();
          return label.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _toggleSelection(T item) {
    setState(() {
      if (_tempSelectedItems.contains(item)) {
        _tempSelectedItems.remove(item);
      } else {
        _tempSelectedItems.add(item);
      }
    });
    widget.onChanged(_tempSelectedItems);
  }

  void _selectAll() {
    setState(() {
      if (_tempSelectedItems.length == widget.items.length) {
        _tempSelectedItems.clear();
      } else {
        _tempSelectedItems = List.from(widget.items);
      }
    });
    widget.onChanged(_tempSelectedItems);
  }

  @override
  Widget build(BuildContext context) {
    final isAllSelected = _tempSelectedItems.length == widget.items.length &&
        widget.items.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle Bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Pesquisar...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: _filter,
              ),
            ),

            // Selecionar Todos
            CheckboxListTile(
              title: Text(
                'Selecionar Todos',
                style: GoogleFonts.lato(fontWeight: FontWeight.bold),
              ),
              value: isAllSelected,
              onChanged: (_) => _selectAll(),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppTheme.primaryRed,
            ),

            const Divider(),

            // List
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum resultado encontrado',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final label = widget.labelBuilder(item);
                        final subLabel = widget.subLabelBuilder?.call(item);
                        final photoUrl = widget.photoUrlBuilder?.call(item);
                        final isSelected = _tempSelectedItems.contains(item);

                        return CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          title: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: AppTheme.lightGrey,
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: photoUrl != null && photoUrl.isNotEmpty
                                      ? Image.network(
                                          photoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, e, s) =>
                                              const Icon(Icons.person,
                                                  color: Colors.grey),
                                        )
                                      : const Icon(Icons.person,
                                          color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: GoogleFonts.lato(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? AppTheme.primaryRed
                                            : AppTheme.primaryText,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (subLabel != null)
                                      Text(
                                        subLabel,
                                        style: GoogleFonts.lato(
                                          fontSize: 12,
                                          color: AppTheme.secondaryText,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(item),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppTheme.primaryRed,
                          checkboxShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        );
                      },
                    ),
            ),

            // Botão Confirmar (Opcional, mas ajuda no UX de modal)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Confirmar Seleção',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
