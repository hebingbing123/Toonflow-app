# Accessibility Guidelines (A11y)

## Overview

This document outlines accessibility requirements and best practices for the Toonflow Studio Flutter UI. All new components and features must meet WCAG 2.1 Level AA standards.

## Core Principles

1. **Perceivable** - Information must be presentable to users in ways they can perceive
2. **Operable** - UI components must be operable by all users
3. **Understandable** - Information and operation must be understandable
4. **Robust** - Content must be robust enough to work with assistive technologies

---

## 1. Semantic Labels & Screen Readers

### Icon-Only Buttons

**❌ WRONG:**
```dart
IconButton(
  tooltip: 'Close dialog',  // Tooltips are NOT accessible to screen readers
  icon: const Icon(Icons.close),
  onPressed: () => Navigator.pop(context),
)
```

**✅ CORRECT:**
```dart
StudioIconButton(
  icon: Icons.close,
  label: 'Close dialog',  // Used for both tooltip AND semantics
  onPressed: () => Navigator.pop(context),
)
```

### Custom Interactive Widgets

Always wrap custom interactive widgets with `Semantics`:

```dart
Semantics(
  button: true,
  label: 'Descriptive action',
  enabled: onPressed != null,
  child: GestureDetector(
    onTap: onPressed,
    child: CustomWidget(),
  ),
)
```

### Decorative Icons

Use `ExcludeSemantics` or `studioDecorativeIcon` for purely decorative icons:

```dart
// When icon is adjacent to text that conveys the same meaning
ExcludeSemantics(
  child: Icon(Icons.info),
)

// Or use the helper
studioDecorativeIcon(Icons.info)
```

### Form Fields

Always provide labels for form fields:

```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Email address',  // Required for screen readers
    hintText: 'you@example.com',
  ),
)
```

---

## 2. Text Scale Resilience

### Fixed Heights - AVOID

**❌ WRONG:**
```dart
Container(
  height: 36,  // Fixed height will cause overflow at large text scales
  child: Text('Label'),
)
```

**✅ CORRECT:**
```dart
// Option 1: Use minHeight
Container(
  constraints: BoxConstraints(minHeight: 36),
  child: Text('Label'),
)

// Option 2: Use padding instead
Padding(
  padding: EdgeInsets.symmetric(vertical: 8),
  child: Text('Label'),
)

// Option 3: Let content determine size
IntrinsicHeight(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [Text('Label')],
  ),
)
```

### Testing Text Scale

Test your UI at multiple text scale factors:

```dart
// In tests or development
MediaQuery(
  data: MediaQuery.of(context).copyWith(
    textScaleFactor: 2.0,  // 200% text size
  ),
  child: YourWidget(),
)
```

**Required test scales:**
- 100% (default) - All text visible
- 150% - No overflow, all text readable
- 200% - Critical UI still functional
- 300% - Graceful degradation acceptable

### Text Scale Helpers

```dart
// Check if user has large text scale
bool isLargeTextScale(BuildContext context) {
  return MediaQuery.textScaleFactorOf(context) >= 1.5;
}

// Clamp text scale to prevent extreme overflow
double clampedTextScale(BuildContext context, {double max = 2.0}) {
  return MediaQuery.textScaleFactorOf(context).clamp(1.0, max);
}
```

---

## 3. Color Contrast

### WCAG Requirements

- **Normal text (< 18pt):** Minimum 4.5:1 contrast ratio
- **Large text (≥ 18pt or ≥ 14pt bold):** Minimum 3:1 contrast ratio
- **UI components & graphics:** Minimum 3:1 contrast ratio

### Current Theme Contrast Ratios

| Combination | Ratio | Status |
|-------------|-------|--------|
| textPrimary on bgBase | 14.2:1 | ✅ Excellent |
| textPrimary on bgSurface | 12.8:1 | ✅ Excellent |
| textSecondary on bgBase | 7.8:1 | ✅ Good |
| textSecondary on bgSurface | 7.1:1 | ✅ Good |
| textMuted on bgBase | 5.1:1 | ✅ Pass |
| textMuted on bgSurface | 4.6:1 | ✅ Pass |
| textMuted on bgElevated | 5.1:1 | ✅ Pass |

### Avoid Alpha Transparency on Text

**❌ WRONG:**
```dart
Text(
  'Label',
  style: TextStyle(
    color: tokens.textSecondary.withValues(alpha: 0.7),  // Reduces contrast
  ),
)
```

**✅ CORRECT:**
```dart
Text(
  'Label',
  style: TextStyle(
    color: tokens.textMuted,  // Use semantic color token
  ),
)
```

### Testing Contrast

