# Zombie Game

My first game project, an arcade-style zombie FPS. Collect weapons, ammo, and blast zombies.


# TODO

- [ ] Add all weapons
- [ ] Investigate if stairs can be fixed with sliding/ stepping up
- [ ] Set up day / night settings for transitions
- [ ] Add more zombie types
- [ ] Level blocking
- [ ] Camera Smooth (generic)
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
