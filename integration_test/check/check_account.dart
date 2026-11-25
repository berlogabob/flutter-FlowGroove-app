// Account area: AU-02 .. AU-06.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowgroove/router/app_router.dart';
import 'package:flowgroove/screens/auth/register_screen.dart';
import 'package:flowgroove/screens/home_screen.dart';
import 'package:flowgroove/screens/login_screen.dart';
import 'package:flowgroove/screens/profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'check.dart';

const _authBase = 'http://$emulatorHost:9099';
const _project = 'repsync-app-8685c';

/// Back to the seeded user (checks that sign out or delete the user call this).
Future<void> _signInSeed() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser?.email == seedEmail) return;
  await auth.signInWithEmailAndPassword(email: seedEmail, password: seedPassword);
}

/// Creates (and signs in as) a throwaway user on the auth emulator.
Future<User> _throwawayUser(String tag) async {
  await bootFirebase();
  final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: 'check-$tag-${DateTime.now().millisecondsSinceEpoch}@flowgroove.test',
    password: seedPassword,
  );
  return cred.user!;
}

/// True when the auth emulator no longer accepts the throwaway user's password.
Future<bool> _signInFails(String email) async {
  final res = await http.post(
    Uri.parse('$_authBase/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': seedPassword, 'returnSecureToken': true}),
  );
  return res.statusCode != 200;
}

Future<void> _openProfile(WidgetTester tester) async {
  appRouter.go('/main/profile');
  await see(tester, find.byType(ProfileScreen), 'profile screen');
}

void registerAccountChecks() {
  check('AU-02', 'Register a new account', (tester) async {
    await bootApp(tester, signedIn: false);
    final email = 'check-register-${DateTime.now().millisecondsSinceEpoch}@flowgroove.test';
    try {
      await tapOn(tester, find.text('Sign Up'), 'Sign Up link on the login screen');
      await see(tester, find.byType(RegisterScreen), 'register screen');
      await pause(tester, 800); // the login screen is still sliding out
      final fields = find.descendant(of: find.byType(RegisterScreen), matching: find.byType(TextFormField));
      await typeInto(tester, fields.at(0), email, 'email field');
      await typeInto(tester, fields.at(1), seedPassword, 'password field');
      await typeInto(tester, fields.at(2), seedPassword, 'confirm field');
      await tapOn(tester, find.widgetWithText(ElevatedButton, 'Create Account'), 'Create Account button');
      await see(tester, find.byType(HomeScreen), 'home screen after registering', seconds: 30);
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email != email) fail('expected signed in as $email after registering; observed ${user?.email}');
    } finally {
      try {
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (_) {}
      await _signInSeed();
    }
  });

  check('AU-03', 'Forgot password sends a reset', (tester) async {
    await bootApp(tester, signedIn: false);
    try {
      await typeInto(tester, find.byType(TextFormField).first, seedEmail, 'email field');
      await tapOn(tester, find.text('Forgot Password?'), 'Forgot Password link');
      await see(tester, find.text('Reset Password'), 'reset screen');
      await tapOn(tester, find.text('Send Reset Email'), 'Send Reset Email button');
      await see(tester, find.textContaining("we've sent password reset"), 'confirmation text');
      // The auth emulator records every reset email as an out-of-band code.
      final res = await http.get(Uri.parse('$_authBase/emulator/v1/projects/$_project/oobCodes'));
      final codes = (jsonDecode(res.body)['oobCodes'] as List).where(
        (c) => c['email'] == seedEmail && c['requestType'] == 'PASSWORD_RESET',
      );
      if (codes.isEmpty) fail('expected a PASSWORD_RESET code for $seedEmail on the auth emulator; observed none (${res.body})');
    } finally {
      await _signInSeed();
    }
  });

  check('AU-04', 'Sign out returns to Login', (tester) async {
    await bootApp(tester);
    try {
      await _openProfile(tester);
      await scrollTo(tester, find.text('Sign Out'), find.byType(ProfileScreen), 'Sign Out button');
      await tapOn(tester, find.text('Sign Out'), 'Sign Out button');
      await see(tester, find.byType(AlertDialog), 'confirmation dialog');
      await tapOn(tester, find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextButton, 'Sign Out')), 'Sign Out in the dialog');
      await see(tester, find.byType(LoginScreen), 'login screen after signing out');
      if (FirebaseAuth.instance.currentUser != null) {
        fail('expected no signed-in user after Sign Out; observed ${FirebaseAuth.instance.currentUser?.email}');
      }
    } finally {
      await _signInSeed();
    }
  });

  check('AU-05', 'Profile: change name, instrument', (tester) async {
    await bootApp(tester);
    final userDoc = FirebaseFirestore.instance.doc('users/$uid');
    final before = (await userDoc.get()).data() ?? {};
    try {
      await _openProfile(tester);
      await tapOn(tester, find.widgetWithIcon(IconButton, Icons.edit), 'pencil next to the name');
      await typeInto(tester, find.byType(TextField), 'Check Renamed', 'name field');
      await tapOn(tester, find.byIcon(Icons.check), 'confirm name button');
      await see(tester, find.text('Name updated'), 'snackbar "Name updated"');
      final named = await eventually(
        tester,
        () async => (await userDoc.get()).data()?['displayName'],
        (n) => n == 'Check Renamed',
        'displayName saved',
        show: (n) => '"$n"',
      );
      if (named != 'Check Renamed') fail('expected displayName "Check Renamed"; saved "$named"');
      final problems = <String>[];
      try {
        await expectSeen(tester, label('Check Renamed'), 'expected the profile to show the new name "Check Renamed" after "Name updated"');
      } on TestFailure catch (e) {
        problems.add(e.message ?? '$e');
      }
      // Instrument: My Roles > Edit > Drummer > Save.
      await tapOn(tester, find.widgetWithText(TextButton, 'Edit'), 'My Roles Edit button');
      await see(tester, find.byType(AlertDialog), 'role picker');
      await tapOn(tester, find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('Drummer')), 'role Drummer');
      await tapOn(tester, find.descendant(of: find.byType(AlertDialog), matching: find.text('Save')), 'Save in the role picker');
      final roles = await eventually(
        tester,
        () async => List<String>.from((await userDoc.get()).data()?['musicRoles'] as List? ?? const []),
        (r) => r.isNotEmpty,
        'musicRoles saved',
      );
      if (!roles.contains('drummer')) fail('expected musicRoles to contain "drummer"; saved $roles');
      await see(tester, find.byType(Chip), 'role chip on the profile');
      if (problems.isNotEmpty) fail(problems.join('; '));
    } finally {
      await FirebaseAuth.instance.currentUser?.updateDisplayName('Check User');
      await userDoc.update({
        'displayName': before['displayName'],
        'musicRoles': before['musicRoles'] ?? [],
      });
    }
  });

}

