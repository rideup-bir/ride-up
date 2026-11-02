# The scene rulebook

The painted view of the Bir landing ground at the top of the home screen is alive: gliders, a tandem landing, cows,
people, traffic, lights. This file lists **everything that lives in it**, **what each thing does**, and **what decides
it**. Everything in the app follows this file. Change the file first, then the code.

It also makes a future change of style possible: a new set of pictures can replace the current ones as long as each
keeps the same place, size, facing, frames and rules.

---

## 1. Ground rules for every piece

1. **To scale.** Sizes come from the painting's own perspective. At the road (about 100 m away) one metre is about
   12 picture units. Something `d` metres away stands on the ground at `y = 560 + 2500 / d` and is scaled
   `1200 / d` units a metre.
2. **Depth = where it stands.** Anything on the ground is drawn in front of things that stand further back. Its depth
   (`z-index`) is the `y` of its feet. The road and its traffic are at about 570; the field is in front of that.
3. **Real movement.** Anything that walks, runs or pedals shows drawn frames (legs move). Nothing slides as a still.
4. **Faces the way it moves.** Each picture is drawn facing one way (see the cast); the code flips it to face the way
   it travels. A mover must never travel one way while facing the other.
5. **Lit by the time of day.** Every piece takes the light of the painting behind it (the `lit` filter): darker and
   bluer at night, warmer at golden hour.
6. **Calm.** At most 9 moving things on the road and field at once. Cows are the slowest, people quicker, vehicles
   quickest.
7. **Only while seen.** New movers start only while the scene is on screen, on the home page, with the app open.
   Phones that ask for less motion get the painting, the lights and resting cows only.
8. **Rules decide, chance only picks.** The rules fix where, when, how fast and how often. Chance is used for one
   thing only: picking *which* allowed option comes next (for example which car model, which direction), so the
   scene doesn't repeat itself like a loop. Section 8 lists every place chance is used.

---

## 2. Coordinates

The painting is **2436 × 866 units** (the files are drawn 1.5 times larger). Every position in this file uses those
units: `x` from the left edge (snow peaks, north-west) to the right edge (the café row and taxi stand, south-east), `y`
from the top. The painting looks north-east (`VIEW_FACING` 45°) with the sun always behind the viewer.

Key marks:

