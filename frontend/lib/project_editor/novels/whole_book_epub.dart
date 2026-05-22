import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../../l10n/app_localizations.dart';

/// Extract plain text from EPUB bytes (spine order).
String extractWholeBookTextFromEpubBytes(
  List<int> bytes,
  AppLocalizations l10n,
) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: false);
  final containerFile = archive.findFile('META-INF/container.xml');
  if (containerFile == null) {
    throw FormatException(l10n.projectEditorNovelsWholeBookEpubInvalid);
  }
  final containerDoc = XmlDocument.parse(
    String.fromCharCodes(containerFile.content as List<int>),
  );
  final rootfileNodes = containerDoc.findAllElements('rootfile');
  final rootfilePath = rootfileNodes.isEmpty
      ? null
      : rootfileNodes.first.getAttribute('full-path');
  if (rootfilePath == null || rootfilePath.trim().isEmpty) {
    throw FormatException(l10n.projectEditorNovelsWholeBookEpubInvalid);
  }

  final opfFile = archive.findFile(rootfilePath);
  if (opfFile == null) {
    throw FormatException(l10n.projectEditorNovelsWholeBookEpubInvalid);
  }
  final opfDir = _dirname(rootfilePath);
  final opfDoc = XmlDocument.parse(
    String.fromCharCodes(opfFile.content as List<int>),
  );

  final manifest = <String, String>{};
  for (final item in opfDoc.findAllElements('item')) {
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id != null && href != null && href.trim().isNotEmpty) {
      manifest[id] = href.trim();
    }
  }

  final spineIds = <String>[];
  for (final itemref in opfDoc.findAllElements('itemref')) {
    final idref = itemref.getAttribute('idref');
    if (idref != null && idref.trim().isNotEmpty) {
      spineIds.add(idref.trim());
    }
  }

  final buffer = StringBuffer();
  var parts = 0;
  for (final id in spineIds) {
    final href = manifest[id];
    if (href == null) {
      continue;
    }
    final path = opfDir.isEmpty ? href : '$opfDir/$href';
    final entry = archive.findFile(path) ?? archive.findFile(href);
    if (entry == null) {
      continue;
    }
    final raw = String.fromCharCodes(entry.content as List<int>);
    final text = _htmlToPlainText(raw);
    if (text.isEmpty) {
      continue;
    }
    if (parts > 0) {
      buffer.writeln();
      buffer.writeln();
    }
    buffer.write(text);
    parts += 1;
  }

  if (parts == 0) {
    throw FormatException(l10n.projectEditorNovelsWholeBookEpubNoText);
  }
  return buffer.toString();
}

String _dirname(String path) {
  final slash = path.lastIndexOf('/');
  if (slash <= 0) {
    return '';
  }
  return path.substring(0, slash);
}

String _htmlToPlainText(String html) {
  final doc = html_parser.parse(html);
  final text = doc.body?.text ?? doc.documentElement?.text ?? '';
  return text.replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
