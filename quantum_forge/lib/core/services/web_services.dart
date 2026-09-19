// ============================================================================
// WebServices — platform-selected browser services
// ----------------------------------------------------------------------------
// The implementation originally lived in `web_bindings.dart` and imported
// `dart:js_interop` unconditionally. Because the settings screen, the quantum
// controls panel and the chemical resolver all used it, the app could not be
// compiled for the Dart VM at all — which is why no widget test covered any of
// those screens.
//
// The real implementation now sits behind a conditional import, so:
//   * web builds use the browser fetch / window.open bindings,
//   * VM builds (`flutter test`) get a stub that fails loudly instead of
//     breaking the compile.
//
// Keep the constant names in sync with `web_services_stub.dart`.
// ============================================================================

export 'web_services_stub.dart'
    if (dart.library.js_interop) 'web_services_web.dart';

/// Endpoint used by [WebServices.fetchJson] for the chemical resolver.
const String kPubChemBaseUrl =
    'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name';
