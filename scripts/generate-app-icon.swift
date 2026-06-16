#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: generate-app-icon.swift <output-iconset>\n", stderr)
    exit(2)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("Sources/PromptNow/Resources/AppIconSource.png")
let outputURL = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

guard let image = NSImage(contentsOf: sourceURL) else {
    fputs("Could not read \(sourceURL.path)\n", stderr)
    exit(1)
}

let icons: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in icons {
    let resized = NSImage(size: NSSize(width: size, height: size))
    resized.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .sourceOver, fraction: 1)
    resized.unlockFocus()

    guard let tiff = resized.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not render \(name)")
    }

    try png.write(to: outputURL.appendingPathComponent(name))
}
