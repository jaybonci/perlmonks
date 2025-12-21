package Everything::Delegation::container;

#############################################################################
#
#   Everything::Delegation::container
#
#   Container delegation module for PerlMonks, following the E2 pattern.
#   Each function is named after a container node title (spaces/hyphens
#   become underscores).
#
#   This module contains the actual container rendering logic, converted
#   from database-stored code to version-controlled Perl for better
#   maintainability, testing, and performance.
#
#############################################################################

use strict;
use warnings;

BEGIN {
    # Import symbols from Everything::HTML via typeglob aliasing
    # This allows us to call these functions without package prefix
    *getNode = *Everything::HTML::getNode;
    *getNodeById = *Everything::HTML::getNodeById;
    *getRef = *Everything::HTML::getRef;
    *getId = *Everything::HTML::getId;
    *getCode = *Everything::HTML::getCode;
    *evalCode = *Everything::HTML::evalCode;
    *htmlcode = *Everything::HTML::htmlcode;
    *parseCode = *Everything::HTML::parseCode;
    *linkNode = *Everything::HTML::linkNode;
    *linkNodeTitle = *Everything::HTML::linkNodeTitle;
    *urlGen = *Everything::HTML::urlGen;
    *isGod = *Everything::HTML::isGod;
    *isApproved = *Everything::HTML::isApproved;
    *getType = *Everything::HTML::getType;
}

#############################################################################
# _get_globals - Access package variables from Everything::HTML
#
# Returns a list of the current request globals:
#   ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS)
#
# This centralizes access to the Everything::HTML package variables,
# making it easy to adapt if the variable handling changes during
# unification with E2.
#############################################################################
sub _get_globals {
    return (
        $Everything::HTML::DB,
        $Everything::HTML::q,
        $Everything::HTML::GNODE,
        $Everything::HTML::USER,
        $Everything::HTML::VARS,
        $Everything::HTML::THEME,
        \%Everything::HTML::HTMLVARS,
    );
}

