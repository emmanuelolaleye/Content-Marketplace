;; EduMarket Pro - Decentralized Learning Content Platform Smart Contract
;; A comprehensive smart contract system that enables educators to create, publish, 
;; and monetize digital educational content while providing students with secure,
;; time-limited access to learning materials through blockchain-based transactions.
;; 
;; Core Features:
;; - Content creation and management for educators
;; - Secure content purchasing with automatic revenue distribution
;; - Time-based access control with extension capabilities
;; - Platform fee management and administrative controls
;; - Comprehensive access validation and portfolio tracking

;; SYSTEM CONFIGURATION AND CONSTANTS

(define-constant contract-owner tx-sender)

;; System Error Codes
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-CONTENT-NOT-FOUND (err u101))
(define-constant ERR-CONTENT-ALREADY-EXISTS (err u102))
(define-constant ERR-ACCESS-DENIED (err u103))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u104))
(define-constant ERR-INVALID-PRICE (err u105))
(define-constant ERR-CONTENT-DISABLED (err u106))
(define-constant ERR-INVALID-INPUT (err u107))
(define-constant ERR-PURCHASE-NOT-FOUND (err u108))
(define-constant ERR-EXTENSION-FAILED (err u109))
(define-constant ERR-PAYMENT-FAILED (err u110))

;; Platform Business Rules
(define-constant max-content-per-educator u100)
(define-constant access-period-seconds u15768000) ;; 6 months access duration
(define-constant percentage-multiplier u10000) ;; For basis points calculation
(define-constant max-platform-fee-rate u2500) ;; 25% maximum platform fee
(define-constant min-content-price u1000) ;; Minimum price: 0.001 STX

;; String Length Limits
(define-constant max-title-length u100)
(define-constant max-description-length u500)
(define-constant max-category-length u50)

;; DATA STORAGE STRUCTURES

;; Primary Content Registry - stores all educational content metadata
(define-map learning-content-registry
  { content-id: uint }
  {
    creator-address: principal,
    title: (string-ascii 100),
    description: (string-utf8 500),
    price-microstacks: uint,
    category: (string-ascii 50),
    created-at: uint,
    is-active: bool
  }
)

;; Educator Portfolio Management - tracks content created by each educator
(define-map educator-portfolio-registry
  { educator-address: principal }
  { content-ids: (list 100 uint) }
)

;; Student Purchase History - records all content purchases
(define-map student-purchase-history
  { student-address: principal, content-id: uint }
  { 
    purchased-at: uint, 
    expires-at: uint,
    total-paid: uint
  }
)

;; Student Content Library - tracks purchased content per student
(define-map student-content-library
  { student-address: principal }
  { owned-content-ids: (list 100 uint) }
)

;; SYSTEM STATE VARIABLES

;; Platform revenue configuration (250 basis points = 2.5%)
(define-data-var platform-fee-basis-points uint u250)

;; Auto-incrementing content ID counter
(define-data-var next-content-id uint u1)

;; Platform statistics
(define-data-var total-content-created uint u0)
(define-data-var total-transactions-processed uint u0)

;; PRIVATE UTILITY FUNCTIONS

;; Generate unique content identifier and increment counter
(define-private (get-next-content-id)
  (let ((current-id (var-get next-content-id)))
    (var-set next-content-id (+ current-id u1))
    current-id
  )
)

;; Calculate platform fee from total transaction amount
(define-private (calculate-platform-fee (total-amount uint))
  (/ (* total-amount (var-get platform-fee-basis-points)) percentage-multiplier)
)

;; Safely add content ID to user's content list
(define-private (add-content-to-list (new-content-id uint) (current-list (list 100 uint)))
  (if (>= (len current-list) u99)
    current-list
    (unwrap! (as-max-len? (append current-list new-content-id) u100) current-list)
  )
)

;; Calculate access expiration timestamp
(define-private (calculate-expiration-time (start-time uint))
  (+ start-time access-period-seconds)
)

;; Update platform statistics
(define-private (increment-content-counter)
  (var-set total-content-created (+ (var-get total-content-created) u1))
)

