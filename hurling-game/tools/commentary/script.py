"""The commentary's script: every line the two voices say, by the moment it is for. Writes
assets/commentary/lines.json (the game reads it) and tools/commentary/SCRIPT.md (to read and to record from).
  python3 tools/commentary/script.py
A = the commentator ("Mick"), calling the play; B = the co-commentator ("Ger"), a former hurler, reading it.
"after": "name" - said straight after the commentator says a man's surname ("Fahy..."); "county" - after a county.
"tone": how to say it (the ElevenLabs settings for it: tools/commentary/README.md)."""
import json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(os.path.dirname(HERE))

# kind -> list of (who, text, tone, after)
S = {}
def add(kind, who, tone, *texts, after=""):
    S.setdefault(kind, [])
    for t in texts:
        S[kind].append((who, t, tone, after))

# --- the start, the halves, the end -------------------------------------------------------------------------------
add("throw_in", "A", "lift",
    "And we're under way.",
    "The referee throws it in, and off we go.",
    "Seventy minutes of hurling, and it starts now.",
    "Up goes the sliotar, and battle is joined.")
add("throw_in", "B", "warm",
    "First few minutes, Mick, it's all about settling. Get a touch, get a score.",
    "Whoever wins the breaking ball early will grow into this.",
    "Plenty of nerves out there. A good first puck-out will calm them.")
add("second_half", "A", "lift",
    "And the second half is under way.",
    "Thirty-five minutes left. Here we go again.",
    "Back out they come, and the throw-in starts the second half.")
add("second_half", "B", "warm",
    "Whatever was said in that dressing room, Mick, we'll see it in the next ten minutes.",
    "The first score of this half will be huge.")
add("half_time", "A", "warm",
    "And there's the whistle for half time.",
    "Half time, and plenty for both managers to think about.",
    "The referee calls a halt. That's the first half done.")
add("half_time", "B", "warm",
    "Good half of hurling, Mick. Not much between them.",
    "They'll want more ball into the full-forward line in the second half.",
    "The puck-outs will decide this one. Whoever wins their own will kick on.")
add("full_time", "A", "big",
    "And there's the final whistle!",
    "It's all over! What a game of hurling.",
    "The referee blows it up. They'll be celebrating long into the night.")
add("full_time", "A", "big",
    "have won it! The final whistle goes, and they've done it!",
    "are the winners! What a performance from them today.",
    "hold on! It's all over, and the day is theirs.", after="county")
add("full_time", "B", "warm",
    "Deserved, Mick. They worked harder for every ball.",
    "That's a team that never stopped running. Great credit to them.",
    "Some hurling. The supporters got their money's worth today.")
add("full_time_draw", "A", "big",
    "And it ends level! Neither side could be separated.",
    "The final whistle, and honours even.")
add("full_time_draw", "B", "warm",
    "A draw is about right, Mick. Nothing between them all day.",
    "Neither side will be happy with that, and neither deserved to lose.")
add("extra_time", "A", "lift",
    "Level at the end of normal time. We're going to extra time.",
    "Extra time, and tired legs all over the field.")
add("extra_time", "B", "warm",
    "It's about who has the most left in the legs now, Mick.")
add("shootout", "A", "lift",
    "Still level. It comes down to penalties.",
    "A shoot-out to settle it. Nerves of steel needed now.")
add("shootout", "B", "warm",
    "Pick your spot and hit it hard. That's all you can do, Mick.")

# --- scores ------------------------------------------------------------------------------------------------------
add("goal", "A", "shout",
    "Goal! It's in the back of the net!",
    "Oh, it's a goal! What a finish!",
    "Goal! The net is bulging!",
    "He buries it! Goal!",
    "Into the corner! A goal!",
    "Green flag! What a goal!")
add("goal", "A", "shout",
    "goes for goal... and finds the net!",
    "the shot... and it's a goal!",
    "bangs it home! A goal!", after="name")
add("goal", "B", "warm",
    "Clinical, Mick. Head down, picked his spot, no keeper stops that.",
    "That's what happens when you give a forward a yard of space.",
    "The run off the shoulder did it. Nobody tracked him in.",
    "The keeper had no chance. Too close, too much power.")
