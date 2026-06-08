# Brick Stunt Rally 🧱🚗

You drive blocky cars
through stunt courses, blow stuff up with rockets, build your own vehicles brick by
brick in a Laboratory, and collect a garage full of cars. It started as a "let me
try Godot for a weekend" thing and kind of refused to stop growing.

![World hub](screenshots/hub.png)

## Why I made this

Honestly? I just wanted to drive a tiny Lego-ish car off a ramp and watch it flip.
That was the whole pitch in my head. Then I added a loop. Then I wanted *worlds*.
Then I thought "what if the car had a rocket on the roof" and there was no going
back. Every evening I'd tell myself "one more small thing" and end up three hours
deep tuning suspension springs or arguing with myself about how a wheel should feel
on a bumpy road.

I'm not a studio, it's just me. A lot of this was trial and error — driving the same
test ramp a hundred times, nudging a number, driving it again. The car physics in
particular took forever to feel *right* (grippy but still fun, springy but not
bouncy-castle). I'm pretty proud of where it landed.

## What's in it

- **Drive-anywhere arcade cars** — full 3D ground driving with tire grip, springy
  suspension, body lean into corners, and the freedom to roam a wide world.
- **A hub world you drive around** — no clicky menus. You steer your car into a
  glowing portal, hold for a couple seconds, and it charges up and warps you in.
- **Six themed worlds**, 10 levels each, getting harder as you go — Grassland,
  Desert (with sand dunes), Neon City, a **War Zone**, a **Mountains** climb to
  the summit, and a **Speedway** where you race AI cars. Levels are generated with
  ramps, gaps, hazards, moving platforms, spinning arms, loops, falling boulders
  and more.
- **Rockets & combat** — roof-mounted launchers fire actual rockets with fire
  trails that explode on impact. Real area blasts that fling bricks around, enemy
  types (drones, turrets, tanks) with health bars, and floating damage numbers.
- **Racing** — line up against bot cars and fight to cross the line in 1st place.
- **A Laboratory where you build your own car** brick by brick — pick blocks,
  wheels and rockets, paint them, and drive your creation everywhere.
- **A Parking lot / garage** — you start with two cars and win a new one every time
  you finish a world. Walk up to any car on foot and hop in.
- **Get out and walk** — there's a little brick character (you can see the driver
  in the car). Press E to get out, wander around, jump with Space, get back in.
- **Nice scenery** — sun, snow-capped mountains, lego trees, drifting clouds, all
  themed per world.
- **Almost no external assets.** Every model, every sound, every level is
  generated in code (the only asset is the comic UI font). The "studded bricks"
  are deliberately generic — this isn't affiliated with any toy company, just
  inspired by the joy of clicking bricks together.

![The Laboratory - build your own car](screenshots/laboratory.png)

![Racing AI bots on the Speedway](screenshots/race.png)

![Your garage in the Parking lot](screenshots/parking.png)

![War Zone in the desert](screenshots/warzone.png)

## Now on iPhone 📱

It also runs on **mobile (iOS)** — built with Godot's Mobile renderer and a full
set of on-screen touch controls: a draggable analog joystick to drive, a turret
joystick, and FIRE / E (in-out) / ENTER / BACK buttons. The desktop keyboard
controls are untouched; the touch UI only appears on a touchscreen.

![Racing on iPhone](screenshots/mobile_race.png)

![World hub on iPhone](screenshots/mobile_hub.png)

## Controls

| Key | What it does |
| --- | --- |
| Arrow keys / WASD | Drive (and rotate the view in the Laboratory) |
| Space / F | Fire rockets · (jump when you're on foot) |
| E | Get out of / into the car |
| Enter | Skip the portal charge-up / continue after a level |
| R | Restart the level |
| M / Esc | Back out (level → world map → hub) |

There's a **Sound** toggle in the top-right of every screen (it starts muted).

## Installation

There's nothing to compile and no dependencies to install — the whole game is
generated in code. You just need Godot.

**1. Install Godot 4** (built on **4.6**, any 4.6+ works):

- Download it from [godotengine.org/download](https://godotengine.org/download), or
- macOS (Homebrew): `brew install --cask godot`
- Linux: grab the binary from the site, or use your package manager / Flatpak
  (`flatpak install flathub org.godotengine.Godot`)
- Windows: download the `.exe` from the site

**2. Get the game:**

```bash
git clone https://github.com/mrshapron/brick-stunt-rally.git
cd brick-stunt-rally
```

**3. Run it:**

```bash
# Easiest: open the project in the Godot editor and press F5
godot project.godot

# Or launch it straight from the command line (from the project folder):
godot --path .

# macOS, fully detached from the terminal:
open -a Godot --args --path "$(pwd)"
```

The first launch imports the bundled font and builds shader caches, so give it a
few seconds. That's it — no build step, no package manager, no assets to download.

## A peek under the hood

Everything is procedural and code-driven, which made it really fun to iterate on:

- `scripts/vehicle.gd` — the arcade car: raycast-wheel suspension, tire grip, body
  lean, and it rebuilds its whole body/wheels/rockets from your Laboratory design.
- `scripts/level_gen.gd` — generates every level (and the combat arenas) from a
  seed, scaling difficulty by world and level.
- `scripts/lab.gd` / `scripts/car_lib.gd` — the voxel car builder and the car catalog.
- `scripts/drive_scene.gd` — the shared base for every drivable scene (lighting,
  environment, camera, scenery, the portal/transition stuff).
- `scripts/enemy.gd`, `scripts/missile.gd`, `scripts/effects.gd` — combat, rockets
  and all the explosions.

If you poke around and find a way to make the cars feel even better, I'm all ears.

## Things I might still do

- Proper drive-able loop-the-loops (right now they're optional rings to the side)
- More car parts in the Lab (different wheel sizes, cannons, boosters)
- A bit of music
- Camera shake on the big explosions because why not

The UI uses the [Bangers](https://fonts.google.com/specimen/Bangers) font
(SIL Open Font License) for that comic, kid-friendly vibe - the only outside
asset in the whole project.

Thanks for checking it out. It was a blast to build. 🚀
