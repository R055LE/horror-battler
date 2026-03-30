# Auto-Battler Demo Alpha — Design Document

**Engine:** Godot 4.x (GDScript)
**Scope:** Throwaway demo alpha — prove the core loop works
**Status:** Concept

---

## Core Concept

You assemble a lineup of things that shouldn't exist. Parasites, cursed artifacts, glitched organisms, cryptids. Each round you shop for units, position them on your bench, and watch them fight autonomously against an AI opponent's lineup. Between rounds, the shop refreshes and enemies scale. You lose when your lineup gets wiped. You win by surviving all rounds.

The tone is dark, weird, and slightly funny — the humor comes from min-maxing synergies between grotesque things.

---

## Core Loop

```
SHOP PHASE → ARRANGE PHASE → COMBAT PHASE → RESULT → repeat
```

### Shop Phase
- Player is presented with 3-4 unit choices from the unit pool
- Player has gold to spend (starts at 10, gains 10 per round, +1 per win streak up to +3)
- Units cost 1-3 gold depending on tier
- Player can buy units and place them on their bench (max 5 active slots)
- Player can sell units back for 1 gold (regardless of purchase price)
- Player can reroll the shop for 1 gold
- Buying a duplicate of a unit you already own upgrades it (stat boost, keeps synergy tags)

### Arrange Phase
- Player can reorder their 5 bench slots (left to right = front to back)
- Position matters: front units get hit first, back units attack longer
- This can be combined with shop phase in the UI (drag to reorder)

### Combat Phase
- Fully automated — no player input
- Units attack in order (front to back, alternating sides)
- Each unit attacks the frontmost enemy unit
- Combat resolves until one side is fully eliminated
- Animations should be simple: slide forward, flash, slide back

### Round Progression
- 10 rounds total for the demo
- Enemy lineups are pre-built (not procedural) and escalate in difficulty
- Round 1-3: 1-2 enemy units, low stats
- Round 4-6: 3-4 enemy units, mid stats, basic synergies
- Round 7-9: 4-5 enemy units, higher stats, strong synergies
- Round 10: Boss round — 5 units with a unique boss unit

### Win/Loss
- Player has a health pool of 10
- Losing a round costs health equal to the number of surviving enemy units
- Reaching 0 health = game over
- Surviving all 10 rounds = win
- Win/loss screen with option to restart

---

## Unit System

### Unit Stats
Each unit has:
- **Name** — something unsettling or weird
- **HP** — health points
- **ATK** — damage dealt per attack
- **Tier** — 1 (common), 2 (uncommon), 3 (rare) — determines shop cost and stat range
- **Synergy Tags** — 1-2 tags per unit that activate group bonuses
- **Ability** (optional) — a passive or triggered effect (keep simple for demo)

### Upgrades
- Buying a duplicate of an owned unit merges them
- First merge: +50% HP and ATK (rounded up)
- Second merge: +100% HP and ATK from base, gain ability upgrade if applicable
- Visual indicator for upgrade level (border glow or star count)

---

## Unit Roster (10 Units)

### Tier 1 (Cost: 1 gold)

| Unit | HP | ATK | Tags | Ability |
|------|-----|-----|------|---------|
| **Crawling Molar** | 3 | 1 | Flesh, Swarm | None |
| **Moth Lantern** | 2 | 2 | Signal, Swarm | On death: deal 1 damage to attacker |
| **Leaking Eye** | 4 | 1 | Flesh, Omen | None |
| **Rust Tick** | 2 | 1 | Parasite, Swarm | Start of combat: steal 1 ATK from target |

### Tier 2 (Cost: 2 gold)

| Unit | HP | ATK | Tags | Ability |
|------|-----|-----|------|---------|
| **Bone Radio** | 5 | 3 | Signal, Relic | Adjacent allies with Signal tag get +1 ATK |
| **Gut Prophet** | 6 | 2 | Flesh, Omen | On ally death: gain +2 ATK |
| **Host Sleeve** | 4 | 2 | Parasite, Flesh | Start of combat: copy the ATK of the unit behind it |
| **Frequency Worm** | 3 | 4 | Parasite, Signal | Attacks the weakest enemy instead of the front |

