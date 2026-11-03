# THE WAITING — Performance (0.3.0)

iOS is the product platform; Windows is the development platform. This file
keeps the two strictly apart: section A is **measured**, section B is
**recommended and not yet verified** — no iOS hardware has run this build.

## Renderer decision

| | Compatibility (OpenGL ES 3) | Mobile (Metal on iOS) |
|---|---|---|
| Oldest iOS GPU (Godot docs) | Apple A7 (iPhone 5S), OpenGL ES 3.0 | Apple A12 (iPhone XR/XS), Metal 3 |
| Oldest iOS version (Godot docs) | not separately listed | iOS 16 (Metal) |
| Godot's guidance | recommended for 2D; low base cost, best for low-end mobile | "slower than Compatibility" on older hardware; medium base cost |
| Features this game uses | 2D lights, one shadowed light, CanvasModulate, canvas shaders, CPU particles — all supported | same, plus HDR 2D (unused) |
| Risk | Apple deprecated OpenGL ES (still shipping) | none for 2D, but drops A9–A11 devices |

**Choice: Compatibility on iOS** (`rendering/rendering_method.mobile="gl_compatibility"`,
unchanged). It is what Godot recommends for 2D, it has the lowest per-frame
base cost (battery), and it is the only option that reaches iPhones older than
the XS. The decision was not based on Windows results — on this laptop the
Mobile renderer was actually *faster* before optimisation (table A3).

**Keep Mobile as the documented fallback** if a future iOS release removes
OpenGL ES, or if on-device profiling shows Compatibility misbehaving: switch
`rendering/rendering_method.mobile` to `"mobile"` and raise the export's
minimum iOS to 16. No game code depends on the renderer.

**Desktop stays on Compatibility too**, so what you see while developing is
what iOS draws. The Mobile renderer can still be tried on desktop with
`--rendering-method mobile` (comparison only).

