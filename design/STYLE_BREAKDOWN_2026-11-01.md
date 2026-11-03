# Chrono-Style Recreation Breakdown (Nich, Nov 1 2026)

Nich's style document, delivered as `Style_breakdown.pdf` on 2026-11-02 and adopted as the project's art
direction in `docs/DECISIONS.md` ("Direction: the Nov 1 recipe is the style"). This is the text layer of the
PDF, kept verbatim (tables flattened by the extraction) so that every tool working from the repository can read
it; the PDF's images are not reproduced. Where this document and the Reference Bible disagree, DECISIONS
records which wins (today: this document on sprite scale, palette, outlines, held frames and world density;
the Reference Bible's per-universe grades survive as compositor post, not as sprite grammar). Its section 14
(originality: no Square Enix names in prompts, no ripped art) is binding on every generator prompt. The game's
working title stays "TRIGGER: Time Debt" until Nich picks the release title (QUESTIONS_FOR_NICH).

```text
Style breakdown




  Chrono Time Break — Chrono-Style
  Recreation Breakdown
    Nov 1, 2026   · ​@Nich


  1. What "Chrono Break" actually is
  Chrono Break is a name, not a game: Square trademarked it in 2001 for a third Chrono title
  that was never built, so there is no Chrono Break art, screenshot or sprite to copy. The
  style Chrono Time Break is chasing is Chrono Trigger's (SNES, 1995), with Chrono Cross's
  colour and mood where you want it, reinterpreted in HD-2D. Everything below treats
  Trigger as the primary reference.


     Date          Event                                   What it means for you

     Feb 19,       Insider John Harker posts that          Rumour only. Nothing official as of
     2026          "chrono stuff" is already in            this doc's date.
                   development at Square Enix; no
                   details, unverified (Vice)

     Nov 2025      Yuji Horii, asked about a remake on a   Neither confirmation nor denial.
                   stream, says he cannot answer (Vice)

     May 9,        Square Enix tells Gamespark no          The only official word in the 2020s.
     2025          Chrono Trigger remake is announced
                   and Horii is not considering one
                   (Nintendo Life)

     Mar 11,       Square Enix marks the 30th              Merchandise and events, not a new
     2025          anniversary and promises "various       game.
                   projects" beyond the game itself;
                   none named (Automaton)

     Dec 2017      Takashi Tokita says the cancelled       The closest thing to a Chrono Break
                   Chrono Break concept was reworked       that shipped is a mobile Final Fantasy.
                   into Final Fantasy Dimensions II;
                   preproduction had started in 2000
                   (Wikipedia)




                                                                                              Page 1 of 36
Style breakdown




     Date         Event                                   What it means for you

     Dec 2015     Masato Kato confirms Square Enix        Story intent exists in interviews;
                  discussed a Chrono Break project        visuals never did.
                  without him and describes the ending
                  he had in mind (Wikipedia)

     Jul 26,      Japanese mark "Chrono Brake" (   クロ     The Chrono Break name itself is
     2012         ノ・ブレイク      ) expires; the EU mark      lapsed, but "Chrono" is still Square
                  had expired Dec 14, 2011 (Wikipedia)    Enix's live mark (see section 14).

     Nov 13,      US "Chrono Break" registration
     2003         dropped (Wikipedia)

     Dec 5,       Square registers "Chrono Break" in      The whole "Chrono Break" era is
     2001         the US, five months after Sakaguchi     2000–2003 and produced no public
                  told GameSpot (3 July 2001) that the    art.
                  Cross team, especially Kato, wanted a
                  new Chrono game but nothing was
                  greenlit (Wikipedia)


  What this means for a fresh start: you are recreating a look that exists in two finished
  games, not a lost one. Trigger gives you the sprite language, field perspective, battle flow
  and UI; Cross gives you a richer, painterly colour sense and world-map mood; HD-2D
  (section 4) gives you the camera, lighting and depth that make it feel "next-gen" without
  losing the pixels. Section 14 covers why the title and the word Chrono need care.


  2. The Chrono visual DNA
  An image reads as Chrono when four things are true at once: Toriyama-style "deformed"
  character design with identity carried by hair silhouette and two or three flat costume
  colours; field sprites about 3 heads tall with coloured outlines and a signature walk per
  character; painterly, saturated field art that changes palette and architecture with every
  era; and battles and effects that happen on that same field art. Everything else (HD-2D
  camera, lighting, audio) is a layer on top of those four.

  Who made the look, so you know which rules are whose. The Dream Team was Hironobu
  Sakaguchi (systems and monster ideas), Yuji Horii (story outline, Lavos) and Akira
  Toriyama (characters, monsters, vehicles and the look of each era), working from eight
  character sketches by scenario writer Masato Kato; the sprite and field team sat under
  graphic director Tetsuya Takahashi with field artists Yasuyuki Honne, Tetsuya Nomura and



                                                                                               Page 2 of 36
Style breakdown




  Yusuke Naora, and graphics programmer Yasuhiko Kamata set the game's brightness
  between Secret of Mana and Final Fantasy and cited the film Alien for its lighting
  (Wikipedia, shmuplations). The cartridge grew from 24 to 32 Mbit, with about 6 of the
  extra 8 Mbit spent on graphics, because Sakaguchi wanted NPC outfits and towns to
  change per era. Toriyama died on 1 March 2024, aged 68 (Nova Crystallis).

  Toriyama's design language, in rules you can apply to original characters. He preferred
  the deformed style over realism, emphasised one or two distinguishing traits or
  deliberately played them down so personality and movement carried the character, did
  little to create depth, and kept linework simple and angular rather than round
  (Kanzenshuu 1990, Kanzenshuu 2010). His machines use an egg-shaped vocabulary of big,
  soft, simple forms with a little exposed piping, and real WWII aircraft and cars deformed
  but authentic (Zimmerit). The early Chrono sketches show what he treated as fixed from
  day one: the hero's hair, clothes and sword never changed, while the robot started as a
  pure machine and became more human (GlitterBerri).


     Rule                                         How to apply it in Chrono Time Break

     One strong hair silhouette per character     design the hair as geometric clumps readable
                                                  at 32 px; it is the first thing players recognise

     Two or three flat costume colours plus one   pick them before any detail; the sprite will
     accent                                       only have 12–16 colours anyway

     Personality in brow and mouth, not           simple eyes and nose, expression from
     rendering                                    eyebrows and mouth shape; humour even in
                                                  serious scenes

     Egg-shaped machines with visible pipes       vehicles and robots built from soft rounded
                                                  masses with one or two mechanical details

     One trait pushed, the rest quiet             every cast member gets one exaggerated
                                                  feature; everyone else is restrained so it
                                                  reads


  How the sprite team translated it (rules for your sprites). Field and battle sprites are the
  same ~32 px tall sprites (the frog character is 24), about 3 heads tall with short torsos and
  long limbs so poses read; a sprite uses about 12 colours out of the SNES limit of 16, with
  black line art recoloured to dark tones matched to each costume part (hair lines in dark
  red or brown), skin in two tones, hair in three or four, and single near-white highlight pixels
  on gloves, boots, shoulders and knees; hair is drawn as a mosaic of rigid triangular shapes;



                                                                                               Page 3 of 36
Style breakdown




  and every character has its own walk (the robot like a stove on feet, the princess delicate,
  the cavewoman swinging fists, the mage strutting), with walk cycles getting the most
  frames (Brandon James Greer tutorial transcript, humbird0). Critics in 1995 and since
  single out exactly this: readable near-realistic sprites, funny character animation, and
  backgrounds full of motion whose palette use makes parts look like a painting (RPGFan).
  Section 5 turns these into a per-character spec.

  Era palettes and motifs. No source publishes the game's palette values, so the hex values
  are yours to set; the motifs below are sourced and the colour summaries are a synthesis.


     Era                    Sourced motifs and mood              Palette brief for your version

     65,000,000 B.C.        jungle, torrential rain, a tribal    saturated greens, red-brown
                            village of festivals and drinking    earth, storm grey; warm
                            contests, a reptile lair in dense    firelight at night
                            jungle, a technologically superior
                            fortress reachable only by air,
                            later a charred impact crater
                            (Chrono Wiki)

     12,000 B.C. (the       warm green kingdom above the         sky blue and cloud white
     floating kingdom)      clouds with water and plants; a      outside, gold and Tyrian purple
                            never-ending blizzard on the         inside, blizzard white and slate
                            surface below; gold-walled           below
                            palace with purple banners,
                            statues and bookcases; crystal
                            spires and togas; the final cape
                            scene uses a morning palette
                            (Chrono Wiki, Giant Bomb,
                            TCRF)

     600 A.D.               knights, monsters and magic;         desaturated greens, grey
                            the town as a gloomy, misty          stone, mist; torchlight interiors
                            version of its future self; stone
                            castle, cathedral and bridge; a
                            cursed wood full of frogs
                            (Chrono Wiki)




                                                                                              Page 4 of 36
Style breakdown




     Era                    Sourced motifs and mood              Palette brief for your version

     1000 A.D.              opening pan to a festival town       the brightest palette in the
                            with fair stalls and a bell; a       game: clear sky, grass green,
                            medieval-modern mix with             festival reds and yellows
                            refrigerators beside swords;
                            mostly a hub (Chrono Wiki)

     1999 A.D.              domed cities on a lush green         glimpsed, not explored: cool
                            continent, seen only in a            whites and glass blues
                            recording before the
                            catastrophe

     2300 A.D.              barren wasteland, discoloured        ash grey, rust brown, cold blue-
                            ground, falling ash, howling wind,   black; one sickly green for
                            craters; domes of rusted metal       machine light
                            and corroded piping; a labyrinth
                            of decapitated buildings; rusted
                            cars and broken streetlights
                            (Chrono Wiki)

     End of Time            a wall-less room, golden gates,      near-black with gold and white
                            three white pillars of light, a      light only
                            staircase and a lone street lamp


  What this means for the HD-2D version. Keep the sprite-side rules exactly (3-head
  proportions, coloured outlines, flat cel colour, signature idle and walk) and let 3D carry
  only the backgrounds; keep lighting high-key and saturated so the era palettes stay
  legible, because readers of Nintendo Life's remake debate warn that tilt-shift and moody
  HD-2D lighting dull the bright colours they associate with the game (Nintendo Life). The
  Octopath Traveler II director drew on Chrono Trigger's trial-scene scenery as the standard
  for a screenshot that looks good anywhere (GoNintendo); you are aiming at the same bar
  from the other direction.


  3. Hard technical specs of Chrono Trigger's art
  Chrono Trigger is a 256×224, Mode 1 game: two 16-colour tile layers plus a 4-colour layer
  for clouds, fog and captions, 16×16 map tiles built from 8×8 chips, characters made of
  16×16 sprite units using exactly 12 colours, and Mode 7 reserved for set pieces (the world
  map is an ordinary three-layer tilemap, not Mode 7). The numbers below come from the




                                                                                             Page 5 of 36
Style breakdown




  SNES hardware references and from two open reverse-engineering projects that read the
  ROM directly: GitExl's CTViewer map viewer and the Belthasar Project, a C re-
  implementation checked frame-by-frame against the original.


     Parameter               Value                                       Source

     Output resolution       256×224; pixels are 8:7 on a typical        Fullsnes, SnesLab
                             CRT (7:6 for exact 4:3)

     Colour                  15-bit BGR, 5 bits per channel, 256         SNESdev
                             palette entries on screen

     Background mode         Mode 1 with BG3 priority ( $2105 =          Belthasar notes
                             $09 ): BG1 and BG2 at 16 colours, BG3
                             at 4 colours

     Palettes                8 background and 8 sprite palettes of       CTViewer palettes.md
                             15 colours plus transparent; a scene
                             carries 7 tile palettes of 15

     Map tile                16×16 built from four 8×8 chips, each       CTViewer tilesets.md
                             with its own palette, priority and flips

     Scene layers            16–64 tiles per axis per layer; field       CTViewer, Belthasar
                             tilemaps 64×32; viewport 16×14 tiles

     Layer scroll speeds     0, 3.75, 7.5, 15, 30, 60, 120 or 240 px/s   CTViewer
                             on BG2/BG3, plus a parallax mode and
                             a half-speed camera mode

     Tile animation          chips animate in sets of 4 with holds       CTViewer, Belthasar
                             of 16, 12, 8 or 4 ticks; palette rotation
                             steps one colour every 6 frames in the
                             gate scene

     Sprite units            16×16 OBJ; a frame is 1×4, 1×8, 3×4 or      CTViewer sprite.rs,
                             3×8 units; the hero in the field is 4       Belthasar
                             units (32×32 box)

     Colours per character   exactly 12 (indices 1–12; 0 transparent;    Belthasar, Greer
                             13–15 unused); the frog has 11, the
                             cavewoman 13




                                                                                                Page 6 of 36
Style breakdown




     Parameter               Value                                      Source

     Character height        about 32 px (one source measures a         Greer, Bahamonde
                             15×36 idle box including hair); the frog
                             is 24 px

     Overworld mini-sprite   about 11×17 px in one 16×16 unit; right    Belthasar, Bahamonde
                             = left flipped; 8 px steps

     Portrait                48×48 px drawn as 6×6 background           Belthasar
                             tiles, not a sprite; a separate 16×16
                             face icon in the battle ribbon

     Facings                 4, each hand-drawn; no automatic           CTViewer
                             mirroring on field or battle sprites

     Frame timing            every animation step holds N frames        CTViewer
                             at 60 Hz; nothing is tweened

     Player walk             6-step strip; NPC walks like 15/10/15/10   Belthasar
                             frames (50-frame cycle); run 5/5;
                             overworld walk legA 8 / stand 8 / legB
                             8 / stand 8

     Idle                    blink after about 767 idle frames          Belthasar
                             (about 13 s); overworld fidget after
                             240 frames

     Basic attack            7 poses over about 79 frames (6, 5, 15,    Belthasar battle notes
                             27, 9, 17, then snap)

     Hurt                    all-white palette swap for 9–10            Belthasar
                             frames; slash effect about 15 frames;
                             knockback 5–9 px; enemy death =
                             palette swap then dissolve

     Sprite limits           128 per frame, 32 per scanline             SNESdev OAM

     Colour math             shadows are BG2 half-added over            SNESdev colour math,
                             BG3; torch glow is BG3 full-add; sprite    Belthasar
                             palettes 0–3 never blend

     Menu gradient           HDMA writes a 16-step ±8 grey ramp         Belthasar
                             per window, added at the top and
                             subtracted at the bottom




                                                                                             Page 7 of 36
Style breakdown




     Parameter               Value                                      Source

     HDMA                    all 8 channels rebuilt every frame for     Belthasar
                             text boxes, a 16-line sine wave at the
                             End of Time, and per-line window
                             colour

     Mode 7                  title pendulum, bike race, Lavos           Data Crystal
                             impact, Epoch crash, wormholes,
                             credits; not the world map

     World map               96×64 tiles, 3 layers with clouds on       CTViewer map_data.md
                             BG3; the 600 and 1000 A.D. overworld
                             tilesets are palette swaps of each
                             other

     Interlace and offset-   interlace only in the cockpit crash;       SNESdev
     per-tile                horizontal offset-per-tile for the Black
                             Omen shimmer; vertical for the wavy
                             title


  What the numbers mean for a 2026 build. Your framing is 256×224-class: at 16:9 that is
  about 398×224, so a 640×360 internal canvas shows roughly 1.6× more world than the
  original, which is fine for HD-2D but means your tiles and sprites need slightly more detail
  than the originals to avoid feeling empty (Octopath hit the same problem and answered it
  with denser tiles, section 4). Keep the 12-colour sprite budget and the hold-N-frames
  timing even though nothing forces you to; they are the two constraints that make
  animation read as Chrono rather than as modern pixel art. Keep solid characters in a
  "never blends" group and ghosts and effects in a "blends" group to mirror the hardware's
  colour-math split.

  Open gaps: no source gives numeric wall-height or floor-compression ratios for the
  interiors, the exact walk duration bytes for the hero, or measured shadow hue shifts;
  Chrono Compendium's sprite and animation tutorials block automated reading.


  4. Chrono Cross and the HD-2D question
  Take Chrono Cross's backgrounds and world design, not its characters: its painterly
  dioramas were captured from 3D scenes at a fixed angle, which is exactly what an HD-2D
  pipeline does in real time, while its 3D cast is the part even its fans call a night-and-day




                                                                                          Page 8 of 36
Style breakdown




  break from Trigger. For Chrono Time Break that means Trigger sprites in a Cross-style
  diorama, lit the Octopath way but kept brighter.

  What Cross changed. Kato directed and wrote it, Hiromichi Tanaka produced, Nobuteru
  Yuuki (Record of Lodoss War, Escaflowne) replaced Toriyama on character design, and
  Honne became art director and "map painter"; locations were modelled in 3D, the best
  angle chosen, and a still capture used as the pre-rendered background with low-poly
  characters over it, and that 3D source data no longer exists (Wikipedia, Siliconera). The
  setting is a bright tropical archipelago, rustic and surrounded by water, as a deliberate
  contrast to Trigger's castles and caves; Kato wanted a Southeast Asian feel with Greek
  tones and chose parallel worlds over time travel so the same places exist in two states, a
  lived-in Home World and a melancholy Another World (Inverse, Siliconera). A 2000 review
  praised the colour and detail of the backgrounds and world map but called Yuuki's
  eccentric cast too cherubic (RPGFan).

  What the 2022 remaster teaches. Chrono Cross: The Radical Dreamers Edition (7 April
  2022) upscaled the old background captures with AI sharpening plus manual repairs, and
  Yuuki redrew every portrait; Digital Foundry found the reconstructed backgrounds blurry
  and clashing with the crisp new models, with battles dropping to 15 fps until a 60 fps
  patch on 22 February 2023 (Sportskeeda summary, Wikipedia). Two lessons for a new
  project: never mix crisp and soft assets in one frame, and keep the 3D source scenes for
  every background you ever render.


     Borrow from Cross                              Leave with Cross

     painterly, high-detail backgrounds             low-poly 3D characters; keep pixel sprites
     composed from a 3D blockout at a fixed
     angle

     a saturated water-and-tropics palette as a     separate battle screens; Trigger fights on
     counterweight to medieval greens               the field

     "same place, two states" level design (your    portrait art that drifts away from the in-
     eras can do this across time)                  world model

     two moons, a red one and a white one, as a     the 30 fps cap
     cheap sky signature


  What HD-2D is, in one paragraph. Square Enix's term for pixel-art sprites billboarded as
  flat sheets inside a fully 3D, tile-built diorama, lit by real 3D lights (the breakthrough on
  Octopath Traveler was giving every battle effect a point light so sprites cast shadows),



                                                                                                 Page 9 of 36
Style breakdown




  then finished with HD post-processing: tilt-shift depth of field, bloom, fog, volumetric
  light and particles (Unreal spotlight, Wikipedia). The only published numbers: Octopath's
  base character sprites are 18×32 px with animation cells up to 128×128 px, about 350
  sprite images per character, and the Switch version renders at 720p docked (CGWORLD,
  Nintendo Everything). Acquire kept ambient light above zero so shadows never go black,
  built interiors about twice the scale of exteriors and hid the jump behind door sounds and
  a lighting change, and reserved camera rotation for scripted moments because rotated
  pixel textures showed seams (Unreal Fest East 2018 report). When sprites looked lonely
  on big screens they raised tile variety and colour density rather than sprite resolution
  (Siliconera). Triangle Strategy's producer: it costs more than you would think, and the
  studio that succeeded started from deliberately low-detail images and built effects up
  rather than downscaling photoreal ones (Nintendo Life).

  The decision for Chrono Time Break. Go HD-2D for the camera tilt, depth and lighting,
  and set three non-negotiables that keep it Chrono rather than Octopath: sprites stay 3
  heads tall with Trigger's coloured outlines and flat cel colour (Octopath II deliberately
  moved to a smaller head-to-body ratio, which reads as a different series); lighting stays
  high-key and saturated with DOF kept subtle, because fans of the original object to the
  dull, moody look (Nintendo Life); and nothing goes photoreal, since a hyper-realistic UE5
  fan remake in October 2025 drew exactly that backlash, with fans asking for a cartoon-
  faithful or HD-2D treatment instead (LevelUp). The engine settings that implement this
  are in section 12.


  5. Character sprite recipe
  A Chrono-style character is a 32 px-tall, 3-heads-tall figure in a 32×32 box (40 tall for
  raised arms), 12 colours plus transparent, dark coloured outlines instead of black, two skin
  tones, three or four hair tones, single-pixel highlights, four hand-drawn facings, and an
  animation set timed in held frames. Build every cast member to this sheet and they will sit
  together.

  Canvas and proportions. Work at 32×32 for the field and battle sprite (the original uses
  the same sprite for both), 48×48 for the menu portrait, and a 16×16 face icon for the battle
  ribbon. The body is almost 3 heads tall with a short torso and long limbs so poses read,
  and the head is smaller than chibi styles, closer to a realistically proportioned human
  (humbird0, Greer). If you generate in PixelLab at 64×64 (section 9), design at that size
  with the same proportions and treat it as 2× the original density, which is also roughly
  Octopath's ratio of 18×32 sprites in 128×128 cells.




                                                                                              Page 10 of 36
Style breakdown




  The 12-colour budget. The ROM stores 12 colours per character palette, so this is a real
  constraint, not a convention.


     Slot         Colours   Use

     1            1         darkest outline, a dark version of the dominant
                            costume colour, never pure black except as deep
                            shadow under a boot

     2–3          2         skin: base and shadow; nothing else uses them

     4–7          3–4       hair: base, shadow, highlight, and a dark line colour
                            matched to the hair (dark red or brown for warm
                            hair)

     8–10         2–3       main garment: base, shadow, optional highlight

     11           1         second garment or trim

     12           1         near-white highlight used as single pixels on
                            gloves, boots, shoulders and knees, or metal shine


  Midtones go down first, then shadow and highlight; keep at least a 1 px gap between limbs;
  step cuffs 3 px then 1 px; skin is drawn as two flat tones with no gradient (Greer).
  Shadows are darker, slightly cooler versions of the base rather than strong purple shifts,
  an estimate from the tutorials rather than a measurement; modern ramp rules agree:
  shadows cooler and less saturated, highlights warmer, hue steps of 20° or less, and three
  shades per material at 32×32 (Saint11, Pixelblog, Pixnote). Anti-alias only steps of 2 px or
  more, never 45° lines, and never pillow-shade (Saint11).

  Outlines. Coloured line work, not black: the outline is a darker shade of whatever it
  encloses, lighter on the lit top and left edges, darker on the bottom and right, with black
  kept only where distinct shapes meet, such as chin against neck (Lospec outlines). This is
  the single biggest difference between a Chrono sprite and a generic RPG Maker one, and
  it is what PixelLab's selective outline setting approximates.

  Hair and silhouette. Hair is a mosaic of rigid triangular clumps; it is the identifier at 32 px,
  so each cast member needs a different clump count and direction (swept back, hanging
  straight, a single fringe, a topknot). Costumes get two or three flat colours in big blocks;
  detail is spent on one prop per character.




                                                                                             Page 11 of 36
Style breakdown




  Portraits. 48×48, drawn to the same palette family as the sprite so menus and dialogue
  never drift from the field; six expressions per main character (calm, happy, angry, sad,
  surprised, determined).

  The animation set per character. Four facings, every one hand-drawn (mirror only tiny
  overworld sprites); frames are held, never tweened; the original's cadences are below so
  your timing matches.


     Animation      Frames                  Timing in the original       Notes

     Idle           1 + blink               blink after about 13 s       the hero also has a
                                            idle                         head-shake when
                                                                         walking into a wall

     Walk           6 steps (player), 4     10–15 frames per step;       each character walks
                    (NPC)                   NPC example 15/10/15/10      differently: a stove on
                                                                         feet, delicate, fist-
                                                                         swinging, strutting

     Run            2–4 steps               about 5 frames per step      triggers above a speed
                                                                         threshold

     Overworld      legA / stand / legB /   8 frames each                one 16×16 unit, 8 px
     walk           stand                                                steps

     Battle ready   1–3 poses               held                         the field sprite turns to
                                                                         face the enemy, no
                                                                         transition

     Attack         7 poses                 about 79 frames: 6, 5, 15,   poses snap; two of the
                                            27, 9, 17, snap to idle      drifts are smooth

     Hurt           1 pose + flash          all-white palette swap       the flash is a palette
                                            9–10 frames, 5–9 px          swap, not an overlay
                                            knockback

     Cast           2–3 poses               held while the effect        effect and palette flash
                                            sprite plays                 are separate layers

     Victory        2–3 poses               held                         one personality beat
                                                                         each

     Death /        1 pose                  palette swap then            party members fall and
     dissolve                               dissolve (enemies)           stay




                                                                                                Page 12 of 36
Style breakdown




     Animation      Frames                 Timing in the original      Notes

     Expressions    nod, shake head,       2–4 frames each             the original hero has
                    laugh, shocked,                                    about 21 expression
                    blink, wink                                        clips, 25 action clips and
                                                                       13 movement clips
                                                                       (VGSprites catalogue)


  Sources for the timings: the Belthasar Project's frame-measured notes on walk rates,
  battle action effects and the overworld sprite (repository). Sea of Stars went to eight
  facings and about 60 navigation animations per character (Nintendo Life); four facings
  with more expression clips is the more Chrono choice and far cheaper.

  Enemies and bosses. Size classes follow the original's sprite assembly: 1×4 units (32×32)
  for small enemies, 1×8 (32×64 or 64×32) for medium, 3×4 and 3×8 for bosses up to about
  96 px wide. Enemy attack sets are drawn per direction, not mirrored. Give every enemy
  one idea and one silhouette, and give bosses a shell form and a reveal (section 7).


  6. Environment and tileset recipe
  Chrono fields are 16×16-tile maps in a three-quarter top-down projection, built on three
  layers with distinct jobs: floors and walls, overlays with half-transparent shadows and
  parallax skies, and a 4-colour cloud, fog and caption layer. Each era is a palette and
  architecture swap on that same grammar, and atmosphere comes from colour-math layers
  and palette rotation, not from dithering.

  Projection. The standard 16-bit three-quarter view: floors seen from above, walls and
  building fronts drawn face-on, the viewer about 45° above, with roughly three quarters of
  a roof and a facade visible and roof angles kept front-on; light comes from one top corner
  and projections never mix in one scene (Pixelblog 3). The usual RPG mapping is x' = x, y' =
  y + z, so a cube is two tiles high (OpenGameArt). No source measures Chrono Trigger's
  own wall ratio; the estimate is about 2 tiles (32 px) of wall face over a 1-tile top edge, so a
  32 px sprite stands in front of a 32 px wall. For HD-2D this is the one rule that changes: the
  GridMap gives you real walls, and the camera pitch (about 30°, section 12) replaces the
  drawn projection, so tile textures are drawn flat top-down and wall faces straight-on with
  no baked perspective.




                                                                                            Page 13 of 36
Style breakdown




     Layer in the       What it held                       Godot equivalent
     original

     BG1 (16            floors, walls, furniture, the      GridMap meshes (HD-2D) or the base
     colours)           camera window that streams         TileMapLayer
                        in

     BG2 (16            overlays, half-added shadows,      a second TileMapLayer with Y-sort, or
     colours)           parallax skies, the half-speed     a shadow-casting mesh; Parallax2D
                        camera layer                       for skies

     BG3 (4 colours)    clouds, fog, captions, the End     a CanvasLayer with a scrolling cloud
                        of Time sine wave                  texture and a wobble shader

     Priority bit per   a bed's headboard draws over       Y-sort origin per tile, or z_index on the
     8×8 chip           the sprite's head                  overlay layer

     Scroll speed       0 to 240 px/s per axis per layer   Parallax2D.scroll_scale or a
     table                                                 GridMap layer offset tied to the
                                                           camera


  Sources: CTViewer tilesets.md, CTViewer maps.rs, Belthasar field notes, Data Crystal
  event tricks.

  Tile rules. 16×16 is the balanced size for this view; stairs are drawn at character scale,
  railings go on a separate layer, and interiors get their own tileset (Pixelblog 35). A scene
  has 7 tile palettes of 15 colours, so one era's tileset lives in about 105 colours: plan each
  biome as 7 material families (ground, water, stone, wood, foliage, metal, special) with 15
  colours each. Animated chips come in sets of 4 with holds of 16, 12, 8 or 4 ticks; water,
  torches, machines and banners should animate on those four speeds and nothing else, so
  the field has a consistent pulse.

  Lighting and atmosphere. Every shadow in a measured scene is BG2 half-added over
  BG3, torch glow is BG3 full-add, and night and weather in games of this type are palette
  swaps or LUT remaps rather than blends: a night remap at about half luma with blue
  pushed up, rain scaling all channels to 13/16 (Belthasar field notes, Crosley). In Godot: a
  half-alpha dark overlay sprite for shadows, an additive sprite for glow, a CanvasModulate
  or colour-correction LUT for time of day, and palette rotation as a shader that cycles a 16-
  entry lookup texture every 6 frames for water and gate effects. The hardware trick where
  the game rebuilds all 8 HDMA channels every frame to draw sky gradients and the text-
  box colour is, in a modern engine, a 1-D gradient texture sampled by screen Y.



                                                                                               Page 14 of 36
Style breakdown




  World map. The original is a 96×64-tile, three-layer map with clouds on the top layer; the
  600 and 1000 A.D. overworld tilesets are palette swaps of each other, which is the
  cheapest era trick in the game (CTViewer map_data.md, TCRF). Build one 96×64 base
  map per world state, derive sibling eras by palette swap plus local tile edits (a forest that
  becomes a desert, a city that becomes a crater), and put the Mode 7 budget into the
  handful of scripted set pieces (section 7).

  Per-era architecture checklist. Each era needs: one exterior ground set (Wang autotiles
  for ground, water and a transition), one town building kit (floor, wall, roof, door, window,
  stairs), one dungeon interior set, one landmark set piece, and the era's sky layer. Section 2
  gives the motifs and palette briefs; the Prompt templates tab has the PixelLab prompts
  per era.

  Open gaps: Chrono Trigger's cliff and stair conventions and its in-location day/night swaps
  are not documented; only the overworld 600/1000 A.D. swap is confirmed.


  7. Battle presentation and signature effects
  Chrono Trigger's battles are a state inside the field scene, not a scene load: a scripted
  event locks exploration, eases the camera to an anchor, runs the party to preset spots and
  starts the ATB timers, all on the same map art (Data Crystal event tricks). Build it the
  same way in Godot and the "no transition" feel comes for free.

  The encounter sequence (ROM event script, in order). ExploreModeOff → move party →
  move enemy sprites → scroll screen to an upper-left tile → Battle → remove trigger object
  → ExploreModeOn. Triggers are a tile object, touching a visible enemy, or a coordinate-
  region loop; ambush variants load the enemy, place it, then start. Enemies wander during
  the fight and may bunch or line up; the party cannot reposition, so waiting for clusters is
  an incentive rather than a rule (wurb.com). Hiromichi Tanaka credited the 32 Mbit
  cartridge with making this possible after the SFC disk drive was cancelled, and
  programmer Katsuhisa Higuchi struggled to load animated monsters without slowdown or
  a black screen (Wikipedia).

  ATB 2.0 numbers to copy.


     Parameter       Value in Chrono Trigger                               Source

     Party size      3, no mid-battle swaps                                StrategyWiki




                                                                                          Page 15 of 36
Style breakdown




     Parameter        Value in Chrono Trigger                              Source

     Gauge refill     scales with Speed; Speed cap 16, Haste doubles it    Gamer Corner
                      with a cap of 24

     HP / MP caps     999 / 99; techs cost up to 20 MP                     Gamer Corner

     Techs            8 singles per character; every pair (except Magus)   Gamer Corner
                      learns 3 Dual Techs; combos appear automatically
                      when all partners' gauges are full

     Modes            Active (enemies act while you browse) or Wait        Caves of Narshe
                      (gauges pause in item/tech menus), chosen at new
                      game and switchable in Options

     Speed settings   Battle Speed (1 = fastest, faster than a TAS can     SDA KB, TCRF proto
                      input) and a separate Message Speed; gauge
                      layout option; cursor-memory options

     After battle     fallen members revive at 1 HP; no random battles,    StrategyWiki
                      none on the world map


  Techs are sync-driven scripts, not fixed timelines. The ROM's tech animation opcodes
  are: load/hide/show sprite, slide sprite, send to target, teleport to coordinates, four speed
  tiers (slower/slow/fast/faster), pause, wait until a section or subsection mark is hit,
  palette switch/morph, screen colour change and reset, shake sprite N times at speed S,
  play weapon sound, and a "super command" cutscene for techs like Cyclone (Data Crystal
  tech docs). Because participants wait on marks rather than frame counts, Dual and Triple
  Techs line up no matter how far each character ran. Targeting shapes are: one enemy, all
  enemies, area around a target, line from the user through the target, horizontal line, area
  around self, one ally, all allies, fallen allies. Each tech's properties fit in 12 bytes: type,
  power, hit rate, status. Battle planner Toshiaki Suzuki said combined techs grew out of the
  fun of individual animations; Yuji Horii coined the term renkei (shmuplations 1995
  interviews).

  How to build it in Godot: one BattleState node under the field scene; a TechScript
  resource that is a list of those opcodes; run each participant as a coroutine ( await ) with
  named sync points; a TargetShape enum for the nine shapes above; a hit = palette flash
  on the victim plus a 2–4 px shake plus an 8 px bitmap damage number (the original's
  number colour coding was not documented in any source reached; white damage and
  green healing is a safe default). Target cursors are gloved hands; status auras are green
  Protect, yellow Barrier, red Haste, white Slow (ArrPeeGeeZ).



                                                                                           Page 16 of 36
Style breakdown




  Later versions worth knowing. The DS (2008) added a bottom-screen tappable battle
  menu with enemy HP meters and a Classic mode that keeps the SNES top screen;
  element names became icons (Chrono Compendium). The 2018 Steam release shipped a
  mobile UI and patched in an "original look" battle UI on 16 May 2018 after complaints (PC
  Gamer). Lesson: players will judge your HUD against the SNES one.

  Signature effects and transitions. Every big moment in the original is a Mode 7 scene:
  opening credits, bike race, three wormhole lengths (long for the first trip to 600 A.D.,
  short, very short) plus a black-strobing variant for Lavos's core, Lavos hitting the planet,
  the Epoch ramming Lavos, and the ending credits with fireworks (Data Crystal Mode 7
  scenes). In the prototype, time travel was a plain fade to white (TCRF). Ambient effects
  are event opcodes: a four-step fade from black, a two-step white flash for lightning, a
  Darken command that also ducks the music, a draw-geometry-plus-brighten command, a
  "wobble" flag for confusion, scroll locks of at least one screen, and wind or conveyor tile
  properties (Data Crystal event tricks). Sky gradients used HDMA, which rewrites PPU
  registers once per scanline (Data Crystal HDMA).


     Effect                Original construction                Modern recipe for Chrono Time
                                                                Break

     Time gate             on-map portal sprite with            sphere sprite + palette-cycle
                           palette cycling, white fade, full-   shader, 0.5 s white fade, UV-
                           screen Mode 7 tunnel in three        scrolling cylinder tunnel with
                           lengths, strobing climax             bloom; tiers of about 4 s / 2 s / 1 s
                           variant, looping warp SFX            and a 1-frame white strobe
                                                                variant; pitch-rising loop SFX (the
                                                                GLSL time-gate repo in the Fan
                                                                projects tab is a ready reference)

     World map and         a three-layer Mode 1 tilemap         perspective camera pitched 20–
     Epoch flight          (96×64 tiles, clouds on the top      30° over a flat plane, 1-D gradient
                           layer) under an HDMA sky             texture sampled by screen Y for
                           gradient, not Mode 7; Mode 7         the sky, horizon fog, wings as a
                           appears only in the warp and         sprite state flag
                           crash scenes; era-name pop-up
                           box

     Scene fades           4-step fade to black, 2-step         CanvasModulate or a full-screen
                           white flash, Darken with music       ColorRect tween with 4 discrete
                           duck                                 steps so it still reads as 16-bit




                                                                                                Page 17 of 36
Style breakdown




     Effect                     Original construction              Modern recipe for Chrono Time
                                                                   Break

     Confusion / drugged        sinusoidal wobble via two RAM      full-screen shader with sin(y × k
     state                      flags                              + t) UV offset

     Weather (rain, fog,        known to exist; parameters not     additive particle layers plus the
     ash, lightning)            documented in any source           2-step white flash; prototype
                                reached                            from the unused ambient set
                                                                   (drips, leaves, dust, twinkle)
                                                                   noted by TCRF

     Lavos                      spiky shell that mimics earlier    your final boss should escalate
                                bosses, then two inner             the same way: a shell form, then
                                humanoid forms; reads as kaiju,    reveals
                                not amorphous horror
                                (Wikipedia)


  Open gaps: no source reached gives attack or tech frame counts, the exact ATB fill
  formula, the results-screen layout, or weather layer parameters; Chrono Compendium's
  mechanics pages block automated reading, so check them by hand.


  8. UI, menus, fonts and text boxes
  The Chrono Trigger interface is two bitmap fonts on an 8 px grid, a bordered window
  whose fill colour the player picks, vertical command lists, and a gloved-hand cursor.
  Recreate the system, not the glyphs: the best fan font is personal-use only.


     Element               What the original does                 Spec for Chrono Time Break

     Fonts                 two bitmap fonts: an 8 px face for     draw your own 8 px fixed-width
                           names and stats and a 16 px            numerals/caps and a 16 px-tall
                           proportional face for dialogue;        proportional dialogue face; keep
                           item, monster and tech names are       the 10-character cap as a design
                           capped at 10 characters (Bisqwit,      constraint (it forces punchy
                           Chronotools)                           names)




                                                                                                 Page 18 of 36
Style breakdown




     Element          What the original does                 Spec for Chrono Time Break

     Window style     gradient-filled window with a light    9-slice window: 2-step vertical
                      border, colour and pattern             gradient fill, 1 px light inner border,
                      selectable in Options; a Steam         1 px dark outer outline; ship 8
                      forum post says the SNES offered       player-selectable themes (blue
                      8 colours and that the Steam port      default, grey, green and others)
                      removed the option (grey only)
                      (Steam discussion)

     Options layout   prototype had the background           two-column options grid; include
                      colour option at the top; final        Battle Mode, Battle Speed,
                      arranges options as two columns        Message Speed, gauge layout,
                      of five (TCRF)                         cursor memory, window theme

     Battle HUD       Attack / Tech / Item per character     vertical command list, name + HP +
                      (Tech reads Combo when partners        MP + gauge per character in one
                      are ready); HP/MP beside the           strip, gauge position as an option
                      command menu at top or bottom;
                      ATB gauge position varies by
                      version; enemy gauges hidden
                      (ArrPeeGeeZ)

     Cursor and       gloved-hand target cursor; status      one hand-cursor sprite with a 2-
     feedback         auras green Protect, yellow Barrier,   frame bob; aura ring shader keyed
                      red Haste, white Slow                  to the same four colours

     Main menu        sections for stats and equipment,      character panels with portrait,
                      items, techs, options, party order,    name, level, HP/MP down the left;
                      save (world map and save points        sub-menus open to the right
                      only); DS adds a bestiary (Caves of
                      Narshe)

     Dialogue         choices appear in a small window       bottom text box, 3 lines of the 16 px
                      at the bottom with a D-pad cursor;     face, choice window stacked above
                      shoulder buttons page the roster       it
                      (wurb.com)




                                                                                                Page 19 of 36
Style breakdown




     Element          What the original does                Spec for Chrono Time Break

     DS / Steam       DS text is smaller and element        keep text at SNES scale (16 px ×
     changes          names became icons; Steam             integer zoom); offer the theme
                      players immediately modded grey,      switch from day one
                      blue and green menus and a font
                      patcher that accepts any font
                      renamed "Chrono" (CT Modding
                      group)


  Fonts you can and cannot use. ChronoType by Caveras recreates the 16 px dialogue face
  with about 1,003 glyphs including kana, Cyrillic and Greek, and should be used at multiples
  of 16 pt with anti-aliasing off, but its licence is free for personal use only, with commercial
  use by arrangement (DaFont). It is fine as a placeholder in builds you do not sell; before
  release, replace it with your own glyph set drawn to the same metrics. No Chrono-specific
  UI kit exists on itch.io; the generic pixel UI packs there are not in this style.

  Menu rules that make it read as Chrono. Vertical lists scan better than horizontal ones;
  colour is a warning, not a category; keep it simple (Yanfly). Every window sits on the 8 px
  grid, text never anti-aliases, and the window colour is the only decoration.

  Open gaps: the exact 8 window colours, the border pixel pattern, number colour coding,
  the item icon set and the name-entry and shop layouts were not documented in any
  source reached; capture them from your own copy of the game when you want them
  exact.


  9. PixelLab workflow, step by step
  The reliable way to get a Chrono-consistent cast out of PixelLab is to lock three things and
  never vary them: one hex palette forced on every pixel, one approved south-facing anchor
  sprite reused as the style reference, and one canvas size and view per asset class.
  Everything below is verified against PixelLab's live docs, API spec and plan feed as of 1
  November 2026. Your plan, Tier 3 Pixel Architect, is $50 a month for 10,000 generations
  with 20 concurrent jobs, 512×512 canvases and inpainting, and commercial use on every
  tier (plan feed, terms). One naming note: there is no product called "PixelLab v3"; v3 is the
  model family behind character creation, rotation and animation, alongside pixen, pixflux,
  bitforge, Pro and Pro Flash (API spec).




                                                                                          Page 20 of 36
Style breakdown




  Step 1. Fix the view and size per asset class before generating anything. PixelLab's view
  values are side, low top-down (about 20° pitch) and high top-down (about 35°); isometric
  and oblique are projection flags, not views, and the docs call all of these "weakly guiding"
  compared with an init image (camera options, projection). For an HD-2D build the camera
  does the projection, so your characters should be low top-down billboards and your
  ground should be flat textures on 3D geometry; isometric tiles bake a 2:1 projection that
  will fight a pitched 3D camera, so keep the isometric sets for a 2D iso spin-off or drop
  them.


     Asset class        Canvas        View      Tool                            Cost at your
                                                                                tier

     Playable           48×64 or      low       Create S-XL (Pro) for the       anchor 10 gens;
     characters and     64×64         top-      anchor, then                    8 directions 1
     named NPCs                       down       create_character v3            gen
                                                from that reference

     Crowd NPCs         32×48         low       create_character v3             2 gens
                                      top-      from text
                                      down

     Bosses and large   128×128       low       create_character v3 or          2 gens (v3)
     enemies                          top-      Pro Flash
                                      down

     Portraits for      96×96         side      Create S-XL (Pro) with the      10 gens, 4
     dialogue                                   character's sprite as style     variants
                                                image

     Ground and         16 or 32 px   high      Create tileset (standard 1      1 / 15 gens
     water autotiles                  top-      gen for drafts, Pro 15 gens
                                      down      for finals)

     Walls, floors,     32 px         high      Create tiles (Pro): Building,   10–15 gens
     roofs, paths                     top-      Paths, Tiles types
                                      down

     Set pieces and     128×128       high      Create map (pixflux) +          1 gen per paint
     interiors          map           top-      Inpaint v3
                        canvas        down




                                                                                              Page 21 of 36
Style breakdown




     Asset class       Canvas        View       Tool                          Cost at your
                                                                              tier

     Tech effects      up to 512     n/a        VFX generator                 varies
                       px, 32                   ( vfx_workbench over
                       frames                   MCP)

     Window frames,    16–64 px      n/a        Create UI elements (Pro)      10 gens
     cursors, icons


  Costs are from the MCP docs and the per-tool pages; Pro tools charge 10 generations at
  43–64 px and 10 at 86–128 px, 15 or 25 at the sizes between and above (consistent style).

  Step 2. Build the style bible first (one afternoon). Pick the project palette on Lospec:
  Jehkoba64 and Z64 are tagged SNES and JRPG, Realm of Esa came from a JRPG engine,
  DHARM32 gives a 15-bit feel; Apollo and Resurrect 64 read as modern HD-2D ramps,
  Endesga 64 is more saturated than Chrono Trigger's muted fields, Sweetie 16 is too small
  for a cast (Lospec SNES tag, JRPG tag). Then generate the hero with Create S-XL (Pro) at
  64×64: Color Palette set to the Lospec link with Max Colors 24–32, No Background on, a
  fixed seed, outline selective outline , shading basic or medium , detail medium
  detail (Create S-XL Pro, outline, shading). Iterate with Inpaint v3 and init-image strength
  600–900 for touch-ups, 400–600 for variations (init image). When one frame is right, run
  Reduce colors to the project palette with dithering off (Reduce colors). That sprite is now
  the anchor for every other character.

  Step 3. Prompt vocabulary for the Chrono look. Describe the style, not the game: "16-bit
  JRPG field sprite, SNES era, large head about one third of height, big expressive eyes,
  spiky hair silhouette, flat cel shading with one light from upper left, selective dark-
  coloured outline, two main costume colours plus one accent, standing, south-facing,
  transparent background". Put era cues in the description ("medieval cloth and leather",
  "cracked future armour with exposed cables"), keep locations out of character prompts,
  and use the negative description for "blur, gradient, anti-aliasing, soft shading, photo, 3D
  render". Animation prompts describe movement only; the docs say to avoid
  environmental details there (guidance options). Never put a Square Enix character name
  in a prompt; section 14 explains why.

  Step 4. Cast and rotations. Create each character with create_character in v3 mode
  from a south-facing reference (your anchor-style sprite), n_directions 8, view low top-
  down, template mannequin; v3 from reference at 64×64 costs 1 generation (MCP docs).
  For a cast-wide look use Pro mode with style_character_id pointing at the hero, or a



                                                                                         Page 22 of 36
Style breakdown




  Pro Flash style_image anchor that fits inside the canvas; outfit variants are
   create_character_state with color_palette_from_reference so armour changes
  keep the palette. Rotation errors accumulate when you chain 45° steps, so generate all
  seven directions from the south sprite and fix a bad one by inpainting or mirroring its
  good opposite (rotating a character). Upload nothing that has been upscaled; run it
  through /unzoom first, because upscaled pixel art confuses every model.

  Step 5. Animations. Template animations cost 1 generation per direction up to about 92 px
  and have fixed frame counts: walking-4-frames 4, walking 6, breathing-idle 4,
   running-6-frames 6, cross-punch 6, high-kick 7, taking-punch 6 (use it for hurt),
   falling-back-death 7 then getting-up 5, fireball 6 (use it for casting), fight-
  stance-idle-8-frames 8; the IDs hurt, casting, dashing and shooting do not exist (MCP
  docs). Set ai_freedom to 0 for rigid, consistent template motion. Custom moves use v3
  (4–16 even frames, keep_first_frame ) or PixMiniMax (4–40 frames); skeleton-v3 poses a
  template onto the character for steadier identity at 2–4 generations per direction
  (animate with skeleton). Field set per character: walk, idle, run in 8 directions. Battle set:
  fight idle, attack, hurt, death, cast, in east only (mirror for west). Budget: one hero at 64 px
  with 8 directions and six template animations is about 49 generations, so a 30-character
  cast with full sets fits inside one month of your 10,000.

  Step 6. Terrain. Create tileset makes two-terrain Wang corner sets of 16 tiles (25 when
   transition_size is above 0.5) at 16 or 32 px, 64 px on Pro, exported as Wang, dual-grid
  15-tile or 3×3 layouts; chain biomes with lower_base_tile_id (ocean → beach → grass →
  forest) and force the palette with target_palette in Pro mode (Create tileset). The MCP
  metadata lists each tile's NW/NE/SW/SE corner as lower, upper or transition, which maps
  directly onto Godot 4's "Match Corners" terrain mode: one TileSetAtlasSource at 16 px,
  terrain set 0, terrains lower and upper, peering bits copied from the corners (Godot
  TileSets). Create tiles (Pro) adds numbered variation lists, 18-configuration path autotiles,
  hex and isometric sets, and building kits with floor, walls one to three high, doorways,
  pillars and stairs (Create tiles Pro). For the HD-2D GridMap, use Create texture for
  seamless ground and wall textures and the building kit for wall and roof faces; for the 2D
  fallback, the Wang sets drop straight into a TileMapLayer .

  Step 7. Automate it. The REST API is bearer-token at https://api.pixellab.ai/v2 with
  about 100 endpoints and async jobs polled at /background-jobs/{id} ; the Python SDK is
   pip install pixellab (pixellab-python). The remote MCP server needs nothing
  installed: claude mcp add pixellab https://api.pixellab.ai/mcp -t http -H
  "Authorization: Bearer YOUR_SECRET" , with tools for characters, states, animations,
  tilesets, objects, inpainting, UI assets, VFX and a Godot sandbox (pixellab.ai/mcp).



                                                                                            Page 23 of 36
Style breakdown




  Exports: /characters/{id}/spritesheet returns a uniform-grid PNG plus a JSON layout
  (row 0 rotations, one row per animation and direction, pivot at cell centre), and
   /characters/{id}/zip returns per-frame PNGs with keypoint metadata; there is no
  .aseprite export from the API, only from the Aseprite extension, which needs Aseprite
  1.3.7 or newer (installation). API prices are per call in USD credits: pixen about $0.007–
  0.017 per image, create-character-v3 about $0.041–0.045, tilesets about $0.008–0.01,
  Pro tools $0.08 to $0.15 by size (API page).

  Limits to plan around. Outline, shading, detail, view and direction are hints; init images
  and palettes are the only strong controls. Expect manual cleanup in Aseprite on every
  output, especially hands, feet and the 4-frame walk. The canvas size changes the result,
  so never resize a prompt mid-cast. PixelLab publishes no changelog and no numeric rate
  limits, so pin the model names you used in your asset manifest. All tiers allow commercial
  use; the only restriction is training other models on the outputs (FAQ). Steam allows AI-
  made assets with disclosure, so keep a log of which assets were generated.


  10. Complementary and alternative tools
  PixelLab plus Aseprite is the whole pipeline; nothing else on the market combines
  purpose-built pixel models, animation and Wang tilesets except Retro Diffusion, which is
  worth keeping as a second opinion for maps. Prices and versions below were checked on 1
  November 2026.


    Tool          What it does                 Price            Animation       Tilesets         Fit for a 16-bit
                                                                                                 JRPG

    Retro         pixel-native models; API     web from         4–16 frames,    Wang-style       strong second
    Diffusion     styles include               $0.03 an         32–256 px;      16–32 px, tile   source for
                  topdown_map,                 image; API RD    walk, idle,     variations,      concept maps
                  topdown_asset,               Pro $0.18, RD    jump, attack,   scene            and props
                  isometric,                   Plus about       8-direction     objects
                  character_turnaround,        $0.06, RD Fast   rotation
                  ui_element                   about $0.03
                                               per image

    Retro         local generation inside      $65 one-time     none            tiling           good for
    Diffusion     Aseprite with palettes,      (LITE $20);      (animation is   modifier         cleanup
    Aseprite      Palettize, style transfer,   needs a 4 GB     web-only)                        passes
    extension     tiling                       GPU and                                           without
                                               Python 3.11                                       leaving
                                                                                                 Aseprite




                                                                                                            Page 24 of 36
Style breakdown




    Tool           What it does                Price             Animation          Tilesets     Fit for a 16-bit
                                                                                                 JRPG

    Sprite-AI      text-to-sprite with an      $8 / $24 / $50    yes                none         fine for one-off
    (you already   editor and text-            for 100 / 400 /                                   props and NPC
    use it)        described animation         900 tokens; 1                                     drafts; no
                                               token per                                         palette lock or
                                               sprite, 14–20                                     terrain
                                               per animation

    Scenario       train your own LoRA on    $15 / $45 / $75 a   via hosted RD      via hosted   useful only if
                   10–30 style images; hosts month               models             RD models    you want a
                   Retro Diffusion models;                                                       custom-
                   Pixelate post-process                                                         trained style
                                                                                                 model

    Rosebud AI     2D assets and sprite        credits, prices   idle, walk,        none         occasional use
    (formerly      sheets with JSON            not listed        attack, jump
    PixelVibe)

    Sprixen        per-project Style Lock   $10 a month          up to 96           none         cheap backup
                   with palette             for 200              frames                          for
                   enforcement, 8-direction generations                                          consistency
                   turnarounds                                                                   tests

    SpriteCook     character creator plus      from $8 a         idle, walk, run,   yes          small-budget
                   connecting terrain tiles,   month             attack, jump                    alternative,
                   MCP and API                                                                   less control
                                                                                                 than PixelLab

    Leonardo.ai    general image model         $12 / $30 / $60   no                 no           concept art
                   with a pixel preset         a month                                           only; outputs
                                                                                                 need
                                                                                                 downscale and
                                                                                                 palette
                                                                                                 cleanup


  Manual tools you need regardless. Aseprite is $19.99 on Steam, version 1.3.18.6 (22
  September 2026), with tilemap layers, sprite-sheet plus JSON export, a Lua API and a CLI;
  it is where every PixelLab output gets its final palette pass and pivot check (Aseprite
  release notes). Free alternatives: Pixelorama (MIT, v1.1.9, Lospec palette import, tilemap
  layers, APNG and sheet export; it is also PixelLab's in-browser editor) and LibreSprite
  (GPLv2). PixelOver ($19.99 one-time) turns images and 3D renders into pixel art with
  bones, IK and palette indexing and contains no generative AI, which makes it a good tool
  for mechanical objects like the time machine. Laigter generates normal maps from sprites
  for the lighting route in section 12.

  Recommended pipeline.



                                                                                                           Page 25 of 36
Style breakdown




   1. Style bible in PixelLab: palette, hero anchor, three test tiles, one battle effect. Freeze
       them.
   2. Cast in PixelLab over the API or MCP so every character uses the same size, view,
      palette and anchor; log model names and seeds per asset.
   3. Cleanup in Aseprite: indexed mode on the project palette, fix hands and feet, set
       pivots, tag animations ( idle_down , walk_left ), export sheet plus JSON.
   4. Terrain in PixelLab (Wang sets and building kits), seams checked in Aseprite's tilemap
      layer, then into Godot as Match Corners terrains or GridMap textures.
   5. Maps laid out in LDtk or Tiled and imported with the importers in section 12.
   6. Effects from the PixelLab VFX generator at 32 frames, quantized to the palette, with an
      OmniLight3D attached in Godot.
   7. A manifest ( assets/MANIFEST.csv ) that records tool, model, seed, prompt and palette
       for every file, which both keeps the style auditable and satisfies Steam's AI disclosure.

  Sources: PixelLab API page, Retro Diffusion API examples, Scenario on Retro Diffusion
  models, Pixelorama, LibreSprite, PixelOver, and a September 2026 directory comparison
  at Cinevva, which is partly vendor-written; no independent head-to-head quality
  benchmark for a 16-bit JRPG look exists.


  11. Audio direction
  The Chrono sound is one main-theme leitmotif restated in a different instrument palette
  per era, played through an 8-voice, 64 KB, 32 kHz sample chip whose compression and
  echo give the softness people remember. You can recreate that softness with free tools
  and keep the composition original.

  Mitsuda's approach. He aimed for music that fitted no single genre, discussed each scene
  with Masato Kato before writing, took about a month and a half to find the voice, and used
  leitmotifs of the main theme to hold the score together; he wrote many sad pieces
  because the theme word was namida, tears, and avoided flashy music in favour of tones
  and textures (shmuplations 1995 interviews, Wikipedia). Nobuo Uematsu finished 10
  tracks after Mitsuda fell ill; the OST runs 64 tracks over 2:39:52. Yoshitaka Hirota built the
  sound effects by modulating one waveform with another, from sines and noise (RPGFan).




                                                                                            Page 26 of 36
Style breakdown




     Era                  Instrument palette in the original   Direction for your era
                          score

     1000 A.D.            flute, woodwinds, strings;           bright, major, mid-tempo; the main
     (present)            morning pieces with fireworks        theme lives here
                          and seagull effects

     600 A.D. (middle     piano, strings, organ in the         sacred and martial; organ for
     ages)                cathedral                            churches, snare for the war front

     2300 A.D.            sparse synth, wind effects, jazzy    thin textures, long reverb, one
     (future)             bass, xylophone melodies             melodic instrument over drones

     65,000,000 B.C.      essentially percussion only          drums, shouts, no harmony
                                                               instruments

     12,000 B.C. (Zeal)   steel drum and zither, bells and     otherworldly beauty with a threat
                          woodwinds, piano with ominous        underneath
                          percussion

     Finale               the villain's theme woven into the   your antagonist motif should be
                          main theme                           able to harmonise with the main
                                                               theme


  Source for the era palettes: a track-by-track review at Square Enix Music Online.

  The hardware signature, in numbers. 8 voices, 16-bit stereo at a nominal 32,000 Hz, 64 KiB
  of audio RAM, 4-point Gaussian interpolation that rolls off highs (snes.nesdev.org S-DSP).
  Samples are BRR: 9 bytes per 16 samples, about 3.6:1 against 16-bit PCM, with loop points
  on 16-sample boundaries (BRR samples). Echo delay runs in 16 ms steps from 0 to 240 ms,
  each step costing 2 KB of that RAM, shaped by an 8-tap FIR filter (nesdev forum). The
  game's driver exposed per-effect pan, volume fades, tempo and pitch slides up to about 7
  s, and an 8-channel disable mask (Data Crystal music commands).

  Toolchain for an original score with that sound (current as of November 2026).

   1. Write in any DAW, then voice it through C700, a free open-source SPC700 soft-sampler
      plug-in with BRR import, FIR settings and SPC export, 128 sample slots and the same 64
       KB limit (picopicose, BotB Lyceum).
   2. Keep the 8-voice ceiling and reserve 2 voices for sound effects so music ducks the way
      the original did; the SNES GSS workflow also suggests mono 16 kHz samples and
       leaving 600–1,200 bytes free (Mega Cat Studios).




                                                                                             Page 27 of 36
Style breakdown




   3. For reverb, Impact Soundworks' SNESVerb emulates the delay-line echo with
      feedback, time, width and 32/22/11 kHz downsampling and has been superseded by
       their GameVerb (KVR). Furnace tracker is the free alternative for authoring directly on
       the chip model, with ADSR ranges attack 0–F, decay 0–7, sustain 0–7, release 00–1F.
   4. If you do not want strict hardware limits, the shortcut is: 32 kHz render, a low-pass
       around 8–10 kHz, one global echo of 100–240 ms with its own low-pass, applied per
       instrument rather than on the master.

  Sound effects. The original's effect IDs include a cursor tick, an invalid-choice buzz, three
  menu-select sounds, HP and MP recovery chimes, a save-point tone, a run-away sound,
  and looping drones for the pendant, portal, Telepod and Epoch warp (Data Crystal sound
  effects). Design a confirm / cancel / invalid triad with clearly different pitches, build
  impacts from a sine thump plus filtered noise, and give the time gate a looping drone with
  a rising pitch slide.

  Chrono Cross, if you want its flavour. Mitsuda shifted the same motifs into
  Mediterranean, fado, Celtic and African-percussion colours, with Tomohiko Kira on
  acoustic guitar and Noriko Mitose singing the ending; fretless bass and violin interplay are
  the signature textures (Wikipedia, SEMO review). A modern Chrono-style score can use
  the Trigger chip aesthetic for the past and present and open into Cross-style acoustic
  instrumentation for key emotional scenes.

  For reference on where the lineage is heading: Katsuhisa Higuchi, Chrono Trigger's battle
  programmer, is directing Eternal Anima, a time-travel JRPG announced 9 September 2026
  and due 4 March 2027 (Automaton).

  Open gaps: no primary source lists the original's sample set by instrument name or its
  echo and FIR settings.


  12. Engine, camera and import settings (Godot 4)
  Build Chrono Time Break on Godot 4.7.2, the current stable release (18 August 2026; 4.8 is
  in beta as of 29 October 2026), with the HD-2D architecture below; keep the pure-2D
  architecture as the fallback if sprite jitter in 3D costs you more than the camera tilt is
  worth (Godot releases, Godot blog). Every setting name here comes from the engine's
  class reference, so your build agent can apply them verbatim.

  Architecture A, HD-2D proper. Forward+ renderer; full-resolution 3D scene; the world is a
  GridMap of 1-unit cells with pixel-art textures; characters are AnimatedSprite3D nodes
  billboarded toward a tilted camera; one DirectionalLight3D sun plus an OmniLight3D



                                                                                           Page 28 of 36
Style breakdown




  on every battle effect so sprites cast shadows (the trick Acquire's lead artist called the
  breakthrough on Octopath Traveler, per the Unreal spotlight); WorldEnvironment glow
  and volumetric fog; CameraAttributesPractical near and far depth of field as the tilt-
  shift. Architecture B, retro grid. Render into a 640×360 SubViewport and integer-
  upscale; pixels stay perfect, but DOF and bloom become pixel-sized too.


   Area                    Setting or node                                      Value for Chrono Time Break (architecture A)

   Renderer                rendering/renderer/rendering_method                  forward_plus (DOF, Compositor, volumetric fog
                                                                                and glow levels need Forward+ or Mobile)

   Base size and stretch   display/window/size/viewport_width × height ;        1920×1080; canvas_items / expand (the defaults
                           display/window/stretch/mode / aspect                 for projects created in 4.7; 4.3–4.6 projects default
                                                                                to disabled and must be changed)

   UI pixels               rendering/textures/canvas_textures/default_t         0 Nearest; snap transforms true , leave
                           exture_filter ;                                      snap_2d_vertices_to_pixel false (the docs say
                            rendering/2d/snap/snap_2d_transforms_to_pixe        never both)
                           l

   3D scaling              rendering/scaling_3d/mode / scale                    0 bilinear at 1.0 for HD-2D; the new 5 Nearest
                                                                                mode (4.7) is for architecture B only

   Texture import          Compress > Mode; Mipmaps; Detect 3D >                 Lossless , never VRAM compressed, even in 3D;
                           Compress To                                          mipmaps on for world tiles, off for UI; set Compress
                                                                                To = Lossless before a texture's first 3D use or
                                                                                Detect 3D silently switches it to VRAM Compressed

   Character sprite        AnimatedSprite3D                                     pixel_size = 1/pixels-per-unit (0.0625 at 16 px per
                                                                                metre, 0.03125 at 32); texture_filter 0 Nearest
                                                                                or 2 Nearest with mipmaps (the default is Linear
                                                                                with mipmaps); billboard 2 Fixed-Y with camera
                                                                                pitch clamped, or 1 Enabled; shaded true ;
                                                                                alpha_cut 1 Discard, threshold 0.5; cast shadows
                                                                                on

   Terrain                 GridMap with cell_size (1,1,1) and a MeshLibrary ;   NEAREST_WITH_MIPMAPS on Lossless 16 or 32 px tiles
                           StandardMaterial3D.texture_filter

   Camera                  Camera3D on a SpringArm3D                            pitch about −30°, arm length 6 (the SimpleHD2D
                                                                                reference); perspective with fov 20–35, or
                                                                                 ORTHOGONAL with size = visible height ÷ pixels-
                                                                                per-unit; snap an orthographic camera's position to
                                                                                the pixel grid

   Depth of field          Camera3D.attributes =                                far and near enabled; dof_blur_far_distance just
                           CameraAttributesPractical                            past the focus plane (28.43 at arm 6 in SimpleHD2D);
                                                                                 dof_blur_far_transition 3–8; dof_blur_amount
                                                                                0.05–0.1; project bokeh shape Hexagon, quality 2

   True tilt-shift         Compositor → CompositorEffect at                     optional compute pass that blurs by screen Y; start
                           EFFECT_CALLBACK_TYPE_POST_TRANSPARENT                from the compute/post_shader demo

   Glow                    Environment                                          glow_enabled , glow_intensity 0.3–0.6,
                                                                                glow_bloom 0.05, glow_hdr_threshold 1.0, levels
                                                                                2–4, rendering/environment/glow/upscale_mode
                                                                                bicubic




                                                                                                                               Page 29 of 36
Style breakdown




   Area                  Setting or node                                Value for Chrono Time Break (architecture A)

   Tonemap and ambient   tonemap_mode ; ambient_light_*                 Filmic or AgX (4.4+); ambient energy above zero so
                                                                        shadows never go black, which is exactly what
                                                                        Acquire did (Unreal Fest East 2018 report)

   Fog                   volumetric_fog_* , fog_sun_scatter             density 0.01–0.05, anisotropy 0.5–0.7,
                                                                        light_volumetric_fog_energy on the sun

   Sun                   DirectionalLight3D                             shadow_enabled , 4-split mode,
                                                                        directional_shadow_max_distance 50–100,
                                                                        shadow_blur 1–3, shadow_opacity 0.7–0.9 (0.72 in
                                                                        SimpleHD2D), light_angular_distance 0.5,
                                                                        rendering/lights_and_shadows/directional_sha
                                                                        dow/size 4096

   Effect lights         OmniLight3D on each tech effect                shadow_enabled , light_size above 0,
                                                                        distance_fade_enabled

   Anti-aliasing         use_debanding ; msaa_3d ; screen_space_aa      debanding on; MSAA 2–4× optional; no FXAA or
                                                                        SMAA, which blur sprites

   Jitter                script                                         keep physics in floats but round each sprite's
                                                                         global_position to multiples of pixel_size
                                                                        every frame; enable 3D physics interpolation (4.4+)



  Sources for the table: the Godot class reference for ProjectSettings, SpriteBase3D,
  CameraAttributesPractical, Environment and Light3D; the multiple resolutions, importing
  images, compositor and 3D rendering limitations guides; and the SimpleHD2D reference
  project.

  Pitfalls that are documented, not theoretical. Sprites in a full-resolution 3D scene jitter
  when X and Y cross pixel boundaries on different frames, and a 4.7.2 thread on exactly
  this setup has no accepted fix beyond mipmaps and snapping (Godot forum). Fixed-Y
  billboards flip when the camera goes near vertical, so clamp pitch to roughly −1.4 to −0.2
  radians (bugnet.io). Billboard shadows are undefined with more than one active camera.
  Transparent sprites mis-sort unless alpha_cut is Discard. CameraAttributesPractical
  does not work on a viewport with transparent_bg . Octopath itself reserves camera
  rotation for scripted battle and event moments because rotated pixel textures showed
  seams (Unreal interview, Octopath II).

  Starting points on GitHub (snapshot 1 November 2026).


     Repo                                           What it gives you                                Godot version

     GSansigolo/SimpleHD2D                          GridMap world, Sprite3D hero,                    4.1, last push
                                                    SpringArm camera, DOF, glow,                     Nov 2023
                                                    shadows; the reference values
                                                    above



                                                                                                                     Page 30 of 36
Style breakdown




     Repo                               What it gives you                  Godot version

     Hybrid 2D 3D Sprite (KavyaJP,      a Hybrid2D3DSprite node with       4.5, listed Feb
     MIT)                               automatic pixel-to-metre scaling   2026
                                        and feet-anchored placement

     Smidle/jeff-studio-scene           HD-2D terrain, procedural towns,   pushed Oct
                                        day/night, weather, pixel sky      2026

     winkidney/hd-2d-godot              per-frame normal maps and          pushed Oct
                                        highlight masks on sprites for     2026
                                        dynamic lighting

     viniciusgerevini/godot-aseprite-   Aseprite tags → animations for     4.x
     wizard                             AnimatedSprite2D/3D and
                                        AnimationPlayer; 1,396 stars

     heygleeson/godot-ldtk-importer,    LDtk and Tiled map import          4.x, both active
     Kiamo2/YATI                                                           Oct 2026


  None of the HD-2D repos implements Compositor tilt-shift or sprite pixel snapping; treat
  SimpleHD2D as a starting scene graph, not a finished pipeline.

  Asset conventions that keep every tool happy. One .aseprite file per character with
  one tag per animation ( idle_down , walk_left , attack_right ), imported by Aseprite
  Wizard to a SpriteFrames resource used by AnimatedSprite3D ; square power-of-two
  cells (32 or 64 px) so pixel_size maths stays exact; durations in milliseconds become
  frames per second automatically (Aseprite Wizard docs). If you choose architecture B,
  640×360 is the documented base: it integer-scales to 720p (2×), 1080p (3×), 1440p (4×)
  and 4K (6×) with no bars.

  The 2D-only alternative. TileMapLayer with Y-sort, Camera2D limits, PointLight2D and
   DirectionalLight2D , LightOccluder2D , CanvasModulate for time of day, and normal
  maps through CanvasTexture (Laigter generates them). Sea of Stars is pure 2D in Unity
  with sun and moon shadows that rotate by time of day (PC Gamer); Chained Echoes is a
  solo seven-year Unity build (Game Developer). HD-2D only pays off for the camera tilt, 3D
  parallax and depth-based DOF; if those are not on your must-have list, the 2D route has
  the mature tooling and none of the sorting or jitter issues.




                                                                                       Page 31 of 36
Style breakdown




  13. Starting-fresh production plan
  Start with a one-week style bible, prove the whole pipeline on a vertical slice before any
  volume work, and only then build the cast and the eras; each phase ends at a gate you can
  test, so the build agent and the asset bot always know what done means.




  production roadmap · 5 phases, 4 gates

  The gates are the point: nothing in phase 3 starts until a stranger can play the slice and the
  sprites stay crisp, and nothing in phase 5 starts until the manifest is full.

  Asset list for the slice and for the first playable.




                                                                                          Page 32 of 36
Style breakdown




     Asset class   Vertical slice             Full first playable        Made with

     Playable      2 (hero plus one           7 Prime characters plus    Prompt templates
     characters    partner), 8 directions,    21 timeline variant        1–3; Legacy cast tab
                   field and battle sets      states

     NPCs          6                          about 40, six per era      Template 4

     Enemies and   4 enemies, 1 boss          about 40 enemies, 7        Template 5
     bosses                                   Severed mirror bosses

     Portraits     2 characters × 6           7 × 6 plus one per         Template 6
                   expressions                variant

     Tilesets      1 exterior Wang set, 1     per era: ground set,       Templates 8–9,
                   interior kit               town kit, dungeon set,     Create texture
                                              one landmark, sky layer

     Maps          1 town, 1 dungeon, 1       as the story bible lists   LDtk or Tiled, then
                   world-map region           them                       GridMap

     Effects       3 techs, 1 time gate       about 30 techs, 3 gate     Template 10
                                              tiers plus strobe,
                                              weather layers

     UI            1 window theme, cursor,    8 themes, icon set, all    Template 11,
                   2 fonts                    menus                      Aseprite

     Music and     1 town theme, 1 battle     1 theme per era, 7         section 11 toolchain
     sound         theme, 6 effects           character motifs, about
                                              40 effects


  How the agents divide it. The asset bot takes every row of the table through the Prompt
  templates tab and writes each file's tool, model, seed, prompt and palette into
   assets/MANIFEST.csv ; the build agent takes sections 7, 8 and 12 as acceptance criteria
  and the Fan projects tab as reference reading for formats and mechanics; your Story,
  Combat and Reference bibles drive phase 4. Review happens at the four gates, not per
  asset.




                                                                                          Page 33 of 36
Style breakdown




  14. Originality and legal guardrails
  An art style cannot be owned, but names, characters, sprites, maps, music and text can,
  and Square Enix has shut down the two most famous Chrono fan projects; so build an
  original game in the Chrono style, give it a release title that does not lean on Square Enix's
  live marks, and keep every asset's provenance on record. This is general information, not
  legal advice; a trademark attorney should check the title before you sell anything.

  The name. Square Enix's CHRONO TRIGGER mark (US serial 74619247, filed 9 January
  1995) and CHRONO CROSS mark (registration 2621722, renewed 2012) are live; the
  Chrono Break marks lapsed in 2003 (US), 2011 (EU) and 2012 (Japan), and no primary
  record of any 2024 renewal exists beyond one anonymous forum post (Justia: Square Co.
  marks, Wikipedia). A lapsed Chrono Break mark does not make the words free: a time-
  travel JRPG in a Toriyama-derived style called "Chrono Time Break" sits next to two live
  marks in the same product category, which is the situation trademark law calls likelihood
  of confusion. Other studios do ship games with Chrono in the title, so the word alone is
  not fatal; the combination of Chrono, a Trigger-like structure and a Trigger-like look is what
  raises the risk. Keep "Chrono Time Break" as the working title, choose a release title
  without Chrono or Trigger, and have the studio name checked too, since "trigger" is also a
  well-known anime studio's name.

  The precedent. Chrono Resurrection, a 3D remake demo of ten scenes, was closed by
  cease-and-desist on 6 September 2004; Crimson Echoes, a ROM-hack sequel about 98
  percent complete, on 8 May 2009 (Wikipedia: Chrono Resurrection, Wikipedia: Crimson
  Echoes). The projects that survive and get praised are original-IP homages: Sakaguchi,
  Horii and Torishima singled out Sea of Stars as looking very much like Chrono Trigger
  (GoNintendo), and Chained Echoes borrowed the on-map enemies and ATB feel without a
  single Square asset.


     Do                                                  Do not

     recreate the style: 3-head sprites, coloured        reuse any ripped sprite, tile, portrait, map
     outlines, era palettes, field battles, ATB 2.0, a   layout, sound or music from the games, even
     Mode 7-style world map                              as a base to trace or inpaint over

     design original characters with their own           ship a red-spiky-haired silent swordsman
     trait combinations                                  with a blue top, or any other recognisable
                                                         cast member under a new name




                                                                                                 Page 34 of 36
Style breakdown




     Do                                             Do not

     write original names for techs, items, eras    reuse Square Enix names, including era titles
     and places                                     and the names of techs, enemies and
                                                    vehicles

     describe the style in prompts (section 9,      type Square Enix character or game names
     Prompt templates tab)                          into a generator prompt or a style-reference
                                                    slot

     draw your own fonts to the 8 px and 16 px      ship the fan ChronoType font, which is
     metrics                                        licensed for personal use only

     study the open-source engines in the Fan       copy code from repositories whose licence
     projects tab for mechanics and formats         does not allow it, or any extracted game data
                                                    they expect you to supply

     keep a manifest of tool, model, seed, prompt   sell AI-made assets without the disclosure
     and palette per asset                          Steam requires


  AI assets. PixelLab's terms give you the copyright in outputs and allow commercial use on
  every tier, with the single restriction that you may not train other models on them (terms);
  Steam allows AI-generated content with disclosure, distinguishing pre-generated assets
  from content generated live (PixelLab FAQ). Keep the manifest from section 10 and you
  can answer that disclosure in one line.

  The fan projects. The second tab audits each repository's licence and whether it contains
  ripped assets; the short version is that native ports and decompilations require you to
  supply your own copy of the game and expose formats and mechanics you may study,
  while anything that ships Square Enix art inside the repo stays out of your project.


  15. Sources
  Pages actually opened for this breakdown, grouped by section; every number in the doc
  links to one of these inline. Chrono Compendium's forum and encyclopedia pages and
  Chrono Wiki's Zeal page refused automated reading, so claims that would have come from
  them are marked as gaps.

  Chrono Break and series history. Wikipedia: Chrono Break · Wikipedia: Chrono (series) ·
  RPGamer, Jan 2004 · Siliconera: Chrono Break and FF Dimensions II · DualShockers:
  Sakaguchi at PAX 2014 · Kotaku: Kitase 2024 · Automaton: 30th anniversary · Nintendo




                                                                                             Page 35 of 36
Style breakdown




  Life: no remake announced · Vice: Harker rumour · Justia: Square Co. trademarks ·
  Wikipedia: Chrono Resurrection · Wikipedia: Crimson Echoes

  Design lineage and art. Wikipedia: Chrono Trigger · Wikipedia: Characters of Chrono
  Trigger · shmuplations: 1995 developer interviews and part 2 · GlitterBerri: early sketches ·
  Kanzenshuu: Toriyama interviews · Zimmerit: Toriyama mechanical design · Brandon James
  Greer sprite tutorial (transcript) · humbird0 on Toriyama and the sprites · Chrono Wiki era
  pages · Wikipedia: Chrono Cross · Siliconera: Cross remaster backgrounds

  Technical specs. Fullsnes · SNESdev wiki: PPU, OAM, colour math, uncommon modes ·
  GitExl/CTViewer · TemplarServant/BelthasarProject · Data Crystal: Chrono Trigger, Mode 7
  scenes, tech documentation, event tricks, sound effects · TCRF prototype differences ·
  Bahamonde: graphics and sprites · Saint11 articles · Pixelblog: projections · Lospec:
  outlines · Pixnote: shading

  Battle, UI and audio. StrategyWiki: gameplay · Gamer Corner: systems · Caves of Narshe
  walkthrough · Bisqwit: Chronotools · DaFont: ChronoType · PC Gamer: Steam battle UI
  patch · Wikipedia: Music of Chrono Trigger · Square Enix Music Online review · RPGFan:
  Hirota interview · SNESdev: S-DSP, BRR · C700 · SNESVerb · Automaton: Eternal Anima

  HD-2D and Godot. Wikipedia: HD-2D · Unreal spotlight: Octopath Traveler · Unreal
  interview: Octopath Traveler II · Automaton: Unreal Fest East 2018 · CGWORLD: sprite
  specs · Siliconera: HD-2D troubles · Nintendo Life: Triangle Strategy producers · Godot
  releases · Godot class reference (master) · Godot docs: multiple resolutions, importing
  images, compositor · SimpleHD2D · Aseprite Wizard · Godot forum: sprite jitter in 2.5D

  PixelLab and tools. PixelLab docs · PixelLab API page · API spec · MCP docs · plan feed ·
  terms · FAQ · Retro Diffusion · Sprite-AI · Scenario pricing · Aseprite release notes · Lospec
  palette tags: SNES · Cinevva comparison, Sep 2026

  The fan-project repositories, hacks and archives have their own source list in the Fan
  projects & code tab.




                                                                                          Page 36 of 36
```
