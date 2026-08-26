//
//  RoundedRingShape.swift
//  ringlight
//

import SwiftUI

struct RoundedRingShape: Shape {
    var thickness: CGFloat
    var cornerRadius: CGFloat
    var margin: CGFloat
    var topOffset: CGFloat = 0
    var showTop: Bool = true
    var showBottom: Bool = true
    var showLeft: Bool = true
    var showRight: Bool = true

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(thickness, cornerRadius) }
        set {
            thickness = newValue.first
            cornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        // If no sides are enabled, return empty path
        if !showTop && !showBottom && !showLeft && !showRight {
            return Path()
        }

        // Fast path: When all 4 sides are active, draw complete closed ring
        if showTop && showBottom && showLeft && showRight {
            var path = Path()
            let outerRect = CGRect(
                x: rect.minX + margin,
                y: rect.minY + margin + topOffset,
                width: max(0, rect.width - margin * 2),
                height: max(0, rect.height - margin * 2 - topOffset)
            )
            path.addRoundedRect(in: outerRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

            let innerRect = CGRect(
                x: rect.minX + margin + thickness,
                y: rect.minY + margin + thickness + topOffset,
                width: max(0, rect.width - (margin + thickness) * 2),
                height: max(0, rect.height - (margin + thickness) * 2 - topOffset)
            )
            let innerCornerRadius: CGFloat
            if cornerRadius > thickness {
                innerCornerRadius = cornerRadius - thickness
            } else {
                innerCornerRadius = max(0, cornerRadius * 0.4)
            }
            path.addRoundedRect(in: innerRect, cornerSize: CGSize(width: innerCornerRadius, height: innerCornerRadius))
            return path
        }

        let minX = rect.minX + margin
        let maxX = rect.maxX - margin
        let minY = rect.minY + margin + topOffset
        let maxY = rect.maxY - margin

        guard maxX > minX, maxY > minY else { return Path() }

        let halfT = thickness / 2
        let topY = minY + halfT
        let bottomY = maxY - halfT
        let leftX = minX + halfT
        let rightX = maxX - halfT

        let R = min(cornerRadius, min((maxX - minX) / 2, (maxY - minY) / 2))
        let Rc = max(0, R - halfT)

        var centerPath = Path()

        let hasTL = showTop && showLeft
        let hasTR = showTop && showRight
        let hasBR = showBottom && showRight
        let hasBL = showBottom && showLeft

        let sideEnabled = [showTop, showRight, showBottom, showLeft]
        let cornerConnected = [hasTR, hasBR, hasBL, hasTL]

        var visited = [false, false, false, false]

        for startIndex in 0..<4 {
            let prevCorner = (startIndex + 3) % 4
            if sideEnabled[startIndex] && !visited[startIndex] && !cornerConnected[prevCorner] {
                var curr = startIndex
                var isFirst = true

                while true {
                    visited[curr] = true

                    switch curr {
                    case 0: // Top
                        let startX = hasTL ? minX + R : leftX
                        let endX = hasTR ? maxX - R : rightX
                        if isFirst {
                            centerPath.move(to: CGPoint(x: startX, y: topY))
                            isFirst = false
                        }
                        centerPath.addLine(to: CGPoint(x: endX, y: topY))

                    case 1: // Right
                        let startY = hasTR ? minY + R : topY
                        let endY = hasBR ? maxY - R : bottomY
                        if isFirst {
                            centerPath.move(to: CGPoint(x: rightX, y: startY))
                            isFirst = false
                        }
                        centerPath.addLine(to: CGPoint(x: rightX, y: endY))

                    case 2: // Bottom
                        let startX = hasBR ? maxX - R : rightX
                        let endX = hasBL ? minX + R : leftX
                        if isFirst {
                            centerPath.move(to: CGPoint(x: startX, y: bottomY))
                            isFirst = false
                        }
                        centerPath.addLine(to: CGPoint(x: endX, y: bottomY))

                    case 3: // Left
                        let startY = hasBL ? maxY - R : bottomY
                        let endY = hasTL ? minY + R : topY
                        if isFirst {
                            centerPath.move(to: CGPoint(x: leftX, y: startY))
                            isFirst = false
                        }
                        centerPath.addLine(to: CGPoint(x: leftX, y: endY))

                    default:
                        break
                    }

                    let nextCorner = curr
                    let nextSide = (curr + 1) % 4
                    if cornerConnected[nextCorner] && !visited[nextSide] {
                        if Rc > 0 {
                            switch nextCorner {
                            case 0: // TR
                                centerPath.addRelativeArc(
                                    center: CGPoint(x: maxX - R, y: minY + R),
                                    radius: Rc,
                                    startAngle: Angle(degrees: 270),
                                    delta: Angle(degrees: 90)
                                )
                            case 1: // BR
                                centerPath.addRelativeArc(
                                    center: CGPoint(x: maxX - R, y: maxY - R),
                                    radius: Rc,
                                    startAngle: Angle(degrees: 0),
                                    delta: Angle(degrees: 90)
                                )
                            case 2: // BL
                                centerPath.addRelativeArc(
                                    center: CGPoint(x: minX + R, y: maxY - R),
                                    radius: Rc,
                                    startAngle: Angle(degrees: 90),
                                    delta: Angle(degrees: 90)
                                )
                            case 3: // TL
                                centerPath.addRelativeArc(
                                    center: CGPoint(x: minX + R, y: minY + R),
                                    radius: Rc,
                                    startAngle: Angle(degrees: 180),
                                    delta: Angle(degrees: 90)
                                )
                            default:
                                break
                            }
                        } else {
                            switch nextCorner {
                            case 0: centerPath.addLine(to: CGPoint(x: rightX, y: topY))
                            case 1: centerPath.addLine(to: CGPoint(x: rightX, y: bottomY))
                            case 2: centerPath.addLine(to: CGPoint(x: leftX, y: bottomY))
                            case 3: centerPath.addLine(to: CGPoint(x: leftX, y: topY))
                            default: break
                            }
                        }
                        curr = nextSide
                    } else {
                        break
                    }
                }
            }
        }

        let cap: CGLineCap = cornerRadius > 0 ? .round : .butt
        return centerPath.strokedPath(StrokeStyle(lineWidth: thickness, lineCap: cap, lineJoin: .round))
    }
}

extension RoundedRingShape {
    func fill(_ content: some ShapeStyle) -> some View {
        self.fill(content, style: FillStyle(eoFill: true))
    }
}
