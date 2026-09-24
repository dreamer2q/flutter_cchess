#!/usr/bin/env swift

import AppKit
import Foundation

let fileManager = FileManager.default
let projectRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let skinDirectory = projectRoot.appendingPathComponent("assets/skins/night")
let piecesDirectory = skinDirectory.appendingPathComponent("pieces")

try fileManager.createDirectory(
  at: piecesDirectory,
  withIntermediateDirectories: true
)

func loadImage(_ name: String) throws -> NSImage {
  let url = skinDirectory.appendingPathComponent(name)
  guard let image = NSImage(contentsOf: url) else {
    throw NSError(
      domain: "NightSkinGenerator",
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
      domain: "NightSkinGenerator",
      code: 2,
      userInfo: [NSLocalizedDescriptionKey: "Unable to encode \(url.path)"]
    )
  }
  try png.write(to: url)
}

func drawLine(_ start: NSPoint, _ end: NSPoint, width: CGFloat = 2.2) {
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

  let sourceSide = min(texture.size.width / 0.9, texture.size.height)
  let sourceWidth = sourceSide * 0.9
  let sourceRect = NSRect(
    x: (texture.size.width - sourceWidth) / 2,
    y: (texture.size.height - sourceSide) / 2,
    width: sourceWidth,
    height: sourceSide
  )
  texture.draw(
    in: NSRect(origin: .zero, size: size),
    from: sourceRect,
    operation: .sourceOver,
    fraction: 1
  )

  NSColor(calibratedWhite: 0.02, alpha: 0.12).setFill()
  NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

  let cell: CGFloat = 100
  let left: CGFloat = 50
  let right: CGFloat = 850
  let bottom: CGFloat = 50
  let top: CGFloat = 950
  let riverBottom: CGFloat = 450
  let riverTop: CGFloat = 550
  NSColor(calibratedRed: 0.88, green: 0.70, blue: 0.43, alpha: 0.96).setStroke()

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

  let frame = NSBezierPath(rect: NSRect(x: 28, y: 28, width: 844, height: 944))
  frame.lineWidth = 4
  frame.stroke()
  let innerFrame = NSBezierPath(rect: NSRect(x: 36, y: 36, width: 828, height: 928))
  innerFrame.lineWidth = 1.5
  innerFrame.stroke()

  let paragraph = NSMutableParagraphStyle()
  paragraph.alignment = .center
  let textAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 36, weight: .semibold),
    .foregroundColor: NSColor(calibratedRed: 0.81, green: 0.60, blue: 0.35, alpha: 1),
    .paragraphStyle: paragraph,
    .kern: 10,
  ]
  ("楚河" as NSString).draw(
    in: NSRect(x: 115, y: 458, width: 250, height: 50),
    withAttributes: textAttributes
  )
  ("汉界" as NSString).draw(
    in: NSRect(x: 535, y: 458, width: 250, height: 50),
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
    in: NSRect(x: 6, y: 6, width: 180, height: 180),
    from: NSRect(origin: .zero, size: base.size),
    operation: .sourceOver,
    fraction: 1
  )

  color.setStroke()
  let ring = NSBezierPath(ovalIn: NSRect(x: 37, y: 37, width: 118, height: 118))
  ring.lineWidth = 4
  ring.stroke()

  let paragraph = NSMutableParagraphStyle()
  paragraph.alignment = .center
  let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 78, weight: .bold),
    .foregroundColor: color,
    .paragraphStyle: paragraph,
  ]
  (glyph as NSString).draw(
    in: NSRect(x: 26, y: 48, width: 140, height: 100),
    withAttributes: attributes
  )

  image.unlockFocus()
  try writePNG(image, to: piecesDirectory.appendingPathComponent(filename))
}

func generatePieces() throws {
  let base = try loadImage("piece-token.png")
  let red = NSColor(calibratedRed: 0.72, green: 0.16, blue: 0.18, alpha: 1)
  let black = NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.10, alpha: 1)
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
print("Generated night skin assets in \(skinDirectory.path)")
