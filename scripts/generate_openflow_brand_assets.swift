#!/usr/bin/env swift

import AppKit
import Foundation

struct PngTarget {
  let relativePath: String
  let size: Int
}

let fileManager = FileManager.default
let repoRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let windowsIconsDir = ProcessInfo.processInfo.environment["OPENFLOW_WINDOWS_ICON_DIR"]

let iconTargets: [PngTarget] = [
  .init(relativePath: "frontend/assets/brand/openflow_glyph.png", size: 1024),
  .init(relativePath: "frontend/web/favicon.png", size: 64),
  .init(relativePath: "frontend/web/icons/Icon-192.png", size: 192),
  .init(relativePath: "frontend/web/icons/Icon-512.png", size: 512),
  .init(relativePath: "frontend/web/icons/Icon-maskable-192.png", size: 192),
  .init(relativePath: "frontend/web/icons/Icon-maskable-512.png", size: 512),
  .init(
    relativePath: "frontend/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png",
    size: 16
  ),
  .init(
    relativePath: "frontend/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png",
    size: 32
  ),
  .init(
    relativePath: "frontend/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png",
    size: 64
  ),
  .init(
    relativePath: "frontend/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png",
    size: 128
  ),
  .init(
    relativePath: "frontend/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png",
    size: 256
  ),
  .init(
    relativePath: "frontend/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png",
    size: 512
  ),
  .init(
    relativePath: "frontend/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png",
    size: 1024
  ),
]

func ensureParentDirectory(for url: URL) throws {
  try fileManager.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
}

func roundedRectPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
  return CGPath(
    roundedRect: rect,
    cornerWidth: radius,
    cornerHeight: radius,
    transform: nil
  )
}

func sparklePath(center: CGPoint, outer: CGFloat, inner: CGFloat) -> CGPath {
  let path = CGMutablePath()
  let points = 8

  for index in 0..<points {
    let angle = CGFloat(index) * .pi / 4 - .pi / 2
    let radius = index.isMultiple(of: 2) ? outer : inner
    let point = CGPoint(
      x: center.x + cos(angle) * radius,
      y: center.y + sin(angle) * radius
    )

    if index == 0 {
      path.move(to: point)
    } else {
      path.addLine(to: point)
    }
  }

  path.closeSubpath()
  return path
}

func drawGlyph(in rect: CGRect, ctx: CGContext) {
  let width = rect.width
  let height = rect.height
  let ink = NSColor(
    calibratedRed: 0.12,
    green: 0.14,
    blue: 0.22,
    alpha: 0.94
  ).cgColor
  let white = NSColor.white.cgColor
  let sparkle = NSColor(
    calibratedRed: 0.13,
    green: 0.97,
    blue: 0.89,
    alpha: 1
  ).cgColor
  let stripe = NSColor(
    calibratedRed: 0.16,
    green: 0.20,
    blue: 0.32,
    alpha: 0.18
  ).cgColor

  let clapRect = CGRect(
    x: rect.minX + width * 0.12,
    y: rect.minY + height * 0.60,
    width: width * 0.50,
    height: height * 0.16
  )
  let bodyRect = CGRect(
    x: rect.minX + width * 0.12,
    y: rect.minY + height * 0.24,
    width: width * 0.58,
    height: height * 0.34
  )

  ctx.setFillColor(white)
  ctx.addPath(
    roundedRectPath(
      clapRect,
      radius: min(clapRect.width, clapRect.height) * 0.26
    )
  )
  ctx.fillPath()

  ctx.saveGState()
  ctx.addPath(
    roundedRectPath(
      clapRect,
      radius: min(clapRect.width, clapRect.height) * 0.26
    )
  )
  ctx.clip()
  ctx.setStrokeColor(stripe)
  ctx.setLineWidth(width * 0.048)

  for index in 0..<4 {
    let offset = CGFloat(index) * width * 0.13
    ctx.move(
      to: CGPoint(
        x: clapRect.minX - width * 0.08 + offset,
        y: clapRect.minY - height * 0.02
      )
    )
    ctx.addLine(
      to: CGPoint(
        x: clapRect.minX + width * 0.06 + offset,
        y: clapRect.maxY + height * 0.04
      )
    )
    ctx.strokePath()
  }
  ctx.restoreGState()

  ctx.setFillColor(white)
  ctx.addPath(
    roundedRectPath(
      bodyRect,
      radius: min(bodyRect.width, bodyRect.height) * 0.18
    )
  )
  ctx.fillPath()

  let playPath = CGMutablePath()
  playPath.move(
    to: CGPoint(x: bodyRect.minX + bodyRect.width * 0.37, y: bodyRect.minY + bodyRect.height * 0.23)
  )
  playPath.addLine(
    to: CGPoint(x: bodyRect.minX + bodyRect.width * 0.37, y: bodyRect.minY + bodyRect.height * 0.77)
  )
  playPath.addLine(
    to: CGPoint(x: bodyRect.minX + bodyRect.width * 0.72, y: bodyRect.minY + bodyRect.height * 0.50)
  )
  playPath.closeSubpath()
  ctx.setFillColor(ink)
  ctx.addPath(playPath)
  ctx.fillPath()

  let starCenter = CGPoint(
    x: rect.minX + width * 0.79,
    y: rect.minY + height * 0.54
  )
  ctx.setFillColor(sparkle)
  ctx.addPath(
    sparklePath(
      center: starCenter,
      outer: width * 0.08,
      inner: width * 0.03
    )
  )
  ctx.fillPath()

  ctx.setFillColor(
    NSColor(
      calibratedRed: 0.52,
      green: 0.99,
      blue: 0.94,
      alpha: 0.95
    ).cgColor
  )
  ctx.fillEllipse(
    in: CGRect(
      x: rect.minX + width * 0.70,
      y: rect.minY + height * 0.38,
      width: width * 0.05,
      height: width * 0.05
    )
  )
  ctx.fillEllipse(
    in: CGRect(
      x: rect.minX + width * 0.84,
      y: rect.minY + height * 0.41,
      width: width * 0.028,
      height: width * 0.028
    )
  )
}

