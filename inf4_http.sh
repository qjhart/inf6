#! /bin/bash

# program at end of file. search #MAIN


: <<=cut
=pod

=head1  NAME

  inf4 - Communicate with a Fedora 4 server

=head1 USAGE

  inf4 [-b|--base=I<base>] [-x|--prefix=I<prefix>] [-r|--no-rc] \
	[-n|--dry-run] [-d|--dir] [-i|--interactive] [-p|--print] \
	I<cmd> [cmd-options] 

	where <cmd> = config|patch|put|GET|HEAD|OPTIONS|url

=cut
	
: <<=cut

=pod

=head1 OPTIONS

=over 4	

=item B<-b|--base=I<INF4_BASE>>
 set the Fedora4 URL

=item B<-x |--prefix=> I<prefix>>
Add a new prefix for ttl, using prefix:url  format 

=item B<-r|--no-rc>
Do not read from or write to rc file.

=item B<-n|--dry-run>
Show what you would do do not really do it

=item B<-d|--dir>
Set URL (wrt. INF4_BASE) for this operation only

=item B<-i|--interactive>
Use interactive mode

=item B<-p|--print>
Adjust httpie --print= argument

=back
=cut

function main.cmd () {
    cmd=$1
    shift;
    
    case $cmd in
	cd | pwd | pushd | popd ) # Directory Commands
	    $cmd $@;
	    ;;
	put | config | patch)
	    $cmd $@;
	    ;;
	GET | HEAD | OPTIONS | url )	# http requests
	    $cmd $@;
	    ;;

	*)
	    echo  "$cmd not found";
	    ;;
    esac
}

: <<=cut
=pod

=head1 CMD

=cut
function main.options() {
    declare -A default_prefix=( 
	[pcdm]="http://pcdm.org/models#"
	[ldp]="http://www.w3.org/ns/ldp#"
	[dc]="http://purl.org/dc/elements/1.1/"
	[ebucore]="http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#")

    declare -A prefix;
    for i in  ${!default_prefix[*]}; do
	prefix[$i]=${default_prefix[$i]};
    done

    OPTS=`getopt -o h:rx:nd:ip: --long base:,no-rc,prefix:,dry-run,dir:,interactive,print: -n 'inf4' -- "$@"` 

    if [ $? != 0 ] ; then echo "Bad Command Options." >&2 ; exit 1 ; fi

    eval set -- "$OPTS"

    PUSHED=0
    noop=0
    INTERACTIVE=0
    dirz=()				# For Pushd popd
    RC=1
    print=hb

    # Check for no-rc first
    case "$OPTS" in
	*"-r "*) RC=0;;
	*"--no-rc "*) RC=0 ;;
    esac
    
    if (( $RC )); then
	config.readrc;
    fi;
    CWD=$(config.cwd);

    while true; do
	case $1 in
	    -b | --base) INF4_BASE=$2;  shift 2;;
	    -x | --prefix) prefix $2 > /dev/null; shift 2 ;;
	    -r | --no-rc) rc=0; shift ;; 
	    -n | --dry-run) noop=1; shift ;;
	    -d | --dir)
		PUSHED=1
		dirz=("$2" "${dirz[@]}"); # Simple pushd
		shift 2;
		;;
	    -i | --interactive) INTERACTIVE=1; shift;;
	    -p | --print) print=$2; shift 2;;
	    -- ) shift; break;;
	    *) shift; break;
	esac
    done

    # Now set the CMD String
    CMD="$*"
}


# Configuration commands
function config.files () {
    for f in ~/.inf4rc .inf4rc; do
	if [[ -f $f ]]; then echo $f; fi;
    done
}

function config.readrc () {
    for f in `config.files`; do
	if [[ -f $f ]]; then
	    . $f
	fi
    done
}

function config.writerc () {
    if [[ ! -z $1 ]]; then
	file=$1
    elif [[ -f .inf4rc ]] ; then
	file=.inf4rc
    else
	file=~/.inf4rc;
    fi;
    
    echo "INF4_BASE="$INF4_BASE > $file
    for k in  ${!prefix[*]}; do
	if [[ -z ${default_prefix[$k]} ]] ; then 
	    echo "prefix[$k]=${prefix[$k]}" >> $file;
	fi
    done
    echo '#DIRZ' >> $file
    # for k in  ${!dirz[*]}; do
    # 	echo "dirz[$k]=${dirz[$k]}" >> $file;
    # 	echo "dirz[$k]=${dirz[$k]}" > file;
    # done
    echo 'dirz=('${dirz[*]}')' >> $file;
}