add("point", "A", "call",
    "Over the bar.",
    "And that's a point.",
    "Split the posts.",
    "White flag. Lovely point.",
    "Up and over. Point.",
    "Clipped over the bar.")
add("point", "A", "call",
    "over the bar.",
    "and he splits the posts.",
    "points. Lovely.",
    "takes his point.",
    "nice and easy, over the bar.", after="name")
add("point", "B", "warm",
    "Lovely score, Mick. Took his time, never rushed it.",
    "That's the work rate that gets you scores.",
    "Good movement. Got the half yard and punished them.",
    "Easy for him in the end. Great ball in.")
add("point_long", "A", "lift",
    "From all of seventy metres! What a point!",
    "From way out the field! Over the bar!",
    "A massive strike! That's a huge point!")
add("point_long", "A", "lift",
    "from distance... and it's over! What a score!",
    "lets fly from way out... over the bar!", after="name")
add("point_long", "B", "warm",
    "Some striking, Mick. You don't see many from that range.",
    "He just backed himself. When you hit it that sweet, it carries.",
    "That's a point that lifts a whole team.")
add("point_free", "A", "call",
    "The free is over.",
    "Pointed. No mistake from the free.",
    "Dead centre. The free is converted.",
    "Over it goes. The free taker is on song.")
add("point_free", "A", "call",
    "makes no mistake with the free.",
    "over the bar from the placed ball.", after="name")
add("point_free", "B", "warm",
    "Routine, but you still have to strike it, Mick.",
    "Great technique. Up, toss, strike, every time the same.")
add("wide", "A", "flat",
    "And it's wide.",
    "Pulled wide. A chance gone.",
    "Drifting... and wide.",
    "The umpire waves it wide.",
    "Wide. He'll be disappointed with that one.")
add("wide", "B", "warm",
    "Snatched at it, Mick. He'd want that back.",
    "Bad option. There was a man free inside.",
    "Hit it under pressure. You'll miss those.")
add("save", "A", "shout",
    "Saved! What a stop!",
    "And the goalkeeper keeps it out!",
    "Brilliant save!",
    "Denied by the keeper!")
add("save", "A", "shout",
    "with a magnificent save!",
    "gets down to it! Saved!", after="name")
add("save", "B", "warm",
    "Stood up big, Mick. Made himself as wide as the goal.",
    "That's a match-winning save, that.",
    "Great reactions. He didn't commit until the last moment.")
add("post", "A", "shout",
    "Off the post!",
    "Rattles the woodwork!",
    "Off the upright! So close!")
add("post", "B", "warm",
    "Inches, Mick. That's the game of hurling.",
    "He'll see that one hitting the post in his sleep tonight.")

# --- the referee and the restarts ---------------------------------------------------------------------------------
add("free", "A", "flat",
    "The referee gives a free.",
    "Whistle. Free given.",
    "And it's a free.",
    "The referee spotted that one. Free.")
add("free", "B", "warm",
    "Soft enough free, Mick, but you can't pull across a man like that.",
    "Careless. You give away frees like that and they punish you.")
add("penalty", "A", "lift",
    "And the referee points to the spot! A penalty!",
    "It's a penalty! Huge moment!")
add("penalty", "B", "warm",
    "Pulled him down in the square, Mick. The referee had no choice.",
    "One against the keeper from twenty metres. Advantage to the striker.")
add("sixty_five", "A", "flat",
    "Out off the defender. A sixty-five.",
    "A sixty-five to come.",
    "Deflected out. It'll be a sixty-five.")
add("sixty_five", "B", "warm",
    "Good defending, Mick. A sixty-five is a lot better than a goal.")
add("puck_out", "A", "flat",
    "The puck-out.",
    "Here's the puck-out.",
    "And we restart with the puck-out.")
add("puck_out", "A", "flat",
    "with the puck-out.",
    "to restart.", after="name")
add("puck_out", "B", "warm",
    "Short or long, Mick? Go short and you risk the turnover. Go long and it is a fifty-fifty under the dropping ball.",
    "Win your own puck-outs and you'll win this game.")
add("sideline", "A", "flat",
    "Over the sideline.",
    "Sideline cut coming up.",
    "Out of play. Sideline ball.")
