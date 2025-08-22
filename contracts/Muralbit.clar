

(define-non-fungible-token muralbit-nft uint)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_NOT_APPROVED (err u403))

(define-data-var next-token-id uint u1)
(define-data-var contract-paused bool false)
(define-data-var mint-price uint u1000000)
(define-data-var platform-fee uint u50)

(define-map art-registry
  uint
  {
    title: (string-ascii 100),
    artist: (string-ascii 50),
    location: (string-ascii 200),
    coordinates: (string-ascii 50),
    description: (string-ascii 500),
    image-uri: (string-ascii 200),
    verified: bool,
    created-at: uint,
    claimed-by: principal
  }
)

(define-map pending-submissions
  uint
  {
    title: (string-ascii 100),
    artist: (string-ascii 50),
    location: (string-ascii 200),
    coordinates: (string-ascii 50),
    description: (string-ascii 500),
    image-uri: (string-ascii 200),
    submitted-by: principal,
    submitted-at: uint
  }
)

(define-map user-submissions principal (list 50 uint))
(define-map token-approvals {token-id: uint, approved: principal} bool)
(define-map art-votes {submission-id: uint, voter: principal} bool)
(define-map submission-vote-count uint uint)

(define-public (submit-art-for-verification 
  (title (string-ascii 100))
  (artist (string-ascii 50))
  (location (string-ascii 200))
  (coordinates (string-ascii 50))
  (description (string-ascii 500))
  (image-uri (string-ascii 200)))
  (let ((submission-id (var-get next-token-id))
        (current-submissions (default-to (list) (map-get? user-submissions tx-sender))))
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len title) u0) ERR_INVALID_INPUT)
    (asserts! (> (len location) u0) ERR_INVALID_INPUT)
    (asserts! (< (len current-submissions) u50) ERR_INVALID_INPUT)
    (try! (stx-transfer? (var-get mint-price) tx-sender CONTRACT_OWNER))
    (map-set pending-submissions submission-id {
      title: title,
      artist: artist,
      location: location,
      coordinates: coordinates,
      description: description,
      image-uri: image-uri,
      submitted-by: tx-sender,
      submitted-at: stacks-block-height
    })
    (map-set user-submissions tx-sender 
      (unwrap! (as-max-len? (append current-submissions submission-id) u50) ERR_INVALID_INPUT))
    (var-set next-token-id (+ submission-id u1))
    (ok submission-id)))

(define-public (vote-for-art (submission-id uint))
  (let ((submission (unwrap! (map-get? pending-submissions submission-id) ERR_NOT_FOUND))
        (current-votes (default-to u0 (map-get? submission-vote-count submission-id))))
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-none (map-get? art-votes {submission-id: submission-id, voter: tx-sender})) ERR_ALREADY_EXISTS)
    (map-set art-votes {submission-id: submission-id, voter: tx-sender} true)
    (map-set submission-vote-count submission-id (+ current-votes u1))
    (ok true)))

(define-public (approve-art (submission-id uint))
  (let ((submission (unwrap! (map-get? pending-submissions submission-id) ERR_NOT_FOUND))
        (vote-count (default-to u0 (map-get? submission-vote-count submission-id))))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (>= vote-count u3) ERR_NOT_APPROVED)
    (map-set art-registry submission-id {
      title: (get title submission),
      artist: (get artist submission),
      location: (get location submission),
      coordinates: (get coordinates submission),
      description: (get description submission),
      image-uri: (get image-uri submission),
      verified: true,
      created-at: stacks-block-height,
      claimed-by: (get submitted-by submission)
    })
    (try! (nft-mint? muralbit-nft submission-id (get submitted-by submission)))
    (map-delete pending-submissions submission-id)
    (ok submission-id)))

(define-public (claim-art (token-id uint) (recipient principal))
  (let ((art-data (unwrap! (map-get? art-registry token-id) ERR_NOT_FOUND))
        (current-owner (unwrap! (nft-get-owner? muralbit-nft token-id) ERR_NOT_FOUND)))
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender current-owner) ERR_NOT_AUTHORIZED)
    (try! (nft-transfer? muralbit-nft token-id tx-sender recipient))
    (map-set art-registry token-id (merge art-data {claimed-by: recipient}))
    (ok true)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (try! (nft-transfer? muralbit-nft token-id sender recipient))
    (let ((art-data (unwrap! (map-get? art-registry token-id) ERR_NOT_FOUND)))
      (map-set art-registry token-id (merge art-data {claimed-by: recipient})))
    (ok true)))

(define-public (approve (token-id uint) (approved principal))
  (let ((owner (unwrap! (nft-get-owner? muralbit-nft token-id) ERR_NOT_FOUND)))
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender owner) ERR_NOT_AUTHORIZED)
    (map-set token-approvals {token-id: token-id, approved: approved} true)
    (ok true)))

