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
    if type /usr/bin/neomutt > /dev/null 2>&1; then
        echo "test 1 sent via neomutt" | /usr/bin/neomutt -s "testing as subject" $email > /dev/null 2>&1
    else
        echo "test 1 sent via mutt" | /usr/bin/mutt -s "testing as subject" $email > /dev/null 2>&1
    fi
    if [ $? -ne 0 ]; then
        echo "mutt failed ... sending one email using msmtp"
        echo "test 1 sent via mutt" | /usr/bin/msmtp -a roland.puntaier@gmail.com $email
        sleep 20
    else
        sleep 3
    fi
}
declare -a kind_emails
kind_emails=()
for kind_email in $( pass find getmail ); do
    if [[ $kind_email =~ ^.*@.* ]]; then
        kind_emails+=" $kind_email"
    fi
done
for ke in $kind_emails; do

    ##comment
    #echo $kind_emails
    #ke=$kind_emails[4]

    echo $ke

    email=${ke##*_}
    srvkind=${ke%_*}
    srv=${srvkind%.*}
    srvgm=${srv%_*}.${email#*@}
    srvsmtp=${srv#*_}.${email#*@}
    kind=${srvkind#*.}
    mkportnr $kind
    # portnr
    mws="${email#*@},${srvgm},${portnr},${srvsmtp},587"
    mwn="Test Person"
    mwp="getmail/$ke"
    mwrmmails=YES mwaddr=$email ~/.local/bin/mw rm > /dev/null 2>&1
    #~/.local/bin/mw list
    mwusegetmail=1 mwtype=offline mwaddr=$email mwlogin=$email mwpass=$mwp mwserverinfo=$mws mwname=$mwn ~/.local/bin/mw add > /dev/null 2>&1
    testemail
    ~/.local/bin/mw $email > /dev/null 2>&1
    cntreceived=$(find $MAILDIR/$email/ -name '*.localhost' | wc -l)
    mwrmmails=YES mwaddr=$email ~/.local/bin/mw rm > /dev/null 2>&1
    [ $cntreceived -ge 1 ] && echo "===========> PASS " || echo "===========> FAIL"
done