(define-private (increment-transaction-counter)
  (var-set total-transactions-processed (+ (var-get total-transactions-processed) u1))
)

;; INPUT VALIDATION FUNCTIONS

;; Validate content title meets requirements
(define-private (is-valid-title (title (string-ascii 100)))
  (and (> (len title) u0) (<= (len title) max-title-length))
)

;; Validate content description meets requirements
(define-private (is-valid-description (description (string-utf8 500)))
  (and (> (len description) u0) (<= (len description) max-description-length))
)

;; Validate content category meets requirements
(define-private (is-valid-category (category (string-ascii 50)))
  (and (> (len category) u0) (<= (len category) max-category-length))
)

;; Validate content price is within acceptable range
(define-private (is-valid-price (price uint))
  (>= price min-content-price)
)

;; Validate content ID exists in system
(define-private (is-valid-content-id (content-id uint))
  (and (> content-id u0) (< content-id (var-get next-content-id)))
)

;; Check if content exists and is purchasable
(define-private (is-content-purchasable (content-id uint))
  (match (map-get? learning-content-registry { content-id: content-id })
    content-data (get is-active content-data)
    false
  )
)

;; READ-ONLY QUERY FUNCTIONS

;; Check if student has purchased specific content
(define-read-only (has-purchased-content (student-address principal) (content-id uint))
  (is-some (map-get? student-purchase-history { student-address: student-address, content-id: content-id }))
)

;; Verify content availability for purchase
(define-read-only (is-content-available (content-id uint))
  (is-content-purchasable content-id)
)

;; Get complete content information
(define-read-only (get-content-info (content-id uint))
  (map-get? learning-content-registry { content-id: content-id })
)

;; Get educator's complete portfolio
(define-read-only (get-educator-portfolio (educator-address principal))
  (map-get? educator-portfolio-registry { educator-address: educator-address })
)

;; Get student's purchased content library
(define-read-only (get-student-library (student-address principal))
  (map-get? student-content-library { student-address: student-address })
)

;; Get purchase details for specific content
(define-read-only (get-purchase-details (student-address principal) (content-id uint))
  (map-get? student-purchase-history { student-address: student-address, content-id: content-id })
)

;; Check if student's access is still valid
(define-read-only (has-valid-access (student-address principal) (content-id uint))
  (let ((purchase-data (map-get? student-purchase-history { student-address: student-address, content-id: content-id }))
        (current-time (get-block-info? time (- block-height u1))))
    (match purchase-data
      found-purchase (and 
                       (is-some current-time)
                       (>= (get expires-at found-purchase) (default-to u0 current-time)))
      false)
  )
)

;; Get current platform statistics
(define-read-only (get-platform-stats)
  {
    total-content: (var-get total-content-created),
    total-transactions: (var-get total-transactions-processed),
    platform-fee-rate: (var-get platform-fee-basis-points)
  }
)

;; Get current platform fee rate
(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-basis-points)
)

;; CORE BUSINESS FUNCTIONS

;; Create and publish new educational content
(define-public (create-learning-content 
                (title (string-ascii 100)) 
                (description (string-utf8 500)) 
                (price-microstacks uint) 
                (category (string-ascii 50)))
  (let ((new-content-id (get-next-content-id))
        (current-time (get-block-info? time (- block-height u1))))
    
    ;; Validate all input parameters
    (asserts! (is-valid-title title) ERR-INVALID-INPUT)
    (asserts! (is-valid-description description) ERR-INVALID-INPUT)
    (asserts! (is-valid-category category) ERR-INVALID-INPUT)
    (asserts! (is-valid-price price-microstacks) ERR-INVALID-PRICE)
    (asserts! (is-some current-time) ERR-CONTENT-NOT-FOUND)
    
    ;; Create content record
    (map-set learning-content-registry
      { content-id: new-content-id }
      {
        creator-address: tx-sender,
        title: title,
        description: description,
        price-microstacks: price-microstacks,
        category: category,
        created-at: (default-to u0 current-time),
        is-active: true
      }
    )
    
    ;; Update educator's portfolio
    (match (map-get? educator-portfolio-registry { educator-address: tx-sender })
      existing-portfolio 
        (map-set educator-portfolio-registry 
          { educator-address: tx-sender }
          { content-ids: (add-content-to-list new-content-id (get content-ids existing-portfolio)) })
      (map-set educator-portfolio-registry
        { educator-address: tx-sender }
        { content-ids: (list new-content-id) })
    )
    
    ;; Update statistics
    (increment-content-counter)
    
    (ok new-content-id)
  )
)