### Tier 3 (Cost: 3 gold)

| Unit | HP | ATK | Tags | Ability |
|------|-----|-----|------|---------|
| **The Teeth Collector** | 8 | 4 | Relic, Omen | On kill: permanently gain +1 HP |
| **Antenna Corpse** | 7 | 5 | Signal, Relic | All Signal units attack first (before normal order) |

---

## Synergy System

Synergies activate when you have 2+ units sharing a tag on your bench. Having 3+ gives a stronger bonus.

| Tag | 2-Unit Bonus | 3-Unit Bonus |
|-----|-------------|-------------|
| **Flesh** | All Flesh units gain +1 HP | All Flesh units regenerate 1 HP per attack |
| **Swarm** | All Swarm units gain +1 ATK | Swarm units attack twice (second attack at half ATK) |
| **Signal** | All Signal units gain +1 ATK | Signal units can't be targeted until a non-Signal ally dies |
| **Parasite** | Parasite units steal 1 HP on hit | Parasite units steal 1 ATK on hit (permanent) |
| **Omen** | All units gain +1 HP | On any ally death, all surviving allies gain +1 ATK |
| **Relic** | All units gain +1 ATK | Relic units take 1 less damage from all attacks (min 1) |

---

## Combat Resolution (Detailed)

### Turn Order
1. Pre-combat triggers fire (Rust Tick steals ATK, Host Sleeve copies ATK, Antenna Corpse reorders)
2. Synergy bonuses are applied
3. Units attack in slot order: Player slot 1, Enemy slot 1, Player slot 2, Enemy slot 2, etc.
4. A unit attacks the frontmost living enemy (unless ability overrides this)
5. When a unit dies, on-death effects trigger immediately
6. Continue until one side is eliminated

### Damage Calculation
```
damage_dealt = attacker.ATK - target.damage_reduction
minimum damage = 1
```

### Edge Cases
- If both sides' last units kill each other simultaneously: player wins (tiebreaker)
- Stolen stats persist for the rest of combat only (reset between rounds) unless ability says "permanently"
- Synergy bonuses recalculate if a unit dies mid-combat and drops below the threshold

---

## Enemy Scaling

Pre-built enemy lineups (not procedural). Each round has a fixed team.

| Round | Enemy Team | Notes |
|-------|-----------|-------|
| 1 | 1x Crawling Molar | Tutorial punching bag |
| 2 | 2x Leaking Eye | Slightly tankier |
| 3 | 1x Rust Tick, 1x Moth Lantern | Introduces abilities |
| 4 | 2x Crawling Molar, 1x Bone Radio | First enemy synergy (Flesh + Signal) |
| 5 | 3x Frequency Worm | Swarm of targeted attackers |
| 6 | 2x Gut Prophet, 1x Moth Lantern | Omen synergy, snowballs if you're slow |
| 7 | 2x Host Sleeve, 2x Rust Tick | Parasite synergy, stat theft |
| 8 | 1x Antenna Corpse, 2x Bone Radio, 1x Moth Lantern | Full Signal comp |
| 9 | 1x Teeth Collector, 2x Gut Prophet, 1x Leaking Eye | Omen + Relic, scaling threats |
| 10 | 1x Teeth Collector (buffed), 2x Antenna Corpse, 2x Frequency Worm | Boss round |

Boss round Teeth Collector starts with 15 HP and 8 ATK.

---

## UI Layout (Single Screen)

```
┌──────────────────────────────────────────────┐
│  ROUND: 3/10          HEALTH: ♥♥♥♥♥♥♥♥♥♥    │
│  GOLD: 7              WINS: 2                │
├──────────────────────────────────────────────┤
│                                              │
│  ENEMY BENCH (5 slots, top)                  │
│  [  ?  ] [  ?  ] [  ?  ] [  ?  ] [  ?  ]    │
│                                              │
│  ──── COMBAT ZONE (animation area) ────      │
│                                              │
│  PLAYER BENCH (5 slots, bottom)              │
│  [ unit ] [ unit ] [ unit ] [     ] [     ]  │
│                                              │
├──────────────────────────────────────────────┤
│  SHOP: [ unit ] [ unit ] [ unit ]  [REROLL]  │
│  ACTIVE SYNERGIES: Flesh(2) Swarm(2)         │
│                        [ READY / FIGHT ]     │
└──────────────────────────────────────────────┘
```

