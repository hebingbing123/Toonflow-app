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
    duration: const Duration(seconds: 18),
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
      setState(() {
        _localErrorMessage = _localized(
          context,
          zh: '两次输入的密码不一致。',
          en: 'Passwords do not match.',
        );
      });
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
                                  errorMessage:
                                      _localErrorMessage ?? widget.errorMessage,
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
                          errorMessage:
                              _localErrorMessage ?? widget.errorMessage,
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
    final displaySize = compact
        ? math.max(typography.display - 1, 27).toDouble()
        : typography.display + 10;

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
            _localized(
              context,
              zh: '把剧本、镜头、任务和发布串成一条 AI 生产链',
              en: 'Turn scripts, shots, jobs, and release into one AI pipeline.',
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: displaySize,
              height: 1.05,
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
          spacing: 10,
          runSpacing: 10,
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
            _SignalChip(
              icon: Icons.task_alt_outlined,
              label: l10n.productNavTasks,
            ),
            _SignalChip(
              icon: Icons.cloud_queue_outlined,
              label: l10n.productNavJobs,
            ),
            _SignalChip(
              icon: Icons.verified_outlined,
              label: l10n.productNavQuality,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (compact)
          SizedBox(
            height: 300,
            child: _AiStagePanel(compact: compact, progress: progress),
          )
        else
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 420),
              child: _AiStagePanel(compact: compact, progress: progress),
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
  const _AiStagePanel({required this.compact, required this.progress});

  final bool compact;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final typography = StudioTypography.of(context);
    final ringSize = compact ? 124.0 : 156.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 26,
            offset: const Offset(0, 18),
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
                    title: _localized(
                      context,
                      zh: '模型编排',
                      en: 'Model Orchestration',
                    ),
                    value: _localized(context, zh: '在线', en: 'Online'),
                  ),
                  _StageMetric(
                    icon: Icons.memory_outlined,
                    title: _localized(
                      context,
                      zh: '推理通道',
                      en: 'Inference Lanes',
                    ),
                    value: _localized(context, zh: '低延迟', en: 'Low Latency'),
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
                title: _localized(
                  context,
                  zh: '模型编排',
                  en: 'Model Orchestration',
                ),
                value: _localized(context, zh: '在线', en: 'Online'),
              ),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: _StageMetric(
                icon: Icons.memory_outlined,
                title: _localized(context, zh: '推理通道', en: 'Inference Lanes'),
                value: _localized(context, zh: '低延迟', en: 'Low Latency'),
                alignEnd: true,
              ),
            ),
          ],
          Center(
            child: Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Container(
                  width: ringSize - 48,
                  height: ringSize - 48,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: <Color>[
                        tokens.primary.withValues(alpha: 0.38),
                        tokens.primary.withValues(alpha: 0.04),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tokens.accent.withValues(alpha: 0.26),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_mode_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),
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
                  label: _localized(
                    context,
                    zh: '多步骤编排',
                    en: 'Multi-step Orchestration',
                  ),
                ),
                _StageLabel(
                  label: _localized(
                    context,
                    zh: '镜头级生成',
                    en: 'Shot-level Generation',
                  ),
                ),
                _StageLabel(
                  label: _localized(context, zh: '闭环发布', en: 'Release Loop'),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            bottom: compact ? 64 : 86,
            child: Text(
              _localized(
                context,
                zh: '从脚本理解到最终发布，AI 在同一条工作流里接力。',
                en: 'AI hands work across the same flow, from script reading to release.',
              ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: const Color(0xFF00CEC9)),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    required this.errorMessage,
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
        color: tokens.bgSurface.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 20 : 24,
          compact ? 20 : 24,
          compact ? 20 : 24,
          compact ? 18 : 22,
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
                  _localized(context, zh: '工作区访问', en: 'Workspace Access'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: studio.primaryGradient.colors.first.withValues(
                        alpha: 0.24,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      _localized(context, zh: 'AI Runtime', en: 'AI Runtime'),
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: Column(
                key: ValueKey<_AuthMode>(mode),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: studioPageTitleStyle(context)),
                  const SizedBox(height: 8),
                  Text(
                    mode == _AuthMode.signIn
                        ? _localized(
                            context,
                            zh: '进入你的工作区，继续脚本、制作、任务与发布链路。',
                            en: 'Return to your workspace and keep scripts, production, jobs, and release in flow.',
                          )
                        : _localized(
                            context,
                            zh: '创建一个工作区账号，让 AI 生产链从第一部短剧开始运转。',
                            en: 'Create a workspace account and bring the AI production loop online.',
                          ),
                    style: studioSectionIntroStyle(context),
                  ),
                ],
              ),
            ),
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
                    labelText: _localized(
                      context,
                      zh: '确认密码',
                      en: 'Confirm Password',
                    ),
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
                  padding: const EdgeInsets.all(12),
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
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
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
                    ? _localized(
                        context,
                        zh: '使用同一工作区账号继续你的生产节奏。',
                        en: 'Use the same workspace account to keep momentum.',
                      )
                    : _localized(
                        context,
                        zh: '注册后可直接进入项目、任务与发布工作区。',
                        en: 'After sign up, step straight into projects, jobs, and release.',
                      ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (kDebugMode) ...<Widget>[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.bgInset,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _localized(
                          context,
                          zh: '本地开发账号',
                          en: 'Local Development Account',
                        ),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.productShellDevCredentialsHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

    for (final path in arcs) {
      canvas.drawPath(path, linePaint);
      final metric = path.computeMetrics().first;
      final offset = metric
          .getTangentForOffset(metric.length * progress)!
          .position;
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

    final sweepX = size.width * (0.16 + (0.68 * progress));
    canvas.drawLine(
      Offset(sweepX, size.height * 0.14),
      Offset(sweepX, size.height * 0.82),
      Paint()
        ..color = accentColorTwo.withValues(alpha: 0.22)
        ..strokeWidth = 1.2,
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

String _localized(
  BuildContext context, {
  required String zh,
  required String en,
}) {
  return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
}
