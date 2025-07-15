//
//  Difference.swift
//  Composable
//
//  Created by chorim.i on 7/15/25.
//


import Foundation

extension Store {
    struct Difference: CustomStringConvertible {
        let path: String
        let actual: String
        let expected: String
        let label: String

        init(path: String, actual: String, expected: String, label: String) {
            self.path = path
            self.actual = actual
            self.expected = expected
            self.label = label
        }

        init(actual: Any, expected: Any, label: String) {
            self.path = ""
            self.actual = String(describing: actual)
            self.expected = String(describing: expected)
            self.label = label
        }

        func prefix(_ key: String?) -> Difference {
            let newPath = path.isEmpty ? (key ?? "") : "\(path).\(key ?? "")"
            return Difference(path: newPath, actual: actual, expected: expected, label: label)
        }

        var description: String {
            let displayPath = path.isEmpty ? label : path
            return """
            ℹ️ \(label) state has been changed:

            \tOld:
            \t\t🕰️ \(displayPath) = \(formatValue(actual.ellipsis(limit: 1000)))

            \tNew:
            \t\t🚀 \(displayPath) = \(formatValue(expected.ellipsis(limit: 1000)))

            """
        }
        
        private func formatValue(_ value: Any) -> String {
            if let arr = value as? [String] {
                return arr.debugDescriptionWithQuotes()
            }
            return "\(value)"
        }
    }
    
    @MainActor
    private func differences(_ a: Any, _ b: Any, path: String) -> [Difference]  {
        if type(of: a) != type(of: b) {
            return [Difference(path: path, actual: "\(a)", expected: "\(b)", label: String(describing: R.self))]
        }

        if let aArray = arrayify(a),
           let bArray = arrayify(b) {
            var diffs: [Difference] = []
            for i in 0..<max(aArray.count, bArray.count) {
                let aElem = i < aArray.count ? aArray[i] : "nil"
                let bElem = i < bArray.count ? bArray[i] : "nil"
                diffs.append(contentsOf: differences(aElem, bElem, path: "\(path)[\(i)]"))
            }
            return diffs
        }

        let mirrorA = Mirror(reflecting: a)
        let mirrorB = Mirror(reflecting: b)

        guard !mirrorA.children.isEmpty else {
            if "\(a)" == "\(b)" {
                return []
            } else {
                return [Difference(path: path, actual: "\(a)", expected: "\(b)", label: String(describing: R.self))]
            }
        }

        var diffs: [Difference] = []

        for (childA, childB) in zip(mirrorA.children, mirrorB.children) {
            let childLabel = childA.label ?? ""
            let childPath = childLabel.isEmpty ? path : (path.isEmpty ? childLabel : "\(path).\(childLabel)")
            diffs.append(contentsOf: differences(childA.value, childB.value, path: childPath))
        }

        return diffs
    }
    
    @MainActor
    private func arrayify(_ value: Any) -> [Any]? {
        if let array = value as? [Any] {
            return array
        }
        return nil
    }
    
    @MainActor
    func diff<V>(_ a: V, _ b: V, label: String) -> String? {
        let rootPath = "\(label).State"
        let diffs = differences(a, b, path: rootPath)
        guard !diffs.isEmpty else { return nil }

        let grouped = groupedByArrayPrefix(diffs)

        if grouped.count == 1, let (key, changes) = grouped.first, changes.count >= 2 {
            return """
            ℹ️ \(label) state has been changed:

            \tOld:
            \t\t🕰️ \(key) = \(extractArrayDescription(from: a, arrayPath: key))

            \tNew:
            \t\t🚀 \(key) = \(extractArrayDescription(from: b, arrayPath: key))
            """
        }

        return diffs.map(\.description).joined(separator: "\n")
    }
    
    @MainActor
    private func groupedByArrayPrefix(_ diffs: [Store<R>.Difference]) -> [String: [Store<R>.Difference]] {
        Dictionary(grouping: diffs) { diff in
            if let range = diff.path.range(of: #"\[\d+\]$"#, options: .regularExpression) {
                return String(diff.path[..<range.lowerBound])
            } else {
                return diff.path
            }
        }
    }
    
    @MainActor
    private func extractArrayDescription<V>(from value: V, arrayPath: String) -> String {
        let mirror = Mirror(reflecting: value)

        for child in mirror.children {
            if let label = child.label,
               arrayPath.hasSuffix(label),
               let arrayValue = child.value as? [Any] {
                return "[" + arrayValue.map { "\"\($0)\"" }.joined(separator: ", ") + "]"
            }
        }

        return "[]"
    }
    
    @MainActor
    public func _printChanges() -> Self {
        self.setDebugging(true)
        return self
    }
}

extension Store {
    fileprivate struct AnyEquatable: Equatable {
        private let value: Any
        private let equals: (Any) -> Bool

        fileprivate init<T: Equatable>(_ value: T) {
            self.value = value
            self.equals = { ($0 as? T == value) }
        }
        
        static public func ==(lhs: AnyEquatable, rhs: AnyEquatable) -> Bool {
            return lhs.equals(rhs.value)
        }
    }
}

fileprivate extension Array where Element == String {
    func debugDescriptionWithQuotes() -> String {
        let quoted = self.map { "\"\($0)\"" }
        return "[\(quoted.joined(separator: ", "))]"
    }
}

fileprivate extension String {
    /// Returns a truncated version of the string with an ellipsis appended if it exceeds the specified character limit.
    ///
    /// - Parameters:
    ///   - limit: The maximum number of characters to keep before truncation.
    ///   - trailing: The string to append at the end if truncation occurs. Default is `"..."`.
    /// - Returns: A string that is either unchanged (if within limit) or truncated with a trailing string.
    ///
    /// - Example:
    /// ```swift
    /// "This is a long string".ellipsis(limit: 10) // "This is a ..."
    /// "Short".ellipsis(limit: 10) // "Short"
    /// ```
    func ellipsis(limit: Int, trailing: String = "...") -> String {
        guard self.count > limit else { return self }
        let truncated = self.prefix(limit)
        return String(truncated) + trailing
    }
}
