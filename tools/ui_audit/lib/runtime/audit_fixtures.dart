import 'package:flutter/material.dart';

/// Named widget scenarios exercised during runtime inspection.
class AuditFixture {
  final String name;
  final Widget widget;

  const AuditFixture({required this.name, required this.widget});
}

/// Built-in fixtures covering interactive, empty, and responsive cases.
List<AuditFixture> builtInAuditFixtures() {
  return [
    AuditFixture(
      name: 'small_icon_button',
      widget: Center(
        child: IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {},
          iconSize: 16,
          constraints: const BoxConstraints.tightFor(width: 24, height: 24),
        ),
      ),
    ),
    AuditFixture(
      name: 'empty_list_without_treatment',
      widget: ListView(children: const []),
    ),
    AuditFixture(
      name: 'fixed_width_panel',
      widget: Center(
        child: SizedBox(
          width: 900,
          height: 200,
          child: ColoredBox(color: Colors.blue),
        ),
      ),
    ),
    AuditFixture(
      name: 'image_without_semantics',
      widget: const Center(child: Icon(Icons.photo, size: 48)),
    ),
    AuditFixture(
      name: 'disabled_button_low_opacity',
      widget: Center(
        child: Opacity(
          opacity: 0.2,
          child: ElevatedButton(onPressed: null, child: const Text('Save')),
        ),
      ),
    ),
  ];
}
