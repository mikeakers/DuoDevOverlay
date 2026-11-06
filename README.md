# DuoDevOverlay

A debug overlay for iPhone Duo apps. It draws the safe-area insets (blue)
and the reserved regions — the fold (orange) and the cameras and status block
(pink) — over your running app, with a draggable panel of the exact numbers.
It updates live as the device folds and rotates.

https://github.com/user-attachments/assets/a9c28701-9c18-498a-865d-e23539e43386

## Add it

In Xcode: **File ▸ Add Package Dependencies…**, enter
`https://github.com/mikeakers/DuoDevOverlay`, and add the `DuoDevOverlay`
library to your app target. (The repo is private: your Xcode account, and any
CI that builds the app, need access to it.)

## Turn it on

In your `UIWindowSceneDelegate`:

```swift
import DuoDevOverlay

func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    // … set up your window …
    #if DEBUG
    DuoDevOverlay.install(in: windowScene)
    #endif
}
```

`DuoDevOverlay.uninstall(from:)` removes it and `isInstalled(in:)` tells you
whether it's there — handy for a debug-menu switch. The panel's
**Hide overlay** button uninstalls it too. Drag the panel anywhere; double-tap
it to send it back to its automatic corner.

Callable from iOS 17; it does nothing below iOS 27.1, where the reserved-region
APIs don't exist.

## What it can and can't see

The overlay is its own window above your app's, so it stays on top of modals
and every touch outside the panel reaches your app. A window of its own sees
**window-level** geometry: the status bar, home indicator, fold and cameras.
Insets that your own navigation bars and tab bars add live inside your view
controllers, so they don't show here.

## Demo apps

`DuoDevOverlayDemo.xcodeproj` has two:

- **DuoDevOverlayDemo**: SwiftUI, with switches for a toolbar, navigation
  title and tab bar, to see how each one changes the safe area.
- **DuoDevOverlayUIKitDemo**: a plain UIKit app with the overlay installed
  the way your app would install it.

## License

MIT — see [LICENSE](LICENSE).
