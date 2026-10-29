#!/usr/bin/env python3
"""Builds data/dialogue/chapter2.json: every Chapter 2 beat (Story Bible §6 Ch2) in the script format
of chapter1.json (README: Dialogue and cutscenes). Run from the repository root:

    python3 tools/build/write_chapter2_dialogue.py

The scenes (scenes/u1/*) wire these ids to markers and interactables; the boss JSONs name the phase
scripts. Voices follow Story Bible §10.1.
"""
import json
from pathlib import Path

S = {}


def say(who, text, portrait=None, style=None):
    d = {"say": text, "who": who}
    if portrait:
        d["portrait"] = portrait
    if style:
        d["style"] = style
    return d


def nar(text):
    return {"say": text, "who": "narrator"}


def cap(text):
    return {"caption": text}


def crono_wheel(prompt, nod, look_away, name):
    """Crono's three-gesture dialogue wheel (§10.1): each option is a label to jump to."""
    return {"who": "crono", "prompt": prompt, "choice": [
        {"text": "[Nod]", "goto": nod},
        {"text": "[Look Away]", "goto": look_away},
        {"text": "[Say Sera's Name]", "goto": name},
    ]}


# ---------------------------------------------------------------- 2.1 Bamboo Grove
S["ch2_grove_wake"] = [
    {"universe": 1},
    {"checkpoint": "ch2_grove"},
    {"music": "mus_u1_morning"},
    cap("Kuro-Truce Bamboo Grove. Rice paper for sky. Every stalk a single brush stroke, and the wind moves them on twos."),
    {"fade": "in", "wait": 1.0},
    nar("Crono comes to with his cheek on paper. The ink has not dried under him: a man-shaped smear where he fell through the seam."),
    {"camera": "truth", "focus": "crono"},
    nar("His scarf still bleeds watercolour. Here, where everything is three inks, he is the only thing with colour in it."),
    {"wait": 0.8},
    {"camera": "explore"},
    say("sera", "Papa. Papa, I can't— I'm not there, I'm— just get up. Please get up.", "hurt"),
    nar("Her voice comes from nowhere and everywhere, thinned to a whisper, doubled."),
    {"anim": "crono", "name": "revive"},
    {"wait": 0.6},
    {"sfx": "sfx_time_ink_footstep"},
    nar("Footprints on the paper. Bare feet, wet with black. They stop six stalks away."),
    {"show": "krona", "at": "krona_duel_start"},
    {"face": "krona", "to": "crono"},
    say("krona", "Red hair. Scarf. Sword on the wrong hip.", "neutral"),
    say("krona", "Someone painted a boy from a story and dropped him in my grove.", "neutral"),
    {"face": "crono", "to": "krona"},
    say("krona", "I know that face. Look at it every morning in the gourd.", "neutral"),
    {"anim": "krona", "name": "ready"},
    say("krona", "Draw. If you're him, you'll know why.", "angry"),
    {"end": True},
]

S["ch2_duel_sequence"] = [
    {"run": "ch2_grove_wake"},
    {"battle": "", "boss_id": "krona_duel", "boss": True, "at": "krona_duel_start", "center": "grove_center",
     "music": "mus_boss_krona_duel", "on_win": "won", "on_lose": "lost"},
    {"label": "lost"},
    {"debt": 5},
    nar("The ink takes him. Somewhere a girl rewinds a blow she did not see, and the paper is blank again."),
    {"goto": "won"},
    {"label": "won"},
    {"run": "ch2_duel_end"},
    {"end": True},
]

# Phase scripts: the boss JSON (krona_duel) names these; they run with the clock stopped.
S["ch2_duel_mid"] = [
    say("krona", "You fight like the story. All light. Burning my ground gold so you can stand on it.", "angry"),
    say("krona", "I didn't get to be the story.", "neutral"),
    say("krona", "Lavos fell on my island. I went down the vein and ate the star. Everyone I love got up afterwards. Wrong.", "sad"),
    {"camera": "truth", "focus": "crono"},
    nar("The Defiled Masamune has opened his wrist. Under the paint the porcelain is lit from inside, and she sees it."),
    say("krona", "...Hollow.", "surprised"),
    {"camera": "explore"},
    {"choice": [
        {"text": "Overcharge the gauntlet.", "goto": "overcharge"},
        {"text": "Hold.", "goto": "hold"},
    ], "who": "crono", "prompt": "The Epoch gauntlet hums against the open seam."},
    {"label": "overcharge"},
    {"call": "duel_overcharge"},
    {"integrity": -2},
    nar("He feeds the crack to the gauntlet. It costs him. It always costs him."),
    {"end": True},
    {"label": "hold"},
    nar("He covers the wrist with his other hand and keeps his feet."),
    {"end": True},
]

