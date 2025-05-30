
;; title: StackTax
;; Handles complex tax calculations, multiple currencies, deductions, and detailed reporting

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-TAX-RATE-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-INVALID-TAX-RATE (err u104))
(define-constant ERR-INVALID-CURRENCY (err u105))
(define-constant ERR-INVALID-DEDUCTION (err u106))
(define-constant ERR-REFUND-NOT-ALLOWED (err u107))
(define-constant ERR-INVALID-PERIOD (err u108))
(define-constant ERR-TRANSFER-FAILED (err u109))

;; Data variables
(define-data-var administrator principal tx-sender)
(define-data-var minimum-taxable-amount uint u100) ;; Minimum tax amount in base currency

;; Currency exchange rates (scaled by 1e8)
(define-map currency-exchange-rates
    { currency-code: (string-ascii 10) }
    { exchange-rate: uint,
      rate-update-timestamp: uint,
      currency-status: bool }
)

;; Tax rates with progressive brackets
(define-map income-tax-brackets
    { income-category: (string-ascii 24) }
    {
        tax-brackets: (list 10 {
            income-threshold: uint,
            tax-percentage: uint,
            bracket-description: (string-ascii 64)
        }),
        base-currency: (string-ascii 10),
        bracket-update-timestamp: uint
    }
)

;; Deductions configuration
(define-map available-deductions
    { deduction-code: (string-ascii 10) }
    {
        deduction-name: (string-ascii 64),
        maximum-deduction-amount: uint,
        deduction-percentage: uint,
        approval-required: bool
    }
)

;; Taxpayer records with enhanced tracking
(define-map taxpayer-profiles
    principal
    {
        cumulative-tax-paid: uint,
        cumulative-tax-refunded: uint,
        most-recent-payment: uint,
        taxpayer-category: (string-ascii 24),
        claimed-deductions: (list 20 {
            deduction-code: (string-ascii 10),
            deduction-amount: uint,
            deduction-approved: bool
        }),
        transaction-history: (list 50 {
            transaction-amount: uint,
            transaction-timestamp: uint,
            transaction-currency: (string-ascii 10)
        })
    }
)


;; Private helper for progressive tax calculation
(define-private (calculate-bracket-tax-amount 
    (tax-bracket { income-threshold: uint, tax-percentage: uint, bracket-description: (string-ascii 64) })
    (calculation-state { remaining-income: uint, accumulated-tax: uint }))
    (let (
        (taxable-bracket-amount (if (> (get remaining-income calculation-state) (get income-threshold tax-bracket))
            (- (get remaining-income calculation-state) (get income-threshold tax-bracket))
            u0))
        (bracket-tax-amount (/ (* taxable-bracket-amount (get tax-percentage tax-bracket)) u100))
    )
        { 
            remaining-income: (get remaining-income calculation-state),
            accumulated-tax: (+ (get accumulated-tax calculation-state) bracket-tax-amount)
        }
    )
)

;; Define helper function to update deduction approval
(define-private (update-deduction-approval 
    (index uint) 
    (current-index uint) 
    (deduction { deduction-code: (string-ascii 10), deduction-amount: uint, deduction-approved: bool })
    (target-index uint))
    (if (is-eq current-index target-index)
        ;; If this is the target index, return updated deduction with approved status
        {
            deduction-code: (get deduction-code deduction),
            deduction-amount: (get deduction-amount deduction),
            deduction-approved: true
        }
        ;; Otherwise return the original deduction unchanged
        deduction)
)

;; Private helper for calculating total approved deductions
(define-private (sum-approved-deductions 
    (deduction { deduction-code: (string-ascii 10), deduction-amount: uint, deduction-approved: bool }) 
    (running-total uint))
    (if (get deduction-approved deduction)
        (+ running-total (get deduction-amount deduction))
        running-total)
)



;; Read-only functions for enhanced reporting
(define-read-only (get-taxpayer-profile (taxpayer principal))
    (map-get? taxpayer-profiles taxpayer)
)

