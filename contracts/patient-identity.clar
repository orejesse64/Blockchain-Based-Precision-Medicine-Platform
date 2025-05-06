;; Patient Identity Contract
;; Securely manages participant profiles

(define-data-var admin principal tx-sender)

;; Data structure for patient profiles
(define-map patients
  { patient-id: (string-utf8 36) }  ;; UUID format
  {
    owner: principal,
    name: (string-utf8 100),
    date-of-birth: uint,  ;; Unix timestamp
    contact-info: (string-utf8 255),
    created-at: uint,
    updated-at: uint
  }
)

;; Track patient IDs by owner
(define-map patient-ids-by-owner
  { owner: principal }
  { ids: (list 10 (string-utf8 36)) }  ;; Limit to 10 IDs per owner
)

;; Create a new patient profile
(define-public (create-patient (patient-id (string-utf8 36)) (name (string-utf8 100)) (date-of-birth uint) (contact-info (string-utf8 255)))
  (let ((current-time (get-block-info? time (- block-height u1))))
    (if (is-some (map-get? patients { patient-id: patient-id }))
      (err u1) ;; Patient ID already exists
      (begin
        ;; Add patient to the map
        (map-set patients
          { patient-id: patient-id }
          {
            owner: tx-sender,
            name: name,
            date-of-birth: date-of-birth,
            contact-info: contact-info,
            created-at: (default-to u0 current-time),
            updated-at: (default-to u0 current-time)
          }
        )
        ;; Update the patient IDs for this owner
        (match (map-get? patient-ids-by-owner { owner: tx-sender })
          existing-entry (map-set patient-ids-by-owner
                          { owner: tx-sender }
                          { ids: (unwrap! (as-max-len? (append (get ids existing-entry) patient-id) u10) (err u3)) })
          (map-set patient-ids-by-owner
            { owner: tx-sender }
            { ids: (list patient-id) })
        )
        (ok true)
      )
    )
  )
)

;; Update an existing patient profile
(define-public (update-patient (patient-id (string-utf8 36)) (name (string-utf8 100)) (contact-info (string-utf8 255)))
  (let ((current-time (get-block-info? time (- block-height u1)))
        (patient-data (map-get? patients { patient-id: patient-id })))
    (match patient-data
      patient-entry (if (is-eq (get owner patient-entry) tx-sender)
                      (begin
                        (map-set patients
                          { patient-id: patient-id }
                          (merge patient-entry {
                            name: name,
                            contact-info: contact-info,
                            updated-at: (default-to u0 current-time)
                          })
                        )
                        (ok true)
                      )
                      (err u2)) ;; Not authorized
      (err u4) ;; Patient not found
    )
  )
)

;; Get patient profile (public read)
(define-read-only (get-patient (patient-id (string-utf8 36)))
  (map-get? patients { patient-id: patient-id })
)

;; Get all patient IDs for the caller
(define-read-only (get-my-patient-ids)
  (default-to { ids: (list) } (map-get? patient-ids-by-owner { owner: tx-sender }))
)
