import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web_only;

/// The Google-rendered GIS sign-in button (web only).
///
/// GIS delivers the sign-in through [GoogleSignIn.instance.authenticationEvents],
/// entirely same-origin — this is what makes Google login survive Safari ITP,
/// unlike Firebase's signInWithPopup/signInWithRedirect flows.
Widget googleSignInButton() => web_only.renderButton(
  configuration: web_only.GSIButtonConfiguration(
    theme: web_only.GSIButtonTheme.outline,
    size: web_only.GSIButtonSize.large,
    text: web_only.GSIButtonText.continueWith,
    shape: web_only.GSIButtonShape.rectangular,
  ),
);
