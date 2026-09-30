import Foundation
import CoreGraphics

func expect(_ value: Bool, _ message: String) {
    if !value { fatalError(message) }
}
expect(pointerAxis(0) == 0 && pointerAxis(0.15) == 0 && pointerAxis(-0.15) == 0, "Dead zone must stop drift")
expect(pointerAxis(1) == 1 && pointerAxis(-1) == -1, "Full stick speed and sign")
expect(abs(pointerAxis(0.7) + pointerAxis(-0.7)) < 0.000001, "Symmetric movement")
expect(pointerAxis(0.4) < pointerAxis(0.8), "Progressive movement")
let displays = [CGRect(x: 0, y: 0, width: 100, height: 100), CGRect(x: 150, y: -100, width: 100, height: 100)]
expect(boundedPointer(CGPoint(x: 170, y: -50), displays: displays) == CGPoint(x: 170, y: -50), "Second screen with negative coordinates")
expect(boundedPointer(CGPoint(x: 500, y: -50), displays: displays) == CGPoint(x: 249, y: -50), "Clamp to closest screen")
let gap = boundedPointer(CGPoint(x: 125, y: 0), displays: displays)
expect(displays.contains { $0.contains(gap) }, "No cursor in gap between monitors")
expect(boundedPointer(CGPoint(x: 5, y: 5), displays: []) == CGPoint(x: 5, y: 5), "No display data must not jump cursor")
let frames = [CGRect(x: 90, y: 0, width: 20, height: 20), CGRect(x: 140, y: 90, width: 20, height: 20), CGRect(x: 90, y: 140, width: 20, height: 20), CGRect(x: 0, y: 90, width: 20, height: 20)]
let origin = CGPoint(x: 100, y: 100)
for (dx, dy, result) in [(0.0, -1.0, 0), (1.0, 0.0, 1), (0.0, 1.0, 2), (-1.0, 0.0, 3)] {
    expect(directionalTarget(frames: frames, origin: origin, dx: dx, dy: dy) == result, "Directional neighbor")
}
expect(directionalTarget(frames: frames, origin: CGPoint(x: 100, y: 0), dx: 0, dy: -1) == nil, "No wrap at edge")
expect(directionalTarget(frames: [], origin: origin, dx: 1, dy: 0) == nil, "Empty accessibility tree")
print("PASS: drift, acceleration, multiple monitors, gaps, directional navigation and no wrapping")
