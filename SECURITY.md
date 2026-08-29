# Security

Report vulnerabilities privately to the repository owner before public disclosure.

YMM4M bridge connections bind only to `127.0.0.1`, require a random per-session token, enforce a protocol version, validate message lengths, and reject output paths not explicitly selected by the user. Diagnostic bundles redact usernames, home-directory prefixes, authorization headers, and common secret fields.

Do not disable SIP or Gatekeeper to run YMM4M. A backend requiring either is unsupported.

