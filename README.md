# QueueUp KMP SDK (Android & iOS)

The QueueUp SDK lets your Android or iOS app talk to the QueueUp platform: merchants and
products, checkouts and payments, fulfillment (tickets), wallet, vouchers, memberships, and the
end-user auth flow.

The SDK is Kotlin Multiplatform. Android consumes it as a Kotlin library; iOS consumes it as an
Objective-C / Swift framework.

## Contents

- [Quick start](#quick-start)
- [Initialization](#initialization)
- [Authentication](#authentication)
- [Domain APIs](#domain-apis)
- [Idempotency](#idempotency)
- [Error handling](#error-handling)

## Quick start

### Install (Android) [TODO: Update when complete]

The SDK is published as a regular Android library artifact:

```kotlin
dependencies {
    implementation("todo-update-artifact")
}
```

### Install (iOS) [TODO: Update when complete]

The SDK ships as the `QueueUpCore` framework. Add it to your Xcode target and import it:

```swift
import QueueUpCore
```

## Initialization

Initialize the SDK once per process, as early as possible (e.g. in your `Application.onCreate` on
Android or your `App` initializer on iOS). `init` returns a `QueueUpClient`; keep this handle —
all domain APIs hang off it.

`init` may throw `QueueUpInitException` if startup fails.

### Android

```kotlin
val queueUp = QueueUp.init(
    environment = Environment.Production,
    campaignId = "your-campaign-id",
    logger = { message -> Log.d("QueueUp", message) }, // optional
)
```

### iOS

```swift
MyApp.queueUp = QueueUp.shared.doInit(
    environment: .production,
    campaignId: "your-campaign-id",
    logger: PrintLogger() // optional, conforms to QueueUpCore.Logger
)
```

Calling `init` again tears down the previous client and replaces it; discard any handle returned
by an earlier call.

### Environments

| Value | Use for |
| --- | --- |
| `Environment.Acceptance` | Integration / staging against QueueUp's acceptance backend. |
| `Environment.Production` | Live traffic. |

## Authentication

The SDK manages tokens (storage, refresh, attach to requests) for you — your job is to (a) drive the
sign-in flow and (b) react when the SDK signals that authentication is needed.

### Reacting to "authentication required"

`client.auth.authenticationRequired` is a `StateFlow<AuthenticationRequired?>` (Swift sees it as
an `AsyncSequence`). It emits:

- `null` — no action needed.
- `NoSession` — no session has ever been established; prompt the user to sign in.
- `SessionExpired` — a previously valid session could not be refreshed; prompt the user to
  sign in again.

Because it's a `StateFlow`, late subscribers immediately receive the latest value — you won't
miss the signal by subscribing after the SDK has already determined that authentication is
required.

**Android:**

```kotlin
viewModelScope.launch {
    client.auth.authenticationRequired
        .filterNotNull()
        .collect { reason ->
            when (reason) {
                AuthenticationRequired.NoSession -> showSignIn()
                AuthenticationRequired.SessionExpired -> showSignInExpired()
            }
        }
}
```

**iOS:**

```swift
Task { @MainActor in
    for await reason in client.auth.authenticationRequired {
        guard let reason else { continue }
        switch onEnum(of: reason) {
        case .noSession:     showSignIn()
        case .sessionExpired: showSignInExpired()
        }
    }
}
```

### Sign-in flows

The SDK supports two sign-in flows; pick whichever fits your product.

**Magic link** (the default). The host requests a magic-link email, the user clicks the link,
your app receives the callback URL via deep / universal link, and you hand it back to the SDK:

```kotlin
client.auth.requestMagicLink(
    email = "user@example.com",
    callbackUrl = "https://your.app/auth/callback", // must be whitelisted
)
// later, when your deep-link handler receives the callback URL:
client.auth.verifyMagicLink(url = receivedUrl)
```

**Authorization code exchange.** If the host already has a single-use server-to-server token,
exchange it for a session directly:

```kotlin
client.auth.exchangeAuthorizationCode(code = "single-use-code")
```

### Checking & ending sessions

```kotlin
// local check: do we have stored tokens?
client.auth.hasAuthenticated()

// local check: are the stored tokens still valid?
client.auth.isAuthenticated()

// server round-trip
client.auth.isAuthenticated(checkRemotely = true)

// clears stored tokens
client.auth.logout()
```

## Domain APIs

All domain APIs are reached from the `QueueUpClient` returned by `init`. Every method is
`suspend` (Swift sees them as `async throws`). Errors are typed — see
[Error handling](#error-handling).

| Property | What it does |
| --- | --- |
| `client.agreements` | Pending consent prompts (partner-driven). |
| `client.checkouts` | Create and confirm checkouts. |
| `client.fulfillment` | Available timeslots, the user's orders, their tickets, and the consolidated PDF. |
| `client.memberships` | The user's memberships within the campaign. |
| `client.merchants` | List, search, look up merchants in your campaign. |
| `client.payments` | Look up a payment by ID. |
| `client.products` | List products by merchant, look one up, fetch a calendar of availability. |
| `client.vouchers` | Validate and redeem voucher codes. |
| `client.wallet` | Loyalty token balance, transactions, partner reconciliation. |

### Agreements

```kotlin
val pending = client.agreements.getPendingAgreements(partnerUserToken = "...")
client.agreements.acceptPendingAgreements(
    partnerUserToken = "...",
    agreementsIds = pending.map { it.id }.toSet(),
)
```

### Checkouts

`createCheckout` reserves capacity (a "checkout") that expires if not confirmed. `confirmCheckout`
returns a PSP-hosted payment URL — redirect the user there. Both calls are idempotent — see
[Idempotency](#idempotency).

```kotlin
val checkout = client.checkouts.createCheckout(
    date = Clock.System.now(),
    flexibleDate = false,
    lines = listOf(Line(productId = "...", quantity = 2)),
    externalReference = "cart-123",
)

val confirmed = client.checkouts.confirmCheckout(
    checkoutId = checkout.id,
    email = "user@example.com",
    firstName = "First",
    lastName = "Last",
    postalCode = "1011AA",
    returnUrl = "https://your.app/payment/return",
)
```

### Fulfillment (tickets)

```kotlin
val slots = client.fulfillment.getAvailableTimeslots(
    productIds = setOf("product-uuid"),
    date = LocalDate(2026, 7, 10),
)

val orders = client.fulfillment.getFulfillmentOrders(
    limit = 20,
    status = FulfillmentStatus.COMPLETED, // optional filter
)

// Single order (includes tickets + presigned PDF URL when ready):
val order = client.fulfillment.getFulfillmentOrderByOrderId(orderId)
```

### Memberships

```kotlin
val memberships = client.memberships.getMemberships()
```

### Merchants

```kotlin
val page = client.merchants.getAll(limit = 50)
val merchant = client.merchants.getById("merchant-uuid")
val nearby = client.merchants.search(
    query = "museum",
    geo = Geo(latitude = 52.37, longitude = 4.89, distanceMeters = 5_000),
)
// page.pagination.nextToken — pass to the next getAll/search to fetch the next page.
```

### Payments

```kotlin
val payment = client.payments.getById("payment-id")
```

### Products

```kotlin
val products = client.products.getAllProductsByMerchantId("merchant-uuid")
val product = client.products.getById(merchantId = "...", productId = "...")
val calendar = client.products.getProductCalendar(
    merchantId = "...",
    productId = "...",
    from = LocalDate(2026, 7, 1),
    to = LocalDate(2026, 7, 14),
)
```

### Vouchers

```kotlin
val status = client.vouchers.validateVoucherCode("ABC123")
val redeemed = client.vouchers.redeemVoucher(code = "ABC123")
```

### Wallet

```kotlin
val balance = client.wallet.getLoyaltyTokenBalance()
val txs = client.wallet.getTransactions(limit = 20)

// For partner-counter campaigns:
val reconciled = client.wallet.syncLoyaltyBalanceWithPartner(partnerUserToken = "...")
```

## Idempotency

Some endpoints send an `Idempotency-Key` header so the backend collapses duplicate requests
instead of acting on them twice (e.g., creating duplicate reservations or payment redirects). By
default the SDK manages the key for you — you don't need to do anything.

> Idempotency currently applies to `client.checkouts.createCheckout` and
> `client.checkouts.confirmCheckout`. More endpoints may opt in over time.

**Default: SDK-managed.** Call an idempotent endpoint without an `idempotencyConfig` and the SDK
takes care of the `Idempotency-Key` for you, including reusing the same key for an immediate
duplicate call (e.g., a double-tapped button) so the backend collapses it.

**Override: caller-managed.** Idempotent endpoints accept an `idempotencyConfig: IdempotencyConfig?`
argument. Supplying one hands key management to you:

```kotlin
// Supply your own key — forwarded verbatim; the SDK will not generate or manage one for this call.
IdempotencyConfig(key = "my-idempotency-key")
```

When you provide a `key`, dedup, rotation, and any retry semantics become your responsibility on
that call.

## Error handling

All domain methods are declared `@Throws(Throwable::class)`. The SDK throws a sealed
`eu.queueup.data.errors.Error` for known failure shapes:

| Type | When |
| --- | --- |
| `Error.Unauthorized` | 401 from the API. Tokens may have expired or are missing. |
| `Error.ApiProblem` | Non-2xx with an RFC 7807 `problem+json` body. Inspect `.problem`. |
| `Error.ApiError` | Non-2xx without a recognized problem body (e.g. proxied third-party errors). |
| `Error.NetworkError` | IO / connectivity failure. |

Init failures throw `QueueUpInitException` instead.

```kotlin
try {
    client.checkouts.createCheckout(/* … */)
} catch (e: Error.ApiProblem) {
    // e.problem.title / e.problem.detail
} catch (e: Error.Unauthorized) {
    // SDK has already emitted on authenticationRequired
} catch (e: Error.NetworkError) {
    // retryable
}
```
