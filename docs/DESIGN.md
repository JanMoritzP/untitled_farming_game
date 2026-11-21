# Design notes

## Pillars

1. **Chains over clicks.** The fun is deciding how far up a chain to take each crop, not clicking faster.
   Every processing step adds value but costs time, machine access and ingredients from other chains.
2. **Cozy, not trivial.** A real-time day timer creates gentle pressure; failure states are soft (debt, withered
   crops, expired contracts), never a hard game over.
3. **Replayability through rules, not grind.** Modes, difficulties and stackable challenges change *how you must
   think*, and each challenge multiplies the score.
4. **Everything is data.** New crops, recipes, machines, weather, modifiers and scenarios are JSON; mods use the
   same files as the base game.

## Systems (all implemented)

* **Calendar**: 4 seasons x 7 days (data-driven). Crops list the seasons they grow in; unfinished crops wither at
  the season change. Weather is drawn per season with weights; tomorrow's weather is the forecast.
* **Weather**: growth multipliers, frost kills `frost_sensitive` crops, "bad" weather is scaled by difficulty/challenges.
* **Plots**: 6x4 grid. Lease (per season, auto-renew, lapses if unpaid) or buy; the price rises with every plot owned.
  Fertility drains on harvest (extra for monoculture), recovers slowly when fallow, or with compost.
* **Quality**: Normal / Fine / Gold from fertility, worth 1.0 / 1.3 / 1.7x, averaged through recipes.
* **Machines**: rent per batch or buy (extra copies = parallel slots). Recipes are `inputs -> outputs` with a time.
  Byproducts (straw) feed animals and the composter, so waste is a loop, not a dead end.
* **Market**: per-item demand drops 3% per unit sold and recovers 35% of the gap each night, pulled toward a seasonal
  target (stew in winter, pie in autumn...). Contracts pay 1.5-2x with deadlines and optional quality minimums.
* **Journal**: persistent discoveries (goods, recipes, weather, seasons), career stats, best scores per mode.
* **Modes**: First Year, Sprint, Three Years, Endless, Scenarios, Daily (seeded by date).
* **Modifiers**: see below. They are plain `effects` dictionaries combined by naming convention:
  `ban_tags` unions, `*_mult` multiplies, `max_*` takes the minimum, booleans OR, anything else adds.

## Challenge modifiers

Implemented (15): Vegan Farm, One Machine, Renter's Life, Boutique Farm, Single Crop Season, Zero Waste, Hurried,
Harsh Weather, Cheap Customers, Blind Farmer, No Fridge, Tired Soil, Free Market, Bread is Banned, No Sweet Tooth.

Ideas to add next (most need only a data entry plus a small `fx` hook in `farm_state.gd`):

| Idea | Rule |
|---|---|
| **Debt Collector** | start with +$1000 but owe 4% interest daily; pay it off to score |
| **Monsoon Season** | rain every other day; crops love it, but machines flood (rent doubled on rainy days) |
| **Hermit** | no contracts and no market on odd days |
| **Specialist** | crops of a single *category* only (grains, fruit, veg) |
| **Fast Food** | every recipe takes half as long, but sells for 25% less |
| **Pickiest Town** | each good may only be sold 5x per day |
| **Craftsperson's Pride** | raw crops can't be sold, only processed goods |
| **Seed Money** | seeds cost 3x, but harvests yield +50% |
| **Rotating Menu** | every season one random good is banned |
| **Heirloom** | a single plot that can never be replanted twice with the same crop |
| **Slow Burn** | crops take twice as long, prices are doubled |
| **Fragile Soil** | fertility never recovers on its own, compost is the only way |
| **Long Winter** | winter lasts 14 days |
| **No Rent Relief** | machines must be rented, you can only buy one |
| **Blackout** | machines stop working in the last third of each day |
| **Landlord Strike** | leases cost 3x but renew at a fixed price forever |

## Roadmap

1. **Content**: more crops (carrot, tomato, grapes -> wine), orchards (perennial trees), bees/honey, fish pond,
   cheese ageing, a second tier of machines (bigger, faster, more expensive).
2. **Townsfolk and reputation**: buyers with tastes (restaurant wants tier-3 goods, kids want sweets); reputation
   unlocks recipes and machines; story campaign inherited farm.
3. **Events**: market day, festivals, travelling merchant, droughts with warnings.
4. **Meta progression**: unlock new crops/machines across runs from the journal (roguelite option with starting perks).
5. **Polish**: real pixel art, animated crops, sound and music (layers that grow richer with farm productivity),
   settings, accessibility, localisation (all strings are in data or UI code, ready to extract).
6. **Mod tooling**: in-game mod list/enable toggles, Steam Workshop style folders, schema docs.
7. **Co-op** is intentionally out of scope.

## Why Godot

Mouse-driven 2D UI with lots of data: Godot's Control nodes, theming and tooltips do most of the work, GDScript
iterates quickly, exports are small (web build possible), and there are no royalties. Performance is a non-issue
because the simulation is plain data ticked once per frame; nodes are used for presentation only.