function config.host () {
    echo $(echo $INF4_BASE | cut -d/ -f1-3)
}

function config.cwd () {
    echo /$(echo $INF4_BASE | cut -d/ -f4-)
}


: <<=cut
=pod

=head2 config

=head3 USAGE

inf4 [inf4options] -- config print|init

=head4 print

Prints the current configuration files in use.

=head4 init

Writes or overwrites the configuration file <./.inf4rc>. And options passed to the
inf4 command are included, For example

inf4 --base=https://foo.com/fcrepo/rest/bar \
     --prefix=baz:https://baz.org/schema config

Will write a new configuration file with the base and prefix set.

=cut
function config() {
    cmd=$1;
    case $cmd in
	 print)
	     for f in `config.files`; do
		 echo "# $f"
		 cat $f;
	     done
	     ;;
	 init)
	     touch .inf4rc;
	     config.writerc;
	     config.writerc /dev/stdout;
	     ;;	     
	 *) (>&2 echo "Bad config cmd $cmd")
    
    esac;
}

# Location Commands
# Change directory -
# if a user sez 'inf4 -d foo cd'  we take that to mean 'inf4 cd foo'
# and 'inf4 -d foo cd bar' is equal to 'inf4 cd foo; inf4 cd bar'
function cd () {    
    if (( $PUSHED )); then
	if [[ ${dirz[0]} == /* ]]; then
	    CWD=${dirz[0]};
	else
	    CWD=$(pwd)
	fi
	dirz=();
    fi
    if [[ ! -z $1 ]] ; then
	if [[ $1 == /* ]] ; then
	    CWD=$1;
	else
	    CWD=$(readlink -m $(pwd)/$1)
	fi
    fi
    # Reset to your base ${CWD}
    dirz=();
    INF4_BASE=$(config.host)${CWD}
    pwd;
}

function pushd () {
    if (( $PUSHED )); then
	if [[ -z $1 ]]; then
	    PUSHED=0;
	else
	    p=${dirz[0]}
	    popd > /dev/null
	    dirz=("${p}/$1" "${dirz[@]}")
	fi
    else
	if [[ ! -z $1 ]] ; then
	    dirz=("$1" "${dirz[@]}");
	fi;
    fi;
    pwd;
}

function popd () {
    dirz=("${dirz[@]:1}")
    pwd;
}

function pwd () {
    pwd=
    dir=${dirz[0]}
    if [[ -z $dir ]]; then
	pwd=${CWD};
    else
	if [[ $dir == /* ]]; then
	    pwd=${dir}
	else
	    pwd=$(readlink -m ${CWD}/${dir})
	fi
    fi
    if [[ ! -z $1 ]]; then 	# Can add to pwd for relative links
	if [[ $1 == /* ]]; then
	    pwd=$1
	else
	    pwd=$(readlink -m ${pwd}/${1})
	fi	
    fi
    echo ${pwd}
}

function url () {
    echo $(config.host)$(pwd) ;
} 

function _http () {
    http --print=$print $@
}

# Direct HTTP Requests
function GET () {
    _http GET $(url)
}

function OPTIONS () {
    _http OPTIONS $(url)
}

function HEAD () {
    _http HEAD $(url)
}

# INF4 write information
function prefix () {
    if [[ ! -z $1 ]]; then
	pre=${1%%:*};
	url=${1#*:};
	if [[ -z $url ]]; then
	    unset prefix[$pre]
	else
	    prefix[$pre]=$url;
	fi
    fi
    for i in  ${!prefix[*]}; do echo "@prefix $i: <${prefix[$i]}> . " ; done   
}

function prefix.sp () {
    for i in ${!prefix[*]}; do echo "PREFIX $i: <${prefix[$i]}>" ; done   
}

function ldp_direct () {
    prefix;
    echo '<> a ldp:DirectContainer, pcdm:Object ;
  ldp:hasMemberRelation pcdm:'$1' ;
  ldp:membershipResource <'$(pwd $2)'> .'
}

function patch () {
    insert='';
    while IFS= read -r line || [[ -n "$line" ]]; do
#	line=${line%?}
	insert+=" $line";
    done < "${1:-/dev/stdin}"

    if (( $noop )); then
	echo "echo $(prefix.sp; echo 'INSERT {'$insert'} WHERE {}') | _http PATCH $(url) Content-Type:application/sparql-update"
    else
	(prefix.sp; echo 'INSERT {'$insert'} WHERE {}') |
	    _http PATCH $(url) Content-Type:application/sparql-update
    fi
}

function put() {
    # Get options
    OPTS=`getopt -o s:m: --long sidecar:,mime-type:,member:,resource: -n 'inf4 put' -- "$@"` 
    if [ $? != 0 ] ; then echo "Bad put options." >&2 ; exit 1 ; fi
    eval set -- "$OPTS"
    sidecar=
    mime=
    member_relation=
    member_resource='..'
    while true; do
    	case $1 in
	    -s | --sidecar)
		if [[ "$2" == "-" ]]; then
		    sidecar=/dev/stdin
		else
		    sidecar=$2;
		fi;
		shift 2;
		;;
	    -m | --mime-type) mime=$2; shift 2;;
	    --member) member_relation=$2; shift 2;;
	    --resource) member_resource=$2; shift 2;;
	    --) shift; break;;
    	    *) break;;
    	esac
    done
        
    cmd=$1
    shift;
    file=0
    case $cmd in
	object)
	    is='<> a ldp:Resource, pcdm:Object .'
	    mime='text/turtle';
	    ;;
	collection)
	    mime='text/turtle';
	    if [[ -z $member_relation ]]; then
		member_relation='hasMember';
	    fi
	    is=$(ldp_direct $member_relation $member_resource)
	    ;;
	dir)
	    mime='text/turtle';
	    if [[ -z $member_relation ]]; then
		member_relation='hasFile';
	    fi
	    is=$(ldp_direct $member_relation $member_resource)
	    ;;
	file)
	    if [[ -z $mime ]]; then
		mime=`file --mime-type -b $1`;
	    fi;
	    ;;
	*)
	    echo "$cmd: bad put";
	    exit 1;
	    ;;
    esac

    if (( $noop )) ; then
	if [[ -z $is ]] ; then
	    echo "http PUT $(url) Content-Type:$mime < $1"
	else
	    echo "http PUT $(url) Content-Type:$mime <<< '$(prefix; echo $is )'"
	fi
    else
	if [[ -z $is ]] ; then
	    _http PUT $(url) Content-Type:$mime < $1
	else
	    (prefix; echo $is ) | _http PUT $(url) Content-Type:$mime
	fi
    fi
    # Post process
    case $cmd in
	file)
	    if (( $noop )); then
		echo 'pushd fcr:metadata'
		echo "patch  <<< '<> a pcdm:File .'"
		if [[ ! -z $sidecar ]] ; then
		    echo "patch $sidecar"
		fi
		echo "popd"		
	    else
		pushd fcr:metadata
		patch  <<< '<> a pcdm:File .'
		if [[ ! -z $sidecar ]] ; then
		    patch $sidecar
		fi
		popd
	    fi
	    ;;
	*)
	    if [[ ! -z $sidecar ]] ; then
		if [[ $mime = 'text/turtle' ]]; then
		    patch $1 $sidecar
		else
		    pushd fcr:metadata
		    patch $sidecar
		    popd
		fi
	    fi	    
    esac
}

function headers() {
    shopt -s extglob # Required to trim whitespace; see below
    while IFS=':' read key value; do
	value=${value##+([[:space:]])}; value=${value%%+([[:space:]])}
	case "$key" in
            HTTP*) read PROTO STATUS MSG <<< "$key{$value:+:$value}"
		   header[$key]=declare -A 
                   ;;
	    *) header[$key]=$value;
		;;

	esac 
    done <<< "$1"
}

: <<=cut
=pod

=head1 AUTHOR

Quinn Hart <qjhart@ucdavis.edu>

=cut


#MAIN
main.options $@

eval set -- "$CMD"		# sets the CMD after initial parse

if (( $INTERACTIVE )) ; then
    while read -p `pwd`'> ' cmd a b c; do
	main.command $cmd $a $b $c
    done
else
    main.command $@
fi

# if -d in parameters, pop of that item
if (( $PUSHED )); then
    popd > /dev/null
fi;

# if not --no-rc, then write config
if (( $RC )); then
    config.writerc;
fi

exit 0;
