package Everything::Delegation::htmlcode;

#############################################################################
#
#   Everything::Delegation::htmlcode
#
#   Htmlcode delegation module for PerlMonks, following the E2 pattern.
#   Each function is named after an htmlcode node title (spaces/hyphens
#   become underscores).
#
#   This module contains the actual htmlcode rendering logic, converted
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
    *getNodeWhere = *Everything::HTML::getNodeWhere;
    *selectNode = *Everything::HTML::selectNode;
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
    *getType = *Everything::HTML::getType;
    *genContainer = *Everything::HTML::genContainer;
    *updateNodelet = *Everything::HTML::updateNodelet;

    # isApproved is in the Everything package, not Everything::HTML
    *isApproved = *Everything::isApproved;
}

#############################################################################
# _get_globals - Access package variables from Everything::HTML
#
# Returns a list of the current request globals:
#   ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS, $NODELET)
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
        $Everything::HTML::NODELET,
    );
}

#############################################################################
# basichead (node 27) - HTML head section generator
#
# Returns the <head> section with title, meta tags, and stylesheets.
# Takes optional head_id parameter for the head element.
#############################################################################
sub basichead {
    my ($head_id) = @_;

    my ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS) = _get_globals();

    my $common = htmlcode('htmlhead');

    my $title = $q->escapeHTML($NODE->{title});
    my $meta = '';

    if ($VARS->{titledef}) {
        $title = $VARS->{titledef};
        $title =~ s/(%[A-Z])/lc($1)/eg;  # get unlinkified versions
        $title =~ s/%[wl]//g;  # these can't be made without links
        $title = htmlcode('node_info_string', '', undef, $title);
        $title =~ s/&nbsp;/ /g;
        $title = $q->escapeHTML($title);
    }
    elsif ($NODE->{node_id} == 131) {
        $title = 'PerlMonks - The Monastery Gates';
        $meta = <<'EOF';
    <meta name    = "description"
          content = "A community committed to sharing Perl
                     knowledge and coding tips.  The site
                     contains questions and answers, useful
                     snippets, and a library of code."
    />
    <meta name    = "keywords"
          content = "perl, mod_perl, regular expressions,
                     regexp, CGI, programming,
                     learning, tutorials, questions, answers,
                     examples, node, experience,
                     votes, code"
    />
EOF
    }

    my $head_attr = $head_id ? qq( id="$head_id") : '';
    return <<"EOF";
<!-- rendered by Everything::Delegation::htmlcode::basichead -->
  <head$head_attr>
    <title>
      $title
    </title>
$common
$meta
  </head>
EOF
}

#############################################################################
# htmlhead (node 320275) - Common head elements
#
# Returns the basics to put inside a head element:
# - Canonical link
# - Theme stylesheet
# - Common CSS
# - User custom CSS
# - Favicon
#############################################################################
sub htmlhead {
    my ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS) = _get_globals();

    my $absprefix = ($ENV{SCRIPT_NAME} =~ m!^(/~\w+)! ? $1 : '');
    my $icon = qq(<link rel="icon" href="$absprefix/favicon.ico" />\n);
    my $canonical = '';

    if (my $thread_root = htmlcode('get_root_node')) {
        $canonical = qq(<link rel="canonical" href="https://www.perlmonks.org/?node_id=$thread_root" />\n);
    }

    my ($theme, $common) = ('', '');
    my $theme_comment = "<!-- Theme $$VARS{preferred_theme}: $THEME->{description} -->\n";

    if ($THEME->{CSS}) {
        my $theme_fmt = qq(<link rel="stylesheet" href="?node_id=%d" type="text/css" />\n);
        my $theme_elem = sprintf $theme_fmt, $THEME->{CSS};
        if ($theme_elem ne $theme_fmt) {
            $theme .= $theme_elem;
            $common = qq(<link rel="stylesheet" href="$absprefix/css/common.css" type="text/css" />\n);
        }
    }

    my $js_url = '/js/list_replies_toggle_javascript.js';
    my $js = qq(<script language="javascript" type="text/javascript" src="$js_url" integrity="sha384-6jdBZxT7udN82vOTryPaLwqMohSfDF3HXv3M32KAZ7dOREMdAkYh9ZhoaKCgCXcr" crossorigin="anonymous"></script>\n);
    $common = $js . $common;

    my $css = $VARS->{css_link};
    if ($css) {
        $css =~ s/\n//g;
        $css =~ s/</&lt;/g;
        $css =~ s/>/&gt;/g;
        $css =~ s/'/&quot;/g;
        $css = qq(<link rel="stylesheet" href='$css' type="text/css" />\n);
    }
    $css ||= "<!-- No CSS Link in Display Settings -->\n";

    my $style = $VARS->{style};
    if ($style) {
        chomp $style;
        my $ind = ' ' x 6;
        $style =~ s/</&lt;/g;
        $style =~ s/\n/\n$ind/g;
        $style = <<"END";
<style type="text/css">
$style
</style>
END
    }
    $style ||= "<!-- No CSS Data in Display Settings -->\n";

    if ('print' eq ($q->param('displaytype') || '')) {
        $theme = $style = '';
        $common = qq(<link rel="stylesheet" type="text/css" href=") . (
            $VARS->{printcss} || urlGen({ node => 'print displaytype stylesheet' }, -1)
        ) . qq(" />\n);
    }

    my $noindex =
        'document' eq $NODE->{type}{title}
            ? '<meta name="robots" content="noindex">'
            : 'Super Search' eq $NODE->{title}
            ? '<meta name="robots" content="noindex,nofollow">' : '';

    return "
<!-- rendered by Everything::Delegation::htmlcode::htmlhead -->
    $canonical
    $theme_comment
    $common
    $theme
    $css
    $style
    $icon
    $noindex
";
}