| Mark | x | y | Note |
|---|---|---|---|
| Banner centre | 1450 | | Billing take-off and the H café (Charlie's) |
| Windsock pole | 1489 | 523 | on the H café's roof |
| Road | 0 → 2120 | 602 → 557 | the far edge of the field (`ROAD_PTS`, `roadY(x)`); at the taxi stand (`ROAD_END` 2120) it bends away behind the cafés |
| Tandem landing point | 1720 | 600 | 62 m away |
| Shacks behind the road | 1505–1900 | ~560 | at Charlie's depth: the house by Charlie's (its 2 umbrella tables in front), Himani (1777, 2 umbrellas on its left), a small shack (1889) |
| Taxi stand | 2084 + | ~559 | on the road edge above the parking ramp (the low concrete slab, 2045–2190), in front of the café cluster (1935–2400) |

---

## 3. What the scene reads (the situation)

| Input | Where from | Values |
|---|---|---|
| **Time** | Bir clock (IST), `sceneMins()` | minutes after midnight. `?t=1730` on a test copy shows 5:30 pm |
| **Weather at the landing** | Open-Meteo, now (`weatherMood`) | clear · cloudy · overcast · rain · storm · snow · fog |
| **Weather at launch** | Open-Meteo, now | fog or any rain/snow at launch stops flying |
| **Wind** | landing, now | direction: windsock, clouds, landings and kiting all follow it; speed: windsock droop |
| **Season** | date | the no-fly season (15 July–15 September) stops flying; the paintings are autumn ones all year for now |
| **Live rides** | the app | one car at the taxi stand per ride that's on (up to 3) |

**Flying is on** when: it's 7:00–18:00, the landing isn't wet or foggy, launch isn't wet or in cloud, and it isn't the
no-fly season. Even then, overcast skies cut it to 2 gliders.

---

## 4. The day, block by block

| Time | Painting | What changes |
|---|---|---|
| 0:00–5:30 | night | cafés dark after 23:00, only the odd car (every ~150 s); one car stays parked by Charlie's |
| 5:30–6:40 | night → dawn | cars parked by Charlie's (no flying yet); early traffic (car every ~70 s, a walker every ~120 s) |
| 6:40–7:50 | dawn → day | mist at the foot of the ridge |
| 7:00 | | **flying starts** (if the weather allows): parked cars leave, the flying crew comes out |
| 8:00–17:30 | day | ground handling: the kiting pilot is out (when dry) |
| 9:00–12:30 | day | **busy flying block**: 12 gliders, a tandem lands every 110–220 s; two people sit on the grass |
| 12:30–14:00 | day | **lunch**: 4 gliders, a tandem every 300–500 s, no launch practice |
| 14:00–17:00 | day | **busy flying block** again |
| 16:00–17:45 | day → golden | warm light, cloud shadows soften |
| 18:00 | golden | **flying ends**: crew leaves, cars park by Charlie's again |
| 18:00–23:00 | golden → night | **evening**: a vehicle every ~13 s, a walker every ~5 s; from 18:30 groups sit out on the grass |
| from dusk | night | headlights and tail lights on; café windows, H café bulbs and village lights glow |
| 23:00 | night | windows go dark, groups leave, traffic thins to the odd car |

(Exact edges: painting keys `PAINT_KEYS`; flying and blocks in `updatePaint` and `glidersUp`; traffic in `lifeRate`.)

---

## 5. Layers, back to front

| # | Layer | Holds | Moves |
|---|---|---|---|
| 1 | Sky (`lay-far`) | the painting (dawn, day, golden, night cross-fade) | colour only |
| 2 | High cloud (`lay-hi`) | 3 thin wisps, behind the peaks | drift with the wind, 8–13 minutes across |
| 3 | Mountains (`lay-mtn`) | the ridge, cut along the true skyline | cloud shadows slide over (sunny or cloudy only) |
| 4 | Mist (`lay-mist`) | 3 wisps at the foot of the ridge | drift; thick at dawn, thicker in rain and fog |
| 5 | Village (`lay-vil`) | houses, trees, Charlie's | barely sways |
| 6 | Field (`lay-near`) | the landing ground | sways and comes a little closer (the "camera") |
| 7 | Life (`lay-life`) | everything in section 6 that stands on the ground, by depth | yes |
| 8 | Foreground (`lay-fore`) | grass at your feet | sways with the wind |
| 9 | Live sky (`svg.live`) | stars, gliders, vulture, birds, windsock, weather, taxis, night lights | yes |

---

## 6. The cast

"Faces" = which way the picture is drawn; the code flips it to travel the other way.

### 6.1 In the sky (layer 9)

| Thing | Picture | When | Where and how |
|---|---|---|---|
| Stars | 12 dots | night | fixed places, twinkle |
| Gliders | `glider-red/blue/yellow`, 12 fixed slots | flying on: 12 in busy blocks, 6 otherwise, 4 at lunch; ⅔ when cloudy, 2 when overcast | each sways side to side (22–36 s) and bobs; specks over the ridge, bigger ones over the field |
| Vulture | `vulture` | flying on, sunny or cloudy, 11:00–16:00 (thermals) | circles over the ridge |
| Small birds | `birds-flock` | daylight, not in storms | crosses the sky every ~2.5 min, with the wind |
| Cloud banks | drawn puffs | cloudy, overcast, rain, storm | drift below the peaks with the wind |
| Rain / snow | drawn streaks / flakes | rain, storm / snow | fall |
| Fog | drawn veil | fog | lies over the field, drifts |
| Lightning | flash | storm | now and then |
| Windsock | `windsock` | always | on Charlie's roof; points where the wind blows, droops in light wind, flutters |

### 6.2 Fixed things that change with the time (layer 7 and 9)

| Thing | Picture | When | What |
|---|---|---|---|
| Road | `road-strip` | always | the tarmac band along the far edge of the field |
| Taxi corner: café cluster, open tea shack at the bend, parking ramp | painted into all four paintings (31 Oct 2026; layout from the satellite map, confirmed by the maker) | always | 1–2-floor cafés with balconies, big windows, fenced garden seating, a few people sitting; the patchwork-roofed open tea shack in front |
| Shacks behind the road | painted cut-outs (Gemini, scaled and placed to the map) in the paintings | always | colourful: tarpaulin roofs, faded flex posters (pictures only, no text), plastic stools, umbrella tables |
| Café lights | `lights-cafes` (the café cluster) | dusk till dawn, together with every other building (`--cafe-glow`) | lit windows, string lights, garden lanterns |
| The left hotel + cafés | painted into all four paintings (31 Oct 2026; Bir High and the Hub Safari / Vikings cluster, x 749–994, no names): a small hotel with wooden balconies and a rooftop terrace, a garden café with umbrellas and a fence, little shops with awnings | always | people sitting on the terrace and in the garden |
| Left lights | `lights-left` | dusk till dawn (`--cafe-glow`) | lit windows, balcony and roof string lights, garden lanterns |
| Tea-shack lights | `lights-shack` (the open shack at the bend), `lights-shacks` (the house by Charlie's, Himani), `lights-shack-i8` (the small shack) | dusk till dawn (`--shack-glow`) | a bulb inside, string lights on the roof, lanterns on the tables |
| Charlie's bulbs, village lights | painted in the night painting | night | glow |
| Taxis at the stand | `car-taxi`, `car-own` | while rides are on in the app | one per live ride (up to 3), queued on the road edge from x 2084 |

Rule (03.11.2026, the maker): all building lights behave the same: if Charlie's is lit (its lights are painted into the
night painting), every café, shack and building is lit; all on at dusk, all off at dawn.

### 6.3 On the field (layer 7)

| Character | Picture · frames · faces | When | Where and how |
|---|---|---|---|
| Cow, left | `life-cow-graze` 3, `-walk` 6, `-turn`, `-rest` · faces right | day: grazing cycle; night: lying down | x ~1180, 616 depth; 150-second day: graze · lift head · walk ~3 m · turn · walk back · graze (~0.25 m/s) |
| Cow, right | same, flipped | same | x ~1880, 602 depth |
| Kiting pilot | `life-kite-wing` + 3 poses | 8:00–17:30, dry, daylight | mid-field (x ~1270); steps between poses, the wing swings into the wind |
| Groups on the grass | `life-friends-a-2`, `-b-2`, `life-couple-a-2`, `-b-2` (6 groups; 2 moments each, `grpBody`) | 2 of them 9:00–18:30 (dry); all 6 18:30–23:00 (dry) | fixed spots 35–55 m away; cigarette and phone glows only after dark |
| Parked cars by Charlie's | 5 cars, x 1268–1652 | when flying is off, 5:30–23:00 (one stays till morning) | still |
| Parked cars at the edges | 4 cars (x 300, 356, 2205, 2262) | 5:30–23:00 | still |

### 6.4 The flying crew (only while flying is on)

| Character | Picture · frames · faces | Where | Life |
|---|---|---|---|
| BPA marshal | `life-marshal` 9 (0–5 walk, 6 look up, 7 whistle-stop, 8 wave on) · faces right | on the road, x 1640–1990 | walks his stretch at 1.2 m/s, stops to look up for 4–9 s, walks back; during a landing: stops traffic, then waves it on |
| Cameraman | `life-cameraman` 6 (0–2 sitting, 3 kneel, 4–5 shooting) · faces right | grass, x 1845, 34 m | looks up / around / checks camera on a loop; kneels and films each landing |
| Tandem friends | `life-tandem-friends` 3 (chat, point, cheer and film) · faces right | beside the cameraman | chat; point when a tandem comes in; cheer when it lands |
| Students (2) | `life-alpine` 6 (wing laid out, pulling up ×3, under the wing, brake) · **faces left** | x 1065 and 1205, 58 m and 50 m | take turns: wing laid out → run 6 m into the wind → brake → wing down, walk back; paused at lunch and during landings |
| Instructor | `life-instructor` 6 (0–3 jog, 4 point, 5 call) · faces right | between the students | jogs to the student whose turn it is, points while the wing comes up, calls at the brake |
| Landing tandem | `life-tandem` 9 (0–5 passenger moments, 6 flare, 7 touch-down run, 8 standing) · **faces left** | lands at x 1720, 62 m, into the wind | first one ~12 s after the scene opens; then every 110–220 s in busy blocks, 200–320 s otherwise, 300–500 s at lunch. 15 s glide in from the ridge, flare, short run, stand, wing comes down; drawn in front of the road |

### 6.5 On the road (layer 7, depth ~570)

| Character | Picture · faces | Length · speed |
|---|---|---|
| Alto, Swift, Scorpio, Innova | `life-car-*` · right | 41–55 units · ~25 km/h |
| Royal Enfield | `life-bike-enfield` · right | 26 · ~28 km/h |
| Scooter (two riders) | `life-bike-scooter` · right | 22 · ~22 km/h |
| Cyclist | `life-cyclist` 4 pedal frames · right | 21 · ~12 km/h |
| Walkers: man, woman, backpacker, elder (slow), pilot with a wing bag (flying hours only) | `life-walker`, `-w`, `-b`, `-o`, `-p` · right | 1.3–1.6 m/s (elder 1.0) |

Vehicles drive the road up to the bend at the taxi stand (`ROAD_END`), left lane or right lane by direction; there they
come round or go round the corner (fading in or out over the last stretch). Walkers walk the visible stretch on the
footpath side. Headlights and tail lights after dusk.

How often (one chance per second, so the gaps vary around the average):

| Time | A vehicle every | A walker every |
|---|---|---|
| 5:00–7:00 | ~70 s | ~120 s |
| 7:00–18:00 | ~35 s | ~12 s |
| 18:00–23:00 | ~13 s | ~5 s |
| 23:00–5:00 | ~150 s | none |

Which vehicle (by day / at night): car 50 % / 62 % (the four models equally), Enfield 20 % / 28 %, scooter 15 % / 7 %,
cyclist 15 % / 3 %.

---

### 6.6 At the shacks and the taxi corner (layer 7, behind the road / by the stand)

| Who | Picture · frames | Where | Life |
|---|---|---|---|
| People going in and out | the walkers (`life-walker`, `-w`, `-b`, `-o`) | the doors of the house by Charlie's, Himani's two tables, the small shack, the open shack at the bend, three café garden gates, and on the left the hotel, the garden café and the little shops (`VISIT`) | while that place is open (tea shacks ~6:30–19:45, cafés ~9:30–23:00): walk a few metres along the road or garden front and in at the door (fading in the doorway), or come out and walk off; about one every 3–8 s on the screen, at most 4 at once; any open place at random, none favoured; not in rain |
| Chai seller | `life-vendor-chai` 5 (0 idle, 1 pouring, 2 handing a glass, 3 stirring, 4 sipping) · right | left end of the parking ramp, x 2093 | 6:30–19:30, not in rain: mostly idle, now and then pours or stirs (cross-faded poses) |
| Snack seller | `life-vendor-snack` 5 (0 idle, 1 reaching in, 2 handing a plate, 3 fanning, 4 counting coins) · right | right end of the ramp, x 2188 | 10:00–19:30, not in rain: the same |
| People on the ramp | `life-couple-a-2`, `life-friends-b-2`, `life-couple-b-2` (`RAMP_SIT`) | sitting on the ramp's concrete roof | 8:30–18:30 on cloudy or overcast days and in winter (on a sunny day the concrete is too hot) |

Sizes: at the shacks (Charlie's depth) ~11 units a metre; at the taxi corner (~200 m) ~6.5. Vendors and walkers were made
with Gemini to match the other figures (`art-sources/sat/make_vendors.py`, the maker's computer only).

## 7. Situations at a glance

| Situation | Gliders | Crew + tandem | Kiting | Parked by Charlie's | Groups | Traffic |
|---|---|---|---|---|---|---|
| Flying day, clear | 6–12 | yes | yes | no | 2 (9:00–18:30) | day rate |
| Cloudy | ⅔ | yes | yes | no | 2 | day rate |
| Overcast | 2 | yes | yes | no | 2 | day rate |
| Rain, storm, snow, fog | 0 | no | no | yes | none | day rate |
| No-fly season | 0 | no | yes if dry | yes | 2 if dry | day rate |
| Evening 18:00–23:00 | 0 | no | no | yes | all 6 from 18:30 if dry | evening rate |
| Late night | 0 | no | no | 1 car | none | the odd car |

---

## 8. Where chance is used (and only here)

| What | Chance picks | Fixed by the rules |
|---|---|---|
| Next vehicle | which allowed kind, which direction | how often (by time), lane, speed, size, lights |
| Next walker | which allowed person, direction, pace within 1.3–1.6 m/s | how often, path, size |
| Next tandem | the gap, within the range for the time of day | the path, frames, landing point, the crew's reactions |
| Tandem passenger | which of 6 moments, every 1.4 s | — |
| Marshal | where he turns (within 90 units of each end), how long he looks up (4–9 s) | his stretch, speed, frames |
| Students | the pause between turns (1.5–4 s) | everything else |
| Stars | positions (the same every night) | count, twinkle |

---

## 9. The camera

| View | What it shows |
|---|---|
| **Banner** (home screen) | 37 % of the screen height, the full height of the painting, about half its width, centred on Billing and Charlie's. The field sways gently and comes a little closer (`camNear`, `dolly`). |
| **Full screen** (⤢) | the painting's full height, about a sixth of its width on an upright phone. The camera slides along ONE fixed loop (`CAM_SEQ`, `camAt`), whatever happens in the scene. It never zooms and there is no hand panning (zooming made phones redraw the whole layered painting at 2×, the likely cause of crashes). Tap or swipe up to close. |

**The loop (about 2 min 26 s, agreed 31 Oct 2026; no holds, the speed varies):** opens on A moving right → B (the taxi
stand + cafés) → turns → one long slide left over everything → C (the snow peaks + the left village) → turns → back
through A. Speed (`CAM_V`, `camSpeed`, painted into `CAM_PATH`): slowest gliding past A (9 units a second), quickest in
the open stretches (46), slowing into each turn at B and C (a turn has to pass through standstill; it lasts under a
second).

Full screen always starts at A. Phones that ask for less motion stay at A.
`camNow()` tells life where the loop is (which stop, how long until the next part), so life can be timed to be seen:
see section 10. New traffic in full screen starts just outside what's on screen.

## 9b. Life timed to the camera (31 Oct 2026)

| Where | What is timed | How |
|---|---|---|
| A / landing spot (x 1720) | the landing tandem | in full screen it is launched only when the camera will pass the landing spot just as its 15 s glide ends (`camFuture`), so the touch-down is on screen; usual gaps between landings stay |
| B (taxi stand) | a car comes round the bend | as the camera nears B on its way right, 4 times in 5 a car comes round the corner heading left (`spawnVehicle(m, { bend })`) |
| C (snow-peak end) | two grazing cows | always there by day, resting together at night (they were all in the middle before) |
| Everywhere | traffic and walkers | in full screen 7 in 10 drive / walk towards the camera, starting just off the leading edge of the screen, so they meet what you're watching |
| Taxi corner, shacks | visitors, vendors, people on the ramp | already shown only where the screen is (`viewRange`) |

## 9c. Animation plan for every character (frames: what we have, what's still to make)

RULE: nothing that moves across the screen may slide on a single pose; legs move on real frames, poses change by
cross-fade.

| Character | Moves across? | Frames now | Status | To make (next art batch) |
|---|---|---|---|---|
| Walkers (man, woman, backpacker, elder, pilot) | yes | 6 / 4 walk frames | OK | — |
| Café / shack visitors | yes (short) | the walkers' frames | OK | — |
| Cyclist | yes | 4 pedal frames | OK | — |
| Cars, bikes, scooter | yes | 1 (wheels too small to see) | OK | — |
| Cows | slowly | graze 3, walk 6, turn, rest | OK | — |
| Marshal | yes | walk 6 + look up, stop, wave | FIXED 31 Oct: he no longer glides in his stop pose (his walk pauses while he holds traffic) | — |
| Instructor | yes | jog 4 + 2 coaching poses | OK | — |
| Launch students | a few metres | 6 poses + 2 wing frames without the figure (6, 7) + `life-student-run` 4-frame run cycle | DONE 31 Oct: the two running stretches use the run cycle under the risers | — |
| Landing tandem | glide + touch-down | 6 passenger moments, flare, run, stand + wing frame 9 (no pair) + `life-tandem-run` 4-frame cycle | DONE 31 Oct: the pair runs out the landing (~2 m, slowing) on the cycle | — |
| Cameraman + friends | no | 6 + 3 poses | OK | — |
| Kiting pilot | sways in place | wing swing + 3 step poses | OK | — |
| Chai seller | no | 5 poses (idle, pour, hand a glass, stir, sip) | DONE 31 Oct | — |
| Snack seller | no | 5 poses (idle, reach in, hand a plate, fan, count coins) | DONE 31 Oct | — |
| People on the ramp, groups on the grass | no | 2 moments each (as drawn + heads / hands moved: a laugh, a raised cup, pointing, a head lifted) | DONE 31 Oct: each group switches for a few seconds now and then, on its own beat | — |
| Evening groups | no | the same 2 moments + ember / phone glows | DONE 31 Oct | — |

## 10. Agreed, to build before sharing (25 October 2026)

1. **Full screen, life comes into view (done 25 Oct):** see section 9.
2. **Full screen camera (REPLACED 31 Oct):** the camera no longer chases the action; it slides along one fixed loop
   (section 9) and LIFE IS TIMED TO THE LOOP instead. Next step (agreed): rework the life plan to favour the pan — a
   landing while at A, taxis arriving / leaving at B, cows and village life at C, traffic and walkers entering just ahead
   of the pan — and give every new character a full animation plan with enough frames (no sliding stills: fix the
   marshal gliding in his stop pose, the launch students' held run poses, the tandem's touch-down slide).
3. **Zoom (REMOVED 31 Oct):** no zoom and no pinch / drag / wheel in full screen (crash risk on phones).
4. **Every café alive, none favoured:** Charlie's (centre), Himani café's tea shacks (right of Charlie's), the major
   cafés from the right edge of the ground, the taxi parking, the cafés on the far left. Each: opening hours by size
   (tea shacks first; big cafés ~9:30–23:00), lights, people outside and walking in and out. No names or branding in
   the art. (The café map is confirmed with the maker on the master photo before building.)
   DONE 31 Oct: the taxi corner and the shacks are painted (section 6.2) with their lights by opening hours, people going in
   and out, the vendors and people on the ramp (section 6.6). The cafés on the left too (31 Oct). DONE. How it was made: `art-sources/sat/` (maker's computer only).
5. **Weather page (done 25 Oct):** Launch has its own painting, the view from take-off down into the valley
   (`art/wx-launch-day.webp`, `-night.webp`, made with Gemini in the house style; the night one relit from the day one so
   the outlines match). Each place has its colour: blue frame and "TAKE-OFF · Billing" label, green frame and
   "LANDING · Bir" label, on the card and the hour tiles (`WX_ART`, `WX_TAG`, `wxArt`).

Open report: a scooter seen "facing one way, moving the other". Not reproduced; an automatic check over a minute of
the scene found every mover facing its way. If seen again, note the time and record the screen.

---

## 11. Where it lives in the code (`index.html`)

| Part | Code |
|---|---|
| Time, sky, paintings | `sceneMins`, `SKY_KEYS`, `skyAt`, `PAINT_KEYS`, `paintMix`, `updatePaint` |
| Layers | `paintHtml`, `placeStageCard` (banner / full-screen framing), `openArtView` |
| Fixed life, café and shack lights, parked cars, groups, cows, kiting | `lifeHtml`, `--cafe-glow`, `--shack-glow`, `PARKED`, `PARKED_EDGE`, `GROUPS` |
| Road and traffic | `ROAD_PTS`, `roadY`, `VEH`, `lifeRate`, `spawnVehicle`, `spawnWalker`, `moveAlong` |
| Flying crew and tandem | `glidersUp`, `syncCrew`, `sprite`, `patrol`, `idleCam`, `coach`, `launchRun`, `spawnTandem` |
| Sky, weather, windsock, taxis | `liveLayerSvg`, `weatherMood`, `weatherLayer`, `WX_FILTER` |
| Review a spot (off the live site) | `?t=HHMM` scenery clock, `?cam=1800,1.5` full screen held on x 1800 at 1.5×, `?wx=cloudy` the scene's weather |