S["ch2_duel_end"] = [
    {"music": "stop"},
    nar("The killing stroke comes down. Then it comes up again, the same stroke, backwards, ink climbing back onto the blade."),
    {"sfx": "sfx_time_rewind"},
    {"show": "sera_ghost", "at": "sera_ghost_mark"},
    say("sera", "No. Not him. Not again.", "angry"),
    nar("A girl in a teal jacket, fourteen percent of a girl, phased halfway through a bamboo stalk. Her daggers are clock hands."),
    say("krona", "...A ghost. Walking through ink.", "surprised"),
    {"wait": 0.5},
    nar("Krona lowers the nodachi. Not surrender. Interest."),
    say("krona", "Yours?", "neutral"),
    crono_wheel("Krona waits.", "nod", "away", "name"),
    {"label": "nod"},
    nar("He nods. The smallest possible nod."),
    {"goto": "after"},
    {"label": "away"},
    nar("He looks at the paper sky instead. Krona reads that too."),
    {"goto": "after"},
    {"label": "name"},
    say("crono", "Sera.", "neutral"),
    {"goto": "after"},
    {"label": "after"},
    {"hide": "sera_ghost"},
    say("sera", "Papa, they're taking me somewhere with no doors. I'll find you. I always—", "hurt"),
    nar("Gone. The grove is three inks again, and a red scarf."),
    say("krona", "Then you're not the story. You're a father. Worse.", "neutral"),
    say("krona", "Town's that way. Don't drink anything.", "neutral"),
    {"hide": "krona"},
    {"checkpoint": "ch2_grove_done"},
    {"save": 0},
    {"end": True},
]

# ---------------------------------------------------------------- 2.2 Pagoda fracture
S["ch2_pagoda_fracture"] = [
    cap("The Chitin-Pagoda. Nine tiers of red Lavos shell, lacquered, leaning over Kuro-Truce like it is listening."),
    {"camera": "truth", "focus": "pagoda_top"},
    {"sfx": "sfx_time_fracture_tear"},
    nar("The paper sky splits. Something falls through it that was never drawn with a brush: a gear the size of a house, thumbprinted clay, turning at twelve frames a second in a world that moves at twenty-four."),
    {"shake": 1.2},
    {"sfx": "sfx_impact_clay_crash"},
    nar("It takes the top three tiers with it. The pagoda holds. The gear keeps turning inside it, hitching, the wrong speed for this world."),
    {"wait": 1.0},
    say("sera", "That's not from here either, Papa. That's from the next one.", "surprised"),
    say("sera", "They're leaking into each other.", "hurt"),
    {"camera": "explore"},
    {"set": {"flag": "Pagoda_Fractured", "state": "set"}},
    {"end": True},
]

# ---------------------------------------------------------------- 2.3 Kuro-Truce streets
S["ch2_streets_arrival"] = [
    {"checkpoint": "ch2_streets"},
    {"music": "mus_u1_morning"},
    cap("Kuro-Truce. The Ashen Morning. Every gate is being painted bone white, and the painters hum."),
    nar("Townsfolk with paper masks and wet brushes. Fresh paper over every door. Under the paper, if you look, something darker that the paper is for."),
    say("sera", "Smells like wet ash under paint.", "neutral"),
    nar("She flickers at his elbow, there and not, a ghost at fourteen percent. Only he hears her. He answers by not looking at the doors."),
    say("sera", "It's Truce. It's our Truce with the colour taken out. There's the fountain. There's... that's the Leene Bell, Papa. They melted it.", "sad"),
    {"end": True},
]

S["ch2_doorway_peel"] = [
    {"choice": [
        {"text": "Peel the paper.", "goto": "peel"},
        {"text": "Leave it.", "goto": "leave"},
    ], "who": "crono", "prompt": "A doorway. Fresh paper over char. The paste is still wet."},
    {"label": "peel"},
    {"sfx": "sfx_ui_paper_tear"},
    nar("Under the paper: char. In the char, small handprints in soot, a row of them at a child's height, and a date scratched beside them. Three sieges ago."),
    say("sera", "...They put the paper on so they wouldn't have to look. Papa, they do it every morning.", "sad"),
    {"counter": "doors_peeled", "add": 1},
    {"end": True},
    {"label": "leave"},
    nar("He leaves it. Somewhere behind him a painter starts the next door."),
    {"end": True},
]

