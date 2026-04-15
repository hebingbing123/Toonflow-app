import 'package:flutter/material.dart';

/// Groups status, result summaries, and suggested flow-key hints for production.
class ProductionWorkspaceStatusPanel extends StatelessWidget {
  const ProductionWorkspaceStatusPanel({
    super.key,
    required this.resultSummaryLines,
    required this.onApplySuggestedFlowKey,
    required this.busy,
    this.runningTaskLine,
    this.taskStatusLine,
    this.workspaceLastToolResultLine,
    this.suggestedFlowKeyLine,
  });

  final List<String> resultSummaryLines;
  final VoidCallback onApplySuggestedFlowKey;
  final bool busy;
  final String? runningTaskLine;
  final String? taskStatusLine;
  final String? workspaceLastToolResultLine;
  final String? suggestedFlowKeyLine;

  @override
  Widget build(BuildContext context) {
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          runningTaskLine ?? taskStatusLine ?? '等待执行：可直接用引导任务或表单按钮。',
          style: bodySmall,
        ),
        if (workspaceLastToolResultLine != null) ...<Widget>[
          const SizedBox(height: 8),
          Text('最新工具结果：$workspaceLastToolResultLine', style: bodySmall),
        ],
        if (resultSummaryLines.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text('结果摘要', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          ...resultSummaryLines.map(
            (String line) => Text(line, style: bodySmall),
          ),
        ],
        if (suggestedFlowKeyLine != null) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text('建议写回 key：$suggestedFlowKeyLine', style: bodySmall),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: busy ? null : onApplySuggestedFlowKey,
                child: const Text('使用该 key'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '核心 key 回写策略：get_flowData 直接写回；资产/分镜/导演计划相关工具会先刷新对应 flow key 再写回。',
          style: bodySmall,
        ),
      ],
    );
  }
}
