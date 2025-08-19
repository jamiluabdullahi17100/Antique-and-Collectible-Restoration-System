# Antique and Collectible Restoration System

A comprehensive blockchain-based system for managing antique and collectible restoration projects using Clarity smart contracts on the Stacks blockchain.

## Overview

This system provides a transparent, immutable platform for managing the entire lifecycle of antique and collectible restoration projects. It ensures accountability, tracks provenance, and facilitates trust between collectors, craftspeople, and insurance providers.

## Core Features

### 1. Restoration Project Management
- Create and track restoration projects from initiation to completion
- Document detailed project specifications and requirements
- Monitor progress through defined milestones
- Maintain immutable project history

### 2. Craftsperson Qualification System
- Register qualified craftspeople with verified credentials
- Track specializations and technique certifications
- Maintain reputation scores based on completed projects
- Verify craftsperson authenticity and expertise

### 3. Cost Estimation and Timeline Management
- Generate transparent cost breakdowns for restoration work
- Set and track project timelines with milestone-based payments
- Handle escrow functionality for secure payment processing
- Provide real-time budget and schedule updates

### 4. Authentication and Provenance Documentation
- Create immutable provenance records for antiques and collectibles
- Document ownership history and authenticity certificates
- Track restoration history and modifications
- Generate verifiable certificates of authenticity

### 5. Insurance Claims and Value Assessment
- Support insurance claim documentation and processing
- Provide pre and post-restoration value assessments
- Generate detailed condition reports
- Facilitate insurance provider verification

## Smart Contract Architecture

The system consists of five interconnected Clarity smart contracts:

1. **restoration-core.clar** - Main project management and coordination
2. **craftsperson-registry.clar** - Craftsperson qualification and management
3. **cost-timeline.clar** - Financial and scheduling operations
4. **provenance-auth.clar** - Authentication and provenance tracking
5. **insurance-claims.clar** - Insurance and valuation services

## Key Benefits

- **Transparency**: All project details and transactions are recorded on-chain
- **Trust**: Immutable records ensure accountability for all parties
- **Efficiency**: Automated processes reduce administrative overhead
- **Security**: Blockchain-based escrow and payment systems
- **Compliance**: Built-in support for insurance and regulatory requirements

## Data Types

### Project Status
- `pending` - Project created, awaiting craftsperson assignment
- `in-progress` - Active restoration work
- `review` - Work completed, awaiting approval
- `completed` - Project finished and approved
- `disputed` - Issues requiring resolution

### Craftsperson Levels
- `apprentice` - Entry level, supervised work only
- `journeyman` - Independent work on standard projects
- `master` - Complex projects and supervision capabilities
- `expert` - Rare and highly valuable items

### Item Categories
- `furniture` - Antique furniture restoration
- `artwork` - Paintings, sculptures, and fine art
- `jewelry` - Precious metals and gemstone work
- `textiles` - Historical fabrics and clothing
- `ceramics` - Pottery, porcelain, and ceramic items
- `books` - Rare books and manuscript restoration
- `instruments` - Musical instruments and scientific equipment

## Getting Started

1. Deploy the smart contracts to the Stacks blockchain
2. Register craftspeople with verified credentials
3. Create restoration projects with detailed specifications
4. Assign qualified craftspeople to projects
5. Monitor progress and handle payments through the system

## Testing

The system includes comprehensive tests using Vitest to ensure contract functionality and security. Run tests with:

\`\`\`bash
npm test
\`\`\`

## Configuration

- **Clarinet.toml** - Blockchain development configuration
- **package.json** - Node.js dependencies and scripts
- **vitest.config.js** - Test configuration

## Security Considerations

- All financial transactions use secure escrow mechanisms
- Multi-signature requirements for high-value projects
- Time-locked payments tied to milestone completion
- Dispute resolution mechanisms for project conflicts

## License

This project is licensed under the MIT License - see the LICENSE file for details.