S["ch2_leene_bell"] = [
    nar("The Leene Bell, melted and recast as a blade, hangs over the square on a frayed rope. A guillotine with a name on it."),
    say("sera", "It used to ring for the Fair. Mom said you could hear it from the castle.", "sad"),
    nar("Crono puts a hand on the frame. The metal is still faintly warm, the way bells are after they ring."),
    say("crono", "Was always warm.", "neutral"),
    {"end": True},
]

S["ch2_ash_forge"] = [
    cap("The Ash Forge. In the home Truce, this is Lucca's house."),
    nar("The same floor plan. The same window. Where her workbench stood there is an anvil, and the anvil is cold."),
    nar("A sign in brushed kanji that Sera reads for him: ASH FORGE. REPAIRS. NO QUESTIONS."),
    say("sera", "She'd hate that sign.", "neutral"),
    {"end": True},
]

S["ch2_dojo_krona_joins"] = [
    {"checkpoint": "ch2_dojo"},
    cap("A burned dojo. The roof is gone; the sky is paper. Krona sits on the one unburned mat, scraping rust off a katana with oil from her gourd."),
    nar("Behind her, five retainers kneel in a row. Old friends, by the way they sit. Their rot is lacquered behind paper masks, and the lacquer is cracking."),
    {"move": "crono", "to": "dojo_threshold", "speed": 2.5},
    say("krona", "Ashtears always blow themselves up. Love language.", "neutral"),
    nar("She does not look up. She sips from the gourd. Every retainer flinches at once, like a single body."),
    say("sera", "You did what Dad does.", "neutral"),
    say("krona", "I did the right Crono thing and everyone died.", "neutral"),
    say("krona", "So I did the wrong thing. Drank the vein under the castle. They got back up. Corroded.", "sad"),
    say("krona", "So I'll keep doing wrong thing.", "neutral"),
    {"wait": 0.6},
    nar("Crono stands in the doorway and says nothing. He is good at it. He has had twenty-four years."),
    say("krona", "You're doing it now. The quiet. The 'nothing to say so nothing is wrong.'", "angry"),
    say("krona", "I invented that. Doesn't work. Sit."),
    crono_wheel("The unburned mat has room for two.", "nod", "away", "name"),
    {"label": "nod"},
    nar("He sits. The retainers watch his wrist."),
    {"goto": "join"},
    {"label": "away"},
    nar("He looks at the retainers instead. One of them looks back, and the mask slips a little, and he looks away again."),
    say("krona", "Yeah. That's why the masks.", "neutral"),
    {"goto": "join"},
    {"label": "name"},
    say("crono", "Sera. They have Sera.", "neutral"),
    say("krona", "The ghost. I know. Saw her stop my blade.", "neutral"),
    {"goto": "join"},
    {"label": "join"},
    say("krona", "Vein's under Goyama. Whoever took your ghost went down it. Castle's four bridges out.", "neutral"),
    say("krona", "I'm not helping you. I'm going anyway. Walk next to me if you want.", "neutral"),
    nar("She stands. The one surprised laugh she will allow herself this chapter is for his sword, which is on the wrong hip after all."),
    say("krona", "Ha. Wrong hip.", "smile"),
    {"recruit": "krona"},
    {"set_flag": "Krona_Joined:set"},
    {"learn": "eclipse_x_strike", "who": "crono"},
    nar("ECLIPSE X-STRIKE. When they strike together the screen splits: his half watercolour, hers ink."),
    {"save": 0},
    {"end": True},
]

