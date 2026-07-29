## 0.3.0

- Send the `X-Vox-Client` header on token requests so the SDK layers a build
  loads are declared at the transport layer instead of per call.
- Add the shared `X-Vox-Client` conformance vectors, run against the same JSON
  the JavaScript, React Native, Python, and CLI SDKs use.
- No request body change. `source_type`, `version`, and
  `metadata.runtime_context.source` are unchanged.

## 0.2.1

- Replace direct Customer UUID inputs with the single `visitorId` session option.
- Send `visitorId` as `visitor_id` so repeat app sessions reuse the same Customer.
- Add request-contract tests for Customer attribution.

## 0.1.0

- Initial `vox.ai` Flutter SDK release.
