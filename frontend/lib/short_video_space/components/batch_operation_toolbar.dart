import 'package:flutter/material.dart';

import 'package:openflow_app/design_system/layout_breakpoints.dart';
import 'package:openflow_app/design_system/components/studio_dense_action_row.dart';
import 'package:openflow_app/design_system/components/studio_repaint_boundary.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/components/studio_tap.dart';
import 'package:openflow_app/design_system/components/studio_entrance_motion.dart';
import 'package:openflow_app/design_system/tokens.dart';
import 'package:flutter/services.dart';

import '../../rust_api.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

/// Batch operation toolbar component for short video assembly
/// 
/// Provides batch selection and batch operation functionality:
/// - Multi-select checkboxes for each shot
/// - Select all / Deselect all functionality
/// - Selected count indicator
/// - Range selection (Shift+click)
/// - Batch operation buttons (enable/disable/duration/replace/voiceover)
/// - 1000ms throttling for batch operations to prevent rapid repeated calls
class BatchOperationToolbar extends StatefulWidget {
  const BatchOperationToolbar({
    super.key,
    required this.totalCount,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onBatchEnable,
    required this.onBatchDisable,
    required this.onBatchUpdateDuration,
    required this.onBatchReplace,
    required this.onBatchGenerateVoiceover,
    this.isOperationInProgress = false,
    this.nowProvider = DateTime.now,
  });

  /// Total number of shots
  final int totalCount;

  /// Set of selected shot IDs
  final Set<int> selectedIds;

  /// Callback when selection changes
  final ValueChanged<Set<int>> onSelectionChanged;

  /// Callback for select all
  final VoidCallback onSelectAll;

  /// Callback for deselect all
  final VoidCallback onDeselectAll;

  /// Callback for batch enable
  final VoidCallback onBatchEnable;

  /// Callback for batch disable
  final VoidCallback onBatchDisable;

  /// Callback for batch update duration
  final VoidCallback onBatchUpdateDuration;

  /// Callback for batch replace
  final VoidCallback onBatchReplace;

  /// Callback for batch generate voiceover
  final VoidCallback onBatchGenerateVoiceover;

  /// Whether a batch operation is currently in progress
  final bool isOperationInProgress;

  /// Clock injection for deterministic throttling in tests.
  final DateTime Function() nowProvider;

  @override
  State<BatchOperationToolbar> createState() => _BatchOperationToolbarState();
}

class _BatchOperationToolbarState extends State<BatchOperationToolbar> {
  DateTime? _lastBatchOperationTime;
  