# ---------------------------------------------------------------- 2.4 Iron Bridges
BRIDGE_CAPS = [
    "The first Iron Bridge. A shrine gate of black iron, ash-ronin kneeling at its foot like they have been waiting a hundred years.",
    "The second Iron Bridge. The river under it runs grey. Something in it is still warm.",
    "The third Iron Bridge. Crows made of VHS feathers watch from the torii, and the picture of them rolls.",
    "The fourth Iron Bridge. Goyama burns at the far end, three floors of fire that never fall.",
]
BRIDGE_KRONA = [
    "They won't let you cross without the parry. Ens. Circle on the ink. Catch the stroke at the edge, not the middle.",
    "Second gate. Same lesson. They only teach one thing.",
    "Crows. Don't look at the picture, look at the bird.",
    "Last gate. After this it's the castle, and the castle doesn't kneel.",
]
for i in range(4):
    n = i + 1
    script = [
        {"checkpoint": f"ch2_bridge_{n}"},
        cap(BRIDGE_CAPS[i]),
        say("krona", BRIDGE_KRONA[i], "neutral"),
    ]
    if n == 1:
        script += [
            nar("ENS PARRY. When an enemy's stroke lands, press parry inside the window. A perfect parry negates the hit and leaves a sumi ring on the ally."),
        ]
    script += [
        {"battle": f"iron_bridge_shrine_{n}", "at": f"bridge_{n}_fight", "center": f"bridge_{n}_center",
         "music": "mus_u1_battle_core", "on_win": "won", "on_lose": "lost"},
        {"label": "lost"},
        {"debt": 5},
        {"goto": "won"},
        {"label": "won"},
    ]
    if n == 2:
        script += [
            nar("Krona sips. The crack on her neck climbs a finger's width. Nobody says anything about it."),
            {"camera": "truth", "focus": "crono"},
            nar("And his wrist answers: the hairline widens, gold under the paint. Near the vein, the copy reacts to the original's atoms, dissolved in the oil she drinks."),
            {"camera": "explore"},
            say("sera", "Papa, your wrist. It's listening to the oil.", "hurt"),
        ]
    if n == 3:
        script += [
            say("krona", "You keep covering the wrist. Everyone here is cracked. Nobody's looking.", "neutral"),
            crono_wheel("She is looking.", "nod3", "away3", "name3"),
            {"label": "nod3"},
            nar("He takes the hand off the wrist. Leaves it uncovered for the rest of the bridge."),
            {"goto": "done3"},
            {"label": "away3"},
            nar("He does not. She lets it go."),
            {"goto": "done3"},
            {"label": "name3"},
            say("crono", "Sera used to trace it.", "sad"),
            say("krona", "...Yeah. Kids do that.", "sad"),
            {"label": "done3"},
        ]
    if n == 4:
        script += [
            nar("The last ronin bows before he falls, and the bow is to her."),
            say("krona", "Captain of my gate guard. Fourth siege. I told him to hold the bridge and he did.", "sad"),
            say("krona", "He got back up too. Didn't ask him."),
            {"checkpoint": "ch2_goyama_gate"},
        ]
    script += [{"save": 0}, {"end": True}]
    S[f"ch2_bridge_{n}"] = script

# ---------------------------------------------------------------- The Gourd
S["ch2_gourd_choice"] = [
    cap("The vein mouth, a rock split under the fourth bridge. The oil inside is not black; it is every colour the ink took away, and it moves."),
    say("krona", "This is it. The star. I come here when the gourd runs dry.", "neutral"),
    nar("She holds the gourd over the vein. Her hand is steady. Her neck is not."),
    say("krona", "You could seal it. Astral burns ink; it'd burn this. Retainers go down for good. I go down slower.", "neutral"),
    say("krona", "Or I fill up and we walk into that castle with the best tank on the island.", "neutral"),
    say("krona", "Your call. I've made mine too many times.", "sad"),
    {"choice": [
        {"text": "Seal the vein.", "goto": "seal"},
        {"text": "Let her drink.", "goto": "keep"},
        {"text": "Seal it. Keep one vial.", "goto": "both", "if": {"has_key_item": "bekkler_doll_small"}},
    ], "who": "crono", "prompt": "The oil hums at 220 hertz. Cracked."},
    {"label": "seal"},
    {"sfx": "sfx_magic_astral_burn"},
    nar("He puts the gauntlet in the vein and the oil goes gold, then white, then stone. Behind them, on the bridge, five masks fall off five faces, and the faces are at peace."),
    say("krona", "...Oh.", "surprised"),
    say("krona", "They look like them again.", "sad"),
    {"set_flag": "The_Gourd:Sealed"},
    nar("OIL-DRINKER ends. Krona's corruption clears over the coming days. She learns, slowly, to ask someone else to take a hit."),
    {"end": True},
    {"label": "keep"},
    nar("He steps back. She fills the gourd and drinks, and the crack reaches her jaw."),
    say("krona", "Good. Don't make it mean anything.", "neutral"),
    {"set_flag": "The_Gourd:Kept"},
    nar("OIL-DRINKER stays. Her Ruin decay will keep stacking, world after world."),
    {"end": True},
    {"label": "both"},
    nar("He seals it. But first she fills one vial and stoppers it with paper, and neither of them says what it is for."),
    say("krona", "Sealed and sipping. That's not a plan. That's a person.", "neutral"),
    {"set_flag": "The_Gourd:Sealed"},
    {"set": {"flag": "Gourd_Vial_Kept", "state": "set"}},
    {"end": True},
]

