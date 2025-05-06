;; Genomic Data Contract
;; Records genetic information securely

(define-data-var admin principal tx-sender)

;; Data structure for genomic data
(define-map genomic-records
  { record-id: (string-utf8 36) }  ;; UUID format
  {
    patient-id: (string-utf8 36),
    data-hash: (buff 32),  ;; SHA-256 hash of the genomic data
    data-location: (string-utf8 255),  ;; Encrypted reference to where data is stored
    timestamp: uint,
    authorized-viewers: (list 10 principal)
  }
)

;; Track genomic records by patient
(define-map records-by-patient
  { patient-id: (string-utf8 36) }
  { records: (list 20 (string-utf8 36)) }  ;; Limit to 20 records per patient
)

;; Add a new genomic record
(define-public (add-genomic-record
                (record-id (string-utf8 36))
                (patient-id (string-utf8 36))
                (data-hash (buff 32))
                (data-location (string-utf8 255)))
  (let ((current-time (get-block-info? time (- block-height u1))))
    (if (is-some (map-get? genomic-records { record-id: record-id }))
      (err u1) ;; Record ID already exists
      (begin
        ;; Add record to the map
        (map-set genomic-records
          { record-id: record-id }
          {
            patient-id: patient-id,
            data-hash: data-hash,
            data-location: data-location,
            timestamp: (default-to u0 current-time),
            authorized-viewers: (list tx-sender)  ;; Initially, only the creator can view
          }
        )
        ;; Update the records for this patient
        (match (map-get? records-by-patient { patient-id: patient-id })
          existing-entry (map-set records-by-patient
                          { patient-id: patient-id }
                          { records: (unwrap! (as-max-len? (append (get records existing-entry) record-id) u20) (err u3)) })
          (map-set records-by-patient
            { patient-id: patient-id }
            { records: (list record-id) })
        )
        (ok true)
      )
    )
  )
)

;; Authorize a new viewer for a genomic record
(define-public (authorize-viewer (record-id (string-utf8 36)) (viewer principal))
  (let ((record-data (map-get? genomic-records { record-id: record-id })))
    (match record-data
      record-entry (begin
                     (map-set genomic-records
                       { record-id: record-id }
                       (merge record-entry {
                         authorized-viewers: (unwrap! (as-max-len? (append (get authorized-viewers record-entry) viewer) u10) (err u3))
                       })
                     )
                     (ok true)
                   )
      (err u4) ;; Record not found
    )
  )
)

;; Check if a principal is authorized to view a record
(define-read-only (is-authorized (record-id (string-utf8 36)) (viewer principal))
  (match (map-get? genomic-records { record-id: record-id })
    record-entry (some (index-of (get authorized-viewers record-entry) viewer))
    none
  )
)

;; Get genomic record if authorized
(define-read-only (get-genomic-record (record-id (string-utf8 36)))
  (let ((record-data (map-get? genomic-records { record-id: record-id })))
    (match record-data
      record-entry (if (is-some (index-of (get authorized-viewers record-entry) tx-sender))
                     (some record-entry)
                     none)
      none
    )
  )
)

;; Get all record IDs for a patient
(define-read-only (get-patient-records (patient-id (string-utf8 36)))
  (default-to { records: (list) } (map-get? records-by-patient { patient-id: patient-id }))
)
