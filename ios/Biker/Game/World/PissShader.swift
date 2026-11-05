import SceneKit

/// The shader modifiers of the stream's liquid. Both stream materials carry the same source, so
/// SceneKit compiles one program for them; `PissWarmup` lets loading compile it before the ride.
enum PissShader {
    /// Ripples run down the surface, the radius breathes and the middle of the stream sways like a
    /// hose, while both ends stay put. Model space is the arc frame of `PissArc`.
    static let geometry = """
    #pragma body
    float pissH = clamp(_geometry.position.y / \(PissArc.height), 0.0, 1.0);
    float pissRadius = mix(\(PissArc.bottomRadius), \(PissArc.topRadius), pissH);
    float pissT = scn_frame.time;
    float pissWave = sin(_geometry.position.y * 2.9 - pissT * 19.0 + _geometry.position.x * 1.7)
        + 0.55 * sin(_geometry.position.y * 6.7 + pissT * 11.0 + _geometry.position.z * 9.0);
    _geometry.position.xyz += _geometry.normal * (pissRadius * 0.24 * pissWave);
    float pissSway = 4.0 * pissH * (1.0 - pissH);
    _geometry.position.x += pissSway * 0.18 * sin(pissT * 5.3 + _geometry.position.y * 0.31);
    _geometry.position.z += pissSway * 0.14 * sin(pissT * 4.1 + _geometry.position.y * 0.23 + 1.7);
    """

    /// A wet highlight down the middle of the stream and slightly denser edges, like a real liquid.
    static let surface = """
    #pragma body
    float3 pissN = normalize(_surface.normal);
    float3 pissV = normalize(_surface.view);
    float pissFacing = abs(dot(pissN, pissV));
    _surface.emission.rgb += float3(1.0, 0.96, 0.78) * (pow(pissFacing, 18.0) * 0.5);
    _surface.diffuse.a = clamp(_surface.diffuse.a * (0.75 + 0.6 * (1.0 - pissFacing)), 0.0, 1.0);
    """

    static func attach(to material: SCNMaterial) {
        material.shaderModifiers = [.geometry: geometry, .surface: surface]
    }
}

/// Everything of the stream that SceneKit compiles or uploads on first draw: its materials and a
/// sample node with every mesh and particle system. The render warm-up passes `objects` to
/// `SCNView.prepare(_:shouldAbortBlock:)` during loading. Filled when the first `StreamKit` is made.
@MainActor
enum PissWarmup {
    private(set) static var objects: [Any] = []

    static func register(_ list: [Any]) {
        objects = list
    }
}