# ---------------------------------------------------------------- 2.5 Karma loop
S["ch2_karma_house"] = [
    cap("The Tanaka house, at the end of Paper Street. It is on fire. It is always on fire at this hour."),
    {"choice": [
        {"text": "Put it out.", "goto": "save"},
        {"text": "Let it burn.", "goto": "burn"},
    ], "who": "crono", "prompt": "A family in the doorway. They have the look of people who have done this before."},
    {"label": "save"},
    {"sfx": "sfx_magic_astral_burn"},
    nar("Astral light eats the fire the way it eats ink. The family bows. The mother repaints the door before the smoke has cleared."),
    {"counter": "house_saved", "add": 1},
    {"if": {"counter_min": "house_saved", "value": 3}, "then": "dojo", "else": "done"},
    {"label": "dojo"},
    nar("Three mornings saved. The family stops painting. They tear the paper off every door and leave the char showing, and the house becomes a dojo, and the dojo stays."),
    say("krona", "A house that stopped lying. First one on the island.", "smile"),
    {"set": {"flag": "Tanaka_Dojo", "state": "set"}},
    {"goto": "done"},
    {"label": "burn"},
    nar("He walks past. Krona walks past. The family walks out, and does not look back, and the fire goes on without an audience."),
    {"counter": "house_burned", "add": 1},
    {"if": {"counter_min": "house_burned", "value": 3}, "then": "flake", "else": "done"},
    {"label": "flake"},
    nar("Three mornings burned. The house is ash. On the ash, where the hearth was, a single flake of gold leaf: the family's memory of the room, left for whoever comes next."),
    {"give_item": "gold_leaf_memory_flake"},
    say("krona", "Some homes you can't save. You can only make sure somebody remembers the shape.", "sad"),
    {"goto": "done"},
    {"label": "done"},
    {"end": True},
]

S["ch2_goyama_flag_resolve"] = [
    # Called at the castle gate. Repainted = saved 3 + sealed; Incinerated = burned 3 + kept; Both = sealed + vial + doll.
    {"if": {"flag": "Gourd_Vial_Kept", "state": "set"}, "then": "both", "else": "check_light"},
    {"label": "both"},
    {"set_flag": "Goyama:Both"},
    {"rift": "Amber_Rift_U1_Goyama"},
    {"end": True},
    {"label": "check_light"},
    {"if": {"counter_min": "house_saved", "value": 3}, "then": "light", "else": "check_dark"},
    {"label": "light"},
    {"if": {"flag": "The_Gourd", "state": "Sealed"}, "then": "repainted", "else": "check_dark"},
    {"label": "repainted"},
    {"set_flag": "Goyama:Repainted"},
    {"end": True},
    {"label": "check_dark"},
    {"if": {"counter_min": "house_burned", "value": 3}, "then": "dark", "else": "none"},
    {"label": "dark"},
    {"if": {"flag": "The_Gourd", "state": "Kept"}, "then": "incinerated", "else": "none"},
    {"label": "incinerated"},
    {"set_flag": "Goyama:Incinerated"},
    {"end": True},
    {"label": "none"},
    {"end": True},
]

# ---------------------------------------------------------------- 2.6 Goyama Castle
S["ch2_castle_gate_poem"] = [
    {"run": "ch2_goyama_flag_resolve"},
    cap("Goyama Castle. The top three floors burn and never fall. On the gate, a poem in the Daimyo's hand, repainted every morning over the one beneath."),
    nar("Sera reads it. 'Hold the bridge, hold the gate, hold the child's hand / the ink will dry before the fire does.'"),
    say("krona", "He wrote that for me. I was nine. He wrote a new one every year and painted over the old one.", "sad"),
    {"if": {"flag": "Goyama", "state": "Both"}, "then": "doll", "else": "go"},
    {"label": "doll"},
    nar("Crono takes the small Bekkler doll from his pack and holds it out. Porcelain knows porcelain."),
    say("krona", "...That's you. The little one. Cracked the same place.", "surprised"),
    nar("She holds it. Sealed and sipping, a doll in one hand and the vial in the other. An Amber Rift opens quietly behind her, and neither of them turns around."),
    {"goto": "go"},
    {"label": "go"},
    {"checkpoint": "ch2_castle"},
    {"save": 0},
    {"end": True},
]

S["ch2_paper_doors"] = [
    cap("The paper floors. Doors of white washi in every direction, and behind each one, ash-ronin who cannot see what is not painted."),
    nar("UNPAINTED. While Crono stands behind untouched paper he is invisible to them, and he cannot attack. Step through paint to be seen. Step back to vanish."),
    say("krona", "The floors are the Daimyo's trick. He's been invisible to himself for years.", "neutral"),
    {"end": True},
]

