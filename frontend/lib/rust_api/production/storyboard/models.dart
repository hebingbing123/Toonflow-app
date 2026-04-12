part of '../../production.dart';

/// OpenAPI **`ProductionStoryboardItem`**.
class ProductionStoryboardItemV1 {
  const ProductionStoryboardItemV1({
    required this.id,
    this.scriptId,
    this.prompt,
    this.url,
    this.duration,
    this.state,
    this.trackId,
    this.flowId,
    this.sbIndex,
  });

  final int id;
  final int? scriptId;
  final String? prompt;
  final String? url;
  final String? duration;
  final String? state;
  final int? trackId;
  final int? flowId;
  final int? sbIndex;

  factory ProductionStoryboardItemV1.fromJson(Map<String, dynamic> json) {
    return ProductionStoryboardItemV1(
      id: (json['id'] as num).toInt(),
      scriptId: json['scriptId'] == null
          ? null
          : (json['scriptId'] as num).toInt(),
      prompt: json['prompt'] as String?,
      url: json['url'] as String?,
      duration: json['duration'] as String?,
      state: json['state'] as String?,
      trackId: json['trackId'] == null
          ? null
          : (json['trackId'] as num).toInt(),
      flowId: json['flowId'] == null ? null : (json['flowId'] as num).toInt(),
      sbIndex: json['sbIndex'] == null
          ? null
          : (json['sbIndex'] as num).toInt(),
    );
  }
}

/// OpenAPI **`ProductionGetProductionDataResponse`**.
class ProductionGetProductionDataResponseV1 {
  const ProductionGetProductionDataResponseV1({required this.data});

  final List<ProductionStoryboardItemV1> data;

  factory ProductionGetProductionDataResponseV1.fromJson(
    Map<String, dynamic> json,
  ) {
    final raw = json['data'] as List<dynamic>? ?? const [];
    return ProductionGetProductionDataResponseV1(
      data: raw
          .map(
            (e) =>
                ProductionStoryboardItemV1.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// OpenAPI **`StoryboardAddResponse`**.
class StoryboardAddResponse {
  const StoryboardAddResponse({
    required this.storyboardId,
    required this.message,
  });

  final int storyboardId;
  final String message;

  factory StoryboardAddResponse.fromJson(Map<String, dynamic> json) {
    return StoryboardAddResponse(
      storyboardId: (json['storyboardId'] as num).toInt(),
      message: json['message'] as String,
    );
  }
}

/// OpenAPI **`StoryboardBatchAddInfoResponse`**.
class StoryboardBatchAddInfoResponse {
  const StoryboardBatchAddInfoResponse({
    required this.added,
    required this.storyboardIds,
  });

  final int added;
  final List<int> storyboardIds;

  factory StoryboardBatchAddInfoResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['storyboardIds'] as List<dynamic>? ?? const [];
    return StoryboardBatchAddInfoResponse(
      added: (json['added'] as num).toInt(),
      storyboardIds: raw.map((e) => (e as num).toInt()).toList(),
    );
  }
}

class StoryboardBatchAddInfoItem {
  const StoryboardBatchAddInfoItem({required this.prompt, this.duration});

  final String prompt;
  final int? duration;

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{'prompt': prompt};
    if (duration != null) body['duration'] = duration;
    return body;
  }
}
