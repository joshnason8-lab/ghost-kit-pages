# The rules

Pok Ta Pok Rivals plays two games:

- **Ulama de cadera (hip ulama).** This is the main mode. It is the living game, still played in the villages of
  southern Sinaloa, Mexico.
- **The classic court.** This mode is clearly labelled *reconstructed*. It is the old stone-court game as scholars
  rebuild it from the 16th-century chroniclers.

No single international rulebook exists. Ulama's rules are oral, and villages play them differently. Aguilar-Moreno
notes that Escuinapa and Los Llanitos apply them differently. Every rule below names its source. Each one says
whether it is **documented** (a source says so), **reconstructed** (pieced together where the sources are silent or
disagree), or **the game's own** (a choice made so the game works on a phone).

The rules live in a pure module, `game/rules.gd`, and the court's shapes live in `game/court.gd`. `tests/test_runner.gd`
checks every numbered rule headless. The match (`game/match.gd`) only reports what happened; the module decides who
wins each raya.

**About the sources.** The research was done in October 2026 with web search. The sandbox could not open most pages
in full, so the claims below rest on the search engines' summaries of the pages listed. Before relying on an exact
figure, open the page.

Main sources:

- **[AM-AI]** Manuel Aguilar-Moreno, "Ulama: Pre-Columbian ballgame survives today", *American Indian* (Smithsonian NMAI).
  <https://www.americanindianmagazine.org/story/ulama-pre-columbian-ballgame-survives-today>
- **[AM-AA]** Aguilar-Moreno, *Anales de Antropología* (2015). <https://www.sciencedirect.com/science/article/pii/S0185122515716450>
- **[CONADE]** Comisión Nacional de Cultura Física y Deporte, Juegos Autóctonos 2021: Ulama.
  <https://autoctonos2021.conade.gob.mx/ulama.html>
- **[SIC]** Secretaría de Cultura, Sistema de Información Cultural, intangible heritage inventory: Ulama.
  <https://sic.cultura.gob.mx/ficha.php?table=frpintangible&table_id=424>
- **[CP]** Cuarto Poder, "El juego del ulama sobrevive". <https://www.cuartopoder.mx/nacional/el-juego-del-ulama-sobrevive/167723>
- **[NORO]** Noro, "Ulama, deporte prehispánico de Sinaloa". <https://noro.mx/cultura/ulama-deporte-prehispanico-sinaloa/>
- **[NPR]** NPR, "An ancient ballgame makes a comeback in Mexico" (2018).
  <https://www.npr.org/2018/09/16/646756260/an-ancient-ballgame-makes-a-comeback-in-mexico>
- **[UNAM]** UNAM thesis on ulama (2008). <https://tesiunamdocumentos.dgb.unam.mx/ptd2008/junio/0628996/0628996.pdf>
- **[WP-U]** Wikipedia, "Ulama". <https://en.wikipedia.org/wiki/Ulama_(game)>
- **[WP-B]** Wikipedia, "Mesoamerican rubber balls". <https://en.wikipedia.org/wiki/Mesoamerican_rubber_balls>
- **[AM]** *Arqueología Mexicana*, "Ulama, el juego de pelota prehispánico que sobrevivió hasta nuestros días".
  <https://arqueologiamexicana.mx/mexico-antiguo/ulama-el-juego-de-pelota-prehispanico-que-sobrevivio-hasta-nuestros-dias>
- **[PENN]** Penn Museum, *Expedition*, "The rubber ball game". <https://www.penn.museum/sites/expedition/the-rubber-ball-game/>
- **[MET]** The Met, "The Mesoamerican Ballgame". <https://www.metmuseum.org/essays/the-mesoamerican-ballgame>
- **[TERM]** Termómetro en línea, 2022 national ulama meet (4 or 5 a side, 30 minutes).
  <https://www.termometroenlinea.com.mx/vernoticiashistorial.php?artid=99557>

## Ulama de cadera

### The court (R7)

| | |
|---|---|
| **Documented** | The court is the **taste**: a long, narrow strip of earth. The **analco**, a line across its middle, splits it into two halves; the word appears in colonial chronicles [AM-AI]. Each end has an end line, called the **chichi** [AM-AI] or **chivo** [NORO]. Sizes disagree: 50 × 4 m [CONADE] [SIC] [CP], 50 × 3 m [UNAM], about 60 × 4 m [AM-AA], about 69 × 4 m [AM-AI]. |
| **In the game** | 60 m × 4 m, the analco across the middle, a chivo at each end, packed earth and no walls (`Court.ULAMA_HALF_L = 30`, `ULAMA_HALF_W = 2`). |
| **Why** | Aguilar-Moreno, who played and filmed the game, gives about 60 × 4 m. It also sits in the middle of the reported range. |

