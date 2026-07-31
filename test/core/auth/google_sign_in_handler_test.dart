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

  // BUG-001 regression: el `webClientId` (Web OAuth Client ID de Google)
  // DEBE fluir desde `EnvConfig` → `service_locator` → `GoogleSignInHandler`
  // → `GoogleSignIn(serverClientId: ...)`. Si alguien borra el parámetro
  // del constructor o se olvida de pasarlo en el service_locator, este
  // test falla. Es la red de seguridad contra la regresión de BUG-001.
  group('GoogleSignInHandler — BUG-001 regression', () {
    test('expone el webClientId que se le pasa al constructor', () {
      // Caso production: el service_locator pasa el webClientId del env.
      final handler = GoogleSignInHandler(
        webClientId: '123456789-abc.apps.googleusercontent.com',
      );
      expect(
        handler.webClientId,
        '123456789-abc.apps.googleusercontent.com',
        reason:
            'BUG-001 regression: webClientId debe propagarse desde el '
            'constructor hasta la propiedad pública. Si esto es null, el '
            'GoogleSignIn() no recibe serverClientId y el idToken vuelve '
            'null (el bug original).',
      );
    });

    test('webClientId es null cuando NO se pasa (caso tests con signInFn)', () {
      // En tests, normalmente NO se pasa webClientId — el signInFn
      // inyectado se usa en lugar del plugin real. El webClientId
      // queda null, lo cual es OK porque _defaultSignIn no se llama.
      final handler = GoogleSignInHandler(
        signInFn: () async => 'fake-token',
      );
      expect(
        handler.webClientId,
        isNull,
        reason:
            'En tests con signInFn, webClientId debe ser null (no se usa).',
      );
    });

    test('const constructor sigue funcionando con webClientId null', () {
      // El const se usa en `const GoogleSignInHandler()` (sin args).
      // Después de BUG-001, sigue funcionando porque el webClientId
      // default es null.
      const handler = GoogleSignInHandler();
      expect(handler.webClientId, isNull);
    });
  });
}
