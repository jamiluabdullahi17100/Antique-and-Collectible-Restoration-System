;; Cost and Timeline Management Contract
;; Handles financial operations, escrow, and milestone-based payments

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-PROJECT-NOT-FOUND (err u301))
(define-constant ERR-INSUFFICIENT-FUNDS (err u302))
(define-constant ERR-INVALID-INPUT (err u303))
(define-constant ERR-PAYMENT-NOT-FOUND (err u304))
(define-constant ERR-MILESTONE-NOT-FOUND (err u305))
(define-constant ERR-ALREADY-PAID (err u306))
(define-constant ERR-ESCROW-LOCKED (err u307))
(define-constant ERR-INVALID-STATUS (err u308))
(define-constant ERR-DEADLINE-PASSED (err u309))

;; Payment status definitions
(define-constant PAYMENT-PENDING u0)
(define-constant PAYMENT-ESCROWED u1)
(define-constant PAYMENT-RELEASED u2)
(define-constant PAYMENT-REFUNDED u3)
(define-constant PAYMENT-DISPUTED u4)

;; Cost category definitions
(define-constant COST-MATERIALS u0)
(define-constant COST-LABOR u1)
(define-constant COST-TOOLS u2)
(define-constant COST-CONSULTATION u3)
(define-constant COST-SHIPPING u4)
(define-constant COST-INSURANCE u5)
(define-constant COST-OTHER u6)

;; Data Variables
(define-data-var next-payment-id uint u1)
(define-data-var next-estimate-id uint u1)
(define-data-var contract-active bool true)
(define-data-var platform-fee-percentage uint u250) ;; 2.5%
(define-data-var escrow-timeout-blocks uint u1440) ;; ~10 days

;; Data Maps
(define-map project-estimates
  { project-id: uint }
  {
    estimate-id: uint,
    total-cost: uint,
    estimated-duration: uint,
    created-by: principal,
    created-at: uint,
    approved: bool,
    approved-by: (optional principal),
    approved-at: (optional uint)
  }
)

(define-map cost-breakdowns
  { estimate-id: uint, category: uint }
  {
    description: (string-ascii 200),
    amount: uint,
    quantity: uint,
    unit-cost: uint,
    notes: (string-ascii 300)
  }
)

(define-map milestone-payments
  { project-id: uint, milestone-id: uint }
  {
    payment-id: uint,
    amount: uint,
    due-date: uint,
    status: uint,
    escrowed-at: (optional uint),
    released-at: (optional uint),
    description: (string-ascii 200)
  }
)

(define-map payment-escrows
  { payment-id: uint }
  {
    payer: principal,
    payee: principal,
    amount: uint,
    escrowed-at: uint,
    release-deadline: uint,
    status: uint,
    dispute-reason: (optional (string-ascii 300))
  }
)

(define-map project-budgets
  { project-id: uint }
  {
    total-budget: uint,
    spent-amount: uint,
    escrowed-amount: uint,
    remaining-budget: uint,
    last-updated: uint,
    budget-owner: principal
  }
)

(define-map timeline-milestones
  { project-id: uint, milestone-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 300),
    start-date: uint,
    due-date: uint,
    actual-completion: (optional uint),
    payment-percentage: uint,
    dependencies: (list 5 uint),
    status: uint
  }
)

(define-map authorized-estimators
  { estimator: principal }
  { authorized: bool }
)

;; Read-only functions

(define-read-only (get-project-estimate (project-id uint))
  (map-get? project-estimates { project-id: project-id })
)

(define-read-only (get-cost-breakdown (estimate-id uint) (category uint))
  (map-get? cost-breakdowns { estimate-id: estimate-id, category: category })
)

(define-read-only (get-milestone-payment (project-id uint) (milestone-id uint))
  (map-get? milestone-payments { project-id: project-id, milestone-id: milestone-id })
)

(define-read-only (get-payment-escrow (payment-id uint))
  (map-get? payment-escrows { payment-id: payment-id })
)

(define-read-only (get-project-budget (project-id uint))
  (map-get? project-budgets { project-id: project-id })
)

(define-read-only (get-timeline-milestone (project-id uint) (milestone-id uint))
  (map-get? timeline-milestones { project-id: project-id, milestone-id: milestone-id })
)

(define-read-only (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-percentage)) u10000)
)

(define-read-only (get-total-project-cost (project-id uint))
  (let ((estimate (get-project-estimate project-id)))
    (if (is-some estimate)
      (get total-cost (unwrap-panic estimate))
      u0
    )
  )
)

(define-read-only (is-payment-overdue (project-id uint) (milestone-id uint))
  (let ((payment (get-milestone-payment project-id milestone-id)))
    (if (is-some payment)
      (let ((payment-data (unwrap-panic payment)))
        (and
          (is-eq (get status payment-data) PAYMENT-PENDING)
          (> block-height (get due-date payment-data))
        )
      )
      false
    )
  )
)

