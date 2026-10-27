import AppKit
import ApplicationServices

let origin = CGRect(x: 0, y: 0, width: 250, height: 160)
let right = CGRect(x: 280, y: 0, width: 250, height: 160)
let diagonal = CGRect(x: 270, y: 230, width: 250, height: 160)
let below = CGRect(x: 0, y: 230, width: 250, height: 160)
assert(CardDirection.left.score(from: origin, to: right) == nil)
assert(CardDirection.up.score(from: origin, to: below) == nil)
assert(CardDirection.right.score(from: origin, to: right)! < CardDirection.right.score(from: origin, to: diagonal)!)
assert(CardDirection.down.score(from: origin, to: below)! < CardDirection.down.score(from: origin, to: diagonal)!)
assert(CardDirection.down.score(from: origin, to: origin) == nil)
assert(CardNavigator.isVideo("https://www.youtube.com/watch?v=test"))
assert(CardNavigator.isVideo("https://www.youtube.com/shorts/test"))
assert(!CardNavigator.isVideo("https://www.youtube.com/@channel"))
assert(!CardNavigator.isVideo("https://youtube.com.attacker.example/watch?v=test"))
assert(!CardNavigator.isVideo("https://example.com/watch?v=test"))
print("OK: spatial directions, row/column priority, YouTube links and host validation")