S["ch2_daimyo_sequence"] = [
    {"checkpoint": "ch2_daimyo"},
    cap("The top floor. It burns. The fire has been burning so long it has become a kind of weather."),
    nar("At the far end, seated, twenty feet of a man made of surrender petitions. Thousands of them, folded and stacked into a body, armour weeping black oil at every joint."),
    nar("He is writing. Each petition he finishes stands up, bows, and becomes a soldier."),
    say("krona", "Lord Ashinaga. The Ashen Daimyo. He raised me when the pigment-house burned.", "sad"),
    say("krona", "Father. It's Krona. I'm back from the vein.", "neutral"),
    nar("The Daimyo does not look up. He writes her name on a petition, and the petition stands, and it has her face."),
    say("krona", "...Okay. Okay. Crono. Burn the ink. I'll corrode the rest.", "angry"),
    {"battle": "", "boss_id": "goyama_ashen_daimyo", "boss": True, "at": "daimyo_fight", "center": "daimyo_center",
     "music": "mus_boss_goyama_daimyo", "on_win": "won", "on_lose": "lost"},
    {"label": "lost"},
    {"debt": 5},
    nar("The petitions close over him like a book. Somewhere, a ghost turns the page back."),
    {"goto": "won"},
    {"label": "won"},
    {"run": "ch2_daimyo_won"},
    {"end": True},
]

S["ch2_daimyo_phase2"] = [
    nar("Break. The petitions scatter like a flock. Under the white-out on the oldest one, a child's name in a child's hand. KRONA. And under that, crossed out, another name, the one she had before the pigment-house."),
    say("krona", "He kept it. He kept the first one.", "surprised"),
    {"set_flag": "Daimyo_Phase1:set"},
    nar("RUIN PURGE learned. Krona's ink can now purge a buff and leave an Ash Field."),
    {"learn": "ruin_purge", "who": "krona"},
    {"end": True},
]

S["ch2_daimyo_phase3"] = [
    nar("The Daimyo cracks down the middle. Inside, where a heart should be, a gourd. The same gourd. Vein-oil bubbling in it at two hundred and twenty hertz."),
    say("krona", "...You drank it too?", "surprised"),
    nar("Oil floods the floor. Ash Field. The castle breathes in."),
    {"end": True},
]

S["ch2_daimyo_phase4"] = [
    nar("One shield left, and it is not a shield. It is a seal, written in two inks at once, and it can only be cut from both canvases in the same instant."),
    say("krona", "Eclipse. Now. Both of us or neither.", "angry"),
    say("sera", "Papa, I can see it from here. The seal's got two sides. Hit both.", "surprised"),
    {"end": True},
]

S["ch2_daimyo_won"] = [
    {"music": "stop"},
    nar("He comes apart as porcelain. Under the porcelain, red muscle fibre, the same fibre that runs under Crono's chest. The same maker."),
    nar("Something small falls out of him and rolls to Crono's feet. A tooth. It whispers, in a clean young voice that is Crono's own voice at seventeen."),
    say("vaelos", "Papa. Big Brother Copy. I planted one of me in every world. This one grew a Daimyo.", "neutral"),
    {"key_item": "vaelos_tooth"},
    nar("THE VAELOS TOOTH. The first proof that Vaelos seeded every timeline."),
    {"choice": [
        {"text": "Let him rest.", "goto": "rest"},
        {"text": "Rip the fibre out.", "goto": "rip"},
    ], "who": "krona", "prompt": "The Daimyo's chest is open. The Lavos fibre inside is still warm. It would make a weapon."},
    {"label": "rest"},
    nar("Krona closes the petitions over him, one by one, and the last one she folds into a crane."),
    say("krona", "Rest, Father. I'll write the next one.", "sad"),
    {"set_flag": "Ashinaga:Rested"},
    nar("U1 keeps its ink parry. The masks of Kuro-Truce stay dry."),
    {"goto": "vault"},
    {"label": "rip"},
    {"sfx": "sfx_combat_fibre_tear"},
    nar("She tears the fibre out of him in handfuls. It knots itself around the Defiled Masamune and the blade drinks."),
    say("krona", "He'd have done the same. He did do the same.", "angry"),
    {"set_flag": "Ashinaga:Ripped"},
    {"relic": "lavos_fibre_wrap"},
    nar("Every paper mask on the island begins, quietly, to weep black oil. They will not stop."),
    {"goto": "vault"},
    {"label": "vault"},
    {"checkpoint": "ch2_daimyo_done"},
    {"save": 0},
    {"end": True},
]

