/// Tokens for **content matching**, crawl parsers, and backend enum literals.
///
/// Not user-visible copy — do not use for [Text] / labels. UI strings belong in
/// `app_en.arb` / `app_zh.arb`.
library;

// --- Backend / DB literals (must match Rust) ---

/// Project asset image row state written by backend jobs and probes.
const String kStudioAssetImageStateCompleted = '已完成';

// --- Workspace / project mode matching ---

const String kStudioWorkspacePersonalDefaultNameZh = '个人工作区';

const List<String> kStudioProjectLiveActionModeTokens = <String>[
  'live',
  'real',
  '真人',
];

// --- Novel crawl (HTML link text) ---

const List<String> kNovelCrawlNextPageLinkTexts = <String>['下一页', '下页'];

final RegExp kNovelCrawlChapterHeaderPattern = RegExp(
  r'^\s*((?:第[0-9零一二三四五六七八九十百千万两〇]+[章节回集部篇卷]|(?:序章|尾声|番外))(?:[^\n\r]{0,36}))\s*$',
  multiLine: true,
);

final RegExp kNovelCrawlJunkLinePattern = RegExp(
  r'(?:收藏本站|最新网址|手机阅读|本章未完|点击下一页|上一章|下一章|广告|版权归|请记住本站)',
  caseSensitive: false,
);

final RegExp kNovelCrawlChapterLabelPattern = RegExp(
  r'(?:第[0-9零一二三四五六七八九十百千万两〇]+[章节回集部篇卷]|序章|尾声|番外)',
);

final RegExp kProductionStoryboardExpandRowsZhPattern = RegExp(
  r'待展开\s*(\d+)\s*行',
);

// --- Quality review: reviewer comment & bucket heuristics ---

const List<String> kQualityReviewDeliveryBucketTokens = <String>['表演', '语气'];

const List<String> kQualityReviewTrimBucketTokens = <String>['动作', '光影'];

const List<String> kQualityReviewStiffDeliveryCommentTokens = <String>[
  '生硬',
  '朗读',
  '没情绪',
  '无情绪',
];

const List<String> kQualityReviewEmotionCommentTokens = <String>['情绪', '台词'];

const List<String> kQualityReviewVisualCommentTokens = <String>['穿帮', '不自然'];

const List<String> kQualityReviewFakeVisualCommentTokens = <String>['假'];

// --- Storyboard prompt compression / repair ---

const List<String> kStoryboardPromptPerformanceKeywords = <String>[
  '表情',
  '情绪',
  '眼神',
  '口型',
  '微表情',
  '呼吸',
  '停顿',
  '台词',
  '语气',
  '人物',
  '角色',
  'identity',
  'expression',
  'emotion',
  'lip',
  'face',
];

const List<String> kStoryboardPromptGenericTrimKeywords = <String>[
  '光影',
  '光线',
  '镜头',
  '运镜',
  '跟拍',
  '推拉',
  '摇镜',
  '氛围',
  '节奏',
  '动作',
  '缓慢',
  '唯美',
  'cinematic',
  'lighting',
  'camera',
  'tracking shot',
  'moody',
  'atmosphere',
];

const List<String> kStoryboardMemorySuppressedTrimBuckets = <String>['动作', '光影'];

const List<String> kStoryboardRepairDeliveryBucketTokens = <String>['表演', '语气'];

// --- Agent memory dedup ---

const List<String> kAgentMemoryDeliveryKeywords = <String>[
  '表演',
  '语气',
  '情绪',
  '呼吸',
  '停顿',
  '眼神',
  '口型',
  '微表情',
  'emotion',
  'expression',
  'delivery',
  'lip',
];

const List<String> kAgentMemoryVisualKeywords = <String>[
  '镜头',
  '光影',
  '光线',
  '逆光',
  '暖光',
  '冷光',
  '运镜',
  '构图',
  '机位',
  '近景',
  '中景',
  '远景',
  'camera',
  'lighting',
  'framing',
];

// --- Production agent script plan ---

const List<String> kProductionScriptStoryboardReadySectionTokens = <String>[
  '分场景',
  '画面意图',
  '镜头意图',
  '情绪',
];

const List<String> kProductionAssetToolSignalTokens = <String>[
  '道具',
  '物件',
  '兵器',
  '武器',
  '法器',
  '信物',
  '令牌',
  '玉佩',
  '佩剑',
  'tool',
  'prop',
];

final RegExp kProductionScriptPlanAssetIdPattern = RegExp(
  r'(?:资产|asset)\s*[#：:\s]?\s*([\d\s,，、]+)',
  caseSensitive: false,
);

// --- Task / error message tokens (backend may emit localized text) ---

const List<String> kTaskCenterWritebackMessageTokens = <String>['写回'];

// --- API / log line prefix stripping ---

final RegExp kStudioApiErrorLinePrefixPattern = RegExp(
  r'^(Unknown error:|出现问题：)\s*',
);

// --- Helpers ---

bool studioContentContainsAny(String haystack, Iterable<String> needles) {
  for (final needle in needles) {
    if (haystack.contains(needle)) {
      return true;
    }
  }
  return false;
}

bool studioContentContainsAnyLower(
  String haystack,
  Iterable<String> needles,
) {
  final lower = haystack.toLowerCase();
  for (final needle in needles) {
    if (lower.contains(needle.toLowerCase())) {
      return true;
    }
  }
  return false;
}

bool studioContentBucketHit(
  Iterable<String> buckets,
  Iterable<String> targets,
) {
  for (final bucket in buckets) {
    if (targets.contains(bucket)) {
      return true;
    }
  }
  return false;
}

bool studioProjectModeLooksLiveAction(String? mode) {
  final value = (mode ?? '').trim().toLowerCase();
  if (value.isEmpty) {
    return false;
  }
  return studioContentContainsAnyLower(value, kStudioProjectLiveActionModeTokens);
}

bool studioTaskMessageLooksLikeWritebackFailure(String message) {
  final lower = message.toLowerCase();
  return lower.contains('writeback') ||
      studioContentContainsAny(message, kTaskCenterWritebackMessageTokens);
}

/// Agent markdown storyboard tables may use Chinese or English column headers.
String studioNormalizeProductionStoryboardTableColumn(String column) {
  switch (column.trim()) {
    case '序号':
    case 'id':
      return 'id';
    case '画面描述':
    case 'description':
      return 'description';
    case '场景':
    case 'scene':
      return 'scene';
    case '时长':
    case 'duration':
      return 'duration';
    case '景别':
    case 'camera':
      return 'camera';
    case '关联资产ID':
    case '关联资产Ids':
    case 'associateAssetsIds':
      return 'associateAssetsIds';
    default:
      return column.trim();
  }
}
