# ADR-001: Supabase as Backend

## Status

Accepted

## Date

2025-06-25

## Context

Life OS requires a backend for:

- User authentication (email/password, Google OAuth)
- Cloud data synchronization across devices
- Real-time updates for collaborative features (future)
- File storage for media attachments (future)
- Row-level security for multi-tenant data isolation

We evaluated several backend options against the project's requirements: offline-first architecture, open-source alignment, developer experience, and long-term cost.

## Decision

**Supabase** has been selected as the backend for Life OS.

## Alternatives Considered

### Firebase

- **Pros**: Mature ecosystem, generous free tier, real-time database, authentication, cloud functions
- **Cons**: Vendor lock-in, proprietary, NoSQL-only (Firestore) limits relational queries, complex security rules, Google dependency
- **Rejected because**: Life OS requires relational data (habits linked to entries, goals linked to metrics). Firebase's NoSQL model would require significant denormalization and increase complexity. Additionally, the project's open-source ethos favors open-source backends.

### Appwrite

- **Pros**: Open-source, self-hostable, REST/GraphQL APIs, authentication, database, storage
- **Cons**: Smaller community, less mature Flutter SDK, fewer real-time capabilities, self-hosting overhead
- **Rejected because**: While Appwrite aligns with open-source values, Supabase's PostgreSQL foundation, mature Flutter SDK, and managed hosting provide a better developer experience for a small team.

### Custom Backend (Dart Frog / Serverpod)

- **Pros**: Full control, no vendor dependency, Dart-native
- **Cons**: Massive development overhead, maintenance burden, security responsibility, scaling complexity
- **Rejected because**: Building and maintaining a custom backend would divert resources from the core product. The team size does not justify this investment at this stage.

### Supabase (Selected)

- **Pros**: Open-source, PostgreSQL (relational), real-time subscriptions, row-level security, mature Flutter SDK, generous free tier, managed hosting available, supports self-hosting
- **Cons**: Younger ecosystem than Firebase, some features still in beta, real-time has scaling limits on free tier
- **Selected because**: Supabase provides the best balance of open-source values, relational data support, Flutter integration, and managed infrastructure. PostgreSQL with Row-Level Security gives us fine-grained data isolation without application-level complexity.

## Consequences

### Positive

- Relational data model enables complex queries (e.g., "show me habits completed on days with high mood scores")
- Row-Level Security ensures data isolation at the database level
- Real-time subscriptions enable live sync across devices
- Open-source alignment with project values
- Managed hosting eliminates infrastructure overhead

### Negative

- Younger ecosystem means fewer community resources and third-party tools
- Some advanced features (e.g., edge functions) are less mature than Firebase equivalents
- Real-time subscriptions have connection limits on the free tier
- Vendor dependency still exists (mitigated by open-source nature and self-hosting option)

### Neutral

- Team must learn Supabase-specific patterns (e.g., PostgREST query syntax)
- Migration path exists to self-hosted Supabase if needed

## References

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase Flutter SDK](https://pub.dev/packages/supabase_flutter)
- [Row-Level Security Guide](https://supabase.com/docs/guides/auth/row-level-security)