# ---------------------------------------------------------------- 2.7 The Cobalt Nodachi
S["ch2_vault_nodachi"] = [
    cap("The vault under Goyama. No fire here. One blade on a stand, and the blade is blue."),
    nar("The Founder's nodachi, dyed in the first cobalt pigment: the colour of the first sunrise after the ichor rain, when the island decided to live."),
    say("krona", "Every Daimyo swore on it. None of them drew it. You don't draw the sky.", "neutral"),
    nar("Its trail would stain any sky cobalt. In every other world, that stain would show Crono where the hidden slips are."),
    say("krona", "If I take it, this island never gets its morning back. Crimson Night, forever. The paint stops working.", "neutral"),
    say("krona", "If I leave it, we go into the Furnace with rust.", "neutral"),
    {"choice": [
        {"text": "Take it.", "goto": "take"},
        {"text": "Leave it.", "goto": "leave"},
    ], "who": "krona", "prompt": "Her hand is on the hilt. She is waiting for him to decide, and he knows it is not his to decide."},
    {"label": "take"},
    {"sfx": "sfx_weapons_nodachi_draw_cobalt"},
    nar("She draws it. The vault turns indigo, then white. Above them, outside, the paper sky goes red and stays red."),
    say("krona", "Some homes you save by leaving them burning.", "sad"),
    nar("Krona weeps. First time. The oil in her gourd stops bubbling and does not start again."),
    {"set_flag": "Cobalt_Nodachi:Taken"},
    {"key_item": "cobalt_nodachi"},
    {"learn": "cobalt_nodachi", "who": "krona"},
    nar("THE COBALT NODACHI. Its trail stains the sky; Crono's Smear Dash can now find hidden Chronoslips in every world. HOMELAND DYE: a portal back to U1 from anywhere."),
    {"goto": "done"},
    {"label": "leave"},
    nar("She takes her hand off the hilt. The blade stays blue. The morning stays possible."),
    say("krona", "Rust is honest. We'll manage.", "neutral"),
    {"set_flag": "Cobalt_Nodachi:Left"},
    {"goto": "done"},
    {"label": "done"},
    {"checkpoint": "ch2_vault_done"},
    {"save": 0},
    {"end": True},
]

# ---------------------------------------------------------------- 2.8 The Mammon Furnace
S["ch2_furnace_sequence"] = [
    {"checkpoint": "ch2_furnace"},
    {"music": "mus_u1_furnace_approach"},
    cap("The Mammon Furnace. Under Goyama, where the vein runs into something older than the island. Heat with a heartbeat."),
    nar("Above the furnace, hung from the clay gear's teeth, a cage of hard geometry. In it, a girl, flickering through seven kinds of drawing: ink, clay, line, glass, rubber, cel, gold."),
    say("sera", "PAPA. Papa I'm here, I'm right here, don't look at the— don't look at the thing under me.", "hurt"),
    nar("The thing under her stands up. Its lower half is an ink Lavos spawn, brushed. Its upper half is a clay clockwork centipede, thumbprinted, turning at twelve. Two drawings, two speeds, one body."),
    say("krona", "That's what the gear brought. That's two worlds eating each other.", "angry"),
    say("krona", "Burn the ink. I'll rot the clay. The ghost does the rest.", "neutral"),
    say("sera", "I've got the daggers. I can rewind you, Papa. I can speed her up. Just don't die where I can see it.", "hurt"),
    {"sera_state": "hover_support"},
    {"battle": "", "boss_id": "weeping_shogun", "boss": True, "at": "furnace_fight", "center": "furnace_center",
     "music": "mus_boss_weeping_shogun", "on_win": "won", "on_lose": "lost"},
    {"label": "lost"},
    {"debt": 5},
    nar("The Furnace takes them. The cage above it turns the page back, and the girl's hand is a little more transparent for it."),
    {"goto": "won"},
    {"label": "won"},
    {"run": "ch2_furnace_won"},
    {"end": True},
]

