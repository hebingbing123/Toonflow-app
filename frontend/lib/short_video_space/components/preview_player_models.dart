part of 'preview_player.dart';

class ShotPreviewItem {
  final String videoUrl;
  final int shotNumber;
  final String? shotTitle;
  final String? durationText;

  const ShotPreviewItem({
    required this.videoUrl,
    required this.shotNumber,
    this.shotTitle,
    this.durationText,
  });
}

/// 预览播放器组件，用于播放单个镜头或连续播放成片
///
/// 支持功能：
/// - 播放/暂停/停止控制
/// - 进度条和时间显示
/// - 拖动进度条跳转
/// - 显示镜头基本信息
/// - 连续播放多个镜头（播放列表模式）
/// - 上一个/下一个镜头控制
/// - 总进度和当前镜头进度显示
