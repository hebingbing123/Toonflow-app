part of '../../production.dart';

/// OpenAPI **`ImageFlowStep`**.
class ImageFlowStepV1 {
  const ImageFlowStepV1({
    required this.stepId,
    required this.stepName,
    required this.status,
  });

  final String stepId;
  final String stepName;
  final String status;

  factory ImageFlowStepV1.fromJson(Map<String, dynamic> json) {
    return ImageFlowStepV1(
      stepId: json['stepId'] as String,
      stepName: json['stepName'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'stepId': stepId, 'stepName': stepName, 'status': status};
  }
}

/// OpenAPI **`ImageFlowResponse`**.
class ImageFlowResponseV1 {
  const ImageFlowResponseV1({
    required this.flowId,
    required this.steps,
    required this.defaultModel,
  });

  final String flowId;
  final List<ImageFlowStepV1> steps;
  final String defaultModel;

  factory ImageFlowResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['steps'] as List<dynamic>? ?? const [];
    return ImageFlowResponseV1(
      flowId: json['flowId'] as String,
      steps: raw
          .map((e) => ImageFlowStepV1.fromJson(e as Map<String, dynamic>))
          .toList(),
      defaultModel: json['defaultModel'] as String,
    );
  }
}

/// OpenAPI **`ImageDefaultModelResponse`**.
class ImageDefaultModelResponseV1 {
  const ImageDefaultModelResponseV1({
    required this.model,
    required this.resolution,
  });

  final String model;
  final String resolution;

  factory ImageDefaultModelResponseV1.fromJson(Map<String, dynamic> json) {
    return ImageDefaultModelResponseV1(
      model: json['model'] as String,
      resolution: json['resolution'] as String,
    );
  }
}

/// OpenAPI **`SaveImageFlowResponse`**.
class SaveImageFlowResponseV1 {
  const SaveImageFlowResponseV1({required this.flowId, required this.saved});

  final String flowId;
  final bool saved;

  factory SaveImageFlowResponseV1.fromJson(Map<String, dynamic> json) {
    return SaveImageFlowResponseV1(
      flowId: json['flowId'] as String,
      saved: json['saved'] as bool,
    );
  }
}

/// OpenAPI **`UpdateImageFlowResponse`**.
class UpdateImageFlowResponseV1 {
  const UpdateImageFlowResponseV1({
    required this.flowId,
    required this.stepId,
    required this.updated,
  });

  final String flowId;
  final String stepId;
  final bool updated;

  factory UpdateImageFlowResponseV1.fromJson(Map<String, dynamic> json) {
    return UpdateImageFlowResponseV1(
      flowId: json['flowId'] as String,
      stepId: json['stepId'] as String,
      updated: json['updated'] as bool,
    );
  }
}

/// OpenAPI **`GenerateFlowImageResponse`**.
class GenerateFlowImageResponseV1 {
  const GenerateFlowImageResponseV1({
    required this.jobId,
    required this.status,
  });

  final String jobId;
  final String status;

  factory GenerateFlowImageResponseV1.fromJson(Map<String, dynamic> json) {
    return GenerateFlowImageResponseV1(
      jobId: json['jobId'] as String,
      status: json['status'] as String,
    );
  }
}

/// OpenAPI **`ProductionEditImageUploadImageResponse`**.
class EditImageUploadImageResponseV1 {
  const EditImageUploadImageResponseV1({required this.url});

  final String url;

  factory EditImageUploadImageResponseV1.fromJson(Map<String, dynamic> json) {
    return EditImageUploadImageResponseV1(url: json['url'] as String);
  }
}