(define-public (transfer-from (token-id uint) (owner principal) (recipient principal))
  (let ((approved (default-to false (map-get? token-approvals {token-id: token-id, approved: tx-sender}))))
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (or (is-eq tx-sender owner) approved) ERR_NOT_AUTHORIZED)
    (try! (nft-transfer? muralbit-nft token-id owner recipient))
    (map-delete token-approvals {token-id: token-id, approved: tx-sender})
    (let ((art-data (unwrap! (map-get? art-registry token-id) ERR_NOT_FOUND)))
      (map-set art-registry token-id (merge art-data {claimed-by: recipient})))
    (ok true)))

(define-public (set-mint-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set mint-price new-price)
    (ok true)))

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee u1000) ERR_INVALID_INPUT)
    (var-set platform-fee new-fee)
    (ok true)))

(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set contract-paused true)
    (ok true)))

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set contract-paused false)
    (ok true)))

(define-public (reject-submission (submission-id uint))
  (let ((submission (unwrap! (map-get? pending-submissions submission-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-delete pending-submissions submission-id)
    (try! (stx-transfer? (/ (var-get mint-price) u2) CONTRACT_OWNER (get submitted-by submission)))
    (ok true)))

(define-public (withdraw-funds (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (try! (stx-transfer? amount tx-sender recipient))
    (ok true)))

(define-read-only (get-last-token-id)
  (- (var-get next-token-id) u1))

(define-read-only (get-token-uri (token-id uint))
  (let ((art-data (map-get? art-registry token-id)))
    (match art-data
      data (ok (some (get image-uri data)))
      (ok none))))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? muralbit-nft token-id)))

(define-read-only (get-art-details (token-id uint))
  (map-get? art-registry token-id))

(define-read-only (get-pending-submission (submission-id uint))
  (map-get? pending-submissions submission-id))

(define-read-only (get-submission-votes (submission-id uint))
  (default-to u0 (map-get? submission-vote-count submission-id)))

(define-read-only (has-voted (submission-id uint) (voter principal))
  (default-to false (map-get? art-votes {submission-id: submission-id, voter: voter})))

(define-read-only (get-user-submissions (user principal))
  (default-to (list) (map-get? user-submissions user)))

(define-read-only (get-mint-price)
  (var-get mint-price))

(define-read-only (get-platform-fee)
  (var-get platform-fee))

(define-read-only (is-contract-paused)
  (var-get contract-paused))

(define-read-only (get-approved (token-id uint) (approved principal))
  (default-to false (map-get? token-approvals {token-id: token-id, approved: approved})))

(define-read-only (get-art-count)
  (- (var-get next-token-id) u1))

(define-public (batch-approve-submissions (submission-ids (list 20 uint)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (unwrap! (fold approve-single-submission submission-ids (ok (list))) ERR_INVALID_INPUT)
    (ok true)))

(define-private (approve-single-submission (submission-id uint) (previous-result (response (list 20 uint) uint)))
  (match previous-result
    success (match (approve-art submission-id)
              ok (ok success)
              error (err error))
    error (err error)))

(define-public (emergency-mint (token-id uint) (recipient principal) 
  (title (string-ascii 100))
  (artist (string-ascii 50))
  (location (string-ascii 200))
  (coordinates (string-ascii 50))
  (description (string-ascii 500))
  (image-uri (string-ascii 200)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-none (map-get? art-registry token-id)) ERR_ALREADY_EXISTS)
    (map-set art-registry token-id {
      title: title,
      artist: artist,
      location: location,
      coordinates: coordinates,
      description: description,
      image-uri: image-uri,
      verified: true,
      created-at: stacks-block-height,
      claimed-by: recipient
    })
    (try! (nft-mint? muralbit-nft token-id recipient))
    (ok token-id)))

(define-public (update-art-metadata (token-id uint) 
  (new-title (optional (string-ascii 100)))
  (new-description (optional (string-ascii 500)))
  (new-image-uri (optional (string-ascii 200))))
  (let ((art-data (unwrap! (map-get? art-registry token-id) ERR_NOT_FOUND))
        (owner (unwrap! (nft-get-owner? muralbit-nft token-id) ERR_NOT_FOUND)))
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq tx-sender owner) ERR_NOT_AUTHORIZED)
    (map-set art-registry token-id (merge art-data {
      title: (default-to (get title art-data) new-title),
      description: (default-to (get description art-data) new-description),
      image-uri: (default-to (get image-uri art-data) new-image-uri)
    }))
    (ok true)))

(define-read-only (get-contract-stats)
  {
    total-submissions: (- (var-get next-token-id) u1),
    mint-price: (var-get mint-price),
    platform-fee: (var-get platform-fee),
    paused: (var-get contract-paused)
  })

(define-public (bulk-vote (submission-ids (list 10 uint)))
  (begin
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (unwrap! (fold vote-for-single submission-ids (ok (list))) ERR_INVALID_INPUT)
    (ok true)))

(define-private (vote-for-single (submission-id uint) (previous-result (response (list 10 uint) uint)))
  (match previous-result
    success (match (vote-for-art submission-id)
              ok (ok success)
              error (ok success))
    error (err error)))