#############################################################################
# stdcontainer (node 22) - Base HTML wrapper
#
# This is the outermost container that provides:
# - DOCTYPE declaration
# - <html> and <head> elements (via basichead htmlcode)
# - <body> element with node ID
# - Session cache stats (if enabled)
#############################################################################
sub stdcontainer {
    my ($contained_stuff) = @_;
    $contained_stuff //= '';

    my ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS) = _get_globals();

    # Build the head section using basichead htmlcode
    my $head = htmlcode('basichead', '', 'stdcontainer');

    # Get node ID for body
    my $node_id = getId($NODE);

    # Session cache stats (only if enabled in user vars)
    my $cache_stats = '';
    if ($VARS->{show_session_cache_stats}) {
        $cache_stats = qq(<hr /><center><table border='1'><tr><th>Routine</th>)
            . qq(<th>Calls</th><th>Cached Return</th><th>Keys</th></tr>\n)
            . "<tr><td>"
            . join("</td></tr>\n<tr><td>",
                map { "$_</td><td>"
                    . ( 0 + ($HTMLVARS->{$_}{calls} // 0) )
                    . "</td><td>"
                    . ( 0 + ($HTMLVARS->{$_}{cachedret} // 0) )
                    . "</td><td>"
                    . join( " - ", sort keys %{ $HTMLVARS->{$_}{cache} // {} } )
                } qw(isGod isApproved))
            . "</td></tr></table></center>";
    }

    return <<"END_HTML";
<!-- rendered by Everything::Delegation::container::stdcontainer -->
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<!-- Took this out for IE6ites "http://www.w3.org/TR/REC-html40/loose.dtd" -->
<html lang="en">
$head
  <body id="id-$node_id">
$contained_stuff
  $cache_stats
  </body>
</html>
END_HTML
}

#############################################################################
# monktainer (node 492) - Main PerlMonks layout
#
# Provides the main page structure:
# - Monk bar (banner, search, monk pic)
# - Title bar (node title, author, date)
# - Main content area
# - Nodelets sidebar
# - Footer
#
# Parent: stdcontainer
#############################################################################
sub monktainer {
    my ($contained_stuff) = @_;
    $contained_stuff //= '';

    my ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS) = _get_globals();

    # Monk bar (banner, search form, monk pic)
    my $monkbar = htmlcode('monkbar2001');

    # Title bar - node info string with title and author
    my %types = (
        14   => 'superdoc',
        1857 => 'categorized_question',
        1888 => 'categorized_answer'
    );
    my $type = $types{ $NODE->{type_nodetype} } || 'other';

    my $title_attrib = htmlcode('node_info_string', '', undef, qq(
<h3 class="$type">%t</h3>
<span class="attribution">by %W </span>
));
    # Kill the entire attribution span if the author info string returned is empty
    $title_attrib =~ s'<span class="attribution">by  </span>'';

    # Title bar navigation
    my $monktitlebar = '';
    unless ($VARS->{navmenuoff}) {
        $monktitlebar = htmlcode('monktitlebar');
    }

    # Date and links attribution
    my $date_attrib = htmlcode('node_info_string', '', undef, qq(
<span class="attribution">on %d</span>
<span class="addlinks">( %N=%S: %L )</span>
));
    $date_attrib =~ s'<span class="attribution">on </span>'';

    # Help link
    my $help_link = linkNodeTitle('PerlMonks FAQ|Need Help??');

    # Content layout (table or div based on user pref)
    my $content_as_div = $VARS->{content_as_div};
    my $content_tag = $content_as_div ? 'div' : 'td';

    my %content_attribs = (
        td  => ' width="80%" valign="top" ',
        div => '',
    );
    my %nodelet_attribs = (
        td  => ' width="20%" valign="top" align="right" ',
        div => '',
    );

    # Build main content section
    my $content = <<"CONTENT";
      <$content_tag $content_attribs{$content_tag} class="main_content">
        <!--contained stuff-->
        $contained_stuff
        <!--/contained stuff-->
      </$content_tag>
      <!--nodelet handling code (monktainer)-->
CONTENT

    # Nodelets (unless turned off)
    unless ($VARS->{nodelets_off}) {
        my $nodelet = evalCode(getCode("nodelet meta-container"));
        $content .= <<"NODELET";
      <$content_tag $nodelet_attribs{$content_tag} class="nodelets">
        <!-- Begin nodelets -->
$nodelet
        <!-- End nodelets -->
      </$content_tag>
NODELET
    }

    $content .= qq(
      <!--/nodelet handling code (monktainer)-->
);

    # Wrap in table if not using div layout
    unless ($content_as_div) {
        $content = qq(
<center>
  <table width="98%">
    <tr>
$content
    </tr>
  </table>
</center>
);
    }

    # Footer with random taglines
    my @ed = (
        'lovingly hand-crafted',
        'parthenogenetically spawned',
        'graciously bestowed',
    );
    my @pair = (
        'Speedy Servers',
        'Beefy Boxes',
        'Marvelous Managed Hosting',
        'Wonderful Web Servers',
    );
    my @yas = (
        "is a proud member of the",
        "was recently assimilated by",
        "somehow became entangled with",
        "went on a couple dates, and then decided to shack up with",
    );

    my $donate_link = linkNodeTitle('Offering Plate|Donate');
    my $footer_text = sprintf(
        'PerlMonks %s by <a href="?node=vroom">Tim Vroom</a>.<br/>' .
        'PerlMonks %s <a href="http://www.perlfoundation.org">The Perl Foundation</a>. %s to TPF!<br />' .
        '%s and Bandwidth Generously Provided by ' .
        '<a href="http://promote.pair.com/direct.pl?perlmonks.org">pair Networks</a>',
        $ed[rand @ed], $yas[rand @yas], $donate_link, $pair[rand @pair]
    );

    # Build the monktainer output
    my $output = <<"END_MONKTAINER";
<!-- rendered by Everything::Delegation::container::monktainer -->
<!-- monkbar2001 -->
$monkbar
<!-- /monkbar2001 -->
<!-- Begin title bar -->
<table width="98%" align="center" id="titlebar-top">
  <tbody>
    <tr>
      <td valign="middle" class="titlechooser">
        <!-- node_info_string: (h3)Title and (span)Author -->
$title_attrib
        <!-- /node_info_string -->
      </td>
      <td valign="top" align="right" class="monktitlebar">
        <!-- monktitlebar -->
        $monktitlebar
        <!-- /monktitlebar -->
      </td>
    </tr>
  </tbody>
</table>
<table width="98%" align="center" id="titlebar-bottom">
  <tbody>
    <tr>
      <td valign="middle" class="titlechooser">
        <!-- node_info_string: (span)Date and (span)Links -->
$date_attrib
        <!-- /node_info_string -->
      </td>
      <td valign="middle" align="right" class="monktitlebar">
        $help_link
      </td>
    </tr>
  </tbody>
</table>
<!-- End title bar -->
<!-- Begin main (monktainer) -->
$content
<!-- End main (monktainer)-->
<br />
<br />

<div id="footer">
    $footer_text
  <br/>Built with the <a href="http://perl.org">Perl programming language</a>.
</div>
<!-- /monktainer -->
END_MONKTAINER

    # Wrap in stdcontainer
    return stdcontainer($output);
}

#############################################################################
# general_container (node 19) - General content wrapper
#
# This container:
# - Sets the parent container based on theme/style preferences
# - Allows style overrides via query params or environment
# - Wraps content and delegates to the appropriate parent container
#
# Parent: monktainer (default) or style-specific container
#############################################################################
sub general_container {
    my ($contained_stuff) = @_;
    $contained_stuff //= '';

    my ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS) = _get_globals();

    # Style container mapping
    my %style = (
        css    => 224760,
        bare   => 1071,
        ns4    => 235065,
        static => 566868,
        mobile => 1175441,
    );

    # Check for style parameter (use scalar context to avoid CGI warning)
    my $style_param = scalar($q->param("style")) // '';

    # Auto-detect style from environment if not specified
    if (!$style_param) {
        my $list = join "|", keys %style;
        for my $env (qw/HTTP_HOST SCRIPT_NAME/) {
            if ($ENV{$env} && $ENV{$env} =~ /\b($list)\b/i) {
                $style_param = lc $1;
                last;
            }
        }
    }

    # Determine parent container
    my $parent_container =
        $THEME->{generalParent_container} ||
        $HTMLVARS->{generalParent_container} ||
        $NODE->{parent_container} ||
        '';

    # Override with style-specific container if specified
    if ($ENV{CONTAINER_STYLE} && $style{$ENV{CONTAINER_STYLE}}) {
        $parent_container = $style{$ENV{CONTAINER_STYLE}};
    }
    if ($style_param && $style{$style_param}) {
        $parent_container = $style{$style_param};
    }

    # Build output with HTML comments
    my $output = <<"END_GENERAL";
<!-- rendered by Everything::Delegation::container::general_container -->
$contained_stuff
<!-- /general_container -->
END_GENERAL

    # If we have a non-standard parent container, use genContainer for it
    # Otherwise, use monktainer
    if ($parent_container && $parent_container != 492) {
        # For now, fall back to genContainer for alternate parent containers
        # These could be delegated later
        my $container = Everything::HTML::genContainer($parent_container);
        $container =~ s/CONTAINED_STUFF/$output/s;
        return $container;
    }

    # Default: wrap in monktainer
    return monktainer($output);
}

#############################################################################
# formcontainer (node 18) - Form wrapper
#
# Wraps content in an HTML form with:
# - Multipart encoding for file uploads
# - Hidden node_id field
# - Parent node reference (for reply notes)
# - Close form button
#
# Parent: general_container
#############################################################################
sub formcontainer {
    my ($contained_stuff) = @_;
    $contained_stuff //= '';

    my ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS) = _get_globals();

    # Open form
    my $form_open = htmlcode('openform', '',
        -multipart => 1,
        -node_id   => getId($NODE),
    );

    # Parent node reference (for reply notes)
    my $parent_ref = '';
    if ($NODE->{parent_node}) {
        my $PARENT = getNodeById($NODE->{parent_node});
        if ($PARENT) {
            $parent_ref = '<p align=right>In reply to ' . linkNode($PARENT) . '</p>';
        }
    }

    # Close form
    my $form_close = htmlcode('closeform');

    # Build the form container
    my $output = <<"END_FORM";
<!-- rendered by Everything::Delegation::container::formcontainer -->
$form_open
$parent_ref
$contained_stuff
<br />$form_close
<!-- /formcontainer -->
END_FORM

    # Wrap in general_container
    return general_container($output);
}

1;
