#!/usr/bin/env bash

# manual preparations: getmail/<server>.<kind>_<email>
# e.g.
# pass insert getmail/imap_smtp.993_puntaier.roland@gmail.com
# pass insert getmail/mail.pops_testpops@fellowsandcarr.ca
# pass insert getmail/mail.imaps_testimaps@fellowsandcarr.ca
# pass insert getmail/broadstreet.pops_getmail6@webconquest.com
# pass insert getmail/broadstreet.imaps_getmail6@webconquest.com

mkportnr(){
    case $1 in
        pop)
            portnr=110
            ;;
        imap)
            portnr=143
            ;;
        imaps)
            portnr=993
            ;;
        pops)
            portnr=995
            ;;
        *)
            portnr=$1
            ;;
    esac
}
testemail(){
    txtinfo="я αβ один süße créme in Tromsœ."
    if type /usr/bin/neomutt > /dev/null 2>&1; then
        echo "Neomutt, $txtinfo" | /usr/bin/neomutt -s "testing as subject" $email > /dev/null 2>&1
        #echo "test 1 sent via neomutt" | /usr/bin/neomutt -s "testing as subject" $email
    else
        echo "Mutt, $txtinfo" | /usr/bin/mutt -s "testing as subject" $email > /dev/null 2>&1
    fi
    if [ $? -ne 0 ]; then
        echo "mutt failed ... sending one email using msmtp"
        echo "Msmtp, $txtinfo" | /usr/bin/msmtp -a puntaier.roland@gmail.com $email
        sleep 20
    else
        sleep 3
    fi
}
declare -a kind_emails
kind_emails=()
for kind_email in $( pass find getmail ); do
    if [[ $kind_email =~ ^.*@.* ]]; then
        kind_emails+="$kind_email "
    fi
done
if [[ -z $kind_emails ]]; then
    echo "test_getmail.sh needs 'pass insert getmail/...'"
fi
for ke in $kind_emails; do

    ##comment
    #echo $kind_emails
    #ke=${kind_emails[1]%%( )*}

    echo $ke

    email=${ke##*_}
    srvkind=${ke%_*}
    srv=${srvkind%.*}
    srvgm=${srv%_*}.${email#*@}
    srvsmtp=${srv#*_}.${email#*@}
    srvgm=${srvgm/chello/upcmail}
    srvsmtp=${srvsmtp/chello/upcmail}
    kind=${srvkind#*.}
    mkportnr $kind
    [ $portnr = "995" ] && kind='POP3'
    [ $portnr = "993" ] && kind='IMAP'
    # portnr
    mws="${email#*@},${srvgm},${portnr},${srvsmtp},587"
    mwn="Test Person"
    mwp="getmail/$ke"
    mwrmmails=YES mwaddr=$email ~/.local/bin/mw rm > /dev/null 2>&1
    #~/.local/bin/mw list
    mwusegetmail=1 mwtype=offline mwaddr=$email mwlogin=$email mwpass=$mwp mwserverinfo=$mws mwname=$mwn ~/.local/bin/mw add > /dev/null 2>&1
    testemail
    ~/.local/bin/mw $email > /dev/null 2>&1
    cntreceived=$(find $MAILDIR/$email/ -type f | wc -l)
    [ $cntreceived -ge 1 ] && echo "===========> PASS " || echo "===========> FAIL"

    echo "getmail to procmail and filters"
    testemail
    cwd=$(pwd)
    mkdir -p procmailtest/Mail/tests/{cur,tmp,new}
    cat > procmailtest/getmail <<EOF
[retriever]
type = Simple${kind}SSLRetriever
server = $srvgm
username = $email
port = $portnr
password_command = ("pass", "$mwp")

[destination]
type = MDA_external
path = /usr/bin/procmail
arguments = ("-f", "%(sender)", "-m", "$cwd/procmailtest/procmail")

#pacman -S spamassassin
[filter-1]
type = Filter_external
path = /usr/bin/vendor_perl/spamc
ignore_header_shrinkage = True

#pacman -S clamav
[filter-2]
type = Filter_classifier
path = /usr/bin/clamscan
arguments = ("--stdout", "--no-summary",
    "--scan-mail", "--infected", "-")
exitcodes_drop = (1,)

[options]
read_all = true
delete = true
EOF
    cat > procmailtest/procmail <<EOF
MAILDIR=$cwd/procmailtest/Mail
DEFAULT=\$MAILDIR/INBOX

:0
* ^Subject:.*test.*
tests/

:0
\$DEFAULT/

EOF

    getmail --rcfile=getmail --getmaildir=$cwd/procmailtest
    cntreceived=$(find $cwd/procmailtest/Mail/tests/new -type f | wc -l)
    [ $cntreceived -ge 1 ] && echo "===========> PASS " || echo "===========> FAIL"
    rm -rf procmailtest

    mwrmmails=YES mwaddr=$email ~/.local/bin/mw rm > /dev/null 2>&1
done

