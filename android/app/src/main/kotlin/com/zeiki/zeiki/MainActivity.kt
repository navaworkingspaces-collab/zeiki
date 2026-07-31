// `FlutterFragmentActivity` (no `FlutterActivity`) es obligatorio para que
// `local_auth` use `BiometricPrompt` en Android. Sin este cambio, el
// `authenticate()` lanza `no_fragment_activity` en runtime (HDU-005b).
package com.zeiki.zeiki

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