#############################################################################
# monkbar2001 (node 63157) - Main header bar
#
# Returns the monk bar with:
# - Page ad (pair Networks banner)
# - Random monk picture
# - Random monk quip
# - Search form
#############################################################################
sub monkbar2001 {
    my ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS) = _get_globals();

    my $LINKNODE = getNode('Land of Monks and Honey', 'fullpage');

    my $monk_pic = $VARS->{monkpicsoff}
        ? '<!-- Monk Pic Turned Off In User Settings -->'
        : linkNode(
            $LINKNODE,
            htmlcode('randomonk'),
            {},
            { trusted => 'yes' }
        );

    my $monk_quip = $VARS->{monkquipsoff}
        ? '<!-- Monk Quip Turned Off In User Settings -->'
        : htmlcode('monkquip');

    my $page_ad = htmlcode('page_ad');

    my $ret = <<"END";
<!-- rendered by Everything::Delegation::htmlcode::monkbar2001 -->
    <table id="monkbar" width="100%" border="0"
        cellpadding="0" cellspacing="0">
      <tr class="bannerrow">
        <td align="left" width="100%">
        $page_ad
        </td>
        <td rowspan="2" align="right" valign="bottom">
          $monk_pic
        </td>
      </tr>
      <tr class="monkquip">
        <td class="monkquip"
            valign="bottom" width="100%" >
          $monk_quip
        </td>
      </tr>
      <tr class="titlebar">
        <td class="titlebar">

          <form method="get" action="?"
              enctype="application/x-www-form-urlencoded" >
            &nbsp;
            <input type="text" name="node"
                id="search_text"
                size="20" maxlength="300" />
            <input class="titlebar" type="submit"
                value="Search" />
          </form>
        </td>
        <td class="titlebar" id="mb2001titlebar" align="right" >
          <a class="titlebar" href="?">PerlMonks</a>&nbsp;&nbsp;
        </td>
      </tr>
    </table>
END

    htmlcode('recordhit');
    return $ret;
}

#############################################################################
# monkquip (node 444) - Random monastery quip
#
# Returns a random quip for display in the monk bar.
#############################################################################
sub monkquip {
    my @quips = (
        "Welcome to the Monastery",
        "Perl Monk, Perl Meditation",
        "Think about Loose Coupling",
        "There's more than one way to do things",
        "laziness, impatience, and hubris",
        "Pathologically Eclectic Rubbish Lister",
        "Perl-Sensitive Sunglasses",
        "P is for Practical",
        "go ahead... be a heretic",
        q("be consistent"),
        "Keep It Simple, Stupid",
        "more <b>useful</b> options",
        "good chemistry is complicated,<br />and a little bit messy -LW",
        "Just another Perl shrine",
        "Syntactic Confectionery Delight",
        "Your skill will accomplish<br />what the force of many cannot",
        "Perl: the Markov chain saw",
        "XP is just a number",
        "No such thing as a small change",
        "The stupid question is the question not asked",
        "Don't ask to ask, just ask",
        "We don't bite newbies here... much",
        "Clear questions and runnable code<br />get the best and fastest answer",
        "Do you know where your variables are?",
        "Problems?  Is your data what you think it is?",
        "Come for the quick hacks, stay for the epiphanies.",
    );

    return $quips[rand @quips];
}

