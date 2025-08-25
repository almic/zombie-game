# Zombie Game

My first game project, an arcade-style zombie FPS. Collect weapons, ammo, and blast zombies.


# Day / Night

- [ ] Turn off moon when below horizon.
- [ ] Moon/ Sun shadow casting when above the horizon, turn off moon shadow if
      Sun is up. Scale shadow opacity to zero before turning off moon shadow.
- [ ] Sun light to diminish accurately to the transmittance in the sky (lut texture)
- [ ] Light color to match transmittance in the sky (lut texture)
- [ ] Moon illumination to scale depending on the phase, look up real equations.
      The full moon is more than 2x brighter than a half-moon! Non-linear!
- [ ] Match mie power to moon illuminance (see above)
- [ ] Fog at dawn and dusk, set with a curve. This looks bad right now.
- [X] Optimize sky shader, should skip sun and moon disk for radiance maps
- [X] Flashlight which can be toggled


# Lighting Solutions

Here is what I would like:
    - Dynamic shadows and time of day
    - Interior of buildings can get dark when no light is reaching the back
    - Able to see the flashlight during the day, needed to see dark corners inside
    - When inside a building and looking near windows, outside appears too bright
      to see detail, when looking at the window, exposure changes and you can see
      outside, and inside becomes darker.

This is what I tried:
    - SDFGI; failed because it just sucks. (BAD AND EXPENSIVE)
    - VoxelGI; failed because too many bugs, only works in certain directions,
      weird color flashing when the light moves slowly (DEAL BREAKER)
    - LightmapGI; it sucks. use blender instead.

What I cannot do:
    - I cannot spend time to fix the bugs of VoxelGI
    - I cannot use any available real-time solution, none of them work for interiors.
    - I cannot do nothing, interiors have to be dark.

Ideas:
    - Make separate levels for buildings, this allows baked lighting to work and
      you can get perfect results. Time of day can be cut into a few moments.
    - Bake lightmaps in blender for all interiors. This would look great but needs
      to be implemented so lightmaps fade. Need to worry about file size, too.
    - Turn off ambient light globally, and use spot lights to illuminate large
      outdoor shadows, implement directly into terrain shader so ground shadows
      look good. Use emissive planes to light interiors.
    - Place planes on windows into buildings. Trace line from plane into direction
      of the sun. Where it hits a wall, draw a texture and place a light to
      simulate bounce lighting. Can even get color of surface for colored lighting.

Common ideas:
    - Baked lighting.
    - Time of day interiors are staggered.
    - Interiors receive no light from outside.

In order of time to implement (fastest to longest):
    - Separated interior levels.
        - PROS:
            - Reduce game scope, only a few interiors can be entered.
            - Full control over lighting.
            - Mask time of day from player, they could not be aware how much time is passing.
        - CONS:
            - Loading scenes
            - Cannot see inside from the exterior (could be "fixed" with high effort)
            - Means more effort for interiors since you could have more detail
    - Turn off ambient light.
        - PROS:
            - No lightmaps needed, just more light sources.
            - VERY dark interiors instantly.
            - Light only goes where you want, a lot of control.
        - CONS:
            - Looks worse without a lot of effort in lighting.
            - Difficult to make it look good at all times of day.
    - Baked lightmaps.
        - PROS:
            - Perfect realistic lighting on static surfaces.
        - CONS:
            - Long time to bake if you decide to change anything about the sky.
            - Would have to blend between lightmaps throughout the day, could be noticeable.
            - File size could get very large for high quality results.
            - Does not fix character lighting on its own, would need to place lights
              to light up characters.

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
