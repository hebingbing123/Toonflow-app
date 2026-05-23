#!/usr/bin/env dart
/// Automatic UI/UX issue fixer
/// 
/// This script reads the audit report and automatically applies fixes
/// for spacing and typography issues.

import 'dart:io';
import 'dart:convert';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart auto_fix.dart <audit-report.json>');
    exit(1);
  }

  final reportPath = args[0];
  final reportFile = File(reportPath);
  
  if (!reportFile.existsSync()) {
    print('Error: Report file not found: $reportPath');
    exit(1);
  }

  print('🔧 UI/UX Auto-Fix Tool');
  print('━' * 50);
  
  // Read audit report
  final reportJson = jsonDecode(await reportFile.readAsString());
  final findings = reportJson['findings'] as List;
  
  print('📊 Found ${findings.length} issues to fix\n');
  
  // Group findings by file
  final findingsByFile = <String, List<Map<String, dynamic>>>{};
  for (final finding in findings) {
    final location = finding['location'] as Map<String, dynamic>;
    final file = location['file'] as String;
    findingsByFile.putIfAbsent(file, () => []).add(finding as Map<String, dynamic>);
  }
  
  print('📁 Affected files: ${findingsByFile.length}\n');
  
  int fixedCount = 0;
  int skippedCount = 0;
  
  // Process each file
  for (final entry in findingsByFile.entries) {
    final filePath = entry.key;
    final fileFindings = entry.value;
    
    print('Processing: ${filePath.split('/').last}');
    
    final file = File(filePath);
    if (!file.existsSync()) {
      print('  ⚠️  File not found, skipping');
      skippedCount += fileFindings.length;
      continue;
    }
    
    var content = await file.readAsString();
    final originalContent = content;
    
    // Sort findings by line number (descending) to avoid offset issues
    fileFindings.sort((a, b) {
      final lineA = a['location']['line'] as int;
      final lineB = b['location']['line'] as int;
      return lineB.compareTo(lineA);
    });
    
    // Apply fixes
    for (final finding in fileFindings) {
      final category = finding['category'] as String;
      final description = finding['description'] as String;
      
      if (category == 'spacing') {
        final fixed = _fixSpacingIssue(content, finding);
        if (fixed != null) {
          content = fixed;
          fixedCount++;
        } else {
          skippedCount++;
        }
      } else if (category == 'typography') {
        final fixed = _fixTypographyIssue(content, finding);
        if (fixed != null) {
          content = fixed;
          fixedCount++;
        } else {
          skippedCount++;
        }
      } else {
        skippedCount++;
      }
    }
    
    // Write back if changed
    if (content != originalContent) {
      await file.writeAsString(content);
      print('  ✅ Fixed ${fileFindings.length} issues');
    } else {
      print('  ⚠️  No changes applied');
    }
  }
  
  print('\n' + '━' * 50);
  print('✨ Auto-fix complete!');
  print('  ✅ Fixed: $fixedCount');
  print('  ⚠️  Skipped: $skippedCount');
  print('  📁 Files modified: ${findingsByFile.length}');
}

String? _fixSpacingIssue(String content, Map<String, dynamic> finding) {
  final description = finding['description'] as String;
  final codeSnippet = finding['codeSnippet'] as String?;
  
  if (codeSnippet == null) return null;
  
  // Extract spacing value from description
  final spacingMatch = RegExp(r'spacing (\d+\.?\d*)').firstMatch(description);
  if (spacingMatch == null) return null;
  
  final spacingValue = double.parse(spacingMatch.group(1)!);
  
  // Determine the appropriate StudioSpacing constant
  String replacement;
  if (spacingValue <= 4) {
    // Very small spacing - use xs (8px) or keep as micro spacing
    if (spacingValue == 2) {
      replacement = '4'; // Minimum acceptable spacing
    } else {
      replacement = 'StudioSpacing.xs';
    }
  } else if (spacingValue <= 6) {
    // 5-6px -> xs (8px)
    replacement = 'StudioSpacing.xs';
  } else if (spacingValue <= 12) {
    // 7-12px -> xs (8px) or sm (16px)
    replacement = spacingValue < 10 ? 'StudioSpacing.xs' : 'StudioSpacing.sm';
  } else if (spacingValue <= 20) {
    // 13-20px -> sm (16px)
    replacement = 'StudioSpacing.sm';
  } else if (spacingValue <= 28) {
    // 21-28px -> md (24px)
    replacement = 'StudioSpacing.md';
  } else {
    // 29+px -> lg (32px)
    replacement = 'StudioSpacing.lg';
  }
  
  // Build the fix - handle various spacing patterns
  String fixedSnippet = codeSnippet;
  
  // SizedBox patterns
  if (codeSnippet.contains('SizedBox(width:')) {
    fixedSnippet = codeSnippet.replaceFirst(
      RegExp(r'width:\s*\d+\.?\d*'),
      'width: $replacement',
    );
  } else if (codeSnippet.contains('SizedBox(height:')) {
    fixedSnippet = codeSnippet.replaceFirst(
      RegExp(r'height:\s*\d+\.?\d*'),
      'height: $replacement',
    );
  }
  // EdgeInsets patterns
  else if (codeSnippet.contains('EdgeInsets.all(')) {
    fixedSnippet = codeSnippet.replaceFirst(
      RegExp(r'EdgeInsets\.all\(\s*\d+\.?\d*\s*\)'),
      'EdgeInsets.all($replacement)',
    );
  } else if (codeSnippet.contains('EdgeInsets.symmetric(')) {
    // Handle horizontal and vertical
    if (codeSnippet.contains('horizontal:')) {
      fixedSnippet = codeSnippet.replaceFirst(
        RegExp(r'horizontal:\s*\d+\.?\d*'),
        'horizontal: $replacement',
      );
    }
    if (codeSnippet.contains('vertical:')) {
      fixedSnippet = fixedSnippet.replaceFirst(
        RegExp(r'vertical:\s*\d+\.?\d*'),
        'vertical: $replacement',
      );
    }
  } else if (codeSnippet.contains('EdgeInsets.only(')) {
    // Handle left, right, top, bottom
    fixedSnippet = codeSnippet
        .replaceFirst(RegExp(r'left:\s*\d+\.?\d*'), 'left: $replacement')
        .replaceFirst(RegExp(r'right:\s*\d+\.?\d*'), 'right: $replacement')
        .replaceFirst(RegExp(r'top:\s*\d+\.?\d*'), 'top: $replacement')
        .replaceFirst(RegExp(r'bottom:\s*\d+\.?\d*'), 'bottom: $replacement');
  }
  // Padding patterns
  else if (codeSnippet.contains('Padding(')) {
    fixedSnippet = codeSnippet.replaceFirst(
      RegExp(r'padding:\s*EdgeInsets\.\w+\(\s*\d+\.?\d*\s*\)'),
      'padding: EdgeInsets.all($replacement)',
    );
  } else {
    return null;
  }
  
  // Apply the fix if something changed
  if (fixedSnippet != codeSnippet) {
    return content.replaceFirst(codeSnippet, fixedSnippet);
  }
  
  return null;
}

String? _fixTypographyIssue(String content, Map<String, dynamic> finding) {
  // Typography fixes would go here
  // For now, we'll skip these as they require more context
  return null;
}