#############################################################################
# randomonk (node 447) - Random monk picture
#
# Returns an img tag for a random monk picture.
#############################################################################
sub randomonk {
    my ($specificMonk, $monkclass) = @_;

    my ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS) = _get_globals();

    my $str;
    if ($specificMonk && $specificMonk =~ /\D/) {
        $specificMonk = undef;
    }

    my $num = rand();
    my $MONKS;
    if ($num > 0.15) {
        ($MONKS) = getNodeWhere({ title => "monkpics" }, getType('nodegroup'));
    } else {
        ($MONKS) = getNodeWhere({ title => "usermonkpics" }, getType('nodegroup'));
    }

    my @monkpics = @{ $MONKS->{group} };
    $specificMonk ||= rand(@monkpics) + 1;
    my $RNDMONK = selectNode($monkpics[--$specificMonk]);
    my ($width, $height) = (74, 91);

    return qq|$str<img src="$$RNDMONK{thumbsrc}" border="0" alt="$$RNDMONK{alt}" title="$$RNDMONK{alt}"
 width="$width" height="$height" />|;
}

#############################################################################
# page_ad (node 390030) - Page advertisement
#
# Returns the pair Networks banner ad.
#############################################################################
sub page_ad {
    return '<a href="http://pair.com">
 <img src="//promote.pair.com/i/pair-banner-current.gif"
  height = "60"
  width  = "468"
  alt    = "Beefy Boxes and Bandwidth Generously Provided by pair Networks"
 />
</a>';
}

#############################################################################
# monktitlebar (node 494) - Title bar navigation
#
# Returns the title bar with login/logout links and user link.
#############################################################################
sub monktitlebar {
    my ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS) = _get_globals();

    my $userlink = linkNode($USER);
    $userlink = '<span class="cloaked">#' . $userlink . '</span>'
        if $q->cookie('userpass') =~ /%(?:u00)?7C(.)$/i && $1;

    return htmlcode('get_sitedoclet', 'monktitlebar sitedoclet',
        -TOPNAV_SPECIAL =>
            getId($USER) == $HTMLVARS->{guest_user}
                ?
                    '<li>' . linkNode(109, 'Log&nbsp;in') . '</li>' .
                    '<li>' . linkNode(101, "Create&nbsp;a&nbsp;new&nbsp;user") . '</li>'
                :
                    '<li>' . linkNode(109, "log&nbsp;" . $q->escapeHTML($USER->{title}) . "&nbsp;out", { op => 'logout' }) . '</li>' .
                    '<li>' . $userlink . '</li>'
    );
}

#############################################################################
# openform (node 42) - Open HTML form
#
# Takes optional list of named parameters which are passed to CGI's
# start_form, except for a -displaytype parameter which can be used to
# override the current displaytype.
# -node_id=>0 prevents the node_id/node hidden params (for 'search' forms)
#############################################################################
sub openform {
    my ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS) = _get_globals();

    my %opts = (-method => 'post', -action => '?', @_);
    $opts{-target} ||= $q->param("formtarget");

    my ($node_param, $node_val) = ('node_id', delete $opts{-node_id});
    if ('0' eq $node_val) {
        $node_param = 0;
    } elsif (!$node_val) {
        if ($node_val = delete $opts{-node}) {
            $node_param = 'node';
        } else {
            $node_val = getId($NODE);
        }
    }

    my $displaytype = delete($opts{-displaytype});
    my $multipart = delete($opts{-multipart});

    my @formparms =
        map {
            defined $opts{$_}
                ? ($_ => delete $opts{$_})
                : ()
        }
        qw/ -method -action -enctype -target /, sort keys %opts;

    my $html =
        $multipart
            ? $q->start_multipart_form(@formparms)
            : $q->start_form(@formparms);

    return $html if !$node_param;

    my $fix_input = sub {
        local $_ = shift;
        s#(<input[^<>]*)/>#<span>$1></input></span>#gi;
        $_
    };

    return join '',
        "<!-- rendered by Everything::Delegation::htmlcode::openform -->\n",
        $html,
        '',
        $fix_input->($displaytype
            ? $q->hidden(-name => 'displaytype', -value => $displaytype, -force => 1)
            : $q->hidden('displaytype')),
        $fix_input->($q->hidden(-name => $node_param, -value => $node_val, -force => 1)),
        ($q->param('back') ? $fix_input->($q->hidden(-name => 'back', -value => $q->param('back'))) : ()),
        '';
}

