# "Immersive" First Person Controller v1.3.1
A first-person controller designed for slower paced, "immersive sim"-like control. The behaviour is done through a finite state machine. I just wanted to learn the pattern and make something useful at the same time. Feel free to contribute or submit issues :)

## How to use
Player.tscn contains the player character scene. Copy it to whichever scene, where you need it. Climbing should work with any horizontal surface, no special setup necessary.

### Controls
- [W][A][S][D] = move
- [Shift] = hold to sprint
- [C] = toggle crouch or slide (when sprinting)
- [Space] = jump, hold near ledge while falling to grab

## Features
### Existing features
- Basic movement (i.e. walking, running, jumping)
- Crouching
- Sliding
- Climbing

### Planned features
- GUI for changing character-related values more conveniently
- More customization (view bobbing, custom crosshair, etc.)
- Controller support
- Customizable animations for climbing
