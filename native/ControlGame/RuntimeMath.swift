import Foundation
import CoreGraphics

func pointerAxis(_ value: Float) -> Double {
    let magnitude = min(abs(Double(value)), 1)
    guard magnitude > 0.16 else { return 0 }
    return (value < 0 ? -1 : 1) * pow((magnitude - 0.16) / 0.84, 1.7)
}
func boundedPointer(_ point: CGPoint, displays: [CGRect]) -> CGPoint {
    guard !displays.contains(where: { $0.contains(point) }) else { return point }
    return displays.filter { $0.width > 1 && $0.height > 1 }.map { bounds in
        CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX - 1), y: min(max(point.y, bounds.minY), bounds.maxY - 1))
    }.min(by: { hypot($0.x - point.x, $0.y - point.y) < hypot($1.x - point.x, $1.y - point.y) }) ?? point
}

func directionalTarget(frames: [CGRect], origin: CGPoint, dx: Double, dy: Double) -> Int? {
    var best: (Int, Double)?
    for (index, frame) in frames.enumerated() {
        let x = frame.midX - origin.x, y = frame.midY - origin.y
        let forward = x * dx + y * dy
        guard forward > 4 else { continue }
        let sideways = abs(x * dy - y * dx)
        let score = hypot(x, y) + sideways * 1.5
        if best == nil || score < best!.1 { best = (index, score) }
    }
    return best?.0
}