#############################################################################
# closeform (node 29) - Close HTML form
#
# Takes optional label and name for the submit button.
#############################################################################
sub closeform {
    my ($label, $name) = @_;

    my ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS) = _get_globals();
    # Note: closeform uses $query instead of $q in the original
    my $query = $q;

    return (
        $HTMLVARS->{closeform_nostumbit}
            ? "<!-- nostumbit=$HTMLVARS->{closeform_nostumbit} -->"
            : $query->submit($name || 'perlisgood', $label || 'stumbit')
    ) . $query->end_form;
}

#############################################################################
# node_info_string (node 1170542) - Node information formatter
#
# Formats node information using a template string with placeholders:
#   %n - node_id
#   %N - linked node_id
#   %t - escaped title
#   %T - linked title
#   %a - author title
#   %A - linked author
#   %B - " by author" if different from node
#   %s - type title
#   %S - linked type
#   %d - create date
#   %R - reputation
#   %L - additional links (print, xml, code)
#   %W - extended author info
#############################################################################
sub node_info_string {
    my ($node, $fmt, $deftitle) = @_;

    my ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS) = _get_globals();

    $node ||= $NODE;
    getRef($node);
    $fmt ||= "%T";

    my $pmdev_ok = isApproved($USER, getNode('pmdev', 'usergroup'));
    my $patchable = htmlcode('lookup_patchable_field');

    my $author = $node->{author_user};
    if ($node->{type_nodetype} == 1857
        || $node->{type_nodetype} == 1888
        and !$pmdev_ok) {
        $author = $node->{original_author};
    }
    if ($patchable and !$pmdev_ok) {
        undef $author;
    }

    my $AUTHOR = $author;
    getRef($AUTHOR) if defined $AUTHOR;

    my $addl_links = sub {
        my $code = $pmdev_ok && $patchable
            ? linkNode($node, 'code', { displaytype => 'viewcode' }) : '';
        my $xml = linkNode($node, 'xml', { displaytype => 'xml' });
        my $print = linkNode($node, 'print', { displaytype => 'print' }, { rel => "nofollow", trusted => 'yes' });
        my $wreplies = linkNode($node, 'w/replies', { displaytype => 'print', replies => 1 }, { rel => "nofollow", trusted => 'yes' });

        join ', ', grep { $_ } $print . ' ' . $wreplies, $xml, $code
    };

    my $extd_auth = sub {
        return '' unless $author;
        my $uid = getId($USER);
        if ($uid == $author && $uid != $HTMLVARS->{guest_user}) {
            return linkNode($USER, 'you') . '!!!';
        }
        my $title = '';
        if ($author != $HTMLVARS->{guest_user}) {
            $title = htmlcode('getLevelTitle', '', user => $author, format => 3);
            $title and $title = ' ' . $q->span({ class => 'attribution-title' }, $title);
        }
        return linkNode($author) . $title;
    };

    my %partsub = (
        n => sub { $node->{node_id} },
        N => sub { linkNode($node->{node_id}, '&#091;id://' . $node->{node_id} . '&#093;') },
        t => sub { $q->escapeHTML($node->{title}) },
        T => sub { linkNode($node, $q->escapeHTML($node->{title}) || $deftitle || $node->{node_id}) },
        a => sub { defined($AUTHOR) ? $AUTHOR->{title} : '' },
        A => sub { defined($author) ? linkNode($author) : '' },
        B => sub { defined($AUTHOR) && $AUTHOR->{node_id} != $node->{node_id} ? ' by ' . linkNode($author) : '' },
        s => sub { $node->{type}{title} },
        S => sub { linkNode($node->{type_nodetype}) },
        d => sub { $node->{'createtime'} && $author ? htmlcode('parseTimeInString', '', $node->{'createtime'}) : '' },
        R => sub { $node->{reputation} },
        L => $addl_links,
        W => $extd_auth,
    );

    # add aliases
    $partsub{'D'} = $partsub{'d'};
    $partsub{'l'} = $partsub{'L'};
    $partsub{'w'} = $partsub{'W'};
    $partsub{'r'} = $partsub{'R'};

    my %partval = ('%' => '%');

    my $html = '';
    my @a = split /(%)(.)/, $fmt;
    while (@a) {
        my $a = shift @a;
        if ($a ne '%' or !@a) {
            $html .= $a;
            next;
        }
        $a = shift @a;
        $html .= ($partval{$a} ||= $partsub{$a} ? $partsub{$a}->() : '');
    }
    return $html;
}

