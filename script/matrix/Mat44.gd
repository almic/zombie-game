
## Column-major 4x4 Matrix
class_name Mat44 extends Object

var cols: PackedVector4Array

func _init(columns: PackedVector4Array) -> void:
    cols = columns.duplicate()

static func identity() -> Mat44:
    return Mat44.new([
            Vector4(1, 0, 0, 0),
            Vector4(0, 1, 0, 0),
            Vector4(0, 0, 1, 0),
            Vector4(0, 0, 0, 1)
    ])

static func zero() -> Mat44:
    return Mat44.new([
            Vector4(0, 0, 0, 0),
            Vector4(0, 0, 0, 0),
            Vector4(0, 0, 0, 0),
            Vector4(0, 0, 0, 0)
    ])

static func create(c1: Vector4, c2: Vector4, c3: Vector4, c4: Vector4) -> Mat44:
    var result: Mat44 = Mat44.new([])
    result.cols = [c1, c2, c3, c4]
    return result

static func from_transform(transform: Transform3D) -> Mat44:
    var result: Mat44 = Mat44.new([])
    var b: Basis = transform.basis
    var o: Vector3 = transform.origin
    result.cols = [
        Vector4(b.x.x, b.x.y, b.x.z, 0),
        Vector4(b.y.x, b.y.y, b.y.z, 0),
        Vector4(b.z.x, b.z.y, b.z.z, 0),
        Vector4(o.x,   o.y,   o.z,   1)
    ]
    return result

static func rotation_x(rads: float) -> Mat44:
    var s: float = sin(rads)
    var c: float = cos(rads)

    var result: Mat44 = Mat44.new([])
    result.cols = [
            Vector4(1,  0, 0, 0),
            Vector4(0,  c, s, 0),
            Vector4(0, -s, c, 0),
            Vector4(0,  0, 0, 1)
    ]
    return result

func transposed() -> Mat44:
    var result: Mat44 = Mat44.zero()

    for c in range(4):
        for r in range(4):
            result.cols[r][c] = cols[c][r]

    return result

func to_transform() -> Transform3D:
    return Transform3D(
            Vector3(cols[0][0], cols[0][1], cols[0][2]),
            Vector3(cols[1][0], cols[1][1], cols[1][2]),
            Vector3(cols[2][0], cols[2][1], cols[2][2]),
            Vector3(cols[3][0], cols[3][1], cols[3][2])
    )

func mult(right: Mat44) -> Mat44:
    var result: Mat44 = Mat44.new([])
    result.cols.resize(4)
    for i in range(4):
        # result.mCol[i] = mCol[0] * inM.mCol[i].mF32[0] + mCol[1] * inM.mCol[i].mF32[1] + mCol[2] * inM.mCol[i].mF32[2] + mCol[3] * inM.mCol[i].mF32[3];
        result.cols[i] = cols[0] * right.cols[i][0] + cols[1] * right.cols[i][1] + cols[2] * right.cols[i][2] + cols[3] * right.cols[3]
    return result
