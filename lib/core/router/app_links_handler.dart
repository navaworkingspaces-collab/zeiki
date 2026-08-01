// Handler de deep links de Zeiki (HDU-004, AC5).
//
// Conecta el plugin `app_links` (que recibe los intents del Android)
// con el `GoRouter` declarado en `app_router.dart`. El plugin entrega
// una `Uri` por cada intent; nosotros la traducimos al path interno
// del router y disparamos `router.go(...)`.
//
// Esquema de deep link: `zeiki://<ruta>` (sin HTTPS, deliberadamente
// simple para MVP — ver spec §Riesgos sobre App Links verificados).
// Ejemplo: `zeiki://login` → `/login`.
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

/// Hosts válidos de deep link `zeiki://<host>` (Housekeeping bundle #3,
/// fix #14). Cualquier host fuera de este set se ignora silenciosamente
/// y se loggea con `debugPrint`.
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
};

/// Traduce una URI de deep link `zeiki://<host>` al path interno
/// `/<host>`. Devuelve `null` si la URI no es del esquema `zeiki`, si
/// el host está vacío, o si el host no está en el whitelist
/// `_allowedDeepLinkHosts` — el caller decide qué hacer (típicamente:
/// ignorar).
///
/// **Defensa en profundidad (bundle #3, fix #14):** un intent
/// `zeiki://admin` (host no whitelisted) NO navega a `/admin`, aunque
/// la app esté construida con un router permisivo. Esto reduce la
/// superficie de ataque si en el futuro se agregan rutas
/// privilegiadas (ej. `/admin`, `/debug`).
String? zeikiUriToPath(Uri uri) {
  if (uri.scheme != 'zeiki') return null;
  final host = uri.host;
  if (host.isEmpty) return null;
  if (!_allowedDeepLinkHosts.contains(host)) {
    debugPrint(
      'zeikiUriToPath: host rechazado por whitelist: "$host" '
      '(uri=$uri)',
    );
    return null;
  }
  return '/$host';
}

/// Suscribe el router a un `Stream<Uri>` (típicamente el de `app_links`)
/// y navega cuando llega un deep link `zeiki://<ruta>`. Las URIs que
/// no son del esquema `zeiki` se ignoran.
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
