part of '../../../home_page.dart';

extension _HomePageProjectEditorHttpProbes on _HomePageState {
  Widget _buildProjectHttpProbeActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required ProjectDetail detail,
    required TextEditingController introCtrl,
    required List<bool> generalLegacyBusy,
    required List<bool> tasksLegacyBusy,
    required List<bool> projectLegacyBusy,
  }) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: const Text('兼容性检查'),
      subtitle: Text(
        '旧 general / project / tasks 接口回归入口，默认折叠',
        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
          color: Theme.of(ctx).colorScheme.outline,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 4,
            runSpacing: 0,
            children: [
              ..._buildProjectLegacyGeneralProbeActions(
                ctx: ctx,
                setDialogState: setDialogState,
                token: token,
                p: p,
                detail: detail,
                introCtrl: introCtrl,
                generalLegacyBusy: generalLegacyBusy,
                tasksLegacyBusy: tasksLegacyBusy,
                projectLegacyBusy: projectLegacyBusy,
              ),
              ..._buildProjectLegacyProjectProbeActions(
                ctx: ctx,
                setDialogState: setDialogState,
                token: token,
                detail: detail,
                generalLegacyBusy: generalLegacyBusy,
                tasksLegacyBusy: tasksLegacyBusy,
                projectLegacyBusy: projectLegacyBusy,
              ),
              ..._buildProjectLegacyTasksProbeActions(
                ctx: ctx,
                setDialogState: setDialogState,
                token: token,
                p: p,
                generalLegacyBusy: generalLegacyBusy,
                tasksLegacyBusy: tasksLegacyBusy,
                projectLegacyBusy: projectLegacyBusy,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
