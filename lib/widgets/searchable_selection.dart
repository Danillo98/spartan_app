import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

class SearchableSelection<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String Function(T)? subLabelBuilder;
  final String? Function(T)? photoUrlBuilder;
  final void Function(T?) onChanged;
  final String hintText;
  final bool isLoading;

  const SearchableSelection({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.subLabelBuilder,
    this.photoUrlBuilder,
    this.hintText = 'Selecione...',
    this.isLoading = false,
  });

  @override
  State<SearchableSelection<T>> createState() => _SearchableSelectionState<T>();
}

class _SearchableSelectionState<T> extends State<SearchableSelection<T>> {
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
                    widget.value != null
                        ? widget.labelBuilder(widget.value as T)
                        : widget.hintText,
                    style: TextStyle(
                      color: widget.value != null
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
      builder: (context) => _SelectionSheet<T>(
        items: widget.items,
        labelBuilder: widget.labelBuilder,
        subLabelBuilder: widget.subLabelBuilder,
        photoUrlBuilder: widget.photoUrlBuilder,
        initialValue: widget.value,
        onSelected: (val) {
          widget.onChanged(val);
          Navigator.pop(context); // Close modal
        },
      ),
    );
  }
}

class _SelectionSheet<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) labelBuilder;
  final String Function(T)? subLabelBuilder;
  final String? Function(T)? photoUrlBuilder;
  final T? initialValue;
  final ValueChanged<T> onSelected;

  const _SelectionSheet({
    required this.items,
    required this.labelBuilder,
    this.subLabelBuilder,
    this.photoUrlBuilder,
    this.initialValue,
    required this.onSelected,
  });

  @override
  State<_SelectionSheet<T>> createState() => _SelectionSheetState<T>();
}

class _SelectionSheetState<T> extends State<_SelectionSheet<T>> {
  late List<T> _filteredItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
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

  @override
  Widget build(BuildContext context) {
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
                        final isSelected = item == widget.initialValue;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.lightGrey,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryRed
                                    : Colors.transparent,
                                width: 2,
                              ),
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
                          title: Text(
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
                          subtitle: subLabel != null
                              ? Text(
                                  subLabel,
                                  style: GoogleFonts.lato(
                                    fontSize: 12,
                                    color: AppTheme.secondaryText,
                                  ),
                                )
                              : null,
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.primaryRed)
                              : null,
                          onTap: () => widget.onSelected(item),
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
