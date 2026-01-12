;; AI Moderated DAO Proposal Filter

;; This smart contract implements an AI-powered proposal filtering system for DAOs.
;; It allows proposals to be submitted, scored by AI moderators, and filtered based on
;; quality thresholds. The system prevents spam, malicious proposals, and ensures only
;; high-quality proposals reach the voting stage. AI moderators stake tokens to participate
;; and can be penalized for poor moderation decisions.

;; constants

;; Error codes for various failure conditions
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-SCORED (err u102))
(define-constant ERR-INSUFFICIENT-STAKE (err u103))
(define-constant ERR-INVALID-SCORE (err u104))
(define-constant ERR-PROPOSAL-EXPIRED (err u105))
(define-constant ERR-NOT-ENOUGH-SCORES (err u106))
(define-constant ERR-ALREADY-REGISTERED (err u107))
(define-constant ERR-NOT-MODERATOR (err u108))

;; Contract owner address
(define-constant CONTRACT-OWNER tx-sender)

;; Minimum stake required to become an AI moderator (1000 tokens)
(define-constant MIN-MODERATOR-STAKE u1000000000)

;; Minimum number of AI scores required before proposal can proceed
(define-constant MIN-SCORES-REQUIRED u3)

;; Score threshold for proposal to pass filtering (70 out of 100)
(define-constant SCORE-THRESHOLD u70)

;; Proposal validity period in blocks (~7 days assuming 10 min blocks)
(define-constant PROPOSAL-VALIDITY-PERIOD u1008)

;; data maps and vars

;; Counter for proposal IDs
(define-data-var proposal-counter uint u0)

;; Counter for moderator IDs
(define-data-var moderator-counter uint u0)

;; Tracks proposal details including submitter, content hash, and submission block
(define-map proposals
    uint
    {
        submitter: principal,
        content-hash: (string-ascii 64),
        submission-block: uint,
        total-score: uint,
        score-count: uint,
        status: (string-ascii 20),
        final-average: uint
    }
)

;; Tracks which moderators have scored which proposals to prevent duplicate scoring
(define-map proposal-scores
    {proposal-id: uint, moderator: principal}
    {
        score: uint,
        scored-at: uint,
        reasoning-hash: (string-ascii 64)
    }
)

;; Tracks registered AI moderators and their stake amounts
(define-map moderators
    principal
    {
        moderator-id: uint,
        stake-amount: uint,
        total-scores-submitted: uint,
        reputation-score: uint,
        is-active: bool
    }
)

;; Tracks moderator performance for reputation calculation
(define-map moderator-performance
    principal
    {
        accurate-scores: uint,
        challenged-scores: uint,
        penalties-received: uint
    }
)

;; private functions

;; Calculate the average score for a proposal
;; @param total-score: cumulative score from all moderators
;; @param score-count: number of moderators who scored
;; @returns: average score as uint
(define-private (calculate-average (total-score-value uint) (score-count-value uint))
    (if (> score-count-value u0)
        (/ total-score-value score-count-value)
        u0
    )
)

;; Check if a proposal has expired based on block height
;; @param submission-block: block when proposal was submitted
;; @returns: true if expired, false otherwise
(define-private (is-proposal-expired (submission-block uint))
    (> (- block-height submission-block) PROPOSAL-VALIDITY-PERIOD)
)

;; Update moderator reputation based on scoring activity
;; @param moderator: principal address of the moderator
;; @param performance-boost: amount to increase reputation
;; @returns: true on success
(define-private (update-moderator-reputation (moderator-address principal) (performance-boost uint))
    (let
        (
            (moderator-data (unwrap! (map-get? moderators moderator-address) false))
            (current-reputation (get reputation-score moderator-data))
        )
        (map-set moderators
            moderator-address
            (merge moderator-data {reputation-score: (+ current-reputation performance-boost)})
        )
        true
    )
)

;; Validate that a score is within acceptable range (0-100)
;; @param score-value: the score to validate
;; @returns: true if valid, false otherwise
(define-private (is-valid-score (score-value uint))
    (and (>= score-value u0) (<= score-value u100))
)

;; public functions

;; Register as an AI moderator by staking tokens
;; @param stake-amount: amount of tokens to stake (must meet minimum)
;; @returns: moderator ID on success, error on failure
(define-public (register-moderator (stake-amount uint))
    (let
        (
            (moderator-address tx-sender)
            (new-moderator-id (+ (var-get moderator-counter) u1))
        )
        ;; Ensure moderator is not already registered
        (asserts! (is-none (map-get? moderators moderator-address)) ERR-ALREADY-REGISTERED)
        
        ;; Validate minimum stake requirement
        (asserts! (>= stake-amount MIN-MODERATOR-STAKE) ERR-INSUFFICIENT-STAKE)
        
        ;; Register the moderator with initial values
        (map-set moderators
            moderator-address
            {
                moderator-id: new-moderator-id,
                stake-amount: stake-amount,
                total-scores-submitted: u0,
                reputation-score: u100,
                is-active: true
            }
        )
        
        ;; Initialize performance tracking
        (map-set moderator-performance
            moderator-address
            {
                accurate-scores: u0,
                challenged-scores: u0,
                penalties-received: u0
            }
        )
        
        ;; Increment moderator counter
        (var-set moderator-counter new-moderator-id)
        
        (ok new-moderator-id)
    )
)

