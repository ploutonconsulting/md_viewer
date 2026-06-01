# Sage Accounting South Africa MCP Handover for Claude Code

## Objective

Build a Python MCP server that connects to Sage Accounting South Africa (`https://accounting.sageone.co.za`) and exposes safe, useful tools for Claude Code to access company financial data programmatically.[cite:1][cite:2]

The first production target is a **read-only MCP** focused on financial reporting, ledger extraction, counterparty lookups, and bank transaction retrieval, even though the Sage API supports create, update, and delete operations on many entities.[cite:1][cite:2]

## Product context

The target accounting product is the South African Sage Accounting / Sage Business Cloud Accounting tenant hosted at `accounting.sageone.co.za`, and Sage publishes a dedicated South Africa developer page for this API.[cite:1][cite:2]

Sage documents the base API URL as `https://accounting.sageone.co.za`, the current version as `2.00`, JSON as the supported format, and the route pattern as `/api/[ver]/[service]/[method]`.[cite:1][cite:2]

The published specification is available at the reseller-hosted API documentation endpoint `https://resellers.accounting.sageone.co.za/api/2.0.0`.[cite:2]

## Authentication model

The South Africa API documentation describes authentication using HTTP Basic authentication with the Sage username and password in the `Authorization` header, while the API key is passed as a query parameter.[cite:2]

Company-scoped calls also require a `CompanyId` parameter for data isolation and tenancy selection.[cite:1][cite:2]

This differs from a modern OAuth-style delegated flow and has important consequences for MCP design: credentials must remain entirely server-side, never be surfaced to the model, never be echoed back in tool results, and never be written to logs.[cite:2]

## Constraints and limits

Sage states that the platform allows 5,000 API requests per day per company and documents list-method limits of 100 results per minute, with HTTP 429 used when request thresholds are exceeded.[cite:1][cite:2]

The MCP must therefore include conservative paging, local throttling, bounded result sizes, request deduplication where practical, and strongly opinionated tool contracts that prevent broad or repeated full-dataset scraping.[cite:1][cite:2]

## API surface confirmed from the published spec

Sage states the South Africa API exposes over 100 services.[cite:1]

The published specification includes entities and services such as the following.[cite:2]

| Domain | Examples observed in spec |
|---|---|
| Company and setup | `Company`, `Account`, `TaxType`, `CostCode`, `AnalysisType`, `AnalysisCategory` [cite:2] |
| Customers and receivables | `Customer`, `CustomerCategory`, `CustomerAgeing`, `CustomerStatement`, `TaxInvoice`, `Quote`, `SalesOrder`, `Receipt` [cite:2] |
| Suppliers and payables | `Supplier`, `SupplierCategory`, `SupplierAgeing`, `SupplierInvoice`, `SupplierReturn`, `SupplierStatement`, `PurchaseOrder` [cite:2] |
| Banking and cash | `BankAccount`, `BankTransaction`, `BankTransfer`, `CashBookTransaction`, `BankRecon` [cite:2] |
| General ledger | `JournalEntry`, `DetailedLedgerTransaction`, `TrialBalance`, `BalanceSheet`, `ProfitAndLoss`, `Budget` [cite:2] |
| Inventory and items | `Item`, `ItemCategory`, `Warehouse`, `WarehouseTransfer`, `WarehouseAdjustment` [cite:2] |

The spec confirms that this API is rich enough to support an MCP centered on finance questions such as receivables exposure, supplier balances, bank activity, account movement, and period financial statements.[cite:2]

## Recommended MCP scope for v1

The v1 server should be intentionally narrow and read-only.[cite:2]

Recommended v1 tool surface:

- `sage_list_companies`: discover available companies and select the correct tenant context.[cite:2]
- `sage_get_company`: fetch company profile and base configuration values.[cite:2]
- `sage_get_customers`: fetch customers with optional pagination and filters.[cite:2]
- `sage_get_suppliers`: fetch suppliers with optional pagination and filters.[cite:2]
- `sage_get_bank_accounts`: fetch available bank accounts.[cite:2]
- `sage_get_bank_transactions`: fetch bank transactions for an account, date range, and page window.[cite:2]
- `sage_get_detailed_ledger`: fetch detailed ledger lines for an account/date range or filter set.[cite:2]
- `sage_get_trial_balance`: retrieve trial balance for a given period.[cite:2]
- `sage_get_balance_sheet`: retrieve statement of financial position for a given period.[cite:2]
- `sage_get_profit_and_loss`: retrieve income statement / profit and loss for a given period.[cite:2]
- `sage_get_customer_ageing`: retrieve receivables ageing summary/detail depending on available method shape.[cite:2]
- `sage_get_supplier_ageing`: retrieve payables ageing summary/detail depending on available method shape.[cite:2]

