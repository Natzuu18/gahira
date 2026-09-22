# Billing Stage Implementation Plan (Admin/Owner Side)

This plan implements the complete financial workflow between miners and owners as described by the user, covering both individual and group requests.

## User Review Required

> [!IMPORTANT]
> The workflow transitions from processing completion to financial handling, then to payment. The payment method is strictly cash.

## Proposed Changes

### Domain & Services
- **Service Layer**: Ensure `submitFinancialHandling` and `recordPayment` correctly handle group breakdowns and itemized expenses.

### Presentation (Admin Side)

#### 1. Processing Completion View
- [MODIFY] `lib/presentation/admin/billing_page.dart`:
    - Add a "READY FOR BILLING" indicator/badge in the pending list for requests with `processingCompleted` status.
    - Improve the request list card to clearly distinguish between requests waiting for financial handling vs. those waiting for payment.

#### 2. Financial Handling Workflow
- [MODIFY] `lib/presentation/admin/billing_page.dart`:
    - Refine `_showFinancialChoiceStep` to offer "Gold Buying" or "Skip to Billing".
    - Refine `_showGoldBuyingStep` to capture gold weight, buying price, and "Deduct Bill" preference.
    - Refine `_showBillingStep` to add itemized expenses (Processing Fee + Others).

#### 3. Settlement Summary (Step 5)
- [MODIFY] `lib/presentation/admin/billing_page.dart`:
    - Implement a structured "Financial Settlement Summary" widget.
    - Clearly show: **Total Bill**, **Gold Purchase Value**, and **Final Net Amount**.
    - For groups, show the breakdown of how much each miner owes/gets.

#### 4. Payment Recording (Step 6)
- [MODIFY] `lib/presentation/admin/billing_page.dart`:
    - Update `_showPaymentStep` and `_showIndividualPaymentStep`.
    - Add a prominent "Payment method: CASH ONLY" notice.
    - Enhance the receipt upload placeholder.
    - Calculate and display the remaining balance after the payment entry.

## Verification Plan

### Manual Verification
1. Log in as Admin.
2. Go to **Billing/Financial Handling**.
3. Select a completed processing request.
4. Go through the Gold Buying step (test both buying and skipping).
5. Add extra expenses (e.g., "Cash Advance").
6. Verify the Settlement Summary totals.
7. Record a cash payment and verify the request moves to "Completed" or "Partially Paid" status.
8. Verify group breakdown totals match the individual payments.
