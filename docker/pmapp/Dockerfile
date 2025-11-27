FROM ubuntu:24.04

LABEL maintainer="Everything Engine Team"
LABEL description="PerlMonks Application Container"

ENV DEBIAN_FRONTEND=noninteractive
ENV PM_ENVIRONMENT=development

# System packages - base LAMP stack for PerlMonks
# Note: No perlmagick, no Node.js, no AWS CLI (unlike E2)
# Using libmysqlclient-dev (not libmariadb-dev-compat - they conflict)
RUN apt-get update && apt-get install -y \
    git wget curl vim \
    build-essential libexpat1-dev \
    libmysqlclient-dev pkg-config \
    libxml2-dev dnsutils tzdata \
    perl apache2 libapache2-mod-perl2 \
    mysql-client \
    cpanminus \
    psmisc \
    && rm -rf /var/lib/apt/lists/*

# Create directory structure
# PerlMonks uses /var/everything like E2 (both built on Everything Engine)
# No /var/mason needed - PerlMonks does not use Mason
RUN mkdir -p \
    /var/libraries/lib/perl5 \
    /var/everything/ecore \
    /var/everything/etc \
    /var/everything/www \
    /var/log/everything \
    /etc/everything \
    /var/bootstrap

# Install Perl dependencies
# Start minimal - will grow iteratively as we discover requirements
COPY cpanfile /var/bootstrap/cpanfile
RUN cpanm -L /var/libraries --notest --installdeps /var/bootstrap \
    || echo "Note: Some dependencies may need to be added iteratively"

# Copy application code
COPY ecore/ /var/everything/ecore/
COPY etc/ /var/everything/etc/
COPY www/ /var/everything/www/

# Ensure all application files are readable by Apache (www-data)
RUN chmod -R 755 /var/everything/www/ /var/everything/ecore/ /var/everything/etc/

# Copy wrapper script
COPY docker/pmapp/apache2_wrapper.sh /etc/everything/apache2_wrapper.sh
RUN chmod +x /etc/everything/apache2_wrapper.sh

# Apache configuration - enable CGI and mod_perl
RUN a2enmod perl headers rewrite cgid cgi

# Note: Don't set PERL5LIB globally - it conflicts with mod_perl's APR modules
# Apache config uses PerlSwitches to add library paths instead

EXPOSE 80 443

WORKDIR /var/everything

CMD ["/etc/everything/apache2_wrapper.sh"]