The v1 server should explicitly omit save/delete methods, inventory movement posting, invoicing mutations, journal posting, and payment creation, even if technically available in the API.[cite:2]

## Recommended Python stack

Use Python with a clean separation between transport, authentication, schema validation, throttling, and MCP tool handlers.[cite:2]

Suggested stack:

- `httpx` for HTTP transport, timeout control, connection pooling, and retry integration.
- `pydantic` for configuration, request models, response normalization, and structured validation.
- MCP Python SDK for server/tool exposure.
- `tenacity` or a small internal retry policy for transient errors and HTTP 429 handling.
- `python-dateutil` only if date parsing flexibility is needed; otherwise prefer strict ISO date parsing.
- Structured logging with standard library `logging`, but with redaction filters that remove credentials, API keys, and authorization headers from all logs.[cite:2]

No database is required for a first local/server-side version unless response caching, audit trails, or multi-company metadata persistence become necessary.[cite:1][cite:2]

## Reference architecture

```text
mcp_server/
  __init__.py
  main.py                 # MCP server bootstrap
  config.py               # env/settings loading
  auth.py                 # Basic auth header construction
  transport.py            # httpx client, retries, backoff, throttling
  errors.py               # typed exceptions and normalization
  models/
    common.py
    company.py
    customer.py
    supplier.py
    bank.py
    ledger.py
    reports.py
  sage_client/
    base.py               # generic request helpers
    company.py
    customers.py
    suppliers.py
    bank.py
    ledger.py
    reports.py
  tools/
    companies.py
    counterparties.py
    bank.py
    ledger.py
    reports.py
  formatters/
    tabular.py            # safe compact result formatting for model consumption
  tests/
    test_auth.py
    test_transport.py
    test_tools.py
    fixtures/
```

The key design rule is that only the transport/client layer knows how Sage URLs, auth headers, and query strings are built; MCP tool handlers should operate on typed service methods and return compact structured JSON to the model.[cite:2]

## Configuration contract

Use environment variables only, loaded at process start.

```text
SAGE_BASE_URL=https://accounting.sageone.co.za
SAGE_API_VERSION=2.00
SAGE_USERNAME=<sage_username>
SAGE_PASSWORD=<sage_password>
SAGE_API_KEY=<api_key>
SAGE_COMPANY_ID=<default_company_id>
SAGE_TIMEOUT_SECONDS=30
SAGE_MAX_RETRIES=3
SAGE_RATE_LIMIT_PER_MINUTE=60
SAGE_USER_AGENT=claude-code-sage-mcp/0.1.0
MCP_READ_ONLY=true
```

The effective defaults should always resolve to the South Africa host and version described in Sage’s documentation unless explicitly overridden for testing or future regional reuse.[cite:1][cite:2]

## HTTP request construction

All requests should target the documented route pattern `/api/{version}/{service}/{method}` with the API key passed in the query string and Basic auth in the header.[cite:2]

Example canonical request shape:

```text
GET https://accounting.sageone.co.za/api/2.00/Customer/Get/1?apikey=...&CompanyId=1
Authorization: Basic <base64(username:password)>
Accept: application/json
```

The exact path segments after `Get` vary by service and method shape in the spec, so the implementation should avoid hard-coding assumptions globally and instead define each endpoint in a service-specific client with typed parameters and fixtures derived from the published documentation.[cite:2]

## Error handling contract

Normalize Sage and transport failures into a small internal exception family:

- `SageAuthenticationError`
- `SageAuthorizationError`
- `SageRateLimitError`
- `SageNotFoundError`
- `SageValidationError`
- `SageUpstreamError`
- `SageTransportError`

HTTP status mapping should treat 401/403 as auth/authorization failures, 404 as missing resource or wrong method shape, 429 as retriable rate limiting, and 5xx as transient upstream failures suitable for bounded retry.[cite:1][cite:2]

All tool-facing errors returned to Claude should be short, deterministic, and non-sensitive. Never include credentials, raw headers, or full upstream URLs containing query-string API keys.[cite:2]

## Throttling and retries

Because Sage documents daily and per-minute ceilings, the client should implement both passive and active protection.[cite:1][cite:2]

Required controls:

