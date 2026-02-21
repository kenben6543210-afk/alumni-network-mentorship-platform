;; title: alumni_network_mentorship_platform
;; version: 1.0.0
;; summary: Smart contract for Alumni Network Mentorship Platform

(define-constant ERR-NOT-FOUND u404)
(define-constant ERR-UNAUTHORIZED u401)
(define-constant ERR-ALREADY-EXISTS u409)
(define-constant ERR-INVALID-INPUT u400)
(define-constant ERR-INACTIVE-MENTOR u403)

(define-data-var platform-admin principal tx-sender)
(define-data-var total-mentors uint u0)
(define-data-var total-mentees uint u0)

(define-map mentors
  { mentor-id: principal }
  {
    name: (string-ascii 100),
    expertise: (string-ascii 200),
    bio: (string-ascii 500),
    hourly-rate: uint,
    is-active: bool,
    created-at: uint,
    total-mentees: uint
  }
)

(define-map mentees
  { mentee-id: principal }
  {
    name: (string-ascii 100),
    goals: (string-ascii 500),
    created-at: uint,
    assigned-mentor: (optional principal)
  }
)

(define-map mentorship-sessions
  { session-id: uint }
  {
    mentor: principal,
    mentee: principal,
    started-at: uint,
    completed: bool,
    feedback-score: (optional uint)
  }
)

(define-data-var session-counter uint u0)

(define-public (register-mentor (name (string-ascii 100)) (expertise (string-ascii 200)) (bio (string-ascii 500)) (rate uint))
  (let
    ((mentor-addr tx-sender))
    (if (is-some (map-get? mentors { mentor-id: mentor-addr }))
      (err ERR-ALREADY-EXISTS)
      (begin
        (map-set mentors
          { mentor-id: mentor-addr }
          {
            name: name,
            expertise: expertise,
            bio: bio,
            hourly-rate: rate,
            is-active: true,
            created-at: burn-block-height,
            total-mentees: u0
          }
        )
        (var-set total-mentors (+ (var-get total-mentors) u1))
        (ok true)
      )
    )
  )
)

(define-public (register-mentee (name (string-ascii 100)) (goals (string-ascii 500)))
  (let
    ((mentee-addr tx-sender))
    (if (is-some (map-get? mentees { mentee-id: mentee-addr }))
      (err ERR-ALREADY-EXISTS)
      (begin
        (map-set mentees
          { mentee-id: mentee-addr }
          {
            name: name,
            goals: goals,
            created-at: burn-block-height,
            assigned-mentor: none
          }
        )
        (var-set total-mentees (+ (var-get total-mentees) u1))
        (ok true)
      )
    )
  )
)

(define-public (request-mentorship (mentor principal))
  (let
    ((mentee-addr tx-sender)
     (mentor-data (map-get? mentors { mentor-id: mentor })))
    (if (is-none mentor-data)
      (err ERR-NOT-FOUND)
      (if (not (get is-active (unwrap! mentor-data ERR-NOT-FOUND)))
        (err ERR-INACTIVE-MENTOR)
        (let
          ((mentee-data (map-get? mentees { mentee-id: mentee-addr })))
          (if (is-none mentee-data)
            (err ERR-NOT-FOUND)
            (begin
              (map-set mentees
                { mentee-id: mentee-addr }
                (merge (unwrap! mentee-data ERR-NOT-FOUND) { assigned-mentor: (some mentor) })
              )
              (ok true)
            )
          )
        )
      )
    )
  )
)

(define-public (complete-session (session-id uint) (feedback-score uint))
  (let
    ((session (map-get? mentorship-sessions { session-id: session-id })))
    (if (is-none session)
      (err ERR-NOT-FOUND)
      (if (not (is-eq (get mentee (unwrap! session ERR-NOT-FOUND)) tx-sender))
        (err ERR-UNAUTHORIZED)
        (begin
          (map-set mentorship-sessions
            { session-id: session-id }
            (merge (unwrap! session ERR-NOT-FOUND) { completed: true, feedback-score: (some feedback-score) })
          )
          (ok true)
        )
      )
    )
  )
)

(define-public (deactivate-mentor-profile)
  (let
    ((mentor-data (map-get? mentors { mentor-id: tx-sender })))
    (if (is-none mentor-data)
      (err ERR-NOT-FOUND)
      (begin
        (map-set mentors
          { mentor-id: tx-sender }
          (merge (unwrap! mentor-data ERR-NOT-FOUND) { is-active: false })
        )
        (ok true)
      )
    )
  )
)

(define-read-only (get-mentor-profile (mentor principal))
  (map-get? mentors { mentor-id: mentor })
)

(define-read-only (get-mentee-profile (mentee principal))
  (map-get? mentees { mentee-id: mentee })
)

(define-read-only (get-platform-stats)
  {
    total-mentors: (var-get total-mentors),
    total-mentees: (var-get total-mentees),
    active-sessions: (var-get session-counter)
  }
)
