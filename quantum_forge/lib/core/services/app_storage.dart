// ============================================================================
// AppStorage — synchronous, plugin-free persistence for workspace state
// ----------------------------------------------------------------------------
// Replaces `shared_preferences`, which could not work in this app.
//
// `shared_preferences_web` is in the lock file, but nothing registers it in the
// built bundle, so every read threw:
//
//   MissingPluginException(No implementation found for method getAll on channel
//     plugins.flutter.io/shared_preferences)
//
// and every write failed the same way. The visible effect was that nothing
// persisted: the theme, the workspace settings and the compute settings all
// silently reset, and the console carried four of those exceptions on every
// single page load. Each call site caught the error and logged it, which is why
// it read as "settings do not stick" rather than as a crash.
//
// Rather than repair plugin registration, this is a small store built on the
// browser's own `localStorage`. That is what `shared_preferences_web` wraps
// anyway, so nothing is lost, and it brings two things with it:
//
//   * **Synchronous reads.** `SharedPreferences.getInstance()` is async, which
//     is why every provider had to load behind an `await` and publish an
//     "initialised" flag. `localStorage.getItem` is synchronous, so state is
//     available the moment a notifier is constructed.
//   * **No plugin, no channel, no registration.** There is nothing left to fail
//     to register — which matters here, because the app already boots without
//     Firebase and needs its local state to survive that.
//
// Values are stored as plain strings, one `localStorage` entry per key. That is
// deliberate: it keeps them readable in the browser's storage inspector, which
// is worth more during debugging than the marginal safety of an opaque JSON
// blob. Types are recovered by parsing on read, and the app uses a distinct key
// per type.
// ============================================================================

export 'app_storage_stub.dart'
    if (dart.library.js_interop) 'app_storage_web.dart';