(define-read-only (get-currency-rate (currency-code (string-ascii 10)))
    (map-get? currency-exchange-rates { currency-code: currency-code })
)

(define-read-only (get-deduction-info (deduction-code (string-ascii 10)))
    (map-get? available-deductions { deduction-code: deduction-code })
)

(define-read-only (get-tax-bracket-info (income-category (string-ascii 24)))
    (map-get? income-tax-brackets { income-category: income-category })
)



;; Currency conversion function
(define-read-only (convert-between-currencies (amount uint) (source-currency (string-ascii 10)) (target-currency (string-ascii 10)))
    (let (
        (source-currency-rate (unwrap! (get-currency-rate source-currency) ERR-INVALID-CURRENCY))
        (target-currency-rate (unwrap! (get-currency-rate target-currency) ERR-INVALID-CURRENCY))
    )
        (ok (/ (* amount (get exchange-rate target-currency-rate)) (get exchange-rate source-currency-rate)))
    )
)



(define-read-only (calculate-progressive-tax (income-amount uint) (income-category (string-ascii 24)))
    (match (map-get? income-tax-brackets { income-category: income-category })
        bracket-data
        (let ((total-tax-due u0))
            (ok (fold calculate-bracket-tax-amount 
                (get tax-brackets bracket-data)
                { remaining-income: income-amount, accumulated-tax: u0 })))
        ERR-TAX-RATE-NOT-FOUND
    )
)



;; Enhanced reporting functions
(define-read-only (generate-annual-tax-report (taxpayer principal) (tax-year uint))
    (let (
        (taxpayer-profile (unwrap! (get-taxpayer-profile taxpayer) ERR-TAX-RATE-NOT-FOUND))
    )
        (ok {
            total-tax-paid: (get cumulative-tax-paid taxpayer-profile),
            total-tax-refunded: (get cumulative-tax-refunded taxpayer-profile),
            net-tax-paid: (- (get cumulative-tax-paid taxpayer-profile) (get cumulative-tax-refunded taxpayer-profile)),
            applied-deductions: (get claimed-deductions taxpayer-profile),
            payment-transactions: (get transaction-history taxpayer-profile)
        })
    )
)

(define-read-only (calculate-net-tax-obligation (taxpayer principal))
    (let (
        (taxpayer-profile (unwrap! (get-taxpayer-profile taxpayer) ERR-TAX-RATE-NOT-FOUND))
        (total-approved-deductions (fold sum-approved-deductions
            (get claimed-deductions taxpayer-profile)
            u0))
    )
        (ok (- (get cumulative-tax-paid taxpayer-profile) total-approved-deductions))
    )
)



;; Enhanced public functions
(define-public (update-exchange-rate (currency-code (string-ascii 10)) (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get administrator)) ERR-NOT-AUTHORIZED)
        (ok (map-set currency-exchange-rates
            { currency-code: currency-code }
            { exchange-rate: new-rate,
              rate-update-timestamp: stacks-block-height,
              currency-status: true }
        ))
    )
)

(define-public (register-deduction-type (deduction-code (string-ascii 10)) (deduction-name (string-ascii 64)) 
               (maximum-amount uint) (deduction-percentage uint) (approval-required bool))
    (begin
        (asserts! (is-eq tx-sender (var-get administrator)) ERR-NOT-AUTHORIZED)
        (asserts! (<= deduction-percentage u100) ERR-INVALID-TAX-RATE)
        (ok (map-set available-deductions
            { deduction-code: deduction-code }
            { deduction-name: deduction-name,
              maximum-deduction-amount: maximum-amount,
              deduction-percentage: deduction-percentage,
              approval-required: approval-required }
        ))
    )
)