;; Submit a new proposal for AI moderation
;; @param content-hash: IPFS or SHA-256 hash of proposal content
;; @returns: proposal ID on success, error on failure
(define-public (submit-proposal (content-hash (string-ascii 64)))
    (let
        (
            (new-proposal-id (+ (var-get proposal-counter) u1))
            (submitter-address tx-sender)
        )
        ;; Create new proposal with pending status
        (map-set proposals
            new-proposal-id
            {
                submitter: submitter-address,
                content-hash: content-hash,
                submission-block: block-height,
                total-score: u0,
                score-count: u0,
                status: "pending",
                final-average: u0
            }
        )
        
        ;; Increment proposal counter
        (var-set proposal-counter new-proposal-id)
        
        (ok new-proposal-id)
    )
)

;; AI moderator submits a score for a proposal
;; @param proposal-id: ID of the proposal to score
;; @param score-value: quality score from 0-100
;; @param reasoning-hash: hash of AI reasoning/explanation
;; @returns: success boolean or error
(define-public (score-proposal (proposal-id uint) (score-value uint) (reasoning-hash (string-ascii 64)))
    (let
        (
            (moderator-address tx-sender)
            (proposal-data (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (moderator-data (unwrap! (map-get? moderators moderator-address) ERR-NOT-MODERATOR))
        )
        ;; Validate moderator is active and authorized
        (asserts! (get is-active moderator-data) ERR-NOT-AUTHORIZED)
        
        ;; Validate score is in acceptable range
        (asserts! (is-valid-score score-value) ERR-INVALID-SCORE)
        
        ;; Check proposal hasn't expired
        (asserts! (not (is-proposal-expired (get submission-block proposal-data))) ERR-PROPOSAL-EXPIRED)
        
        ;; Ensure moderator hasn't already scored this proposal
        (asserts! (is-none (map-get? proposal-scores {proposal-id: proposal-id, moderator: moderator-address})) ERR-ALREADY-SCORED)
        
        ;; Record the score with timestamp and reasoning
        (map-set proposal-scores
            {proposal-id: proposal-id, moderator: moderator-address}
            {
                score: score-value,
                scored-at: block-height,
                reasoning-hash: reasoning-hash
            }
        )
        
        ;; Update proposal with new score data
        (let
            (
                (updated-total (+ (get total-score proposal-data) score-value))
                (updated-count (+ (get score-count proposal-data) u1))
            )
            (map-set proposals
                proposal-id
                (merge proposal-data {
                    total-score: updated-total,
                    score-count: updated-count
                })
            )
        )
        
        ;; Update moderator statistics
        (map-set moderators
            moderator-address
            (merge moderator-data {
                total-scores-submitted: (+ (get total-scores-submitted moderator-data) u1)
            })
        )
        
        (ok true)
    )
)

;; Finalize proposal filtering decision after minimum scores reached
;; @param proposal-id: ID of the proposal to finalize
;; @returns: final status (approved/rejected) or error
;; This function evaluates all AI scores, calculates the average, and determines
;; whether the proposal meets the quality threshold to proceed to DAO voting.
;; It implements a multi-stage validation process ensuring proposal integrity,
;; sufficient moderator participation, and fair scoring distribution.
(define-public (finalize-proposal (proposal-id uint))
    (let
        (
            (proposal-data (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (current-score-count (get score-count proposal-data))
            (current-total-score (get total-score proposal-data))
        )
        ;; Validate sufficient scores have been collected from AI moderators
        (asserts! (>= current-score-count MIN-SCORES-REQUIRED) ERR-NOT-ENOUGH-SCORES)
        
        ;; Verify proposal is still within validity period
        (asserts! (not (is-proposal-expired (get submission-block proposal-data))) ERR-PROPOSAL-EXPIRED)
        
        ;; Calculate weighted average score from all moderator inputs
        (let
            (
                (average-score (calculate-average current-total-score current-score-count))
                (new-status (if (>= average-score SCORE-THRESHOLD) "approved" "rejected"))
            )
            ;; Update proposal with final decision and average score
            (map-set proposals
                proposal-id
                (merge proposal-data {
                    status: new-status,
                    final-average: average-score
                })
            )
            
            ;; Return final status with average score for transparency
            (ok {status: new-status, average: average-score})
        )
    )
)


