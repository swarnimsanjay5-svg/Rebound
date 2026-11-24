Rebound Neon Cosmos Edition is a 2D arcade game where you climb as high as you can by bouncing an energy orb off neon platforms in space.

This is my first game project, made for Hack Club Phantom by Swarnim (swrn.exe). You can play it in your browser on the itch.io demo page or download the source code to run it locally with Godot 4.This Is My First Project And I Didnt Had Idea About Git Commits So Sorry For Few Commits (Added Commits Adter Reading About It Online)

The game has a Neon Cosmos theme with a simple arcade idea: "Every fall is another chance."

The look of the game is deep space, a dark blue (#080d20) with stars that move in the background. On the title screen, there's a planet with rings. The platforms are made of glowing neon shapes. As you get a higher score, the platforms change color. They start as bright cyan and move through green, yellow, hot pink, and finally purple.

Most of the visuals, like the orb, sparkles, lightning effects, and trails, are drawn directly using Godot's _draw() function instead of using separate image files.

To play, your orb bounces every time it hits a platform. You can move left and right, and if you go off one side of the screen, you'll appear on the other.

Bouncing the orb fills up a ring around it and a bar at the bottom called the Turbo bar. After 10 bounces, the orb turns bright blue and you can press 'W' to jump really high.

You need to be careful where you land. Standard neon platforms are safe, but if you bounce on the same one 5 times in a row, it will start to crack and break so you can't stay in one place too long. Orange platforms are already cracked and will break after just one bounce.

If you fall too close to the bottom of the screen, a red warning will flash and say "DANGER!" before you fall off the game area. Your highest score is saved automatically.

Controls:
A or Left Arrow: Move left
D or Right Arrow: Move right
W: Use Turbo Jump (when the orb is ultra-blue)
M: Turn music on or off
Esc: Pause or unpause the game

For game over, when you fall off-screen, it shows a dark overlay with black bars and a "WASTED" title, similar to GTA.

When the game is over, the background music volume goes down so you can hear a "Faah" sound effect. If the sound file isn't there, it will make its own descending tone.

The background music loops "Dance Monkey" and fades smoothly between the menu, gameplay, and game over screens.

You can add your own custom fonts and backgrounds by putting them in the "assets" folder. If you don't, the game will use its built-in options.

The game was made using Godot 4 and GDScript. It handles physics, collision detection, sound effects, and graphics all in one script. Your high score is saved locally using Godot's ConfigFile.

The menus and buttons are styled like CSS, using Godot's StyleBoxFlat to create borders, rounded corners, and glowing shadows for different button states.

You can play the game in your browser at the itch.io demo link. To run it locally with Godot 4, download the code, open the project in Godot, and press F5 to play.
