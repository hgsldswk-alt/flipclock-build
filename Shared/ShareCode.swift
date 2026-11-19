import Foundation
import Compression

enum ShareCode {
    static let marker = "#翻页时钟#"
    static let englishMarker = "#FlipClock#"
    static let maxTextLength = 6000
    static let maxJSONLength = 4096
    private struct Payload: Codable { var v: Int; var face: FaceConfiguration }
    static func encode(_ face: FaceConfiguration, locale: Locale = .current) -> String? {
        guard face.isValid, let json = try? JSONEncoder().encode(Payload(v: 1, face: face)), let packed = pack(json) else { return nil }
        let base = packed.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return (locale.language.languageCode?.identifier == "zh" ? marker : englishMarker) + base + "#"
    }
    static func decode(_ text: String) -> FaceConfiguration? {
        guard text.count <= maxTextLength else { return nil }
        let starts = [marker, englishMarker].compactMap { text.range(of: $0) }.sorted { $0.lowerBound < $1.lowerBound }
        guard let start = starts.first, let end = text[start.upperBound...].firstIndex(of: "#") else { return nil }
        let raw = text[start.upperBound..<end].filter { !$0.isWhitespace }
        guard !raw.isEmpty, raw.count % 4 != 1,
              raw.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }) else { return nil }
        var base = raw.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base.count % 4 != 0 { base += "=" }
        guard let packed = Data(base64Encoded: base), let json = unpack(packed),
              let payload = try? JSONDecoder().decode(Payload.self, from: json), payload.v == 1, payload.face.isValid else { return nil }
        return payload.face
    }
    private static func adler(_ bytes: [UInt8]) -> UInt32 {
        var a: UInt32 = 1, b: UInt32 = 0
        for v in bytes { a = (a + UInt32(v)) % 65521; b = (b + a) % 65521 }
        return (b << 16) | a
    }
    static func pack(_ data: Data) -> Data? {
        guard !data.isEmpty, data.count <= maxJSONLength else { return nil }
        let source = [UInt8](data)
        var destination = [UInt8](repeating: 0, count: maxJSONLength + 512)
        let capacity = destination.count
        let count = source.withUnsafeBufferPointer { src in
            destination.withUnsafeMutableBufferPointer { dst in
                compression_encode_buffer(dst.baseAddress!, capacity, src.baseAddress!, source.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard count > 0 else { return nil }
        let check = adler(source)
        return Data([0x78, 0x9c] + Array(destination.prefix(count)) + [UInt8((check >> 24) & 255), UInt8((check >> 16) & 255), UInt8((check >> 8) & 255), UInt8(check & 255)])
    }
    static func unpack(_ data: Data) -> Data? {
        let bytes = [UInt8](data)
        guard bytes.count >= 7, bytes.count <= maxTextLength, bytes[0] & 15 == 8,
              bytes[0] >> 4 <= 7, (Int(bytes[0]) * 256 + Int(bytes[1])) % 31 == 0, bytes[1] & 32 == 0 else { return nil }
        let source = Array(bytes[2..<(bytes.count - 4)])
        var destination = [UInt8](repeating: 0, count: maxJSONLength + 1)
        let capacity = destination.count
        let count = source.withUnsafeBufferPointer { src in
            destination.withUnsafeMutableBufferPointer { dst in
                compression_decode_buffer(dst.baseAddress!, capacity, src.baseAddress!, source.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard count > 0, count <= maxJSONLength else { return nil }
        let json = Array(destination.prefix(count)), tail = Array(bytes.suffix(4))
        let check = tail.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard adler(json) == check else { return nil }
        return Data(json)
    }
}
