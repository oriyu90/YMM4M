# Contributing

Start with `AGENTS.md`. Keep evidence separate from claims: a feature remains `untested` until its referenced test has reproducible evidence. Never add proprietary binaries to fixtures. Use synthetic media and protocol fixtures.

Before submitting a change, run `swift build`, `swift run YMM4MContractTests`, and the Python unit tests. Compatibility fixes must state the affected YMM4 and runtime versions, include a reproducer, and define their removal condition.
