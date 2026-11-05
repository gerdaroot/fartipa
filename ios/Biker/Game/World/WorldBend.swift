import SceneKit

/// How much the road ahead curves and climbs. The world itself is built straight and bent on the GPU:
/// a point `ahead` metres in front of the bike moves sideways by `x * ahead²` and up by `y * ahead²`.
/// Moving objects use `offset` and `slope` on the CPU, so everything agrees.
struct BendAmount: Equatable {
    var x: Double
    var y: Double

    static let flat = BendAmount(x: 0, y: 0)

    func offset(ahead: Double) -> (x: Double, y: Double) {
        let a = max(0, ahead)
        return (x * a * a, y * a * a)
    }

    /// Yaw and pitch of the road at that point, to turn objects along it.
    func slope(ahead: Double) -> (yaw: Double, pitch: Double) {
        let a = max(0, ahead)
        return (-atan(2 * x * a), atan(2 * y * a))
    }
}

enum WorldBend {
    private static let sideSlow = 0.00021
    private static let sideFast = 0.00011
    private static let sideSlowWave = 340.0
    private static let sideFastWave = 131.0
    private static let dropBias = -0.000045
    private static let hill = 0.000055
    private static let hillWave = 233.0

    static let keyX = "bendX"
    static let keyY = "bendY"

    /// The bend at a point of the road. Long waves, so it changes slowly while riding.
    static func amount(atDistance distance: Double) -> BendAmount {
        let side = sideSlow * sin(distance / sideSlowWave) + sideFast * sin(distance / sideFastWave + 1.3)
        let rise = dropBias + hill * sin(distance / hillWave + 0.7)
        return BendAmount(x: side, y: rise)
    }

    /// Bends model positions by their distance in front of the bike (world z below 0).
    static let geometryShader = """
    #pragma arguments
    float bendX;
    float bendY;
    #pragma body
    float4 bentWorld = scn_node.modelTransform * _geometry.position;
    float bentAhead = max(0.0, -bentWorld.z);
    bentWorld.x += bendX * bentAhead * bentAhead;
    bentWorld.y += bendY * bentAhead * bentAhead;
    _geometry.position = scn_node.inverseModelTransform * bentWorld;
    """

    static func attach(to material: SCNMaterial) {
        var modifiers = material.shaderModifiers ?? [:]
        modifiers[.geometry] = geometryShader
        material.shaderModifiers = modifiers
        apply(.flat, to: material)
    }

    static func apply(_ amount: BendAmount, to material: SCNMaterial) {
        material.setValue(NSNumber(value: Float(amount.x)), forKey: keyX)
        material.setValue(NSNumber(value: Float(amount.y)), forKey: keyY)
    }
}
