import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/controller.dart';
import '../config.dart'
    show kDevAdminEmail, kDevAdminPassword, kSupabaseConfigured;
import '../design_system/components/openflow_brand.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/studio_typography.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import 'studio_theme.dart';

/// Full-screen sign-in for [HomeShellMode.product].
class ProductLoginPage extends StatefulWidget {
  const ProductLoginPage({
    super.key,
    required this.authController,
    this.errorMessage,
    required this.onSignIn,
    required this.onSignUp,
  });

  final AuthController authController;
  final String? errorMessage;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  @override
  State<ProductLoginPage> createState() => _ProductLoginPageState();
}

enum _AuthMode { signIn, signUp }

class _ProductLoginPageState extends State<ProductLoginPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sceneController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 15),
  );
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  String? _localErrorMessage;

  bool get _ambientAnimationEnabled {
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return !bindingName.contains('TestWidgetsFlutterBinding') &&
        !bindingName.contains('IntegrationTestWidgetsFlutterBinding') &&
        !bindingName.contains('LiveTestWidgetsFlutterBinding');
  }

  @override
  void initState() {
    super.initState();
    widget.authController.passwordController.addListener(_clearLocalError);
    _confirmPasswordController.addListener(_clearLocalError);
    if (_ambientAnimationEnabled) {
      _sceneController.repeat();
    } else {
      _sceneController.value = 0.18;
    }
  }

  @override
  void didUpdateWidget(covariant ProductLoginPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.authController, widget.authController)) {
      oldWidget.authController.passwordController.removeListener(
        _clearLocalError,
      );
      widget.authController.passwordController.addListener(_clearLocalError);
    }
    if (oldWidget.errorMessage != widget.errorMessage &&
        _localErrorMessage != null) {
      setState(() {
        _localErrorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    widget.authController.passwordController.removeListener(_clearLocalError);
    _confirmPasswordController.removeListener(_clearLocalError);
    _confirmPasswordController.dispose();
    _sceneController.dispose();
    super.dispose();
  }

  void _clearLocalError() {
    if (_localErrorMessage == null || !mounted) {
      return;
    }
    setState(() {
      _localErrorMessage = null;
    });
  }

  void _setMode(_AuthMode mode) {
    if (_mode == mode) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = mode;
      _localErrorMessage = null;
    });
  }

  void _handleSubmit() {
    FocusScope.of(context).unfocus();
    if (_mode == _AuthMode.signUp &&
        widget.authController.passwordController.text !=
            _confirmPasswordController.text) {
      return;
    }
    if (_mode == _AuthMode.signIn) {
      widget.onSignIn();
      return;
    }
    widget.onSignUp();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final studio = StudioColors.of(context);
    final tokens = StudioTokens.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: studio.loginBackdrop),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _sceneController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _BackdropGridPainter(
                        progress: _sceneController.value,
                        lineColor: tokens.borderDefault.withValues(alpha: 0.20),
                        accentColor: tokens.primary.withValues(alpha: 0.22),
                        accentColorTwo: tokens.accent.withValues(alpha: 0.18),
                      ),
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentWidth = constraints.maxWidth;
                  final wide = contentWidth >= 1120;
                  final ultraCompact = contentWidth < 480;
                  final pagePadding = EdgeInsets.all(
                    wide
                        ? 28
                        : ultraCompact
                        ? 16
                        : 20,
                  );
                  if (wide) {
                    final authPanelWidth = (constraints.maxWidth * 0.34)
                        .clamp(392.0, 456.0)
                        .toDouble();
                    return Padding(
                      padding: pagePadding,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(
                            child: AnimatedBuilder(
                              animation: _sceneController,
                              builder: (context, _) => _HeroStage(
                                l10n: l10n,
                                progress: _sceneController.value,
                                compact: false,
                              ),
                            ),
                          ),
                          const SizedBox(width: 28),
                          SizedBox(
                            width: authPanelWidth,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: SingleChildScrollView(
                                child: _AuthPanel(
                                  l10n: l10n,
                                  authController: widget.authController,
                                  mode: _mode,
                                  confirmPasswordController:
                                      _confirmPasswordController,
                                  onModeChanged: _setMode,
                                  onSubmit: _handleSubmit,
                                  compact: false,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: pagePadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _BrandBanner(
                          title: l10n.appTitle,
                          eyebrow: l10n.productPipelineStripTitle,
                        ),
                        const SizedBox(height: 20),
                        if (ultraCompact)
                          Text(
                            l10n.productShellLoginTagline,
                            style: studioSectionIntroStyle(context)?.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          )
                        else
                          AnimatedBuilder(
                            animation: _sceneController,
                            builder: (context, _) => _HeroStage(
                              l10n: l10n,
                              progress: _sceneController.value,
                              compact: true,
                            ),
                          ),
                        const SizedBox(height: 20),
                        _AuthPanel(
                          l10n: l10n,
                          authController: widget.authController,
                          mode: _mode,
                          confirmPasswordController: _confirmPasswordController,
                          onModeChanged: _setMode,
                          onSubmit: _handleSubmit,
                          compact: true,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStage extends StatelessWidget {
  const _HeroStage({
    required this.l10n,
    required this.progress,
    required this.compact,
  });

  final AppLocalizations l10n;
  final double progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = StudioTypography.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!compact) ...<Widget>[
          _BrandBanner(
            title: l10n.appTitle,
            eyebrow: l10n.productPipelineStripTitle,
          ),
          const SizedBox(height: 28),
        ],
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? double.infinity : 640,
          ),
          child: Text(
            l10n.productShellLoginHeroTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: compact ? math.min(typography.paneTitle + 1, 24).toDouble() : math.min(typography.display, 28).toDouble(),
              height: 1.08,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? double.infinity : 560,
          ),
          child: Text(
            l10n.productShellLoginTagline,
            style: studioSectionIntroStyle(context)?.copyWith(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: typography.bodyLarge,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: StudioSpacing.xs + 2,
          runSpacing: StudioSpacing.xs + 2,
          children: <Widget>[
            _SignalChip(
              icon: Icons.auto_stories_outlined,
              label: l10n.productPipelineStripScripts,
            ),
            _SignalChip(
              icon: Icons.theaters_outlined,
              label: l10n.productPipelineStripProduction,
            ),
            _SignalChip(
              icon: Icons.movie_creation_outlined,
              label: l10n.productPipelineStripShortVideo,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (compact)
          SizedBox(
            height: 300,
            child: _AiStagePanel(
              l10n: l10n,
              compact: compact,
              progress: progress,
            ),
          )
        else
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 420),
              child: _AiStagePanel(
                l10n: l10n,
                compact: compact,
                progress: progress,
              ),
            ),
          ),
      ],
    );
  }
}

class _BrandBanner extends StatelessWidget {
  const _BrandBanner({required this.title, required this.eyebrow});

  final String title;
  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: <Widget>[
        const OpenFlowBrandMark(size: 54),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.54),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AiStagePanel extends StatelessWidget {
  const _AiStagePanel({
    required this.l10n,
    required this.compact,
    required this.progress,
  });

  final AppLocalizations l10n;
  final bool compact;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final typography = StudioTypography.of(context);
    final ringSize = compact ? 124.0 : 156.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _AiStagePainter(
                progress: progress,
                lineColor: tokens.borderDefault.withValues(alpha: 0.40),
                accentColor: tokens.primary.withValues(alpha: 0.85),
                accentColorTwo: tokens.accent.withValues(alpha: 0.85),
              ),
            ),
          ),
          if (compact)
            Positioned(
              top: 18,
              left: 18,
              right: 18,
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                children: <Widget>[
                  _StageMetric(
                    icon: Icons.auto_awesome_outlined,
                    title: l10n.productLoginStageModelOrchestration,
                    value: l10n.productLoginStageStatusOnline,
                  ),
                  _StageMetric(
                    icon: Icons.memory_outlined,
                    title: l10n.productLoginStageInferenceLanes,
                    value: l10n.productLoginStageLowLatency,
                    alignEnd: true,
                  ),
                ],
              ),
            )
          else ...<Widget>[
            Positioned(
              top: 18,
              left: 18,
              child: _StageMetric(
                icon: Icons.auto_awesome_outlined,
                title: l10n.productLoginStageModelOrchestration,
                value: l10n.productLoginStageStatusOnline,
              ),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: _StageMetric(
                icon: Icons.memory_outlined,
                title: l10n.productLoginStageInferenceLanes,
                value: l10n.productLoginStageLowLatency,
                alignEnd: true,
              ),
            ),
          ],
          Center(
            child: _StageCoreCluster(progress: progress, ringSize: ringSize),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              children: <Widget>[
                _StageLabel(
                  label: l10n.productLoginStageMultiStepOrchestration,
                ),
                _StageLabel(
                  label: l10n.productLoginStageShotLevelGeneration,
                ),
                _StageLabel(
                  label: l10n.productLoginStageReleaseLoop,
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            bottom: compact ? 64 : 86,
            child: Text(
              l10n.productLoginStageFlowTagline,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: typography.hint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StudioSpacing.xs + 4,
          vertical: StudioSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: tokens.textMuted),
            const SizedBox(width: StudioSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageCoreCluster extends StatelessWidget {
  const _StageCoreCluster({required this.progress, required this.ringSize});

  final double progress;
  final double ringSize;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final orbitSize = ringSize + 60;
    final basePulse = 0.5 + (0.5 * math.sin(progress * math.pi * 2));

    return SizedBox(
      width: orbitSize,
      height: orbitSize,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (final (index, scaleBase) in <(int, double)>[
            (0, 0.74),
            (1, 0.88),
            (2, 1.03),
          ])
            Opacity(
              opacity: (0.16 - (index * 0.03)) + (basePulse * 0.04),
              child: Transform.scale(
                scale:
                    scaleBase +
                    (0.028 *
                        math.sin(((progress + (index * 0.18)) * math.pi * 2))),
                child: Container(
                  width: ringSize + (index * 16),
                  height: ringSize + (index * 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tokens.accent.withValues(
                        alpha: 0.18 - (index * 0.03),
                      ),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          Transform.rotate(
            angle: progress * math.pi * 2,
            child: SizedBox.square(
              dimension: orbitSize,
              child: Stack(
                children: <Widget>[
                  Align(
                    alignment: Alignment.topCenter,
                    child: _OrbitMarker(
                      color: tokens.accent,
                      glowColor: tokens.accent.withValues(alpha: 0.26),
                      size: 9,
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0.78, -0.10),
                    child: _OrbitMarker(
                      color: tokens.primary,
                      glowColor: tokens.primary.withValues(alpha: 0.22),
                      size: 7,
                    ),
                  ),
                  Align(
                    alignment: const Alignment(-0.72, 0.62),
                    child: _OrbitMarker(
                      color: tokens.accent.withValues(alpha: 0.9),
                      glowColor: tokens.accent.withValues(alpha: 0.18),
                      size: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Transform.rotate(
            angle: -progress * math.pi * 1.2,
            child: SizedBox.square(
              dimension: ringSize + 22,
              child: Stack(
                children: <Widget>[
                  Align(
                    alignment: const Alignment(0.84, 0),
                    child: _OrbitMarker(
                      color: Colors.white.withValues(alpha: 0.92),
                      glowColor: tokens.primary.withValues(alpha: 0.18),
                      size: 5,
                    ),
                  ),
                  Align(
                    alignment: const Alignment(-0.86, 0.18),
                    child: _OrbitMarker(
                      color: tokens.accent.withValues(alpha: 0.88),
                      glowColor: tokens.accent.withValues(alpha: 0.14),
                      size: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: ringSize,
            height: ringSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: tokens.primary.withValues(
                    alpha: 0.06 + (basePulse * 0.04),
                  ),
                  blurRadius: 16,
                  spreadRadius: -10,
                ),
              ],
            ),
          ),
          Container(
            width: ringSize - 20,
            height: ringSize - 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: tokens.surfaceHighlight.withValues(alpha: 0.80),
              ),
            ),
          ),
          Container(
            width: ringSize - 48,
            height: ringSize - 48,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: <Color>[
                  tokens.primary.withValues(alpha: 0.34 + (basePulse * 0.06)),
                  tokens.accent.withValues(alpha: 0.10),
                  tokens.primary.withValues(alpha: 0.02),
                ],
                stops: const <double>[0.0, 0.62, 1.0],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: tokens.accent.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: Transform.rotate(
              angle: progress * math.pi * 2,
              child: const Icon(
                Icons.auto_mode_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitMarker extends StatelessWidget {
  const _OrbitMarker({
    required this.color,
    required this.glowColor,
    required this.size,
  });

  final Color color;
  final Color glowColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: glowColor.withValues(alpha: 0.55),
            blurRadius: size * 1.6,
            spreadRadius: size * 0.15,
          ),
        ],
      ),
    );
  }
}

class _StageMetric extends StatelessWidget {
  const _StageMetric({
    required this.icon,
    required this.title,
    required this.value,
    this.alignEnd = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 126),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.68)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: textAlign,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.58),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageLabel extends StatelessWidget {
  const _StageLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StudioSpacing.sm,
          vertical: StudioSpacing.xs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.l10n,
    required this.authController,
    required this.mode,
    // ignore: unused_element_parameter
    this.errorMessage,
    required this.confirmPasswordController,
    required this.onModeChanged,
    required this.onSubmit,
    required this.compact,
  });

  final AppLocalizations l10n;
  final AuthController authController;
  final _AuthMode mode;
  final String? errorMessage;
  final TextEditingController confirmPasswordController;
  final ValueChanged<_AuthMode> onModeChanged;
  final VoidCallback onSubmit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final studio = StudioColors.of(context);
    final title = mode == _AuthMode.signIn ? l10n.authSignIn : l10n.authSignUp;
    final submitIcon = mode == _AuthMode.signIn
        ? Icons.login_rounded
        : Icons.person_add_alt_1_rounded;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.bgSurface.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? StudioSpacing.sm + 4 : StudioLayoutSpacing.section,
          compact ? StudioSpacing.sm + 4 : StudioLayoutSpacing.section,
          compact ? StudioSpacing.sm + 4 : StudioLayoutSpacing.section,
          compact ? StudioSpacing.sm + 2 : StudioLayoutSpacing.section - 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  l10n.productLoginWorkspaceAccess,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.bgSurface.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: tokens.primary.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      l10n.productLoginAiRuntime,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _AuthModeToggle(mode: mode, onChanged: onModeChanged),
            const SizedBox(height: 22),
            if (!kSupabaseConfigured)
              Text(
                l10n.authSupabaseNotConfigured,
                style: studioHintStyle(
                  context,
                )?.copyWith(color: theme.colorScheme.error),
              )
            else ...<Widget>[
              TextField(
                key: const Key('product-auth-email'),
                controller: authController.emailController,
                decoration: InputDecoration(
                  labelText: l10n.authEmailFieldLabel,
                  hintText: kDebugMode ? kDevAdminEmail : null,
                  prefixIcon: const Icon(
                    Icons.alternate_email_rounded,
                    size: 18,
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('product-auth-password'),
                controller: authController.passwordController,
                decoration: InputDecoration(
                  labelText: l10n.authPasswordFieldLabel,
                  hintText: kDebugMode ? kDevAdminPassword : null,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                ),
                obscureText: true,
                autofillHints: const <String>[AutofillHints.password],
                textInputAction: mode == _AuthMode.signUp
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: (_) {
                  if (mode == _AuthMode.signIn) {
                    onSubmit();
                  }
                },
              ),
              if (mode == _AuthMode.signUp) ...<Widget>[
                const SizedBox(height: 14),
                TextField(
                  key: const Key('product-auth-password-confirm'),
                  controller: confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: l10n.productLoginConfirmPasswordLabel,
                    prefixIcon: const Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                    ),
                  ),
                  obscureText: true,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit(),
                ),
              ],
              if (errorMessage != null && errorMessage!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(StudioSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(
                      alpha: 0.40,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: studioHintStyle(
                            context,
                          )?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: studio.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: tokens.primary.withValues(alpha: 0.10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  key: const Key('product-auth-submit'),
                  onPressed: onSubmit,
                  icon: Icon(submitIcon, size: 16),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  label: Text(title),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                mode == _AuthMode.signIn
                    ? l10n.productLoginSignInHint
                    : l10n.productLoginSignUpHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({required this.mode, required this.onChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bgInset,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Stack(
          children: <Widget>[
            AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: mode == _AuthMode.signIn
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF7C6CF0), Color(0xFF6355D4)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ToggleSegment(
                    key: const Key('auth-mode-sign-in'),
                    selected: mode == _AuthMode.signIn,
                    label: AppLocalizations.of(context)!.authSignIn,
                    onTap: () => onChanged(_AuthMode.signIn),
                  ),
                ),
                Expanded(
                  child: _ToggleSegment(
                    key: const Key('auth-mode-sign-up'),
                    selected: mode == _AuthMode.signUp,
                    label: AppLocalizations.of(context)!.authSignUp,
                    onTap: () => onChanged(_AuthMode.signUp),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.64),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _BackdropGridPainter extends CustomPainter {
  const _BackdropGridPainter({
    required this.progress,
    required this.lineColor,
    required this.accentColor,
    required this.accentColorTwo,
  });

  final double progress;
  final Color lineColor;
  final Color accentColor;
  final Color accentColorTwo;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    const gridSize = 42.0;

    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final sweepPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              accentColor.withValues(alpha: 0),
              accentColor,
              accentColorTwo,
              accentColorTwo.withValues(alpha: 0),
            ],
            stops: const <double>[0.0, 0.35, 0.65, 1.0],
          ).createShader(
            Rect.fromLTWH(
              size.width * (progress - 0.28),
              0,
              size.width * 0.42,
              size.height,
            ),
          );
    canvas.drawRect(Offset.zero & size, sweepPaint);

    final pathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accentColor.withValues(alpha: 0.24);
    final path = Path()
      ..moveTo(0, size.height * 0.22)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.08,
        size.width * 0.38,
        size.height * 0.36,
        size.width * 0.58,
        size.height * 0.26,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.18,
        size.width * 0.84,
        size.height * 0.42,
        size.width,
        size.height * 0.28,
      );
    canvas.drawPath(path, pathPaint);

    final lowerPath = Path()
      ..moveTo(size.width * 0.06, size.height * 0.78)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.62,
        size.width * 0.52,
        size.height * 0.84,
        size.width * 0.76,
        size.height * 0.66,
      )
      ..cubicTo(
        size.width * 0.88,
        size.height * 0.58,
        size.width * 0.94,
        size.height * 0.48,
        size.width,
        size.height * 0.52,
      );
    canvas.drawPath(
      lowerPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accentColorTwo.withValues(alpha: 0.14),
    );

    final horizontalBandY =
        size.height * (0.18 + (0.64 * ((progress * 1.12) % 1)));
    final horizontalBandRect = Rect.fromLTWH(
      0,
      horizontalBandY - 18,
      size.width,
      36,
    );
    canvas.drawRect(
      horizontalBandRect,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            accentColorTwo.withValues(alpha: 0),
            accentColorTwo.withValues(alpha: 0.07),
            accentColorTwo.withValues(alpha: 0),
          ],
        ).createShader(horizontalBandRect),
    );

    void drawProbe(Path probePath, double phase, Color color) {
      final metric = probePath.computeMetrics().first;
      final tangent = metric.getTangentForOffset(metric.length * phase);
      if (tangent == null) {
        return;
      }
      final point = tangent.position;
      canvas.drawCircle(
        point,
        10,
        Paint()..color = color.withValues(alpha: 0.08),
      );
      canvas.drawCircle(
        point,
        2.6,
        Paint()..color = color.withValues(alpha: 0.92),
      );
    }

    drawProbe(path, progress, accentColorTwo);
    drawProbe(lowerPath, (progress + 0.34) % 1.0, accentColor);
  }

  @override
  bool shouldRepaint(covariant _BackdropGridPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.accentColorTwo != accentColorTwo;
  }
}

class _AiStagePainter extends CustomPainter {
  const _AiStagePainter({
    required this.progress,
    required this.lineColor,
    required this.accentColor,
    required this.accentColorTwo,
  });

  final double progress;
  final Color lineColor;
  final Color accentColor;
  final Color accentColorTwo;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.48);
    final frame = Rect.fromCenter(
      center: center,
      width: size.width * 0.56,
      height: size.height * 0.42,
    );
    final pulseBase = (0.5 + (0.5 * math.sin(progress * math.pi * 2)));

    canvas.drawCircle(
      center,
      (math.min(size.width, size.height) * 0.17).toDouble(),
      Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                accentColorTwo.withValues(alpha: 0.12 + (pulseBase * 0.04)),
                accentColor.withValues(alpha: 0.04),
                accentColor.withValues(alpha: 0),
              ],
              stops: const <double>[0.0, 0.58, 1.0],
            ).createShader(
              Rect.fromCircle(
                center: center,
                radius: (math.min(size.width, size.height) * 0.17).toDouble(),
              ),
            ),
    );

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = lineColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, const Radius.circular(24)),
      ringPaint,
    );
    canvas.drawCircle(
      center,
      (math.min(size.width, size.height) * 0.14).toDouble(),
      ringPaint,
    );
    for (var i = 0; i < 3; i++) {
      final wave = ((progress + (i * 0.24)) % 1.0);
      canvas.drawCircle(
        center,
        (math.min(size.width, size.height) * (0.10 + (wave * 0.13))).toDouble(),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = accentColorTwo.withValues(alpha: (1 - wave) * 0.14),
      );
    }

    void drawCornerBracket(Offset start, Offset horizontal, Offset vertical) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accentColorTwo.withValues(alpha: 0.22);
      canvas.drawLine(start, horizontal, paint);
      canvas.drawLine(start, vertical, paint);
    }

    drawCornerBracket(
      Offset(frame.left + 18, frame.top + 18),
      Offset(frame.left + 40, frame.top + 18),
      Offset(frame.left + 18, frame.top + 40),
    );
    drawCornerBracket(
      Offset(frame.right - 18, frame.top + 18),
      Offset(frame.right - 40, frame.top + 18),
      Offset(frame.right - 18, frame.top + 40),
    );
    drawCornerBracket(
      Offset(frame.left + 18, frame.bottom - 18),
      Offset(frame.left + 40, frame.bottom - 18),
      Offset(frame.left + 18, frame.bottom - 40),
    );
    drawCornerBracket(
      Offset(frame.right - 18, frame.bottom - 18),
      Offset(frame.right - 40, frame.bottom - 18),
      Offset(frame.right - 18, frame.bottom - 40),
    );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accentColor.withValues(alpha: 0.42);

    final arcs = <Path>[
      Path()
        ..moveTo(size.width * 0.12, size.height * 0.72)
        ..quadraticBezierTo(
          size.width * 0.28,
          size.height * 0.55,
          center.dx,
          center.dy,
        )
        ..quadraticBezierTo(
          size.width * 0.72,
          size.height * 0.30,
          size.width * 0.88,
          size.height * 0.24,
        ),
      Path()
        ..moveTo(size.width * 0.16, size.height * 0.18)
        ..quadraticBezierTo(
          size.width * 0.34,
          size.height * 0.34,
          center.dx,
          center.dy,
        )
        ..quadraticBezierTo(
          size.width * 0.70,
          size.height * 0.66,
          size.width * 0.84,
          size.height * 0.78,
        ),
      Path()
        ..moveTo(size.width * 0.22, size.height * 0.48)
        ..lineTo(size.width * 0.78, size.height * 0.48),
    ];

    for (final (index, path) in arcs.indexed) {
      canvas.drawPath(path, linePaint);
      final metric = path.computeMetrics().first;
      final packetProgress = (progress + (index * 0.18)) % 1.0;
      final offset = metric
          .getTangentForOffset(metric.length * packetProgress)!
          .position;
      final trailOffset = metric
          .getTangentForOffset(
            metric.length * math.max(0, packetProgress - 0.06),
          )!
          .position;
      canvas.drawLine(
        trailOffset,
        offset,
        Paint()
          ..color = accentColorTwo.withValues(alpha: 0.24)
          ..strokeWidth = 1.8,
      );
      canvas.drawCircle(
        offset,
        9,
        Paint()..color = accentColorTwo.withValues(alpha: 0.08),
      );
      canvas.drawCircle(offset, 3.4, Paint()..color = accentColorTwo);
    }

    final nodes = <Offset>[
      Offset(size.width * 0.12, size.height * 0.72),
      Offset(size.width * 0.16, size.height * 0.18),
      Offset(size.width * 0.22, size.height * 0.48),
      Offset(size.width * 0.78, size.height * 0.48),
      Offset(size.width * 0.84, size.height * 0.78),
      Offset(size.width * 0.88, size.height * 0.24),
      center,
    ];

    for (final node in nodes) {
      canvas.drawCircle(
        node,
        5,
        Paint()..color = accentColor.withValues(alpha: 0.18),
      );
      canvas.drawCircle(node, 2.4, Paint()..color = accentColorTwo);
    }

    final radarRect = Rect.fromCircle(
      center: center,
      radius: (math.min(size.width, size.height) * 0.18).toDouble(),
    );
    canvas.drawArc(
      radarRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = SweepGradient(
          colors: <Color>[
            accentColorTwo.withValues(alpha: 0),
            accentColorTwo.withValues(alpha: 0.05),
            accentColorTwo.withValues(alpha: 0.44),
            accentColorTwo.withValues(alpha: 0),
          ],
          stops: const <double>[0.0, 0.62, 0.78, 1.0],
          transform: GradientRotation(progress * math.pi * 2),
        ).createShader(radarRect),
    );

    final sweepX = size.width * (0.16 + (0.68 * progress));
    canvas.drawLine(
      Offset(sweepX, size.height * 0.14),
      Offset(sweepX, size.height * 0.82),
      Paint()
        ..color = accentColorTwo.withValues(alpha: 0.22)
        ..strokeWidth = 1.2,
    );
    final sweepY = size.height * (0.22 + (0.52 * ((progress + 0.28) % 1.0)));
    canvas.drawLine(
      Offset(size.width * 0.16, sweepY),
      Offset(size.width * 0.84, sweepY),
      Paint()
        ..color = accentColor.withValues(alpha: 0.10)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _AiStagePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.accentColorTwo != accentColorTwo;
  }
}