/// Registered last: its deletion leaves the app's navigator in a state later checks cannot use.
void registerAccountDeleteCheck() {
  check('AU-06', 'Delete account asks and deletes', (tester) async {
    final user = await _throwawayUser('delete');
    final (email, id) = (user.email!, user.uid);
    try {
      await bootApp(tester);
      await _openProfile(tester);
      await scrollTo(tester, find.text('Danger zone'), find.byType(ProfileScreen), 'Danger zone');
      await tapOn(tester, find.text('Danger zone'), 'Danger zone header');
      await tapOn(tester, find.text('Delete account'), 'Delete account link');
      await see(tester, find.textContaining('permanently deletes your account'), 'confirmation text');
      await tapOn(tester, find.text('Cancel'), 'Cancel in the dialog');
      await pause(tester, 600);
      if (found(find.byType(AlertDialog))) fail('dialog still open after Cancel');
      if (FirebaseAuth.instance.currentUser?.uid != id) fail('Cancel changed the signed-in user');
      await tapOn(tester, find.text('Delete account'), 'Delete account link');
      await see(tester, find.byType(AlertDialog), 'confirmation dialog');
      await tapOn(tester, find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')), 'Delete in the dialog');
      try {
        await see(tester, find.byType(LoginScreen), 'login screen after deleting', seconds: 20);
      } on TimeoutException {
        final gone = await _signInFails(email);
        fail(
          'expected the login screen after confirming Delete; observed no login screen after 20 s '
          '(progress spinner shown: ${found(find.byType(CircularProgressIndicator))}, profile still shown: '
          '${found(find.byType(ProfileScreen))}, server account deleted: $gone, on screen: ${onScreen()})',
        );
      }
      // The account must be gone on the server: signing in again fails.
      if (!await _signInFails(email)) fail('expected sign-in as the deleted $email to fail; it succeeded');
    } finally {
      try {
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (_) {}
      await _signInSeed();
    }
  });
}
