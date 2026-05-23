import 'dart:convert';

import '../models/models.dart';

/// Minimal interactive HTML report with severity/category filters.
class HtmlFormatter {
  String format(AuditResult result) {
    final findingsJson = jsonEncode(
      result.findings.map((f) => f.toJson()).toList(),
    );

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>UI/UX Audit Report</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 24px; background: #0f1419; color: #e8f1ff; }
    h1 { font-size: 1.5rem; }
    .filters { margin: 16px 0; display: flex; gap: 12px; flex-wrap: wrap; }
    select, input { padding: 8px; border-radius: 8px; border: 1px solid #244d86; background: #1a2332; color: inherit; }
    .finding { border: 1px solid #244d86; border-radius: 12px; padding: 16px; margin: 12px 0; }
    .severity-critical { border-left: 4px solid #ff6b6b; }
    .severity-high { border-left: 4px solid #ffa94d; }
    .severity-medium { border-left: 4px solid #ffd43b; }
    .severity-low { border-left: 4px solid #69db7c; }
    pre { background: #0c1523; padding: 12px; overflow-x: auto; border-radius: 8px; font-size: 12px; }
    .meta { color: #9fb3d9; font-size: 14px; }
  </style>
</head>
<body>
  <h1>UI/UX Audit Report</h1>
  <p class="meta">Project: ${escape(result.metadata.projectPath)} · Files: ${result.metadata.filesAnalyzed} · Total findings: ${result.summary.totalFindings}</p>
  <div class="filters">
    <label>Severity <select id="severity"><option value="">All</option>${Severity.values.map((s) => '<option value="${s.name}">${s.name}</option>').join()}</select></label>
    <label>Category <select id="category"><option value="">All</option>${FindingCategory.values.map((c) => '<option value="${c.name}">${c.name}</option>').join()}</select></label>
    <label>Search <input id="search" type="search" placeholder="Title or file..." /></label>
  </div>
  <div id="findings"></div>
  <script>
    const findings = $findingsJson;
    const container = document.getElementById('findings');
    function render() {
      const sev = document.getElementById('severity').value;
      const cat = document.getElementById('category').value;
      const q = document.getElementById('search').value.toLowerCase();
      container.innerHTML = '';
      findings.filter(f => (!sev || f.severity === sev) && (!cat || f.category === cat) && (!q || JSON.stringify(f).toLowerCase().includes(q)))
        .forEach(f => {
          const el = document.createElement('article');
          el.className = 'finding severity-' + f.severity;
          el.innerHTML = '<h3>' + f.id + ': ' + escapeHtml(f.title) + '</h3>'
            + '<p class="meta">' + f.severity + ' · ' + f.category + ' · ' + f.location.file + ':' + f.location.line + '</p>'
            + '<p>' + escapeHtml(f.description) + '</p>'
            + '<p><strong>Recommendation:</strong> ' + escapeHtml(f.recommendation) + '</p>'
            + (f.codeSnippet ? '<pre>' + escapeHtml(f.codeSnippet) + '</pre>' : '');
          container.appendChild(el);
        });
    }
    function escapeHtml(s) { return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
    ['severity','category','search'].forEach(id => document.getElementById(id).addEventListener('input', render));
    render();
  </script>
</body>
</html>
''';
  }

  String escape(String value) => const HtmlEscape().convert(value);
}
