# Accessibility (A11y) Audit Report
**Date:** 2026-05-27  
**Scope:** Flutter UI Architecture - Full Codebase

## Executive Summary

This audit identifies three critical accessibility categories requiring remediation:
1. **Semantic Labels** - Icon-only buttons missing screen reader support
2. **Text Scale Resilience** - Fixed-height containers causing overflow
3. **Color Contrast** - Insufficient contrast ratios in current theme

---

## 1. Semantic Labels & Screen Reader Support

### Issues Found

#### 1.1 Icon-Only Buttons Without Semantics
**Severity:** HIGH  
**Impact:** Screen reader users cannot understand button functions

**Affected Components:**
- `frontend/lib/product_shell/studio_app_bar_actions.dart` - _UtilityIconButton (notifications, settings, help)
- `frontend/lib/project_editor/assets/dialogs/candidate_status_dialog.dart` - Navigation buttons (prev/next)
- `frontend/lib/project_editor/scripts/section_view.dart` - Edit button
- `frontend/lib/storyboard_editor/character_section.dart` - Reload button
- `frontend/lib/notifications/section.dart` - Template management buttons (move up/down, edit, delete)
- `frontend/lib/product_shell/studio_agent_drawer.dart` - Close button

**Current Pattern:**
```dart
IconButton(
  tooltip: 'Some action',
  icon: const Icon(Icons.some_icon),
  onPressed: () => doSomething(),
)
```

**Problem:** Tooltips are NOT accessible to screen readers. They only appear on hover.

**Required Fix:**
```dart
Semantics(
  button: true,
  label: 'Some action',
  enabled: onPressed != null,
  child: Tooltip(
    message: 'Some action',
    child: IconButton(
      icon: Icon(Icons.some_icon, semanticLabel: 'Some action'),
      onPressed: () => doSomething(),
    ),
  ),
)
```

#### 1.2 Components Already Using Semantics (Good Examples)
- `StudioPrimaryButton` - ✅ Proper Semantics wrapper
- `StudioDropdownField` - ✅ Button semantics with combined labels
- `StudioGettingStartedSteps` - ✅ Step semantics with position info
- `studioDecorativeIcon` - ✅ ExcludeSemantics for decorative icons

---

## 2. Text Scale Factor Resilience

### Issues Found

#### 2.1 Fixed Height Containers
**Severity:** HIGH  
**Impact:** Text truncation/overflow when users increase system font size

**Affected Patterns:**

**Pattern A: Fixed SizedBox Heights**
```dart
// PROBLEM: Text can overflow if user has large text scale
SizedBox(
  height: 36,  // Fixed height
  child: Text('Some label'),
)
```

**Pattern B: Fixed Container Heights**
```dart
Container(
  height: 28,  // Fixed height
  child: Text('Badge'),
)
```

**Pattern C: ConstrainedBox with maxHeight**
```dart
ConstrainedBox(
  constraints: BoxConstraints(maxHeight: 200),
  child: Column(children: [Text('...')]),
)
```

**Affected Files:**
- `frontend/lib/design_system/components/studio_getting_started_steps.dart` - Step indicator circles (28px fixed)
- `frontend/lib/product_shell/studio_app_bar_actions.dart` - Icon button boxes (28px/48px fixed)
- `frontend/lib/design_system/components/studio_primary_button.dart` - Button height from typography
- Multiple dialog and panel components with fixed heights

**Required Fixes:**

**Fix A: Use minHeight instead of height**
```dart
Container(
  constraints: BoxConstraints(minHeight: 28),
  child: Text('Badge'),
)
```

**Fix B: Let content determine height**
```dart
// Remove fixed height, use padding instead
Padding(
  padding: EdgeInsets.symmetric(vertical: 8),
  child: Text('Some label'),
)
```

**Fix C: Use IntrinsicHeight for dynamic sizing**
```dart
IntrinsicHeight(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [...],
  ),
)
```

#### 2.2 Typography System Analysis
**File:** `frontend/lib/design_system/studio_typography.dart`

Current system has three profiles (compact/regular/large) but doesn't account for user's system text scale factor.

