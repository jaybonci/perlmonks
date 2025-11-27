# PerlMonks + Everything2 Ecosystem Unification Plan

**Note:** All plans in this document are subject to ratification from PerlMonks site leadership.

## Executive Summary

This document outlines the plan to unify PerlMonks with the Everything2 codebase, creating a shared engine that can power both sites while respecting their distinct communities and content. The goal is to bring PerlMonks onto the same modernization path as E2, enabling shared development effort and consistent architecture.

**Key Constraint:** We will not modify the E2 codebase to support PerlMonks at this stage. Instead, PerlMonks will adopt E2's patterns and eventually both will share the same core libraries.

**Infrastructure Target:** Traditional LAMP stack (Linux, Apache, MySQL, Perl) - no AWS dependencies.

**Note on Database:** PerlMonks production runs on MySQL. The SQLite database in `db/perlmonks.sqlite` is a sanitized, converted MySQL dump provided for development environment bootstrapping. The schema is MySQL-compatible and **node_ids are preserved** - critical for the many hardcoded node references in the codebase.

**Development Ports:** Since E2 and PerlMonks development may run on the same machine, PerlMonks uses different ports:
- HTTP: **9180** (E2 uses 9080)
- HTTPS: **9543** (E2 uses 9443)
- MySQL: **9406** (E2 uses 9306)

---

## Part 1: Analysis Summary

### 1.1 Database Comparison

| Aspect | PerlMonks (Production) | Everything2 (Target) |
|--------|------------------------|----------------------|
| Database | MySQL | MySQL 8.0 |
| Reference Dump | SQLite 3.x (1.5GB, sanitized) | N/A |
| Tables | 88 tables | ~40+ tables (nodepack-defined) |
| Nodes | 1,294,203 | Variable |
| Users | 97,309 | Variable |
| Documents | 1,277,451 | Variable |
| Node Types | 112 | 38+ |
| Character Set | UTF-8 | utf8mb4 |

**Schema Compatibility:** Both use the same fundamental node-based architecture with nearly identical table structures:
- `node` - Core polymorphic content table
- `nodetype` - Type definitions with inheritance
- `nodegroup` - Hierarchical relationships
- `user` - User accounts with karma/experience
- `document` - Content text storage
- `htmlpage`, `htmlcode` - Rendering templates

**Key Differences:**
1. Both use MySQL in production (reference SQLite dump provided for dev bootstrapping)
2. PerlMonks has additional tables: `approval`, `polls`, `pollvote`, `traffic_stats`, `tomb`, `considernodes`
3. E2 has migrated database-stored code to filesystem (`Everything::Delegation::*`)
4. E2 uses Moose-based OOP; PerlMonks is procedural

### 1.2 Code Comparison

| Component | PerlMonks | Everything2 |
|-----------|-----------|-------------|
| Everything.pm | 1,054 lines, procedural | Moose-based with singletons ($APP, $DB, $FACTORY, $MASON) |
| NodeBase.pm | 2,498 lines, procedural | 2,849 lines, being refactored to Moose |
| NodeCache.pm | 519 lines | Similar with session cache |
| HTML.pm | 2,112 lines | Delegated to Mason2 + React |
| API Layer | None | 23 REST API modules |
| Configuration | Everything::Password | Everything::Configuration (JSON-based) |

**Shared Heritage:** Both derive from the original Everything engine (1999). The core node operations (`getNode`, `insertNode`, `updateNode`, `nukeNode`) are functionally identical.

---

## Part 2: Phased Implementation Plan

### Phase 1: Docker Development Environment ✓ COMPLETE

**Goal:** Create a working local development environment for PerlMonks using Docker, mirroring E2's structure.

- Docker containers (pmdevapp, pmdevdb) - **DONE**
- SQLite to MySQL import tooling - **DONE**
- Basic CGI request handling - **DONE**
- Front page renders correctly - **DONE**

### Phase 2: Code Delegation

**Goal:** Migrate database-stored code (htmlcode, htmlpage) to filesystem using E2's delegation pattern.

E2 uses `Everything::Delegation::*` modules to replace database-stored code. The key pattern is in `../everything2/ecore/Delegation/htmlcode.pm` where **each function name gets its own subroutine**.

#### 2.1 Delegation Pattern Benefits

1. **Performance** - Filesystem reads are faster than database queries for code
2. **Security** - Code is no longer executable from database; reduces attack surface
3. **Version Control** - Code changes are tracked in git
4. **Testing** - Individual functions can be unit tested

#### 2.2 Delegation Challenges

1. **Symbol Mapping** - Delegated functions need to be mapped back to `Everything::HTML` or `Everything::NodeBase` namespaces for compatibility
2. **mod_perl Variable Reuse** - Under mod_perl, variables persist between requests. Each variable must be reinitialized on declaration to avoid data leakage between requests
3. **Gradual Migration** - Must support both database and filesystem code during transition

#### 2.3 Example Delegation Structure

```perl
# ecore/Everything/Delegation/htmlcode.pm
package Everything::Delegation::htmlcode;

# Each htmlcode node becomes its own subroutine
sub displayNodeInfo {
    my ($NODE, $query, $USER, $VARS) = @_;
    # IMPORTANT: Reinitialize all variables to avoid mod_perl reuse issues
    my $result = '';  # Don't rely on previous value
    # ... code previously stored in database ...
    return $result;
}

sub formatTimestamp {
    my ($NODE, $query, $USER, $VARS) = @_;
    my $output = '';  # Fresh initialization
    # ...
}
```

