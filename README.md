# Zombie Game

My first game project, an arcade-style zombie FPS. Collect weapons, ammo, and blast zombies.


# Day / Night

- [ ] Flashlight which can be toggled
- [ ] Optimize sky shader, should skip sun and moon disk for radiance maps
- [ ] Turn off moon when below horizon.
- [ ] Moon/ Sun shadow casting when above the horizon, turn off moon shadow if
      Sun is up. Scale shadow opacity to zero before turning off moon shadow.
- [ ] Sun light to diminish accurately to the transmittance in the sky (lut texture)
- [ ] Light color to match transmittance in the sky (lut texture)
- [ ] Moon illumination to scale depending on the phase, look up real equations.
      The full moon is more than 2x brighter than a half-moon! Non-linear!
- [ ] Match mie power to moon illuminance (see above)
- [ ] Fog at dawn and dusk, set with a curve. This looks bad right now.


# TODO

- [ ] Set up day / night settings for transitions
- [ ] Investigate if stairs can be fixed with sliding/ stepping up
- [ ] Investigate weird snapping bug
- [ ] Make each weapon have its own UI scene for displaying the weapon and ammo
- [ ] Add more zombie types
- [ ] Level blocking
- [ ] Camera Smooth (generic)
- [X] Add all weapons
- [X] Make WeaponNode do random weapon kick and sway instead of animations
- [X] Fix CharacterBase friction on slopes (cannot climb slopes anymore)
- [X] Add idle/ walk animation to shotgun + pistol
- [X] Add pistol animations
- [X] Fix shovel animations
- [X] Weapon aiming (reduce look speed and FOV)
- [X] Add individual weapon melee
- [X] Add ammo type selection
- [X] Connect weapon charging animation to system
- [X] Connect reload animation to reload system


# ANGRY TODOS

- [ ] Allow aiming while walking with the bolt, but greatly reduce move speed and
      add a substantial amount of walking sway.
- [ ] When aiming with the bolt, move projectile marker to the scope, and turn off
      weapon targetting. This makes shots line up with the scope, and prevents weird
      rotation for close targets.
      ALTERNATIVELY: special targetting that only rotates the projectile marker
      and not the weapon. SILLY.
- [ ] Make revolver scene ports only update changes, instead of clearing and resetting
- [ ] Add way to spin revolver cylinder randomly, and obscure the ammo order for UI
- [ ] Add special ammo for the revolver only
- [ ] Make recoil rotation origin marker work
- [ ] Make bolt rifle scope have input for magnification and focus, also compute
      magnifications so they are accurate. And reticle setting if bullet wind/ drop is added.
- [ ] Make second rifle reload out animation that doesn't charge, to keep a live
      round chambered.
- [ ] Add procedural weapon sway, standing, walking, jumping, added on top of
      existing animation for inaccuracy.
- [ ] Make weapon recoil bounce when it hits a boundary, so it will sway right-left over time
- [ ] Refactor player weapon aim, move to weapon node and use Interpolation resources
- [ ] Increase expended bullet life time, increase damping
- [ ] Weapon "random spread" and "minimum spread" changed to "kick" and "random range"
      so the values don't look ridiculous
