# GugupaySDK

A TypeScript SDK for integrating Gugupay payments into your applications. Gugupay enables merchants to accept cryptocurrency payments using the Sui blockchain.

## Installation

```bash
npm install @gugupay/sdk
```

## Quick Start

```typescript
import {GugupayClient} from '@gugupay/sdk';

// Initialize client (use 'mainnet' for production)
const client = new GugupayClient('testnet');

// Create a new transaction
const txb = new Transaction();

// Register as a merchant
const merchant = await client.createMerchantObject({
  txb,
  name: 'Coffee Shop',
  imageURL: 'https://example.com/logo.png',
  callbackURL: 'https://myshop.com/callback',
  description: 'Best coffee in town',
});

// Create an invoice
const invoice = await client.createInvoice({
  txb,
  merchantId: merchant.id,
  amount_usd: 5.0,
  description: 'Large Coffee',
});

// Pay an invoice
await client.payInvoice({
  txb,
  invoiceId: invoice.id,
  amountSui: invoice.amountSui,
});
```

## Features

- Create and manage merchant profiles
- Generate payment invoices with USD pricing
- Process cryptocurrency payments
- Real-time payment notifications via webhooks
- Automatic currency conversion
- Support for both testnet and mainnet environments

## API Reference

### `GugupayClient`

#### Constructor

```typescript
const client = new GugupayClient(network: "testnet" | "mainnet");
```

#### Methods

##### `createMerchantObject`

Create a new merchant profile.

```typescript
const merchant = await client.createMerchantObject({
  txb: Transaction,
  name: string,
  imageURL: string,
  callbackURL: string,
  description: string,
});
```

##### `createInvoice`

Generate a new payment invoice.

```typescript
const invoice = await client.createInvoice({
  txb: Transaction,
  merchantId: string,
  amount_usd: number,
  description: string,
});
```

##### `payInvoice`

Process a payment for an invoice.

```typescript
await client.payInvoice({
  txb: Transaction,
  invoiceId: string,
  amountSui: number,
});
```

## Error Handling

The SDK throws typed errors that you can catch and handle:

```typescript
try {
  await client.createInvoice({...});
} catch (error) {
  if (error instanceof GugupayError) {
    console.error('Payment failed:', error.message);
  }
}
```

## Webhook Integration

To receive payment notifications, set up a webhook endpoint in your merchant profile:

1. Provide a `callbackURL` when creating your merchant profile
2. Implement an endpoint at your callback URL to handle webhook events
3. Verify webhook signatures to ensure authenticity

## Development

To run tests:

```bash
npm test
```

## Support

- Documentation: [https://docs.gugupay.com](https://gugupay.io/docs)
- Issues: [GitHub Issues](https://github.com/gugupay/gugupay/issues)

## License

Apache-2.0
