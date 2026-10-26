# Notes from a real match

The owner shared 40 minutes of a broadcast (RTÉ2) of Galway v Limerick at Croke Park, summer 2026, the first half
and half-time. It was studied for how the game is played, how the ground looks and feels, and how a strike sounds;
none of the broadcast (its pictures or its sound) is in the game: it is RTÉ's. Frames were taken every 20 s and in
2 s runs through passages of open play; the sound was searched for the sharp transients of strikes.

## The game

- **Scoring**: 0-8 v 0-13 at half-time, 21 points and no goals in about 37 minutes: points from everywhere, goals
  rare. The game's AI already plays to about 3 goals and 43 points over 70 minutes (tests/score_check.tscn).
- **Compact**: in the wide shots most of the 30 are in a band about 40 m across round the ball; the far wing is often
  empty. The game's lines now squeeze further across toward the ball (TeamAI.home_spot).
- **Swarming**: the man in possession is closed by two or three at once, well out from goal, and a ball on the
  ground becomes a ruck of four to six, hurleys low, bodies over it. The game now sends a second man in on the carrier
  within 65 m of goal (was 45) and three from each side for a loose ball (was two).
- **Puck-outs are contested**: the broadcast's own count at 15 minutes: Galway had won 2 of their 6, Limerick 5 of 6;
  short puck-outs are the safe ones. Turnovers at half-time: 18 and 16. (The game's keepers choose short or long by
  their side's tactics and the space in front: docs/AI.md.)
- **Restarts**: many sideline cuts: the ball placed on the line, the taker bent low over it, the hurley flat on the
  grass, the linesman beside him with his flag; frees struck from the hand after a lift.
- **Breaks**: many: injuries, frees, the referee speaking to a player; the ball is live about two-fifths of the time
  (the game's match clock is set to that: docs/AI.md).

## The ground

- **Stands**: two decks on the long sides with a level of glass-fronted boxes between them, a cantilevered roof with a
  white truss on its front edge, a terrace at one end (the Hill), the crowd filling everything.
- **The crowd**: in its counties' colours, maroon and white and green, in blocks: whole sections of one or the other,
  a few of the other side among them. The game's stadium and county ground now fill most seats with the two
  counties' colours, section by section (Crowd.build).
- **The edges**: lit advertising boards round the field and on the upper deck's front, magenta and purple; a
  terracotta strip between the grass and the boards.
- **The light**: a hot afternoon; the stands throw a shadow over part of the field, and every player has a long,
  hard shadow. The grass is mown in broad stripes with a diagonal cross-cut, the competition's name painted at
  midfield (not copied: it is the organisers' mark).

All of the ground's details went into the national stadium on Medium and High (Stadium._stadium, _boards,
_perimeter, _truss), and the shadows into every match on Medium and High (PlayerShadows).

## The sound

The commentary is over everything, but in close shots of sideline cuts and a free the strike stands out: a crack
gone in 1 to 3 ms (12 dB down), its energy under 500 Hz (a thump) and at 4 to 8 kHz (the crack), little between.
The game's strike was a tone ringing at 1.2 and 2.4 kHz for 25 ms; it is now made to that measure (Sfx._strike: -12
dB in 3 ms, the same split of energy). The recording itself is not used.
