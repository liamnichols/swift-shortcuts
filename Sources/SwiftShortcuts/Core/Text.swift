import Foundation

public struct Text: Hashable {
    public let string: String
    public let variablesByRange: [Range<String.Index>: Variable]
    var allowsEncodingAsRawString = true
}

extension Text: ExpressibleByStringInterpolation {
    public struct StringInterpolation: StringInterpolationProtocol {
        static var objectReplacementCharacter = "\u{fffc}"

        var string: String
        var variablesByRange: [Range<String.Index>: Variable]

        public init(literalCapacity: Int, interpolationCount: Int) {
            var value = ""
            value.reserveCapacity(literalCapacity)
            self.string = value
            self.variablesByRange = [Range<String.Index>: Variable](minimumCapacity: interpolationCount)
        }

        public mutating func appendLiteral(_ literal: String) {
            string.append(literal)
        }

        public mutating func appendInterpolation(_ variable: Variable) {
            let lowerBound = string.endIndex
            string.append(Self.objectReplacementCharacter)
            variablesByRange[lowerBound ..< string.endIndex] = variable
        }

        public mutating func appendInterpolation<T>(literal value: T) {
            string.append(String(describing: value))
        }
    }

    public init(_ string: String) {
        self.string = string
        self.variablesByRange = [:]
    }

    public init(stringLiteral value: String) {
        self.string = value
        self.variablesByRange = [:]
    }

    public init(stringInterpolation: StringInterpolation) {
        self.string = stringInterpolation.string
        self.variablesByRange = stringInterpolation.variablesByRange
    }
}

extension Text: Encodable {
    enum CodingKeys: String, CodingKey {
        case value = "Value"
        case serializationType = "WFSerializationType"
    }

    enum ValueCodingKeys: String, CodingKey {
        case string = "string"
        case attachments = "attachmentsByRange"
    }

    public func encode(to encoder: Encoder) throws {
        if variablesByRange.isEmpty && allowsEncodingAsRawString {
            var container = encoder.singleValueContainer()
            try container.encode(string)
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(SerializationType.textTokenString, forKey: .serializationType)

            var nestedContainer = container.nestedContainer(keyedBy: ValueCodingKeys.self, forKey: .value)
            try nestedContainer.encode(string, forKey: .string)

            var attachmentsByRange = [String: Attachment](minimumCapacity: variablesByRange.count)
            for (range, variable) in variablesByRange {
                let rangeInString = NSRange(range, in: string)
                attachmentsByRange[String(describing: rangeInString)] = variable.value
            }

            try nestedContainer.encode(attachmentsByRange, forKey: .attachments)
        }
    }
}