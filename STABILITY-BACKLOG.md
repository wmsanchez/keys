# Stability backlog

Parked work from the long-poll / crash-handler pass. None of this is required for the idle-CPU or NSAlert-reentrancy fixes.

## Accessibility trust

`AppDelegate checkTrusted` still uses `AXIsProcessTrusted` / `AXAPIEnabled` and `AuthorizationExecuteWithPrivileges` plus `VSCOKeysActivator`. Ad-hoc re-signing after a Debug install drops TCC, so the first-run “process is not trusted” path is the likely source of the original exception after rebuilds. Replace with `AXIsProcessTrustedWithOptions` and a normal system prompt. Do not `exit` or terminate from a background thread when trust is missing.

## HTTP keep-alive

The halfway server still sends `Connection: close` on every response. Idle long-poll is one TCP handshake per 25s, which is fine. Keep-alive would only matter under rapid key-repeat.

## Stale plugin UUID (403)

`Client.lua` already treats HTTP 403 as “this Lightroom thread is a dangler.” The Python server never sends 403. If two plugin loops can run at once, the server should reject a UUID that is not `currentUUID`.

## NSURLConnection

`HttpRequest.m` still uses `NSURLConnection`. Move to `NSURLSession` when that file is touched for other reasons.

## Status bar thread

`statusBarUpdateLoop` runs at 4 Hz and mutates `NSStatusItem` / menu titles off the main thread. Hop those AppKit writes to the main queue.

## Event-tap ObjC

`myCGCreateEventCallback` still calls `toggleKeyControlActive`, `NSRunningApplication` (`checkIsLRInForeground`), and dictionary lookups on the tap thread. The `@try/@catch` now contains throws; the better long-term split is to hop command dispatch off the tap callback and keep the callback C-ish.

## HUD GPU

The keyboard HUD is a small layer-backed `drawRect:` overlay. 0% GPU is expected. `CAGradientLayer` / Metal would be a visual enhancement, not a stability fix.
