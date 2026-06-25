# CONSTITUTION.md

## Purpose

This document defines the **non-negotiable principles** that govern all development decisions for Life OS. Every pull request, feature, and architectural decision must align with these principles.

---

## 1. Code Quality Over Speed

- Code must be readable, maintainable, and well-documented
- No hacks, no shortcuts, no "fix it later" mentality
- Every file should be understandable by a new contributor within 10 minutes
- Strict linting is enforced — no warnings allowed in production code

---

## 2. Feature-First Architecture

- Code is organized by feature, not by type
- Each feature is self-contained with its own data, domain, and presentation layers
- Cross-feature dependencies must be explicit and minimal
- Shared code lives in `core/` or `shared/`

---

## 3. Offline First

- Every feature must work without internet
- Local database is the primary data source for reads
- Cloud sync is a background process, not a requirement
- Users should never see a "No internet connection" error for core functionality

---

## 4. Privacy by Default

- No third-party analytics without explicit opt-in
- No data leaves the device without user knowledge
- Sensitive data is encrypted at rest
- Users own their data — export must always be possible

---

## 5. Dependency Discipline

- Dependencies must be justified — no "nice to have" packages
- Prefer well-maintained packages with active communities
- Pin versions — no caret (`^`) without consideration
- Review dependency licenses for compatibility

---

## 6. Testing Culture

- Business logic must be unit tested
- Repositories must have integration tests
- Critical user flows must have widget tests
- Tests are not optional — they are part of the definition of done

---

## 7. Documentation Standards

- Every public API must be documented with `///` comments
- Architecture decisions must be recorded in `ARCHITECTURE.md`
- README must always reflect the current state of the project
- No placeholder documentation — write meaningful content or don't write it

---

## 8. Git Hygiene

- Conventional Commits only (`feat:`, `fix:`, `docs:`, etc.)
- One logical change per commit
- Commit messages explain "why", not just "what"
- No giant commits — break work into logical chunks

---

## 9. Design Consistency

- All UI must follow the design system
- No one-off styles or hardcoded values
- Design tokens are the single source of truth
- New components must be added to the design system, not created ad-hoc

---

## 10. Long-Term Thinking

- Optimize for the next 100 prompts, not the current one
- Every decision should consider: "Will this still make sense in 2 years?"
- Avoid coupling to specific services or platforms
- Build abstractions that survive implementation changes

---

## Amendment Process

This constitution can be amended through:

1. Proposal in a GitHub issue with rationale
2. Discussion period (minimum 1 week)
3. Approval by project maintainers
4. Update this document with the amendment date

---

*Last amended: June 2025 — Original ratification.*