- A token-bucket or leaky-bucket limiter for per-minute request smoothing.
- Exponential backoff with jitter for 429 and selected 5xx responses.
- A hard ceiling on pages fetched per MCP call.
- Optional in-memory memoization for repeated reads during a single Claude session.
- Sensible default page sizes to avoid exhausting the 100-results-per-minute list cap.[cite:1][cite:2]

## Tool design rules for Claude Code

Every tool should be bounded, typed, and boring.

Required rules:

- Read-only only for v1.
- Require explicit date ranges for transaction and ledger extraction tools.
- Cap the maximum date window for heavy endpoints unless an override is explicitly allowed.
- Cap page size and total pages.
- Return summarized metadata alongside records, for example `count`, `page`, `has_more`, `filters_applied`, and `company_id`.
- Prefer IDs and compact names over large nested payloads.
- Normalize dates to ISO 8601 strings.
- Normalize monetary fields to decimals serialized as strings when precision matters.
- Include raw upstream payload passthrough only behind a debug flag that defaults to false and is not exposed as a normal model tool option.

## Proposed MCP tool contracts

### `sage_list_companies`

Purpose: enumerate accessible companies for the configured credentials.[cite:2]

Input:

```json
{}
```

Output shape:

```json
{
  "companies": [
    {
      "id": 1,
      "name": "Example Pty Ltd",
      "currency": "ZAR",
      "country": "ZA",
      "is_default": true
    }
  ],
  "default_company_id": 1
}
```

### `sage_get_bank_transactions`

Purpose: return bounded bank transactions for one account and one date range.[cite:2]

Input:

```json
{
  "company_id": 1,
  "bank_account_id": 12,
  "from_date": "2026-01-01",
  "to_date": "2026-01-31",
  "page": 1,
  "page_size": 50
}
```

Output shape:

```json
{
  "company_id": 1,
  "bank_account_id": 12,
  "from_date": "2026-01-01",
  "to_date": "2026-01-31",
  "page": 1,
  "page_size": 50,
  "count": 37,
  "has_more": false,
  "transactions": [
    {
      "id": 12345,
      "date": "2026-01-03",
      "amount": "1500.00",
      "reference": "DEP-001",
      "description": "Deposit",
      "contact_name": "Customer A",
      "tax_amount": "0.00"
    }
  ]
}
```

### `sage_get_profit_and_loss`

Purpose: return a period P&L in a compact, model-consumable structure.[cite:2]

Input:

```json
{
  "company_id": 1,
  "from_date": "2026-01-01",
  "to_date": "2026-03-31",
  "include_zero_balances": false
}
```

Output shape:

```json
{
  "company_id": 1,
  "from_date": "2026-01-01",
  "to_date": "2026-03-31",
  "currency": "ZAR",
  "sections": [
    {
      "name": "Revenue",
      "lines": [
        {"account_code": "4000", "account_name": "Sales", "amount": "100000.00"}
      ],
      "subtotal": "100000.00"
    }
  ],
  "net_profit": "25000.00"
}
```

### `sage_get_detailed_ledger`

Purpose: return detailed account movement while forcing a narrow query envelope.[cite:2]

Input:

```json
{
  "company_id": 1,
  "from_date": "2026-01-01",
  "to_date": "2026-01-31",
  "account_id": 200,
  "page": 1,
  "page_size": 100
}
```

Output shape:

```json
{
  "company_id": 1,
  "account_id": 200,
  "from_date": "2026-01-01",
  "to_date": "2026-01-31",
  "count": 88,
  "has_more": false,
  "entries": [
    {
      "date": "2026-01-05",
      "reference": "INV-1001",
      "description": "Tax invoice",
      "debit": "0.00",
      "credit": "2500.00",
      "running_balance": "2500.00"
    }
  ]
}
```

## Data modeling guidance

Pydantic models should distinguish among:

- Config models: environment/settings.
- Request models: tool inputs with validation and bounds.
- Domain response models: normalized business objects.
- Transport models: optional thin wrappers around raw Sage payload shapes if the API is irregular.[cite:2]

Preferred normalization strategy:

- Convert field names to Pythonic snake_case internally.
- Preserve original upstream keys only in optional debug metadata.
- Parse dates into `date` objects internally and serialize as ISO strings at tool boundaries.
- Use `Decimal` internally for all monetary values.
- Avoid leaking null-heavy upstream schemas directly to MCP responses; produce compact schemas optimized for model use.

## Security requirements

Non-negotiable requirements:

