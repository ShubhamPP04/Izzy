//
//  TidalQualityBadge.swift
//  Izzy
//
//  Quality badge component for Tidal tracks
//

import SwiftUI

// MARK: - Tidal Quality Badge

struct TidalQualityBadge: View {
    let quality: String
    
    var body: some View {
        if let badgeInfo = qualityBadgeInfo {
            Text(badgeInfo.text)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(badgeInfo.color)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(badgeInfo.color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(badgeInfo.color.opacity(0.5), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
    
    private var qualityBadgeInfo: (text: String, color: Color)? {
        switch quality.uppercased() {
        case "HI_RES_LOSSLESS", "HI_RES":
            // Hi-Res badge - gold/amber for premium quality
            return ("Hi-Res", Color(red: 0.85, green: 0.65, blue: 0.13)) // Gold
        case "LOSSLESS":
            // Lossless badge - cyan/teal for CD quality
            return ("Lossless", Color(red: 0.0, green: 0.75, blue: 0.75)) // Teal
        case "HIGH":
            // High quality AAC - subtle gray
            return ("HQ", Color.secondary)
        case "LOW":
            return nil // Don't show badge for low quality
        default:
            return nil
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        HStack {
            Text("Hi-Res Lossless:")
            TidalQualityBadge(quality: "HI_RES_LOSSLESS")
        }
        HStack {
            Text("Lossless:")
            TidalQualityBadge(quality: "LOSSLESS")
        }
        HStack {
            Text("High Quality:")
            TidalQualityBadge(quality: "HIGH")
        }
    }
    .padding()
}