func renderPng(size: Int, draw: (CGContext, CGFloat) -> Void) -> Data {
  guard
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: size,
      pixelsHigh: size,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    ),
    let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
  else {
    fatalError("Unable to create bitmap context")
  }

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = graphicsContext

  let cgSize = CGFloat(size)
  let ctx = graphicsContext.cgContext
  ctx.clear(CGRect(origin: .zero, size: CGSize(width: cgSize, height: cgSize)))
  ctx.setAllowsAntialiasing(true)
  ctx.interpolationQuality = .high

  draw(ctx, cgSize)

  NSGraphicsContext.restoreGraphicsState()

  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode PNG")
  }
  return data
}

func drawFullIcon(size: Int) -> Data {
  return renderPng(size: size) { ctx, cgSize in
    let outerRect = CGRect(
      x: cgSize * 0.05,
      y: cgSize * 0.05,
      width: cgSize * 0.90,
      height: cgSize * 0.90
    )
    let radius = cgSize * 0.24

    ctx.saveGState()
    ctx.setShadow(
      offset: CGSize(width: 0, height: -cgSize * 0.03),
      blur: cgSize * 0.08,
      color: NSColor.black.withAlphaComponent(0.26).cgColor
    )
    ctx.addPath(roundedRectPath(outerRect, radius: radius))
    ctx.setFillColor(NSColor.black.withAlphaComponent(0.10).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(roundedRectPath(outerRect, radius: radius))
    ctx.clip()

    let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: [
        NSColor(calibratedRed: 0.49, green: 0.42, blue: 0.94, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.00, green: 0.81, blue: 0.79, alpha: 1).cgColor,
      ] as CFArray,
      locations: [0, 1]
    )!
    ctx.drawLinearGradient(
      gradient,
      start: CGPoint(x: outerRect.minX, y: outerRect.maxY),
      end: CGPoint(x: outerRect.maxX, y: outerRect.minY),
      options: []
    )

    let overlayGradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: [
        NSColor.white.withAlphaComponent(0.16).cgColor,
        NSColor.clear.cgColor,
        NSColor.black.withAlphaComponent(0.14).cgColor,
      ] as CFArray,
      locations: [0, 0.42, 1]
    )!
    ctx.drawLinearGradient(
      overlayGradient,
      start: CGPoint(x: outerRect.minX, y: outerRect.maxY),
      end: CGPoint(x: outerRect.maxX, y: outerRect.minY),
      options: []
    )
    ctx.restoreGState()

    drawGlyph(in: outerRect.insetBy(dx: cgSize * 0.11, dy: cgSize * 0.11), ctx: ctx)
  }
}

func drawGlyphImage(size: Int) -> Data {
  return renderPng(size: size) { ctx, cgSize in
    drawGlyph(
      in: CGRect(
        x: cgSize * 0.08,
        y: cgSize * 0.08,
        width: cgSize * 0.84,
        height: cgSize * 0.84
      ),
      ctx: ctx
    )
  }
}

func writeImage(_ data: Data, to target: PngTarget) throws {
  let url = repoRoot.appendingPathComponent(target.relativePath)
  try ensureParentDirectory(for: url)
  try data.write(to: url)
}

let glyphTarget = iconTargets[0]
try writeImage(drawGlyphImage(size: glyphTarget.size), to: glyphTarget)

for target in iconTargets.dropFirst() {
  try writeImage(drawFullIcon(size: target.size), to: target)
}

if let windowsIconsDir {
  let windowsRoot = URL(fileURLWithPath: windowsIconsDir, isDirectory: true)
  try fileManager.createDirectory(at: windowsRoot, withIntermediateDirectories: true)
  for size in [16, 32, 48, 64, 128, 256] {
    let url = windowsRoot.appendingPathComponent("icon-\(size).png")
    try drawFullIcon(size: size).write(to: url)
  }
}
