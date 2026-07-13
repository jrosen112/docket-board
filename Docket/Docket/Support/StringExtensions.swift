//
//  StringExtensions.swift
//  Docket
//

import Foundation

nonisolated extension String {
    /// Whitespace/newline-trimmed copy.
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Trimmed value, or nil when empty — for optional CloudKit fields.
    var orNil: String? { trimmed.isEmpty ? nil : trimmed }
}