(define-read-only (is-authorized-estimator (estimator principal))
  (default-to false (get authorized (map-get? authorized-estimators { estimator: estimator })))
)

;; Public functions

(define-public (create-project-estimate
  (project-id uint)
  (total-cost uint)
  (estimated-duration uint)
)
  (let ((estimate-id (var-get next-estimate-id)))
    (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (or (is-authorized-estimator tx-sender) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    (asserts! (> total-cost u0) ERR-INVALID-INPUT)
    (asserts! (> estimated-duration u0) ERR-INVALID-INPUT)

    (map-set project-estimates
      { project-id: project-id }
      {
        estimate-id: estimate-id,
        total-cost: total-cost,
        estimated-duration: estimated-duration,
        created-by: tx-sender,
        created-at: block-height,
        approved: false,
        approved-by: none,
        approved-at: none
      }
    )

    (var-set next-estimate-id (+ estimate-id u1))
    (ok estimate-id)
  )
)

(define-public (add-cost-breakdown
  (estimate-id uint)
  (category uint)
  (description (string-ascii 200))
  (amount uint)
  (quantity uint)
  (unit-cost uint)
  (notes (string-ascii 300))
)
  (begin
    (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (or (is-authorized-estimator tx-sender) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    (asserts! (<= category COST-OTHER) ERR-INVALID-INPUT)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (> quantity u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)

    (map-set cost-breakdowns
      { estimate-id: estimate-id, category: category }
      {
        description: description,
        amount: amount,
        quantity: quantity,
        unit-cost: unit-cost,
        notes: notes
      }
    )

    (ok true)
  )
)

(define-public (approve-estimate (project-id uint))
  (let ((estimate (unwrap! (get-project-estimate project-id) ERR-PROJECT-NOT-FOUND)))
    (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (not (get approved estimate)) ERR-INVALID-STATUS)

    (map-set project-estimates
      { project-id: project-id }
      (merge estimate {
        approved: true,
        approved-by: (some tx-sender),
        approved-at: (some block-height)
      })
    )

    ;; Initialize project budget
    (map-set project-budgets
      { project-id: project-id }
      {
        total-budget: (get total-cost estimate),
        spent-amount: u0,
        escrowed-amount: u0,
        remaining-budget: (get total-cost estimate),
        last-updated: block-height,
        budget-owner: tx-sender
      }
    )

    (ok true)
  )
)

(define-public (create-milestone-payment
  (project-id uint)
  (milestone-id uint)
  (amount uint)
  (due-date uint)
  (description (string-ascii 200))
)
  (let ((payment-id (var-get next-payment-id)))
    (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (> due-date block-height) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)

    (map-set milestone-payments
      { project-id: project-id, milestone-id: milestone-id }
      {
        payment-id: payment-id,
        amount: amount,
        due-date: due-date,
        status: PAYMENT-PENDING,
        escrowed-at: none,
        released-at: none,
        description: description
      }
    )

    (var-set next-payment-id (+ payment-id u1))
    (ok payment-id)
  )
)

(define-public (escrow-payment (project-id uint) (milestone-id uint) (payee principal))
  (let (
    (payment (unwrap! (get-milestone-payment project-id milestone-id) ERR-PAYMENT-NOT-FOUND))
    (budget (unwrap! (get-project-budget project-id) ERR-PROJECT-NOT-FOUND))
  )
    (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status payment) PAYMENT-PENDING) ERR-INVALID-STATUS)
    (asserts! (>= (stx-get-balance tx-sender) (get amount payment)) ERR-INSUFFICIENT-FUNDS)

    (let (
      (payment-id (get payment-id payment))
      (amount (get amount payment))
      (platform-fee (calculate-platform-fee amount))
      (total-amount (+ amount platform-fee))
    )
      ;; Transfer funds to contract
      (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))

      ;; Create escrow record
      (map-set payment-escrows
        { payment-id: payment-id }
        {
          payer: tx-sender,
          payee: payee,
          amount: amount,
          escrowed-at: block-height,
          release-deadline: (+ block-height (var-get escrow-timeout-blocks)),
          status: PAYMENT-ESCROWED,
          dispute-reason: none
        }
      )

      ;; Update payment status
      (map-set milestone-payments
        { project-id: project-id, milestone-id: milestone-id }
        (merge payment {
          status: PAYMENT-ESCROWED,
          escrowed-at: (some block-height)
        })
      )

      ;; Update budget
      (map-set project-budgets
        { project-id: project-id }
        (merge budget {
          escrowed-amount: (+ (get escrowed-amount budget) amount),
          remaining-budget: (- (get remaining-budget budget) amount),
          last-updated: block-height
        })
      )

      (ok payment-id)
    )
  )
)

(define-public (release-payment (project-id uint) (milestone-id uint))
  (let (
    (payment (unwrap! (get-milestone-payment project-id milestone-id) ERR-PAYMENT-NOT-FOUND))
    (escrow (unwrap! (get-payment-escrow (get payment-id payment)) ERR-PAYMENT-NOT-FOUND))
    (budget (unwrap! (get-project-budget project-id) ERR-PROJECT-NOT-FOUND))
  )
    (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status payment) PAYMENT-ESCROWED) ERR-INVALID-STATUS)
    (asserts! (or
      (is-eq tx-sender (get payer escrow))
      (is-eq tx-sender CONTRACT-OWNER)
    ) ERR-NOT-AUTHORIZED)

    (let ((amount (get amount escrow)))
      ;; Transfer funds to payee
      (try! (as-contract (stx-transfer? amount tx-sender (get payee escrow))))

      ;; Update escrow status
      (map-set payment-escrows
        { payment-id: (get payment-id payment) }
        (merge escrow { status: PAYMENT-RELEASED })
      )

      ;; Update payment status
      (map-set milestone-payments
        { project-id: project-id, milestone-id: milestone-id }
        (merge payment {
          status: PAYMENT-RELEASED,
          released-at: (some block-height)
        })
      )

      ;; Update budget
      (map-set project-budgets
        { project-id: project-id }
        (merge budget {
          spent-amount: (+ (get spent-amount budget) amount),
          escrowed-amount: (- (get escrowed-amount budget) amount),
          last-updated: block-height
        })
      )

      (ok true)
    )
  )
)

