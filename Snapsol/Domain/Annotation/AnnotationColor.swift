struct AnnotationColor: Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    static let red = AnnotationColor(red: 0.96, green: 0.23, blue: 0.21)
    static let orange = AnnotationColor(red: 1.0, green: 0.58, blue: 0.0)
    static let yellow = AnnotationColor(red: 1.0, green: 0.84, blue: 0.04)
    static let green = AnnotationColor(red: 0.2, green: 0.78, blue: 0.35)
    static let blue = AnnotationColor(red: 0.0, green: 0.48, blue: 1.0)
    static let purple = AnnotationColor(red: 0.69, green: 0.32, blue: 0.87)
    static let black = AnnotationColor(red: 0.1, green: 0.1, blue: 0.1)
    static let white = AnnotationColor(red: 1.0, green: 1.0, blue: 1.0)

    static let palette: [AnnotationColor] = [.red, .orange, .yellow, .green, .blue, .purple, .black, .white]
}