### Phase 3: Development Database Setup

The development database is established by a slightly refactored ecoretool that enables bootstrapping a database from on-disk files. This contains enough database structure to launch the site and test features.

#### 3.1 Bootstrap Tool (pmcoretool)

Create `pmcoretool/pmcoretool.pl` - based on E2's ecoretool but using JSON nodepack format:

```bash
# Bootstrap from nodepack
pmcoretool bootstrap --nodepack=./nodepack

# 1. Create tables from dbtable/*.json
# 2. Insert nodetypes (direct INSERT, no Everything.pm)
# 3. Initialize Everything.pm
# 4. Insert system nodes (settings, usergroups, etc.)
```

#### 3.2 Nodepack Format (JSON)

```json
// nodepack/nodetype/nodetype.json
{
  "node_id": 1,
  "title": "nodetype",
  "type_nodetype": 1,
  "sqltable": "nodetype",
  "restrictdupes": 1
}
```

### Phase 4: Testing Infrastructure

**Goal:** Establish automated testing to catch regressions and ensure code quality.

#### 4.1 Perl::Critic for Bug Detection

The primary testing tool is **Perl::Critic** configured for bugs-level warnings:

```bash
perlcritic --severity 4 --theme bugs ecore/
```

This catches common issues like:
- Undefined variables
- Unreachable code
- Mismatched subroutine signatures
- Potential security issues

#### 4.2 Test Structure

```
t/
├── 001-database.t      # Database connectivity
├── 002-node-basic.t    # Basic node operations
├── 003-nodetype.t      # Nodetype inheritance
├── 004-critic.t        # Perl::Critic checks
└── run.pl              # Test runner
```

### Phase 5: Server Error Cleanup

**Goal:** Reduce server warnings to enable use of modern Perl libraries.

#### 5.1 Common Warning Sources

The codebase generates many warnings that need to be addressed:

1. **CGI param() in list context** - Modern CGI.pm warns when `param()` is called in list context. The legacy code does this frequently:
   ```perl
   # Generates warning in modern CGI
   my @values = $query->param('field');

   # Should be
   my @values = $query->multi_param('field');
   ```

2. **Uninitialized values** - Many variables are used without initialization
3. **Deprecated syntax** - Various Perl 4-isms that generate warnings

#### 5.2 Benefits of Cleanup

- Enables use of modern CPAN libraries without warning floods
- Makes real errors visible in logs
- Prepares codebase for `use warnings FATAL => 'all'`
- Improves security by catching potential issues

### Phase 6: Application Logic Centralization

**Goal:** Refactor scattered htmlcode logic into centralized application libraries.

#### 6.1 Everything::Application Pattern

Following E2's `Everything::Application` pattern, centralize business logic that's currently duplicated across htmlcodes:

```perl
package Everything::Application::Voting;

sub cast_vote {
    my ($user, $node, $vote) = @_;
    # Centralized voting logic
}

sub get_user_votes_today {
    my ($user) = @_;
    # ...
}
```

#### 6.2 Benefits

1. **Separation of Concerns** - Business logic separate from presentation
2. **Testability** - Application logic can be unit tested in isolation
3. **Reusability** - Functions can be called from multiple htmlcodes
4. **Stepping Stone** - Prepares for eventual API layer or decoupled frontend

---

## Part 3: Path to Modernization

These changes start PerlMonks down the path of modernization and enable site ownership to make decisions about where to take the site in the future. Key outcomes:

1. **Working Docker development environment** - Developers can run PerlMonks locally
2. **Code in version control** - htmlcode/htmlpage migrated to filesystem
3. **Improved performance and security** - Through delegation pattern
4. **Cleaner codebase** - Fewer warnings, Perl::Critic compliant
5. **Testable architecture** - Centralized application logic
6. **Foundation for future work** - Site leadership can decide next steps

---

## Appendix A: E2 File Reference

Key E2 files to reference during implementation:

| E2 File | Purpose | PerlMonks Equivalent |
|---------|---------|----------------------|
| `ecore/Delegation/htmlcode.pm` | Delegated htmlcode functions | `ecore/Everything/Delegation/htmlcode.pm` |
| `ecore/Everything/Application.pm` | Centralized app logic | `ecore/Everything/Application.pm` |
| `docker/devbuild.sh` | Build orchestration | `docker/devbuild.sh` |
| `ecoretool/ecoretool.pl` | Bootstrap tool | `pmcoretool/pmcoretool.pl` |
| `nodepack/` | Node definitions | `nodepack/` (JSON format) |

---

## Appendix B: mod_perl Variable Reuse

Under mod_perl, Perl code is compiled once and executed repeatedly. This means:

```perl
# DANGEROUS under mod_perl - $count persists between requests
my $count;
$count++;  # Will increment across requests!

# SAFE - always initialize
my $count = 0;
$count++;

# DANGEROUS - hash may contain stale data
my %cache;

# SAFE - clear on each request
my %cache = ();
```

All delegated htmlcode functions must initialize variables explicitly to avoid data leakage between requests.

---

## Appendix C: Current Status

**Completed:**
- Docker development environment
- SQLite to MySQL import
- Basic page rendering
- Static asset serving (CSS, JS, images)

**In Progress:**
- Code delegation planning
- Warning cleanup identification

**Future (Pending Site Leadership Approval):**
- Delegation implementation
- pmcoretool development
- Application logic centralization
