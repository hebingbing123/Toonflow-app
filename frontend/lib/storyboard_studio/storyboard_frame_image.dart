import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../rust_api/production/storyboard/grid_generate.dart';

/// Storyboard frame preview (http(s), data URI, or authenticated local-frame).
class StoryboardFrameImage extends StatelessWidget {
  const StoryboardFrameImage({
    super.key,
    required this.accessToken,
    required this.projectUuid,
    required this.scriptNumericId,
    required this.storyboardNumericId,
    required this.imageUrl,
    this.height = 240,
    this.fit = BoxFit.contain,
  });

  final String accessToken;
  final String projectUuid;
  final int scriptNumericId;
  final int storyboardNumericId;
  final String? imageUrl;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final raw = imageUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return SizedBox(height: height);
    }

    if (raw.startsWith('data:image/')) {
      final payload = raw.split(',').length > 1 ? raw.split(',').last : '';
      try {
        final bytes = base64Decode(payload);
        return Image.memory(
          bytes,
          height: height,
          width: double.infinity,
          fit: fit,
        );
      } catch (_) {
        return _errorBox(context, raw);
      }
    }

    if (raw.startsWith('/storyboard-local/')) {
      final uri = storyboardLocalFrameUri(
        projectUuid: projectUuid,
        scriptId: scriptNumericId,
        storyboardId: storyboardNumericId,
      );
      return FutureBuilder<http.Response>(
        future: http.get(
          uri,
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return SizedBox(
              height: height,
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          final res = snapshot.data;
          if (res == null || res.statusCode != 200) {
            return _errorBox(context, raw);
          }
          return Image.memory(
            res.bodyBytes,
            height: height,
            width: double.infinity,
            fit: fit,
          );
        },
      );
    }

    final resolved = raw.startsWith('http')
        ? raw
        : resolveRustApiUrl(raw);
    return Image.network(
      resolved,
      height: height,
      width: double.infinity,
      fit: fit,
      errorBuilder: (_, _, _) => _errorBox(context, resolved),
    );
  }

  Widget _errorBox(BuildContext context, String label) {
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        label,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}
