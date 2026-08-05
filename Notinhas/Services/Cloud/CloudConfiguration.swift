//
//  CloudConfiguration.swift
//  Notinhas
//
//  Data model for cloud storage configuration and expire time options
//

import Foundation

// MARK: - Cloud Expire Time

/// Expiration time options for uploaded files.
/// Aligned with AWS S3 / Cloudflare R2 lifecycle rule granularity (days).
enum CloudExpireTime: String, Codable, CaseIterable {
    case day1 = "1d"
    case day3 = "3d"
    case day7 = "7d"
    case day14 = "14d"
    case day30 = "30d"
    case day60 = "60d"
    case day90 = "90d"
    case permanent

    var displayName: String {
        switch self {
        case .day1: L10n.CloudExpire.day1
        case .day3: L10n.CloudExpire.day3
        case .day7: L10n.CloudExpire.day7
        case .day14: L10n.CloudExpire.day14
        case .day30: L10n.CloudExpire.day30
        case .day60: L10n.CloudExpire.day60
        case .day90: L10n.CloudExpire.day90
        case .permanent: L10n.CloudExpire.permanent
        }
    }

    /// Number of days for S3/R2 lifecycle Expiration.Days, nil for permanent
    var days: Int? {
        switch self {
        case .day1: 1
        case .day3: 3
        case .day7: 7
        case .day14: 14
        case .day30: 30
        case .day60: 60
        case .day90: 90
        case .permanent: nil
        }
    }

    /// Duration in seconds, nil for permanent. Used for local isExpired check and Cache-Control.
    var seconds: Int? {
        guard let d = days else { return nil }
        return d * 86400
    }

    var isPermanent: Bool {
        self == .permanent
    }

    /// Decode legacy values (15m, 30m, 1h, etc.) by mapping to nearest day-based option
    init(legacyRawValue: String) {
        switch legacyRawValue {
        case "15m", "30m", "1h", "2h", "3h", "5h", "8h", "12h":
            self = .day1
        case "5d":
            self = .day7
        case "15d":
            self = .day14
        case "24d":
            self = .day30
        default:
            self = CloudExpireTime(rawValue: legacyRawValue) ?? .day7
        }
    }
}

// MARK: - Cloud Configuration

/// Non-sensitive cloud storage configuration stored in UserDefaults
struct CloudConfiguration: Codable, Equatable {
    let providerType: CloudProviderType
    let bucket: String
    let region: String
    let endpoint: String?
    let customDomain: String?
    let expireTime: CloudExpireTime

    /// Validate that required fields are present
    var isValid: Bool {
        switch providerType {
        case .awsS3:
            !bucket.trimmingCharacters(in: .whitespaces).isEmpty
                && !region.trimmingCharacters(in: .whitespaces).isEmpty
        case .cloudflareR2:
            !bucket.trimmingCharacters(in: .whitespaces).isEmpty
                && !(endpoint ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        case .googleDrive:
            // googleDrive doesn't require bucket/region/endpoint fields to be validated here,
            // and default folder name "Notinhas" is used if bucket is empty.
            true
        }
    }
}
