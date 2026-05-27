# Accessibility Quick Reference Card

## 🚀 Quick Start

### Icon-Only Buttons

```dart
// ❌ WRONG
IconButton(
  tooltip: 'Close',
  icon: Icon(Icons.close),
  onPressed: () {},
)

// ✅ CORRECT
StudioIconButton(
  icon: Icons.close,
  label: 'Close',
  onPressed: () {},
)
```

### Custom Interactive Widgets

```dart
// ✅ Add Semantics wrapper
Semantics(
  button: true,
  label: 'Action description',
  enabled: onPressed != null,
  child: GestureDetector(
    onTap: onPressed,
    child: CustomWidget(),
  ),
)
```

### Decorative Icons

```dart
// ✅ Exclude from screen readers
ExcludeSemantics(
  child: Icon(Icons.info),
)

// Or use helper
studioDecorativeIcon(Icons.info)
```

---

## 📏 Layout Rules

### Fixed Heights - AVOID

```dart
// ❌ WRONG - Will overflow at large text scale
Container(
  height: 36,
  child: Text('Label'),
)

// ✅ CORRECT - Use minHeight
Container(
  constraints: BoxConstraints(minHeight: 36),
  child: Text('Label'),
)

// ✅ CORRECT - Use padding
Padding(
  padding: EdgeInsets.symmetric(vertical: 8),
  child: Text('Label'),
)
```

---

## 🎨 Color Contrast

### Use Semantic Tokens

```dart
// ❌ WRONG - Hardcoded color
Text('Label', style: TextStyle(color: Color(0xFF667892)))

// ✅ CORRECT - Semantic token
Text('Label', style: TextStyle(color: tokens.textMuted))
```

### Avoid Alpha on Text

```dart
// ❌ WRONG - Reduces contrast
color: tokens.textSecondary.withValues(alpha: 0.7)

// ✅ CORRECT - Use semantic color
color: tokens.textMuted
```

---

## 🎯 Touch Targets

### Minimum Sizes

```dart
// ✅ Use constants
IconButton(
  style: IconButton.styleFrom(
    minimumSize: Size(
      StudioSpacing.iconTouchTarget,  // 48dp
      StudioSpacing.iconTouchTarget,
    ),
  ),
  icon: Icon(Icons.close),
  onPressed: () {},
)
```

---

## ✅ Component Checklist

Before submitting code, verify:

- [ ] Icon buttons have semantic labels (not just tooltips)
- [ ] No fixed heights that could cause text overflow
- [ ] Uses semantic color tokens (not hardcoded colors)
- [ ] Touch targets are at least 48x48 dp
- [ ] Tested at 200% text scale
- [ ] Keyboard accessible

---

## 🧪 Quick Tests

### Screen Reader Test
```bash
# iOS: Enable VoiceOver
Settings → Accessibility → VoiceOver

# Android: Enable TalkBack
Settings → Accessibility → TalkBack
```

### Text Scale Test
```dart
// Wrap widget with scaled MediaQuery
MediaQuery(
  data: MediaQuery.of(context).copyWith(
    textScaleFactor: 2.0,  // 200%
  ),
  child: YourWidget(),
)
```

---

## 📚 Full Documentation

See `ACCESSIBILITY.md` for complete guidelines, examples, and testing procedures.

---

## 🆘 Common Issues

### "My IconButton doesn't announce"
→ Use `StudioIconButton` instead, or add `Semantics` wrapper

### "Text overflows at large scale"
→ Replace `height:` with `minHeight:` or remove fixed height

### "Low contrast warning"
→ Use semantic color tokens instead of hardcoded colors

### "Touch target too small"
→ Use `StudioSpacing.iconTouchTarget` for minimum size

---

## 🔗 Quick Links

- Full Guidelines: `ACCESSIBILITY.md`
- Audit Report: `.tmp/a11y_audit_report.md`
- Progress Tracking: `.tmp/a11y_implementation_progress.md`
- Component Docs: `components/studio_icon_button.dart`
