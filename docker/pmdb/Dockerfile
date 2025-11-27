FROM ubuntu:24.04

LABEL maintainer="Everything Engine Team"
LABEL description="PerlMonks Database Container"

ENV DEBIAN_FRONTEND=noninteractive

# Install MySQL and SQLite (for import)
RUN apt-get update && apt-get install -y \
    mysql-server \
    sqlite3 \
    perl \
    libdbi-perl \
    libdbd-mysql-perl \
    libdbd-sqlite3-perl \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p \
    /var/everything/db \
    /var/everything/tools \
    /etc/everything \
    /var/run/mysqld \
    && chown mysql:mysql /var/run/mysqld

# Copy SQLite database and tools
COPY db/perlmonks.sqlite /var/everything/db/
COPY tools/sqlite_to_mysql.pl /var/everything/tools/
COPY tools/seeds.pl /var/everything/tools/
COPY docker/pmdb/mysqld_wrapper.sh /etc/everything/mysqld_wrapper.sh

RUN chmod +x /etc/everything/mysqld_wrapper.sh \
    && chmod +x /var/everything/tools/sqlite_to_mysql.pl \
    && chmod +x /var/everything/tools/seeds.pl

EXPOSE 3306

CMD ["/etc/everything/mysqld_wrapper.sh"]