add("sideline", "B", "warm",
    "One of the hardest skills in the game, the sideline cut.")
add("yellow", "A", "flat",
    "And out comes the yellow card.",
    "The referee goes to the pocket. Yellow.")
add("yellow", "B", "warm",
    "He can have no complaints, Mick.",
    "He'll have to be careful now for the rest of the game.")
add("red", "A", "lift",
    "And it's a red card! He's off!",
    "Straight red! They're down to fourteen!")
add("red", "B", "warm",
    "That changes everything, Mick. A man down for the rest of it.",
    "Reckless. He's let his team down there.")

# --- the play -----------------------------------------------------------------------------------------------------
add("tackle", "A", "call",
    "Big shoulder.",
    "Strong in the tackle.",
    "Bounced off that challenge.")
add("tackle", "B", "warm",
    "Hard but fair, Mick. That's championship hurling.",
    "Shoulder to shoulder. Lovely and clean.")
add("hook", "A", "call",
    "Hooked!",
    "A great hook!",
    "Gets the hurley in. Hooked.")
add("hook", "B", "warm",
    "That's the bit of hurling nobody sees, Mick. Huge.",
    "Never gave up the chase. Brilliant hook.")
add("block", "A", "call",
    "Blocked!",
    "And it's blocked down!",
    "Charged down!")
add("block", "B", "warm",
    "Brave, Mick. Put the body on the line.",
    "Unbelievable courage to get in front of that.")
add("catch", "A", "call",
    "Great catch.",
    "Plucks it out of the sky.")
add("catch", "A", "call",
    "with a lovely catch.",
    "rises highest. Superb catch.",
    "plucks it from the clouds.", after="name")
add("catch", "B", "warm",
    "Some hands on him, Mick. Up among the hurleys.",
    "Great timing on the jump. Caught it at the highest point.")
add("attack", "A", "rise",
    "Here they come now.",
    "This is dangerous.",
    "Bearing down on goal.",
    "In on the edge of the square.")
add("attack", "A", "rise",
    "is through... ",
    "bearing down on goal...",
    "on the burst...", after="name")

# --- the score, after a score -------------------------------------------------------------------------------------
add("level", "A", "call",
    "And we're level again.",
    "All square once more.",
    "That's them level.")
add("lead_one", "A", "call",
    "Just the one between them now.",
    "A one-point game.")
add("lead_one", "A", "call",
    "lead by one.",
    "edge in front by a point.", after="county")
add("lead_big", "A", "call",
    "pulling clear now.",
    "in total control.", after="county")
add("lead_big", "A", "call",
    "The gap is growing.")
add("comeback", "A", "lift",
    "are right back in this!",
    "won't lie down!", after="county")
add("comeback", "A", "lift",
    "What a comeback this is!")
add("late", "A", "lift",
    "Nerves now. Every score is gold.",
    "Into the closing minutes, and it's still anybody's.",
    "Hearts in mouths all around the ground.")
add("late", "B", "warm",
    "Whoever holds their nerve now, Mick, wins it.")

# --- the replays (the co-commentator over them) ------------------------------------------------------------------
add("replay_goal", "B", "warm",
    "Watch the run here, Mick. He's gone before the ball is even struck.",
    "Look at the space he's in. Nobody picked him up.",
    "See the hand pass across the square. Unselfish, and it opened them up.",
    "Look at the finish. Low, hard, into the corner. Unstoppable.")
add("replay_point", "B", "warm",
    "Look at the turn there. Bought himself the yard and that's all he needed.",
    "Watch the head. Up, sees the posts, and strikes in one movement.",
    "Off the left side too. That's a hurler with two sides.",
    "Watch the touch first. Controls it, and then the strike is easy.")
add("replay_wide", "B", "warm",
    "Look here, Mick. Off balance, and the ball goes where the body goes.",
    "He had time there. He didn't need to snatch at it.",
    "The angle was against him. A pass was on.")

# --- between the plays ---------------------------------------------------------------------------------------------
add("lull", "A", "warm",
    "A big crowd here today, and they're getting their money's worth.",
    "The breeze is playing a part here this afternoon.",
    "Plenty of hurling still to be played.",
    "Both sides trying to find a way through here.",
    "Patient enough build-up. Looking for the opening.",
    "Ger, what are you making of it so far?")
