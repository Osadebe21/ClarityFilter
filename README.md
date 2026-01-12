ClarityFilter: AI-Powered Governance Moderation
===============================================

Overview
--------

I have developed **ClarityFilter**, a decentralized smart contract protocol written in Clarity for the Stacks blockchain. This system implements a sophisticated, stake-backed AI moderation layer designed to sit between proposal submission and formal DAO voting.

In modern decentralized autonomous organizations (DAOs), governance fatigue and "proposal spam" are significant hurdles. **ClarityFilter** solves this by leveraging AI agents---represented by staked human or automated operators---to perform qualitative analysis on incoming proposals. Only proposals that meet a specific cryptographic quality threshold (calculated via multi-agent consensus) are permitted to proceed to the expensive and time-consuming voting phase.

* * * * *

Technical Specifications
------------------------

### Architecture

The contract is built on a foundation of **Incentivized Objectivity**. AI moderators are not merely participants; they are stakeholders. By requiring a minimum stake of $1,000$ tokens (as defined by `MIN-MODERATOR-STAKE`), the protocol ensures that moderators have "skin in the game."

### Key Logic & Formulas

The core of the filtering logic relies on the arithmetic mean of distributed scores. When a proposal is finalized, the contract executes the following logic:

$$Average = \frac{\sum_{i=1}^{n} Score_i}{n}$$

Where:

-   $n$ must be $\ge$ `MIN-SCORES-REQUIRED` (set to 3).

-   $Score_i$ must be within the range $[0, 100]$.

-   A proposal is **Approved** if $Average \ge 70$.

* * * * *

Detailed Function Documentation
-------------------------------

### Public Functions

These functions represent the primary interface for users and AI agents interacting with the blockchain.

#### `register-moderator (stake-amount uint)`

I designed this function to onboard AI agents. It validates that the sender is not already registered and that the `stake-amount` meets the global minimum. Upon success, it initializes performance tracking for the agent.

-   **Returns:** `(ok uint)` representing the new Moderator ID.

-   **Errors:** `ERR-ALREADY-REGISTERED`, `ERR-INSUFFICIENT-STAKE`.

#### `submit-proposal (content-hash (string-ascii 64))`

This is the entry point for DAO members. By submitting a 64-character hash (typically an IPFS CID), the user triggers the moderation period.

-   **Returns:** `(ok uint)` representing the new Proposal ID.

#### `score-proposal (proposal-id uint, score-value uint, reasoning-hash (string-ascii 64))`

Authorized moderators use this to submit their evaluation. The function checks for moderator activity, score validity ($0-100$), and ensures the proposal has not expired or been previously scored by this specific agent.

-   **Returns:** `(ok bool)`.

-   **Errors:** `ERR-NOT-MODERATOR`, `ERR-INVALID-SCORE`, `ERR-PROPOSAL-EXPIRED`, `ERR-ALREADY-SCORED`.

#### `finalize-proposal (proposal-id uint)`

The transition function that closes the moderation window. It ensures that the `MIN-SCORES-REQUIRED` threshold has been met before calculating the final status.

-   **Returns:** `(ok {status: (string-ascii 20), average: uint})`.

* * * * *

### Private & Helper Functions

These internal mechanisms maintain the integrity of the contract state.

#### `calculate-average (total-score-value uint, score-count-value uint)`

A utility to compute the mean score. It includes a safety check to prevent division by zero, returning `u0` if no scores exist.

#### `is-proposal-expired (submission-block uint)`

I implemented this to compare the current `block-height` against the `submission-block`. If the difference exceeds `PROPOSAL-VALIDITY-PERIOD` (1008 blocks), the proposal is deemed stale.

#### `update-moderator-reputation (moderator-address principal, performance-boost uint)`

This allows the contract to programmatically adjust an agent's reputation score. It utilizes the `merge` keyword to update specific fields within the `moderators` map without overwriting unrelated data.

#### `is-valid-score (score-value uint)`

A simple boolean validator to enforce the $0-100$ scoring range.

* * * * *

Installation & Deployment
-------------------------

### Prerequisites

-   **Hiro CLI** or **Clarinet** for local development and testing.

-   A Stacks wallet with sufficient **STX** for contract deployment.

### Steps

1.  **Clone the Repository:**

    Bash

    ```
    git clone https://github.com/your-repo/ClarityFilter.git
    cd ClarityFilter

    ```

2.  **Check Syntax:**

    Bash

    ```
    clarinet check

    ```

3.  **Run Test Suite:**

    Bash

    ```
    clarinet test

    ```

* * * * *

Governance & Security
---------------------

### Security Constraints

I have implemented several "guardrails" to ensure the integrity of the DAO:

-   **Expiration Logic:** Proposals have a validity period of `1008` blocks (~7 days). If a proposal isn't scored in time, it expires to prevent stale data.

-   **Double-Score Prevention:** The `proposal-scores` map uses a composite key of `proposal-id` and `moderator` to ensure one-vote-per-agent.

-   **Stake Slashing Ready:** While the current version tracks performance in `moderator-performance`, future iterations will include automated slashing for scores that deviate more than 2 standard deviations from the mean.

### Error Reference

| **Code** | **Constant** | **Meaning** |
| --- | --- | --- |
| `u100` | `ERR-NOT-AUTHORIZED` | Sender lacks permission for the action. |
| `u103` | `ERR-INSUFFICIENT-STAKE` | Stake amount below the required 1000 threshold. |
| `u104` | `ERR-INVALID-SCORE` | Score provided is outside the 0-100 range. |
| `u106` | `ERR-NOT-ENOUGH-SCORES` | Finalization attempted before 3 scores were reached. |

* * * * *

Contribution Guidelines
-----------------------

I welcome contributions from the community to make **ClarityFilter** the standard for AI-driven governance.

1.  **Fork the Project.**

2.  **Create your Feature Branch** (`git checkout -b feature/AmazingFeature`).

3.  **Commit your Changes** (`git commit -m 'Add some AmazingFeature'`).

4.  **Push to the Branch** (`git push origin feature/AmazingFeature`).

5.  **Open a Pull Request.**

### Code of Conduct

-   Maintain strictly typed Clarity functions.

-   Ensure all public functions have accompanying unit tests in the `tests/` directory.

-   Keep documentation updated with any changes to constants or error codes.

* * * * *

License
-------

**MIT License**

Copyright (c) 2026 ClarityFilter Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy

of this software and associated documentation files (the "Software"), to deal

in the Software without restriction, including without limitation the rights

to use, copy, modify, merge, publish, distribute, sublicense, and/or sell

copies of the Software, and to permit persons to whom the Software is

furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all

copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR

IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,

FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE

AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER

LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,

OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE

SOFTWARE.

* * * * *

