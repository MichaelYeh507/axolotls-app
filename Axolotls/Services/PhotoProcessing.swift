//
//  PhotoProcessing.swift
//  Axolotls
//
//  Part C (Photos). Turns a captured or picked image into the JPEG we upload:
//  upright, at most 2048 px on the long side, 80% quality (usually 300–700 KB
//  instead of several MB straight off the camera).
//

import UIKit

enum PhotoProcessing {
    static let maxDimension: CGFloat = 2048
    static let jpegQuality: CGFloat = 0.8

    /// Accepts any format UIImage can read (camera HEIC, JPEG, PNG, ...).
    static func uploadJPEG(from imageData: Data,
                           maxDimension: CGFloat = maxDimension,
                           quality: CGFloat = jpegQuality) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        return uploadJPEG(from: image, maxDimension: maxDimension, quality: quality)
    }

    static func uploadJPEG(from image: UIImage,
                           maxDimension: CGFloat = maxDimension,
                           quality: CGFloat = jpegQuality) -> Data? {
        let pixelSize = CGSize(width: image.size.width * image.scale,
                               height: image.size.height * image.scale)
        let size = scaledSize(for: pixelSize, maxDimension: maxDimension)
        guard size.width >= 1, size.height >= 1 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1                // size is in pixels
        format.opaque = true
        // Drawing applies the photo's orientation, so the result is always upright.
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: quality)
    }

    /// Shrinks `size` to fit `maxDimension` on its long side, keeping the aspect
    /// ratio. Smaller images keep their size.
    static func scaledSize(for size: CGSize, maxDimension: CGFloat) -> CGSize {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else {
            return CGSize(width: size.width.rounded(), height: size.height.rounded())
        }
        let scale = maxDimension / longest
        return CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }
}
