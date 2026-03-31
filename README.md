# horror-battler

A dark auto-battler demo alpha. Cursed creatures. Grotesque synergies. Watch them murder each other.

---

![screenshot](screenshot.png)
> *(screenshot coming)*

---

## What it is

Turn-based auto-battler in the vein of Super Auto Pets, except everything on your bench is wrong. You shop for units with names like "Crawling Molar" and "The Teeth Collector," position them, and hit fight. They handle the rest.

10 rounds. Pre-built enemy lineups that scale up. You lose health equal to surviving enemy units after each loss. Reach 0 HP and you're done.

## How it plays

**Shop phase** — You get 3 units to choose from. Buy, sell, reroll. Duplicate units merge and upgrade. Max 5 on your bench.

**Arrange phase** — Drag to reorder. Front units get hit first. Position matters.

**Combat phase** — Fully automated. Units attack front-to-back, alternating sides. Abilities and synergies fire. You watch.

**Result** — Win/loss screen. Restart or keep going.

## Features

- 10 units across 3 tiers with distinct abilities
- 6 synergy tags (Flesh, Swarm, Signal, Parasite, Omen, Relic) with 2-unit and 3-unit thresholds
- Full ability system: on-death damage, stat theft, ATK copying, kill rewards, targeting overrides, etc.
- Synergy glow indicators and stat-change animations during combat
- Floating damage numbers and ability triggers with visual feedback
- Stat steal animation (number slides from target to attacker)
- 10 pre-built enemy rounds with a buffed boss on round 10
- Tooltip on hover for unit stats and ability descriptions
- Upgrade system: duplicate merging with star indicators and border glow
- Win/loss tracking with kill count and win streak stats

## How to run

1. Clone the repo
2. Open Godot 4.x → Import Project → point it at the project folder
3. Hit Play

That's it. No dependencies, no setup.

## Tech stack

- [Godot 4.x](https://godotengine.org/) — engine
- GDScript — all game logic
- [Claude Code](https://claude.ai/code) — built almost entirely with it

## Built With

The heavy lifting on this was done by [Claude Code](https://claude.ai/code) (Anthropic's CLI agent). Combat resolution, synergy system, animation playback, UI wiring, bug hunting — most of it was pair-programmed with the agent in WSL across a few sessions.

This is a demo alpha. It works. It's not pretty. That was the goal.
