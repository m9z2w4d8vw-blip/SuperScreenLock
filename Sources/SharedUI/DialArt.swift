import UIKit

/// The dial as a small bitmap, for the lock screen icon (which must be a UIImage).
enum DialArt {
    static func image(ticks: Int, side: CGFloat = 64) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { context in
            let c = context.cgContext
            let center = CGPoint(x: side / 2, y: side / 2)
            let radius = side / 2 - 1.5

            c.setStrokeColor(Palette.brass.cgColor)
            c.setLineWidth(1.5)
            c.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))

            let count = max(1, ticks)
            let outer = radius - 4
            let inner = outer - side * 0.13
            c.setLineCap(.round)
            c.setLineWidth(max(1.5, min(3.5, side * 2.4 / CGFloat(count))))
            c.setStrokeColor(Palette.brass.cgColor)
            for index in 0..<count {
                let angle = CGFloat(index) / CGFloat(count) * 2 * .pi - .pi / 2
                c.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                c.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
            }
            c.strokePath()

            // Keyhole
            let hole = side * 0.085
            c.setFillColor(Palette.brass.cgColor)
            c.fillEllipse(in: CGRect(x: center.x - hole, y: center.y - hole * 1.7, width: hole * 2, height: hole * 2))
            c.beginPath()
            c.move(to: CGPoint(x: center.x - hole * 0.5, y: center.y - hole * 0.2))
            c.addLine(to: CGPoint(x: center.x + hole * 0.5, y: center.y - hole * 0.2))
            c.addLine(to: CGPoint(x: center.x + hole * 0.85, y: center.y + hole * 1.9))
            c.addLine(to: CGPoint(x: center.x - hole * 0.85, y: center.y + hole * 1.9))
            c.closePath()
            c.fillPath()
        }
    }
}
