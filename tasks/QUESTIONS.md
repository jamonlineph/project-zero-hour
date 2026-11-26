# Questions for the owner

Agents add questions here when a decision belongs to the owner. The owner answers inline, and answered questions are binding. Keep answered questions; don't delete them.

Format:

```
### Q-<number> · <short title> — OPEN | ANSWERED (date)
- Context: …
- Options: …
- Agent's recommendation: …
- Answer: …
```

---

### Q-1 · Final game name — OPEN
- **Context:** "Signal Front" is a codename. A trademark and store search comes first (P0-10).
- **Agent's recommendation:** let an agent shortlist names in P0-10, then pick one.
- **Answer:**

### Q-2 · Confirm the licenses — OPEN
- **Context:** ADR 0006 chose GPL-3.0-or-later for code and CC BY-SA 4.0 for assets.
  - These keep forks open.
  - MIT/CC BY would allow closed forks.
  - It's easy to change now, hard after outside contributors join.
- **Agent's recommendation:** keep GPL-3.0-or-later + CC BY-SA 4.0.
- **Answer:**

### Q-3 · Three or four factions at 1.0? — OPEN
- **Context:** four factions is about 25% more art and balance work. The roadmap's scope levers allow shipping the Irregulars as the first update.
- **Agent's recommendation:** plan for four, decide at the Phase 3 midpoint.
- **Answer:**

### Q-4 · Public or private repository until launch? — OPEN
- **Context:** public from day one attracts contributors and is honest open source. Private until the vertical slice avoids early judgement.
- **Agent's recommendation:** public from the start, with a clear "early development" note in the README.
- **Answer:**

### Q-5 · Money — OPEN
- **Context:** options:
  - free everywhere, with donations (GitHub Sponsors, Open Collective)
  - paid on Google Play, free on F-Droid and GitHub (the GPL allows selling)
  - no money at all
- **Agent's recommendation:** free with donations until 1.0, then decide.
- **Answer:**

### Q-6 · Art direction sign-off — OPEN
- **Context:** [docs/04-art-pipeline.md](../docs/04-art-pipeline.md) proposes "clean stylized realism". The owner should approve it, or change it, before final art starts (Phase 2).
- **Answer:**

### Q-7 · Native code for the simulation's hot spots? — OPEN
- **Context:** the performance harness (P1-33) measures about 9–12 ms per sim tick at 300 units on a desktop CPU, after GDScript optimizations that cut it from 34–79 ms. A mid-range phone is roughly 3× slower, and the budget there is 8 ms. The biggest costs are separation (units pushing apart), movement, vision and combat targeting. ADR 0004 allows a C++ GDExtension for hot spots only through a new ADR with your approval.
- **Options:**
  - **C++ GDExtension** for separation, movement and vision (same integer rules, same tests and golden replays). Fastest, but adds a C++ toolchain, including the Android NDK, to CI and to anyone building from source.
  - **Stay in GDScript** and cut work: for example, run separation every other tick, or cap units at about 200 on phones. Simpler, but it changes the game rules or the scale.
- **Agent's recommendation:** first measure on a real mid-range phone (P0-12 and P1-36). If it misses the budget there, approve the C++ route for separation and movement only.
- **Answer:**

