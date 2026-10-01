# Life of Grimoire: Spell VFX

The spell visual-effects system for the Roblox wizard game **Life of Grimoire**, set up as a [Rojo](https://rojo.space) project.

The art direction is dark, anime-style magic: mostly black and white with very high contrast. Thick black ink and smoke wrap around bright white cores. Each impact adds jagged white electric arcs, a flat horizontal lens-flare streak, a radial shockwave, a cracked-ground decal, floating debris shards, a light flash and some camera shake. Only two spells use accent colours: InfernoSeal (crimson) and FrostRequiem (pale cyan).

| Key | Spell | Notes |
| --- | --- | --- |
| 1 | **GrimoireAwakening** | Summon: ink pages form a book, runes etch, the book opens, glyph ring and orbit trails appear |
| 2 | **VoidBurst** | Smoke implodes, then detonates in a white starburst with black shockwave arcs |
| 3 | **AbyssalAura** | Toggle loop: black flames, orbiting rings, drifting shards. Ends with a heavy flash |
| 4 | **ThunderJudgment** | Ink clouds gather, a flickering segmented bolt strikes, ground arcs and sparks bounce |
| 5 | **InfernoSeal** | A rune seal draws itself, then a black and crimson flame pillar rises and leaves embers |
| 6 | **FrostRequiem** | A line of crystal spikes with a white rim, frost mist, a star crack. Spikes shatter after 1.5 s |
| 7 | **GaleReaper** | A crescent wind slash travels to the target and splits into smaller crescents |
| 8 | **CelestialVerdict** | Ultimate: the sky dims, a sky rune circle appears and a pillar of light crashes down |

---

## Folder layout

```
default.project.json        Rojo project → maps src/ to Roblox services
packaging/                  Rojo projects that build drag-in .rbxm model files
tools/make_installer.py     generates dist/InstallGrimoireVFX.lua (command-bar installer)
dist/InstallGrimoireVFX.lua paste-into-Studio installer for other games
preview/                    browser mockup of every spell + screenshots
aftman.toml                 pinned rojo / stylua / selene versions
selene.toml, stylua.toml    lint + format config
src/
  ReplicatedStorage/
    VFX/
      Config.lua            ALL tunables: colours, sizes, timings, counts,
                            cooldowns, ranges, key binds, texture IDs, DEBUG flag
      VFXController.lua     loads every spell, exposes Play / Stop / StopAll
      Util/
        Types.lua           shared type definitions (EmitterSpec, BoltParams, ...)
        Emit.lua            emitters, bursts, anchors, tweens, per-frame steps, ground raycast
        CameraShake.lua     additive noise shake with distance falloff
        Flash.lua           PointLight flash, screen flash, horizontal lens-flare streak
        GroundDecal.lua     spreading crack decal + procedural crack lines, fades out
        Shockwave.lua       expanding beam ring / partial arcs
        Debris.lua          shards that rise, hang, then fall
        Lightning.lua       segmented jagged Beam bolts, branches, crackle, ground arcs
        OrbitTrail.lua      white trails orbiting a character (or a helix)
        RuneCircle.lua      self-drawing rune seal made of beams
      Spells/
        GrimoireAwakening.lua  VoidBurst.lua      AbyssalAura.lua   ThunderJudgment.lua
        InfernoSeal.lua        FrostRequiem.lua   GaleReaper.lua    CelestialVerdict.lua
    Remotes/                (created at runtime by SpellServer, not in the repo)
  ServerScriptService/
    SpellServer.server.lua  validation, cooldowns, broadcast
  StarterPlayer/StarterPlayerScripts/
    SpellClient.client.lua  receives broadcasts and renders the VFX
    VFXTestBinds.client.lua debug keys 1-8 + on-screen bind list
```

---

## Running it in Studio

1. Install the toolchain. The easiest way is [Aftman](https://github.com/LPGhatguy/aftman):
   ```sh
   aftman install          # installs rojo, stylua, selene from aftman.toml
   ```
   You can also install [Rojo 7.5+](https://rojo.space/docs/v7/getting-started/installation/) directly.
2. Install the **Rojo** Studio plugin. You can get it from the Creator Store, or run `rojo plugin install`.
3. Start the sync server from the repository root:
   ```sh
   rojo serve
   ```
4. In Roblox Studio, open any place (an empty Baseplate works), open the **Rojo** plugin panel and click **Connect**. The default address is `localhost:34872`. From then on, any file you save syncs into Studio straight away.
5. Press **Play**.

To build a standalone place file instead of syncing, run:
```sh
rojo build -o LifeOfGrimoireVFX.rbxlx
```
Place files are gitignored, so they never get committed.

---

## Copying the VFX into a different game

You don't need Rojo, git or this repo on the other device. Pick one of these:

**Option A: paste one script (easiest)**
1. Copy everything in [`dist/InstallGrimoireVFX.lua`](dist/InstallGrimoireVFX.lua). On GitHub, open the file, click **Raw**, then select all and copy.
2. In Roblox Studio, open the other game and go to **View → Command Bar**.
3. Paste the whole thing into the command bar and press **Enter**. The Output window prints `[GrimoireVFX] Installed.`
4. Press **Play**, then press keys 1-8.

The installer creates `ReplicatedStorage.VFX`, `ServerScriptService.SpellServer` and the two LocalScripts in `StarterPlayerScripts`. If any of these already exist it stops and tells you which ones, so it never overwrites your own scripts.

**Option B: drag in model files**
Build the four model files with `rojo build packaging/<Name>.project.json -o dist/<Name>.rbxm`, or ask for them to be sent to you. Then drag each one into Studio and put it in the right place:

| File | Put it in |
| --- | --- |
| `VFX.rbxm` | `ReplicatedStorage` |
| `SpellServer.rbxm` | `ServerScriptService` |
| `SpellClient.rbxm` | `StarterPlayer → StarterPlayerScripts` |
| `VFXTestBinds.rbxm` | `StarterPlayer → StarterPlayerScripts` (optional; debug keys) |

After you change any code, run `python3 tools/make_installer.py` to regenerate the installer.

**Preview without Studio:** open [`preview/index.html`](preview/index.html) in a browser to watch an animated mockup of all 8 spells. Stills are in `preview/screenshots/`. These are drawn on a 2D canvas from the Config timings and colours, so treat them as a guide to composition and pacing, not real in-engine renders.

---

## Testing with keys 1-8

`VFXTestBinds.client.lua` turns on when `Config.DEBUG = true`, which is the default.

* Press **1-8** to cast the spell bound to that key at your **mouse hit position**. If the target is further than the spell's `MaxRange`, it is pulled back to that range.
* A small label in the bottom-left corner lists the binds. Looping spells show **[ON]** while they are active.
* Press **3** again to stop AbyssalAura, which ends with the heavy white flash.
* Test casts go through the real server path, so cooldowns and range checks apply as normal.

To remove the debug binds and the label in a release build, set:
```lua
Config.DEBUG = false
```

---

## Replacing the placeholder textures

All textures live in **`Config.Textures`**:

```lua
Config.Textures = {
	Smoke    = "rbxasset://textures/particles/smoke_main.dds", -- REPLACE: 8x8 black ink smoke flipbook
	InkWisp  = ..., Spark = ..., Flare = ..., Ring = ..., Crack = ..., Shard = ...,
	Rune     = ..., Glyph = ..., Crescent = ..., Snow = ..., Ember = ..., Fire = ...,
}
```

* Entries that start with `rbxasset://` point to textures that ship with every Roblox client, so the effects show up before you upload anything.
* Entries set to `"rbxassetid://0"` (Ring, Crack, Rune, Glyph, Crescent) are not drawn until you replace them. Every effect that uses one also has a procedural fallback made from parts or beams, so nothing looks broken in the meantime.

To swap in your own art:

1. Upload your images in Studio (**Asset Manager → Bulk Import**), or through the Creator Dashboard.
2. Right-click each asset and choose **Copy Asset ID**, then paste it into Config. For example: `Smoke = "rbxassetid://1234567890"`.
3. **For flipbooks**, open `Config.Flipbook` and set:
   ```lua
   Enabled = true,                                   -- turn flipbooks on
   Layout = Enum.ParticleFlipbookLayout.Grid4x4,     -- most sprites
   LargeLayout = Enum.ParticleFlipbookLayout.Grid8x8,-- Smoke / Fire specs (LargeFlipbook = true)
   Mode = Enum.ParticleFlipbookMode.OneShot,
   ```
   `Enabled` defaults to `false` so the built-in placeholder images don't get cut into tiles. Each emitter spec marked `Flipbook = true` picks up these settings automatically.

---

## Tuning

Every tunable value is in `Config.lua`; the spell and utility files contain no magic numbers. Each spell has its own block:

```lua
Config.Spells.VoidBurst = {
	DisplayName = "Void Burst",
	Key = Enum.KeyCode.Two,  -- test bind
	Cooldown = 4,            -- seconds, enforced by the server
	MaxRange = 140,          -- studs
	Looping = false,
	VFX = { ImplodeTime = 0.4, ImplodeRadius = 9, Starburst = { ... }, Shake = "Medium", ... },
}
```

Shared presets live in `Config.Flash.Presets` (Small/Medium/Large/Ultimate) and `Config.CameraShake.Presets` (Light/Medium/Heavy/Ultimate). Reusable emitter specs live in `Config.Emitters`. The palette lives in `Config.Palette`.

Config entries are wrapped in typed constructors such as `spec({...})`, `bolt({...})` and `ring({...})`. This lets the Luau type checker catch a misspelled or missing field while you edit.

---

## Remote event flow

```
 Client (caster)                     Server (SpellServer)                    All clients (SpellClient)
 ───────────────                     ────────────────────                    ─────────────────────────
 key press
 CastSpell:FireServer(       ───▶    validate:
   spellName, targetPosition)          • arg types, finite Vector3
                                       • spell exists in Config
                                       • caster alive, has HumanoidRootPart
                                       • anti-spam + per-player cooldown
                                       • target within MaxRange (+ tolerance)
                                     looping spell? toggle server-side state
                                     PlaySpellVFX:FireAllClients(   ───▶     VFXController.Play(
                                       casterUserId, spellName,                spellName, character,
                                       origin, targetPosition,                 targetPosition, active)
                                       active?)                              → particles, beams, tweens
```

* The server **never** creates particles, and none of its handlers yield. The only scheduling it does is a `task.delay` that enforces AbyssalAura's `MaxDuration`.
* `ReplicatedStorage.Remotes` (holding `CastSpell` and `PlaySpellVFX`) is created by the server at startup.
* For looping spells the server sends `active = true/false`, which keeps every client in agreement. Loops also stop on death, respawn, player leave and `MaxDuration`.
* Each client renders every cast locally under `Workspace.GrimoireVFX`. All instances are removed by `Debris` or an explicit `Destroy`, and every tween is finite, so repeated casts don't leak anything.

To cast from your own gameplay code, from any LocalScript:
```lua
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
remotes:WaitForChild("CastSpell"):FireServer("VoidBurst", targetPosition)
```

---

## Adding a new spell

1. **Add a Config block.** In `Config.lua`, add an entry inside the `Config.Spells = { ... }` table, and add its name to `Config.SpellOrder`. Adding it inside the table keeps it strictly typed, and the local helpers `Emitters`, `Palette`, `ring(...)` and `LIGHT_BRIGHTNESS` are in scope there:
   ```lua
   ShadowLance = {
   	DisplayName = "Shadow Lance",
   	Key = Enum.KeyCode.Nine,
   	Cooldown = 4,
   	MaxRange = 120,
   	Looping = false,
   	VFX = {
   		Flash = "Medium",
   		Shake = "Medium",
   		Sparks = { Spec = Emitters.WhiteSparks, Count = 40 },
   		Ring = ring({ StartRadius = 1, EndRadius = 14, Duration = 0.4, Segments = 28, Width = 1,
   			Color = Palette.White, LightEmission = 1, Brightness = LIGHT_BRIGHTNESS }),
   	},
   },
   ```
2. **Create `src/ReplicatedStorage/VFX/Spells/ShadowLance.lua`:**
   ```lua
   --!strict
   --[[
   	ShadowLance (key 9)
   	Short description of what the effect looks like.
   ]]

   local Config = require(script.Parent.Parent.Config)
   local Util = script.Parent.Parent.Util
   local CameraShake = require(Util.CameraShake)
   local Emit = require(Util.Emit)
   local Flash = require(Util.Flash)
   local Shockwave = require(Util.Shockwave)
   local Types = require(Util.Types)

   local C = Config.Spells.ShadowLance.VFX

   local ShadowLance = {}

   function ShadowLance.Play(_character: Model, targetPosition: Vector3)
   	local ground = Emit.groundAt(targetPosition)
   	Flash.Impact(ground, C.Flash)
   	Emit.burstAt(CFrame.new(ground), C.Sparks)
   	Shockwave.Ground(ground, C.Ring)
   	CameraShake.Preset(C.Shake, ground)
   end

   -- Looping spells also export Stop(character).
   local module: Types.SpellModule = { Play = ShadowLance.Play }
   return module
   ```
3. **Register it** in `VFXController.lua`:
   ```lua
   ShadowLance = require(SpellsFolder.ShadowLance),
   ```
   That's all. The server, the client and the test binds read the spell list from Config, so they pick it up automatically.

Rules for spell files:
* Fire bursts with `:Emit(n)` (through `Emit.burstAt` or `Emit.pulse`) rather than a constant `Rate`. The one exception is a looping aura.
* Use only finite tweens (`Emit.tween`).
* Clean up every instance, either by using a host part with a lifetime (`Emit.anchor(cf, lifetime)`) or by calling `Emit.cleanup`.
* Read every value from Config.

---

## Linting & formatting

```sh
stylua src            # format
selene src            # lint (std = "roblox"; first run downloads the API dump)
rojo sourcemap -o sourcemap.json   # for luau-lsp / strict type checking in your editor
```
