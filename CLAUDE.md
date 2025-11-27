# PerlMonks Development - Claude Context

This file provides context for Claude Code sessions working on the PerlMonks unification project.

## Project Overview

PerlMonks and Everything2 share a common heritage - both were built on the "Everything Engine" around 1999. The goal is to unify these codebases, creating a shared engine that both sites can use while maintaining their distinct identities.

## Current Phase

The basic development environment is working:
- Docker development environment for PerlMonks (complete)
- SQLite to MySQL data import tooling (complete)
- Basic CGI request handling (complete - mod_perl has DynaLoader issues on Ubuntu 24.04)
- Application renders "The Monastery Gates" front page
- No modifications to E2 codebase yet

## Key Technical Decisions

### Architecture

- **Traditional LAMP stack**: MySQL + Apache + mod_perl (no AWS dependencies)
- **Directory structure**: Uses `/var/everything` (same as E2)
- **No Mason**: PerlMonks does NOT use Mason templates (unlike E2)
- **No Carton**: Dependencies managed iteratively via cpanfile
- **Parallel development**: Different ports (9180/9543/9406) to run alongside E2

### Database

- **SQLite dump**: The provided SQLite database is a converted MySQL dump with preserved node_ids
- **Schema**: 88 tables, ~1.3M nodes, ~97K users, 112 nodetypes
- **Hardcoded mapping**: `NodeBase.pm` maps 'perlmonks' → 'perlmonk_ebase' (production database name)
- **Password storage**: Plaintext in `user.passwd` field
- **Authentication**: Uses `crypt()` for cookie-based login

### Missing/Modified Modules

- **Everything::Password**: Created as a shim module that reads credentials from JSON config or environment variables. The original was likely a simple production secret holder.

### Hardcoded Paths to Clean Up

Found in ecore libraries:
- `perlmonks.org` URLs throughout code
- `/usr/tmp/everything.errlog` error log path
- Database name 'perlmonk_ebase' in NodeBase.pm

## File Structure

```
perlmonks/
├── CLAUDE.md              # This file
├── UNIFICATION_PLAN.md    # Comprehensive planning document
├── cpanfile               # Perl dependencies
├── db/
│   └── perlmonks.sqlite   # Reference database (~1.5GB)
├── docker/
│   ├── devbuild.sh        # Main build script
│   ├── devclean.sh        # Cleanup script
│   ├── pmapp/             # Application container
│   │   ├── Dockerfile
│   │   └── apache2_wrapper.sh
│   └── pmdb/              # Database container
│       ├── Dockerfile
│       └── mysqld_wrapper.sh
├── ecore/                 # PerlMonks ecore libraries
│   └── Everything/
│       ├── Password.pm    # Created shim for DB credentials
│       └── ...            # Provided libraries
├── etc/
│   └── development.json   # Configuration file
├── tools/
│   ├── sqlite_to_mysql.pl # SQLite import tool
│   └── seeds.pl           # Development password seeder
└── www/
    └── index.pl           # Entry point (mod_perl)
```

## Development Login

After running `docker/devbuild.sh`:
- **Username**: root
- **Password**: blah

Also available: qauser/blah, vroom/blah

## Common Commands

```bash
# Build everything (first time takes ~10-15 mins for DB import)
./docker/devbuild.sh

# Rebuild just the app container (fast - use for code changes)
./docker/devbuild.sh --app

# Stop containers
./docker/devclean.sh

# Clean everything including images
./docker/devclean.sh --full

# View logs
docker logs pmdevdb
docker logs pmdevapp

# Shell into containers
docker exec -it pmdevdb bash
docker exec -it pmdevapp bash

# Connect to MySQL
mysql -h localhost -P 9406 -u pmuser -ppmpass perlmonks
```

## Full Rebuild Procedure

When you need to completely reset the development environment (e.g., database schema changes, fresh import):

```bash
# 1. Stop and remove all containers and images
./docker/devclean.sh --full

# 2. Rebuild everything from scratch (takes 10-15 mins for DB import)
./docker/devbuild.sh

# 3. Verify the site is working
curl http://localhost:9180/
```

This is necessary when:
- You've modified the SQLite import script
- You've changed the database schema
- You've modified seeds.pl
- You want a fresh database with no cached state

## Access URLs

- **HTTP**: http://localhost:9180
- **HTTPS**: https://localhost:9543
- **MySQL**: localhost:9406

## Next Steps

1. ~~Get basic page rendering working~~ (DONE - front page renders)
2. Fix remaining ecore library issues (some htmlcode errors in output)
3. Test login functionality with seeded users
4. Create minimal nodepack for bootstrap
5. Contact PerlMonks developers with progress
6. Plan shared engine architecture

## Related Projects

- **Everything2**: `/home/jaybonci/projects/everything2`
- E2 uses ports 9080/9443/3306 (different from PM)

## Notes for Future Sessions

- The SQLite import takes 10-15 minutes on first run due to the 1.5GB database size
- The timeout is set to 900 seconds (15 minutes) in devbuild.sh
- Check `UNIFICATION_PLAN.md` for detailed architecture analysis
- Check `docs/DEVELOPMENT.md` for development environment specifics

## Library Source

The ecore libraries were updated from production (Perlmonks-SQLite/lib) on 2025-11-26.

### Files removed (not in production):
- `ecore/Config.pm` - was a Perl 5.30.0 Config.pm, conflicted with system Perl 5.38.2
- `ecore/CGI.pm` - conflicted with CPAN CGI module
- `ecore/CGI/Util.pm` - use CPAN CGI module instead
- `ecore/LWP/Simple.pm` - use CPAN LWP::Simple instead
- `ecore/Mail/Sender.pm` - use CPAN Mail::Sender instead

### Files added (new from production):
- `ecore/DBIx/MySQLite.pm`
- `ecore/Everything/AccessLog.pm`
- `ecore/Everything/File.pm`
- `ecore/Everything/Room.pm`
- `ecore/Everything/Search.pm`
- `ecore/Everything/VoteSecret.pm`
- `ecore/Everything/XML.pm`
- `ecore/Perlmonks.pm`

## Patches Applied to ecore

- **Everything/Password.pm**: Replaced with MySQL connection shim (production version uses SQLite). Reads config from /var/everything/etc/$PM_ENVIRONMENT.json or environment variables.
- **Everything/HTML.pm line 1730**: Removed `HTTP/1.1 200 OK` output from `printHeader()` - NPH style breaks CGI mode.

## Known Issues

1. **Canonical link error**: The front page has a server error in the canonical link generation
2. **mod_perl not working**: Using CGI mode due to DynaLoader conflicts with mod_perl on Ubuntu 24.04's threaded Apache
3. **Some htmlcode errors**: Various minor errors appearing in page output that need debugging
