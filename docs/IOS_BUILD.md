# Building Brick Stunt Rally for iPhone (iOS)

The project is already iOS-ready: it uses the Mobile renderer on devices,
landscape orientation, on-screen touch controls (auto-shown only on a
touchscreen), and a performance pass tuned for iPhone. Desktop play is
unchanged. This guide covers the parts that must be done on your Mac with your
Apple account.

## What's already done in the project
- `project.godot`: `rendering/renderer/rendering_method.mobile = "mobile"`,
  landscape orientation, `canvas_items` + `expand` stretch.
- Touch controls (`scripts/touch_controls.gd`): draggable analog movement
  joystick, turret joystick, FIRE/JUMP/INTERACT/PAUSE/ENTER/BACK buttons. They
  appear only when `DisplayServer.is_touchscreen_available()`.
- Lab supports tap-to-place, drag-to-orbit, pinch-zoom, and a Remove toggle.
- Mobile performance: lighter shadows, glow off, fewer studs/particles, no
  dynamic explosion/missile lights (all gated in `scripts/mobile.gd`).
- A starter iOS export preset in `export_presets.cfg`.

## One-time setup on your Mac
1. Install **Xcode** (App Store) and run `xcode-select --install`.
2. Enroll in the **Apple Developer Program** ($99/yr) for App Store / TestFlight.
3. In Godot: **Editor > Manage Export Templates > Download and Install** (matching your Godot version, 4.6).

## Configure the export
Open **Project > Export** and select the **iOS** preset:
- Set **App Store Team ID** (from developer.apple.com > Membership).
- Confirm **Bundle Identifier** (currently `com.mrshapron.brickstuntrally`).
- Add app **icons** (1024x1024 App Store icon + the required sizes) and, if you
  want, a custom launch image. Without custom icons Godot uses its default.

## Export and run on a device
1. **Project > Export > Export Project** to e.g. `build/ios/` -> produces an
   Xcode project (`BrickStuntRally.xcodeproj`).
2. Open it in **Xcode**, select **Signing & Capabilities > Team** (your team),
   pick your iPhone as the run target, and press **Run**. First run requires
   trusting your developer cert on the phone (Settings > General > VPN & Device
   Management).

## TestFlight / App Store
1. In Xcode: **Product > Archive**.
2. In the Organizer, **Distribute App > App Store Connect > Upload**.
3. On **App Store Connect**: create the app record (matching bundle id), fill in
   metadata/screenshots, attach the build, and submit to TestFlight (beta) or for
   App Store review.

## Tips
- Test the touch feel on-device; tune joystick `radius`/`dead_zone` in
  `scripts/virtual_joystick.gd` and button sizes in `scripts/touch_controls.gd`.
- If a scene is heavy, the knobs in `scripts/mobile.gd` (shadow distance, stud
  segments, particle scale) are the quickest levers.