#############################################################################
# nodelet_meta_container (node 40) - Nodelet container
#
# Renders all configured nodelets for the current user.
# Note: function name uses underscore for "nodelet meta-container"
#############################################################################
sub nodelet_meta_container {
    my ($DB, $q, $NODE, $USER, $VARS, $THEME, $HTMLVARS) = _get_globals();

    my $listem = grep { $_ eq 'list' } @_;

    return "<!-- you have nodelets turned off -->"
        if $VARS->{nodelets_off} && !$listem;

    my @nodelets;
    @nodelets = split ',', $VARS->{nodelets}
        if exists $VARS->{nodelets};
    if (getId($NODE) == $HTMLVARS->{default_node} || $VARS->{fpeqnonfp}) {
        @nodelets = split ',', $VARS->{fpnodelets}
            if exists $VARS->{fpnodelets};
    }

    if (!@nodelets && $VARS->{nodelet_group}) {
        my ($NODELETGROUP) = $DB->getNodeById($VARS->{nodelet_group});
        @nodelets = @{ $NODELETGROUP->{group} }
            if $NODELETGROUP->{type}{title} eq 'nodeletgroup';
    }
    if (!@nodelets) {
        my ($DEFAULT) = $DB->getNodeById($HTMLVARS->{default_nodeletgroup});
        @nodelets = @{ $DEFAULT->{group} };
    }
    return "<!-- no nodelets! -->"
        if !@nodelets;

    my ($hasApp, $hasStat, $hasEd, $hasXp, $hasLogin) = map {
        0 <= index(" @nodelets ", " $_ ")
    } my ($approve, $status, $editors, $xp, $login) = map {
        getId(getNode($_, 'nodelet'))
    } 'Approval Nodelet', 'Node Status', 'Editors Nodelet',
        'XP Nodelet', 'Log In';

    unshift @nodelets, $approve
        if $VARS->{approvalnodelet} && !$hasApp;
    unshift @nodelets, $status
        if !$hasApp && !$hasStat;
    unshift @nodelets, $editors
        if $VARS->{editorsnodelet} && !$hasEd;
    unshift @nodelets, $xp
        if !$hasXp && getId($USER) != $HTMLVARS->{guest_user};
    unshift @nodelets, $login
        if !$hasLogin && getId($USER) == $HTMLVARS->{guest_user};

    my (%seen, $nlts);
    for my $node (@nodelets) {
        next
            if $node !~ /\d/
            || $seen{$node}++;
        $node = $DB->getNodeById($node);

        # Set global NODELET for container access
        $Everything::HTML::NODELET = $node;

        updateNodelet($node);
        next unless $node->{nltext} =~ /\S/;

        my $html = '';
        if ($listem) {
            $html = qq(<dt>$node->{title}</dt>) .
                    qq(<dd id="nl$node->{node_id}">$node->{nltext}</dd>);
        }
        elsif ($node->{parent_container}) {
            $html = genContainer($node->{parent_container});
            $html =~ s/CONTAINED_STUFF/$node->{nltext}/s;
        }
        else {
            $html = $node->{nltext};
        }

        $nlts .= $html;
    }

    $listem and return qq(<dl>$nlts</dl>);

    my $elem = $VARS->{'nodelets_as_div'} ? 'div' : 'table';
    return join "\n",
        "<!-- rendered by Everything::Delegation::htmlcode::nodelet_meta_container -->",
        "<$elem class='nodelet_container' id='nodelet_container'>",
        $nlts,
        "</$elem>",
        '';
}

1;
