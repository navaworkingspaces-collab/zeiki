// Tests de `AuthException` (HDU-005, AC7).
//
// El contrato:
//   - `AuthException` envuelve errores de Supabase Auth con mensajes
//     en español, accionables, sin exponer detalles internos (conventions
//     §6, §8).
//   - `AuthErrorKind` clasifica el error para que la UI pueda decidir
//     cómo reaccionar (mostrar mensaje, sugerir acción).
//   - El `cause` original se conserva para logging (no se muestra al
//     usuario).
import 'package:flutter_test/flutter_test.dart';

import 'package:zeiki/core/auth/auth_exception.dart';

void main() {
  group('AuthException', () {
    test('message y kind son los que el constructor recibió', () {
      const ex = AuthException(
        kind: AuthErrorKind.emailAlreadyInUse,
        message: 'Este correo ya está registrado.',
      );
      expect(ex.kind, AuthErrorKind.emailAlreadyInUse);
      expect(ex.message, 'Este correo ya está registrado.');
    });

    test('toString() expone kind + message, NO el cause', () {
      // El cause se reserva para logs internos (conventions §6: sin
      // logs de información sensible). El toString va a la UI/logs de
      // crash, así que NO debe filtrar la excepción original.
      const ex = AuthException(
        kind: AuthErrorKind.invalidCredentials,
        message: 'Correo o contraseña incorrectos.',
        cause: 'original-secure-data-no-debe-filtrarse',
      );
      final str = ex.toString();
      expect(str, contains('invalidCredentials'));
      expect(str, contains('Correo o contraseña incorrectos.'));
      expect(str, isNot(contains('original-secure-data')),
          reason: 'cause NO debe filtrarse en toString()');
    });

    test('cause default es null cuando no se pasa', () {
      const ex = AuthException(
        kind: AuthErrorKind.unknown,
        message: 'Algo salió mal.',
      );
      expect(ex.cause, isNull);
    });
  });

  group('mapSupabaseAuthError', () {
    // El mapeo es la pieza que traduce los errores crudos de Supabase
    // (strings en inglés, a veces vacíos, a veces con stack) a un
    // `AuthException` con mensaje en español. Las pruebas siguientes
    // verifican los códigos que ya validamos en runtime durante la
    // implementación (ver `auth_exception.dart::_mapSupabaseAuthError`).

    test('email ya registrado → emailAlreadyInUse', () {
      final ex = mapSupabaseAuthError('User already registered');
      expect(ex.kind, AuthErrorKind.emailAlreadyInUse);
      expect(ex.message, contains('ya está registrado'));
    });

    test('password débil (weak/short) → weakPassword', () {
      final ex = mapSupabaseAuthError('Password should be at least 6 characters');
      expect(ex.kind, AuthErrorKind.weakPassword);
      expect(ex.message, contains('débil'));
    });

    test('credenciales inválidas → invalidCredentials', () {
      final ex = mapSupabaseAuthError('Invalid login credentials');
      expect(ex.kind, AuthErrorKind.invalidCredentials);
      expect(ex.message, contains('incorrectos'));
    });

    test('email no confirmado → emailNotConfirmed', () {
      final ex = mapSupabaseAuthError('Email not confirmed');
      expect(ex.kind, AuthErrorKind.emailNotConfirmed);
      expect(ex.message.toLowerCase(), contains('confirmar'));
    });

    test('mensaje desconocido → unknown con causa preservada', () {
      final ex = mapSupabaseAuthError('some weird failure 0x1234');
      expect(ex.kind, AuthErrorKind.unknown);
      // El cause se preserva para logging — el caller decide qué hacer.
      expect(ex.cause, isNotNull);
    });

    test('error de red (SocketException) → networkError', () {
      // `mapSupabaseAuthError` recibe un `Object` (no solo `String`) y
      // detecta tipos comunes de red. Esto cubre el caso "no hay
      // internet" sin que la UI tenga que conocer las excepciones de
      // dart:io.
      final ex = mapSupabaseAuthError(
        Exception('SocketException: Failed host lookup'),
      );
      expect(ex.kind, AuthErrorKind.networkError);
      expect(ex.message.toLowerCase(), contains('conexión'));
    });
  });
}
