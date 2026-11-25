// Prints the screen rectangle (x,y,w,h in points) around where banners appear, for screencapture.
import AppKit

let screen = NSScreen.screens[0]
let area = screen.visibleFrame
let width: CGFloat = 340, height: CGFloat = 104
let x = area.maxX - 293 - 34 - 24
let top = screen.frame.maxY - area.maxY
print("\(Int(x)),\(Int(top)),\(Int(width)),\(Int(height))")
