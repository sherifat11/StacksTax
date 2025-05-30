
# 📊 StacksTax: A Comprehensive Smart Taxation Framework on Stacks

## Overview

**TaxMaster** is a powerful Clarity smart contract designed for managing complex tax operations, supporting multiple currencies, progressive tax brackets, customizable deductions, refund logic, and comprehensive reporting. Built for jurisdictions or DAOs looking to automate and audit taxation processes on the Stacks blockchain.

---

## 🔧 Features

### ✅ Authorization & Access Control

* Only the designated administrator can update sensitive data like tax brackets, exchange rates, and approve deductions or issue refunds.

### 💱 Multi-Currency Support

* Stores and updates exchange rates between supported currencies.
* Converts income, taxes, and refunds into the base currency (STX).

### 📈 Progressive Tax Brackets

* Customizable income brackets for each taxpayer category.
* Automatically calculates progressive tax obligations.

### 🧾 Deduction Handling

* Admin-defined deduction types with caps and approval requirements.
* Taxpayers can submit deduction requests.
* Admin can approve individual deduction requests.

### 💸 Refund Mechanism

* Allows issuing tax refunds using `stx-transfer?`.
* Validates refund limits based on tax paid and currency conversions.

### 📚 Detailed Taxpayer Profiles

* Tracks cumulative tax paid, refunds issued, claimed deductions, and transaction history.

### 📊 Reporting Functions

* Annual tax report generation.
* Net tax obligation computation considering all approved deductions.

---

## 🧱 Contract Data Structures

### Constants

* Error codes for common failures (e.g., unauthorized actions, invalid input).

### Variables

* `administrator`: Contract owner.
* `minimum-taxable-amount`: Minimum taxable threshold.

### Maps

* `currency-exchange-rates`: Stores exchange rate, last update, and currency status.
* `income-tax-brackets`: Defines progressive tax rates per income category.
* `available-deductions`: Registry of deduction types with conditions.
* `taxpayer-profiles`: Tracks each taxpayer’s full record and history.

---

## 🛠️ Key Functions

### 🧮 Read-Only

* `get-taxpayer-profile`, `get-tax-bracket-info`, `get-currency-rate`, `get-deduction-info`
* `convert-between-currencies`: Converts amounts between currencies.
* `calculate-progressive-tax`: Calculates tax due using progressive brackets.
* `generate-annual-tax-report`: Summary of payments, refunds, deductions.
* `calculate-net-tax-obligation`: Final tax due after approved deductions.

### 📤 Public (Admin Only for Some)

* `update-exchange-rate`: Update exchange rate for a currency.
* `register-deduction-type`: Add a new deduction type.
* `submit-deduction-request`: Taxpayer submits a deduction.
* `approve-deduction-request`: Admin approves a pending deduction.
* `issue-tax-refund`: Admin refunds taxes in STX after conversion.

---

## 🔒 Access Control

| Function                    | Admin Only? |
| --------------------------- | ----------- |
| `update-exchange-rate`      | ✅           |
| `register-deduction-type`   | ✅           |
| `approve-deduction-request` | ✅           |
| `issue-tax-refund`          | ✅           |
| `submit-deduction-request`  | ❌ (User)    |

---

## ⚠️ Error Codes

| Code                            | Description                    |
| ------------------------------- | ------------------------------ |
| `u100` ERR-NOT-AUTHORIZED       | Unauthorized caller            |
| `u101` ERR-INVALID-AMOUNT       | Deduction/refund out of bounds |
| `u102` ERR-TAX-RATE-NOT-FOUND   | Bracket info not found         |
| `u103` ERR-INSUFFICIENT-BALANCE | Not enough STX for transfer    |
| `u104` ERR-INVALID-TAX-RATE     | Tax rate exceeds 100%          |
| `u105` ERR-INVALID-CURRENCY     | Currency not in registry       |
| `u106` ERR-INVALID-DEDUCTION    | Deduction doesn't exist/index  |
| `u107` ERR-REFUND-NOT-ALLOWED   | Refund exceeds taxes paid      |
| `u108` ERR-INVALID-PERIOD       | Invalid report/tax year        |
| `u109` ERR-TRANSFER-FAILED      | STX transfer failed            |

---

## 🔍 Example Use Cases

1. **Progressive Income Tax**
   Authorities define multiple brackets with increasing tax rates.

2. **Cross-Border Tax Collection**
   Supports conversion from foreign currencies into STX-equivalent taxes.

3. **Grant/DAO Deductions**
   Contributors may apply deductions for project expenses, subject to admin approval.

4. **Automated Refunds**
   If tax is overpaid, administrators can process refunds in STX.

5. **Annual Tax Reporting**
   Taxpayers can retrieve complete history and net tax status for audits or filings.

---

## 🔐 Security Considerations

* **Authorization Checks** are enforced for admin-sensitive operations.
* **Error Handling** ensures consistent and predictable results.
* **Data Limits** like list lengths protect against state bloat.
* **Conversion Accuracy** relies on admin-updated exchange rates.

---