(define-public (refund-payment (project-id uint) (milestone-id uint) (reason (string-ascii 300)))
  (let (
    (payment (unwrap! (get-milestone-payment project-id milestone-id) ERR-PAYMENT-NOT-FOUND))
    (escrow (unwrap! (get-payment-escrow (get payment-id payment)) ERR-PAYMENT-NOT-FOUND))
    (budget (unwrap! (get-project-budget project-id) ERR-PROJECT-NOT-FOUND))
  )
    (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status payment) PAYMENT-ESCROWED) ERR-INVALID-STATUS)
    (asserts! (or
      (is-eq tx-sender (get payee escrow))
      (is-eq tx-sender CONTRACT-OWNER)
      (> block-height (get release-deadline escrow))
    ) ERR-NOT-AUTHORIZED)

    (let ((amount (get amount escrow)))
      ;; Refund to payer
      (try! (as-contract (stx-transfer? amount tx-sender (get payer escrow))))

      ;; Update escrow status
      (map-set payment-escrows
        { payment-id: (get payment-id payment) }
        (merge escrow {
          status: PAYMENT-REFUNDED,
          dispute-reason: (some reason)
        })
      )

      ;; Update payment status
      (map-set milestone-payments
        { project-id: project-id, milestone-id: milestone-id }
        (merge payment { status: PAYMENT-REFUNDED })
      )

      ;; Update budget
      (map-set project-budgets
        { project-id: project-id }
        (merge budget {
          escrowed-amount: (- (get escrowed-amount budget) amount),
          remaining-budget: (+ (get remaining-budget budget) amount),
          last-updated: block-height
        })
      )

      (ok true)
    )
  )
)

(define-public (create-timeline-milestone
  (project-id uint)
  (milestone-id uint)
  (title (string-ascii 100))
  (description (string-ascii 300))
  (start-date uint)
  (due-date uint)
  (payment-percentage uint)
  (dependencies (list 5 uint))
)
  (begin
    (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> due-date start-date) ERR-INVALID-INPUT)
    (asserts! (<= payment-percentage u100) ERR-INVALID-INPUT)

    (map-set timeline-milestones
      { project-id: project-id, milestone-id: milestone-id }
      {
        title: title,
        description: description,
        start-date: start-date,
        due-date: due-date,
        actual-completion: none,
        payment-percentage: payment-percentage,
        dependencies: dependencies,
        status: u0
      }
    )

    (ok true)
  )
)

;; Administrative functions

(define-public (authorize-estimator (estimator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-estimators { estimator: estimator } { authorized: true })
    (ok true)
  )
)

(define-public (revoke-estimator (estimator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-estimators { estimator: estimator } { authorized: false })
    (ok true)
  )
)

(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u1000) ERR-INVALID-INPUT) ;; Max 10%
    (var-set platform-fee-percentage new-fee)
    (ok true)
  )
)

(define-public (update-escrow-timeout (new-timeout uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-timeout u0) ERR-INVALID-INPUT)
    (var-set escrow-timeout-blocks new-timeout)
    (ok true)
  )
)

(define-public (toggle-contract-active)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-active (not (var-get contract-active)))
    (ok (var-get contract-active))
  )
)
