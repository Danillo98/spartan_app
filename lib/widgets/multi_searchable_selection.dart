import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

class MultiSearchableSelection<T> extends StatefulWidget {
  final String label;
  final List<T> selectedItems;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String Function(T) idBuilder; // Necessário para comparar identidade
  final void Function(List<T>) onChanged;
  final String hintText;
  final bool isLoading;

  const MultiSearchableSelection({
    super.key,
    required this.label,
    required this.selectedItems,
    required this.items,
    required this.labelBuilder,
    required this.idBuilder,
    required this.onChanged,
    this.hintText = 'Selecione...',
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
    String displayText = widget.hintText;
    if (widget.selectedItems.isNotEmpty) {
      if (widget.selectedItems.length == widget.items.length) {
        displayText = 'Todos selecionados (${widget.items.length})';
      } else if (widget.selectedItems.length == 1) {
        displayText = widget.labelBuilder(widget.selectedItems.first);
      } else {
        displayText = '${widget.selectedItems.length} selecionados';
      }
    }

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
                    displayText,
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
        initialSelected: widget.selectedItems,
        labelBuilder: widget.labelBuilder,
        idBuilder: widget.idBuilder,
        onConfirm: (List<T> newSelection) {
          widget.onChanged(newSelection);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _MultiSelectionSheet<T> extends StatefulWidget {
  final List<T> items;
  final List<T> initialSelected;
  final String Function(T) labelBuilder;
  final String Function(T) idBuilder;
  final ValueChanged<List<T>> onConfirm;

  const _MultiSelectionSheet({
    required this.items,
    required this.initialSelected,
    required this.labelBuilder,
    required this.idBuilder,
    required this.onConfirm,
  });

  @override
  State<_MultiSelectionSheet<T>> createState() =>
      _MultiSelectionSheetState<T>();
}

class _MultiSelectionSheetState<T> extends State<_MultiSelectionSheet<T>> {
  late List<T> _filteredItems;
  late Set<String> _selectedIds; // Usamos IDs para evitar problemas de hash
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.items);
    _selectedIds = widget.initialSelected.map(widget.idBuilder).toSet();
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(widget.items);
      } else {
        _filteredItems = widget.items.where((item) {
          final label = widget.labelBuilder(item).toLowerCase();
          return label.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _toggleItem(T item) {
    final id = widget.idBuilder(item);
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      // Se todos os FILTRADOS estão selecionados, desseleciona eles
      // Se algum não está, seleciona todos os FILTRADOS
      final allFilteredIds = _filteredItems.map(widget.idBuilder).toSet();
      final allSelected =
          allFilteredIds.every((id) => _selectedIds.contains(id));

      if (allSelected) {
        _selectedIds.removeAll(allFilteredIds);
      } else {
        _selectedIds.addAll(allFilteredIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Verifica estado do "Selecionar Todos" (baseado no filtro atual)
    final allFilteredIds = _filteredItems.map(widget.idBuilder).toSet();
    final isAllSelected = allFilteredIds.isNotEmpty &&
        allFilteredIds.every((id) => _selectedIds.contains(id));

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
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

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Selecionar Itens',
                      style: GoogleFonts.cinzel(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  TextButton(
                    onPressed: () {
                      final selectedItems = widget.items
                          .where((item) =>
                              _selectedIds.contains(widget.idBuilder(item)))
                          .toList();
                      widget.onConfirm(selectedItems);
                    },
                    child: const Text('CONFIRMAR',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            const Divider(),

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

            // Select All Checkbox
            if (_filteredItems.isNotEmpty)
              ListTile(
                leading: Checkbox(
                  value: isAllSelected,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (v) => _toggleSelectAll(),
                ),
                title: const Text('Selecionar Todos (Exibidos)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: _toggleSelectAll,
              ),

            const Divider(height: 1),

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
                        final id = widget.idBuilder(item);
                        final isSelected = _selectedIds.contains(id);

                        return ListTile(
                          leading: Checkbox(
                            value: isSelected,
                            activeColor: AppTheme.primaryRed,
                            onChanged: (v) => _toggleItem(item),
                          ),
                          title: Text(
                            label,
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.black : Colors.grey[800],
                            ),
                          ),
                          onTap: () => _toggleItem(item),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
