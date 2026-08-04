// Tests de `AuthService` (HDU-005, AC1, AC3, AC27).
//
// `AuthService` envuelve `supabase.auth` y expone una API mínima:
// `signUpWithEmail`, `signInWithEmail`, `signInWithGoogle`, `signOut`,
// `getCurrentSession`, `authStateChanges`.
//
// Tests con fakes (conventions §3): las funciones de Supabase se
// inyectan vía constructor. No hay `mockito` ni `build_runner`.
//
// Cubre:
//   - signUpWithEmail: éxito, email duplicado, password débil.
//   - signInWithEmail: éxito, credenciales inválidas.
//   - signInWithGoogle: éxito con idToken, cancelación (null),
//     fallo del popup.
//   - signOut: limpia la sesión.
//   - getCurrentSession: devuelve la sesión o null.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:zeiki/core/auth/auth_exception.dart';
import 'package:zeiki/core/auth/auth_service.dart';
import 'package:zeiki/core/auth/google_sign_in_handler.dart';

void main() {
  // Helpers ------------------------------------------------------------

  /// Construye una `User` mínima. El resto de campos se quedan vacíos.
  sb.User fakeUser({String email = 'hugo@zeiki.app'}) {
    return sb.User(
      id: 'user-id-1',
      appMetadata: const <String, dynamic>{},
      userMetadata: const <String, dynamic>{},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
  }

  /// Construye una `Session` mínima. Solo `accessToken`, `tokenType` y
  /// `user` son requeridos por el constructor de go_true 2.26.0.
  sb.Session fakeSession({String email = 'hugo@zeiki.app'}) {
    return sb.Session(
      accessToken: 'access',
      tokenType: 'bearer',
      user: fakeUser(email: email),
    );
  }

  /// Construye una `AuthResponse` mínima.
  sb.AuthResponse fakeAuthResponse({String email = 'hugo@zeiki.app'}) {
    return sb.AuthResponse(session: fakeSession(email: email), user: null);
  }

  /// Fakes que devuelven/throw valores controlados.
  /// Cada test los configura a su gusto.
  late _SupabaseStubs stubs;

  setUp(() {
    stubs = _SupabaseStubs();
  });

  AuthService makeService({GoogleSignInHandler? googleHandler}) {
    return AuthService(
      signUpWithEmailFn: stubs.signUpWithEmail,
      signInWithEmailFn: stubs.signInWithEmail,
      signInWithIdTokenFn: stubs.signInWithIdToken,
      signOutFn: stubs.signOut,
      resetPasswordForEmailFn: stubs.resetPasswordForEmail,
      updateUserPasswordFn: stubs.updateUser,
      getCurrentSessionFn: stubs.getCurrentSession,
      authStateChangeFn: stubs.authStateChange,
      googleSignInHandler: googleHandler ?? const GoogleSignInHandler(),
    );
  }

  group('signUpWithEmail', () {
    test('éxito: devuelve AuthResult y la sesión queda activa', () async {
      stubs.signUpResult = fakeAuthResponse(email: 'hugo@zeiki.app');
      final service = makeService();

      final result = await service.signUpWithEmail(
        email: 'hugo@zeiki.app',
        password: 'secret-pass-1',
      );

      expect(result.session?.user.email, 'hugo@zeiki.app');
      expect(stubs.signUpCalls, 1);
      expect(stubs.signUpLastEmail, 'hugo@zeiki.app');
      expect(stubs.signUpLastPassword, 'secret-pass-1');
    });

    test(
        'pasa emailRedirectTo al callback de Supabase (HDU-007, AC1) → link '
        'debe apuntar a io.supabase.flutter://verify-email/', () async {
      stubs.signUpResult = fakeAuthResponse(email: 'hugo@zeiki.app');
      final service = makeService();

      await service.signUpWithEmail(
        email: 'hugo@zeiki.app',
        password: 'secret-pass-1',
      );

      // Verifica que el service pasa el `emailRedirectTo` correcto al
      // callback. Sin esto, Supabase usa el default del proyecto
      // (localhost:3000) y el link de confirmación no abre la app.
      expect(
        stubs.signUpLastEmailRedirectTo,
        'io.supabase.flutter://verify-email/',
      );
    });

    test('email duplicado → lanza AuthException(emailAlreadyInUse) (AC7)',
        () async {
      stubs.signUpError = Exception('User already registered');
      final service = makeService();

      await expectLater(
        service.signUpWithEmail(
          email: 'hugo@zeiki.app',
          password: 'secret-pass-1',
        ),
        throwsA(
          isA<AuthException>()
              .having((e) => e.kind, 'kind', AuthErrorKind.emailAlreadyInUse),
        ),
      );
    });

    test('password débil → lanza AuthException(weakPassword)', () async {
      stubs.signUpError = Exception('Password should be at least 8 characters');
      final service = makeService();

      await expectLater(
        service.signUpWithEmail(email: 'a@b.com', password: 'short'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.kind, 'kind', AuthErrorKind.weakPassword),
        ),
      );
    });
  });

  group('signInWithEmail', () {
    test('éxito: devuelve AuthResult con sesión del usuario', () async {
      stubs.signInResult = fakeAuthResponse(email: 'hugo@zeiki.app');
      final service = makeService();

      final result = await service.signInWithEmail(
        email: 'hugo@zeiki.app',
        password: 'secret-pass-1',
      );

      expect(result.session?.user.email, 'hugo@zeiki.app');
      expect(stubs.signInCalls, 1);
    });

    test('credenciales inválidas → lanza AuthException(invalidCredentials)',
        () async {
      stubs.signInError = Exception('Invalid login credentials');
      final service = makeService();

      await expectLater(
        service.signInWithEmail(
          email: 'hugo@zeiki.app',
          password: 'wrong',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.kind,
            'kind',
            AuthErrorKind.invalidCredentials,
          ),
        ),
      );
    });
  });

  group('signInWithGoogle', () {
    test('idToken del handler → llama signInWithIdToken con provider=google',
        () async {
      stubs.signInWithIdTokenResult = fakeAuthResponse(email: 'g@zeiki.app');
      final handler = GoogleSignInHandler(
        signInFn: () async => 'google-id-token-xyz',
      );
      final service = makeService(googleHandler: handler);

      final result = await service.signInWithGoogle();

      expect(result.session?.user.email, 'g@zeiki.app');
      expect(stubs.signInWithIdTokenCalls, 1);
      expect(stubs.signInWithIdTokenLastProvider, sb.OAuthProvider.google);
      expect(stubs.signInWithIdTokenLastIdToken, 'google-id-token-xyz');
    });

    test('handler devuelve null (canceló el popup) → lanza '
        'UserCancelledAuthFlow', () async {
      // No hay error de Supabase. La UI lo captura y NO muestra error
      // (AC10). El service NO llama a signInWithIdToken ni a signInWithEmail.
      final handler = GoogleSignInHandler(signInFn: () async => null);
      final service = makeService(googleHandler: handler);

      await expectLater(
        service.signInWithGoogle(),
        throwsA(isA<UserCancelledAuthFlow>()),
      );
      expect(stubs.signInWithIdTokenCalls, 0,
          reason: 'signInWithIdToken NO debe llamarse si el user canceló');
    });

    test('handler lanza excepción → propaga AuthException', () async {
      final handler = GoogleSignInHandler(
        signInFn: () async => throw Exception('Play Services unavailable'),
      );
      final service = makeService(googleHandler: handler);

      await expectLater(
        service.signInWithGoogle(),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('signOut', () {
    test('llama a la función inyectada de signOut', () async {
      final service = makeService();
      await service.signOut();
      expect(stubs.signOutCalls, 1);
    });
  });

  group('resetPasswordForEmail (HDU-007, AC6)', () {
    test('éxito → llama a la función inyectada con el email', () async {
      final service = makeService();

      await service.resetPasswordForEmail(email: 'hugo@zeiki.app');

      expect(stubs.resetPasswordCalls, 1);
      expect(stubs.resetPasswordLastEmail, 'hugo@zeiki.app');
    });

    test('error del servicio → lanza AuthException(unknown)', () async {
      // El mapper por default convierte excepciones desconocidas a
      // `AuthException(kind: unknown)`. Aquí verificamos que el service
      // propaga el mapeo (no la excepción cruda).
      stubs.resetPasswordError = Exception('rate limit exceeded');
      final service = makeService();

      await expectLater(
        service.resetPasswordForEmail(email: 'hugo@zeiki.app'),
        throwsA(isA<AuthException>()),
      );
      expect(stubs.resetPasswordCalls, 1);
    });
  });

  group('updateUserPassword (HDU-007, AC9)', () {
    test('éxito → llama a la función inyectada con el nuevo password',
        () async {
      final service = makeService();

      await service.updateUserPassword(newPassword: 'new-secret-pass-9');

      expect(stubs.updateUserPasswordCalls, 1);
      expect(stubs.updateUserPasswordLastPassword, 'new-secret-pass-9');
    });

    test('error del servicio → lanza AuthException mapeada', () async {
      stubs.updateUserPasswordError = Exception('session expired');
      final service = makeService();

      await expectLater(
        service.updateUserPassword(newPassword: 'new-secret-pass-9'),
        throwsA(isA<AuthException>()),
      );
      expect(stubs.updateUserPasswordCalls, 1);
    });
  });

  group('getCurrentSession', () {
    test('sin sesión guardada → devuelve null', () {
      stubs.session = null;
      final service = makeService();
      expect(service.getCurrentSession(), isNull);
    });

    test('con sesión guardada → devuelve la sesión', () {
      stubs.session = fakeSession(email: 'hugo@zeiki.app');
      final service = makeService();
      final s = service.getCurrentSession();
      expect(s, isNotNull);
      expect(s!.user.email, 'hugo@zeiki.app');
    });
  });

  group('currentUserId (HDU-005b, KEY por usuario en secure storage)', () {
    test('sin sesión guardada → devuelve null', () {
      stubs.session = null;
      final service = makeService();
      expect(service.currentUserId, isNull,
          reason: 'sin sesión no hay userId para el flag de biometría');
    });

    test('con sesión guardada → devuelve el id del user', () {
      stubs.session = fakeSession(email: 'hugo@zeiki.app');
      final service = makeService();
      expect(service.currentUserId, 'user-id-1',
          reason: 'currentUserId se usa como KEY en secure storage para '
              'aislar el flag de biometría por cuenta');
    });
  });

  group('authStateChanges', () {
    test('expone el stream que devuelve la función inyectada', () async {
      final controller = StreamController<sb.AuthState>.broadcast();
      addTearDown(controller.close);
      stubs.authStateController = controller;

      final service = makeService();
      final received = <sb.AuthState>[];
      final sub = service.authStateChanges.listen(received.add);
      addTearDown(sub.cancel);

      controller.add(sb.AuthState(sb.AuthChangeEvent.signedIn, fakeSession()));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, hasLength(1));
    });
  });
}

/// Conjunto de fakes para inyectar a `AuthService`. Cada función es
/// una trampilla que el test configura en `setUp` y luego ajusta por
/// test.
///
/// **Por qué no `mockito`:** las funciones inyectadas no necesitan
/// verificación de interacciones complejas — solo "se llamó N veces"
/// o "se llamó con X". Eso se hace con contadores (`signUpCalls`) y
/// últimos argumentos (`signUpLastEmail`). Más simple, sin
/// `build_runner` (conventions §3).
class _SupabaseStubs {
  // signUpWithEmail
  int signUpCalls = 0;
  String? signUpLastEmail;
  String? signUpLastPassword;
  String? signUpLastEmailRedirectTo;
  Object? signUpError;
  sb.AuthResponse? signUpResult;
  Future<sb.AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? emailRedirectTo,
  }) async {
    signUpCalls++;
    signUpLastEmail = email;
    signUpLastPassword = password;
    signUpLastEmailRedirectTo = emailRedirectTo;
    if (signUpError != null) throw signUpError!;
    return signUpResult ?? fakeAuthResponse();
  }

  // signInWithEmail
  int signInCalls = 0;
  Object? signInError;
  sb.AuthResponse? signInResult;
  Future<sb.AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (signInError != null) throw signInError!;
    return signInResult ?? fakeAuthResponse();
  }

  // signInWithIdToken
  int signInWithIdTokenCalls = 0;
  sb.OAuthProvider? signInWithIdTokenLastProvider;
  String? signInWithIdTokenLastIdToken;
  Object? signInWithIdTokenError;
  sb.AuthResponse? signInWithIdTokenResult;
  Future<sb.AuthResponse> signInWithIdToken({
    required sb.OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
  }) async {
    signInWithIdTokenCalls++;
    signInWithIdTokenLastProvider = provider;
    signInWithIdTokenLastIdToken = idToken;
    if (signInWithIdTokenError != null) throw signInWithIdTokenError!;
    return signInWithIdTokenResult ?? fakeAuthResponse();
  }

  // signOut
  int signOutCalls = 0;
  Object? signOutError;
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
  }

  // resetPasswordForEmail (HDU-007, AC6)
  int resetPasswordCalls = 0;
  String? resetPasswordLastEmail;
  Object? resetPasswordError;
  Future<void> resetPasswordForEmail(String email, {String? redirectTo}) async {
    resetPasswordCalls++;
    resetPasswordLastEmail = email;
    if (resetPasswordError != null) throw resetPasswordError!;
  }

  // updateUserPassword (HDU-007, AC9)
  int updateUserPasswordCalls = 0;
  String? updateUserPasswordLastPassword;
  Object? updateUserPasswordError;
  Future<sb.UserResponse> updateUser(sb.UserAttributes attributes) async {
    updateUserPasswordCalls++;
    updateUserPasswordLastPassword = attributes.password;
    if (updateUserPasswordError != null) throw updateUserPasswordError!;
    // Devolvemos un UserResponse mínimo vía fromJson. Los features no
    // leen la respuesta, solo necesitan que el tipo se satisfaga.
    return sb.UserResponse.fromJson(<String, dynamic>{
      'id': 'user-id-1',
      'aud': 'authenticated',
      'app_metadata': const <String, dynamic>{},
      'user_metadata': const <String, dynamic>{},
      'created_at': DateTime.now().toIso8601String(),
      'email': 'hugo@zeiki.app',
    });
  }

  // getCurrentSession
  sb.Session? session;
  sb.Session? getCurrentSession() => session;

  // authStateChange
  StreamController<sb.AuthState>? authStateController;
  Stream<sb.AuthState> authStateChange() {
    // Si el test no inyecta controller, devolvemos un stream vacío
    // (broadcast) que no emite nunca. Así, el código bajo test no
    // falla al escuchar.
    return authStateController?.stream ??
        const Stream<sb.AuthState>.empty();
  }
}

// Helpers top-level (en vez de una clase anidada) para que los stubs
// puedan llamarlos directamente.
sb.AuthResponse fakeAuthResponse({String email = 'hugo@zeiki.app'}) {
  return sb.AuthResponse(
    session: sb.Session(
      accessToken: 'access',
      tokenType: 'bearer',
      user: sb.User(
        id: 'user-id-1',
        appMetadata: const <String, dynamic>{},
        userMetadata: const <String, dynamic>{},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: email,
      ),
    ),
    user: null,
  );
}