add("lull", "B", "warm",
    "They're very good at turning the ball over, Mick. Pressure all over the field.",
    "The half-back lines are winning a lot of ball today.",
    "You need runners off the shoulder. Somebody has to break the line.",
    "Short puck-outs are working for them. Why go long?",
    "The work rate is savage. Every ball contested.",
    "It's fierce physical out there. The bench will be needed later.",
    "If you win the breaking ball, you win the game. Simple as that.",
    "A great day for hurling, Mick. You'd travel a long way for this.")

# --- the names (the commentator only) -------------------------------------------------------------------------
LAST = ['Ryan', "O'Brien", 'Walsh', 'Murphy', 'Kelly', "O'Sullivan", 'Byrne', 'Dwyer', 'Hayes', 'Quinlan', 'Moloney',
    'Fitzgerald', 'Brennan', 'Doyle', 'Kennedy', 'Gleeson', 'Lynch', 'Nolan', 'Shanahan', 'Kearney', 'Maguire',
    'Duggan', 'Costello', 'Fahy', 'Hogan', 'Carroll', 'Daly', 'Egan', 'Flanagan', 'Grace', 'Hennessy', 'Lenihan',
    'McGrath', 'Meagher', 'Nagle', 'Phelan', 'Ruane', 'Treacy', 'Cleary', 'Delaney']
COUNTIES = {"TIP": "Tipperary", "LIM": "Limerick", "COR": "Cork", "KIL": "Kilkenny", "CLA": "Clare", "GAL": "Galway",
    "DUB": "Dublin", "WAT": "Waterford", "WEX": "Wexford", "OFF": "Offaly", "ANT": "Antrim", "LAO": "Laois",
    "CAR": "Carlow", "WME": "Westmeath", "KER": "Kerry", "DOW": "Down", "MEA": "Meath", "KIE": "Kildare",
    "DER": "Derry", "LON": "London"}


def slug(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")[:28]


def main():
    lines = []
    for kind, items in S.items():
        n = {}
        for who, text, tone, after in items:
            n[who] = n.get(who, 0) + 1
            lines.append({"id": "%s_%s%s%d" % (kind, who.lower(), "_" + after[0] if after else "", n[who]),
                "who": who, "on": kind, "text": text, "tone": tone, "after": after})
    for i, n in enumerate(LAST):
        lines.append({"id": "name_%d" % i, "who": "A", "on": "name", "text": n + "...", "tone": "call", "after": ""})
    for k, n in COUNTIES.items():
        lines.append({"id": "county_" + k, "who": "A", "on": "county", "text": n + "...", "tone": "call", "after": ""})
    # (ids unique)
    ids = [l["id"] for l in lines]
    assert len(ids) == len(set(ids)), "duplicate ids"
    with open(os.path.join(GAME, "assets/commentary/lines.json"), "w") as f:
        json.dump({"lines": lines}, f, indent=1, ensure_ascii=False)
    chars = {"A": 0, "B": 0}
    for l in lines:
        chars[l["who"]] += len(l["text"])
    with open(os.path.join(HERE, "SCRIPT.md"), "w") as f:
        f.write("# Commentary script\n\nGenerated by tools/commentary/script.py - edit that, not this.\n\n")
        f.write("%d lines; %d characters (Mick %d, Ger %d).\n\n" % (len(lines), chars["A"] + chars["B"], chars["A"], chars["B"]))
        cur = ""
        for l in lines:
            if l["on"] != cur:
                cur = l["on"]
                f.write("\n## %s\n\n| id | who | tone | text |\n|---|---|---|---|\n" % cur)
            f.write("| %s | %s | %s | %s%s |\n" % (l["id"], "Mick" if l["who"] == "A" else "Ger", l["tone"],
                "(after a name) " if l["after"] == "name" else ("(after a county) " if l["after"] == "county" else ""), l["text"]))
    print("%d lines, %d characters (Mick %d, Ger %d)" % (len(lines), chars["A"] + chars["B"], chars["A"], chars["B"]))


if __name__ == "__main__":
    main()
