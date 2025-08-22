# Muralbit - Public Art Registry NFTs

A Clarity smart contract for claiming and showcasing public art as NFTs on the Stacks blockchain.

## Overview

Muralbit enables users to submit public art for verification, vote on submissions, and mint NFTs representing verified public artworks. Each NFT represents a unique piece of public art with metadata including location, artist, and coordinates.

## Core Features

- **Art Submission**: Submit public art for community verification
- **Community Voting**: Vote on pending art submissions
- **NFT Minting**: Mint NFTs for approved public art pieces
- **Ownership Transfer**: Transfer and approve art NFTs
- **Metadata Management**: Update art details by owners
- **Admin Controls**: Pause/unpause contract and manage submissions

## Usage

### Submit Art for Verification

```clarity
(contract-call? .Muralbit submit-art-for-verification 
  "Street Mural" 
  "Anonymous" 
  "Downtown Main St" 
  "40.7128,-74.0060" 
  "Colorful abstract mural on brick wall" 
  "https://example.com/image.jpg")
```

### Vote for Art Submission

```clarity
(contract-call? .Muralbit vote-for-art u1)
```

### Approve Art (Admin Only)

```clarity
(contract-call? .Muralbit approve-art u1)
```

### Transfer NFT

```clarity
(contract-call? .Muralbit transfer u1 'SP1... 'SP2...)
```

### Get Art Details

```clarity
(contract-call? .Muralbit get-art-details u1)
```

## Key Functions

### Public Functions

- `submit-art-for-verification` - Submit new public art
- `vote-for-art` - Vote on pending submissions
- `approve-art` - Approve submissions (admin only)
- `claim-art` - Transfer art NFT ownership
- `transfer` - Standard NFT transfer
- `approve` - Approve another principal to transfer
- `transfer-from` - Transfer on behalf of approved principal
- `update-art-metadata` - Update art information
- `batch-approve-submissions` - Approve multiple submissions
- `bulk-vote` - Vote on multiple submissions
- `emergency-mint` - Direct mint (admin only)
- `reject-submission` - Reject pending submission
- `set-mint-price` - Update submission fee
- `pause-contract`/`unpause-contract` - Emergency controls

### Read-Only Functions

- `get-art-details` - Get complete art information
- `get-pending-submission` - Get submission details
- `get-submission-votes` - Get vote count for submission
- `has-voted` - Check if user voted on submission
- `get-user-submissions` - Get user's submission history
- `get-contract-stats` - Get contract statistics
- `get-art-count` - Total number of approved artworks

## Contract Configuration

- **Mint Price**: Fee required to submit art (default: 1,000,000 microSTX)
- **Platform Fee**: Fee percentage for operations (default: 50 basis points)
- **Minimum Votes**: Submissions need 3+ votes for approval
- **Max Submissions**: Users limited to 50 submissions

## Error Codes

- `u400` - Invalid input
- `u401` - Not authorized
- `u402` - Insufficient funds
- `u403` - Not approved
- `u404` - Not found
- `u409` - Already exists

## Installation

1. Clone the repository
2. Install Clarinet
3. Run `clarinet check` to verify contract
4. Deploy with `clarinet deploy`

## Testing

Run tests with:
```bash
npm install
npm test
```
