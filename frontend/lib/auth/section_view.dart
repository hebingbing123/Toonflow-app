import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config.dart';

part 'section_view_content.dart';

class AuthSectionViewModel {
  const AuthSectionViewModel({
    required this.signedIn,
    required this.session,
    required this.emailController,
    required this.passwordController,
    required this.loadingMe,
    required this.loadingDevSwitchProbe,
    required this.loadingMemoryConfigProbe,
    required this.loadingAboutProbe,
    required this.loadingUsageSummary,
    required this.loadingPromptsProbe,
    required this.loadingVisualManualProbe,
    required this.loadingDirectorManualProbe,
    required this.loadingSkillsBinaryProbe,
    required this.loadingModelsCatalog,
    required this.loadingTextModelDefault,
    required this.loadingModelDetail,
    required this.meBody,
    required this.devSwitchProbeBody,
    required this.memoryConfigProbeBody,
    required this.aboutProbeBody,
    required this.usageSummaryBody,
    required this.promptsProbeBody,
    required this.visualManualProbeBody,
    required this.directorManualProbeBody,
    required this.skillsBinaryProbeBody,
    required this.modelsCatalogBody,
    required this.textModelDefaultBody,
    required this.modelDetailBody,
  });

  final bool signedIn;
  final Session? session;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loadingMe;
  final bool loadingDevSwitchProbe;
  final bool loadingMemoryConfigProbe;
  final bool loadingAboutProbe;
  final bool loadingUsageSummary;
  final bool loadingPromptsProbe;
  final bool loadingVisualManualProbe;
  final bool loadingDirectorManualProbe;
  final bool loadingSkillsBinaryProbe;
  final bool loadingModelsCatalog;
  final bool loadingTextModelDefault;
  final bool loadingModelDetail;
  final String? meBody;
  final String? devSwitchProbeBody;
  final String? memoryConfigProbeBody;
  final String? aboutProbeBody;
  final String? usageSummaryBody;
  final String? promptsProbeBody;
  final String? visualManualProbeBody;
  final String? directorManualProbeBody;
  final String? skillsBinaryProbeBody;
  final String? modelsCatalogBody;
  final String? textModelDefaultBody;
  final String? modelDetailBody;
}

class AuthSectionViewCallbacks {
  const AuthSectionViewCallbacks({
    required this.onSignIn,
    required this.onSignUp,
    required this.onSignOut,
    required this.onCallMe,
    required this.onCallDevSwitchProbe,
    required this.onCallMemoryConfigProbe,
    required this.onCallAboutProbe,
    required this.onCallUsageSummary,
    required this.onCallPromptsProbe,
    required this.onCallVisualManualProbe,
    required this.onCallDirectorManualProbe,
    required this.onCallSkillsBinaryProbe,
    required this.onCallModelsCatalog,
    required this.onCallTextModelDefault,
    required this.onCallModelDetail,
  });

  final VoidCallback? onSignIn;
  final VoidCallback? onSignUp;
  final VoidCallback? onSignOut;
  final VoidCallback? onCallMe;
  final VoidCallback? onCallDevSwitchProbe;
  final VoidCallback? onCallMemoryConfigProbe;
  final VoidCallback? onCallAboutProbe;
  final VoidCallback? onCallUsageSummary;
  final VoidCallback? onCallPromptsProbe;
  final VoidCallback? onCallVisualManualProbe;
  final VoidCallback? onCallDirectorManualProbe;
  final VoidCallback? onCallSkillsBinaryProbe;
  final VoidCallback? onCallModelsCatalog;
  final VoidCallback? onCallTextModelDefault;
  final VoidCallback? onCallModelDetail;
}

/// Auth section view shell. Keeps the section file focused on wiring inputs and callbacks.
class AuthSectionView extends StatelessWidget {
  const AuthSectionView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final AuthSectionViewModel model;
  final AuthSectionViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return _AuthSectionContent(model: model, callbacks: callbacks);
  }
}
