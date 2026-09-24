# RetroSnake

Multiplayer-style Snake for iOS with a CRT arcade neon-vector aesthetic. Bots only for now; real multiplayer (GameKit / MultipeerConnectivity) planned later.

## Build

```
xcodegen
open RetroSnake.xcodeproj
```

Deployment target: iOS 17, portrait only.

## Layout

- `RetroSnake/App/` — SwiftUI `@main` entry
- `RetroSnake/Game/` — pure model: grid, snakes, food, tick, bot AI (no UIKit/SwiftUI deps)
- `RetroSnake/UI/` — SwiftUI views: menu, Canvas board, HUD, CRT overlay

## Design notes

- Grid-locked movement, swipe to turn (cannot reverse onto own neck).
- One player snake + N bot snakes on a shared board.
- Bot AI picks direction each tick by scoring the 3 non-reverse moves: hard-fail on immediate death, prefer larger reachable-area (flood fill), tiebreak by Manhattan distance to nearest food.
- Rendering is SwiftUI `Canvas`. The neon bloom is a stack of blurred copies of the same draw closure with `.blendMode(.plus)`.
- Tick frequency lives on `GameState` and speeds up modestly as snakes grow.
