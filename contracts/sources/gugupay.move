module gugupay::payment_service {
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::table::{Self, Table};
    use pyth::price_info;
    use pyth::price_identifier;
    use pyth::price;
    use pyth::pyth;
    use pyth::price_info::PriceInfoObject;
    use sui::math::{Self, pow};
    use pyth::i64;

    // ======== Errors ========
    const ENotMerchantOwner: u64 = 0;
    const EInvoiceExpired: u64 = 1;
    const EInvoiceAlreadyPaid: u64 = 2;
    const EInsufficientPayment: u64 = 3;
    const EInvalidAmount: u64 = 4;
    const EInvalidExpiryTime: u64 = 5;
    const EInvalidPriceFeed: u64 = 6;

    // ======== Events ========
    public struct MerchantCreated has copy, drop {
        merchant_id: ID,
        name: String,
        owner: address
    }

    public struct InvoiceCreated has copy, drop {
        invoice_id: ID,
        merchant_id: ID,
        description: String,
        amount_usd: u64,
        amount_sui: u64,
        exchange_rate: u64,
        rate_timestamp: u64,
        expires_at: u64
    }

    public struct InvoicePaid has copy, drop {
        invoice_id: ID,
        merchant_id: ID,
        paid_by: address,
        amount_sui: u64
    }

    public struct MerchantUpdated has copy, drop {
        merchant_id: ID,
        name: String,
        owner: address
    }

    public struct InvoiceUpdated has copy, drop {
        invoice_id: ID,
        merchant_id: ID,
        amount_usd: u64,
        expires_at: u64
    }

    // ======== Objects ========
    public struct PaymentStore has key {
        id: UID,
        merchants: Table<ID, Merchant>,
        invoices: Table<ID, Invoice>,
        last_merchant_id: Option<ID>,
        last_invoice_id: Option<ID>,
        merchant_ids: vector<ID>,
        merchant_invoices: Table<ID, vector<ID>>
    }

    public struct Merchant has store {
        id: ID,
        name: String,
        description: String,
        logo_url: String,
        callback_url: String,
        owner: address,
        balance: Balance<SUI>
    }

    public struct Invoice has store {
        id: ID,
        merchant_id: ID,
        description: String,
        amount_usd: u64,
        amount_sui: u64,
        exchange_rate: u64,
        rate_timestamp: u64,
        expires_at: u64,
        is_paid: bool
    }

    // ======== Constants ========
    // SUI/USD price feed ID from Pyth Network
    const PYTH_PRICE_FEED_ID: vector<u8> = x"50c67b3fd225db8912a424dd4baed60ffdde625ed2feaaf283724f9608fea266";
    const PRICE_FEED_MAX_AGE: u64 = 1800; // Price must be no older than 30 minutes
    const INVOICE_VALIDITY_PERIOD: u64 = 1800000; // 30 minutes in milliseconds

    // ======== Init Function ========
    fun init(ctx: &mut TxContext) {
        let store = PaymentStore {
            id: object::new(ctx),
            merchants: table::new(ctx),
            invoices: table::new(ctx),
            last_merchant_id: option::none(),
            last_invoice_id: option::none(),
            merchant_ids: vector::empty<ID>(),
            merchant_invoices: table::new(ctx)
        };
        transfer::share_object(store);
    }

    #[test_only]
    public(package) fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }

    // ======== Public Functions ========
    public entry fun create_merchant(
        store: &mut PaymentStore,
        name: vector<u8>,
        description: vector<u8>,
        logo_url: vector<u8>,
        callback_url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let merchant_id = object::new(ctx);
        let id = object::uid_to_inner(&merchant_id);
        object::delete(merchant_id);

        let name_str = string::utf8(name);
        let owner = tx_context::sender(ctx);

        let merchant = Merchant {
            id,
            name: name_str,
            description: string::utf8(description),
            logo_url: string::utf8(logo_url),
            callback_url: string::utf8(callback_url),
            owner,
            balance: balance::zero()
        };

        table::add(&mut store.merchants, id, merchant);store.last_merchant_id = option::some(
            id
        );
        vector::push_back(&mut store.merchant_ids, id);
        table::add(
            &mut store.merchant_invoices,
            id,
            vector::empty<ID>()
        );

        event::emit(
            MerchantCreated {
                merchant_id: id,
                name: name_str,
                owner
            }
        );
    }

    public entry fun create_invoice(
        store: &mut PaymentStore,
        merchant_id: ID,
        description: vector<u8>,
        amount_usd: u64,
        clock: &Clock,
        price_info_object: &PriceInfoObject,
        ctx: &mut TxContext
    ) {
        let merchant = table::borrow(&store.merchants, merchant_id);
        assert!(
            tx_context::sender(ctx) == merchant.owner,
            ENotMerchantOwner
        );
        assert!(amount_usd > 0, EInvalidAmount);

        // Get SUI/USD price from Pyth Oracle
        let price_struct = pyth::get_price_no_older_than(
            price_info_object,
            clock,
            PRICE_FEED_MAX_AGE
        );

        // Verify this is the correct SUI/USD price feed
        let price_info = price_info::get_price_info_from_price_info_object(
            price_info_object
        );
        let price_id = price_identifier::get_bytes(
            &price_info::get_price_identifier(&price_info)
        );
        assert!(
            price_id == PYTH_PRICE_FEED_ID,
            EInvalidPriceFeed
        );

        // Get price and convert considering decimals
        let price_i64 = price::get_price(&price_struct);
        let expo_i64 = price::get_expo(&price_struct);

        // Convert price to u64 (assuming price is positive)
        let price_u64 = i64::get_magnitude_if_positive(&price_i64);
        let expo = i64::get_magnitude_if_negative(&expo_i64); // Expo is typically negative

        // Calculate required SUI amount
        let decimals = 9; // SUI decimals
        let price_decimals = (expo as u8);
        let price_multiplier = math::pow(10, price_decimals);

        let exchange_rate = price_u64; // Store the raw exchange rate
        let amount_sui = (
            amount_usd * (math::pow(10, decimals) as u64) * price_multiplier
        ) / price_u64;

        let current_time = clock::timestamp_ms(clock);
        let expires_at = current_time + INVOICE_VALIDITY_PERIOD;

        let invoice_id = object::new(ctx);
        let id = object::uid_to_inner(&invoice_id);
        object::delete(invoice_id);

        let invoice = Invoice {
            id,
            merchant_id,
            description: string::utf8(description),
            amount_usd,
            amount_sui,
            exchange_rate, // Store the exchange rate
            rate_timestamp: current_time, // Store when we got the rate
            expires_at,
            is_paid: false
        };

        table::add(&mut store.invoices, id, invoice);store.last_invoice_id = option::some(
            id
        );

        // Add invoice ID to merchant's invoice list
        let merchant_invoices = table::borrow_mut(
            &mut store.merchant_invoices,
            merchant_id
        );
        vector::push_back(merchant_invoices, id);

        event::emit(
            InvoiceCreated {
                invoice_id: id,
                merchant_id,
                description: string::utf8(description),
                amount_usd,
                amount_sui,
                exchange_rate,
                rate_timestamp: current_time,
                expires_at
            }
        );
    }

    public entry fun pay_invoice(
        store: &mut PaymentStore,
        invoice_id: ID,
        mut payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let invoice = table::borrow_mut(&mut store.invoices, invoice_id);
        let merchant = table::borrow_mut(
            &mut store.merchants,
            invoice.merchant_id
        );

        assert!(
            !invoice.is_paid,
            EInvoiceAlreadyPaid
        );
        assert!(
            clock::timestamp_ms(clock) <= invoice.expires_at,
            EInvoiceExpired
        );

        let payment_value = coin::value(&payment);
        assert!(
            payment_value >= invoice.amount_sui,
            EInsufficientPayment
        );

        // Split excess payment if any
        if (payment_value > invoice.amount_sui) {
            let excess = coin::split(
                &mut payment,
                payment_value - invoice.amount_sui,
                ctx
            );
            transfer::public_transfer(excess, tx_context::sender(ctx));
        };

        // Add payment to merchant balance
        let balance = coin::into_balance(payment);
        balance::join(&mut merchant.balance, balance);

        // Mark invoice as paid
        invoice.is_paid = true;

        event::emit(
            InvoicePaid {
                invoice_id,
                merchant_id: invoice.merchant_id,
                paid_by: tx_context::sender(ctx),
                amount_sui: invoice.amount_sui
            }
        );
    }

    public entry fun withdraw_balance(
        store: &mut PaymentStore,
        merchant_id: ID,
        ctx: &mut TxContext
    ) {
        let merchant = table::borrow_mut(&mut store.merchants, merchant_id);
        assert!(
            tx_context::sender(ctx) == merchant.owner,
            ENotMerchantOwner
        );

        let amount = balance::value(&merchant.balance);
        let withdrawn = coin::from_balance(
            balance::split(&mut merchant.balance, amount),
            ctx
        );
        transfer::public_transfer(withdrawn, merchant.owner);
    }

    public entry fun update_merchant(
        store: &mut PaymentStore,
        merchant_id: ID,
        name: vector<u8>,
        description: vector<u8>,
        logo_url: vector<u8>,
        callback_url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let merchant = table::borrow_mut(&mut store.merchants, merchant_id);
        // Verify sender is merchant owner
        assert!(
            tx_context::sender(ctx) == merchant.owner,
            ENotMerchantOwner
        );

        // Update merchant details
        merchant.name = string::utf8(name);
        merchant.description = string::utf8(description);
        merchant.logo_url = string::utf8(logo_url);
        merchant.callback_url = string::utf8(callback_url);

        event::emit(
            MerchantUpdated {
                merchant_id: merchant.id,
                name: merchant.name,
                owner: merchant.owner
            }
        );
    }

    public entry fun update_invoice(
        store: &mut PaymentStore,
        invoice_id: ID,
        description: vector<u8>,
        amount_usd: u64,
        expires_at: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let invoice = table::borrow_mut(&mut store.invoices, invoice_id);
        let merchant = table::borrow(
            &store.merchants,
            invoice.merchant_id
        );

        // Verify sender is merchant owner
        assert!(
            tx_context::sender(ctx) == merchant.owner,
            ENotMerchantOwner
        );

        // Cannot update paid invoices
        assert!(
            !invoice.is_paid,
            EInvoiceAlreadyPaid
        );

        // Validate new values
        assert!(amount_usd > 0, EInvalidAmount);
        assert!(
            expires_at > clock::timestamp_ms(clock),
            EInvalidExpiryTime
        );

        // Update invoice details
        invoice.description = string::utf8(description);
        invoice.amount_usd = amount_usd;
        invoice.expires_at = expires_at;

        event::emit(
            InvoiceUpdated {
                invoice_id,
                merchant_id: invoice.merchant_id,
                amount_usd,
                expires_at
            }
        );
    }

    // ======== View Functions ========
    public fun get_merchant_owner(store: &PaymentStore, merchant_id: ID): address {
        let merchant = table::borrow(&store.merchants, merchant_id);
        merchant.owner
    }

    public fun get_invoice_amount_sui(store: &PaymentStore, invoice_id: ID): u64 {
        let invoice = table::borrow(&store.invoices, invoice_id);
        invoice.amount_sui
    }

    public fun get_invoice_merchant_id(store: &PaymentStore, invoice_id: ID): ID {
        let invoice = table::borrow(&store.invoices, invoice_id);
        invoice.merchant_id
    }

    public fun is_invoice_paid(store: &PaymentStore, invoice_id: ID): bool {
        let invoice = table::borrow(&store.invoices, invoice_id);
        invoice.is_paid
    }

    public fun get_merchant_balance(store: &PaymentStore, merchant_id: ID): u64 {
        let merchant = table::borrow(&store.merchants, merchant_id);
        balance::value(&merchant.balance)
    }

    public fun get_merchant_by_owner(store: &PaymentStore, owner: address): vector<ID> {
        let mut merchant_ids = vector::empty<ID>();
        let mut i = 0;
        let len = vector::length(&store.merchant_ids);

        while (i < len) {
            let merchant_id = *vector::borrow(&store.merchant_ids, i);
            let merchant = table::borrow(&store.merchants, merchant_id);
            if (merchant.owner == owner) {
                vector::push_back(&mut merchant_ids, merchant_id);
            };
            i = i + 1;
        };

        merchant_ids
    }

    // Add these helper functions after the view functions
    #[test_only]
    public(package) fun get_merchant_id_for_testing(store: &PaymentStore): ID {
        assert!(
            option::is_some(&store.last_merchant_id),
            0
        );
        *option::borrow(&store.last_merchant_id)
    }

    #[test_only]
    public(package) fun get_invoice_id_for_testing(
        store: &PaymentStore,
        _merchant_id: ID
    ): ID {
        assert!(
            option::is_some(&store.last_invoice_id),
            0
        );
        *option::borrow(&store.last_invoice_id)
    }

    // Add new helper functions for testing
    #[test_only]
    public(package) fun get_merchant_for_testing(store: &PaymentStore, merchant_id: ID)
        : &Merchant {
        table::borrow(&store.merchants, merchant_id)
    }

    #[test_only]
    public(package) fun get_invoice_for_testing(store: &PaymentStore, invoice_id: ID): &Invoice {
        table::borrow(&store.invoices, invoice_id)
    }

    // Add these new view functions after the existing view functions

    /// Get all invoice IDs for a merchant
    /// filter_paid: Option<bool> - if Some(true) returns only paid invoices,
    /// if Some(false) returns only unpaid invoices, if None returns all invoices
    public fun get_merchant_invoices(
        store: &PaymentStore,
        merchant_id: ID,
        filter_paid: Option<bool>
    ): vector<ID> {
        let mut result = vector::empty<ID>();

        // Verify merchant exists
        assert!(
            table::contains(&store.merchants, merchant_id),
            ENotMerchantOwner
        );

        let merchant_invoices = table::borrow(
            &store.merchant_invoices,
            merchant_id
        );
        let len = vector::length(merchant_invoices);
        let mut i = 0;

        while (i < len) {
            let invoice_id = *vector::borrow(merchant_invoices, i);
            let invoice = table::borrow(&store.invoices, invoice_id);

            if (should_include_invoice(invoice.is_paid, &filter_paid)) {
                vector::push_back(&mut result, invoice_id);
            };

            i = i + 1;
        };

        result
    }

    /// Helper function to determine if an invoice should be included based on filter
    fun should_include_invoice(is_paid: bool, filter: &Option<bool>): bool {
        if (option::is_none(filter)) { true // Include all if no filter
        } else {
            let filter_value = *option::borrow(filter);
            is_paid == filter_value // Include only if matches filter
        }
    }

    /// Get invoice details
    public fun get_invoice_details(store: &PaymentStore, invoice_id: ID)
        : (
        ID, // merchant_id
        String, // description
        u64, // amount_usd
        u64, // amount_sui
        u64, // exchange_rate
        u64, // rate_timestamp
        u64, // expires_at
        bool // is_paid
    ) {
        let invoice = table::borrow(&store.invoices, invoice_id);
        (
            invoice.merchant_id,
            invoice.description,
            invoice.amount_usd,
            invoice.amount_sui,
            invoice.exchange_rate,
            invoice.rate_timestamp,
            invoice.expires_at,
            invoice.is_paid
        )
    }

    /// Get merchant details
    public fun get_merchant_details(store: &PaymentStore, merchant_id: ID)
        : (
        ID, // id
        String, // name
        String, // description
        String, // logo_url
        String, // callback_url
    ) {
        let merchant = table::borrow(&store.merchants, merchant_id);
        (
            merchant.id,
            merchant.name,
            merchant.description,
            merchant.logo_url,
            merchant.callback_url,
        )
    }
}