- Keep Sage username, password, and API key in environment variables or a secret manager only.
- Never print authorization headers.
- Never print full URLs after query construction because the API key is embedded in the query string.[cite:2]
- Add logging redaction filters for `apikey`, `Authorization`, `username`, and `password` patterns.
- Add a startup validation check that refuses to enable write-capable tools while `MCP_READ_ONLY=true`.
- Ensure exception strings are sanitized.
- Prefer localhost/private network deployment for early usage because this auth model is credential-sensitive.[cite:2]

## Testing strategy

Create tests at three layers.

### Unit tests

- Basic auth header construction.
- Query parameter assembly with `apikey` and `CompanyId`.
- Request model validation and bounds checking.
- Error mapping from HTTP responses.
- Redaction filters.

### Integration tests with mocked transport

Use `respx` or equivalent to mock Sage endpoints and verify:

- Correct method/path construction.
- Retry behavior for 429 and 5xx.
- Pagination caps.
- Normalization of typical Sage payloads into MCP result schemas.

### Optional live smoke tests

Only run when credentials are supplied explicitly in a secure local environment.

Smoke tests should validate:

- Company listing.
- One low-volume master-data call.
- One narrow report call.
- One narrow transaction query over a small date range.

No smoke test should execute create/update/delete actions in v1.[cite:2]

## Implementation sequence

1. Build configuration loading and startup validation.
2. Build auth header generation and redacted logging.
3. Build transport client with timeout, retries, and rate limiting.
4. Implement `list_companies` and `get_company` first to validate credentials and tenant selection.[cite:2]
5. Implement one simple entity reader, for example `customers` or `suppliers`.[cite:2]
6. Implement one transaction endpoint, preferably bank transactions with explicit date windows.[cite:2]
7. Implement core report endpoints: trial balance, balance sheet, and profit and loss.[cite:2]
8. Wrap service methods as MCP tools with strict Pydantic input schemas.
9. Add tests and a local smoke-test harness.
10. Add optional session-scoped caching only after correctness is proven.

## Operational recommendations

Use a single shared `httpx.Client` or `AsyncClient` instance for connection reuse and consistent headers.

Set aggressive but realistic timeouts, for example connect timeout 5 seconds and total timeout around 30 seconds, because Claude-facing tools should fail fast and clearly rather than hanging indefinitely.

Record lightweight metrics in logs such as endpoint name, status code family, latency bucket, retry count, and row count returned, but never sensitive payload content.[cite:2]

## Open questions Claude Code should resolve during implementation

The public spec is extensive but may contain endpoint-specific quirks, so verify these items against live docs or test responses during coding.[cite:2]

- Exact method signatures and path parameter conventions for each chosen report endpoint.
- Whether some report methods require `POST` with JSON bodies versus `GET` with query parameters.
- Native pagination model for each list endpoint.
- Whether filtering capabilities differ materially between customers, suppliers, bank transactions, and ledger endpoints.
- Whether there are stable unique identifiers and timestamps needed for incremental sync patterns later.
- Whether the company list endpoint returns all companies accessible to the user credentials in the same tenancy shape expected by v1 tooling.

## Non-goals for v1

The following are out of scope for the first production handoff even if the API supports them.[cite:2]

- Posting journals.
- Creating or editing invoices, receipts, orders, or supplier bills.
- Deleting records.
- Inventory movement workflows.
- Attachments or document upload handling.
- Cross-system sync engines.
- Natural-language autonomous writeback.

## Definition of done

The MCP is ready for first real use when all of the following are true.

- It authenticates successfully to `accounting.sageone.co.za` using the documented South Africa auth model.[cite:1][cite:2]
- It can list companies and operate against a configured default `CompanyId`.[cite:2]
- It exposes at least five stable read-only tools covering company info, counterparties, bank transactions, ledger detail, and financial statements.[cite:2]
- It enforces request bounds, rate limiting, and sanitized error handling consistent with Sage’s documented limits.[cite:1][cite:2]
- It never emits credentials or API keys to logs or tool output.[cite:2]
- It has automated tests for transport, validation, and tool contracts.

## Suggested next-phase enhancements

After v1 is stable, possible v2 enhancements include session-scoped caching, multi-company routing, report result shaping for analytics workloads, incremental extraction helpers, and a gated write-capable admin mode with explicit human approval boundaries.[cite:1][cite:2]

Until then, the correct design posture is conservative: small trusted toolset, read-only access, narrow date ranges, explicit company scoping, and strong protection around the Basic-auth-plus-API-key credential model documented for South Africa.[cite:1][cite:2]
