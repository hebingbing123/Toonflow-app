part of '../../../home_page.dart';

extension _HomePageProjectEditorHttpProbes on _HomePageState {
  Widget _buildProjectHttpProbeActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required ProjectDetail detail,
    required TextEditingController introCtrl,
    required List<bool> generalProbeBusy,
    required List<bool> tasksProbeBusy,
    required List<bool> projectProbeBusy,
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
              ..._buildProjectGeneralProbeActions(
                ctx: ctx,
                setDialogState: setDialogState,
                token: token,
                p: p,
                detail: detail,
                introCtrl: introCtrl,
                generalProbeBusy: generalProbeBusy,
                tasksProbeBusy: tasksProbeBusy,
                projectProbeBusy: projectProbeBusy,
              ),
              ..._buildProjectProjectProbeActions(
                ctx: ctx,
                setDialogState: setDialogState,
                token: token,
                detail: detail,
                generalProbeBusy: generalProbeBusy,
                tasksProbeBusy: tasksProbeBusy,
                projectProbeBusy: projectProbeBusy,
              ),
              ..._buildProjectTasksProbeActions(
                ctx: ctx,
                setDialogState: setDialogState,
                token: token,
                p: p,
                generalProbeBusy: generalProbeBusy,
                tasksProbeBusy: tasksProbeBusy,
                projectProbeBusy: projectProbeBusy,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
