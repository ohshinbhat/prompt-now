#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Crop {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fputs("usage: extract-logo-assets.swift <logo-board.png> <output-dir>\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

guard
    let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
    let sourceImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
else {
    fputs("Could not read \(sourceURL.path)\n", stderr)
    exit(1)
}

// Coordinates are based on the supplied 1254x1254 logo board.
let markCrop = Crop(x: 952, y: 842, width: 190, height: 160)
let appIconCrop = Crop(x: 172, y: 238, width: 410, height: 410)

let mark = cropAndTransparentMask(sourceImage, crop: markCrop, padding: 18, transparentWhites: true)
let appIcon = cropAndTransparentMask(sourceImage, crop: appIconCrop, padding: 0, transparentWhites: false)

try writePNG(mark, to: outputURL.appendingPathComponent("PromptNowMark.png"))
try writePNG(appIcon, to: outputURL.appendingPathComponent("AppIconSource.png"))

func cropAndTransparentMask(_ image: CGImage, crop: Crop, padding: Int, transparentWhites: Bool) -> CGImage {
    guard let cropped = image.cropping(to: CGRect(x: crop.x, y: crop.y, width: crop.width, height: crop.height)) else {
        fatalError("Invalid crop")
    }

    let width = cropped.width
    let height = cropped.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Could not create bitmap context")
    }

    context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))

    var minX = width
    var minY = height
    var maxX = 0
    var maxY = 0

    for y in 0..<height {
        for x in 0..<width {
            let index = y * bytesPerRow + x * bytesPerPixel
            let red = pixels[index]
            let green = pixels[index + 1]
            let blue = pixels[index + 2]
            let brightness = (UInt16(red) + UInt16(green) + UInt16(blue)) / 3
            let isWhite = brightness > 232 && abs(Int(red) - Int(green)) < 18 && abs(Int(green) - Int(blue)) < 18

            if transparentWhites && isWhite {
                pixels[index + 3] = 0
            } else if !isWhite || !transparentWhites {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }

    guard transparentWhites else {
        return context.makeImage()!
    }

    let cropMinX = max(0, minX - padding)
    let cropMinY = max(0, minY - padding)
    let cropMaxX = min(width - 1, maxX + padding)
    let cropMaxY = min(height - 1, maxY + padding)
    let outputWidth = max(1, cropMaxX - cropMinX + 1)
    let outputHeight = max(1, cropMaxY - cropMinY + 1)
    let outputBytesPerRow = outputWidth * bytesPerPixel
    var output = [UInt8](repeating: 0, count: outputHeight * outputBytesPerRow)

    for y in 0..<outputHeight {
        for x in 0..<outputWidth {
            let sourceIndex = (cropMinY + y) * bytesPerRow + (cropMinX + x) * bytesPerPixel
            let outputIndex = y * outputBytesPerRow + x * bytesPerPixel
            output[outputIndex] = pixels[sourceIndex]
            output[outputIndex + 1] = pixels[sourceIndex + 1]
            output[outputIndex + 2] = pixels[sourceIndex + 2]
            output[outputIndex + 3] = pixels[sourceIndex + 3]
        }
    }

    guard let outputContext = CGContext(
        data: &output,
        width: outputWidth,
        height: outputHeight,
        bitsPerComponent: 8,
        bytesPerRow: outputBytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Could not create output context")
    }

    return outputContext.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "PromptNowAssets", code: 1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "PromptNowAssets", code: 2)
    }
}