- Enemy units are hidden (shown as "?") until combat starts
- Clicking a shop unit buys it (if gold allows) and places it in first empty bench slot
- Dragging bench units reorders them
- Clicking a bench unit shows its stats in a tooltip
- Active synergies displayed at bottom with count
- "FIGHT" button starts combat phase

---

## Art Direction (Demo Alpha)

### Minimum Viable Art
- Units are colored rectangles or circles with a 1-2 letter abbreviation and stat numbers
- Each synergy tag has a distinct color: Flesh (red), Swarm (yellow), Signal (cyan), Parasite (green), Omen (purple), Relic (orange)
- Unit border color = primary synergy tag
- Upgrade stars shown as dots below the unit

### If Time Allows
- Midjourney-generated portraits for each unit (square, dark/weird style)
- Simple particle effects for combat (slash, impact flash)
- Synergy icons instead of colored borders

---

## Godot Architecture (Suggested)

```
Main (Node2D)
├── GameManager (script: manages state machine)
├── UI
│   ├── HUD (health, gold, round, synergies)
│   ├── Shop (3-4 unit slots + reroll button)
│   ├── FightButton
│   └── Tooltip
├── PlayerBench (5 UnitSlot nodes)
├── EnemyBench (5 UnitSlot nodes)
└── CombatZone (handles animation during fight)
```

### Key Scripts
- `game_manager.gd` — state machine (SHOP, COMBAT, RESULT), round progression, gold/health tracking
- `unit.gd` — unit resource/class with stats, tags, abilities, upgrade level
- `unit_slot.gd` — clickable slot that holds a unit, handles drag-and-drop
- `shop.gd` — generates shop offerings from pool, handles buy/sell/reroll
- `combat.gd` — resolves combat turn by turn with optional animation delays
- `synergy.gd` — checks active synergies, applies bonuses
- `enemy_rounds.gd` — data file with pre-built enemy lineups per round

### Data Structure
Units should be defined as Godot Resources (.tres files) or a dictionary/JSON so they're easy to tweak:

```gdscript
var unit_data = {
    "crawling_molar": {
        "name": "Crawling Molar",
        "hp": 3, "atk": 1, "tier": 1, "cost": 1,
        "tags": ["flesh", "swarm"],
        "ability": null
    },
    # ... etc
}
```

---

## Implementation Priority

### Phase 1 — Playable Skeleton
1. Game state machine (shop → combat → result loop)
2. Unit data structure and roster
3. Shop: display units, buy, sell
4. Bench: place units, reorder
5. Combat: basic turn resolution (no animation, just calculate outcome)
6. Win/loss condition and restart

### Phase 2 — Feels Like a Game
7. Combat animation (units slide and flash)
8. Synergy system
9. Unit abilities
10. Unit upgrades (duplicate merging)
11. Enemy round scaling
12. Health/gold UI

### Phase 3 — Polish (If You Get Here)
13. Tooltip with unit details on hover/click
14. Midjourney unit portraits
15. Sound effects (buy, sell, hit, death)
16. Screen transitions between phases
17. Win/loss screen with stats

---

## Notes for Claude Code

- Start with Phase 1. Get the loop working with placeholder rectangles before adding any complexity.
- Use signals for communication between nodes (Godot pattern).
- Keep combat resolution in a separate function that can run instantly (for testing) or with `await` delays (for animation).
- Unit abilities should be implemented as a match/switch on ability name — don't over-engineer an ability system for 10 units.
- Test by printing combat logs to console before building UI.
- GDScript style: snake_case for variables/functions, PascalCase for classes/nodes.
