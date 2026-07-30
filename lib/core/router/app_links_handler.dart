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
// necesario porque la suscripción vive lo que vive la app, pero en
// tests se cancela en `tearDown`).
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

/// Traduce una URI de deep link `zeiki://<host>` al path interno
/// `/<host>`. Devuelve `null` si la URI no es del esquema `zeiki` o
/// si el host está vacío — el caller decide qué hacer (típicamente:
/// ignorar).
String? zeikiUriToPath(Uri uri) {
  if (uri.scheme != 'zeiki') return null;
  final host = uri.host;
  if (host.isEmpty) return null;
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
