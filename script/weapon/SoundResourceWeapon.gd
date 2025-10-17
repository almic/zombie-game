@tool
## Resource for dynamic weapon sound organization
class_name SoundResourceWeapon extends SoundResourceLayered


## Transient sound. Intended to be the very short explosive sound that comes
## from the bullet ignition. These should be unique to the type of round being
## fired, not the weapon itself, so it can be more generic. This should have
## subtle volume and pitch shifting to immitate inconsistent bullet filling.
@export var transient: SoundResource:
    set(value):
        transient = value
        _array_dirty = true

## Kick sub sound. This gives weapon shots a lot of power with little effort.
## This can be generic or a pitched and EQ'd version of the body. These should
## be mono-channel and have subtle volume and pitch shifting to immitate bullet
## fill inconsistency. Try to include a subtle *click* in kicks to get the most
## out of pitch variety.
@export var kick_sub: SoundResource:
    set(value):
        kick_sub = value
        _array_dirty = true

## Body sound. Intended to be the distinct sound produced by the construction
## of the weapon when fired. This is unique to each weapon and accounts for
## half of a weapon's character. This should include a distinct transient and
## a short explosive tail distinct from other weapons.
@export var body: SoundResource:
    set(value):
        body = value
        _array_dirty = true

## Mechanical sound. Intended to be the moving parts of a weapon when fired,
## so it should be unique to each weapon, and this accounts for a quarter of a
## weapon's character. This may have the most volume and pitch shifting relative
## to the other sound components.
@export var mech: SoundResource:
    set(value):
        mech = value
        _array_dirty = true

## Tail sound. This is the sound heard bouncing off distant terrain, and can
## range from a loud crack from rifles, to a soft pop of a suppressor, to a
## long rolling thunder from the loudest guns. It should be rendered to fade in
## as the body fades out. This should have subtle volume and pitch shifting so
## the sound is not compromised when passed through environmental filters.
@export var tail: SoundResource:
    set(value):
        tail = value
        _array_dirty = true


var _array_dirty: bool = true


func get_sounds() -> Array[SoundResource]:
    if not sounds:
        sounds = []
        sounds.resize(5)

    if _array_dirty:
        sounds[0] = body
        sounds[1] = kick_sub
        sounds[2] = mech
        sounds[3] = tail
        sounds[4] = transient

    return sounds


## Hides the `sounds` export from the inspector and disables storage
func _validate_property(property: Dictionary) -> void:
    super._validate_property(property)

    if property.name == 'sounds':
        property.usage = PROPERTY_USAGE_NONE
