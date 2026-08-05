// Handler de deep links de Zeiki (HDU-004, HDU-007).
//
// Conecta el plugin `app_links` (que recibe los intents del Android)
// con el `GoRouter` declarado en `app_router.dart`. El plugin entrega
// una `Uri` por cada intent; nosotros la traducimos al path interno
// del router y disparamos `router.go(...)`.
//
// **Esquemas de deep link aceptados:**
//   - `zeiki://<host>` (HDU-004) — scheme interno de Zeiki para
//     navegación entre rutas (login, home, etc.).
//   - `io.supabase.flutter://<host>` (HDU-007) — scheme del SDK de
//     Supabase para los deep links de email (solo reset password
//     después del cleanup; verify-email nunca se mostró).
//     Mantenemos este scheme para que el link del email
//     generado por Supabase apunte a la app sin necesidad de dominio
//     ni App Links verificados (ver
//     `specs/HDU-007-email-callback-flow.md` §1, knowledge reuse del
//     legacy `seiki_app`).
//
// **Hosts válidos:** cualquier host fuera de `_allowedDeepLinkHosts`
// se ignora silenciosamente. El whitelist limita la superficie de
// ataque y mantiene el contrato en sync con el enum `AppRoute`.
//
// **Traducción de host → path:**
//   - `zeiki://login` → `/login`
//   - `io.supabase.flutter://reset-password` → `/auth/reset-password`
//
// La función `wireDeepLinks` devuelve una `StreamSubscription` que el
// caller debe cancelar cuando la app se cierre (en `main.dart` no es
// necesario porque la suscripción vive lo que vive la app). En tests
// se inyecta un `Stream<Uri>` controlado y se limpia el `StreamController`
// en `addTearDown`; la subscription a ese stream se cancela también ahí.
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Schemes válidos de deep link de Zeiki.
///
/// - `zeiki`: scheme interno de navegación (HDU-004).
/// - `io.supabase.flutter`: scheme que Supabase usa en los emails de
///   confirmación y reset password (HDU-007). El mismo que usaba el
///   legacy `seiki_app` para deep links custom sin App Links.
const _allowedDeepLinkSchemes = <String>{
  'zeiki',
  'io.supabase.flutter',
};

/// Hosts válidos de deep link. Cualquier host fuera de este set se
/// ignora silenciosamente y se loggea con `debugPrint`.
///
/// **Por qué existe:** antes, `zeikiUriToPath` aceptaba CUALQUIER host
/// (`zeiki://admin`, `zeiki://../etc`), lo que permitía que un intent
/// externo navegara a rutas no declaradas (o que el `errorBuilder`
/// mostrara basura al usuario). El whitelist limita la superficie de
/// ataque y mantiene el contrato en sync con el enum `AppRoute` de
/// `app_router.dart`.
///
/// **Regla de mantenimiento:** si agregas un valor a `AppRoute` en
/// `app_router.dart`, agrega el host correspondiente aquí. El test en
/// `app_links_handler_test.dart` documenta el contrato.
const _allowedDeepLinkHosts = <String>{
  'splash',
  'onboarding',
  'login',
  'register',
  'unlock',
  'home',
  'reset-password',
};

/// Mapeo de host → path interno del router. Solo los hosts de Supabase
/// (`io.supabase.flutter://...`) necesitan traducción porque usan un
/// path distinto al del host. Los hosts internos de `zeiki://` mapean
/// 1:1 (`host` → `/host`).
///
/// Por ejemplo:
///   - `io.supabase.flutter://reset-password` → `/auth/reset-password`
const _supabaseHostToPath = <String, String>{
  'reset-password': '/auth/reset-password',
};

/// Traduce una URI de deep link al path interno del router. Acepta
/// schemes `zeiki://<host>` y `io.supabase.flutter://<host>`. Devuelve
/// `null` si el scheme no es válido, si el host está vacío, o si el
/// host no está en el whitelist `_allowedDeepLinkHosts` — el caller
/// decide qué hacer (típicamente: ignorar).
///
/// **Defensa en profundidad (bundle #3, fix #14 + HDU-007):** un
/// intent `zeiki://admin` (host no whitelisted) NO navega a `/admin`,
/// aunque la app esté construida con un router permisivo. Esto reduce
/// la superficie de ataque si en el futuro se agregan rutas
/// privilegiadas (ej. `/admin`, `/debug`).
String? zeikiUriToPath(Uri uri) {
  if (!_allowedDeepLinkSchemes.contains(uri.scheme)) return null;
  final host = uri.host;
  if (host.isEmpty) return null;
  if (!_allowedDeepLinkHosts.contains(host)) {
    debugPrint(
      'zeikiUriToPath: host rechazado por whitelist: "$host" '
      '(uri=$uri)',
    );
    return null;
  }
  // Hosts de Supabase (io.supabase.flutter://<host>) necesitan
  // traducción: el path interno es /auth/<host>, no /<host>.
  // Hosts de zeiki://<host> mapean 1:1.
  if (uri.scheme == 'io.supabase.flutter') {
    return _supabaseHostToPath[host] ?? '/$host';
  }
  return '/$host';
}

/// Suscribe el router a un `Stream<Uri>` (típicamente el de `app_links`)
/// y navega cuando llega un deep link válido. Las URIs que no son
/// de los schemes aceptados o tienen hosts no whitelisted se ignoran.
StreamSubscription<Uri> wireDeepLinks(
  GoRouter router,
  Stream<Uri> uriStream,
) {
  return uriStream.listen((uri) {
    final path = zeikiUriToPath(uri);
    if (path == null) return;
    router.go(path);
  });
}

/// Helper que cablea el handler con el plugin real `AppLinks`. Se llama
/// desde `main.dart` después de inicializar el router.
///
/// Devuelve la suscripción para que el caller pueda cancelarla si
/// necesita (tests). En producción se ignora — la suscripción vive lo
/// que vive el proceso.
StreamSubscription<Uri> wireAppLinksDeepLinks(GoRouter router) {
  final appLinks = AppLinks();
  return wireDeepLinks(router, appLinks.uriLinkStream);
}
