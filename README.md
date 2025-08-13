# Zombie Game

My first game project, an arcade-style zombie FPS. Collect weapons, ammo, and blast zombies.

# TODO

- [ ] Make WeaponNode do random weapon kick and sway instead of animations
- [ ] Add all weapons
- [ ] Investigate if stairs can be fixed with sliding/ stepping up
- [ ] Add more zombie types
- [ ] Level blocking
- [ ] Camera Smooth (generic)
- [X] Fix CharacterBase friction on slopes (cannot climb slopes anymore)
- [X] Add idle/ walk animation to shotgun + pistol
- [x] Add pistol animations
- [x] Fix shovel animations
- [X] Weapon aiming (reduce look speed and FOV)
- [X] Add individual weapon melee
- [X] Add ammo type selection
- [X] Connect weapon charging animation to system
- [X] Connect reload animation to reload system


# ANGRY TODOS

- [ ] Make second rifle reload out animation that doesn't charge, to keep a live
      round chambered.
- [ ] Add procedural weapon sway, standing, walking, jumping, added on top of
      existing animation for inaccuracy.
- [ ] Refactor player weapon aim, move to weapon node and use Interpolation resources
- [ ] Increase expended bullet life time, increase damping
- [ ] Weapon "random spread" and "minimum spread" changed to "kick" and "random range"
      so the values don't look ridiculous