**Recommendation:** Add MediaQuery.textScaleFactorOf(context) awareness to critical text components.

---

## 3. Color Contrast Analysis

### Current Theme Colors
**File:** `frontend/lib/design_system/tokens.dart`

#### 3.1 Contrast Ratio Issues

**Background Colors:**
- `bgBase`: #070D15 (very dark)
- `bgSurface`: #101825
- `bgElevated`: #152033
- `bgInset`: #0A1018

**Text Colors:**
- `textPrimary`: #E8F1FF (light)
- `textSecondary`: #A2B4CD (medium)
- `textMuted`: #667892 (darker)

**Contrast Calculations (WCAG 2.1 AA requires 4.5:1 for normal text, 3:1 for large text):**

| Combination | Ratio | Status | Usage |
|-------------|-------|--------|-------|
| textPrimary on bgBase | ~14.2:1 | ✅ PASS | Body text |
| textPrimary on bgSurface | ~12.8:1 | ✅ PASS | Card text |
| textSecondary on bgBase | ~7.8:1 | ✅ PASS | Secondary text |
| textSecondary on bgSurface | ~7.1:1 | ✅ PASS | Hints |
| **textMuted on bgBase** | **~4.2:1** | ⚠️ BORDERLINE | Meta text |
| **textMuted on bgSurface** | **~3.8:1** | ❌ FAIL | Small text |
| **textMuted on bgElevated** | **~3.4:1** | ❌ FAIL | Elevated surfaces |

#### 3.2 Specific Problem Areas

