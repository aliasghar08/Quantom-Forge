# Vendored Firebase JS SDK

The Firebase JavaScript SDK, vendored so the web build initialises Firebase from
its own origin instead of fetching it from `gstatic.com` at runtime.

| | |
| --- | --- |
| Version | **12.19.0** (required by `firebase_core_web`, not chosen here — see below) |
| Source | `https://www.gstatic.com/firebasejs/12.19.0/` |
| Files | `firebase-app.js`, `firebase-auth.js`, `firebase-firestore-pipelines.js` |
| Total size | 1 016 619 bytes |
| Licence | Apache-2.0 (Google) |

| File | SHA-256 (as vendored, after the import rewrite) |
| --- | --- |
| `firebase-app.js` | `39A50952B5DEF557337B2290069C7D7371F3515AD46C44A43B9C520F734D8D14` |
| `firebase-auth.js` | `0F99FC82C189CC62A37EF58558BBE91A54B83D47A8592B03144E3DC15C678B5C` |
| `firebase-firestore-pipelines.js` | `0C4E645F0CF31B5553E71922C29EB0314A998940A7949141A668340FBE749A98` |

## Why

FlutterFire loads the JS SDK at runtime, by injecting a `<script>` that imports
`https://www.gstatic.com/firebasejs/<version>/firebase-<service>.js`. That makes
`Firebase.initializeApp()` a **network operation**, and when the fetch stalls, two
things go wrong at once:

1. The browser logs `TypeError: Failed to fetch dynamically imported module`, and
2. FlutterFire's loader never resolves its Dart `Future` — the injected script's
   callback does not fire on failure — so `await Firebase.initializeApp(...)`
   hangs forever.

On a machine where that one request stalls, this produced a **white screen**.

Booting the app without waiting for Firebase fixes the white screen (see the
`Boot the app without waiting on Firebase` commit), but it leaves the SDK
unfetchable, so cloud features never come up. Vendoring removes the third-party
fetch entirely: the files are served from the same origin, so there is nothing to
stall and no CORS to fail.

## Why these three files, and why the third one is not the obvious name

Captured from the running build rather than inferred:

```
firebase-app.js
firebase-auth.js
firebase-firestore-pipelines.js      <- not `firebase-firestore.js`
```

The plugin source builds `firebase-${service.name}.js`, which would suggest
`firebase-firestore.js`, but the compiled app special-cases firestore to use the
`pipelines` bundle. Downloading the obvious filename would have produced a
silently uninitialised Firestore.

`firebase-app.js` imports nothing. The other two import **only** `firebase-app.js`
— and they do so by absolute gstatic URL, so vendoring alone would have kept
sending the browser back to the CDN for the app module. That single import is
rewritten to `./firebase-app.js` in each; `grep -c gstatic` on both files is now 0.
This is the only edit made to any vendored file, which is why the hashes above
differ from the CDN's.

## How FlutterFire picks these up

`firebase_core_web` skips its own CDN injection when the globals already exist
(`firebase_core_web.dart`):

```dart
Future<void> _initializeCore() async {
  // If Firebase is already available, core has already been initialized
  // (or the user has added the scripts to their html file).
  if (globalContext.getProperty('firebase_core'.toJS) != null) {
    return;
  }
```

The names are fixed by the consumers: `firebase_core` (`firebase_core_web.dart`),
`firebase_auth` (`@JS('firebase_auth')`) and `firebase_firestore`
(`@JS('firebase_firestore')`). The injected loader passes the **module namespace
object** to the global, which is why `web/index.html` assigns the result of
`await import(...)` — a plain `<script src="firebase-app.js">` would define
nothing, since an ES module sets no global.

`flutter_bootstrap.js` is no longer a static `<script>` in `index.html`; it is
injected *after* those assignments. Without that ordering a deferred module
script races the Flutter loader, FlutterFire's check runs too early, and it falls
back to injecting from the CDN — failing exactly as before.

## Updating

The version is not a free choice: it is whatever the installed
`firebase_core_web` requires, and FlutterFire warns at runtime if it differs.
Check the version currently in use, then re-capture the file list from a running
build rather than assuming filenames:

```powershell
# 1. Which version does the plugin want?
Select-String -Path "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\firebase_core_web-*\lib\src\firebase_core_web.dart" `
  -Pattern 'supportedFirebaseJsSdkVersion|gstatic\.com/firebasejs'

# 2. Which files does the app actually request? (run against a served build)
node tool/capture_firebase_urls.cjs

# 3. Download each, rewrite the absolute firebase-app.js import to ./firebase-app.js,
#    then re-record the SHA-256 values above.
```

`tool/capture_firebase_urls.cjs` exists for step 2 and is worth keeping: guessing
the filename from the service name is what produces the silent-Firestore failure
described above.

## A missing file fails confusingly on Firebase Hosting, not obviously

`firebase.json` rewrites `**` to `/index.html`. A rewrite only applies when no
static file matches, so correctly-placed files are served as-is — but if one is
**missing**, the request does not 404. It returns `index.html` with HTTP 200, and
the browser reports a JavaScript parse error inside a module rather than a
missing file. If Firebase ever silently stops initialising after an update,
check that every file in the table above actually exists in `build/web/firebasejs/`
before debugging anything else.
