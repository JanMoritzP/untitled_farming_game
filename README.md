# Untitled Farming Game

A cozy, real-time farming game about **long production chains**. Grow wheat, mill it into
flour, bake bread, sell it. Sell earlier for less, or climb the chain for much more.
Lease or buy land, rent machines per batch or buy them outright, and plan around seasons,
weather and a market that reacts to everything you sell. Everything is played with the mouse.

Built with **Godot 4.3** (GDScript, GL Compatibility renderer, pixel art).

## Running

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, no .NET needed).
2. Open this folder as a project (the first open imports assets), then press **F5**.
   Or from a terminal: `godot --path .`

## How it plays

* A **real-time day timer** ticks down; when it runs out the day ends and you get a summary.
  Speed up with 2x/3x. Cozy difficulty lets you pause.
* **Plots**: click a locked plot to lease it (per season, auto-renews) or buy it.
  Select seeds on the toolbar, then click or **drag** across empty plots. Click ripe crops to harvest.
* **Seasons and weather**: crops only grow in their seasons and wither if the season ends first.
  Rain speeds growth, storms and heatwaves slow it, frost kills sensitive crops. Check the forecast!
* **Soil fertility** drops when you harvest (faster when repeating the same crop) and affects yield and quality.
  Compost it back up with straw.
* **Machines** (Machines tab): rent per batch, or buy to run for free. Buy more copies to run in parallel.
* **Market**: every unit you sell pushes that item's price down; it recovers overnight. Quality (Normal, Fine, Gold)
  carries through the whole chain. **Contracts** (Orders tab) pay well above market.
* **Farm journal**: discoveries persist across runs.

### Modes, difficulties and challenges

| Mode | |
|---|---|
| The First Year | reach a net worth goal in 28 days |
| Sprint / Three Years | 14 or 84 day versions |
| Endless | no goal |
| Scenarios | hand-made puzzles with fixed rules (see `data/scenarios.json`) |
| Daily Farm | same seed and two random challenges for everyone, each date |

Difficulties: **Cozy**, **Normal**, **Hard**. On top of any mode you can stack **challenge modifiers**
(Vegan Farm, One Machine, Renter's Life, Boutique Farm, Single Crop Season, Zero Waste, Hurried, Harsh Weather,
Cheap Customers, Blind Farmer, No Fridge, Tired Soil, Free Market, Bread is Banned, No Sweet Tooth).
Each one multiplies your final score.

## Project layout

```
data/                 all game content as JSON (items, crops, machines, recipes, seasons, weather,
                      modifiers, difficulties, modes, scenarios)
scripts/core/         pure simulation: content_db.gd, farm_state.gd (the whole game rules), journal.gd
scripts/autoload/     game.gd: current run, save/load, daily seed
scripts/ui/           UI built in code: game_screen, menu, plot_view, panels/*, pixel_art (procedural sprites)
tests/                test_sim.gd (127 checks), balance.gd (bot), ui_driver.gd (screenshots)
docs/DESIGN.md        design notes, ideas and roadmap
docs/example_mod/     a working example mod
```

The simulation (`FarmState`) has no dependency on nodes or UI, so it is fully testable headless and
the UI only calls its action methods (`plant`, `harvest`, `sell`, `queue_job`, ...) and reacts to its signals.

## Tests

```bash
tests/run_all.sh                       # or: GODOT=/path/to/godot tests/run_all.sh
godot --headless --path . -s tests/balance.gd      # greedy-bot economy probe, for tuning goals
```

`tests/ui_driver.tscn` drives the real UI and saves screenshots (needs a display, e.g. `xvfb-run`):
`xvfb-run -a godot --path . tests/ui_driver.tscn -- /output/dir`

## Modding

Drop a folder in the game's `user://mods/` directory (Godot: *Project > Open User Data Folder*):

```
mods/my_mod/data/crops.json      (any of the data file names, only the ones you need)
```

Each file is a JSON array of entries with an `id`. A new id adds content; an existing id replaces the entry,
or merges into it when you set `"_patch": true`. Invalid entries are dropped with a warning, never a crash.
Art is optional: icons are generated from `color` and `shape`, or drop a PNG at
`assets/items/<id>.png` / `assets/machines/<id>.png`. See `docs/example_mod/` for a complete example.

## Art and fonts

All art is generated procedurally as placeholder pixel art. To use a pixel font, put a TTF at
`assets/fonts/pixel.ttf` and it is picked up automatically.
