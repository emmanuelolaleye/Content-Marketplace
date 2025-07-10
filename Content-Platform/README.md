# EduMarket Pro - Decentralized Learning Content Platform

A comprehensive smart contract system built on the Stacks blockchain that enables educators to create, publish, and monetize digital educational content while providing students with secure, time-limited access to learning materials through blockchain-based transactions.

## Features

### Core Functionality
- **Content Creation & Management**: Educators can create, update, and manage their educational content
- **Secure Payment Processing**: Automatic revenue distribution between creators and platform
- **Time-Based Access Control**: Students get 6-month access periods with extension capabilities
- **Portfolio Management**: Track content libraries for both educators and students
- **Platform Fee System**: Configurable platform fees with transparent revenue sharing

### Security Features
- **Access Control**: Content creators can only modify their own content
- **Input Validation**: Comprehensive validation for all user inputs
- **Payment Verification**: Secure STX transfers with error handling
- **Administrative Controls**: Owner-only functions for platform management

## Contract Overview

### Constants & Configuration
- **Access Period**: 6 months (15,768,000 seconds)
- **Platform Fee**: 2.5% (250 basis points) - configurable up to 25%
- **Minimum Price**: 0.001 STX (1,000 microSTX)
- **Content Limits**: 100 pieces of content per educator
- **String Limits**: Title (100 chars), Description (500 chars), Category (50 chars)

### Error Codes
- `ERR-OWNER-ONLY (100)`: Function restricted to contract owner
- `ERR-CONTENT-NOT-FOUND (101)`: Requested content doesn't exist
- `ERR-CONTENT-ALREADY-EXISTS (102)`: Content ID already in use
- `ERR-ACCESS-DENIED (103)`: User lacks permission for action
- `ERR-INSUFFICIENT-PAYMENT (104)`: Payment amount too low
- `ERR-INVALID-PRICE (105)`: Price outside acceptable range
- `ERR-CONTENT-DISABLED (106)`: Content is inactive
- `ERR-INVALID-INPUT (107)`: Input validation failed
- `ERR-PURCHASE-NOT-FOUND (108)`: Purchase record not found
- `ERR-EXTENSION-FAILED (109)`: Access extension failed
- `ERR-PAYMENT-FAILED (110)`: Payment processing failed

## Data Structures

### Content Registry
```clarity
{
  content-id: uint,
  creator-address: principal,
  title: string-ascii,
  description: string-utf8,
  price-microstacks: uint,
  category: string-ascii,
  created-at: uint,
  is-active: bool
}
```

### Purchase History
```clarity
{
  student-address: principal,
  content-id: uint,
  purchased-at: uint,
  expires-at: uint,
  total-paid: uint
}
```

## Public Functions

### Content Management

#### `create-learning-content`
Create and publish new educational content.
```clarity
(create-learning-content 
  (title (string-ascii 100)) 
  (description (string-utf8 500)) 
  (price-microstacks uint) 
  (category (string-ascii 50)))
```

#### `update-learning-content`
Update existing content details (creator only).
```clarity
(update-learning-content 
  (content-id uint) 
  (new-title (string-ascii 100)) 
  (new-description (string-utf8 500)) 
  (new-price uint) 
  (new-category (string-ascii 50)))
```

#### `disable-learning-content`
Disable content from being purchased (creator or owner only).
```clarity
(disable-learning-content (content-id uint))
```

### Student Functions

#### `purchase-learning-content`
Purchase educational content with automatic payment processing.
```clarity
(purchase-learning-content (content-id uint))
```

#### `extend-content-access`
Extend access period for owned content by 6 months.
```clarity
(extend-content-access (content-id uint))
```

### Administrative Functions

#### `set-platform-fee-rate`
Update platform fee rate (owner only).
```clarity
(set-platform-fee-rate (new-fee-basis-points uint))
```

#### `withdraw-platform-funds`
Emergency fund withdrawal (owner only).
```clarity
(withdraw-platform-funds (amount uint))
```

## Read-Only Functions

### Content Information
- `get-content-info(content-id)`: Get complete content details
- `is-content-available(content-id)`: Check if content is available for purchase
- `get-platform-stats()`: Get platform statistics

### User Portfolios
- `get-educator-portfolio(educator-address)`: Get educator's content portfolio
- `get-student-library(student-address)`: Get student's purchased content library
- `get-purchase-details(student-address, content-id)`: Get specific purchase details

### Access Control
- `has-purchased-content(student-address, content-id)`: Check if student owns content
- `has-valid-access(student-address, content-id)`: Check if access is still valid

### Platform Information
- `get-platform-fee-rate()`: Get current platform fee rate
- `get-contract-balance()`: Get contract balance (owner only)

## Payment Flow

1. **Content Purchase**:
   - Student pays full content price
   - Platform fee (2.5%) goes to contract owner
   - Remaining amount (97.5%) goes to content creator
   - Student receives 6-month access

2. **Access Extension**:
   - Student pays full price again
   - Same fee distribution applies
   - Access extended by another 6 months

## Security Considerations

- **Input Validation**: All inputs are validated before processing
- **Access Control**: Users can only modify their own content
- **Payment Security**: STX transfers are verified before updating records
- **Time-based Access**: Access expiration is enforced using block timestamps
- **Administrative Safeguards**: Critical functions restricted to contract owner

## Deployment

1. Deploy the contract to Stacks blockchain
2. The deployer becomes the contract owner
3. Set initial platform fee rate (default: 2.5%)
4. Contract is ready for educators and students to use

## Usage Examples

### Creating Content
```clarity
;; Create a programming course
(contract-call? .edumarket-pro create-learning-content
  "Advanced JavaScript Programming"
  "Learn advanced JavaScript concepts including async/await, closures, and more"
  u50000000  ;; 50 STX
  "Programming")
```

### Purchasing Content
```clarity
;; Purchase content with ID 1
(contract-call? .edumarket-pro purchase-learning-content u1)
```

### Checking Access
```clarity
;; Check if student has valid access to content
(contract-call? .edumarket-pro has-valid-access 'SP1STUDENT123 u1)
```

## State Management

The contract maintains several key state variables:
- `next-content-id`: Auto-incrementing content identifier
- `platform-fee-basis-points`: Current platform fee rate
- `total-content-created`: Total content pieces created
- `total-transactions-processed`: Total transactions processed