S["ch2_furnace_won"] = [
    {"music": "stop"},
    nar("The Shogun falls in two directions at once, the ink half dissolving to gold, the clay half sagging in slow, stepped frames. The weeping stops."),
    {"camera": "truth", "focus": "sera_cage"},
    nar("And the cage lifts. Not on the chain. Lifted. A hand nine feet above the ground, alabaster and leaking starlight, closes around the geometry and raises it toward the tear the gear left in the sky."),
    say("vaelos", "Little Sister. Day one.", "neutral"),
    say("sera", "Papa! PAPA, I'll find— don't forget me—", "hurt"),
    {"sera_state": "absent"},
    nar("Gone, up the seam. Crono does not shout. He has never been a shouter. He puts his hand on his wrist and the crack under it is wider than it was this morning."),
    {"camera": "explore"},
    {"wait": 1.0},
    say("krona", "That's the thing from the Fair.", "neutral"),
    say("krona", "It has your face. Younger. It's the you that didn't come back.", "sad"),
    crono_wheel("Krona has never asked him a question he had to answer with words.", "nod_f", "away_f", "name_f"),
    {"label": "nod_f"},
    nar("He nods. Once."),
    {"goto": "hook"},
    {"label": "away_f"},
    nar("He looks at the tear in the sky, and keeps looking."),
    {"goto": "hook"},
    {"label": "name_f"},
    say("crono", "Sera.", "neutral"),
    say("crono", "He said day one.", "neutral"),
    {"goto": "hook"},
    {"label": "hook"},
    nar("Wedged in the clay gear's teeth, something from the next world: the front wheel of a jetbike, burned out, its tyre still turning. A name scratched into the hub. JOHNNY."),
    say("krona", "Still runs. Course it still runs.", "smile"),
    nar("It tows them up the seam, toward a year that smells of oil and dust. 2300 A.D."),
    {"set": {"flag": "Chapter2_Done", "state": "set"}},
    {"chapter": 3},
    {"checkpoint": "ch2_done"},
    {"save": 0},
    {"run": "ch2_interlude_day1"},
    {"go": "ossuary_arrival", "spawn": "seam_exit"},
    {"end": True},
]

# ---------------------------------------------------------------- Interlude — Day 1
S["ch2_interlude_day1"] = [
    {"universe": 8},
    {"party": ["sera"]},
    {"music": "mus_interlude_ash_kitchen"},
    cap("Interlude. Day 1. The House Without Doors."),
    nar("A kitchen built from ash. Guardia's table, Guardia's pots, Guardia's window, and behind the window, nothing. Not dark. Nothing."),
    nar("Vaelos sits where her father sits. There is a bowl in front of him, and a spoon, and ash where the porridge should be."),
    say("vaelos", "Little Sister. Teach me the seven stirs.", "neutral"),
    say("sera", "...Why.", "angry"),
    say("vaelos", "Because he does them for you every morning and nobody has ever done them for me. I was incubated, not stirred.", "neutral"),
    say("vaelos", "You hum like the house I was never allowed into.", "neutral"),
    nar("She can walk the room. She can rewind the ash he spills, and every rewind costs her: the day's clock, moving in her hands."),
    {"choice": [
        {"text": "Teach him. Properly.", "goto": "teach"},
        {"text": "Teach him wrong.", "goto": "wrong"},
        {"text": "Refuse.", "goto": "refuse"},
    ], "who": "sera", "prompt": "Seven stirs, clockwise, and a tap on the rim. She has known it since before she could hold the spoon."},
    {"label": "teach"},
    nar("She shows him. Seven, clockwise. The tap. His hand is too big for the spoon and he holds it like a sword, and she fixes his fingers without thinking, the way her father fixed hers."),
    say("vaelos", "Again. I want to get it right before he does.", "neutral"),
    {"counter": "spoon_lessons", "add": 1},
    {"debt": 3},
    {"goto": "end_day"},
    {"label": "wrong"},
    nar("She shows him. Six stirs, counter-clockwise, no tap. He copies it exactly, and she watches him be wrong with a face that gives nothing away."),
    say("vaelos", "That felt incomplete. Is it supposed to feel incomplete?", "neutral"),
    say("sera", "That's the whole trick of it.", "neutral"),
    {"counter": "spoon_lessons_wrong", "add": 1},
    {"debt": 2},
    {"goto": "end_day"},
    {"label": "refuse"},
    say("sera", "No. That's his. You don't get to have his.", "angry"),
    nar("He does not get angry. That is worse. He stirs the ash on his own, wrong, and watches her watch him."),
    say("vaelos", "Which of us has the right to be her father? I'll keep asking. There are six more days.", "neutral"),
    {"debt": 2},
    {"goto": "end_day"},
    {"label": "end_day"},
    say("vaelos", "This is day one, Little Sister.", "neutral"),
    {"camera": "truth", "focus": "sera"},
    nar("When the interlude ends her hand is a little more transparent than it was. She notices. She does not say 'Mama'. Not yet."),
    {"camera": "explore"},
    {"fade": "out", "wait": 1.0},
    {"party": ["crono", "krona"]},
    {"end": True},
]

out = Path("data/dialogue/chapter2.json")
out.write_text(json.dumps(S, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"wrote {out} with {len(S)} scripts, {sum(len(v) for v in S.values())} commands")