;; Update existing content details
(define-public (update-learning-content 
                (content-id uint) 
                (new-title (string-ascii 100)) 
                (new-description (string-utf8 500)) 
                (new-price uint) 
                (new-category (string-ascii 50)))
  (let ((content-data (map-get? learning-content-registry { content-id: content-id })))
    
    ;; Validate inputs and permissions
    (asserts! (is-valid-content-id content-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-title new-title) ERR-INVALID-INPUT)
    (asserts! (is-valid-description new-description) ERR-INVALID-INPUT)
    (asserts! (is-valid-category new-category) ERR-INVALID-INPUT)
    (asserts! (is-valid-price new-price) ERR-INVALID-PRICE)
    (asserts! (is-some content-data) ERR-CONTENT-NOT-FOUND)
    
    (let ((content-record (unwrap-panic content-data)))
      (asserts! (is-eq (get creator-address content-record) tx-sender) ERR-ACCESS-DENIED)
      
      ;; Update content record
      (map-set learning-content-registry
        { content-id: content-id }
        {
          creator-address: (get creator-address content-record),
          title: new-title,
          description: new-description,
          price-microstacks: new-price,
          category: new-category,
          created-at: (get created-at content-record),
          is-active: (get is-active content-record)
        }
      )
      
      (ok true)
    )
  )
)

;; Disable content from being purchased
(define-public (disable-learning-content (content-id uint))
  (let ((content-data (map-get? learning-content-registry { content-id: content-id })))
    
    (asserts! (is-valid-content-id content-id) ERR-INVALID-INPUT)
    (asserts! (is-some content-data) ERR-CONTENT-NOT-FOUND)
    
    (let ((content-record (unwrap-panic content-data)))
      (asserts! (or 
                  (is-eq (get creator-address content-record) tx-sender)
                  (is-eq tx-sender contract-owner))
                ERR-ACCESS-DENIED)
      
      ;; Mark content as inactive
      (map-set learning-content-registry
        { content-id: content-id }
        {
          creator-address: (get creator-address content-record),
          title: (get title content-record),
          description: (get description content-record),
          price-microstacks: (get price-microstacks content-record),
          category: (get category content-record),
          created-at: (get created-at content-record),
          is-active: false
        }
      )
      
      (ok true)
    )
  )
)

;; Purchase educational content with payment processing
(define-public (purchase-learning-content (content-id uint))
  (let ((current-time (get-block-info? time (- block-height u1)))
        (content-data (map-get? learning-content-registry { content-id: content-id })))
    
    (asserts! (is-valid-content-id content-id) ERR-INVALID-INPUT)
    (asserts! (is-some current-time) ERR-CONTENT-NOT-FOUND)
    (asserts! (is-some content-data) ERR-CONTENT-NOT-FOUND)
    
    (let ((purchase-time (unwrap-panic current-time))
          (content-record (unwrap-panic content-data)))
      
      (asserts! (get is-active content-record) ERR-CONTENT-DISABLED)
      
      (let ((creator-address (get creator-address content-record))
            (total-price (get price-microstacks content-record))
            (platform-fee (calculate-platform-fee total-price))
            (creator-payment (- total-price platform-fee))
            (access-expiration (calculate-expiration-time purchase-time)))
        
        ;; Process payment to creator
        (match (stx-transfer? creator-payment tx-sender creator-address)
          success-creator 
            ;; Process platform fee
            (match (stx-transfer? platform-fee tx-sender contract-owner)
              success-platform
                (begin
                  ;; Record purchase
                  (map-set student-purchase-history
                    { student-address: tx-sender, content-id: content-id }
                    { 
                      purchased-at: purchase-time, 
                      expires-at: access-expiration,
                      total-paid: total-price
                    }
                  )
                  
                  ;; Update student library
                  (match (map-get? student-content-library { student-address: tx-sender })
                    existing-library 
                      (map-set student-content-library 
                        { student-address: tx-sender }
                        { owned-content-ids: (add-content-to-list content-id (get owned-content-ids existing-library)) })
                    (map-set student-content-library
                      { student-address: tx-sender }
                      { owned-content-ids: (list content-id) })
                  )
                  
                  ;; Update statistics
                  (increment-transaction-counter)
                  
                  (ok true)
                )
              error-platform ERR-PAYMENT-FAILED
            )
          error-creator ERR-INSUFFICIENT-PAYMENT
        )
      )
    )
  )
)

