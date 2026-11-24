Nov 15 — Project Kickoff & Core Movement
Started my first game in Godot 4. I wanted to make a vertical arcade climber in space, so I settled on 960x540 viewport and started working on my prototype in GDScript.
Initialize the basic player state (orb_pos, vel). Initialize gravity to 1200.0. Initialize left/right movement A/D and Left/Right arrow keys.


Nov 16 - Collision Tunneling & Camera Scrolling Fixes
Confronted a serious physics bug earlier today: the orbs would occasionally leap through the floor between frames once they hit too fast.
Changed the basic overlap test to a swept landing check on lasty + 17 and orbpos.y + 17 versus the top of the platform, which totally fixed the tunneling.
Locked camy to only scroll up when the player pushes higher and scored based on highest altitude( topy).
New procedural platform spawn above camera, cleanup culling for tiles that fall off bottom of camera.

Nov 17 - Going Full Procedural with _draw() & Neon Zones
Rather than looking for sprite sheets I chose to use Godot's _draw() functions to draw the complete game programatically.
Created the distant deep-space background (#080d20) and 120 twinkling parallax stars that move through the scene at 0.25x camera speed.
Cluster multi-pass translucent rectangles around platforms to fake a neon bloom.
Tacked on dynamic altitude color zones (zone_color()) so the platforms gradually transition from cyan to green, yellow, hot pink, and purple for every 60 score points.

Nov 18 – Designing the Energy Orb & Game Feel
Completely dedicated to making the player character look and move as if alive.
Implemented a multi-layered orb renderer (render_orb) with shaded core, rim highlights, two energy rings counter-rotating, and three sparkles orbiting.
Extra velocity-based vertical stretching when flying up/down plus impact squash + expanding shockwave ring whenever the orb hits a tile.
Added 28 frames of fading motion trail behind the orb.

Nov 19 - Platform Mechanics & Anti-Camping Rules
During the playtest I realized you could just bounce on the same safe platform forever.
Inserted a consecutive bounce tracker (hits) on each tile; bounce 5 times on the same normal platform in a row and eventually, white/orange stress cracks will appear until the platform explodes.
Added an orange fragile platform that spawns 25% and gets destroyed after a bounce.
Created a shard particle system (shatter_plat) that shatters broken platforms into spinning, gravity-driven shards with slight camera shake.



20 Nov - Turbo Charge System
Did a risk-reward kind of mechanic that lets players rocket right over those troublesome gaps.
•Established a 10-bounce charge system, where every bounce illuminates one of the ten arcs around the orb and the bottom HUD bar.
Once charged, the orb turns ultra-blue (#2f6bff), crackles with procedural electric arcs, and pulses out a shockwave.
Pressing W executes fire_turbo() (1500.0 upward velocity), introduces a thruster flame polygon, induces heavy camera shake, and creates a bright cyan-blue trail.



Nov 21 – Custom UI Styling & Live Title Screen
The default grey Godot UI buttons looked totally out of place with this neon theme, so I just wrote the entire UI layout and styling in code.
All buttons and menu cards were styled using Style Box Flat (rounded corners, glowing borders, drop shadows, and my own custom hover/pressed color states - basically css-ing the Style Box Flat).
Created a live animated demo background for the main menu with a glowing planet, floating neon tiles, and a demo orb on a starter pad switching between normal and charged states.
Connect the How to Play Screen and Esc Pause Menu (Resume, Restart, Main Menu).



Nov 22 - Danger Warnings, Memes & Procedural Audio
Incorporated the last component of personality, tension and sound feedback.
Constructed a red edge vignette and blinking DANGER! Warning when the orb drops within 190px of the bottom of the screen.
Developed a WASTED game-over screen sequence in the style of GTA, complete with desaturated screen, cinematic black letterbox aspect ratio, and retry buttons popping up 2.0s after the screen goes to black.
Hooked up as background music (with M muted and auto volume ducking on death) and also set up the Faah sound effect. Also authored a procedural AudioStreamWAV synthesizer fallback so the death sound still works even when external audio assets are not present.


Nov 23 - High Score Persistence & Playtest Balancing
Working on tuning constants and edge cases today.
User:// added Config File saving (rebound.cfg) so best scores are stored.
Slighlty scaled bounce velocity with bounce count (minf(float(bounces) * 3.0, 120.0)), so the pace of the game gradually accelerates as you stay alive longer.
Confirmed font fallbacks (System Font stack) so bold headers will display correctly on other machines.



Nov 24 – Web Export, itch.io Upload & Final Polish
Finish the project with Hack Club Phantom.
Tested the build in browser (HTML5 export) and uploaded the playable demo to itch.io.
Cleaned up script structure, added more controls and mechanics to the final README.md, and got the Github repo ready for submission.