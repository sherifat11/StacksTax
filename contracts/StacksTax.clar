
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
