import Foundation
import CryptoKit
import SingVoice

// Private, deliberately *human/externally aligned* boundaries. Never pretend
// the generated speech WAV contains self-verifying phoneme identities.
public struct SpeechSourceManifest: Codable {
    public struct Region: Codable {
        public let syllableId: String
        public let onsetStartFrame: Int
        public let vowelStartFrame: Int
        public let vowelEndFrame: Int

        public init(syllableId: String, onsetStartFrame: Int,
                    vowelStartFrame: Int, vowelEndFrame: Int) {
            self.syllableId = syllableId
            self.onsetStartFrame = onsetStartFrame
            self.vowelStartFrame = vowelStartFrame
            self.vowelEndFrame = vowelEndFrame
        }
    }

    public let schema: String
    public let sourceKind: String
    public let sourceModelOrVoice: String
    public let sourceText: String
    public let sampleRate: Int
    public let sourceWavSHA256: String
    public let rightsDeclaration: String
    public let alignmentStatus: String
    public let release: String
    public let regions: [Region]

    public init(schema: String = "sing.speech-source.v1", sourceKind: String,
                sourceModelOrVoice: String, sourceText: String, sampleRate: Int,
                sourceWavSHA256: String, rightsDeclaration: String,
                alignmentStatus: String, release: String = "not-admitted",
                regions: [Region]) {
        self.schema = schema
        self.sourceKind = sourceKind
        self.sourceModelOrVoice = sourceModelOrVoice
        self.sourceText = sourceText
        self.sampleRate = sampleRate
        self.sourceWavSHA256 = sourceWavSHA256
        self.rightsDeclaration = rightsDeclaration
        self.alignmentStatus = alignmentStatus
        self.release = release
        self.regions = regions
    }
}

public struct DecodedSpeechWav {
    public let sampleRate: Int
    public let samples: [Float]
    public let sha256: String

    // Tests may construct known original signals; production CLI must always
    // obtain this structure through PrivateSpeechWav.read and full-file SHA.
    public init(sampleRate: Int, samples: [Float], sha256: String) {
        self.sampleRate = sampleRate
        self.samples = samples
        self.sha256 = sha256
    }
}

public enum PrivateSpeechWav {
    /// The input WAV is PCM16 mono, with no host-specific audio dependency.
    /// WAV validity and the *whole file's* immutable SHA are verified before use.
    public static func read(url: URL, expectedSHA256: String) throws -> DecodedSpeechWav {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard expectedSHA256.count == 64, expectedSHA256 == digest else {
            throw SingError.invalid("Speech WAV SHA256 mismatch or missing immutable identity")
        }
        guard data.count >= 44,
              String(decoding: data[0..<4], as: UTF8.self) == "RIFF",
              String(decoding: data[8..<12], as: UTF8.self) == "WAVE" else {
            throw SingError.invalid("Not a RIFF/WAVE speech source")
        }
        func u16(_ i: Int) -> Int { Int(data[i]) | Int(data[i + 1]) << 8 }
        func u32(_ i: Int) -> Int {
            Int(data[i]) | Int(data[i + 1]) << 8 |
            Int(data[i + 2]) << 16 | Int(data[i + 3]) << 24
        }
        var offset = 12
        var format: (rate: Int, channels: Int, encoding: Int, bits: Int)?
        var audio: Range<Int>?
        while offset + 8 <= data.count {
            let length = u32(offset + 4)
            let begin = offset + 8
            guard length >= 0, length <= data.count - begin else {
                throw SingError.invalid("WAV chunk length invalid")
            }
            let kind = String(decoding: data[offset..<offset + 4], as: UTF8.self)
            if kind == "fmt " {
                guard length >= 16 else { throw SingError.invalid("WAV fmt chunk too short") }
                format = (u32(begin + 4), u16(begin + 2), u16(begin), u16(begin + 14))
            }
            if kind == "data" {
                guard audio == nil else { throw SingError.invalid("Repeated WAV data chunk") }
                audio = begin..<(begin + length)
            }
            offset = begin + length + (length % 2)
        }
        guard let f = format, let bytes = audio, f.channels == 1, f.encoding == 1,
              f.bits == 16, (16_000...96_000).contains(f.rate),
              bytes.count > 0, bytes.count % 2 == 0 else {
            throw SingError.invalid("Only mono PCM16 16-96 kHz speech WAV is admitted")
        }
        let count = bytes.count / 2
        guard count < 96_000 * 120 else {
            throw SingError.invalid("Speech source exceeds two-minute private experiment bound")
        }
        var samples = [Float]()
        samples.reserveCapacity(count)
        var i = bytes.lowerBound
        while i < bytes.upperBound {
            samples.append(Float(Int16(bitPattern: UInt16(u16(i)))) / 32768)
            i += 2
        }
        return DecodedSpeechWav(sampleRate: f.rate, samples: samples, sha256: digest)
    }
}
