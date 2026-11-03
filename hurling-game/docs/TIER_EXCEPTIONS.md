# Tier exceptions (owner-approved)

Places where Hurling Heroes draws something above the player's own graphics level, with the owner's approval. Each
one names the note that approved it.

## Free-taking practice: the taker, his hurley, the ball and the posts at full detail

- **Approved:** the owner's decision, relayed by the lead on 3 November 2026 ("practice graphics: the middle
  ground").
- **Full detail on every tier:**
  - the free-taker: the HD body at its full mesh, the kit's full look, his shadow on the grass (`Player.make_full_detail`);
  - his hurley (on that body);
  - the sliotar;
  - the posts and crossbar: drawn whole over the baked light on Low and Medium (`Stadium._posts`).
- **The player's own level:** the crowd (cards on Low), the stands, the venue's extras and effects, as in a quick
  match at that ground. On High, the practice keeps its sharpest look (`Practice._best_look`) and the 3D crowd
  behind the goal at High's budget.
- **Test:** `_practice_low` in tests/test_runner.gd (an owner-note test).
- **Replaces:** 0.15–0.23, where practice forced High graphics for its whole length.
