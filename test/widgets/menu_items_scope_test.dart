import 'package:flowgroove/widgets/app_menu_sheet.dart';
import 'package:flowgroove/widgets/menu_items_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Branch indices used by the shell: songs = 1, bands = 2.
void main() {
  const roots = {'/main/songs', '/main/bands'};
  MenuScopeData data(String title) => MenuScopeData(
    title: title,
    items: [AppMenuItem(icon: Icons.abc, label: title)],
  );

  setUp(MenuScopeRegistry.reset);

  test('returns the topmost pushed child on the visible branch', () {
    MenuScopeRegistry.attach('bands-root', '/main/bands', 2, data('Bands'));
    MenuScopeRegistry.attach(
      'band-songs',
      '/main/bands/b1/songs',
      2,
      data('Band Songs'),
    );

    final entry = MenuScopeRegistry.pushedEntryFor(2, roots: roots);
    expect(entry?.title, 'Band Songs');
  });

  test('cross-branch push resolves its OWN menu, not the parent screen', () {
    // edit-song is a /main/songs route but was opened from — and is visible on —
    // the bands branch, so it's tagged branch 2 despite its foreign location.
    MenuScopeRegistry.attach('bands-root', '/main/bands', 2, data('Bands'));
    MenuScopeRegistry.attach(
      'band-setlist-view',
      '/main/bands/b1/setlists/s1',
      2,
      data('Wedding Party Set'),
    );
    MenuScopeRegistry.attach(
      'edit-song',
      '/main/songs/s1/edit',
      2,
      data('Song Title'),
    );

    final entry = MenuScopeRegistry.pushedEntryFor(2, roots: roots);
    // Topmost branch-2 non-root = the song editor, NOT the setlist below it.
    expect(entry?.title, 'Song Title');
  });

  test('an orphaned pushed child on another branch is ignored', () {
    // edit-song visible on songs (branch 1); a setlist-view left alive on bands
    // (branch 2) was attached later. Viewing songs must show edit-song's menu.
    MenuScopeRegistry.attach(
      'edit-song',
      '/main/songs/s1/edit',
      1,
      data('Song Title'),
    );
    MenuScopeRegistry.attach(
      'band-setlist-view',
      '/main/bands/b1/setlists/s1',
      2,
      data('Wedding Party Set'),
    );

    expect(MenuScopeRegistry.pushedEntryFor(1, roots: roots)?.title, 'Song Title');
    expect(
      MenuScopeRegistry.pushedEntryFor(2, roots: roots)?.title,
      'Wedding Party Set',
    );
  });
}
