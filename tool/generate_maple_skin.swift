#!/usr/bin/env swift

import AppKit
import Foundation

let fileManager = FileManager.default
let projectRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let skinDirectory = projectRoot.appendingPathComponent("assets/skins/maple")
let piecesDirectory = skinDirectory.appendingPathComponent("pieces")

try fileManager.createDirectory(
  at: piecesDirectory,
  withIntermediateDirectories: true
)

func loadImage(_ name: String) throws -> NSImage {
  let url = skinDirectory.appendingPathComponent(name)
  guard let image = NSImage(contentsOf: url) else {
    throw NSError(
      domain: "MapleSkinGenerator",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Unable to load \(url.path)"]
    )
  }
  return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
  guard
    let data = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: data),
    let png = bitmap.representation(using: .png, properties: [:])
  else {
    throw NSError(
      domain: "MapleSkinGenerator",
      code: 2,
      userInfo: [NSLocalizedDescriptionKey: "Unable to encode \(url.path)"]
    )
  }
  try png.write(to: url)
}

func drawLine(_ start: NSPoint, _ end: NSPoint, width: CGFloat = 1.8) {
  let path = NSBezierPath()
  path.lineWidth = width
  path.move(to: start)
  path.line(to: end)
  path.stroke()
}

func generateBoard() throws {
  let texture = try loadImage("board-texture.png")
  let size = NSSize(width: 900, height: 1000)
  let image = NSImage(size: size)
  image.lockFocus()

  NSColor(calibratedRed: 0.82, green: 0.64, blue: 0.40, alpha: 1).setFill()
  NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

  // The generated source has a vignette. Use only its evenly lit center.
  let cropSide = min(texture.size.width, texture.size.height) * 0.68
  let cropRect = NSRect(
    x: (texture.size.width - cropSide) / 2,
    y: (texture.size.height - cropSide) / 2,
    width: cropSide,
    height: cropSide
  )
  texture.draw(
    in: NSRect(origin: .zero, size: size),
    from: cropRect,
    operation: .sourceOver,
    fraction: 0.88
  )

  let cell: CGFloat = 100
  let left: CGFloat = 50
  let right: CGFloat = 850
  let bottom: CGFloat = 50
  let top: CGFloat = 950
  let riverBottom: CGFloat = 450
  let riverTop: CGFloat = 550
  let ink = NSColor(calibratedRed: 0.31, green: 0.20, blue: 0.13, alpha: 0.82)
  ink.setStroke()

  for rank in 0..<10 {
    let y = bottom + CGFloat(rank) * cell
    drawLine(NSPoint(x: left, y: y), NSPoint(x: right, y: y))
  }

  for file in 0..<9 {
    let x = left + CGFloat(file) * cell
    if file == 0 || file == 8 {
      drawLine(NSPoint(x: x, y: bottom), NSPoint(x: x, y: top))
    } else {
      drawLine(NSPoint(x: x, y: bottom), NSPoint(x: x, y: riverBottom))
      drawLine(NSPoint(x: x, y: riverTop), NSPoint(x: x, y: top))
    }
  }

  drawLine(NSPoint(x: 350, y: 50), NSPoint(x: 550, y: 250))
  drawLine(NSPoint(x: 550, y: 50), NSPoint(x: 350, y: 250))
  drawLine(NSPoint(x: 350, y: 750), NSPoint(x: 550, y: 950))
  drawLine(NSPoint(x: 550, y: 750), NSPoint(x: 350, y: 950))

  let frame = NSBezierPath(rect: NSRect(x: 27, y: 27, width: 846, height: 946))
  frame.lineWidth = 3.2
  frame.stroke()
  let innerFrame = NSBezierPath(rect: NSRect(x: 35, y: 35, width: 830, height: 930))
  innerFrame.lineWidth = 1.2
  innerFrame.stroke()

  let paragraph = NSMutableParagraphStyle()
  paragraph.alignment = .center
  let textAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "Kaiti SC", size: 38)
      ?? NSFont.systemFont(ofSize: 36, weight: .medium),
    .foregroundColor: ink,
    .paragraphStyle: paragraph,
    .kern: 8,
  ]
  ("楚河" as NSString).draw(
    in: NSRect(x: 115, y: 456, width: 250, height: 54),
    withAttributes: textAttributes
  )
  ("汉界" as NSString).draw(
    in: NSRect(x: 535, y: 456, width: 250, height: 54),
    withAttributes: textAttributes
  )

  image.unlockFocus()
  try writePNG(image, to: skinDirectory.appendingPathComponent("board.png"))
}

func generatePiece(
  base: NSImage,
  glyph: String,
  color: NSColor,
  filename: String
) throws {
  let size = NSSize(width: 192, height: 192)
  let image = NSImage(size: size)
  image.lockFocus()
  base.draw(
    in: NSRect(x: 5, y: 5, width: 182, height: 182),
    from: NSRect(origin: .zero, size: base.size),
    operation: .sourceOver,
    fraction: 1
  )

  color.setStroke()
  let ring = NSBezierPath(ovalIn: NSRect(x: 39, y: 39, width: 114, height: 114))
  ring.lineWidth = 3
  ring.stroke()

  let paragraph = NSMutableParagraphStyle()
  paragraph.alignment = .center
  let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "Kaiti SC", size: 76)
      ?? NSFont.systemFont(ofSize: 74, weight: .semibold),
    .foregroundColor: color,
    .paragraphStyle: paragraph,
  ]
  (glyph as NSString).draw(
    in: NSRect(x: 26, y: 49, width: 140, height: 98),
    withAttributes: attributes
  )

  image.unlockFocus()
  try writePNG(image, to: piecesDirectory.appendingPathComponent(filename))
}

func generatePieces() throws {
  let base = try loadImage("piece-token.png")
  let red = NSColor(calibratedRed: 0.58, green: 0.16, blue: 0.15, alpha: 1)
  let black = NSColor(calibratedRed: 0.23, green: 0.16, blue: 0.12, alpha: 1)
  let redPieces = [
    ("k", "帅"), ("a", "仕"), ("b", "相"), ("n", "马"),
    ("r", "车"), ("c", "炮"), ("p", "兵"),
  ]
  let blackPieces = [
    ("k", "将"), ("a", "士"), ("b", "象"), ("n", "马"),
    ("r", "车"), ("c", "炮"), ("p", "卒"),
  ]
  for (code, glyph) in redPieces {
    try generatePiece(base: base, glyph: glyph, color: red, filename: "r\(code).png")
  }
  for (code, glyph) in blackPieces {
    try generatePiece(base: base, glyph: glyph, color: black, filename: "b\(code).png")
  }
}

try generateBoard()
try generatePieces()
print("Generated maple skin assets in \(skinDirectory.path)")
