//
//  CKRecord+SystemFields.swift
//  Docket
//
//  CloudKit rejects an update built from a bare CKRecord(recordType:recordID:)
//  because it lacks the server's record change tag (the default save policy is
//  if-unchanged). So every decoded model keeps an archive of the fetched
//  record's SYSTEM fields (metadata + change tag, no app fields), and
//  toRecord() resurrects that archive as its base. New, never-saved models
//  have no archive and start from a fresh record.
//

import CloudKit

extension CKRecord {

    /// Archive of this record's system metadata (record ID, type, change tag).
    /// App fields are not included — toRecord() re-applies those.
    nonisolated var systemFieldsData: Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    nonisolated static func decodeSystemFields(_ data: Data) -> CKRecord? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        return CKRecord(coder: unarchiver)
    }

    /// The base record for a model's toRecord(): the resurrected fetched record
    /// when system fields are available (so updates carry the change tag), or a
    /// fresh record for never-saved models.
    nonisolated static func base(type: String, id: CKRecord.ID, systemFields: Data?) -> CKRecord {
        if let systemFields,
           let record = decodeSystemFields(systemFields),
           record.recordID == id,
           record.recordType == type {
            return record
        }
        return CKRecord(recordType: type, recordID: id)
    }
}