### The players (R7) and their places

| | |
|---|---|
| **Documented** | Five a side [SIC] [CP]. CONADE and CP add one more at the head of the taste, the *golpeador*. Four or five by agreement at a 2022 national meet [TERM]. Players are called *taures* or *tahúres*. The places: the **male** serves; the **malero** defends the front of the taste by the analco; the **chivero** covers the back by the chivo; the **topador** returns the other side's serve [NORO] [SIC]. |
| **In the game** | 4 or 5 a side (5 by default), set in match setup. The players stand down their half, the malero at the front and the chivero at the back, with the topador and the others between (`TeamAI.role_of`). The server is the malero (the male's job). |
| **Simplified** | The golpeador is not used: the sources do not say what he does beyond the five. |

### The ball

| | |
|---|---|
| **Documented** | Solid natural rubber, 3–4 kg [CONADE] [WP-B], 3.5–4 kg [AM], about 3.7 kg [UNAM], about 4 kg [SIC] [CP]. Under 20 cm across [WP-B]. No source gives measured bounce or speed figures. |
| **In the game** | 3.6 kg and 19 cm (`Ball.MASS`, `Ball.RADIUS`). Air drag comes from its size and mass (a heavy ball barely slows in the air). Bounce on earth: 0.42 of the speed into the ground comes back, so a ball dropped from the hip rises about 15 cm. On stone: 0.58, about 30 cm. Rolling, the earth slows it by 1.5 m/s each second; stone by 0.7. A strike sends it at 8.5–16 m/s, depending on the player's power and how cleanly the hip meets it. |
| **Why** | The bounce and rolling figures are the game's own, because no source measures them. They were chosen so the ball *feels* as heavy as the sources describe: it thuds down, rolls a short way and dies. |

### R1. Winning

| | |
|---|---|
| **Documented** | The first side to **eight rayas** wins. All sources agree [AM-AI] [CONADE] [NPR]. |
| **In the game** | `Rules.TARGET = 8`. |

### R2–R4. The count

| | |
|---|---|
| **Documented** | Points are **rayas**, named after the tally marks the count is kept in [AM-AI]. The count "is not linear, but oscillatory… the points of the teams go up and down" [AM-AA]. Only one side holds rayas at a time: NPR's example is "if team A is winning 1-0 and team B scores, team A loses its point" [NPR]. If the sides draw level, both are at zero [WP-U]. **Urria**: in certain places in the count, a side holding rayas is in danger. A raya against it there wipes out its whole count. The sources place urria differently: rayas 2–3 and 6–7 [AM-AA], rayas 2, 4 and 6 [UNAM], rayas 3, 5 and 7 [CONADE]. CONADE says urria is what makes matches long. |
| **In the game** | R2: one side holds the count. A raya to the holder adds one. R3: a raya to the other side takes one off the holder's count. From level, the next raya starts that side's count. R4: urria on rayas **3 and 7** by default (where Aguilar-Moreno and CONADE agree), or **3, 5 and 7** (CONADE), or off, chosen in match setup. Standing on an urria raya, the holder loses its whole count to the next raya against it (`Rules.award`). |
| **Reconstructed** | NPR's one-line example could also be read as the raya passing straight to the other side (1–0 to 0–1). The game follows Wikipedia's reading instead: a raya against the holder takes one off, and a level count is zero–zero. Both readings agree that the count swings and that eight wins. The UNAM thesis describes a different urria (the other side "cannot remove" a count until it reaches raya 2). The game does not model that; it is noted for a knowledgeable reviewer in docs/CULTURE.md. |

### R5–R6. Striking the ball, and faults

| | |
|---|---|
| **Documented** | The ball is struck with the **hip** only; some sources say the hip and the top of the thigh [AM-AI]. It may be passed among a side and volleyed with the hips [AM-AI]. A raya goes to the other side for touching the ball with any other part of the body (hands and feet included), hitting out of turn, missing it, knocking it out of bounds, touching a teammate, or letting it stop before it reaches the analco [WP-U]. The ball may bounce and roll [AM-AI]. |
| **In the game** | R5: the hip strike, and the **dive** (a hip strike made low with the player down on the ground, as ulama players do for a low ball). A ball whose centre is below 34 cm (rolling, or skimming the earth) goes under a standing hip: only the dive reaches it, as on a real taste. Teammates may play it one after another in their own half. R6: if the ball touches a player anywhere but his hip, the raya goes to the other side. That happens when a strike misses the ball and it runs into him, or when he stands in its way. The AI steps out of its way (`TeamAI._place`). |
| **Simplified** | *Hitting out of turn* is not modelled: the sources do not say what the turn is. Neither is *touching a teammate*: the players never collide. A "missed" ball is covered by R6 (it touches the body) and R8 (it dies in your half). Each side stays on its own side of the analco, which the sources imply but do not state. |

### R8. The ball dies in a half

| | |
|---|---|
| **Documented** | A raya is won "when one team fails to return the ball past the analco" [AM-AI], or when the ball stops before reaching the analco [WP-U]. |
| **In the game** | When the ball has stopped (rolling slower than 0.35 m/s), the side whose half it is in loses the raya (`Rules.dead_ball`). A strike that dies short of the analco in the striker's own half loses it the same way. |

### R9. Past the end line

| | |
|---|---|
| **Documented** | A raya is won "when the ball is driven past the opponent's end line" [AM-AI]. |
| **In the game** | The ball's centre passing beyond a chivo, at any height: the side whose end it is loses the raya (`Rules.over_end`). |

### R10. Out at the side

| | |
|---|---|
| **Documented** | Knocking the ball out of bounds is a fault [WP-U]. |
| **In the game** | The ball touching the ground beyond a side line: the raya goes against the side that last struck it (`Rules.out_side`). In the air beyond the line it is still in play until it comes down. |

### R11. The serve (the male)

| | |
|---|---|
| **Documented** | The **male** puts the ball in play across the analco: **male arriba**, a high throw, or **male abajo**, rolled along the ground. The kind changes with the score [AM-AI] [AM-AA]. Play starts with the low serve [CONADE]. |
| **In the game** | The server (the malero) bowls or throws the ball by hand from 5 m behind the analco. *Abajo* when the count is level (including the first serve); *arriba* when a side holds the count. A serve that dies short of the analco loses the raya (R8). |
| **Reconstructed** | No source says which score calls for which serve, or who serves after a raya. The game rolls the ball from level and throws it once a side holds the count. The side that won the last raya serves. |
| **Stone court (0.5.0)** | Pelota maya as played in Yucatán today (two videos the owner sent: a street game in Mérida and a court game in a Yucatán park) serves differently: the ball is thrown down so it bounces short of the other side and comes up to them, who play it off the bounce. On the smooth court it bounces lively, to knee and hip height. So on the stone court the serve is *de bote*: thrown up and over to come down 0.8–2.6 m past the analco, and the receivers let it bounce and take it as it rises (`Rules.serve_kind`, `Match._launch_serve`, `TeamAI`); the stone floor's bounce went from 0.58 to 0.68 and the talud's and walls' with it. Ulama's earth courts keep the documented rolled and thrown serves and the earth's dead bounce. |

### R14. Time (the game's own)

| | |
|---|---|
| **Documented** | Real games run until a side reaches eight. Resets "can make for lengthy games" [WP-U]. A 2022 national meet set a **30-minute** limit [TERM]. |
| **In the game** | Match setup sets a limit of 6, 10 or 15 minutes of play (calls not counted), or none. When the limit is reached, the side holding the count wins. If the count is level, **the next raya wins**. |
| **Why** | A phone game needs an end in sight. The 2022 meet shows real organisers do the same. |

### The judges (veedores)

| | |
|---|---|
| **Documented** | One or two **veedores** stand at the analco and see that the rules are kept [CP] [SIC]. The UNAM thesis says one for each side. No source describes their signals. |
| **In the game** | Two judges, one each side of the analco, in everyday clothes. For each raya, each points an arm to the half of the side that wins it. For a fault, they first cross their arms over their heads. The words of the call appear at the top of the screen. |
| **Game's own** | The gestures are the game's own. They are marked in docs/CULTURE.md for someone who has watched ulama to check. |

## The classic court (reconstructed)

The game labels this mode **"Classic court (reconstructed)"** wherever it can be chosen. The old game's rules are
not known in detail. What follows rests on the 16th-century Spanish chroniclers who saw the Aztec game, through the
Penn Museum's summary [PENN], and on the courts themselves [MET].

### R12. The court

| | |
|---|---|
| **Documented** | An alley between two parallel structures with sloped (talud) benches and walls. Enclosed end zones, which give the "I" shape, became common by the Terminal Classic [MET]. Sizes vary widely: Tula about 41 × 10 m. Chichén Itzá's Great Ball Court has an alley of 96.5 × 30 m [MET], walls about 8 m high and rings about 6 m up. |
| **In the game** | The size of the smaller Yucatán courts: a 36 m alley, 9 m wide. Each side has a talud 1.5 m deep rising 1.6 m, then a wall to 5 m. At each end is an end court 6 m deep and 18 m wide, walled to 3 m. One stone ring sits in each wall at the centre line, 4 m up, its hole along the alley, 38 cm across (the ball is 19 cm). 2–4 players a side, 3 by default. Points to eight. |
| **Reconstructed** | The sizes, the ring's height and hole, the team sizes and the target of eight are the game's own. The target follows ulama's count of eight, because the chroniclers give none. The classic Maya courts (Tikal, Copán) had floor markers instead of rings [PENN]. Rings came in the Terminal Classic and Postclassic, as at Chichén Itzá [PENN]. The game's court follows the later, ringed kind. |

### R13. The ring

| | |
|---|---|
| **Documented** | Passing the ball through a ring won the game outright, whatever the score. The chroniclers Durán and Motolinía describe it as extremely rare [PENN]. |
| **In the game** | The ball's centre passing through a ring's hole wins the match at once (`Rules.award_ring`). The hole is barely twice the ball's width and stands 4 m up a wall. It is meant to be rare and spectacular, but a skill, not luck: a strike from 4 to 12 m out, near the wall, with the stick held toward it, is aimed at the ring so that the ball meets it at the top of its arc (the hole is a short tube along the alley; a ball still climbing or already dropping catches the stone). The strike's timing sets the error: a perfect one goes in about one time in three, a good one about one in ten, an ordinary one hardly ever. The computer tries it now and then, more often at a harder level. A ball through the ring is replayed, slowed, from below it. |

### R15–R16. Points

| | |
|---|---|
| **Documented** | Per Durán, points came from (1) a strike with a body part other than the hip or upper leg; (2) the ball landing in or flying over an end zone; (3) the ball "dying" in the alley without being returned across the centre line [PENN]. |
| **In the game** | (1) R6 as in ulama. (2) R16: the ball landing in an end court, or going over its wall: the point goes to the side driving it that way (`Rules.end_court`). (3) R8 as in ulama. R15: the ball going out over the top of a side wall is a fault against the side that last struck it. The ball plays off the taluds and walls. |
| **Reconstructed** | R15 is the game's own: the chroniclers do not say. |

## Not in the initial build

- **The pok-ta-pok / pelota maya revival** played in Yucatán, Quintana Roo, Belize and Guatemala, and at the world
  cup held since 2015. Tournaments set their own rules:
  - **Teams:** 4 a side in Guatemala and at the 2021 Copa del Sureste; 5 in Belize.
  - **Time:** halves of 13 minutes at the 2025 world cup in Copán; 2 × 15 at the Copa del Sureste.
  - **Contact:** hip and buttocks only. One strike per side before the ball crosses (AFP).
  - **Points:** the ball over the opponents' end line scores 4 (Guatemala) or 5 (Copa del Sureste). Fouls
    (non-hip touch −1, kick −2, sitting on the ball −3) go to the opponents.
  - **Ring:** a double ring about 3–4 m up wins the match outright (Guatemala) or scores 5 or 10 points.

  It is first in docs/PROGRESS.md's next steps, as a third rule set on the festival court.
  Sources: [AFP/France 24](https://www.france24.com/es/minuto-a-minuto/20210622-la-pelota-maya-una-tradici%C3%B3n-que-rebota-de-cadera-en-cadera-en-guatemala),
  [Mestizo QRoo](https://mestizoqroocom.wordpress.com/2021/10/12/todo-lo-que-debes-saber-para-disfrutar-la-1er-copa-del-sureste-mexicano-de-pok-ta-pok/),
  [Smithsonian](https://www.smithsonianmag.com/travel/in-belize-maya-descendants-are-reviving-an-ancient-sacred-ballgame-180987058/),
  [Honduras Trascendental](https://www.hondurastrascendental.com/post/mundial-juego-pelota-maya-honduras),
  [JSFD](https://jsfd.org/2023/09/13/chaaj-pok-ta-pok-and-chajchaay-rubber-ballgames-from-middle-america-to-the-world/).
- **Ulama de brazo** (the forearm game of northern Sinaloa) and **ulama de mazo** (with a mallet).