**Issue 1: textMuted (#667892) on elevated surfaces**
- Used in: hints, meta text, disabled states
- Current ratio: 3.4:1 on bgElevated
- Required: 4.5:1 for normal text

**Recommended Fix:**
```dart
// Lighten textMuted from #667892 to #7A8AA5
textMuted: Color(0xFF7A8AA5),  // New ratio: ~5.1:1 on bgElevated
```

**Issue 2: Border colors on dark backgrounds**
- `borderSubtle`: #1B2A3E (very low contrast)
- `borderDefault`: #29435E

These are acceptable for borders (3:1 minimum) but borderSubtle is at the edge.

**Issue 3: Gradient text on gradient backgrounds**
- `StudioColors.primaryGradient` used for buttons
- Text color varies based on gradient position
- Need to ensure minimum contrast at all gradient stops

#### 3.3 Icon Color Contrast

**Problem:** Icon-only buttons using `textSecondary` with alpha transparency:
```dart
color: tokens.textSecondary.withValues(alpha: 0.86)
```

This reduces effective contrast. Should use solid colors for interactive elements.

---

## 4. Remediation Plan

### Phase 1: Semantic Labels (Priority: HIGH)
**Estimated effort:** 4-6 hours

1. Create reusable `StudioIconButton` component with built-in Semantics
2. Update all IconButton instances to use semantic labels
3. Add semantic labels to custom icon-only widgets
4. Test with VoiceOver (iOS) and TalkBack (Android)

**Files to update:**
- [ ] `studio_app_bar_actions.dart`
- [ ] `candidate_status_dialog.dart`
- [ ] `section_view.dart` (scripts)
- [ ] `character_section.dart`
- [ ] `notifications/section.dart`
- [ ] `studio_agent_drawer.dart`
- [ ] All other IconButton instances (search: `IconButton\(`)

### Phase 2: Text Scale Resilience (Priority: HIGH)
**Estimated effort:** 6-8 hours

1. Audit all fixed-height containers
2. Replace `height:` with `minHeight:` where appropriate
3. Add `MediaQuery.textScaleFactorOf(context)` checks for critical UI
4. Test with system text scale at 200% and 300%

**Files to update:**
- [ ] `studio_getting_started_steps.dart`
- [ ] `studio_app_bar_actions.dart`
- [ ] `studio_primary_button.dart`
- [ ] All dialog components
- [ ] All panel components with fixed heights

### Phase 3: Color Contrast (Priority: MEDIUM)
**Estimated effort:** 2-3 hours

1. Update `textMuted` color in `tokens.dart`
2. Review all uses of alpha transparency on text
3. Test contrast ratios with automated tools
4. Visual QA on all screens

**Files to update:**
- [ ] `tokens.dart` - Update textMuted color
- [ ] `theme.dart` - Review alpha usage
- [ ] `studio_app_bar_actions.dart` - Remove alpha from icon colors

### Phase 4: Testing & Validation (Priority: HIGH)
**Estimated effort:** 4-6 hours

1. Manual testing with screen readers (VoiceOver/TalkBack)
2. Automated contrast testing
3. Text scale testing (100%, 150%, 200%, 300%)
4. Create accessibility regression tests

---

## 5. Recommended Design System Additions

### 5.1 New Component: StudioIconButton
```dart
/// Accessible icon button with built-in Semantics and Tooltip
class StudioIconButton extends StatelessWidget {
  const StudioIconButton({
    required this.icon,
    required this.label,  // Used for both tooltip and semantics
    required this.onPressed,
    this.size,
  });
  
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double? size;
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: onPressed != null,
      child: Tooltip(
        message: label,
        child: IconButton(
          icon: Icon(icon, size: size, semanticLabel: label),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
```

### 5.2 Text Scale Helper
```dart
/// Returns true if user has increased text scale significantly
bool isLargeTextScale(BuildContext context) {
  return MediaQuery.textScaleFactorOf(context) >= 1.5;
}

/// Clamps text scale to prevent extreme overflow
double clampedTextScale(BuildContext context, {double max = 2.0}) {
  return MediaQuery.textScaleFactorOf(context).clamp(1.0, max);
}
```

### 5.3 Contrast Checker (Development Tool)
```dart
/// Development-only contrast ratio checker
void assertContrast(Color foreground, Color background, {double minRatio = 4.5}) {
  assert(() {
    final ratio = calculateContrastRatio(foreground, background);
    if (ratio < minRatio) {
      debugPrint('⚠️ Contrast ratio $ratio:1 is below minimum $minRatio:1');
      return false;
    }
    return true;
  }());
}
```

---

## 6. Testing Checklist

### Screen Reader Testing
- [ ] VoiceOver (iOS): All icon buttons announce their function
- [ ] TalkBack (Android): All icon buttons announce their function
- [ ] Navigation order is logical
- [ ] Form fields have proper labels
- [ ] Error messages are announced

### Text Scale Testing
- [ ] 100% (default) - All text visible
- [ ] 150% - No overflow, all text readable
- [ ] 200% - Critical UI still functional
- [ ] 300% - Graceful degradation (acceptable overflow in non-critical areas)

### Color Contrast Testing
- [ ] All body text meets 4.5:1 ratio
- [ ] All large text (18pt+) meets 3:1 ratio
- [ ] All interactive elements meet 3:1 ratio
- [ ] Focus indicators are visible
- [ ] Error states have sufficient contrast

### Automated Testing
- [ ] Run `flutter analyze` with no accessibility warnings
- [ ] Add semantic tests to existing test suites
- [ ] Set up contrast ratio CI checks

---

## 7. Priority Matrix

| Issue | Severity | Impact | Effort | Priority |
|-------|----------|--------|--------|----------|
| Icon button semantics | HIGH | HIGH | Medium | **P0** |
| Fixed height overflow | HIGH | HIGH | Medium | **P0** |
| textMuted contrast | MEDIUM | MEDIUM | Low | **P1** |
| Alpha transparency on icons | MEDIUM | LOW | Low | **P1** |
| Border contrast | LOW | LOW | Low | **P2** |

---

## 8. Success Criteria

✅ **Phase 1 Complete When:**
- All icon-only buttons have semantic labels
- Screen reader announces button functions correctly
- No tooltip-only buttons remain

✅ **Phase 2 Complete When:**
- No text overflow at 200% text scale
- Critical UI functional at 300% text scale
- All fixed heights replaced with min-heights or removed

✅ **Phase 3 Complete When:**
- All text meets WCAG AA contrast ratios
- No alpha transparency on interactive text
- Visual QA passes on all screens

✅ **Project Complete When:**
- All phases complete
- Automated tests added
- Documentation updated
- Design system components created