Sources: [Godot — Renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html),
[Godot — System requirements](https://docs.godotengine.org/en/stable/about/system_requirements.html).

## A. Windows development environment (measured)

Machine: HP ProBook 640 G2, Intel HD Graphics 520, 8 GB RAM, 1920×1080 @ 60 Hz.
Renderer: Compatibility via ANGLE → Direct3D 11 (Godot forces ANGLE on this
Intel driver; kept by choice). Window 1280×720. Tool:
`godot --path . -- --profile=fpstest --reset-save --selftest-fps`.

### A1. Before and after (ANGLE, walking through the cave)

| Build | FPS | Frame time p50 / p99 / max | Frames > 25 ms (6 s) |
|---|---|---|---|
| 0.1 (every stroke drawn per frame) | ~6 | — | — |
| 0.2 (layers and props baked) | 24.9 | 37.7 / 61.5 / 68.8 ms | 150 |
| **0.2.1 (this pass)** | **58.5–60.0** | **16.7 / 18.6–22.7 / 29–34 ms** | **2–3** |

Full 0.2.1 profile (bake scale 1.0):

| Phase | FPS | p50 | p99 | max | > 25 ms | Draw calls |
|---|---|---|---|---|---|---|
| Walking right | 58.5 | 16.9 | 22.7 | 34.4 | 3 | 95 |
| Walking left | 60.1 | 16.6 | 19.8 | 20.8 | 0 | 96 |
| Reading (text open) | 56.8–60.0 | 16.7 | 17.7–22.9 | 19.5–24.7 | 0 | 106 |
| Pause menu | 30.3 (by design) | 33.3 | 33.4 | 34.1 | — | 111 |

### A2. Memory (ANGLE)

| | Bake scale 1.0 | Bake scale 1.5 |
|---|---|---|
| Baked layer textures | 44.4 MB | 99.8 MB |
| All textures (Godot monitor) | 76.1 MB | 152.3 MB |
| Video memory (Godot monitor) | 92.5 MB | 166.6 MB |
| Static (script/engine) memory | 43.1 MB | 43.1 MB |
| Nodes in the game scene | ~200 | ~200 |

### A3. Mobile renderer on the same laptop (before this pass, comparison only)

| Phase | FPS | p50 / p99 / max |
|---|---|---|
| Walking | 59.7–60.3 | 16.7 / 21 / 22–57 ms |
| Pause menu | 60.3 | 16.7 / 17.1 / 31.7 ms |
| Memory | static 66.1 MB, video 118.7 MB | — |

### A4. Bottlenecks found (by elimination, ANGLE)

| Cost | Evidence | Fix |
|---|---|---|
| Thousands of separate strokes per frame | 6 fps; freezing layers → big gain | 0.2: bake static layers and props to textures |
| 8 prompt glyphs rebuilding draw commands every frame | 29 → 48 fps when hidden | Glyphs drawn once; bob/pulse/fade via transform and modulate |
| The creature rebuilding ~25 draw commands every frame | 41 → 60 fps when frozen | Body, face, eyes, bulb drawn once and moved by transform; only hem, stalk and moving legs redrawn |
| Lights, lantern shadow, particles, physics, vignette shader | ≤ 2 fps each, within noise | Kept as they are (no visual changes) |
| Draw-call count itself | Pause menu: 107 draws at 60 fps | Not a bottleneck; left alone |

The lesson for iOS: the expensive thing was not drawing but *re-issuing*
drawing every frame. That is CPU time — on iPhone, battery.

## B. Intended iOS environment (not verified on hardware)

Nothing in this section has been measured on an iPhone or iPad.

### B1. What the build does on iOS

| Area | Setting / behaviour |
|---|---|
| Renderer | Compatibility (OpenGL ES 3) — `rendering/rendering_method.mobile` |
| Frame rate | 60 fps cap, also on 120 Hz ProMotion (`application/run/max_fps=60`, PowerManager) |
| Pause menu | 30 fps (scene frozen) |
| App inactive but visible (Control Center, banners) | 10 fps (PowerManager, mobile only) |
| Backgrounded | iOS suspends; SaveManager saves on `APPLICATION_PAUSED`; TimeManager credits the gap once on `APPLICATION_RESUMED` (tested: 3.00 s suspension → 3.06 s credited) |
| Static art | Baked once at load under the opening fade; tally and caps rebake only when a real day passes |
| Per-frame redraws | Creature hem + stalk (+ legs while walking), pool ripples while active; everything else animates by transform/modulate |
| Lights | 6 in the home cave; 1 with shadows (the lantern, PCF5) |
| Textures | Imported textures use ETC2/ASTC (`import_etc2_astc=true`); baked layers are uncompressed RGBA8, cropped to painted pixels |
| Background work | None while suspended; no timers poll anything but autosave (20 s) and the rare ambient sound |

### B2. Recommended iOS settings

| Setting | Recommendation | Why |
|---|---|---|
| Renderer | Compatibility | see decision above |
| `the_waiting/rendering/bake_scale` | **1.0** to start; test **1.5** on 3 GB+ devices | 1.0 is softer on Retina screens (canvas renders at native resolution, art is baked at 1×); 1.5 is sharper but doubles texture memory (A2) |
| Max fps | 60 | battery; the game's motion is slow |
| Stretch mode | keep `canvas_items` | crisp text and creature on Retina; only reconsider if GPU time is too high on the oldest device |
| Export min iOS | Godot default for Compatibility | raise to 16 only if switching to Mobile/Metal |

### B3. What to measure on the first device builds

Test on at least: the oldest target (iPhone 8 / A11 or iPhone 7 / A10),
a recent iPhone, and an iPad.

1. Xcode → Instruments → **Time Profiler** and **Metal System Trace**: CPU
   and GPU frame time while walking; target ≤ 12 ms GPU on the oldest device.
2. **Energy Log**: energy impact in gameplay, in the pause menu (should drop
   with the 30 fps cap) and with Control Center pulled down (10 fps).
3. **Allocations / VM Tracker**: total memory at bake scale 1.0 and 1.5.
4. Godot debug monitors over the remote debugger: FPS, draw calls, texture
   memory — compare with section A.
5. Background the app for 10 minutes; confirm the countdown and save on return.
6. Check visual sharpness of baked layers at native resolution; decide
   bake scale per device class.

If GPU time is too high on the oldest device, levers in order of visual cost:
lantern shadow filter PCF5 → PCF3; vignette grain off; bake scale 0.75 for the
far wall only; finally `viewport` stretch mode.

## A5. 0.3 areas (ANGLE, walking, two runs)

Tool: `-- --profile=fpstest --reset-save --selftest-fps-areas` (windowed).

| Area | FPS | p50 / p99 frame ms | Draw calls | Textures |
|---|---|---|---|---|
| Home | 58.5–60.2 | 16.6–16.7 / 18.5–21.4 | 101–102 | 75 MB |
| Narrow Way | 59.2–59.4 | 16.6–16.7 / 21–22 | 99 | 55 MB |
| Hall of Echoes | 58.0–59.3 | 16.7 / 22–27 | 104 | 67 MB |
| Still Garden | 59.5–60.0 | 16.7 / 19–22 | 101 | 58 MB |

Only one room is loaded at a time: texture memory at home was 75.1 MB before
a full round trip through all four areas and 75.6 MB after (no leak).
The Still Garden first measured 359 draw calls / 53 fps (the glowing moss was
drawn stroke by stroke); baking it like other static art brought it to 101.
Not verified on iOS hardware.
