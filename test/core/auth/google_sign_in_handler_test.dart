// Tests de `GoogleSignInHandler` (HDU-005, AC8, AC9, AC10, AC11).
//
// El handler es un wrapper sobre `google_sign_in` que:
//   - Encapsula el popup del SO.
//   - Devuelve el `idToken` (string) para que `AuthService` lo pase a
//     `Supabase.auth.signInWithIdToken`.
//   - Devuelve `null` cuando el usuario cancela el popup (AC10).
//   - Lanza `AuthException` con mensaje accionable si algo falla.
//
// Se prueba con fakes (conventions §3): una función inyectada en vez
// del plugin real, para que el test corra en `flutter test` sin device.
import 'package:flutter_test/flutter_test.dart';

import 'package:zeiki/core/auth/auth_exception.dart';
import 'package:zeiki/core/auth/google_sign_in_handler.dart';

void main() {
  group('GoogleSignInHandler.signInAndGetIdToken', () {
    test('devuelve el idToken cuando la función inyectada lo retorna', () async {
      // Caso feliz: la fake devuelve un idToken simulado.
      final handler = GoogleSignInHandler(
        signInFn: () async => 'fake-id-token-abc',
      );
      final result = await handler.signInAndGetIdToken();
      expect(result, 'fake-id-token-abc');
    });

    test('devuelve null cuando el usuario cancela (AC10)', () async {
      // El popup del SO fue cancelado → la fake devuelve null. La UI
      // debe tratarlo como "no se hace nada", no como error.
      final handler = GoogleSignInHandler(
        signInFn: () async => null,
      );
      final result = await handler.signInAndGetIdToken();
      expect(result, isNull);
    });

    test('lanza AuthException(googleFailed) si la función inyectada lanza', () async {
      // El popup del SO falló (ej. Google Play Services no disponible).
      // El handler NO propaga la excepción cruda — la traduce a
      // `AuthException` con mensaje accionable (conventions §6, §8).
      final handler = GoogleSignInHandler(
        signInFn: () async {
          throw Exception('PlatformException: sign_in_failed');
        },
      );
      await expectLater(
        handler.signInAndGetIdToken(),
        throwsA(
          isA<AuthException>()
              .having((e) => e.kind, 'kind', AuthErrorKind.unknown)
              .having(
                (e) => e.message.toLowerCase(),
                'message',
                contains('google'),
              ),
        ),
      );
    });
  });
}