(define-public (submit-deduction-request (deduction-code (string-ascii 10)) (deduction-amount uint))
    (let (
        (deduction-details (unwrap! (get-deduction-info deduction-code) ERR-INVALID-DEDUCTION))
        (taxpayer-profile (default-to 
            {
                cumulative-tax-paid: u0,
                cumulative-tax-refunded: u0,
                most-recent-payment: u0,
                taxpayer-category: "",
                claimed-deductions: (list ),
                transaction-history: (list )
            }
            (get-taxpayer-profile tx-sender)))
    )
        (begin
            (asserts! (<= deduction-amount (get maximum-deduction-amount deduction-details)) ERR-INVALID-AMOUNT)
            (ok (map-set taxpayer-profiles
                tx-sender
                {
                    cumulative-tax-paid: (get cumulative-tax-paid taxpayer-profile),
                    cumulative-tax-refunded: (get cumulative-tax-refunded taxpayer-profile),
                    most-recent-payment: (get most-recent-payment taxpayer-profile),
                    taxpayer-category: (get taxpayer-category taxpayer-profile),
                    claimed-deductions: (unwrap-panic (as-max-len? 
                        (append (get claimed-deductions taxpayer-profile)
                            {
                                deduction-code: deduction-code,
                                deduction-amount: deduction-amount,
                                deduction-approved: (not (get approval-required deduction-details))
                            })
                        u20)),
                    transaction-history: (get transaction-history taxpayer-profile)
                }
            ))
        )
    )
)

;; Modified approve-deduction-request function
(define-public (approve-deduction-request (taxpayer principal) (deduction-index uint))
    (let (
        (taxpayer-profile (unwrap! (get-taxpayer-profile taxpayer) ERR-TAX-RATE-NOT-FOUND))
        (current-deductions (get claimed-deductions taxpayer-profile))
    )
        (begin
            (asserts! (is-eq tx-sender (var-get administrator)) ERR-NOT-AUTHORIZED)
            (asserts! (< deduction-index (len current-deductions)) ERR-INVALID-DEDUCTION)

            (ok (map-set taxpayer-profiles
                taxpayer
                {
                    cumulative-tax-paid: (get cumulative-tax-paid taxpayer-profile),
                    cumulative-tax-refunded: (get cumulative-tax-refunded taxpayer-profile),
                    most-recent-payment: (get most-recent-payment taxpayer-profile),
                    taxpayer-category: (get taxpayer-category taxpayer-profile),
                    claimed-deductions: (unwrap-panic (as-max-len? 
                        (map update-deduction-approval 
                            (list deduction-index)
                            (list u0)
                            current-deductions
                            (list deduction-index))
                        u20)),
                    transaction-history: (get transaction-history taxpayer-profile)
                }
            ))
        )
    )
)

;; Modified issue-tax-refund function to use native STX transfer
(define-public (issue-tax-refund (taxpayer principal) (refund-amount uint) (refund-currency (string-ascii 10)))
    (let (
        (taxpayer-profile (unwrap! (get-taxpayer-profile taxpayer) ERR-TAX-RATE-NOT-FOUND))
        (converted-refund-amount (unwrap! (convert-between-currencies refund-amount refund-currency "STX") ERR-INVALID-CURRENCY))
    )
        (begin
            (asserts! (is-eq tx-sender (var-get administrator)) ERR-NOT-AUTHORIZED)
            (asserts! (<= converted-refund-amount (get cumulative-tax-paid taxpayer-profile)) ERR-REFUND-NOT-ALLOWED)
            ;; Use stx-transfer instead of contract-call
            (try! (stx-transfer? converted-refund-amount (var-get administrator) taxpayer))
            (ok (map-set taxpayer-profiles
                taxpayer
                {
                    cumulative-tax-paid: (get cumulative-tax-paid taxpayer-profile),
                    cumulative-tax-refunded: (+ (get cumulative-tax-refunded taxpayer-profile) converted-refund-amount),
                    most-recent-payment: (get most-recent-payment taxpayer-profile),
                    taxpayer-category: (get taxpayer-category taxpayer-profile),
                    claimed-deductions: (get claimed-deductions taxpayer-profile),
                    transaction-history: (unwrap-panic (as-max-len?
                        (append (get transaction-history taxpayer-profile)
                            { 
                                transaction-amount: (- u0 converted-refund-amount),
                                transaction-timestamp: stacks-block-height,
                                transaction-currency: refund-currency 
                            })
                        u50))
                }
            ))
        )
    )
)
