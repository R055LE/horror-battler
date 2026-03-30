# Auto-Battler Demo Alpha — Godot 4.x

## Project Overview

A dark/weird auto-battler in the vein of Super Auto Pets. Player assembles a lineup of cursed creatures, positions them, and watches them fight AI opponents across 10 rounds. This is a throwaway demo alpha — prove the core loop works, nothing more.

Full design doc: @game-design-doc.md

## Environment

- Engine: Godot 4.x with GDScript
- Editor runs on Windows, Claude Code runs in WSL
- Project lives on Windows filesystem (accessible via /mnt/c/)
- Git initialized from WSL with `* text=auto` in .gitattributes

## GDScript Style

- snake_case for variables, functions, signals
- PascalCase for classes, nodes, enums
- Prefix private functions with underscore: `_calculate_damage()`
- Type hints on all function signatures: `func deal_damage(target: Unit, amount: int) -> void:`
- Use `@onready` for node references, never `get_node()` in `_ready()`
- Signals over direct method calls between nodes — loose coupling always
- Constants for magic numbers: `const MAX_BENCH_SLOTS := 5`
- Keep scripts under 200 lines. If a script is growing past that, split it.

## Architecture Rules

- Logic in .gd files, data in .tres files, scene structure in .tscn files
- Unit stats defined as Resource files (.tres), not hardcoded in scripts
- Game state machine in game_manager.gd: SHOP → COMBAT → RESULT
- Combat resolution must work both instantly (for testing) and with await delays (for animation)
- Use signals for all cross-node communication
- No autoloads unless absolutely necessary — prefer dependency injection via scene tree

## File Structure

```
project/
├── scenes/
│   ├── main.tscn
│   ├── ui/
│   │   ├── hud.tscn
│   │   ├── shop.tscn
│   │   └── tooltip.tscn
│   └── game/
│       ├── unit_slot.tscn
│       ├── player_bench.tscn
│       ├── enemy_bench.tscn
│       └── combat_zone.tscn
├── scripts/
│   ├── game_manager.gd
│   ├── unit.gd
│   ├── shop.gd
│   ├── combat.gd
│   ├── synergy.gd
│   └── enemy_rounds.gd
├── resources/
│   ├── units/          # .tres files for each unit type
│   └── rounds/         # .tres files for enemy round configs
└── assets/
    ├── sprites/        # placeholder art, eventually Midjourney portraits
    ├── fonts/
    └── audio/
```

## Implementation Phases

Build in order. Do not skip ahead.

### Phase 1 — Playable Skeleton
Game state machine, unit data, shop (buy/sell), bench (place/reorder), combat resolution (no animation, just calculate), win/loss + restart. Use colored rectangles for units.

### Phase 2 — Feels Like a Game
Combat animation (slide and flash), synergy system, unit abilities, unit upgrades (duplicate merging), enemy round scaling, health/gold UI.

### Phase 3 — Polish
Tooltips, Midjourney portraits, sound effects, screen transitions, win/loss stats.

## Testing

- Print combat logs to console before building combat UI
- Test combat resolution with hardcoded lineups before wiring up the shop
- After any .tscn or .tres edit, validate the file can be opened in the editor
- Run the project via Godot CLI to catch runtime errors: `godot --path . --headless --quit-after 5`

## Common Mistakes to Avoid

- Do NOT use `preload()` in .tres or .tscn files — use `ExtResource("id")`
- Do NOT use `[1, 2, 3]` syntax in .tres — use `Array[int]([1, 2, 3])`
- Do NOT nest `get_parent().get_parent()` chains — use signals or group queries
- Do NOT put UI logic in game logic scripts — keep them separated
- Do NOT create circular dependencies between scripts
- Do NOT generate .import files — Godot creates those automatically

## Git Workflow

- Commit after each working milestone, not after each file change
- Commit messages: imperative mood, under 72 chars
- Never commit .import/ directory or .godot/ directory contents
- Branch for experimental features, merge when stable

## Tone

This is a side project with no deadline. Favor simplicity over cleverness. If something works ugly, ship it and clean up later. The goal is a playable demo, not production code.