Use online tools or browser extensions:
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- Chrome DevTools Accessibility Panel
- [Colour Contrast Analyser](https://www.tpgi.com/color-contrast-checker/)

---

## 4. Focus Management

### Keyboard Navigation

Ensure all interactive elements are keyboard accessible:

```dart
// Focus nodes for custom widgets
final _focusNode = FocusNode();

@override
void dispose() {
  _focusNode.dispose();
  super.dispose();
}

// In build method
Focus(
  focusNode: _focusNode,
  child: GestureDetector(
    onTap: () => _focusNode.requestFocus(),
    child: CustomWidget(),
  ),
)
```

### Focus Indicators

Ensure focus indicators are visible:

```dart
focusColor: tokens.primary.withValues(alpha: 0.35),
```

---

## 5. Touch Targets

### Minimum Size

All interactive elements must meet minimum touch target sizes:

- **Mobile:** 48x48 dp (Material Design guideline)
- **Desktop:** 44x44 dp minimum

```dart
// Use StudioSpacing constants
IconButton(
  style: IconButton.styleFrom(
    minimumSize: const Size(
      StudioSpacing.iconTouchTarget,  // 48dp
      StudioSpacing.iconTouchTarget,
    ),
  ),
  icon: Icon(Icons.close),
  onPressed: () {},
)
```

---

## 6. Motion & Animation

### Respect Reduced Motion

Check user's motion preferences:

```dart
bool reduceMotion = MediaQuery.of(context).disableAnimations;

Duration duration = reduceMotion 
  ? Duration.zero 
  : const Duration(milliseconds: 300);
```

### Animation Guidelines

- Keep animations under 400ms
- Provide option to disable non-essential animations
- Avoid flashing content (no more than 3 flashes per second)

---

## 7. Component Checklist

Use this checklist when creating new components:

### Interactive Components
- [ ] Has semantic label (not just tooltip)
- [ ] Announces state changes to screen readers
- [ ] Minimum 48x48 dp touch target
- [ ] Visible focus indicator
- [ ] Keyboard accessible
- [ ] Works at 200% text scale
- [ ] Meets contrast requirements

### Text Components
- [ ] Uses semantic color tokens (not hardcoded colors)
- [ ] No fixed heights that could cause overflow
- [ ] Readable at 200% text scale
- [ ] Meets 4.5:1 contrast ratio

### Layout Components
- [ ] Responsive to text scale changes
- [ ] No horizontal scrolling at 200% text scale
- [ ] Logical reading order
- [ ] Proper heading hierarchy

---

## 8. Testing

### Manual Testing

**Screen Readers:**
- iOS: VoiceOver (Settings → Accessibility → VoiceOver)
- Android: TalkBack (Settings → Accessibility → TalkBack)
- macOS: VoiceOver (System Preferences → Accessibility → VoiceOver)

**Text Scale:**
- iOS: Settings → Display & Brightness → Text Size
- Android: Settings → Display → Font size
- macOS: System Preferences → Accessibility → Display → Larger Text

**Keyboard Navigation:**
- Tab through all interactive elements
- Verify focus indicators are visible
- Test all actions with keyboard only

### Automated Testing

```dart
testWidgets('Button has semantic label', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StudioIconButton(
          icon: Icons.close,
          label: 'Close',
          onPressed: () {},
        ),
      ),
    ),
  );

  // Verify semantic label exists
  expect(
    find.bySemanticsLabel('Close'),
    findsOneWidget,
  );
});

testWidgets('Text scales without overflow', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaleFactor: 2.0),
        child: YourWidget(),
      ),
    ),
  );

  await tester.pumpAndSettle();
  
  // Verify no overflow
  expect(tester.takeException(), isNull);
});
```

---

## 9. Resources

### WCAG Guidelines
- [WCAG 2.1 Quick Reference](https://www.w3.org/WAI/WCAG21/quickref/)
- [Material Design Accessibility](https://material.io/design/usability/accessibility.html)
- [Flutter Accessibility](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)

### Tools
- [Accessibility Scanner (Android)](https://play.google.com/store/apps/details?id=com.google.android.apps.accessibility.auditor)
- [Accessibility Inspector (Xcode)](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/OSXAXTestingApps.html)
- [axe DevTools](https://www.deque.com/axe/devtools/)

### Testing Checklist
- [ ] All icon buttons have semantic labels
- [ ] No text overflow at 200% text scale
- [ ] All text meets contrast requirements
- [ ] All interactive elements keyboard accessible
- [ ] Focus indicators visible
- [ ] Screen reader announces all content correctly
- [ ] Touch targets meet minimum size
- [ ] Respects reduced motion preference

---

## 10. Common Patterns

### Accessible Icon Button
```dart
StudioIconButton(
  icon: Icons.edit,
  label: 'Edit item',
  onPressed: () => editItem(),
)
```

### Accessible Custom Button
```dart
Semantics(
  button: true,
  label: 'Custom action',
  enabled: enabled,
  child: Tooltip(
    message: 'Custom action',
    child: GestureDetector(
      onTap: enabled ? onTap : null,
      child: CustomButtonWidget(),
    ),
  ),
)
```

### Accessible List Item
```dart
Semantics(
  label: 'Project: ${project.name}',
  button: true,
  child: ListTile(
    title: Text(project.name),
    onTap: () => openProject(project),
  ),
)
```

### Accessible Form
```dart
Form(
  child: Column(
    children: [
      TextFormField(
        decoration: InputDecoration(
          labelText: 'Email',  // Required
          hintText: 'you@example.com',
        ),
        validator: (value) => validateEmail(value),
      ),
      Semantics(
        liveRegion: true,  // Announces validation errors
        child: Text(errorMessage),
      ),
    ],
  ),
)
```

---

## Questions?

For accessibility questions or to report issues, contact the design system team or file an issue in the repository.
