part of 'section.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _ShortVideoSpaceSectionProductionBatchProgress on _ShortVideoSpaceSectionState {
  Future<void> _showBatchOperationProgress({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> operations,
    required Future<void> Function(Map<String, dynamic> operation)
    executeOperation,
    required Future<void> Function(
      int successful,
      int failed,
      List<BatchOperationFailedItem> failedItems,
    )
    onComplete,
  }) async {
    var completed = 0;
    var successful = 0;
    var failed = 0;
    final failedItems = <BatchOperationFailedItem>[];
    var isCancelled = false;
    final l10n = resolveAppLocalizationsForErrors(context);

    await showStudioDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            // Execute operations asynchronously
            Future<void> executeOperations() async {
              for (final operation in operations) {
                if (isCancelled) break;

                try {
                  await executeOperation(operation);
                  successful++;
                } catch (e) {
                  failed++;
                  final storyboardId = operation['storyboardId'] as int;
                  final errorMessage = context.mounted
                      ? describeUserVisibleApiErrorResolved(context, e)
                      : e.toString();
                  failedItems.add(
                    BatchOperationFailedItem(
                      shotId: storyboardId,
                      errorMessage: errorMessage,
                    ),
                  );
                }

                completed++;
                if (ctx.mounted) {
                  setState(() {});
                }
              }

              // Call onComplete callback
              await onComplete(successful, failed, failedItems);
            }

            // Start execution if not already started
            if (completed == 0 && !isCancelled) {
              executeOperations();
            }

            final isComplete = completed >= operations.length || isCancelled;

            return BatchOperationProgressDialog(
              title: title,
              total: operations.length,
              completed: completed,
              successful: successful,
              failed: failed,
              failedItems: failedItems,
              isComplete: isComplete,
              onCancel: isComplete
                  ? null
                  : () {
                      setState(() {
                        isCancelled = true;
                      });
                    },
              onRetryFailed: failedItems.isEmpty
                  ? null
                  : () async {
                      // Close current dialog
                      Navigator.of(ctx).pop();

                      // Retry failed operations
                      final retryOperations = failedItems
                          .map(
                            (item) => operations.firstWhere(
                              (op) => op['storyboardId'] == item.shotId,
                            ),
                          )
                          .toList();

                      if (context.mounted) {
                        await _showBatchOperationProgress(
                          context: context,
                          title: l10n.shortVideoBatchOperationRetryTitle(title),
                          operations: retryOperations,
                          executeOperation: executeOperation,
                          onComplete: onComplete,
                        );
                      }
                    },
            );
          },
        );
      },
    );
  }
}
