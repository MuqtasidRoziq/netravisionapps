import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import 'single_object_search_catalog.dart';

/// Modal Bottom Sheet interaktif dan berkontras tinggi untuk memilih
/// objek target pencarian tunggal.
class SingleObjectPickerSheet extends StatefulWidget {
  const SingleObjectPickerSheet({
    super.key,
    required this.onSelected,
    this.currentTargetLabel,
  });

  final ValueChanged<SearchableTarget> onSelected;
  final String? currentTargetLabel;

  /// Membuka sheet pemilih objek target.
  static Future<void> show(
    BuildContext context, {
    required ValueChanged<SearchableTarget> onSelected,
    String? currentTargetLabel,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SingleObjectPickerSheet(
        onSelected: onSelected,
        currentTargetLabel: currentTargetLabel,
      ),
    );
  }

  @override
  State<SingleObjectPickerSheet> createState() =>
      _SingleObjectPickerSheetState();
}

class _SingleObjectPickerSheetState extends State<SingleObjectPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SearchableTarget> get _filteredTargets {
    if (_searchQuery.trim().isEmpty) {
      return SingleObjectSearchCatalog.allTargets;
    }
    final query = _searchQuery.trim().toLowerCase();
    return SingleObjectSearchCatalog.allTargets.where((t) {
      return t.displayName.toLowerCase().contains(query) ||
          t.label.toLowerCase().contains(query) ||
          t.category.toLowerCase().contains(query);
    }).toList();
  }

  void _selectTarget(SearchableTarget target) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    widget.onSelected(target);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.85;

    return Container(
      height: sheetHeight,
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.center_focus_strong_rounded,
                    color: AppColors.primaryBlue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Objek Target',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Pilih barang yang ingin Anda temukan',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Tutup pemilih objek',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 28),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Semantics(
              label: 'Cari nama objek',
              textField: true,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Ketik nama barang (mis. ponsel, botol)...',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.lightBlueBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.lightBlueBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.primaryBlue,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Quick targets / Objek Populer
          if (_searchQuery.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: AppColors.yellowAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Objek Populer',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: SingleObjectSearchCatalog.quickTargets.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final target = SingleObjectSearchCatalog.quickTargets[index];
                  final isSelected = widget.currentTargetLabel != null &&
                      widget.currentTargetLabel!.trim().toLowerCase() ==
                          target.label;

                  return Semantics(
                    label: 'Pilih ${target.displayName}',
                    button: true,
                    child: ActionChip(
                      avatar: Icon(
                        target.icon,
                        size: 18,
                        color: isSelected
                            ? Colors.white
                            : AppColors.primaryBlue,
                      ),
                      label: Text(target.displayName),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      backgroundColor: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.lightBlue,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : AppColors.lightBlueBorder,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onPressed: () => _selectTarget(target),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
          ],

          // List item
          Expanded(
            child: _filteredTargets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 54,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Objek "$_searchQuery" tidak ditemukan',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Coba kata kunci lain seperti botol, kursi, atau ponsel',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: _filteredTargets.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final target = _filteredTargets[index];
                      final isSelected = widget.currentTargetLabel != null &&
                          widget.currentTargetLabel!.trim().toLowerCase() ==
                              target.label;

                      return Semantics(
                        label: '${target.displayName}, kategori ${target.category}. '
                            '${isSelected ? "Sedang aktif." : "Ketuk dua kali untuk memilih."}',
                        button: true,
                        child: Material(
                          color: isSelected
                              ? AppColors.lightBlue
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _selectTarget(target),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryBlue
                                      : AppColors.lightBlueBorder.withValues(alpha: 0.5),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primaryBlue
                                          : AppColors.background,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      target.icon,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.primaryBlue,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          target.displayName,
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 16,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          target.category,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.primaryBlue,
                                      size: 24,
                                    )
                                  else
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: AppColors.textSecondary,
                                      size: 16,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
