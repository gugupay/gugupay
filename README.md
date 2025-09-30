# Gugupay

Gugupay is a decentralized payment solution on the Sui blockchain that enables merchants to easily receive payments from customers via QR codes. Customers can pay directly with their Sui wallet using Sui tokens, which are automatically converted to stablecoin-equivalent amounts based on live exchange rates from the Pyth oracle. This approach removes the need for customers to hold stablecoins, simplifying the payment process while ensuring the merchant receives a stable value. With Gugupay, merchants can offer a seamless, crypto-based payment method that's accessible and straightforward for customers.

## 🏗️ Project Structure

This monorepo contains three main components:

```
gugupay2/
├── contracts/      # Sui Move smart contracts
├── sdk/           # TypeScript SDK for developers
├── web/           # Web application (Astro + Svelte + React)
└── package.json   # Monorepo workspace configuration
```

## 📦 Components

### 1. Smart Contracts (`/contracts`)

Sui Move smart contracts built with **Pyth Network** integration for real-time price feeds.

**Key Features:**
- Shared object design for scalability
- Merchant registration and management
- Invoice creation with USD pricing
- Automatic SUI/USD conversion using Pyth oracles
- Payment processing and balance withdrawal
- Real-time payment events

**Tech Stack:**
- Sui Move (2024 edition)
- Pyth Network oracle integration
- Wormhole for cross-chain messaging

**Commands:**
```bash
cd contracts
sui move build        # Build contracts
sui move test         # Run tests
sui client publish    # Deploy to network
```

[View detailed contract documentation →](./contracts/README.md)

### 2. SDK (`/sdk`)

TypeScript SDK for integrating Gugupay payments into applications.

**Key Features:**
- Simple API for merchant and invoice management
- Automatic price conversion using Pyth
- Support for testnet and mainnet
- Type-safe interfaces
- Real-time price updates from Hermes

**Installation:**
```bash
npm install @gugupay/sdk
```

**Quick Example:**
```typescript
import { GugupayClient } from '@gugupay/sdk';

const client = new GugupayClient('testnet');
const txb = new Transaction();

// Create merchant
await client.createMerchantObject({
  txb,
  name: 'My Shop',
  imageURL: 'https://example.com/logo.png',
  callbackURL: 'https://myshop.com/callback',
  description: 'My awesome shop'
});

// Create invoice
await client.createInvoice({
  txb,
  merchantId: 'merchant_id',
  amount_usd: 10.0,
  description: 'Product purchase'
});
```

**Tech Stack:**
- TypeScript
- @mysten/sui SDK
- @pythnetwork/pyth-sui-js

**Commands:**
```bash
npm run sdk:build    # Build SDK
```

[View detailed SDK documentation →](./sdk/README.md)

### 3. Web Application (`/web`)

Modern web application providing merchant dashboard and payment interface.

**Key Features:**
- Merchant dashboard for managing payments
- QR code generation for payment links
- Real-time payment status updates
- Wallet integration (Sui wallets)
- Documentation site built-in
- Mobile-responsive payment interface

**Tech Stack:**
- Astro 4.x (Static site generation)
- Svelte 5.x (UI components)
- React 18.x (Some components)
- TailwindCSS + DaisyUI (Styling)
- Starlight (Documentation)
- Mersui (Sui wallet integration)

**Pages:**
- `/` - Landing page
- `/app` - Merchant dashboard
- `/pay` - Payment interface
- `/donate` - Donation page with Mersui integration
- `/docs` - Full documentation

**Commands:**
```bash
npm run web          # Start dev server
npm run web:build    # Build for production
```

[View web application README →](./web/README.md)

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ and npm
- Sui CLI (for contract development)
- Git

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/gugupay2.git
cd gugupay2
```

2. Install dependencies:
```bash
npm install
```

3. Build the SDK:
```bash
npm run sdk:build
```

4. Start the web application:
```bash
npm run web
```

The web app will be available at `http://localhost:4321`

## 🔧 Development Workflow

### Working with Smart Contracts
```bash
cd contracts
sui move build
sui move test
```

### Working with SDK
```bash
npm run sdk:build     # Build SDK after changes
```

### Working with Web App
```bash
npm run web           # Hot reload enabled
```

## 📚 Documentation

- **Smart Contracts**: See [contracts/README.md](./contracts/README.md)
- **SDK Documentation**: See [sdk/README.md](./sdk/README.md)
- **Web App**: See [web/README.md](./web/README.md)
- **Live Docs**: Available at `/docs` when running the web app

## 🌐 Environment Variables

### SDK & Contracts
Key environment variables are defined in:
- `sdk/src/const.ts` - SDK constants
- `contracts/README.md` - Contract addresses

### Web Application
Create `.env` in the `web/` directory:
```bash
# See web/.env.example for required variables
```

## 🛠️ Tech Stack Summary

| Component | Technologies |
|-----------|-------------|
| **Blockchain** | Sui, Pyth Oracle, Wormhole |
| **Smart Contracts** | Sui Move |
| **SDK** | TypeScript, @mysten/sui |
| **Frontend** | Astro, Svelte, React, TailwindCSS |
| **UI Framework** | DaisyUI |
| **Wallet** | Mersui, @suiet/wallet-sdk |
| **Documentation** | Starlight |

## 🏛️ Architecture

```
┌─────────────────────────────────────────────┐
│           Web Application (Astro)           │
│  ┌─────────────────────────────────────┐   │
│  │  Merchant Dashboard  │  Payment UI  │   │
│  └─────────────────────────────────────┘   │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│          Gugupay SDK (TypeScript)           │
│  ┌─────────────────────────────────────┐   │
│  │  Client API  │  Type Definitions    │   │
│  └─────────────────────────────────────┘   │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│     Sui Blockchain + Smart Contracts        │
│  ┌─────────────────────────────────────┐   │
│  │  Payment Store  │  Merchants │ Inv. │   │
│  └─────────────────────────────────────┘   │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│         Pyth Oracle (Price Feeds)           │
└─────────────────────────────────────────────┘
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

Apache-2.0

## 🔗 Links

- Website: [gugupay.io](https://gugupay.io)
- Documentation: Available at `/docs` in the web app
- GitHub: [GitHub Repository](https://github.com/yourusername/gugupay2)