  /// Throttle batch operations to prevent rapid repeated calls
  /// Returns true if the operation should proceed, false if throttled
  bool _shouldAllowBatchOperation() {
    final now = widget.nowProvider();
    if (_lastBatchOperationTime == null) {
      _lastBatchOperationTime = now;
      return true;
    }
    
    final timeSinceLastOperation = now.difference(_lastBatchOperationTime!);
    if (timeSinceLastOperation.inMilliseconds >= 1000) {
      _lastBatchOperationTime = now;
      return true;
    }
    
    final l10n = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.shortVideoBatchThrottleMessage),
        duration: const Duration(milliseconds: 1500),
      ),
    );
    return false;
  }
  
  void _handleBatchOperation(VoidCallback operation) {
    if (!widget.isOperationInProgress && _shouldAllowBatchOperation()) {
      operation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final hasSelection = widget.selectedIds.isNotEmpty;
    final isAllSelected = widget.selectedIds.length == widget.totalCount && widget.totalCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.sm,
        vertical: StudioSpacing.radiusComfort,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: studioPanelBorderColor(context),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Select all checkbox
          Checkbox(
            value: isAllSelected,
            tristate: true,
            onChanged: widget.isOperationInProgress
                ? null
                : (value) {
                    if (value == true) {
                      widget.onSelectAll();
                    } else {
                      widget.onDeselectAll();
                    }
                  },
          ),
          const SizedBox(width: StudioSpacing.xs),
          
          // Select all / Deselect all button
          TextButton.icon(
            style: studioFormTextButtonIconStyle(context),
            onPressed: widget.isOperationInProgress
                ? null
                : () {
                    if (isAllSelected) {
                      widget.onDeselectAll();
                    } else {
                      widget.onSelectAll();
                    }
                  },
            icon: Icon(isAllSelected ? Icons.deselect : Icons.select_all),
            label: Text(
              isAllSelected ? l10n.shortVideoBatchDeselectAll : l10n.shortVideoBatchSelectAll,
            ),
          ),
          
          const SizedBox(width: StudioSpacing.sm),
          
          // Selected count indicator
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: StudioLayoutSpacing.insetDense,
              vertical: StudioLayoutSpacing.microGap,
            ),
            decoration: BoxDecoration(
              color: hasSelection
                  ? StudioTokens.of(context).primarySoft
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(StudioSpacing.sm),
            ),
            child: Text(
              l10n.shortVideoBatchSelectedCount(
                widget.selectedIds.length,
                widget.totalCount,
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: hasSelection
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
          
          const SizedBox(width: StudioSpacing.sm),
          
          // Batch operation buttons (only show when items are selected)
          if (hasSelection) ...[
            const VerticalDivider(),
            const SizedBox(width: StudioSpacing.xs),
            
            Expanded(
              child: StudioDenseActionRow(
                children: [
                  // Batch enable
                  FilledButton.tonalIcon(
                    style: studioFormIconLabeledButtonStyle(context),
                    onPressed: widget.isOperationInProgress 
                        ? null 
                        : () => _handleBatchOperation(widget.onBatchEnable),
                    icon: const Icon(Icons.play_arrow, size: StudioIconSize.sm),
                    label: Text(l10n.shortVideoBatchOpEnable),
                  ),
                  
                  // Batch disable
                  OutlinedButton.icon(
                    style: studioFormOutlinedIconLabeledButtonStyle(context),
                    onPressed: widget.isOperationInProgress 
                        ? null 
                        : () => _handleBatchOperation(widget.onBatchDisable),
                    icon: const Icon(Icons.pause, size: StudioIconSize.sm),
                    label: Text(l10n.shortVideoBatchOpDisable),
                  ),
                  
                  // Batch update duration
                  OutlinedButton.icon(
                    style: studioFormOutlinedIconLabeledButtonStyle(context),
                    onPressed: widget.isOperationInProgress 
                        ? null 
                        : () => _handleBatchOperation(widget.onBatchUpdateDuration),
                    icon: const Icon(Icons.timer, size: StudioIconSize.sm),
                    label: Text(l10n.shortVideoBatchOpDurationAlign),
                  ),
                  
                  // Batch replace
                  OutlinedButton.icon(
                    style: studioFormOutlinedIconLabeledButtonStyle(context),
                    onPressed: widget.isOperationInProgress 
                        ? null 
                        : () => _handleBatchOperation(widget.onBatchReplace),
                    icon: const Icon(Icons.swap_horiz, size: StudioIconSize.sm),
                    label: Text(l10n.shortVideoBatchOpReplace),
                  ),
                  
                  // Batch generate voiceover
                  OutlinedButton.icon(
                    style: studioFormOutlinedIconLabeledButtonStyle(context),
                    onPressed: widget.isOperationInProgress 
                        ? null 
                        : () => _handleBatchOperation(widget.onBatchGenerateVoiceover),
                    icon: const Icon(Icons.record_voice_over, size: StudioIconSize.sm),
                    label: Text(l10n.shortVideoBatchOpVoiceover),
                  ),
                ],
              ),
            ),
          ],
          
          // Show loading indicator when operation is in progress
          if (widget.isOperationInProgress) ...[
            const SizedBox(width: StudioSpacing.sm),
            const StudioRepaintBoundary(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: StudioControlSize.progressStroke,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shot selection checkbox widget
/// 
/// Provides individual shot selection with Shift+click range selection support
class ShotSelectionCheckbox extends StatefulWidget {
  const ShotSelectionCheckbox({
    super.key,
    required this.shotId,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.onRangeSelection,
    this.isEnabled = true,
  });

  /// Shot ID
  final int shotId;

  /// Whether this shot is selected
  final bool isSelected;

  /// Callback when selection changes
  final ValueChanged<bool> onSelectionChanged;

  /// Callback for range selection (Shift+click)
  /// Parameters: (shotId, isShiftPressed)
  final Function(int, bool) onRangeSelection;

  /// Whether the checkbox is enabled
  final bool isEnabled;

  @override
  State<ShotSelectionCheckbox> createState() => _ShotSelectionCheckboxState();
}

class _ShotSelectionCheckboxState extends State<ShotSelectionCheckbox> {
  bool _isShiftPressed = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
            event.logicalKey == LogicalKeyboardKey.shiftRight) {
          final isPressed = event is KeyDownEvent ||
              (event is KeyRepeatEvent && _isShiftPressed);
          if (_isShiftPressed != isPressed) {
            setState(() {
              _isShiftPressed = isPressed;
            });
          }
          return KeyEventResult.ignored;
        }

        // Handle keyboard events for accessibility
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            if (widget.isEnabled) {
              widget.onSelectionChanged(!widget.isSelected);
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: StudioTap(
        enabled: widget.isEnabled,
        onTap: () {
          final isShiftPressed =
              _isShiftPressed || HardwareKeyboard.instance.isShiftPressed;
          if (isShiftPressed) {
            widget.onRangeSelection(widget.shotId, true);
          } else {
            widget.onSelectionChanged(!widget.isSelected);
          }
        },
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
        child: IgnorePointer(
          // Tap behavior is handled by [StudioTap] to provide feedback and a larger target.
          child: Checkbox(value: widget.isSelected, onChanged: null),
        ),
      ),
    );
  }
}

/// Batch operation progress dialog
/// 
/// Shows progress for batch operations with success/failure statistics
class BatchOperationProgressDialog extends StatelessWidget {
  const BatchOperationProgressDialog({
    super.key,
    required this.title,
    required this.total,
    required this.completed,
    required this.successful,
    required this.failed,
    this.failedItems = const [],
    this.onRetryFailed,
    this.onCancel,
    this.isComplete = false,
  });

  /// Dialog title
  final String title;

  /// Total number of operations
  final int total;

  /// Number of completed operations
  final int completed;

  /// Number of successful operations
  final int successful;

  /// Number of failed operations
  final int failed;

  /// List of failed items with error messages
  final List<BatchOperationFailedItem> failedItems;

  /// Callback to retry failed items
  final VoidCallback? onRetryFailed;

  /// Callback to cancel operation
  final VoidCallback? onCancel;

  /// Whether the operation is complete
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final progress = total > 0 ? completed / total : 0.0;
    final hasFailures = failedItems.isNotEmpty;

    return StudioAlertDialog(
      title: Text(title),
      content: SizedBox(
        width: studioConstrainedDialogWidth(context, maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
            ),
            const SizedBox(height: StudioSpacing.sm),
            
            // Statistics
            Text(
              l10n.shortVideoBatchProgressCompletedTotal(completed, total),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: StudioSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: StudioIconSize.md,
                ),
                const SizedBox(width: StudioSpacing.xs),
                Text(l10n.shortVideoBatchProgressSucceededLabel(successful)),
                const SizedBox(width: StudioSpacing.md),
                Icon(
                  Icons.error,
                  color: Theme.of(context).colorScheme.error,
                  size: StudioIconSize.md,
                ),
                const SizedBox(width: StudioSpacing.xs),
                Text(l10n.shortVideoBatchProgressFailedLabel(failed)),
              ],
            ),
            
            // Failed items list
            if (hasFailures) ...[
              const SizedBox(height: StudioSpacing.sm),
              const Divider(),
              const SizedBox(height: StudioSpacing.xs),
              Text(
                l10n.shortVideoBatchProgressFailedHeading,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: StudioSpacing.xs),
              Flexible(
                child: ListView.builder(
                  itemCount: failedItems.length,
                  itemBuilder: (context, index) {
                    final item = failedItems[index];
                    return studioStaggeredItem(
                      index,
                      entranceKey: failedItems.length,
                      child: StudioListRow(
                        dense: true,
                        onCopy: () async {
                          await Clipboard.setData(
                            ClipboardData(text: item.errorMessage),
                          );
                        },
                        leading: Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: StudioIconSize.md,
                        ),
                        title: Text(l10n.shortVideoBatchProgressStoryboardLine(item.shotId)),
                        subtitle: Text(
                          item.errorMessage,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!isComplete && onCancel != null)
          TextButton(
            onPressed: onCancel,
            child: Text(l10n.shortVideoBatchProgressCancel),
          ),
        if (isComplete && hasFailures && onRetryFailed != null)
          FilledButton.tonal(
            style: studioFormTonalButtonStyle(context),
            onPressed: onRetryFailed,
            child: Text(l10n.shortVideoBatchProgressRetryFailed),
          ),
        if (isComplete)
          FilledButton(
            style: studioFormPrimaryButtonStyle(context),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.shortVideoBatchProgressClose),
          ),
      ],
    );
  }
}

/// Failed item in batch operation
class BatchOperationFailedItem {
  const BatchOperationFailedItem({
    required this.shotId,
    required this.errorMessage,
  });

  final int shotId;
  final String errorMessage;
}
