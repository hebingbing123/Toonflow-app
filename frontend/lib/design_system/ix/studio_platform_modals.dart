import 'package:flutter/material.dart';

/// iOS / macOS use Cupertino modal chrome; Android and web use Material.
bool studioPrefersCupertinoModals(BuildContext context) {
  return switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };
}
