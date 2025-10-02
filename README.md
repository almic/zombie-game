# Zombie Game

My first game project, an arcade-style zombie FPS. Collect weapons, ammo, and blast zombies.


# TODO

- [ ] Add more zombie types
- [ ] Support controller movement, can move slower/ faster
- [ ] Investigate top_speed / speed value in update_movement
- [ ] Level blocking
- [ ] Charge input broke
- [ ] Add brake and handbrake inputs
- [ ] Align vehicle camera to world UP
- [ ] Apply interpolation to steer, forward, and brake target on WheeledJoltVehicle.
      Add interpolation to handbrake, but much faster (under 0.5 seconds)
- [ ] Add limit to steering angle based on speed curve.
- [ ] For magazine weapons, allow keeping live round chambered during reload.
      Perhaps keep chambered if reload input is held when it would normally
      eject, allowing an effective "mixed" load on magazine weapons. Also, allow
      charging a magazine weapon if the chambered round is a different type than
      the reserve. Maybe require the input to be held for some time to prevent
      "check" charges from ejecting a round.
- [ ] Pack weapon images and round icons into two textures, one for all weapons,
      one for all round types. WeaponResource and AmmoResource will need to have
      icon indexes added to support this.
- [ ] FIX THE SLUG MODEL, metal cap should be longer than the shot shell
- [ ] Camera Smooth (generic)
- [ ] Investigate if stairs can be fixed with sliding/ stepping up
- [X] Debug front differential / front wheels not recieving any engine torque
- [X] Make each weapon have its own UI scene for displaying the weapon and ammo
- [X] Investigate weird snapping bug
- [X] Set up day / night settings for transitions
- [X] Moon illumination to scale depending on the phase, look up real equations.
      The full moon is more than 2x brighter than a half-moon! Non-linear!
- [X] Sun light energy to diminish accurately to the transmittance in the sky (lut texture)
- [X] Apply horizon disk effect, e.g. can see celestial bodies earlier and they
      linger closer to the horizon for longer. Apply to sun and moon light basis.
- [X] Sun light color to match transmittance in the sky (lut texture)
- [X] Sky intensity to match brightness of the sky texture
- [X] Moon/ Sun shadow casting when above the horizon, turn off moon shadow if
      Sun is up. Scale shadow opacity to zero before turning off moon shadow.
- [X] Turn off moon when below horizon.
- [X] Optimize sky shader, should skip sun and moon disk for radiance maps
- [X] Flashlight which can be toggled
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

# Building Count

Family homes: 36  (36)
Business:     26  (62)
Special:      14  (76)

Total:        76


# ANGRY TODOS

- [ ] IDEA for fixing terrain nav meshing: Compare close polygons for XZ overlap,
      and if they overlap then push the lower polygon vertices back so from above
      they do not appear to overlap (easier said than done).
- [ ] Set up vehicle suspensions to get random impulses at low speeds when on
      terrain
- [ ] Match moon's mie power to moon illuminance.
- [ ] Fog at dawn and dusk, set with a curve. This looks bad right now.
- [ ] Apply Kawase Blur during night vision, depth based (further = more blurry)
      Should be active based on exposure value, use pos multiplier as depth (cheap)
- [ ] Add random refraction and squashing to moon and sun near horizon for shaders.
- [ ] If aiming at the sun with the bolt scope, midday, flashbang the entire screen
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