;; Extend access period for owned content
(define-public (extend-content-access (content-id uint))
  (let ((existing-purchase (map-get? student-purchase-history { student-address: tx-sender, content-id: content-id }))
        (current-time (get-block-info? time (- block-height u1)))
        (content-data (map-get? learning-content-registry { content-id: content-id })))
    
    (asserts! (is-valid-content-id content-id) ERR-INVALID-INPUT)
    (asserts! (is-some existing-purchase) ERR-PURCHASE-NOT-FOUND)
    (asserts! (is-some current-time) ERR-CONTENT-NOT-FOUND)
    (asserts! (is-some content-data) ERR-CONTENT-NOT-FOUND)
    
    (let ((purchase-record (unwrap-panic existing-purchase))
          (content-record (unwrap-panic content-data)))
      
      (asserts! (get is-active content-record) ERR-CONTENT-DISABLED)
      
      (let ((creator-address (get creator-address content-record))
            (extension-price (get price-microstacks content-record))
            (platform-fee (calculate-platform-fee extension-price))
            (creator-payment (- extension-price platform-fee))
            (current-expiration (get expires-at purchase-record))
            (new-expiration (+ current-expiration access-period-seconds)))
        
        ;; Process extension payment to creator
        (match (stx-transfer? creator-payment tx-sender creator-address)
          success-creator 
            ;; Process platform fee
            (match (stx-transfer? platform-fee tx-sender contract-owner)
              success-platform
                (begin
                  ;; Update access expiration
                  (map-set student-purchase-history
                    { student-address: tx-sender, content-id: content-id }
                    { 
                      purchased-at: (get purchased-at purchase-record),
                      expires-at: new-expiration,
                      total-paid: (+ (get total-paid purchase-record) extension-price)
                    }
                  )
                  
                  ;; Update statistics
                  (increment-transaction-counter)
                  
                  (ok true)
                )
              error-platform ERR-PAYMENT-FAILED
            )
          error-creator ERR-INSUFFICIENT-PAYMENT
        )
      )
    )
  )
)

;; ADMINISTRATIVE FUNCTIONS

;; Update platform fee rate (owner only)
(define-public (set-platform-fee-rate (new-fee-basis-points uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-OWNER-ONLY)
    (asserts! (<= new-fee-basis-points max-platform-fee-rate) ERR-INVALID-PRICE)
    (var-set platform-fee-basis-points new-fee-basis-points)
    (ok true)
  )
)

;; Emergency fund withdrawal (owner only)
(define-public (withdraw-platform-funds (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-OWNER-ONLY)
    (asserts! (<= amount (stx-get-balance (as-contract tx-sender))) ERR-INSUFFICIENT-PAYMENT)
    (as-contract (stx-transfer? amount tx-sender contract-owner))
  )
)

;; Get contract balance (owner only)
(define-read-only (get-contract-balance)
  (if (is-eq tx-sender contract-owner)
    (ok (stx-get-balance (as-contract tx-sender)))
    ERR-OWNER-ONLY
  )
)