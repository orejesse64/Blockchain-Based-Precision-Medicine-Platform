;; Outcome Tracking Contract
;; Records treatment effectiveness

(define-data-var admin principal tx-sender)

;; Data structure for outcome records
(define-map outcome-records
  { outcome-id: (string-utf8 36) }  ;; UUID format
  {
    protocol-id: (string-utf8 36),
    patient-id: (string-utf8 36),
    recorder: principal,
    outcome-data: (string-utf8 1000),  ;; Encrypted outcome details
    effectiveness-score: uint,  ;; 0-100 scale
    side-effects: (string-utf8 500),
    timestamp: uint
  }
)

;; Track outcomes by protocol
(define-map outcomes-by-protocol
  { protocol-id: (string-utf8 36) }
  { outcomes: (list 50 (string-utf8 36)) }  ;; Limit to 50 outcomes per protocol
)

;; Add a new outcome record
(define-public (add-outcome-record
                (outcome-id (string-utf8 36))
                (protocol-id (string-utf8 36))
                (patient-id (string-utf8 36))
                (outcome-data (string-utf8 1000))
                (effectiveness-score uint)
                (side-effects (string-utf8 500)))
  (let ((current-time (get-block-info? time (- block-height u1))))
    (if (is-some (map-get? outcome-records { outcome-id: outcome-id }))
      (err u1) ;; Outcome ID already exists
      (begin
        ;; Add outcome to the map
        (map-set outcome-records
          { outcome-id: outcome-id }
          {
            protocol-id: protocol-id,
            patient-id: patient-id,
            recorder: tx-sender,
            outcome-data: outcome-data,
            effectiveness-score: effectiveness-score,
            side-effects: side-effects,
            timestamp: (default-to u0 current-time)
          }
        )
        ;; Update the outcomes for this protocol
        (match (map-get? outcomes-by-protocol { protocol-id: protocol-id })
          existing-entry (map-set outcomes-by-protocol
                          { protocol-id: protocol-id }
                          { outcomes: (unwrap! (as-max-len? (append (get outcomes existing-entry) outcome-id) u50) (err u3)) })
          (map-set outcomes-by-protocol
            { protocol-id: protocol-id }
            { outcomes: (list outcome-id) })
        )
        (ok true)
      )
    )
  )
)

;; Get outcome record
(define-read-only (get-outcome (outcome-id (string-utf8 36)))
  (map-get? outcome-records { outcome-id: outcome-id })
)

;; Get all outcome IDs for a protocol
(define-read-only (get-protocol-outcomes (protocol-id (string-utf8 36)))
  (default-to { outcomes: (list) } (map-get? outcomes-by-protocol { protocol-id: protocol-id }))
)

;; Calculate average effectiveness for a protocol
(define-read-only (get-protocol-effectiveness (protocol-id (string-utf8 36)))
  (let ((outcome-ids (get outcomes (default-to { outcomes: (list) } (map-get? outcomes-by-protocol { protocol-id: protocol-id })))))
    (if (is-eq (len outcome-ids) u0)
      (ok u0)  ;; No outcomes yet
      (let ((total (fold calculate-total outcome-ids u0))
            (count (len outcome-ids)))
        (ok (/ total count))
      )
    )
  )
)

;; Helper function for calculating total effectiveness
(define-private (calculate-total (outcome-id (string-utf8 36)) (current-total uint))
  (match (map-get? outcome-records { outcome-id: outcome-id })
    outcome-entry (+ current-total (get effectiveness-score outcome-entry))
    current-total
  )
)
