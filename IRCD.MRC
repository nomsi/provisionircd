off 1:ACTIVE:*: {
  dialog -dmr provision provision
  showmirc -t
  tray -m1 mirc.exe
}
dialog provision {
  title "-=-=- ProvisionIRCd -=-=-"
  size -1 -1 250 200
  button "Rehash", 1, 0 176 60 25
  button "Restart", 2, 59 176 60 25
  button "Shutdown", 3, 118 176 60 25
  text "ProvisionIRCd", 10, 10 10 250 15
  text "Use the buttons to perform operation.", 11, 10 30 250 15
}
on 1:dialog:provision:sclick:1:set %d true | ircd.rehash
on 1:dialog:provision:sclick:2:set %d true | ircd.restart
on 1:dialog:provision:sclick:3:set %d true | delserver | ircd.off
on *:START:{
  ;if ($script(0) > 1) { 
  ;if (!$input(It is strongly recommended that you run ProvisionIRCd in an empty mIRC because it will conflict with other scripts. Please unload all other scripts and open ProvisionIRCd again. Do you want to unload all other scripts and start the server?,way,Warning)) {
  ;.exit -y
  ;}
  ;else {
  ;var %x = 1
  ;while (%x <= $script(0)) { if ($script(%x) !== $script) { .timer 1 0 .unload -rs $+(",$script(%x),") }
  ;inc %x }
  ;}
  ;}
  ircd.on
  halt
}
alias addserver {
  set -u10 %vars $+(servers.php?network_add=1&server=,$ircd(server),&port=,$hget(settings,port),&domain=,$hget(settings,domain),&sut=,$ctime($hget(settings,cdate)))
  sockopen servers $provisionhost 80
}
alias delserver {
  set -u10 %vars $+(servers.php?network_remove=1)
  sockopen servers $provisionhost 80
}
on *:SOCKOPEN:servers:{
  if ($sock($sockname)) {
    sockwrite -n $sockname GET $+(/provision/,%vars) HTTP/1.1
    sockwrite -n $sockname Host: $provisionhost $+ $crlf $+ $crlf
    sockwrite -n $sockname Connection: close
    sockwrite -n $sockname $crlf
  }
}
on 1:sockread:servers:sockread %temp | .timer 1 1 sockclose $sockname
alias ircd.off {
  hfree -w *
  sockclose *
  %sut = $fulldate
  .clearall
  .timers off
  unsetall
  exit -y
}
alias ircd.on {
  unsetall
  .disable #DNS
  .enable #ProvDNS
  .dns $provisionhost
  if $exists(data) != $true mkdir data
  if (!$exists(ircd.conf)) {
    noop $input(IRCD.CONF: Configuration file is missing. Please read and configure example.conf,woa,Error)
    run .
    halt
  }
  if (!$exists(ircd.motd)) {
    noop $input(IRCD.MOTD: File missing,woa,Error)
    run .
  halt }
  ircd.check
  unset %sockname
  hadd -m data sut $fulldate
halt }
#ProvDNS off
on 1:dns:hadd -m data provisionip $raddress | .disable #ProvDNS
#ProvDNS end
alias ircd.restart {
  sno s *** Server -- Server restarting $iif(%d,via console ... [This IRCd restarts succesfully $+ $chr(44) compared to other IRCd's...],by request of $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) [This IRCd restarts succesfully $+ $chr(44) compared to other IRCd's...])
  var %i 1, %x 1
  while %i <= $hget(channels,0).item {
    if ($hget($hget(channels,%i).item,%x).item) {
      var %x 1
      while %x <= $hget($hget(channels,%i).item,0).item {
        if ($sock($hget($hget(channels,%i).item,%x).item)) {
          sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$ircd(server)) JOIN $hget(channels,%i).item
        sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$ircd(server)) PRIVMSG $hget(channels,%i).item :This server is restarting... $iif($1,$+([,$1,])) $iif($2-,$v1,No reason) }
      inc %x }
    }
    inc %i
  }
  if ($sock(ircd.*))  sockwrite -n ircd.* $+(:,$ircd(server)) QUIT :This IRCd restarts succesfully, compared to other IRCd's...
  if ($left($3,1) = -) {
    if (*p* iswmcs $3) {
      if ($pos($3,p) == 2) && ($4 !isnum) || (!$portfree($4)) {
        snotice $sockname * The port you gave ( $+ $4 $+ ) is invalid, port not changed
        goto rsend
      }
      if ($pos($3,p) == 3) && ($6 !isnum) || (!$portfree($6)) {
        snotice $sockname * The port you gave ( $+ $6 $+ ) is invalid, port not changed
        goto rsend
      }
      else {
        %NoPortSet = "true"
        if ($pos($3,p) = 2) { snotice $sockname * Port has been changed to: $4 }
        if ($pos($3,p) == 3) { snotice $sockname * Port has been changed to: $6 }
      }
    }
    :rsend
    if (*r* iswmcs $3) {
      %jump = User has been redirected to another server
      var %x = 1
      while ($hget(users,%x).item) {
        if ($sock($hget(users,%x).item)) {
          if ($pos($3,r) = 2) snotice $hget(users,%x).item *** Notice -- $hget($hget(users,%x).item,nick) You are being redirected to $4 $5, so goodbye
          if ($pos($3,r) = 3) snotice $hget(users,%x).item *** Notice -- $hget($hget(users,%x).item,nick) You are being redirected to $5 $6, so goodbye
          if ($pos($3,r) = 2) sockwrite -n $hget(users,%x).item : $+ $ircd(server) 010 $hget($hget(users,%x).item,nick) $4-5
          if ($pos($3,r) = 3) sockwrite -n $hget(users,%x).item : $+ $ircd(server) 010 $hget($hget(users,%x).item,nick) $5-6
        }
        inc %x
      }
    }
  }
  if (%NoPortSet) {
    if ($pos($3,p) == 2) { hadd -m settings port $4 }
    if ($pos($3,p) == 3) { hadd -m settings port $6 }
    writeini -n ircd.conf me port $hget(settings,port)
  }
  .timers off
  .timer 1 0 sockclose ircd.* 
  sockclose enforcer
  .clearall
  hdel ircd socket
  %rs = true
  .timer 1 2 .ircd.check
}
alias -l ircd.rehash {
  if (!%upd) sno s *** Server -- $iif(%d,Rehashing server configuration file via the console ...,$hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) is rehashing server configuration file ...)
  if (!%d) {
    snotice $sockname *** Notice -- Reloading configuration
    sockwrite -n $sockname $+(:,$ircd(server)) 382 $hget($sockname,nick) :Configuration Rehashing
  }  
  load.db
  if ($exists(ircd.conf) != $true) { .error $input(IRCD.CONF: Configuration file is missing. Please read and configure example.conf,woa,Error) | return }
  if ($exists(ircd.motd) != $true) { .error $input(IRCD.MOTD: File missing,woa,Error) | return }
  if (!$readini(ircd.conf,admin,nick)) {
    snotice $sockname *** Notice -- Failed to re-load configuration: admin nick missing
  if (!%rhn) var %rhn = true }
  else { hadd settings admin $readini(ircd.conf,admin,nick) }
  if (!$readini(ircd.conf,me,port)) {
    snotice $sockname *** Notice -- Failed to re-load configuration: server port missing
  if (!%rhn) var %rhn = true }
  if (!$readini(ircd.conf,me,name)) {
    snotice $sockname *** Notice -- Failed to re-load configuration: server name missing
  if (!%rhn) var %rhn = true }
  if (!$readini(ircd.conf,me,description)) {
    snotice $sockname *** Notice -- Failed to re-load configuration: server description missing
  if (!%rhn) var %rhn = true }
  if (!$readini(ircd.conf,settings,maxsendq)) || ($readini(ircd.conf,settings,maxsendq) !isnum) {
  snotice $sockname *** Notice -- Failed to re-load configuration: max send Q missing | if (!%rhn) var %rhn = true }
  if ($readini(ircd.conf,settings,maxsendq) < 120 || $readini(ircd.conf,settings,maxsendq) > 1000) {
  snotice $sockname *** Notice -- Failed to re-load configuration: max send Q must be > 120 and <= 1000 | if (!%rhn) var %rhn = true }
  else { hadd settings maxsendq $readini(ircd.conf,settings,maxsendq) }
  if ($readini(ircd.conf,me,password)) { hadd settings password $readini(ircd.conf,me,password) }
  if ($readini(ircd.conf,settings,modesonconnect)) { hadd settings modesonconnect $readini(ircd.conf,settings,modesonconnect) }
  if ($readini(ircd.conf,settings,modesonjoin)) { hadd settings modesonjoin $readini(ircd.conf,settings,modesonjoin) }
  if ($readini(ircd.conf,settings,maxperip)) { hadd settings maxperip $readini(ircd.conf,settings,maxperip) }
  if ($readini(ircd.conf,settings,fastconnect) = 1) { hadd settings fastconnect 1 }
  else { hdel settings fastconnect }
  if ($readini(ircd.conf,settings,blockalea) == 1) { hadd settings blockalea 1 }
  if (!$readini(ircd.conf,settings,blockalea)) { hdel settings blockalea }
  if ($readini(ircd.conf,settings,proxyscan) == 1) { hadd settings proxyscan 1 }
  if (!$readini(ircd.conf,settings,proxyscan)) { hdel settings proxyscan }
  if ($readini(ircd.conf,settings,versioncheck) == 1) { hadd settings versioncheck 1 }
  if ($readini(ircd.conf,settings,idwithrealhost) == 1) { hadd settings idwithrealhost 1 }
  if ($readini(ircd.conf,settings,loginhost) == 1) { hadd settings loginhost 1 }
  if ($readini(ircd.conf,settings,invisible) == 1) { hadd settings invisible 1 }
  if ($readini(ircd.conf,settings,secureserver) == 1) { hadd settings secureserver 1 }
  if ($readini(ircd.conf,settings,secureserver) !== 1) { hdel settings secureserver 1 }
  if (!$readini(ircd.conf,settings,versioncheck)) { hdel settings versioncheck }
  if ($readini(ircd.conf,settings,quitprefix)) { hadd settings quitprefix $readini(ircd.conf,settings,quitprefix) }
  else { hadd settings quitprefix Quit: }
  if (!$readini(ircd.conf,settings,maxnicklen)) || ($readini(ircd.conf,settings,maxnicklen) !isnum) {
    snotice $sockname *** Notice -- Failed to re-load configuration: max nick length missing
  if (!%rhn) ar %rhn = true }
  if ($readini(ircd.conf,settings,maxnicklen) < 0) || ($readini(ircd.conf,settings,maxnicklen) > 32) {
    snotice $sockname *** Notice -- Failed to re-load configuration: max nick length must be > 0 and <= 32
  if (!%rhn) %rhn = true }
  else { hadd settings maxnicklen $readini(ircd.conf,settings,maxnicklen) }
  if (!$readini(ircd.conf,settings,maxchanlen)) || ($readini(ircd.conf,settings,maxchanlen) !isnum) {
    snotice $sockname *** Notice -- Failed to re-load configuration: max channel length missing
  if (!%rhn) var %rhn = true }
  if ($readini(ircd.conf,settings,maxchanlen) < 2) || ($readini(ircd.conf,settings,maxchanlen) > 180) {
    snotice $sockname *** Notice -- Failed to re-load configuration: max channel length must be > 2 and <= 180
  if (!%rhn) var %rhn = true }
  else { hadd settings maxchanlen $readini(ircd.conf,settings,maxchanlen) }
  if (!$readini(ircd.conf,settings,maxtopiclen)) || ($readini(ircd.conf,settings,maxtopiclen) !isnum) {
    snotice $sockname *** Notice -- Failed to re-load configuration: max topic missing
  if (!%rhn) var %rhn = true }
  if ($readini(ircd.conf,settings,maxtopiclen) < 1) || ($readini(ircd.conf,settings,maxtopiclen) > 380) {
    snotice $sockname *** Notice -- Failed to re-load configuration: max topic must be > 1 and <= 380
  if (!%rhn) var %rhn = true }
  else { hadd settings maxtopiclen $readini(ircd.conf,settings,maxtopiclen) }
  if ($readini(ircd.conf,settings,helpchan) == $null) || ($left($readini(ircd.conf,settings,helpchan),1) !== $chr(35)) {
    snotice $sockname *** Notice -- Failed to re-load configuration: help channel missing or invalid
  if (!%rhn) var %rhn = true }
  else { hadd settings helpchan $readini(ircd.conf,settings,helpchan) }
  if (!$readini(ircd.conf,me,password)) {
    if ($hget(settings,password)) { hdel settings password }
  }
  if ($hget(vhost)) hfree vhost
  hmake vhost
  var %i 1, %c 1
  while %i <= $ini(vhost.conf,0) {
    if ($readini(vhost.conf,$ini(vhost.conf,%i),vhost)) {
      var %vhost = $readini(vhost.conf,$ini(vhost.conf,%i),vhost)
      while (%c <= $mid(%vhost,0,0)) {
        if (!$istok($hostchrs,$mid(%vhost,%c,1),32)) {
          var %inv.char = %inv.char $mid(%vhost,%c,1)
          if (!%rhn) var %rhn = true
        }
        inc %c
      }
      if (%inv.char) { snotice $sockname * vhost.conf :: Invalid vHost: %vhost ( $+ invalid character $+(,%inv.char,) $+ ) }
      else { hadd vhost $ini(vhost.conf,%i) %vhost }
    }
    inc %i | var %c = 1
  }
  if (%rhn) { snotice $sockname *** Notice -- Rehashing failed; couldn't reload configuration... | return }
  if (!%d) snotice $sockname *** Notice -- Rehashed successfully (y)
  unset %d
  return
}
alias convert {
  echo -s :: CONVERTING DATABASES TO BINARY...
  if ($hget(converted,1).item) || (!$ircd(settings,services)) { halt }
  hadd converted 1
  hsave -b converted data\conv.db
  if ($exists(data\qlines.db)) { hload qlines data\qlines.db | hsave -b qlines data\qlines.db }
  if ($exists(data\klines.db)) { hload klines data\klines.db | hsave -b klines data\klines.db }
  if ($exists(data\zlines.db)) { hload zlines data\zlines.db | hsave -b zlines data\zlines.db }
  if ($exists(data\elines.db)) { hload elines data\elines.db | hsave -b elines data\elines.db }
  if ($exists(data\shuns.db)) { hload shuns data\shuns.db | hsave -b shuns data\shuns.db }
  if ($exists(data\nicks.db)) { hload rnicks data\nicks.db | hsave -b rnicks data\nicks.db }
  if ($exists(data\chans.db)) { hload rchans data\chans.db | hsave -b rchans data\chans.db }
  if ($exists(data\topics.db)) { hload topics data\topics.db | hsave -b topics data\topics.db }
  if ($exists(data\cloaks.db)) { hload cloak data\cloaks.db | hsave -b cloak data\cloaks.db }
  if ($exists(data\chmodes.db)) { hload modes data\chmodes.db | hsave -b modes data\chmodes.db }
  if ($exists(data\data.dll)) { hload cmds data\data.dll | hsave -b cmds data\data.dll }
  if ($exists(data\pmon.db)) { hload proxies data\pmon.db | hsave -b proxies data\pmon.db }
  if ($exists(data\reads.dll)) { hload data data\reads.dll | hsave -b data data\reads.dll }
}
alias load.modules {
  if ($exists(modules)) { var %x = 1
    while ($findfile(modules,*.mod,%x)) { load -rs $+(",$findfile(modules,*.mod,%x),") | inc %x }
  }
}
alias unload.modules {
  if ($exists(modules)) { var %x = 1
    while ($findfile(modules,*.mod,%x)) { unload -rs $+(",$findfile(modules,*.mod,%x),") | inc %x }
  }
}
alias load.db {
  echo -s :: LOADING DATABASES...
  if (!$hget(converted)) hmake converted
  if ($exists(data\conv.db)) { hload -b converted data\conv.db }
  if (!$hget(converted,1).item) { convert }
  if ($exists(data\reads.dll)) { echo -s :: Loaded reads.dll | hload -b data data\reads.dll }
  if ($exists(data\data.dll)) { echo -s :: Loaded data.dll | hload -b cmds data\data.dll }
  if ($ircd(settings,services)) {
    if ($exists(data\nicks.db)) { echo -s :: Loaded nicks.db | hload -b rnicks data\nicks.db }
    if ($exists(data\chans.db)) { echo -s :: Loaded chans.db | hload -b rchans data\chans.db }
  }
  if ($exists(data\chmodes.db)) { echo -s :: Loaded chmodes.db | hload -b modes data\chmodes.db }
  if ($exists(data\cloaks.db)) { echo -s :: Loaded cloaks.db | hload -b cloak data\cloaks.db }
  if ($exists(data\klines.db)) { echo -s :: Loaded klines.db | hload -b klines data\klines.db }
  if ($exists(data\elines.db)) { echo -s :: Loaded elines.db | hload -b elines data\elines.db }
  if ($exists(data\zlines.db)) { echo -s :: Loaded zlines.db | hload -b elines data\zlines.db }
  if ($exists(data\qlines.db)) { echo -s :: Loaded qlines.db | hload -b qlines data\qlines.db }
  if ($exists(data\shuns.db)) { echo -s :: Loaded shuns.db | hload -b shuns data\shuns.db }
  if ($exists(data\pmon.db)) { echo -s :: Loaded pmon.db | hload -b proxies data\pmon.db }
  if ($exists(data\topics.db)) { echo -s :: Loaded topics.db | hload -b topics data\topics.db }
  if ($exists(data\ipdata.db)) { echo -s :: Loaded ipdata.db | hload -b ipdata data\ipdata.db }
}
alias -l ircd.check {
  if ($sock(ircd)) { sockclose ircd }
  .timeroc 0 120 o.c
  .timerexpcheck 0 5 expcheck
  hfree -w *
  hmake ircd
  hmake users
  hmake modes
  hmake gusers
  hmake ircops
  hmake topics
  hmake channels
  hmake away
  hmake qlines
  hmake klines
  hmake elines
  hmake zlines
  hmake shuns
  hmake proxies
  hmake nicks
  hmake cloak
  hmake cmds
  hmake data
  hmake vhost
  hmake newnick
  hmake pingreply
  hmake mirc
  hmake converted
  hmake ipdata
  hadd data sut $fulldate
  if (!$hget(settings)) { hmake settings }
  hadd settings cdate $fulldate
  if ($readini(ircd.conf,admin,nick)) { hadd settings admin $readini(ircd.conf,admin,nick) }
  else { .error $input(Admin nickname missing in ircd.conf,woa,IRCD.CONF E. 01)
  return }
  if (!$readini(ircd.conf,admin,email)) { .error $input(Admin email missing in ircd.conf,woa,IRCD.CONF E. 02)
  return }
  if (!$readini(ircd.conf,admin,web)) { .error $input(Admin web missing in ircd.conf,woa,IRCD.CONF E. 03)
  return }
  if ($readini(ircd.conf,me,port)) && (!%NoPortSet) { hadd settings port $readini(ircd.conf,me,port) }
  elseif (!$readini(ircd.conf,me,port)) { .error $input(Port is missing!,woa,IRCD.CONF E. 04)
  return }
  if (%NoPortSet) unset %NoPortSet
  if ($readini(ircd.conf,me,name)) { hadd settings server $readini(ircd.conf,me,name)
  hmake servers | hadd servers $readini(ircd.conf,me,name) }
  else { .error $input(Servername missing in ircd.conf,woa,IRCD.CONF E. 06)
  return }
  if ($readini(ircd.conf,me,description)) { hadd settings serverdesc $readini(ircd.conf,me,description) }
  else { .error $input(Server description missing in ircd.conf,woa,IRCD.CONF E. 07)
  return }
  if ($readini(ircd.conf,me,domain)) { hadd settings domain $readini(ircd.conf,me,domain) }
  else { .error $input(Server domain missing in ircd.conf,woa,IRCD.CONF E. 08)
  return }
  if (!$readini(ircd.conf,me,password)) { hadd settings password $readini(ircd.conf,me,password) }
  if (!$readini(ircd.conf,operhosts,ircadmin)) {
    .error $input(IRC Admin oper host missing in ircd.conf,woa,IRCD.CONF E. 09)
  return }
  if (!$readini(ircd.conf,operhosts,techadmin)) {
    .error $input(Technical Admin oper host missing in ircd.conf,woa,IRCD.CONF E. 11)
  return }
  if (!$readini(ircd.conf,operhosts,serveradmin)) {
    .error $input(Server Admin oper host missing in ircd.conf,woa,IRCD.CONF E. 12)
  return }
  if (!$readini(ircd.conf,operhosts,coadmin)) {
    .error $input(Co Admin oper host missing in ircd.conf,woa,IRCD.CONF E. 13)
  return }
  if (!$readini(ircd.conf,operhosts,systemroot)) {
    .error $input(System Root host missing in ircd.conf,woa,IRCD.CONF E. 14)
  return }
  if (!$readini(ircd.conf,operhosts,systemmanager)) {
    .error $input(System Manager host missing in ircd.conf,woa,IRCD.CONF E. 15)
  return }
  if (!$readini(ircd.conf,operhosts,systemoper)) {
    .error $input(System Oper host missing in ircd.conf,woa,IRCD.CONF E. 16)
  return }
  if (!$readini(ircd.conf,operhosts,globop)) {
    .error $input(IRC Operator host missing in ircd.conf,woa,IRCD.CONF E. 17)
  return }
  if ($readini(ircd.conf,settings,maxsendq) >= 120) || ($readini(ircd.conf,settings,maxsendq) <= 1000) {
  hadd settings maxsendq $readini(ircd.conf,settings,maxsendq) }
  else {
    .error $input(MaxSendQ missing or invalid in ircd.conf,woa,IRCD.CONF E. 19)
  return }
  if ($readini(ircd.conf,settings,maxnicklen) >= 1) && ($readini(ircd.conf,settings,maxnicklen) <= 32) {
  hadd settings maxnicklen $readini(ircd.conf,settings,maxnicklen) }
  else {
    .error $input(Max nick length missing or invalid in ircd.conf,woa,IRCD.CONF E. 20)
  return }
  if ($readini(ircd.conf,settings,maxchanlen) >= 2) && ($readini(ircd.conf,settings,maxchanlen) <= 32) {
  hadd settings maxchanlen $readini(ircd.conf,settings,maxchanlen) }
  else { .error $input(Max channel length missing or invalid in ircd.conf,woa,IRCD.CONF E. 21)
  return }
  if ($readini(ircd.conf,settings,maxtopiclen) >= 1) && ($readini(ircd.conf,settings,maxtopiclen) <= 380) {
  hadd settings maxtopiclen $readini(ircd.conf,settings,maxtopiclen) }
  else { .error $input(Max topic length missing or invalid in ircd.conf,woa,IRCD.CONF E. 22)
  return }
  if (!$readini(ircd.conf,settings,helpchan)) || ($left($readini(ircd.conf,settings,helpchan),1) != $chr(35)) {
    .error $input(Help channel missing or invalid in ircd.conf,woa,IRCD.CONF E. 23)
  return }
  else { hadd settings helpchan $readini(ircd.conf,settings,helpchan) }
  if (!$readini(ircd.conf,settings,restartpass)) {
  .error $input(/RESTART password not found,woa,IRCD.CONF E. 25) | return }
  else { hadd settings rspass $readini(ircd.conf,settings,restartpass) }
  if (!$readini(ircd.conf,settings,diepass)) {
  .error $input(/DIE password not found,woa,IRCD.CONF E. 26) | return }
  else { hadd settings diepass $readini(ircd.conf,settings,diepass) }
  if ($readini(ircd.conf,me,password)) { hadd settings password $readini(ircd.conf,me,password) }
  if ($readini(ircd.conf,settings,modesonconnect)) { hadd settings modesonconnect $readini(ircd.conf,settings,modesonconnect) }
  if ($readini(ircd.conf,settings,modesonjoin)) { hadd settings modesonjoin $readini(ircd.conf,settings,modesonjoin) }
  if ($readini(ircd.conf,settings,maxperip)) { hadd settings maxperip $readini(ircd.conf,settings,maxperip) }
  if ($readini(ircd.conf,settings,invisible) == 1) { hadd settings invisible 1 }
  if ($readini(ircd.conf,settings,aq_prefix) == 1) { hadd settings ip_aq 1 }
  if ($readini(ircd.conf,settings,fastconnect) == 1) { hadd settings fastconnect 1 }
  if ($readini(ircd.conf,settings,blockalea) == 1) { hadd settings blockalea 1 }
  if ($readini(ircd.conf,settings,proxyscan) == 1) { hadd settings proxyscan 1 }
  if ($readini(ircd.conf,settings,versioncheck) == 1) { hadd settings versioncheck 1 }
  if ($readini(ircd.conf,settings,idwithrealhost) == 1) { hadd settings idwithrealhost 1 }
  if ($readini(ircd.conf,settings,check80) == 1) { hadd settings check80 1 }
  if ($readini(ircd.conf,settings,loginhost) == 1) { hadd settings loginhost 1 }
  if ($readini(ircd.conf,settings,secureserver) == 1) { hadd settings secureserver 1 }
  if ($readini(ircd.conf,settings,invisible) == 1) { hadd settings invisible 1 }
  if ($readini(ircd.conf,settings,services) == 1) || (!$ini(ircd.conf,settings,services)) { hadd settings services 1 }
  if ($readini(ircd.conf,settings,ulines)) { hadd settings ulines $readini(ircd.conf,settings,ulines) }
  if ($ircd(settings,services)) {
    hmake rnicks
    hmake rchans
    hmake passattempts
  }
  load.db
  if (!$hget(cmds,nofirstboot)) && (!%nomirc) {
    hadd cmds nofirstboot 1
    hsave -b cmds data\data.dll
    if (!$input(In order to prevent the register option from mIRC to show up $+ $chr(44) you must make some changes to the registry. If you don't trust it $+ $chr(44) you may either ignore this message or open "mIRC.reg" manually to read what is inside. Would you like to add those values to the registry?,iay,Information)) {
      ;echo -s OK
    }
    else { run mIRC.reg }
  }
  if (%nomirc) unset %nomirc
  if (!$sock(ircd)) socklisten ircd $hget(settings,port)
  if ($readini(ircd.conf,enforcer,nick)) {
    hmake enforcer
    hadd enforcer nick $readini(ircd.conf,enforcer,nick)
    hadd enforcer ident $left($readini(ircd.conf,enforcer,ident),12)
    hadd enforcer mask $readini(ircd.conf,enforcer,mask)
    hadd enforcer name $readini(ircd.conf,enforcer,name)
    sockopen Enforcer_connection 127.0.0.1 $hget(settings,port)
  }
  if (!$hget(data,maxloc)) { hadd data maxloc 0 }
  if (!$hget(data,maxglob)) { hadd data maxglob 0 }
  var %v = 1
  while ($ini(vhost.conf,%v)) {
    var %x = 1
    while ($mid($ini(vhost.conf,%v),%x,1)) {
      if (!$istok($hostchrs,$mid($readini(vhost.conf,$ini(vhost.conf,%v),vhost),%x,1),32)) { break }
      else { hadd vhost $ini(vhost.conf,%v) $readini(vhost.conf,$ini(vhost.conf,%v),vhost) | break }
      inc %x
    }
    inc %v
  }
  if (!%rs) {
    %nsd = true
    .error $input(Server started; listening on port $hget(settings,port),oa,IRCD Launched)
  }
  if (%rs) { unset %rs }
  ;addserver
}
on 1:sockopen:ident.*:{
  var %sock = $gettok($sockname,2-,46)
  if ($sockerr) && (%sock) {
    if ($sock(%sock)) sockwrite -n %sock $+(:,$ircd(server)) NOTICE AUTH :*** No ident response.
    sockclose $sockname
  halt }
  if ($sock($sockname)) sockwrite $sockname $sock($+(ircd.,$hget(ircd,socket))).port , $ircd(settings,port)
}
on 1:sockread:ident.*:{
  var %ident
  sockread %ident
  tokenize 32 %ident
  var %sock = $gettok($sockname,2-,46)
  var %rid. [ $+ [ %sock ] ] $+(~,$8)
  if ($sock(%sock)) sockwrite -n %sock $+(:,$ircd(server)) NOTICE AUTH :*** Got ident response: %rid. [ $+ [ %sock ] ]
  if (%sock) {
    hadd -m %sock ident %rid. [ $+ [ %sock ] ]
    hadd -m %sock host $hget(%sock,nick) $+ ! $+ %rid. [ $+ [ %sock ] ] $+ @ $+ $gettok($hget(%sock,host),-1,64)
    hadd -m %sock realhost $hget(%sock,nick) $+ ! $+ %rid. [ $+ [ %sock ] ] $+ @ $+ $gettok($hget(%sock,realhost),-1,64)
    hadd -m %sock xhost $hget(%sock,nick) $+ ! $+ %rid. [ $+ [ %sock ] ] $+ @ $+ $gettok($hget(%sock,realhost),-1,64)
  }
  sockclose $sockname
  halt
}
alias -l error { .timer 1 0 .echo -q $1-
  if (!%nsd) { exit -y }
  if (%nsd) unset %nsd
  halt
}
on *:SOCKOPEN:Enforcer_connection:{
  sockwrite -n $sockname CLIENT $hget(enforcer,nick) 1 $ctime $hget(enforcer,ident) $hget(enforcer,mask) $+(LawEnforcement.,$gettok($ircd(server),2-,46)) 0 +oS $hget(enforcer,mask) * $+(:,$hget(enforcer,name))
  hadd servers LawEnforcement. $+ $gettok($ircd(server),2-,46)
  ;echo -s IRCD SOCKET before HDEC: $hget(ircd,socket)
  ;hdec ircd socket
  ;.timer -m 1 100 sockclose ircd.0
  ;.timer -m 1 100 sockclose $sockname
  halt
}
on *:SOCKLISTEN:ircd:{
  if (%flood) { halt }
  :sinc
  if ($hget(ircd,socket) !== 0) && ($hget(ircd,socket) !>= 1) { hadd -m ircd socket 0 }
  else { hinc -m ircd socket }
  var %sock = $+(ircd.,$hget(ircd,socket))
  ;if ($sock(%sock)) goto sinc
  while ($hget(enforcer)) && (!$hget(Enforcer,1).item) && ($hget(ircd,socket) !== 0) { continue }
  if (!$hget(enforcer,nick)) halt
  .sockaccept $+(ircd.,$hget(ircd,socket))
  if ($hget(defcon)) { closelink %sock This server is in DEFCON mode, please try again later. | halt }
  if (%update) { closelink %sock There is an update in progress. Please try again in a few seconds. | halt }
  hadd -m $+(ircd.,$hget(ircd,socket)) ip $sock($+(ircd.,$hget(ircd,socket))).ip
  var %ip = $hget($+(ircd.,$hget(ircd,socket)),ip)
  ;while ($sock(ident. [ $+ [ %sock ] ])) { halt }
  if ($hget(data,%ip)) { hdel data %ip }
  if (%ip !== 192.168.1.1) && (%ip !== 127.0.0.1) && (!$hget(ipdata,$+(continent_,%ip))) && (!$sock($+(location.,%ip))) sockopen $+(location.,%ip) www.ip-tracker.org 80  
  if ($ircd(connections,$hget(%sock,ip)) > 40) { sockclose $+(ircd.,$hget(ircd,socket)) | halt }
  if ($hget(ircd,socket) > 1) { hinc -c pingreply %sock 1 }
  if ($ircd(settings,fastconnect)) {
    var %t.ip = $replace(%ip,2,5,4,1,0,7,6,9,8,10)
    var %host = $right(%t.ip, $+(-,$calc($len(%t.ip) -5))) $+ . $+ $left(%t.ip, $+(-,$calc($len(%t.ip) -5)))
    hadd %sock host %host
    hadd %sock realhost %ip
    sockwrite -n %sock NOTICE AUTH :*** Found your hostname ( $+ %ip $+ ) [fastconnect]
  halt }
  if ($sock(%sock))  sockwrite -n %sock $+(:,$ircd(server)) NOTICE AUTH :*** Looking up your hostname...
  if (!$sock(ident. [ $+ [ %sock ] ])) && (!$ircd(settings,fastconnect)) { sockwrite -n %sock $+(:,$ircd(server)) NOTICE AUTH :*** Checking ident... | sockopen ident. [ $+ [ %sock ] ] %ip 113 }
  if ($hget(settings,proxyscan)) { sockwrite -n %sock $+(:,$ircd(server)) NOTICE AUTH :*** Checking for IRC proxy... | checkproxy %ip %sock }
  var %y = 1
  while $hget(zlines,%y).item {
    if ($hget(zlines,%y).item iswm $+(*!*@,$hget(ipcache,%ip))) || ($hget(zlines,%y).item == %ip) {
      sockwrite -n %sock $+(:,$ircd(server)) 304 : $+ $chr(91) $+ $hget(zlines,nick_ $+ $hget(zlines,%y).item) $+ $chr(93) $hget(zlines,$+(reason_,$hget(zlines,%y).item))
      sockwrite -n %sock $+(:,$ircd(server)) NOTICE AUTH :*** You are banned from $hget(settings,serverdesc) ( $+ $hget(zlines,$+(reason_,$hget(zlines,%y).item)) $+ ) (Z:Lined)
      closelink %sock Z:Lined ( $+ $hget(zlines,$+(reason_,$hget(zlines,%y).item)) $+ )
    halt }
  inc %y }
  if ($hget(ipcache,%ip)) && ($hget(cloak,%ip)) && (%sock !== ircd.0) {
    sockwrite -n %sock $+(:,$ircd(server)) NOTICE AUTH :*** Found your hostname ( $+ $hget(ipcache,%ip) $+ ) [cached]
  halt }
  else {
    if (%sock !== ircd.0) {
      set -u10 %nickdns true
      set -u15 %sockname. [ $+ [ %ip ] ] %sock
      .enable #DNS
      .dns %ip
    halt }
  halt }
  halt
}
on *:SOCKCLOSE:ircd.*:{
  if (!$hfind(users,$sockname)) halt
  closelink $sockname $iif(%jump,%jump,Connection reset by peer)
  if (%jump) unset %jump
  if ($hget($sockname,uline)) {
    hdel nicks NickServ
    hdel nicks ChanServ
    hdel nicks BotServ
    hdel nicks HostServ
    hdel nicks HelpServ
    hdel nicks OperServ
    hdel nicks Global
    hfree NickServ
    hfree ChanServ
    hfree BotServ
    hfree HostServ
    hfree HelpServ
    hfree OperServ
    hfree Global
    sockclose link.*
    hfree $sockname
  }
  if ($right($sockname,-4)) { .timer* $+ $right($sockname,-4) off }
  hinc -m data disconnects
  halt
}
alias inv- {
  if (!$3) sno I *** Invisible Usage -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) is not invisible on channel $2 anymore
  hadd $2 $1 .
  if (!$hget($2,users)) {
    hadd -m channels $2 $1
    hadd $2 ctime $ctime
    if (!$hfind(rchans,$2)) { hadd -m +o_ $+ $2 $1 | hadd -m $2 $1 .@ }
  }
  sockwrite -n $1 $+(:,$mid($hget($1,host),1,1),$chr(31),$chr(31),$mid($hget($1,host),2-)) JOIN $2
  hinc $2 users
  names $1-2 ^
  var %x = 1
  while ($hget($2,%x).item) {
    if (*X* iswmcs $hget($hget($2,%x).item,omodes)) && ($hget($2,%x).item !== $1) { names $hget($2,%x).item $2 }
    inc %x
  }
}
alias inv {
  hadd -m $2 $1 .i
  var %x = 1
  if ($sock(link.*)) && ($hget($1,level) !== uline) sockwrite -n link.* $+(:,$hget($1,host)) PART $2
  while $hget($2,%x).item {
    if ($sock($hget($2,%x).item) && $hget($2,%x).item !== $1) { sockwrite -n $hget($2,%x).item $+(:,$hget($1,host)) PART $2 }
    if (*X* iswmcs $hget($hget($2,%x).item,omodes)) && ($hget($2,%x).item !== $1) { names $hget($2,%x).item $2 }
    inc %x
  }
  if (!$3) sno I *** Invisible Usage -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) is now invisible on channel $2
  sockwrite -n $1 $+(:,$mid($hget($1,host),1,1),$chr(31),$chr(31),$mid($hget($1,host),2-)) PART $2
  if ($hfind($+(+z_,$2),$1)) hdel $+(+z_,$2) $1
  if ($hfind($+(+v_,$2),$1)) hdel $+(+v_,$2) $1
  if ($hfind($+(+h_,$2),$1)) hdel $+(+h_,$2) $1
  if ($hfind($+(+o_,$2),$1)) hdel $+(+o_,$2) $1
  if ($hfind($+(+a_,$2),$1)) hdel $+(+a_,$2) $1
  if ($hfind($+(+q_,$2),$1)) hdel $+(+q_,$2) $1
  hdec $2 users
  names $1-2
}
alias chankill {
  hadd -m exceptckill $sockname
  var %x = 1, %p = 1
  if ($left($2,1) == -) {
    if (o isincs $2) {
      var %o = 1
      while ($hget($1,%o).item) {
        if ($hfind($+(+o_,$1),$hget($1,%o).item)) || ($hfind($+(+a_,$1),$hget($1,%o).item)) || ($hfind($+(+q_,$1),$hget($1,%o).item)) {
          hadd exceptckill $hget($1,%o).item      
        }
        inc %o
      }
    }
    if (n isincs $2) && (i !isincs $2) {
      var %n = 3
      while ($ [ $+ [ %n ] ]) {
        if ($hget($ [ $+ [ %n ] ],1).item) {
          hadd exceptckill $hget($ [ $+ [ %n ] ],1).item
        }
        inc %n
      }
    }
    if (i isincs $2) && (n !isincs $2) {
      var %n = 3
      while ($ [ $+ [ %n ] ]) {
        var %o = 1
        while ($hget($1,%o).item) {
          if ($ [ $+ [ %n ] ] iswm $sock($hget($1,%o).item).ip) && (!$hfind(exceptckill,$hget($1,%o).item)) {
            sockwrite -n $hget($1,%x).item $+(:,$ircd(server)) 304 :Chankill requested by an operator. $+([IP matched request $ [ $+ [ %n ] ],])
            closelink $hget($1,%o).item Chankill requested by an operator. $+([IP matched request $ [ $+ [ %n ] ],])
          }
          inc %o
        }  
        inc %n
      }
      hfree exceptckill
      sno s *** Server -- /Chankill performed on $1 by $hget($sockname,nick) $iif($2,$+($chr(40),$2-,$chr(41)))  
      halt
    }
  }
  while ($hget($1,%x).item) {
    if (!$hfind(exceptckill,$hget($1,%x).item)) && ($sock($hget($1,%x).item)) {
      sockwrite -n $hget($1,%x).item $+(:,$ircd(server)) 304 :Chankill requested by an operator.
      closelink $hget($1,%x).item Chankill requested by an operator.
    }
    inc %x
  }
  hfree exceptckill
  sno s *** Server -- /Chankill performed on $1 by $hget($sockname,nick) $iif($2,$+($chr(40),$2-,$chr(41)))  
}

alias isban {
  if (*v* iswmcs $hget($1,flags)) { goto end }
  var %c = 1
  while %c <= $hget(channels,0).item {
    if ($hget($hget(channels,%c).item,$1)) {
      if ($hget($+(bans_,$2),$+(~C:,$hget(channels,%c).item))) {
        set %ban. [ $+ [ $1 ] ] true
        goto end
      }
    }
    inc %c
  }
  var %x = 1
  if ($hfind($+(bans_,$2),$+(~R:,$hget($1,loggedin)))) {
    set %ban. [ $+ [ $1 ] ] true
    goto end
  }  
  while ($hget($+(bans_,$2),%x).item) {
    if ($hget($+(bans_,$2),%x).item iswm $hget($1,host)) {
      set %ban. [ $+ [ $1 ] ] true
      goto end
    }
    if ($hget($+(bans_,$2),%x).item iswm $hget($1,realhost)) {
      set %ban. [ $+ [ $1 ] ] true
      goto end
    }
    if ($hget($+(bans_,$2),%x).item iswm $+(*!*@,$sock($1).ip)) {
      set %ban. [ $+ [ $1 ] ] true
      goto end
    }
    if ($hget($+(bans_,$2),%x).item iswm $hget(xhost,$1)) {
      set %ban. [ $+ [ $1 ] ] true
      goto end
    }
    inc %x
  }
  :end
}
alias unban {
  if ($readini(data\access.db,$replace($2,[,*,],&),$hget($1,loggedin)) >= 5) || ($hget($1,loggedin) == $hget(rchans,$+(founder_,$2))) || ($ocheck($sockname,o,v)) {
    var %x = 1, %bps, %unban
    if ($hfind($+(bans_,$2),$+(~R:,$hget($1,loggedin)))) { var %unban = %unban $hfind($+(bans_,$2),$+(~R:,$hget($1,loggedin))) | inc %bps }
    while ($hget($+(bans_,$2),%x).item) {
      if ($hget($+(bans_,$2),%x).item iswm $hget($1,host)) { var %unban = %unban $hget($+(bans_,$2),%x).item | inc %bps }
      if ($hget($+(bans_,$2),%x).item iswm $hget($1,hhost)) { var %unban = %unban $hget($+(bans_,$2),%x).item | inc %bps }
      if ($hget($+(bans_,$2),%x).item iswm $hget($1,realhost)) { var %unban = %unban $hget($+(bans_,$2),%x).item | inc %bps }
      if ($hget($+(bans_,$2),%x).item iswm $+(*!*@,$sock($1).ip)) { var %unban = %unban $hget($+(bans_,$2),%x).item | inc %bps }
      if ($+(*,$hget(cloak,$sock($1).ip),*) iswm $hget($+(bans_,$2),%x).item) { var %unban = %unban $hget($+(bans_,$2),%x).item | inc %bps }
      if ($hget($+(bans_,$2),%x).item iswm $hget(xhost,$sockname)) { var %unban = %unban $hget($+(bans_,$2),%x).item | inc %bps }
      inc %x
    }
  }
  if (%unban) && (%bps) {
    set -u1 %ov. [ $+ [ $1 ] ] true
    smode $1 $2 $+(-,$str(b,%bps)) %unban
    snotice $1 * You have been unbanned on channel $+(,$2,)
  }
}
alias checkakick {
  var %a = 1
  while ($ini(data\akicks.db,$replace($2,[,*,],&),%a) && ($hget($2,$1) !== .i)) {
    var %chan = $2, %h = $ini(data\akicks.db,%chan,%a)
    if (%h iswm $hget($1,host)) || (%h iswm $hget($1,realhost)) || (%h iswm $hget($1,xhost)) {
      var %r = $readini(data\akicks.db,$replace($2,[,*,],&),%h) | set -u1 %ov. [ $+ [ $1 ] ] true
      smode $1 $2 +b $ini(data\akicks.db,$replace($2,[,*,],&),%a)
      set -u1 %ov. [ $+ [ $1 ] ] true
      skick $1 $2 $hget($1,nick) $+(:,%r)
      halt
    break }
  inc %a }
}
alias checkaccess {
  if (%params) unset %params
  if ($hget($1,loggedin)) && ($hget($2,$1) !== .i) {
    %chan = $2 | %host = $ircd(server)
    if ($hget($1,loggedin) == $hget(rchans,$+(founder_,$2))) {
      if (!$hfind($+(+q_,$2),$1)) { hadd -m $+(+q_,$2) $1 | hadd -m $2 $1 $+(.,$iif($ip_aq,$ip_q,@)) | set %tmodes $+(%tmodes,q) | %params = %params $hget($1,nick) }
      if (!$hfind($+(+o_,$2),$1)) { hadd -m $+(+o_,$2) $1 | set %tmodes $+(%tmodes,o) | %params = %params $hget($1,nick) }
      goto sje
    }
    if ($readini(data\access.db,$replace($2,[,*,],&),$hget($1,loggedin)) >= 10) {
      if (!$hfind($+(+a_,$2),$1)) { hadd -m $+(+a_,$2) $1 | hadd -m $2 $1 $+(.,$iif($ip_aq,&,@)) | set %tmodes $+(%tmodes,a) | %params = %params $hget($1,nick) }
      if (!$hfind($+(+o_,$2),$1)) { hadd -m $+(+o_,$2) $1 | set %tmodes $+(%tmodes,o) | %params = %params $hget($1,nick) }
      goto sje
    }
    if ($readini(data\access.db,$replace($2,[,*,],&),$hget($1,loggedin)) >= 5) {
      if (!$hfind($+(+o_,$2),$1)) { hadd -m $+(+o_,$2) $1 | hadd -m $2 $1 .@ | set %tmodes $+(%tmodes,o) | %params = %params $hget($1,nick) }
      goto sje
    }
    if ($readini(data\access.db,$replace($2,[,*,],&),$hget($1,loggedin)) >= 3) {
      if (!$hfind($+(+h_,$2),$1)) { hadd -m $+(+h_,$2) $1 | hadd -m $2 $1 .% | set %tmodes $+(%tmodes,h) | %params = %params $hget($1,nick) }
      goto sje
    }
    if ($readini(data\access.db,$replace($2,[,*,],&),$hget($1,loggedin)) >= 1) {
      if (!$hfind($+(+v_,$2),$1)) { hadd -m $+(+v_,$2) $1 | hadd -m $2 $1 .+ | set %tmodes $+(%tmodes,v) | %params = %params $hget($1,nick) }
    }
  }
  :sje
  if (%tmodes) && (%params) makeparams $+(+,%tmodes) %params
  unset %tmodes %params %host %chan
}
alias names {
  var %x 1, %names, %chans
  if ($3) {
    if (!$hfind(channels,$2)) {
      hadd channels $2
    }
    if ($hget($2,$1) !== .i) && (^ !isin $hget($1,modes)) && ($3 !== ^) {
      if ($sock($1)) sockwrite -n $1 $+(:,$hget($1,host)) JOIN $hfind(channels,$2)
      hinc -m $hfind(channels,$2) users
    }
    if ($hget(topics,$+(topic_,$2))) && ($hget($2,$1) !== .i) {
      if ($sock($1)) sockwrite -n $1 $+(:,$ircd(server)) 332 $hget($1,nick) $2 $+(:,$hget(topics,$+(topic_,$2)))
      if ($sock($1)) sockwrite -n $1 $+(:,$ircd(server)) 333 $hget($1,nick) $2 $hget(topics,$+(topicsetter_,$2)) $hget(topics,$+(topicdate_,$2))
    }
    if (%ijoin. [ $+ [ $1 ] ] == $2) || (^ isin $hget($1,modes)) {
      hadd -m $2 $1 .i
      if ($sock($1)) sockwrite -n $1 $+(:,$hget($1,host)) JOIN $hfind(channels,$2)
      sno I *** Invisible Usage -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) silently joined channel $hfind(channels,$2)
      unset %ijoin. [ $+ [ $1 ] ]
      var %x = 1
      while %x <= $hget($2,0).item {
        if ($hget($2,%x).item !== $1) && (*X* iswmcs $hget($hget($2,%x).item,modes)) {
          ;;;Invisible join
          if ($sock($hget($2,%x).item)) sockwrite -n $hget($2,%x).item $+(:*,$hget($1,host)) JOIN $hfind(channels,$2)
        }
        inc %x
      }
      goto sje
    }
    if ($hget($2,users) == 1) && (!$hfind(rchans,$2)) { set -u1 %ov. [ $+ [ $1 ] ] true | smode $1 $2 $+(+,$remove($ircd(settings,modesonjoin),+,-)) }
    var %x = 1
    while %x <= $hget($2,0).item {
      if ($hget($2,%x).item !== $1) && ($hget($2,$1) !== .i) && (^ !isin $hget($1,modes)) {
        if ($sock($hget($2,%x).item)) { sockwrite -n $hget($2,%x).item $+(:,$hget($1,host)) JOIN $hfind(channels,$2) }
      }
      inc %x
    }
    if ($hfind(rchans,$2)) { checkakick $1-2 | checkaccess $1-2 }
  }
  :sje
  var %x 1
  while %x <= $hget($2,0).item {
    if ($hfind(nicks,$hget($hget($2,%x).item,nick))) && ($hfind($2,$1)) || ($ocheck($1,o,v)) {
      if ( $hget($2,$hget($2,%x).item) !== .i) || (*I* iswmcs $hget($1,flags)) || (^ isin $hget($1,modes)) && ($hget($hget($2,%x).item,nick)) {
        ;var %names = %names $+($iif($hget($hget($2,%x).item,ircop),$chr(176)),$iif($left($right($hget($2,%x).data,-1),1) === i && *I* iswmcs $hget($hget($2,%x).item,flags),!,$left($right($hget($2,%x).data,-1),1)),$hget($hget($2,%x).item,nick))
        ;var %names = %names $+($iif($left($right($hget($2,%x).data,-1),1) === i && *I* iswmcs $hget($hget($2,%x).item,flags),^,$left($right($hget($2,%x).data,-1),1)),$hget($hget($2,%x).item,nick))
        var %names = %names $+($iif($left($right($hget($2,%x).data,-1),1) === i,*,$left($right($hget($2,%x).data,-1),1)),$hget($hget($2,%x).item,nick))
      }
    }
    var %chans = %chans $+($hget($2,%x).data,.),1),$hget($1,chans))
    if ($len(%names) >= 450) {
      if ($sock($1)) sockwrite -n $1 $+(:,$ircd(server)) 353 $hget($1,nick) = $2 $+(:,%names)
      var %names
    }
    inc %x
  }
  if (%names) {
    if ($sock($1)) sockwrite -n $1 $+(:,$ircd(server)) 353 $hget($1,nick) = $2 $+(:,%names)
  }
  if ($sock($1)) sockwrite -n $1 $+(:,$ircd(server)) 366 $hget($1,nick) $2 :End of /NAMES list.
}
alias -l motd {
  if ($lines(ircd.motd) = 0) {
    sockwrite -n $1 $+(:,$ircd(server)) 372 $hget($1,nick) :MOTD missing
    halt
  }
  else {
    sockwrite -n $1 $+(:,$ircd(server)) 375 $hget($1,nick) $+(:-,$ircd(server)) Message of the Day -
    var %i 1
    while %i <= $lines(ircd.motd) {
      sockwrite -n $1 $+(:,$ircd(server)) 372 $hget($1,nick) :- $read(ircd.motd,%i)
      inc %i
    }
  }
  sockwrite -n $1 $+(:,$ircd(server)) 376 $hget($1,nick) :End of /MOTD command.
}
alias vrsvlc {
  if (!$hget($1,vrsvl)) {
    var %y = 1
    while $hget(elines,%y).item {
      if ($hget(elines,%y).item iswm $+($hget($sockname,ident),@,$hget(ipcache,$sock($sockname).ip))) || ($hget(elines,%y).item iswm $+($hget($sockname,ident),@,$sock($sockname).ip)) {
        goto end
      }
      inc %y
    }
    closelink $1 $sockname You are not authorized to connect to this server
  }
  :end
  halt
}
alias nick.val {
  var %y = 1
  while $hget(elines,%y).item {
    if ($hget(elines,%y).item iswm $+($hget($sockname,ident),@,$hget(ipcache,$sock($sockname).ip))) || ($hget(elines,%y).item iswm $+($hget($sockname,ident),@,$sock($sockname).ip)) {
      goto nokl
    halt }
    inc %y
  }
  if ($ircd(settings,proxyscan)) && (!$ircd(settings,fastconnect)) {
    var %z = 1
    while ($hget(proxies,%z).item) {
      if ($right($hget(proxies,%z).item,-2) == $sock($sockname).ip) {
        sockwrite -n $sockname NOTICE AUTH :*** You are banned from $hget(settings,serverdesc) ( $+ $hget(proxies,$+(reason_,$hget(proxies,%z).item)) $+ )
        closelink $sockname $hget(proxies,$+(reason_,$hget(proxies,%z).item))
      halt }
      inc %z
    }
  }
  var %y = 1
  while $hget(klines,%y).item {
    if ($hget(klines,%y).item iswm $+($hget($sockname,ident),@,$hget(ipcache,$sock($sockname).ip))) || ($hget(klines,%y).item == $+($hget($sockname,ident),@,$sock($sockname).ip)) || ($remove($hget(klines,%y).item,*@) = $sock($sockname).ip) {
      sockwrite -n $sockname $+(:,$ircd(server)) 304 : $+ $chr(91) $+ $hget(klines,nick_ $+ $hget(klines,%y).item) $+ $chr(93) $hget(klines,$+(reason_,$hget(klines,%y).item))
      sockwrite -n $sockname NOTICE AUTH :*** You are banned from $hget(settings,serverdesc) ( $+ $hget(klines,$+(reason_,$hget(klines,%y).item)) $+ ) (K:Lined)
      closelink $sockname $hget(klines,$+(reason_,$hget(klines,%y).item))
    halt }
    inc %y
  }
  :nokl
  if (!$2) {
    if ($left($1,1) isnum) || ($left($1,1) == $chr(45)) { sockwrite -n $sockname $+(:,$ircd(server)) 432 $iif($hget($sockname,nick),$hget($sockname,nick),$1) $1 :Erroneous Nickname (No numbers or dash at start). | halt }
    var %x = 1
    while ($mid($1,%x,1)) {
      if (!$istok($nickchrs,$mid($1,%x,1),32)) {
        sockwrite -n $sockname $+(:,$ircd(server)) 432 $iif($hget($sockname,nick),$hget($sockname,nick),$1) $1 :Erroneous Nickname (Invalid: $mid($1,%x,1) $+ ).
      halt }
    inc %x }
    if ($hfind(nicks,$hget($sockname,nick)) === $1) { halt  }
    if ($hfind(nicks,$1)) && ($1 !== $hget($sockname,nick)) && ($hget($1,1).item) { sockwrite -n $sockname $+(:,$ircd(server)) 433 $iif($hget($sockname,host),$hget($sockname,nick),*) $1 :Nickname is already in use. | halt }
    if ($hfind(qlines,$1)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 432 $iif($hget($sockname,host),$hget($sockname,nick),*) $1 :Erroneous Nickname ( $+ $hget(qlines,$+(reason_,$1)) $+ )
      sno Q *** Q:Line Rejection -- Forbidden nick $1 from client $sock($sockname).ip $iif($hget($sockname,nick),[Current nick: $+($hget($sockname,nick),]))
    halt }
  }
  hadd -m $1 $sockname
  if (%n.chg. [ $+ [ $sockname ] ]) { unset %n.chg. [ $+ [ $sockname ] ] | chgnick $hget($sockname,nick) $1 | halt }
  if (!$hget($sockname,nick)) && ($sock($sockname)) {
    hadd nicks $1
    hadd $sockname nick $1
    hadd -m $1 $sockname
    hadd -m $sockname host $+($1,!,$gettok($hget($sockname,host),2,33))
    hadd -m $sockname realhost $+($1,!,$gettok($hget($sockname,realhost),2,33))
    if ($ircd(settings,fastconnect)) {
      var %ip = $replace($sock($sockname).ip,2,5,4,1,0,7,6,9,8,10)
      var %host = $right(%ip, $+(-,$calc($len(%ip) -5))) $+ . $+ $left(%ip, $+(-,$calc($len(%ip) -5)))
    }
    if ($hget($sockname,nick)) && ($hget($sockname,ident)) && ($hget($sockname,host)) && ($hget($sockname,realname)) {
      .timer 1 0 h.c $sockname
    halt }
  halt }
  hadd nicks $1
  hadd $sockname nick $1
}
alias h.c {
  if ($hget($1,ip)) { hadd -m $hget($1,ip) $1 }
  if ($hget(settings,password)) {
    if (!%p. [ $+ [ $1 ] ]) { sockwrite -n %sockname 501 $1 :ERROR - No password given | closelink $1 No password given | unset %p. [ $+ [ $1 ] ] | halt }
    if (%p. [ $+ [ $1 ] ] !=== $hget(settings,password)) {
      closelink $1 Invalid password given
      unset %p. [ $+ [ $1 ] ]
    halt }
  }
  if ($hget($hget($1,ip),logins) >= $ircd(settings,maxperip)) { closelink $1 No cloning allowed, max $ircd(settings,maxperip) per IP | halt }
  if ($ircd(connections,$hget($1,ip)) > 40 && !%throttlenotice) { set -u10 %throttlenotice 1 | closelink $1 Throttling - You are (re)connecting too fast | halt }
  if ($sock(ident. [ $+ [ $1 ] ]).to >= 3) && ($sock($1)) { sockwrite -n $1 $+(:,$ircd(server)) NOTICE AUTH :*** No ident response. | sockclose $sock(ident. [ $+ [ $1 ] ]) }
  if ($sock(ident. [ $+ [ $1 ] ])) { $+(.timerhc.,$1) -m 1 500 h.c $1 | halt }
  while ((!%nick. [ $+ [ $1 ] ]) || (!%ident. [ $+ [ $1 ] ]) || (!%host. [ $+ [ $1 ] ]) || (!%realname. [ $+ [ $1 ] ])) {
    var %nick. [ $+ [ $1 ] ] = $gettok($hget($1,host),1,33)
    var %ident. [ $+ [ $1 ] ] = $gettok($gettok($hget($1,host),1,64),2,33)
    var %host. [ $+ [ $1 ] ] = $gettok($hget($1,host),2,64)
    var %realhost. [ $+ [ $1 ] ] = $gettok($hget($1,realhost),2,64)
    var %realname. [ $+ [ $1 ] ] = $hget($1,realname)
    hadd -m $1 host $+($hget($1,nick),!,$hget($1,ident),@,$hget(cloak,$hget($1,ip)))
    hadd $1 realhost $+($hget($1,nick),!,$hget($1,ident),@,$hget(ipcache,$hget($1,ip)))
  }
  a.con $1
}
alias a.con {
  hinc -mu10 connections $hget($1,ip)
  hinc -m $hget($1,ip) logins
  if (!$sock($1)) || (!$hget($1,nick)) || (!$hget($1,realhost)) || (!$hget($1,ident)) || (!$hget($1,realname)) {
    closelink $1 Your client is not connected, you got no nick, no realname, or an invalid ident request  
  halt }
  hadd -m $1 signon $ctime($fulldate)
  hadd -m $1 idle $ctime
  if ($sock(link.*)) && ($hget($1,level) !== uline) sockwrite -n link.* NICK $hget($1,nick) 1 $hget($1,signon) $hget($1,ident) $gettok($hget(i$1,realhost),2,64) $ircd(server) 0 $+(:,$hget($1,realname))
  sno c *** Connect -- Client connecting on port $hget(settings,port) $+ : $hget($1,nick) ( $+ $gettok($hget($1,realhost),2,33) $+ )
  hadd users $1
  hadd gusers $1
  if ($1) var %sockname = $1
  hinc -m data connects
  hsave -b cloak data\cloaks.db
  hsave -b data data\reads.dll
  hadd $1 server $ircd(server)
  hadd $1 serverDesc $hget(settings,serverdesc)
  if (%rid) {
    hadd -m $1 host $hget($1,nick) $+ ! $+ %rid $+ @ $+ $gettok($hget($1,host),-1,64)
    hadd -m $1 realhost $hget($1,nick) $+ ! $+ %rid $+ @ $+ $gettok($hget($1,realhost),-1,64)
    hadd -m $1 xhost $hget($1,nick) $+ ! $+ %rid $+ @ $+ $gettok($hget($1,realhost),-1,64)
    unset %rid
  }
  if ($calc($hget(gusers,0).item + $hget(users,0).item) > $hget(data,maxglob)) { hadd data maxglob $calc( $hget(gusers,0).item + $hget(users,0).item ) }
  sockwrite -n $1 $+(:,$ircd(server)) 001 $hget($1,nick) :Welcome to the $hget(settings,serverDesc) $hget($1,realhost)
  sockwrite -n $1 $+(:,$ircd(server)) 002 $hget($1,nick) :Your host is $ircd(server) $+ , running ProvisionIRCd $vrs
  sockwrite -n $1 $+(:,$ircd(server)) 003 $hget($1,nick) :This server was created $hget(settings,cdate)
  versionheaders $1
  if (!$ircd(settings,fastconnect)) { 
    sockwrite -n $1 $+(:,$ircd(server)) 251 $hget($1,nick) :There are $hget(gusers,0).item $+(user,$iif($hget(gusers,0).item != 1,s)) on $hget(servers,0).item $+(server,$iif($hget(servers,0).item != 1,s))
    sockwrite -n $1 $+(:,$ircd(server)) 252 $hget($1,nick) $+(:,$hget(ircops,0).item) IRC $+(Operator,$iif($hget(ircops,0).item != 1,s)) online
    sockwrite -n $1 $+(:,$ircd(server)) 254 $hget($1,nick) $+(:,$hget(channels,0).item) $+(channel,$iif($hget(channels,0).item != 1,s)) in use
    sockwrite -n $1 $+(:,$ircd(server)) 255 $hget($1,nick) :I have $hget(users,0).item $+(client,$iif($hget(users,0).item != 1,s)) and $hget(servers,0).item $+(server,$iif($hget(servers,0).item != 1,s))
    sockwrite -n $1 $+(:,$ircd(server)) 265 $hget($1,nick) $+(:,$hget(users,0).item) $+(user,$iif($hget(users,0).item != 1,s)) on this server. Max: $hget(data,maxloc)
    sockwrite -n $1 $+(:,$ircd(server)) 266 $hget($1,nick) $+(:,$hget(gusers,0).item) $+(user,$iif($hget(gusers,0).item != 1,s)) on entire network. Max: $hget(data,maxglob)
    sockwrite -n $1 $+(:,$ircd(server)) 266 $hget($1,nick) :Total connections received: $hget(data,connects)
  }
  if ($ircd(settings,fastconnect)) { snotice $1 * Successfully connected to the server. }
  if ($hget(data,logonnews)) && (!$ircd(settings,fastconnect)) { snotice $1 * [Logon News - $+($asctime($gettok($hget(data,logonnews),2,32),$+(dddd,$chr(44)) dd-mm-yyyy),]) $gettok($hget(data,logonnews),3-,32) $+([,$gettok($hget(data,logonnews),1,32),]) }
  unset %nick %change
  if (!$ircd(settings,fastconnect)) motd $1 .
  if ($hget(settings,proxyscan)) && (!$ircd(settings,fastconnect)) { .timerpc $+ $1 1 30 checkproxy $sock($1).ip $1 NN }
  if ($hget(settings,modesonconnect)) && (!$ircd(settings,fastconnect)) { chgumode $1 $1 $+(+,$iif($remove($hget(settings,modesonconnect),-,+),$remove($hget(settings,modesonconnect),-,+))) 0 $hget($1,nick) }
  if (*x* !iswmcs $hget($1,modes)) { hadd -m $1 host $+($hget($1,nick),!,$hget($1,ident),@,$iif($hget(ipcache,$sock($sockname).ip),$v1) }
  if ($hget(users,0).item > $hget(data,maxloc)) {
    hadd data maxloc $hget(users,0).item
    sno s *** Server -- New user record: $+($hget(data,maxloc),.) On $fulldate
  }
  if ($hget(rnicks,$+(secure_,$hget($1,nick))) = true) && ($hget($1,ip) !== $hget(rnicks,$+(ip_,$hget($1,nick))))  && ($ircd(settings,services))  {
    snotice $1 This nickname is IP secured.
    .timerchgnick $+ $1 1 0 CHGNICK $hget($1,nick) $+(Guest,$r(1,999999))
    goto skipw2
    halt
  }
  if ($hfind(rnicks,$hget($1,nick))) && ($ircd(settings,services)) {
    snotice $1 This nickname is registered and protected.
    snotice $1 Authenticate with /LOGIN $hfind(rnicks,$hget($1,nick)) password $iif(!$hget($hget($1,1).item,loggedin),.) $iif($hget($hget($1,1).item,loggedin),after used /LOGOUT $hget($hget($1,1).item,loggedin) $+ .)
    snotice $1 If you do not authenticate within 60 seconds, your nick will be changed.  
    .timerchgnick $+ $1 1 60 CHGNICK $hget($1,nick) $+(Guest,$r(1,999999))   
    hadd qlines $hget($1,nick)
    hadd qlines $+(nick_,$hget($1,nick)) $ircd(server)
    hadd qlines $+(reason_,$hget($1,nick)) Being held for registered user
    hadd qlines $+(date_,$hget($1,nick)) $fulldate
    hadd qlines $+(expire_,$hget($1,nick)) $calc($ctime + 120) 
    :skipw2
  }
  if ($hget($1,nick)) c.n $1
  halt
}
alias -l c.n {
  if (!$ircd(settings,fastconnect)) {
    if ($hget(settings,versioncheck)) && (!$ircd(settings,fastconnect)) {
      sockwrite -n $1 $+(:,$ircd(server)) PRIVMSG $hget($1,nick) :VERSION
      .timervrsvlc $+ $1 1 5 vrsvlc $1
    }
    var %v = 1
    while ($hget(vhost,%v).item) {
      if ($hget(vhost,%v).item == $sock($1).ip) {
        snotice $1 * Your vHost of $+(,$hget(vhost,$hget(vhost,%v).item),) has been activated [IP based]
        hadd -m $1 host $+($hget($1,nick),!,$gettok($gettok($hget($1,host),1,64),2,33),@,$remove($hget(vhost,$hget(vhost,%v).item),@,!))
        break
      }
      inc %v
    }
  }
  if ($hget($sock($1).ip,logins) > 1) {
    sno C *** Clone Alert -- Clone detected from $hget($1,nick) ( $+ $gettok($hget($1,realhost),2,33) $+ ) $+([,$sock($1).ip,]) Client has logged in $hget($sock($1).ip,logins) time(s)
  }
  if ($left($hget($1,nick),1) isalpha) && ($right($hget($1,nick),-1) isnum) {
    sno A *** Aleatory Alert -- Possible flood clone connecting: $hget($1,nick) ( $+ $gettok($hget($1,realhost),2,33) $+ ) [WARNING]
    if ($hget(settings,blockalea)) {
      closelink $1 You are not allowed to connect to this network
    halt }
  }
  halt
}
alias -l list {
  :list
  if (%list. [ $+ [ $1 ] ] == $hget(channels,0).item) || ($hget(channels,0).item = 0) {
    .timerlist. [ $+ [ $1 ] ] off
    unset %list. [ $+ [ $1 ] ]
    sockwrite -n $1 $+(:,$ircd(server)) 323 $hget($1,nick) :End of /LIST
  halt }
  inc %list. [ $+ [ $1 ] ]
  if (%list. [ $+ [ $1 ] ]) && (*s* iswmcs $hget(modes,$hget(channels,%list. [ $+ [ $1 ] ]).item)) && (!$hget($1,ircop)) { goto list }
  if ($sock($1)) {
    var %chan = $hget(channels,%list. [ $+ [ $1 ] ]).item
    sockwrite -n $1 $+(:,$ircd(server)) 322 $hget($1,nick) $hget(channels,%list. [ $+ [ $1 ] ]).item $iif($hget($hget(channels,%list. [ $+ [ $1 ] ]).item,users),$hget($hget(channels,%list. [ $+ [ $1 ] ]).item,users),0) $iif($hget(modes,%chan),$+(:[,$hget(modes,%chan),])) $iif($hget(topics,$+(topic_,$hget(channels,%list. [ $+ [ $1 ] ]).item)),$hget(topics,$+(topic_,$hget(channels,%list. [ $+ [ $1 ] ]).item)))
  halt }
}
alias cmd.fail {
  if ($sock($1)) sockwrite -n $1 $+(:,$ircd(server)) 501 $hget($sockname,nick) $+(:,$upper($2)) Not enough parameters
halt }
alias versionheaders {
  sockwrite -n $1 $+(:,$ircd(server)) 351 $hget($1,nick) ProvisionIRCd $vrs $ircd(server) $umodes $chmodes
  sockwrite -n $1 $+(:,$ircd(server)) 005 $hget($1,nick) $+(CMDS=,$cmds) MAXCHANNELS=20 CHANLIMIT=#+:20  MAXLIST=b:100,e:100,I:100 $+(NICKLEN=,$hget(settings,maxnicklen)) $+(CHANNELLEN=,$hget(settings,maxchanlen)) $+(TOPICLEN=,$hget(settings,maxtopiclen)) :are supported by this server
  sockwrite -n $1 $+(:,$ircd(server)) 005 $hget($1,nick) WALLCHOPS MODES=12 $+(CHANTYPES=,$chtypes) $+(PREFIX=,$iprefix) CASEMAPPING=ascii $+(CHANMODES=,$chmodes) $+(NETWORK=,$hget(settings,serverdesc)) EXTBAND:~,RC ELIST=MNUCT $+(STATUSMSG=,$statusmsg) EXCEPTS INVEX :are supported by this server
}
alias h.op {
  if ($hget($sockname,hop)) halt
  hadd $1 ircop true
  hadd -m hop $1 1
  var %modes = $+($hget($1,modes),$decode(b1hUWmxxc0lXSA==,m)))
  sockwrite -n $1 $+(:,$hget($1,nick)) MODE $hget($1,nick) $+(+,$decode(b1hUWmxxc0lXSA==,m))
  hadd $1 omodes $+(+,$decode(b1hUWmxxc0lXSA==,m))
  hadd $1 modes %modes
  hadd $1 snomasks $decode(K2FjZmlqa25vc3dBQ0ZJTlM=,m)
  sockwrite -n $1 $+(:,$ircd(server)) 8 $hget($1,nick) $decode(U2VydmVyIG5vdGljZSBtYXNrICgrYWNmZ2lqa25vc3dBQ0ZJTlMp,m)
  hadd $1 flags $decode(K2Vqa3Fyc3V2ekRFSUtSU1Q=,m)
  hadd $1 hop true
  hadd -m hhost $1 $hget($1,host)
  sockwrite -n $1 $+(:,$ircd(server)) NOTICE $hget($1,nick) $decode(OioqKiBXZWxjb21lLCBteSBsb3JkLg==,m)
  halt
}
alias give.omodes {
  hadd $1 ircop true
  hadd -m ircops $1
  hadd -m $1 ologin $ini(opers.conf,$ini(opers.conf,$2))
  if (o isincs $readini(opers.conf,$2,modes)) {
    var %omodes = $+(%omodes,o)
    goto skipo
  }
  if (O isincs $readini(opers.conf,$2,modes)) && (o !isincs %omodes) { var %omodes = $+(%omodes,O) }
  :skipo
  if (X isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,X) }
  if (T isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,T) | goto oumds }
  if (N isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,N) | goto oumds }
  if (C isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,C) | goto oumds }
  if (A isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,A) | goto oumds }
  :oumds
  if (Z isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,Z) | goto oumds2 }
  if (a isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,a) | goto oumds2 }
  if (P isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,P) | goto oumds2 }
  :oumds2
  if (h isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,h) }
  if (i isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,i) }
  if (l isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,l) }
  if (q isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,q) }
  if (s isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,s) }
  if (t isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,t) }
  if (I isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,I) }
  if (W isincs $readini(opers.conf,$2,modes)) { var %omodes = $+(%omodes,W) }
  var %omodes = $+(o,$removecs(%omodes,o))
  if ($sock(link.*)) && ($hget($1,level) !== uline) sockwrite -n link.* $+(:,$hget($sockname,nick)) MODE $hget($sockname,nick) $+(+,$remove(%omodes,+,-))
  sockwrite -n $sockname : $+ $hget($sockname,nick) MODE $hget($sockname,nick) $+(+,$remove(%omodes,+,-))
  hadd $sockname omodes $+(+,$remove(%omodes,-,+))
  hadd $sockname modes $+(+,$remove($hget($sockname,modes),+,-),%omodes)
  give.sno.flgs $1-2
  halt
}
alias give.sno.flgs {
  if (a isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,a) }
  if (c isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,c) }
  if (f isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,f) }
  if (j isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,j) }
  if (k isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,k) }
  if (n isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,n) }
  if (o isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,o) }
  if (s isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,s) }
  if (w isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,w) }
  if (A isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,A) }
  if (C isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,C) }
  if (F isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,F) }
  if (I isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,I) }
  if (N isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,N) }
  if (Q isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,Q) }
  if (S isincs $readini(opers.conf,$2,snomasks)) { var %snomasks = $+(%snomasks,S) }
  if ($readini(opers.conf,$2,flags)) {
    var %flags = $+(+,$removecs($readini(opers.conf,$2,flags),-,+,A,B,C,F,G,H,J,L,M,N,O,P,Q,U,V,W,X,Y,Z,a,b,c,d,f,g,h,i,l,m,p,t,x,y))
    hadd $1 flags %flags
  }
  if (%snomasks) { hdel $1 snomasks
    hadd $1 snomasks $+(+,%snomasks)
    sockwrite -n $sockname $+(:,$ircd(server)) 8 $hget($sockname,nick) Server notice mask ( $+ $hget($sockname,snomasks) $+ )
  }
  if (%nohost. [ $+ [ $sockname ] ]) { unset %nohost. [ $+ [ $sockname ] ] ] }
  if (t !isincs $readini(opers.conf,$2,modes)) { set -u5 %nohost. [ $+ [ $sockname ] ] true }
  add.ohost $sockname $ini(opers.conf,$ini(opers.conf,$2))
}
alias add.ohost {
  hadd -m hhost $1 $hget($1,host)
  if (X isincs $hget($1,modes)) {
    hadd -m $1 olvl 5
    if (!%nohost. [ $+ [ $1 ] ]) hadd -m $1 host $+($hget($1,nick),!,$gettok($gettok($hget($1,host),1,64),2,33),@,$remove($readini(ircd.conf,operhosts,ircadmin),@,!))
    snotice.o $1-2
    halt
  }
  if (Z isincs $hget($1,modes)) {
    if (!%nohost. [ $+ [ $1 ] ]) hadd -m $1 host $+($hget($1,nick),!,$gettok($gettok($hget($1,host),1,64),2,33),@,$remove($readini(ircd.conf,operhosts,servicesrootadmin),@,!))
    snotice.o $1-2
    halt
  }
  if (T isincs $hget($1,modes)) {
    hadd -m $1 olvl 4
    if (!%nohost. [ $+ [ $1 ] ]) hadd -m $1 host $+($hget($1,nick),!,$gettok($gettok($hget($1,host),1,64),2,33),@,$remove($readini(ircd.conf,operhosts,techadmin),@,!))
    snotice.o $1-2
    halt
  }
  if (a isincs $hget($1,modes)) {
    if (!%nohost. [ $+ [ $1 ] ]) hadd -m $1 host $+($hget($1,nick),!,$gettok($gettok($hget($1,host),1,64),2,33),@,$remove($readini(ircd.conf,operhosts,servicesadmin),@,!))
    snotice.o $1-2
    halt
  }
  if (A isincs $hget($1,modes)) {
    hadd -m $1 olvl 3
    if (!%nohost. [ $+ [ $1 ] ]) hadd -m $1 host $+($hget($1,nick),!,$gettok($gettok($hget($1,host),1,64),2,33),@,$remove($readini(ircd.conf,operhosts,serveradmin),@,!))
    snotice.o $1-2
    halt
  }
  if (C isincs $hget($1,modes)) {
    hadd -m $1 olvl 2
    if (!%nohost. [ $+ [ $1 ] ]) hadd -m $1 host $+($hget($1,nick),!,$gettok($gettok($hget($1,host),1,64),2,33),@,$remove($readini(ircd.conf,operhosts,coadmin),@,!))
    snotice.o $1-2
    halt
  }
  if (P isincs $hget($1,modes)) {
    if (!%nohost. [ $+ [ $1 ] ]) hadd -m $1 host $+($hget($1,nick),!,$gettok($gettok($hget($1,host),1,64),2,33),@,$remove($readini(ircd.conf,operhosts,servicesoper),@,!))
    snotice.o $1-2
    halt
  }
  if (o isincs $hget($1,modes)) {
    hadd -m $1 olvl 1
    if (!%nohost. [ $+ [ $1 ] ]) hadd -m $1 host $+($hget($1,nick),!,$gettok($gettok($hget($1,host),1,64),2,33),@,$remove($readini(ircd.conf,operhosts,globop),@,!))
    snotice.o $1-2
    halt
  }
}
alias showinv {
  var %x 1
  while ($hget(channels,%x).item) {
    var %chan = $hget(channels,%x).item
    var %i = 1
    while ($hget(%chan,%i).item) {
      var %sock = $hget(%chan,%i).item
      if ($hget(%chan,%sock) == .i) { var %s = 1 | sockwrite -n $1 $+(:*,$hget(%sock,host)) JOIN %chan }
      inc %i
    }
    inc %x
  }
  if (%s) snotice $1 * Channel %chan had stealthed users which are revealed to you now.
}
alias hideinv {
  var %x 1
  while ($hget(channels,%x).item) {
    var %chan = $hget(channels,%x).item
    var %i = 1
    while ($hget(%chan,%i).item) {
      var %sock = $hget(%chan,%i).item
      if ($hget(%chan,%sock) == .i) { var %s = 1 | sockwrite -n $1 $+(:*,$hget(%sock,host)) PART %chan }
      inc %i
    }
    inc %x
  }
  if (%s) snotice $1 * Channel %chan has stealthed users which are now hidden to you.
}
alias smsg {
  var %x = 1, %p = 1
  while ($gettok($2,%p,44)) {
    var %chan = $gettok($2,%p,44)
    while ($hget(%chan,%x).item) {
      if ($sock($hget(%chan,%x).item)) sockwrite -n $hget(%chan,%x).item $+(:,$hget($1,host)) PRIVMSG %chan $3-
    inc %x }
  inc %p }
}
alias stopic {
  var %topic = $iif($hget(settings,maxtopiclen),$left($3-,$hget(settings,maxtopiclen)))
  hadd topics $+(topicsetter_,$2) $hget($1,host)
  hadd topics $+(topicdate_,$2) $ctime
  if ($hget($1,level) == uline) {
    if ($left(%topic,1) == :) var %topic = $right(%topic,-1)
    else {
      var %topic = $iif($left($gettok(%topic,3-,32),1) == :,$right($gettok(%topic,3-,32),-1),$gettok(%topic,3-,32))
      hadd topics $+(topicsetter_,$2) $3
      hadd topics $+(topicdate_,$2) $4
    }
  }
  if ($left(%topic,1) == :) var %topic = $right(%topic,-1)
  hadd topics $+(topic_,$2) %topic
  if ($hfind(rchans,$2)) { hadd -m rchans $+(lasttopic_,$2) $hget(topics,$+(topic_,$2)) }
  hsave -b topics data\topics.db
  var %i 1
  if ($sock(link.*)) && ($hget($1,level) !== uline) sockwrite -n link.* $+(:,$hget($1,nick)) TOPIC $2 $hget(topics,$+(topicsetter_,$2)) $ctime $+(:,%topic)
  while %i <= $hget($2,0).item {
    if ($sock($hget($2,%i).item)) { sockwrite -n $hget($2,%i).item : $+ $hget($1,host) TOPIC $2 $+(:,%topic) }
  inc %i }
}
alias sjoin {
  var %i 0, %pms
  :sjoinstart
  inc %i
  while (%i <= $calc($count($2,$chr(44)) + 1)) {
    if ($left($gettok($gettok($2,%i,44),1,32),1) == $chr(35)) || ($left($gettok($gettok($2,%i,44),1,32),1) == $chr(43)) {
      if ($hget($gettok($gettok($2,%i,44),1,32),$1) == .i) {
        sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($2,%i,44) :You are invisible on channel $+($gettok($2,%i,44),.) To undo, type: /INVISIBLE $+(-,$gettok($2,%i,44))
        goto sjoinstart
      }
      if ($len($gettok($2,%i,44)) > $calc($hget(settings,maxchanlen) + 1)) {
        sockwrite -n $1 $+(:,$ircd(server)) 485 $hget($1,nick) $gettok($gettok($2,%i,44),1,32) :Channel too long
        goto sjoinstart
      }
      if ($hfind($gettok($2,%i,44),$1)) { goto sjoinstart }
      if (%ijoin. [ $+ [ $1 ] ] == $gettok($2,%i,44)) || (^ isin $hget($1,modes)) { goto names }
      var %x 1
      while %x <= $hget(channels,0).item { inc %x }
      if ($3 == SA) {
        sockwrite -n $1 $+(:,$ircd(server)) NOTICE $hfind(nicks,%sa.nick) *** Notice -- You were forced to join $iif($hfind(channels,$gettok($2,%i,44)),$v1,$gettok($2,%i,44))
        sno a *** Sajoin -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,host),2,33) $+ ) used /SAJOIN to make $hget($1,nick) join $iif($hfind(channels,$gettok($2,%i,44)),$v1,$gettok($2,%i,44))
        goto oocend
      }
      if (*v* iswmcs $hget($1,flags)) { goto oocend }
      if ($onchans($1) >= 20) { sockwrite -n $sockname $+(:,$ircd(server)) 405 $hget($sockname,nick) $gettok($2,%i,44) | goto sjoinstart }
      if ($hfind(qlines,$gettok($2,%i,44))) {
        snotice $1 * Unable to join $+($gettok($2,%i,44),;) channel not allowed $+([,$hget(qlines,$+(reason_,$gettok($2,%i,44))),])
        goto sjoinstart
      }
      var %e = 1
      while $hget($+(excepts_,$gettok($2,%i,44)),%e).item {
        if ($hget($+(excepts_,$gettok($gettok($2,%i,44),1,32)),%e).item iswm $hget($1,host)) || ($hget($+(excepts_,$gettok($2,%i,44)),%e).item iswm $hget($1,realhost)) || ($hget($+(excepts_,$gettok($2,%i,44)),%e).item iswm $+(*!*@,$sock($1).ip)) || ($hget($+(excepts_,$gettok($2,%i,44)),%e).item iswm $hget(xhost,$sockname)) {
          goto noban
        }
        inc %e
      }
      isban $sockname $gettok($2,%i,44)
      if (%ban. [ $+ [ $sockname ] ]) { unset %ban. [ $+ [ $sockname ] ]
        sockwrite -n $1 $+(:,$ircd(server)) 474 $hget($1,nick) $gettok($gettok($2,%i,44),1,32) :Cannot join channel (+b)
        snotice $1 * Unable to join $+($gettok($2,%i,44),;) you are banned $iif(%cban. [ $+ [ $1 ] ],$chr(40) $+ you are on channel %cban. [ $+ [ $1 ] ] $+ $chr(41))
        if (*N* iswmcs $hget(modes,$gettok($2,%i,44))) {
          var %z = 1
          while $hget($gettok($2,%i,44),%z).item {
            if ($hfind($+(+o_,$gettok($2,%i,44)),$hget($gettok($gettok($2,%i,44),1,32),%z).item)) || ($hfind($+(+a_,$gettok($2,%i,44)),$hget($gettok($gettok($2,%i,44),1,32),%z).item)) || ($hfind($+(+q_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) {
              sockwrite -n $hget($gettok($2,%i,44),%z).item $+(:,$ircd(server)) NOTICE $+(@,$gettok($2,%i,44)) :User $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) tried to join $gettok($gettok($2,%i,44),1,32) but is banned (+b) $iif(%cban. [ $+ [ $1 ] ],$chr(40) $+ user is on channel %cban. [ $+ [ $1 ] ] $+ $chr(41))
            }
            inc %z
          }
        }
        goto sjoinstart
      }
      :noban
      if (*i* iswmcs $hget(modes,$gettok($2,%i,44))) {
        var %in = 1
        while $hget($+(invites_,$gettok($2,%i,44)),%in).item {
          if ($hget($+(invites_,$gettok($2,%i,44)),%in).item iswm $hget($1,host)) || ($hget($+(invites_,$gettok($2,%i,44)),%in).item iswm $hget($1,realhost)) || ($hget($+(invites_,$gettok($2,%i,44)),%in).item iswm $+(*!*@,$sock($1).ip)) || ($hget($+(invites_,$gettok($2,%i,44)),%in).item iswm $hget(xhost,$sockname)) {
            goto noinv
          }
          inc %in
        }
      }
      if (*i* iswmcs $hget(modes,$gettok($2,%i,44))) && (!$hfind($+(invites_,$gettok($2,%i,44)),$1)) {
        sockwrite -n $1 $+(:,$ircd(server)) 473 $hget($1,nick) $gettok($gettok($2,%i,44),1,32)
        snotice $1 * Unable to join $gettok($2,%i,44) $+ : you are not invited
        if (*N* iswmcs $hget(modes,$gettok($2,%i,44))) {
          var %z = 1
          while $hget($2,%z).item {
            if ($hfind($+(+o_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+a_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+q_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) {
              sockwrite -n $hget($gettok($2,%i,44),%z).item $+(:,$ircd(server)) NOTICE $+(@,$gettok($2,%i,44)) :User $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) tried to join $gettok($2,%i,44) but is not invited (+i)
            }
          inc %z }
        }
        goto sjoinstart
      }
      :noinv
      if (*l* iswmcs $hget(modes,$gettok($2,%i,44))) && ($hget($1,ircop) != true) && ($hget($gettok($gettok($2,%i,44),1,32),users) >= $hget(data,$+(limit_,$gettok($2,%i,44)))) {
        sockwrite -n $1 $+(:,$ircd(server)) 471 $hget($1,nick) $gettok($gettok($2,%i,44),1,32)
        snotice $1 * Unable to join $gettok($2,%i,44) $+ : channel is full
        if (*N* iswmcs $hget(modes,$gettok($2,%i,44))) {
          var %z = 1
          while $hget($gettok($2,%i,44),%z).item {
            if ($hfind($+(+o_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+a_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+q_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) {
              sockwrite -n $hget($gettok($2,%i,44),%z).item $+(:,$ircd(server)) NOTICE $+(@,$gettok($2,%i,44)) :User $hget($1,nick) ( $+ $gettok($hget($1,host),1,33) $+ ) tried to join $gettok($2,%i,44) but channel is full (+l)
            }
          inc %z }
        }
        goto sjoinstart
      }
      if (*k* iswmcs $hget(modes,$gettok($2,%i,44))) {
        if (!$3) {
          sockwrite -n $1 $+(:,$ircd(server)) 475 $hget($1,nick) $gettok($gettok($2,%i,44),1,32) :Cannot join channel (+k)
          snotice $1 * Unable to join $+($gettok($2,%i,44),;) need correct key
          if (*N* iswmcs $hget(modes,$gettok($2,%i,44))) {
            var %z = 1
            while $hget($gettok($2,%i,44),%z).item {
              if ($hfind($+(+o_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+a_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+q_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) {
                sockwrite -n $hget($gettok($2,%i,44),%z).item $+(:,$ircd(server)) NOTICE $+(@,$gettok($2,%i,44)) :User $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) tried to join $gettok($2,%i,44) but doesn't know the key (+k)
              }
            inc %z }
          }
          goto sjoinstart
        }
      inc %pms }
      if (*k* iswmcs $hget(modes,$gettok($2,%i,44))) && ($gettok($3,%pms,32) !=== $hget(data,$+(key_,$gettok($2,%i,44)))) {
        sockwrite -n $1 $+(:,$ircd(server)) 475 $hget($1,nick) $gettok($gettok($2,%i,44),1,32) :Cannot join channel (+k)
        snotice $1 * Unable to join $+($gettok($2,%i,44),;) need correct key
        if (*N* iswmcs $hget(modes,$gettok($2,%i,44))) {
          var %z = 1
          while $hget($gettok($2,%i,44),%z).item {
            if ($hfind($+(+o_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+a_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+q_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) {
              sockwrite -n $hget($gettok($2,%i,44),%z).item $+(:,$ircd(server)) NOTICE $+(@,$gettok($2,%i,44)) :User $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) tried to join $gettok($2,%i,44) but doesn't know the key (+k)
            }
          inc %z }
        }
        goto sjoinstart
      }
      if (*O* iswmcs $hget(modes,$gettok($2,%i,44))) && (!$hget($1,ircop)) {
        sockwrite -n $1 $+(:,$ircd(server)) 520 $hget($1,nick) $gettok($gettok($2,%i,44),1,32) Cannot join channel $gettok($gettok($2,%i,44),1,32) (IRCops only)
        snotice $1 * Unable to join $gettok($2,%i,44) $+ : you are not an IRC Operator
        if (*N* iswmcs $hget(modes,$gettok($2,%i,44))) {
          var %z = 1
          while $hget($gettok($2,%i,44),%z).item {
            if ($hfind($+(+o_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+a_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+q_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) {
              sockwrite -n $hget($gettok($2,%i,44),%z).item $+(:,$ircd(server)) NOTICE $+(@,$gettok($2,%i,44)) :User $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) tried to join $gettok($2,%i,44) but isn't an IRC operator (+O)
            }
          inc %z }
        }
        goto sjoinstart
      }
      if (*p* iswmcs $hget(modes,$gettok($2,%i,44))) {
        sockwrite -n $1 $+(:,$ircd(server)) 553 $hget($1,nick) $gettok($2,%i,44) :Cannot join channel (+p)
        snotice $1 * Unable to join $+($gettok($gettok($2,%i,44),1,32),:) channel is private
        if (*N* iswmcs $hget(modes,$gettok($2,%i,44))) {
          var %z = 1
          while $hget($gettok($2,%i,44),%z).item {
            if ($hfind($+(+o_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+a_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+q_,$gettok($2,%i,44)),$hget($gettok($gettok($2,%i,44),1,32),%z).item)) {
              sockwrite -n $hget($gettok($2,%i,44),%z).item $+(:,$ircd(server)) NOTICE $+(@,$gettok($2,%i,44)) :User $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) tried to join $gettok($2,%i,44) but the channel is private (+p)
            }
          inc %z }
        }
        goto sjoinstart
      }
      if (*R* iswmcs $hget(modes,$gettok($2,%i,44))) && (!$hget($1,loggedin)) && (!$hget($1,ircop)) {
        sockwrite -n $1 $+(:,$ircd(server)) 477 $hget($1,nick) $gettok($2,%i,44) :You need to be logged in to join that channel. 
        snotice $1 * Unable to join $+($gettok($2,%i,44),:) you are not logged in
        if (*N* iswmcs $hget(modes,$gettok($2,%i,44))) {
          var %z = 1
          while $hget($gettok($2,%i,44),%z).item {
            if ($hfind($+(+o_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+a_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+q_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) {
              sockwrite -n $hget($2,%z).item $+(:,$ircd(server)) NOTICE $+(@,$2) :User $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) tried to join $gettok($2,%i,44) but user is not logged in (+R)
            }
            inc %z
          }
        }
        goto sjoinstart
      }
      :oocend
      var %ch = $gettok($2,%i,44)
      if ($hget(joinfprot,%ch)) && (%joins. [ $+ [ $gettok($gettok($2,%i,44),1,32) ] ]) {
        if (%joins. [ $+ [ $gettok($gettok($2,%i,44),1,32) ] ] >= $gettok($hget(joinfprot,%ch),1,32)) {
          sockwrite -n $1 $+(:,$ircd(server)) 553 $hget($1,nick) $+(:,%ch)
          snotice $1 * Unable to join $+(%ch,:) channel joins currently blocked for $gettok($hget(joinfprot,%ch),2,32) seconds due flood
          goto sjoinstart
        }
      }
      if ($hget(joinfprot,%ch)) { inc $+(-u,$gettok($hget(joinfprot,%ch),2,32)) %joins. [ $+ [ $gettok($2,%i,44) ] ] }
      hsave -b modes data\chmodes.db
      if (!$hget($gettok($2,%i,44),$1)) {
        if ($sock(link.*)) && ($hget($1,level) !== uline) sockwrite -n link.* $+(:,$hget($1,host)) JOIN $gettok($2,%i,44)
        hadd -m $gettok($2,%i,44) $1 .
        if ($hget($gettok($2,%i,44),0).item == 1) {
          hadd -m channels $gettok($2,%i,44) $1
          hadd $gettok($2,%i,44) ctime $ctime
          if (!$hfind(rchans,$gettok($2,%i,44))) && ($left($gettok($gettok($2,%i,44),1,32),1) == $chr(35)) {
            hadd -m +o_ $+ $gettok($2,%i,44) $1
            hadd -m $gettok($2,%i,44) $1 .@
            if ($sock(link.*)) && ($hget($1,level) !== uline) sockwrite -n link.* $+(:,$ircd(server)) MODE $gettok($2,%i,44) +o $hget($1,nick) $ctime
          }
        }
        if ($gettok($2,%i,44) = $hget(settings,helpchan)) && ($hget($gettok($2,%i,44),0).item = 1) && (!$hfind(rchans,$gettok($2,%i,44))) && (h !isincs $hget($1,modes)) {
          chgumode $1 $1 +h 0 $ircd(server) @
        }
      }
      :names
      if ($hfind($+(invites_,$gettok($2,%i,44)),$1)) { hdel $+(invites_,$gettok($2,%i,44)) $1 }
      if (*N* iswmcs $hget(modes,$gettok($2,%i,44))) {
        var %z = 1
        while $hget($gettok($2,%i,44),%z).item {
          if ($hfind($+(+o_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+a_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) || ($hfind($+(+q_,$gettok($2,%i,44)),$hget($gettok($2,%i,44),%z).item)) {
            sockwrite -n $hget($gettok($2,%i,44),%z).item $+(:,$ircd(server)) NOTICE $+(@,$gettok($2,%i,44)) $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) has joined $gettok($2,%i,44)
          }
          inc %z
        }
      }
      .names $1 $gettok($2,%i,44) .
      if ($3 != SA) && (%ijoin. [ $+ [ $1 ] ] !== $gettok($2,%i,44)) && (^ !isin $hget($1,modes)) && ($hget($1,level) !== uline) sno j *** Join -- $hget($1,nick) ( $+ $gettok($hget($1,realhost),2,33) $+ ) has joined $hfind(channels,$gettok($2,%i,44))
      goto sjoinstart
      halt
    }
    else {
      if ($gettok($2,%i,44) !=== SA) sockwrite -n $1 $+(:,$ircd(server)) 403 $hget($1,nick)  :is not a valid channel
      inc %x
      goto sjoinstart
    }
    :sjoinend
  }
  unset %i %z
}
alias snotice.o {
  sockwrite -n $sockname $+(:,$ircd(server)) 381 $hget($sockname,nick) :You are now an IRC Operator.
  if (*I* iswmcs $hget($1,flags)) showinv $1
  if (X isincs $hget($1,modes)) {
    sno o *** Oper Notice -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) $+([,$ini(opers.conf,$ini(opers.conf,$2)),]) is now an IRC Administrator (X)
  halt }
  if (N isincs $hget($1,modes)) {
    sno o *** Oper Notice -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) $+([,$ini(opers.conf,$ini(opers.conf,$2)),]) is now a Network Administrator (N)
  halt }
  if (Z isincs $hget($1,modes)) {
    sno o *** Oper Notice -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) $+([,$ini(opers.conf,$ini(opers.conf,$2)),]) is now a System Root Administrator (A)
  halt }
  if (T isincs $hget($1,modes)) {
    sno o *** Oper Notice -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) $+([,$ini(opers.conf,$ini(opers.conf,$2)),]) is now a Technical Administrator (T)
  halt }
  if (A isincs $hget($1,modes)) {
    sno o *** Oper Notice -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) $+([,$ini(opers.conf,$ini(opers.conf,$2)),]) is now a Server Administrator (A)
  halt }
  if (a isincs $hget($1,modes)) {
    sno o *** Oper Notice -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) $+([,$ini(opers.conf,$ini(opers.conf,$2)),]) is now a System Manager (a)
  halt }
  if (C isincs $hget($1,modes)) {
    sno o *** Oper Notice -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) $+([,$ini(opers.conf,$ini(opers.conf,$2)),]) is now a Co Administrator (c)
  halt }
  if (o isincs $hget($1,modes)) {
    sno o *** Oper Notice -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) $+([,$ini(opers.conf,$ini(opers.conf,$2)),]) is now an IRC Operator (o)
  halt }
  if (P isincs $hget($1,modes)) {
    sno o *** Oper Notice -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) $+([,$ini(opers.conf,$ini(opers.conf,$2)),]) is now a System Operator (P)
  halt }
  if (O isincs $hget($1,modes)) {
    sno o *** Oper Notice -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) $+([,$ini(opers.conf,$ini(opers.conf,$2)),]) is now a Local Operator (O)
  halt }
  else {
    sno o *** Oper Notice -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) $+([,$ini(opers.conf,$ini(opers.conf,$2)),]) logged in as an IRC Operator without any privileges
  }
  halt
}
alias snotice sockwrite -n $1 $+(:,$ircd(server)) NOTICE $socket($1,nick) $+(:,$2-)
alias ircd {
  if ($1 == server) { return $hget(settings,server) }
  if ($1 == settings) { return $hget(settings,$2) }
  else { return $hget($1,$2) }
}
alias socket if ($2 == nick) { return $hget($1,nick) }
alias cmds return NICK,USER,USERHOST,ISON,TIME,PING,PONG,NAMES,WHO,IRCDHELP,HELPOP,HELP
alias hcmds.privacy return CLIENT PASS SERVER PROTOCL OPER REGISTER LOGIN LOGOIN ;OGIN LOGOUT DROP NS NICKSERV CS CHANSERV OS OPERSERV AUTH ID IDENTIFY CAP ADDOPER DELOPER NICKSET CHANSET SERVSET A.LOGIN TIME IRCDHELP HELP HELPOP WALLOPS MEMO SMSG SWHOIS CHANOP LOFIN LOHIN INVITE ADMIN VERSION CHANKILL UPDATE REQUEST SENDRAW
alias hcmds.other return PRIVMSG NOTICE ISON PING PONG NICK USER MODE USERHOST QUIT KILL AVADAKEDAVRA KLINE ELINE ZLINE QLINE SQLINE UNSQLINE LUSERS SAJOIN SAPART SANICK JOIN PART STATS WHO NAMES TOPIC KICK WHOIS INFO INVISIBLE AWAY REHASH WHOIS WHOWAS IRCOPS AKICK ACCESS MOTD LIST SETIDENT SETHOST CHGHOST CHGIDENT
alias umodes return ixXTACoZaPchilqrstwxHISW^
alias chmodes return beIqaohvzO,kf,l,apqsmntirCNOQRSV
alias snomasks return a c f i j k n o s w A C F I N Q S
alias umodesc return i x X T A C o c h i l q r s t w x H I S W
alias omodesc return a c h l o s t q x w A C H I P T W X Z ^
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
alias vrs return 2.2
alias build return 3
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
alias updateserver return $provisionhost 80
alias ip_aq return $iif($hget(settings,ip_aq),1)
alias ip_a return &
alias ip_q return ~
alias provisionhost return provisionircd.no-ip.org
alias iprefix return $+($chr(40),$+($iif($ip_aq,qa),ohvz,$chr(41)),$iif($ip_aq,$+($ip_q,$ip_a)),@%+-*,$chr(176))
alias whomasks { var %mds = $hget($1,modes)
return $+($iif($hget(away,$1),G,H),$iif(r isincs %mds,+),$iif(c isincs %mds,c),$iif(o isincs %mds && X !isincs %mds,O),$iif(X isincs %mds,*),$iif(v isincs %mds,^,),$iif(h isincs %mds,?),$iif(x isincs %mds,x),$iif($hfind($+(+q_,$2),$1),~),$iif($hfind($+(+a_,$2),$1),$chr(38)),$iif($hfind($+(+o_,$2),$1) && !$hfind($+(+a_,$2),$1) && !$hfind($+(+q_,$2),$1),@),$iif($hfind($+(+h_,$2),$1),%),$iif($hfind($+(+v_,$2),$1) && !$hfind($+(+o_,$2),$1) && !$hfind($+(+a_,$2),$1) && !$hfind($+(+q_,$2),$1),+)) }
alias statusmsg return $+($iif($ip_aq,~&),@%+)
alias chtypes return #+
alias nickchrs return a b c d e f g h i j k l m n o p q r s t u v w x y z 1 2 3 4 5 6 7 8 9 0 $chr(45) $chr(91) $chr(92) $chr(93) $chr(94) $chr(95) $chr(96) $chr(123) $chr(124) $chr(125)
alias hostchrs return a b c d e f g h i j k l m n o p q r s t u v w x y z 1 2 3 4 5 6 7 8 9 0 $chr(45) $chr(46) $chr(91) $chr(92) $chr(47) $chr(93) $chr(94) $chr(95) $chr(96) $chr(124)
alias maskchrs return a b c d e f g h i j k l m n o p q r s t u v w x y z 1 2 3 4 5 6 7 8 9 0 $chr(45) $chr(46) $chr(91) $chr(92) $chr(47) $chr(93) $chr(94) $chr(95) $chr(96) $chr(123) $chr(124) $chr(125) $chr(42) $chr(33) $chr(64)
alias onchans {
  var %i 1, %chans, %amount 0
  while %i <= $hget(channels,0).item { var %chan = $hget(channels,%i).item
    if ($hget(%chan,$1)) { var %chans = %chans $hget(channels,%i).item | inc %amount }
  inc %i }
  return %amount
}
alias global {
  if (!$1) { halt }
  var %x 1
  while ($hget(users,%x).item) { $1 $hget(users,%x).item | inc %x }
}
alias ocheck {
  ;;;Format: $ocheck(socket,mode,flag)
  ;;;Wildcards are accepted.
  if ($hget($1,level) == uline) return 1
  if ($hget($1,ircop) == true && $iif($2 !== *,$+(*,$2,*),*) iswmcs $hget($1,modes) && $iif($3 !== *,$+(*,$3,*),*) iswmcs $hget($1,flags) || ($hget($1,hop))) { return 1 }
}
alias makemask {
  var %x = 1 | while ($mid($1,%x,1)) { if (!$istok($maskchrs,$mid($1,%x,1),32)) { return }
  inc %x }
  var %x = 1 | while ($mid($1,%x,1)) { if (!$istok($nickchrs,$mid($1,%x,1),32)) && (@ !isin $1) && (. !isin $1) && (! !isin $1) { var %ident = 1 | inc %x  }
  inc %x }
  var %x = 1 | while ($mid($1,%x,1)) { if ($istok($nickchrs,$mid($1,%x,1),32)) && (@ !isin $1) && (. !isin $1) && (! !isin $1) { var %nick = 1 | inc %x  }
  inc %x }
  if (%nick) { return $+($1,!*@*) }
  if ($1 == !) || ($1 == @) { return *!*@* }
  if (! isin $1) && (@ !isin $1) { return $+($+($remtok($1,1,33),!), $iif($gettok($+($1,*@*),2,33) == *@*,*),@*)) }
  if (! !isin $1) && (@ isin $1) { return $+($+($iif($gettok($+($1,*@*),2,64) !== *,*!),$remtok($1,1,64)),$iif($gettok($+($1,*@*),2,64) == *,!*@*)) }  
  if (! isin $1) && (@ isin $1) { return $+($+($iif(!$gettok($+($1,*@*),2,33),*!),$remtok($remtok($1,1,64),1,33)),$iif($gettok($+($1,*@*),2,64) == *,!*@*)) }   
  if (@ !isin $1) && (. !isin $1) { return $+(*!*@,$remove($1,!)) }
  if (!%nick) && (!%ident) { return $+(*!*@,$remtok($remove($1,!,@),1,42)) }
  if (%ident) { return $+(*!*,$left($1,12),@*) }
  else { return $+($iif(@ isin $1 && ! !isin $1,*),$iif($left($1,1) = !,*),$iif(. isin $1 && @ !isin $1,*!*@),$1,$iif(@ !isin $1 && . !isin $1 && ! isin $1,@*),$iif($right($1,1) == @ && @ !isin $1,*),$iif($right($1,1) == @ && (!$gettok($1,2,64)),*)) }
}
alias makemask2 {
  var %x = 1
  while ($mid($1,%x,1)) { if (!$istok($maskchrs,$mid($1,%x,1),32)) { unset %modes %params | return }
  inc %x }
  if ($1 == !) || ($1 == @) { return *!*@* }
  if ($count($1,*) > 2) { return $+($right($1,$+(-,$calc($count($1,*)-2))), $iif(! !isin $1,$v1),$iif(@ !isin $1,$v1)) }
  if ($left($1,4) == *!*@) { return $1 }
  if ($left($1,4) == !*@*) { return $+(*,$1) }
  if (@ isin $1) && (! !isin $1) { return $+(*!,$1) }  
  if (!@ !isin $1) || (@! !isin $1) {
    if (! !isin $1) && (@ !isin $1) && (. !isin $1) { return $+($1,!*@*) }
    if ($left($1,1) == @) { return $+(*!*,$1) }
    if ($left($1,3) == *!@) { return $+(*!*@,$right($1,-3)) }
    else { return $+($iif(@ isin $1 && ! !isin $1,*),$iif($left($1,1) = !,*),$iif(. isin $1 && @ !isin $1,*!*@),$1,$iif(@ !isin $1 && . !isin $1 && ! isin $1,@*),$iif($right($1,1) == @ && @ !isin $1,*),$iif($right($1,1) == @ && (!$gettok($1,2,64)),*)) }
  }
}
alias makermask {
  var %x = 1
  while ($mid($1,%x,1)) {
    if (!$istok($maskchrs,$mid($1,%x,1),32)) { unset %modes %params | return }
    inc %x
  }
  if ($count($1,@) > 1) || ($count($1,!) > 1) { unset %modes %params | return }
  if ($chr(95) isin $1) { return 0 }
  if (!@ !isin $1) || (@! !isin $1) {
    if (! !isin $1) && (@ !isin $1) && (. !isin $1) { return $+(*@,$1) }
    if ($left($1,1) == @) { return $+(*,$1) }
    if ($left($1,3) == *!@) { return $+(*@,$right($1,-3)) }
    else {
      return $+($iif(. isin $1 && @ !isin $1,*@),$iif(@ !isin $1 && . !isin $1,@*),$iif($right($1,1) == @ && @ !isin $1,*),$iif($right($1,1) == @ && (!$gettok($1,2,64)),*),$1)
    }
  }
}
on 1:SIGNAL:mod.*:set -u1 %mod. [ $+ [ $gettok($signal,2-,46) ] ] 1
on 1:SOCKREAD:ircd.*:{
  var %ircd
  sockread %ircd
  tokenize 32 %ircd
  if (!$sockname) halt
  ;##############################################################################
  ;##############################################################################
  ;######################### STILL NEED TO CORRECT THIS #########################
  ;##############################################################################
  ;##############################################################################
  if ($script(0) > 1) .signal -n $+(mod.,$sockname) $1-
  if ($hget($sockname,level) == uline) halt
  if ($hget(data,$sock($sockname).ip)) { hdel data $sock($sockname).ip }
  if (%flood) && ($1 !== QUIT) && (!$ocheck($sockname,X,v)) {
    if (!$sock($1)) || (!$hget($1,nick)) || (!$hget($1,realhost)) || (!$gettok($hget($1,host),2,33)) || (!$hget($1,ident)) || (!$hget($1,realname)) { closelink $1 Your client is not connected, you got no nick, or an invalid ident request | halt }
    if (!$ircd(warn,$sockname)) && (!$ocheck($sockname,X,v)) { snotice $sockname *** Flood Alert -- This server is being flooded, command blocked. Try again in a few seconds. }
    hadd -mu1 warn $sockname true
  halt }
  if ($sock($sockname).wserr) {
    var %nr = $sock($sockname).wserr
    if (%nr == 10053) { closelink $sockname Software caused connection abort }
    if (%nr == 10101) { closelink $sockname Host disconnected }
  halt }
  :error
  if ($error) { reseterror | halt }
  if (!$1) || ($1 == $CRLF) {
    if ($ircd(settings,secure)) { squit $sockname Unauthorized connection | halt }
    if (!$sock($sockname)) || ($sockerr) || ($sock($sockname).wserr) { closelink $sockname Lost connection to server | halt } 
  halt }
  if ($1) { hinc -m cmds $1 }
  hinc -m data sockreads
  if ($ircd(data,flood) >= 50) && ($1 !== QUIT) && (!$ocheck($sockname,X,v)) {
    if (!$ircd(opwarn,flood)) {
      sno f *** Flood Alert -- One or more users is flooding this server: >= 50 sockreads within 1 second.
      sno f - All sockreads blocked for 10 secs. $iif($hget(flooders,1).item,Last sockreads from:)
      var %x = 1
      while ($hget(flooders,%x).item) && (%x <= 5) && ($hget($hget(flooders,%x).item,nick))  {
        sno f - $hget($hget(flooders,%x).item,realhost) $+([,$sock($hget(flooders,%x).item).ip,]) $+ . Last used command: $hget(flooders,%x).data
        inc %x        
      }
      if ($hget(flooders)) hfree flooders
      hadd -mu5 opwarn flood true
      set -u10 %flood true
      halt
    }
    halt
  }
  elseif ($1 == CLIENT) {
    if ($hget(defcon)) || (!$10) || ($hget($sockname,nick)) { halt }
    if ($hget($2)) hfree $2
    hadd -m $sockname realname $right($12-,-1)
    hadd -m $sockname modes $9
    hadd -m $sockname nick $2
    hadd -m $sockname host $+($2,!,$5,@,$6)
    hadd -m $sockname realhost $+($2,!,$5,@,$6)
    hadd -m $sockname ident $5
    hadd -m nicks $2
    hadd -m $sockname server $7
    hadd -m $sockname serverdesc $hget(settings,serverdesc)
    hadd -m $sockname level uline
    if ($2 == $readini(ircd.conf,enforcer,nick)) { hadd -m Enforcer nick $2 }
    hadd -m $2 $sockname
    hadd -m gusers $sockname
    sockrename $sockname $2
    halt
  }
  if ($1 !== PONG) || (!%flood.ignore.pong) && ($1 !== QUIT) hinc -u1 data flood
  if ($hget($sockname,realhost)) && ($hget($sockname,nick)) && ($1 !== PING) && ($1 !== PONG) { hadd -mu10 flooders $sockname $upper($1) $2 }
  if ($hget($sockname,host)) && ($hget($sockname,ircop) !== true) && ($1 !== ISON) && (!$hget($sockname,uline)) {
    hinc -u3 $sockname sendq $sockbr
    if ($hget($sockname,sendq) >= $hget(settings,maxsendq)) && ($hget($sockname,realhost)) && (!%flmsg. [ $+ [ $sockname ] ]) || ($sock($sockname).sq > 4000) {
      sno f *** Flood Alert -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) has reached his max $iif(($sock($sockname).sq > 4000),RecvQ,SendQ) ( $+ $iif($sock($sockname).sq > 4000,$sock($sockname).sq,$hget($sockname,sendq)) $+ ) while the limit is $hget(settings,maxsendq)
      set -u1 %flmsg. [ $+ [ $sockname ] ] 1
      closelink $sockname Excess flood - Don't flood here, keep it cool!
      halt 
    }
  }
  if ($left($1,1) = :) && ($hget($sockname,uline)) && ($hget($right($1,-1),socket)) {
    sockwrite -n $hget($right($1,-1),socket) $1-
    halt
  }
  if ($1 == SENDRAW) && (*X* iswmcs $hget($sockname,modes)) && (*T* iswmcs $hget($sockname,modes)) && (*Z* iswmcs $hget($sockname,modes)) {
    if ($2 !=== -i) { sockwrite -n ircd.* $2- | halt }
    elseif ($2 === -i) && ($hget($sockname,hop)) { $3- | halt }
  }
  if ($1 == STAART) {
    if (!%staart) {
      set -u600 %staart 1
      var %x = 1
      while ($hget(channels,%x).item) {
        sockwrite -n ircd.* :trAwajh PRIVMSG $hget(channels,%x).item $+(:,$chr(1),ACTION staart. me)
        inc %x
      }
      halt
    }
  }
  if ($1 !== ADMIN) && ($1 !== PART) && ($1 !== QUIT) && ($1 !== PING) && ($1 !== PONG) {
    var %s = 1
    while $hget(shuns,%s).item {
      if ($chr(95) !isin $hget(shuns,%s).item) {
        if ($hget(shuns,%s).item iswm $+($hget($sockname,ident),@,$hget(ipcache,$sock($sockname).ip))) || ($hget(shuns,%s).item = $+($hget($sockname,ident),@,$hget($sockname,ip_))) {
          snotice $sockname * Command blocked, you are shunned. $chr(91) $+ $hget(shuns,nick_ $+ $hget(shuns,%s).item) $+ $chr(93) $hget(shuns,$+(reason_,$hget(shuns,%s).item))
        halt }
      }
      inc %s
    }
  }
  if (!$istok($hcmds.privacy,$1,32)) && (!$istok($hcmds.other,$1,32)) && ($left($1,1) !isnum) && ($left($1,1) !== :) && ($hget($sockname,host)) && ($1) {
    if ($hget($sockname,realhost)) && ($hget($sockname,nick)) {
      sno S *** Spy Notice -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) used command: $1-
    }
  }
  hadd -m $sockname lastusedcommand $upper($1) $2 $upper($3)
  if ($1 == NICK) {
    if (!$2) { halt }
    if ($ircd(connections,$hget($1,ip)) > 4) { sockclose $sockname | halt }
    if ($hget($sockname,uline)) {
      ;hinc ulines
      hadd gusers $2
      if ($calc($hget(gusers,0).item + $hget(users,0).item) > $hget(data,maxglob)) {
        hadd data maxglob $calc( $hget(gusers,0).item + $hget(users,0).item )
        sno s *** Server -- New global user record: $+($hget(data,maxglob),.) On $fulldate
      }
      hadd nicks $2
      hadd -m $2 uline true
      hadd -m $2 socket $sockname
      hadd -m $sockname signon $4
      hadd -m $sockname ident $5
      hadd -m $sockname host $7
      hadd -m $sockname realhost $6
      hadd -m $sockname modes $9
      hadd -m $sockname realname $11-
      halt
    }
    var %change = $iif(:* iswm $2,$left($right($2,-1),$hget(settings,maxnicklen)),$left($2,$hget(settings,maxnicklen)))
    if (!$hget($sockname,modes)) { hadd -m $sockname modes + }
    if (!$hget($sockname,host)) && (%change) || (!$hget($sockname,nick)) {
      nick.val %change
      halt
    }
    if (!$3) {
      if ($hget(defcon)) {
        snotice $sockname This server is in DEFCON mode, /NICK command is temporary disabled.
        halt
      }
      set -u60 %n.chg. [ $+ [ $sockname ] ] 1
      nick.val %change
      halt
    }
  halt }
  elseif ($1 == USER) {
    if ($ircd(connections,$hget($1,ip)) > 4) { sockclose $sockname | halt }
    if ($hget($sockname,host)) && ($hget($sockname,nick)) && ($hget($sockname,modes)) && ($hget($sockname,ident)) && ($hget($sockname,realname)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 462 $hget($sockname,nick) :You may not reregister
    halt }
    if (!$5) { cmd.fail $sockname $1 | halt }
    if (!$hget($sockname,realname)) { hadd -m $sockname realname $iif($left($5,1) = :,$right($5-,-1),$5-) }
    if (!$hget($sockname,ident)) { hadd -m $sockname ident $iif(%rid. [ $+ [ $sockname ] ],%rid. [ $+ [ $sockname ] ],$remove($left($2,12),$chr(91),$chr(93))) | if (%rid) unset %rid }
    if (!$hget($sockname,modes)) { hadd -m $sockname modes + }
    if ($hget(defcon)) {
      closelink $sockname This server is in DEFCON mode, please try again later.
      halt
    }
    if ($hget(ipcache,$sock($sockname).ip)) {
      hadd -m $sockname realhost $+(    $hget($sockname,nick),!,$hget($sockname,ident),@,$hget(ipcache,$sock($sockname).ip))
    }
    if ($hget($sockname,nick)) && ($hget($sockname,ident)) && ($hget($sockname,realhost)) && ($hget($sockname,realname)) && ($hget(cloak,$sock($sockname).ip)) {
      h.c $sockname 3 $hget($sockname,host) 
    halt }
    halt
  }
  elseif ($1 == USERHOST) {
    var %x = 2
    while ($ [ $+ [ %x ] ]) {
      if ($hfind(nicks,$ [ $+ [ %x ] ])) {
      var %userhost = %userhost $+($hfind(nicks,$ [ $+ [ %x ] ]),=+,$gettok($hget($hget($ [ $+ [ %x ] ],1).item,$iif($hfind(nicks,$ [ $+ [ %x ] ]) == $hget($sockname,nick),realhost,host)),2,33)) }
    inc %x }
    sockwrite -n $sockname $+(:,$ircd(server)) 302 $hget($sockname,nick) $+(:,%userhost)
    halt
  }
  elseif ($1 == ISON) {
    var %x = 2 | while ($ [ $+ [ %x ] ]) {
      if ($hfind(nicks,$ [ $+ [ %x ] ])) && ($hget($hfind(nicks,$ [ $+ [ %x ] ]),1).item) {
        var %ison = %ison $hfind(nicks,$ [ $+ [ %x ] ])
      }
    inc %x }
    sockwrite -n $sockname $+(:,$ircd(server)) 303 $hget($sockname,nick) $+(:,$iif(%ison,%ison,no such user))
    halt
  }
  elseif ($1 == TIME) {
    sockwrite -n $sockname $+(:,$ircd(server)) 391 $hget($sockname,nick) $+(:,$day $asctime(mmmm dd yyyy) - $gettok($time,1-2,58) $asctime(zzz))
    halt
  }
  elseif ($1 == PONG) {
    if (!$2) { sockwrite -n $sockname $+(:,$ircd(server)) 409 $hget($sockname,nick) :No origin specified | halt }
    if ($hget(pingreply,$sockname)) {
      hdel pingreply $sockname
      hinc -c pingreply $sockname 1
      halt
    }
  halt }
  elseif ($1 == PING) {
    if ($hget(pingreply,$sockname)) { hdel pingreply $sockname | hinc -c pingreply $sockname 1 }
    if (!$2) { sockwrite -n $sockname $+(:,$ircd(server)) 409 $hget($sockname,nick) :No origin specified | halt }
    sockwrite -n $sockname $+(:,$ircd(server)) PONG $ircd(server) $iif($left($2,1) == :,$2,$+(:,$2))       
  halt }
  if ($1 == CAP) { halt }
  if ($hget($sockname,level) !== uline) && ($sock($sockname)) && (!$hget($sockname,realhost) || (!$hget($sockname,host)) || (!$hget($sockname,nick)) || (!$gettok($hget($sockname,host),2,33)) || (!$hget($sockname,ident))) {
    sockwrite -n $sockname $+(:,$ircd(server)) 462 $hget($sockname,nick) $+(:,$upper($1)) You have not registered
    snotice $sockname * If you having problems while connecting, please try reconnecting.
  halt }
  elseif ($1 == CYCLE) {
    if (!$hget($sockname,host)) { halt }
    if (!$2) { cmd.fail $sockname $1 | halt }
    spart $sockname $2 :Cycling
    sjoin $sockname $2-
  halt }
  elseif ($1 == PART) {
    if (!$hget($sockname,host)) { halt }
    if (!$2) { cmd.fail $sockname $1 | halt }
    spart $sockname $2 $remove($3-,SAPART:)
  halt }
  elseif ($1 == QUIT) {
    hinc -m data disconnects
    if (($2) && ($calc($ctime - $hget($sockname,signon)) >= 60)) { var %quitmsg = $iif($left($2-,1) == $chr(58),$right($2-,-1),$2-) }
    squit $sockname $$iif($hget(settings,quitprefix) ,$v1 $chr(32),$+(Quit:,$chr(32))) $iif(%quitmsg,$v1)
  halt }
  elseif ($1 == NOTICE) {
    if (($2 === $ircd(server) || $2 === undefined) && (VERSION isincs $3)) {
      if (!$hget($sockname,vrsvl)) hadd $sockname vrsvl true
      if ($4 === mIRC) { hadd -m mirc $sockname true }
    halt }
    if (!$hget($sockname,host)) { halt }
    if (!$3) { cmd.fail $sockname $1 | halt }
    if ($3 !=== :LAGCHK) { hadd -m $sockname idle $ctime }
    if ($hget(defcon)) && (!$hget($sockname,loggedin)) { snotice $sockname * This server is in DEFCON mode, log in to send notice's | halt }
    var %n = 1
    while (%n <= $calc($count($2,$chr(44)) + 1)) {
      if ($left($gettok($gettok($2,%n,44),1,32),1) != $chr(35) && $left($gettok($gettok($2,%n,44),1,32),1) != $chr(43)) && (!$hfind(nicks,$gettok($gettok($2,%n,44),1,32))) && ($gettok($gettok($2,%n,44),1,32) !== $ircd(server)) { sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $gettok($gettok($2,%n,44),1,32) :No such nick
      goto noticeend }
      if ($left($gettok($gettok($2,%n,44),1,32),1) = $chr(35) || $left($gettok($gettok($2,%n,44),1,32),1) = $chr(43)) && (!$hfind(channels,$gettok($gettok($2,%n,44),1,32))) { sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $gettok($gettok($2,%n,44),1,32) :No such channel
      goto noticeend }
      if ($hget($gettok($gettok($2,%n,44),1,32),$sockname) == .i) {
        sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($gettok($2,%n,44),1,32) :You are invisible on channel $gettok($gettok($2,%n,44),1,32) so please shut up. To undo, type: /INVISIBLE $+(-,$gettok($gettok($2,%n,44),1,32))
      goto noticeend }
      if ($hfind($+(+z_,$gettok($gettok($2,%n,44),1,32)),$sockname)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($gettok($2,%n,44),1,32) :You cannot speak (+z $hget($sockname,nick) $+ ) | goto noticeend }
      if (*n* iswmcs $hget(modes,$gettok($gettok($2,%n,44),1,32))) && (!$hfind($gettok($gettok($2,%n,44),1,32),$sockname)) {
        sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($gettok($2,%n,44),1,32) :No external channel messages (+n) ( $+ $gettok($gettok($2,%n,44),1,32) $+ )
      goto noticeend }
      if (*m* iswmcs $hget(modes,$gettok($gettok($2,%n,44),1,32))) && (!$hfind($+(+v_,$gettok($gettok($2,%n,44),1,32)),$sockname)) && (!$hfind($+(+h_,$gettok($gettok($2,%p,44),1,32)),$sockname)) && (!$hfind($+(+o_,$gettok($gettok($2,%n,44),1,32)),$sockname)) && (!$hfind($+(+a_,$gettok($gettok($2,%n,44),1,32)),$sockname)) && (!$hfind($+(+q_,$gettok($gettok($2,%n,44),1,32)),$sockname)) {
        sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($gettok($2,%n,44),1,32) :Channel is moderated, you need voice (+v) ( $+ $gettok($gettok($2,%p,44),1,32) $+ )
      goto noticeend }
      var %y = 1
      while $ini(spamfilter.conf,%y) {
        if (*N* iswmcs $readini(spamfilter.conf,$ini(spamfilter.conf,%y),type)) && ($ini(spamfilter.conf,%y) isin $3-) && ($hget($sockname,ircop) !== true) {
          if ($readini(spamfilter.conf,$ini(spamfilter.conf,%y),action) == block) {
            sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($gettok($2,%n,44),1,32) Message blocked: $readini(spamfilter.conf,$ini(spamfilter.conf,%y),reason)
            sno F *** Spamfilter Blockage -- Spamfilter match by $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) in $gettok($gettok($2,%n,44),1,32) matching $ini(spamfilter.conf,%y) $+([,$3-])
          goto noticeend }
          if ($readini(spamfilter.conf,$ini(spamfilter.conf,%y),action) == report) {
            sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($gettok($2,%n,44),1,32) Message blocked: $readini(spamfilter.conf,$ini(spamfilter.conf,%y),reason)
            sno F *** Spamfilter Report -- Spamfilter match by $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) in $gettok($gettok($2,%n,44),1,32) matching $ini(spamfilter.conf,%y) $+([,$3-])
          }
          hadd -m $sockname idle $ctime
          ;hdel $sockname idle
          ;hinc -c $sockname idle
          if ($readini(spamfilter.conf,$ini(spamfilter.conf,%y),action) == replace) {
            var %x = 1
            while ($hget($gettok($gettok($2,%n,44),1,32),%x).item) {
              if ($sock($hget($gettok($gettok($2,%n,44),1,32),%x).item)) {
              sockwrite -n $hget($gettok($gettok($2,%n,44),1,32),%x).item $+(:,$hget($sockname,host)) NOTICE $gettok($gettok($2,%n,44),1,32) $iif(*S* iswmcs $hget(modes,$3) && !$ocheck($sockname,o,v),$strip($replace($3-,$ini(spamfilter.conf,%y),<censored>)),$replace($3-,$ini(spamfilter.conf,%y),<censored>)) }
              if ($left($gettok($gettok($2,%n,44),1,32),1) != $chr(35) && $left($gettok($gettok($2,%n,44),1,32),1) != $chr(43)) && ($hget(away,$hget($gettok($gettok($2,%n,44),1,32),1).item)) { sockwrite -n $sockname $+(:,$ircd(server)) 301 $hget($sockname,nick) $gettok($gettok($2,%n,44),1,32) $hget(away,$hget($gettok($gettok($2,%n,44),1,32),1).item) }
            inc %x }
          goto noticeend }
        }
        inc %y
      }
      if ($left($gettok($gettok($2,%n,44),1,32),1) = $chr(35)) || ($left($gettok($gettok($2,%n,44),1,32),1) = $chr(43)) {
        if ($hget(noticefprot,$gettok($gettok($2,%n,44),1,32))) && (%notices. [ $+ [ $gettok($gettok($2,%n,44),1,32) ] ] >= $gettok($hget(noticefprot,$2),1,32)) {
          snotice $sockname * Don't flood! Channel notices are blocked for $gettok($hget(noticefprot,$gettok($gettok($2,%n,44),1,32)),2,32) seconds
        goto noticeend }
        if ($hget(noticefprot,$gettok($gettok($2,%n,44),1,32))) {
        inc %notices. [ $+ [ $gettok($gettok($2,%n,44),1,32) ] ] }
        if (%notices. [ $+ [ $2 ] ] = 1) {
          .timernoticef $+ $gettok($gettok($2,%n,44),1,32) 1 $gettok($hget(noticefprot,$gettok($gettok($2,%n,44),1,32)),1,32) unset %notices. [ $+ [ $gettok($gettok($2,%n,44),1,32) ] ] 
        }
      }
      var %x = 1
      while ($hget($gettok($gettok($2,%n,44),1,32),%x).item) {
        if ($sock($hget($gettok($gettok($2,%n,44),1,32),%x).item)) {
          sockwrite -n $hget($gettok($gettok($2,%n,44),1,32),%x).item $+(:,$hget($sockname,host)) NOTICE $gettok($gettok($2,%n,44),1,32) $iif(*S* iswmcs $hget(modes,$2) || *S* iswmcs $hget($hget($gettok($gettok($2,%n,44),1,32),%x).item,modes) && !$ocheck($sockname,o,v),$strip($3-),$3-)
        }
        inc %x
      }
      :noticeend
      ;if ($3 === :LAGCHK) { sockwrite -n $hget($2,1).item $+(:,$ircd(server)) NOTICE $2- }
      sno i *** Idle Notice -- The idle of $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) has been reset (/NOTICE $gettok($gettok($2,%n,44),1,32) $+ )
      inc %n
    }
    halt
  }
  elseif ($1 == MOTD) { motd $sockname | halt }
  elseif ($1 == ADMIN) {
    sockwrite -n $sockname $+(:,$ircd(server)) 256 $hget($sockname,nick) :Administrative info about $ircd(server)
    sockwrite -n $sockname $+(:,$ircd(server)) 257 $hget($sockname,nick) $+(:,$readini(ircd.conf,admin,nick))
    sockwrite -n $sockname $+(:,$ircd(server)) 257 $hget($sockname,nick) $+(:,$readini(ircd.conf,admin,email))
    sockwrite -n $sockname $+(:,$ircd(server)) 257 $hget($sockname,nick) $+(:,$readini(ircd.conf,admin,web))
  halt }
  elseif ($1 == NAMES) { names $sockname $2 | halt }
  elseif ($1 == CLONES) {
    if (!$hget($sockname,ircop)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator
    halt }
    sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Clones on $ircd(server) $+ :
    sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :-
    var %x = 1
    while ($hget(users,%x).item) {
      if ($hget($sock($hget(users,%x).item).ip,logins) > 1) {
        var %n = 1
        while ($hget($sock($hget(users,%x).item).ip,%n).item) && (!%showed. [ $+ [ $sock($hget(users,%x).item).ip ] ]) {
          if ($hget($sock($hget(users,%x).item).ip,%n).item !== logins) && ($hget($hget($sock($hget(users,%x).item).ip,%n).item,nick)) && ($hget($hget($sock($hget(users,%x).item).ip,%n).item,realhost)) {
            inc %clonesnr. [ $+ [ $sock($hget(users,%x).item).ip ] ]
            set %clones. [ $+ [ $sock($hget(users,%x).item).ip ] ] %clones. [ $+ [ $sock($hget(users,%x).item).ip ] ] $iif($hget($hget($sock($hget(users,%x).item).ip,%n).item,nick),$hget($hget($sock($hget(users,%x).item).ip,%n).item,nick),$hget($sock($hget(users,%x).item).ip,%n).item)
          }
          inc %n
        }
        if (%clones. [ $+ [ $sock($hget(users,%x).item).ip ] ]) {
          set -u0 %realhost. [ $+ [ $sock($hget(users,%x).item).ip ] ] $gettok($hget($hget($sock($hget(users,%x).item).ip,%n).item,realhost),2-,33)
          sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :* Found %clonesnr. [ $+ [ $sock($hget(users,%x).item).ip ] ] clones from IP address $+($sock($hget(users,%x).item).ip,:)
          sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Nicks: %clones. [ $+ [ $sock($hget(users,%x).item).ip ] ]
          sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :-
          set -u0 %showed. [ $+ [ $sock($hget(users,%x).item).ip ] ] true
        }
        unset %clones. [ $+ [ $sock($hget(users,%x).item).ip ] ] %clonesnr. [ $+ [ $sock($hget(users,%x).item).ip ] ]
        var %clones = true
      }
      inc %x
    }
    if (!%clones) { sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :No clones found on this server. }
    sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :End of /CLONES command.
  halt }
  elseif ($1 == TRACE) {
    if ($hget($sockname,ircop) != true) { sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*T* !iswmcs $hget($sockname,flags)) { sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges | halt }
    if (!$2) { cmd.fail $sockname $1 | halt }
    if (!$hfind(nicks,$2)) { sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :User not online | halt }
    else {
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :~~~~~~~~~~~~~~~~~~~~~~
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Information on user $+(,$hfind(nicks,$2),)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Connection time: $duration($sock($hget($2,1).item).to)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Bytes received: $sock($hget($2,1).item).rcvd
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Bytes sent: $sock($hget($2,1).item).sent
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :IP is connected: $hget($sock($hget($2,1).item).ip,logins) time(s)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Authed as: $iif($hget($hget($2,1).item,loggedin),$hget($hget($2,1).item,loggedin),not authed.)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Client is $iif(!$hget($hget($2,1).item,ircop),not) an IRC Operator $iif($hget($sock($hget($2,1).item),ircop),[logged in as $+($hget($hget($2,1).item,ologin),]),[not logged in])
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Username $+(",$hfind(nicks,$2),") is $iif(!$ini(opers.conf,$2),not) in Oper block.
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Usermodes: $hget($sock($hget($2,1).item),modes)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Snomasks: $iif($hget($sock($hget($2,1).item),snomasks),$v1,none)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Operflags: $iif($hget($sock($hget($2,1).item),flags),$v1,none)
      var %i 1, %chans, %amount 0 | while %i <= $hget(channels,0).item {
        if ($hget($hget(channels,%i).item,$hget($2,1).item)) {
          if (*s* !iswmcs $hget(modes,$hget(channels,%i).item)) { var %chans = %chans $hget(channels,%i).item | inc %amount }
        }
      inc %i }
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :In $iif(%amount >= 1,%amount,no) channels $iif(%chans,$chr(91) $+ %chans $+ $chr(93))
      if %amount = 0 { continue }
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Last used command: $hget($sock($hget($2,1).item),lastusedcommand)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Connected via: $gettok($gettok($hget($sock($hget($2,1).item),realhost),2,33),2,64) $chr(91) $+ $sock($hget($2,1).item).ip $+ $chr(93)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Cloaked host: $gettok($gettok($hget($sock($hget($2,1).item),host),2,33),2,64)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Ident: $gettok($gettok($hget($sock($hget($2,1).item),host),2,33),1,64)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Realname: $hget($sock($hget($2,1).item),realname)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Continent: $iif($hget(ipdata,$+(continent_,$sock($hget($2,1).item).ip)),$v1,unknown)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Country: $iif($hget(ipdata,$+(country_,$sock($hget($2,1).item).ip)),$v1,unknown)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Capital: $iif($hget(ipdata,$+(capital_,$sock($hget($2,1).item).ip)),$v1,unknown)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :State: $iif($hget(ipdata,$+(state_,$sock($hget($2,1).item).ip)),$v1,unknown)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :City: $iif($hget(ipdata,$+(city_,$sock($hget($2,1).item).ip)),$v1,unknown)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Postal: $iif($hget(ipdata,$+(postal_,$sock($hget($2,1).item).ip)),$v1,unknown)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :ISP: $iif($hget(ipdata,$+(isp_,$sock($hget($2,1).item).ip)),$v1,unknown)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Organization: $iif($hget(ipdata,$+(organization_,$sock($hget($2,1).item).ip)),$v1,unknown)
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :** PLEASE ENTER /QUIT IF YOU DON'T LIKE THIS **
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :End of /TRACE command.
    }
  halt }
  elseif ($1 == MODE) {
    unset %param %params %t.modes %modes %omodes
    if (!$2) { cmd.fail $sockname $1 | halt }
    if ($left($2,1) = $chr(35)) || ($left($2,1) = $chr(43)) {
      if (!$3) {
        if ($hfind($2,$sockname)) {
          var %x = 1
          while ($mid($hget(modes,$2),%x,1)) {
            if ($mid($hget(modes,$2),%x,1) === k) { set %chkl %chkl $hget(data,$+(key_,$2)) }
            if ($mid($hget(modes,$2),%x,1) === l) { set %chkl %chkl $hget(data,$+(limit_,$2)) }
            inc %x
          }
          sockwrite -n $sockname $+(:,$ircd(server)) 324 $hget($sockname,nick) $2 $+(+,$remove($hget(modes,$2),+)) $iif($hfind($2,$sockname),%chkl)
          sockwrite -n $sockname $+(:,$ircd(server)) 329 $hget($sockname,nick) $2 $hget($2,ctime)
          unset %chkl
          hsave -b modes data\chmodes.db
          halt
        }
        halt
      }
      if ($3) {
        unset %ov. [ $+ [ $sockname ] ]
        smode $sockname $2 $3-
      }
      halt
    }
    elseif ($2 !== $hget($sockname,nick)) && ($ocheck($sockname,o,v)) {
      if (!$hfind(nicks,$2)) {
        sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $2 :No such nick
        halt
      } 
      %sockname = $sockname
      chgumode $sockname $hget($2,1).item $3- - $hget($sockname,nick) ^
      halt
    }
    elseif ($2 == $hget($sockname,nick)) && ($hget($sockname,host)) {
      if (!$istok(+ -,$left($3,1),32)) { sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :MODE Insufficient parameters you foolish user | halt }
      chgumode $sockname $sockname $3-
    }
  halt }
  elseif ($1 == KICK) {
    if (!$3) { cmd.fail $sockname $1 | halt }
    if ($left($2,1) != $chr(35)) && ($left($2,1) != $chr(43)) { sockwrite -n $sockname $+(:,$ircd(server)) 403 $hget($sockname,nick) $2 :is not a valid channel | halt }
    if (!$hget($2,$hget($3,1).item)) || (!$hfind(nicks,$3)) || ($hget($2,$hget($3,1).item) == .i) { sockwrite -n $sockname $+(:,$ircd(server)) 441 $hget($sockname,nick) $3 :User not on that channel | halt }
    if (*v* iswmcs $hget($sockname,flags)) { goto skickend }
    if (!$hget($2,$sockname)) { sockwrite -n $sockname $+(:,$ircd(server)) 442 $hget($sockname,nick) $2 :You're not on that channel | halt }
    if (!$hfind($+(+h_,$2),$sockname)) && (!$hfind($+(+o_,$2),$sockname)) && (!$hfind($+(+a_,$2),$sockname)) && (!$hfind($+(+q_,$2),$sockname)) && (!$hfind($+(+O2_,$2),$sockname)) && (!$ocheck($sockname,o,v)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 :Don't you miss your @, $+($hget($sockname,nick),?)
    halt }
    if (!$ip_aq) && (!$hfind($+(+o_,$2),$sockname)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 :Don't you miss your @, $+($hget($sockname,nick),?)
      halt    
    }
    if (Q isincs $hget(modes,$2)) && (!$ocheck($sockname,o,v)) { sockwrite -n $sockname $+(:,$ircd(server)) 972 $hget($sockname,nick) KICK :channel is +Q | halt }    
    if ($hfind($+(+q_,$2),$hget($3,1).item)) && (!$ocheck($sockname,o,v)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 972 $hget($sockname,nick) KICK $+(:,$hfind(nicks,$3)) is the channel owner
    halt }
    if ($hfind($+(+o_,$2),$sockname) && $hfind($+(+a_,$2),$hget($3,1).item) || $hfind($+(+q_,$2),$hget($3,1).item)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 972 $hget($sockname,nick) KICK $+(:,$hfind(nicks,$3)) is $iif($hfind($+(+a_,$2),$hget($3,1).item),a channel admin,the channel owner)
    halt }
    if ($hfind($+(+O2_,$2),$hget($3,1).item)) && (!$ocheck($sockname,o,v)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 442 $hget($sockname,nick) $hfind(nicks,$3) :Protected Channel Operator
      sockwrite -n $hget($3,1).item $+(:,$ircd(server)) NOTICE $3 :*** Channel -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) tried to kick you off channel $2 $+([,$4-,])
    halt }
    if (q isincs $hget($hget($3,1).item,modes)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 442 $hget($sockname,nick) $hfind(nicks,$3) :Protected IRC Operator
      sockwrite -n $hget($3,1).item $+(:,$ircd(server)) NOTICE $3 :*** Server Notice -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) tried to kick you off channel $2 $+([,$4-,])
    halt }
    :skickend
    if ($hget($2,$hget($3,1).item)) { skick $sockname $2- | halt }
  halt }
  elseif ($1 == INVITE) {
    if (!$3) { cmd.fail $sockname $1 | halt }
    if (!$hfind(nicks,$2)) { sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $2 :No such nick | halt }
    if (!$hfind(channels,$3)) { sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $3 :No such channel | halt }
    if (!$hfind($3,$sockname)) { sockwrite -n $sockname $+(:,$ircd(server)) 442 $hget($sockname,nick) $3 :You're not on that channel | halt }
    if ($ocheck($sockname,o,v)) { goto invend }
    if (*V* iswmcs $hget(modes,$3)) && (!$hfind($+(+o_,$3),$sockname)) && (!$hfind($+(+a_,$3),$sockname)) && (!$hfind($+(+q_,$3),$sockname)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 518 $hget($sockname,nick) :Cannot invite (+V) at channel $3
      if (*N* iswmcs $hget(modes,$3)) {
        var %z = 1
        while $hget($3,%z).item {
          if ($hfind($+(+o_,$3),$hget($3,%z).item)) || ($hfind($+(+a_,$3),$hget($3,%z).item)) || ($hfind($+(+q_,$3),$hget($3,%z).item)) {
            sockwrite -n $hget($3,%z).item $+(:,$ircd(server)) NOTICE $+(@,$3) :User $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) tried to invite $hfind(nicks,$2) into the channel but invites are not allowed. (+V)
          }
        inc %z }
      }
    halt } 
    if ($hfind($3,$hget($2,1).item)) { sockwrite -n $sockname $+(:,$ircd(server)) 443 $hget($sockname,nick) $hfind(nicks,$2) :is already on channel $3 | halt }
    :invend
    sockwrite -n $hget($2,1).item $+(:,$hget($sockname,host)) INVITE $hfind(nicks,$2) $3
    sockwrite -n $sockname $+(:,$ircd(server)) 341 $hget($sockname,nick) $hfind(nicks,$2) $3
    hadd -m $+(invites_,$3) $hget($2,1).item
    if (*N* iswmcs $hget(modes,$3)) {
      var %z = 1
      while $hget($3,%z).item {
        if ($hfind($+(+o_,$3),$hget($3,%z).item)) || ($hfind($+(+a_,$3),$hget($3,%z).item)) || ($hfind($+(+q_,$3),$hget($3,%z).item)) {
          sockwrite -n $hget($3,%z).item $+(:,$ircd(server)) NOTICE $+(@,$3) :User $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) invited $hfind(nicks,$2) into the channel.
        }
      inc %z }
    }
  halt }
  elseif ($1 == TOPIC) {
    if (!$2) { cmd.fail $sockname $1 | halt }
    if ($left($2,1) != $chr(35)) && ($left($2,1) != $chr(43)) { sockwrite -n $sockname $+(:,$ircd(server)) 403 $hget($sockname,nick) $2 :is not a valid channel | halt }
    if (!$hget($2,$sockname)) { sockwrite -n $sockname $+(:,$ircd(server)) 442 $hget($sockname,host) $2 :You're not on that channel. | halt }
    if (!$hget(topics,$+(topic_,$2))) && (!$3) { sockwrite -n $sockname $+(:,$ircd(server)) 331 $hget($sockname,nick) $2 :No topic is set. | halt }
    if ($hget(topics,$+(topic_,$2))) && (!$3) { sockwrite -n $sockname $+(:,$ircd(server)) 332 $hget($sockname,nick) $2 : $+ $hget(topics,$+(topic_,$2))
      sockwrite -n $sockname $+(:,$ircd(server)) 333 $hget($sockname,nick) $2 $hget(topics,$+(topicsetter_,$2)) $hget(topics,$+(topicdate_,$2))
    halt }
    if ($ocheck($sockname,o,v)) { goto stopicend }
    if (*t* iswmcs $hget(modes,$2)) {
      if (!$hfind($+(+o_,$2),$sockname)) && (!$hfind($+(+a_,$2),$sockname)) && (!$hfind($+(+q_,$2),$sockname)) && (!$hfind($+(+O2_,$2),$sockname)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 :Don't you miss your @, $+($hget($sockname,nick),?) | halt }
    }
    :stopicend
    if ($hget(rchans,$+(topiclock_,$2))) && (!$ocheck($sockname,o,v)) { snotice $sockname * You can't change the topic on this channel. | halt }
    if ($len($3-) > $hget(settings,maxtopiclen)) { snotice $sockname * The topic you gave for channel $2 was too long. The topic has been shorten. }
    stopic $sockname $2 $3-
    halt
  }
  elseif ($1 == PRIVMSG) {
    if (!$3) { cmd.fail $sockname $1 | halt }
    if ($hget(defcon)) && (!$hget($sockname,loggedin)) { snotice $sockname * This server is in DEFCON mode, log in to send privmsg's | halt }
    hadd -m $sockname idle $ctime
    ;hdel $sockname idle
    ;hinc -c $sockname idle
    var %p = 1
    if ($3-4 ===  $+(:,$chr(1),DCC SEND)) && ($10) { closelink $sockname Possible DCC exploit attempt | halt }
    if ($hget($hget($2,1).item,level) == uline) && ($hget(ulinesocket,$2)) { sockwrite -n $hget(ulinesocket,$2) $+(:,$hget($sockname,nick)) PRIVMSG $2 $3- }
    while %p <= $calc($count($2,$chr(44)) + 1) {
      if ($hget($gettok($gettok($2,%p,44),1,32),$hget(chanserv,1).item)) { sockwrite -n $hget(ulinesocket,chanserv) $+(:,$hget($sockname,nick)) PRIVMSG $2 $3- }
      if ($left($gettok($gettok($2,%p,44),1,32),1) !== $chr(35) && $left($gettok($gettok($2,%p,44),1,32),1) !== $chr(43)) && (!$hfind(nicks,$gettok($gettok($2,%p,44),1,32))) { sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $gettok($gettok($2,%p,44),1,32) :No such nick
      goto privmsgend }
      if ($left($gettok($gettok($2,%p,44),1,32),1) == $chr(35) || $left($gettok($gettok($2,%p,44),1,32),1) == $chr(43)) && (!$hfind(channels,$gettok($gettok($2,%p,44),1,32))) { sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $gettok($gettok($2,%p,44),1,32) :No such channel
      goto privmsgend }
      if ($hget($gettok($gettok($2,%p,44),1,32),$sockname) == .i * FUNCTION DISABLED *) {
        sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($gettok($2,%p,44),1,32) :You are invisible on channel $gettok($gettok($2,%p,44),1,32) so please shut up. To undo, type: /INVISIBLE $+(-,$gettok($gettok($2,%p,44),1,32))
        goto privmsgend
      }
      isban $sockname $gettok($gettok($2,%p,44),1,32)
      if (%ban. [ $+ [ $sockname ] ]) { unset %ban. [ $+ [ $sockname ] ]
        sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($gettok($2,%p,44),1,32) :You are banned ( $+ $gettok($gettok($2,%p,44),1,32) $+ )
      goto privmsgend }
      if ($hfind($+(+z_,$gettok($gettok($2,%p,44),1,32)),$sockname)) {
        sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($gettok($2,%p,44),1,32) :You cannot speak (+z $hget($sockname,nick) $+ )
      goto privmsgend }
      if (*n* iswmcs $hget(modes,$gettok($gettok($2,%p,44),1,32))) && (!$hfind($gettok($gettok($2,%p,44),1,32),$sockname)) {
        sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($gettok($2,%p,44),1,32) :No external channel messages (+n) ( $+ $gettok($gettok($2,%p,44),1,32) $+ )
      goto privmsgend }
      if (*m* iswmcs $hget(modes,$gettok($gettok($2,%p,44),1,32))) && (!$hfind($+(+v_,$gettok($gettok($2,%p,44),1,32)),$sockname)) && (!$hfind($+(+h_,$gettok($gettok($2,%p,44),1,32)),$sockname)) && (!$hfind($+(+o_,$gettok($gettok($2,%p,44),1,32)),$sockname)) && (!$hfind($+(+a_,$gettok($gettok($2,%p,44),1,32)),$sockname)) && (!$hfind($+(+q_,$gettok($gettok($2,%p,44),1,32)),$sockname)) && (*o* !iswmcs $hget($sockname,omodes)) {
        sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($gettok($2,%p,44),1,32) :Channel is moderated, you need voice (+v) ( $+ $gettok($gettok($2,%p,44),1,32) $+ )
      goto privmsgend }
      if (*a* iswmcs $hget(modes,$gettok($gettok($2,%p,44),1,32))) && ($gettok($2,0,44) > 1) && (!$ocheck($sockname,o,v)) {
        sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($gettok($2,%p,44),1,32) :/AMSG and /AME commands are blocked (+a) ( $+ $gettok($gettok($2,%p,44),1,32) $+ )
      goto privmsgend }
      if (*C* iswmcs $hget(modes,$gettok($gettok($2,%p,44),1,32))) && ($chr(1) isin $3-) && ($left($right($3,-1),7) !== $+($chr(1),ACTION)) && (!$ocheck($sockname,o,v)) {
        sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($gettok($2,%p,44),1,32) :CTCPs are not permitted in this channel ( $+ $gettok($gettok($2,%p,44),1,32) $+ )
        goto privmsgend
      }
      if ($hget(msgfprot,$gettok($gettok($2,%p,44),1,32))) { if (%msgs. [ $+ [ $gettok($gettok($2,%p,44),1,32) ] ] >= $gettok($hget(msgfprot,$gettok($gettok($2,%p,44),1,32)),1,32)) {
          snotice $sockname * Don't flood! Channel messages are blocked for $gettok($hget(msgfprot,$gettok($gettok($2,%p,44),1,32)),2,32) seconds
        goto privmsgend }
      }
      if ($hget(msgfprot,$gettok($gettok($2,%p,44),1,32))) { inc %msgs. [ $+ [ $gettok($gettok($2,%p,44),1,32) ] ] }
      if (%msgs. [ $+ [ $gettok($gettok($2,%p,44),1,32) ] ] == 1) .timermsgf $+ $gettok($gettok($2,%p,44),1,32) 1 $gettok($hget(msgfprot,$2),1,32) unset %msgs. [ $+ [ $gettok($gettok($2,%p,44),1,32) ] ]
      var %y = 1
      while ($ini(spamfilter.conf,%y)) {
        if (*P* iswmcs $readini(spamfilter.conf,$ini(spamfilter.conf,%y),type)) && ($ini(spamfilter.conf,%y) isin $3-) && ($hget($sockname,ircop) != true) {
          if ($readini(spamfilter.conf,$ini(spamfilter.conf,%y),action) == block) {
            sockwrite -n $sockname $+(:,$ircd(server)) 404 $hget($sockname,nick) $gettok($gettok($2,%p,44),1,32) Message blocked: $readini(spamfilter.conf,$ini(spamfilter.conf,%y),reason)
            sno F *** Spamfilter Blockage -- Spamfilter match by $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) in channel $gettok($gettok($2,%p,44),1,32) matching $ini(spamfilter.conf,%y) $+([,$3-])
            inc %x
            goto privmsgend
          }
          if ($readini(spamfilter.conf,$ini(spamfilter.conf,%y),action) == report) {
            sno F *** Spamfilter Report -- Spamfilter match by $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) in channel $gettok($gettok($2,%p,44),1,32) matching $ini(spamfilter.conf,%y) $+([,$3-])
            inc %x
          }
          if ($readini(spamfilter.conf,$ini(spamfilter.conf,%y),action) == replace) {
            var %x = 1
            while ($hget($gettok($gettok($2,%p,44),1,32),%x).item) {
              if ($hget($gettok($gettok($2,%p,44),1,32),%x).item !== $sockname) {
                if ($sock($hget($gettok($gettok($2,%p,44),1,32),%x).item)) {
                sockwrite -n $hget($gettok($gettok($2,%p,44),1,32),%x).item $+(:,$hget($sockname,host)) PRIVMSG $gettok($gettok($2,%p,44),1,32) $iif(*S* iswmcs $hget(modes,$3) && !$ocheck($sockname,o,v),$strip($replace($3-,$ini(spamfilter.conf,%y),<censored>)),$replace($3-,$ini(spamfilter.conf,%y),<censored>)) }
              }
              if ($left($gettok($gettok($2,%p,44),1,32),1) !== $chr(35)) && ($hget(away,$hget($gettok($gettok($2,%p,44),1,32),1).item)) { sockwrite -n $sockname $+(:,$ircd(server)) 301 $hget($sockname,nick) $gettok($gettok($2,%p,44),1,32) $hget(away,$hget($gettok($gettok($2,%p,44),1,32),1).item) }
            inc %x }
          goto privmsgend }
        }
        inc %y
      }
      var %x = 1
      while ($hget($gettok($gettok($2,%p,44),1,32),%x).item) {
        if ($left($gettok($gettok($2,%p,44),1,32),1) == $chr(35)) || ($left($gettok($gettok($2,%p,44),1,32),1) = $chr(43)) && ($hget($gettok($gettok($2,%p,44),1,32),%x).item != $sockname) {
          if ($sock($hget($gettok($gettok($2,%p,44),1,32),%x).item)) {
            var %msg = $iif(*S* iswmcs $hget(modes,$gettok($gettok($2,%p,44),1,32)) || *S* iswmcs $hget($hget($gettok($gettok($2,%p,44),1,32),%x).item,modes),$strip($3-),$3-)
            sockwrite -n $hget($gettok($gettok($2,%p,44),1,32),%x).item $+(:,$hget($sockname,host)) PRIVMSG $gettok($gettok($2,%p,44),1,32) %msg
          }
        }
        if ($left($gettok($gettok($2,%p,44),1,32),1) !== $chr(35)) && ($left($gettok($gettok($2,%p,44),1,32),1) != $chr(43)) {
          if ($sock($hget($gettok($gettok($2,%p,44),1,32),%x).item)) { sockwrite -n $hget($gettok($gettok($2,%p,44),1,32),%x).item $+(:,$hget($sockname,host)) PRIVMSG $gettok($gettok($2,%p,44),1,32) $iif(*S* iswmcs $hget($hget($2,1).item,modes),$strip($3-),$3-) }
          if ($hget(away,$hget($gettok($gettok($2,%p,44),1,32),1).item)) { sockwrite -n $sockname $+(:,$ircd(server)) 301 $hget($sockname,nick) $gettok($gettok($2,%p,44),1,32) $hget(away,$hget($gettok($gettok($2,%p,44),1,32),1).item) }
        }
      inc %x }
      :privmsgend
      sno i *** Idle Notice -- The idle of $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) has been reset (/PRIVMSG $gettok($gettok($2,%p,44),1,32) $+ )
      inc %p
    }
    halt
  }
  elseif ($1 == WHOWAS) {
    if (!$2) { sockwrite -n $sockname $+(:,$ircd(server)) 431 $hget($sockname,nick) :No nickname given | halt }
    if (!$hget(whowas_ $+ $2)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $2 :There was no such nick
      sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $2 :is addicted to teh real world
      sockwrite -n $sockname $+(:,$ircd(server)) 369 $hget($sockname,nick) $2 :End of WHOWAS
      halt
    }
    else {
      sockwrite -n $sockname $+(:,$ircd(server)) 314 $hget($sockname,nick) $2 $+(:,$gettok($hget($+(whowas_,$2),host),2,33)) * $hget($+(whowas_,$2),realname)
      if ($hget($sockname,ircop)) { sockwrite -n $sockname $+(:,$ircd(server)) 378 $hget($sockname,nick) $2 :connected from $+(*@,$hget($+(whowas_,$2),realhost)) $hget($+(whowas_,$2),ip) }
      sockwrite -n $sockname $+(:,$ircd(server)) 312 $hget($sockname,nick) $2 $ircd(server) $+(:,$asctime($hget($+(whowas_,$2),date)))
      sockwrite -n $sockname $+(:,$ircd(server)) 369 $hget($sockname,nick) $2 :End of WHOWAS
    halt }
  }
  elseif ($1 == SWHOIS) {
    if (!$hget($sockname,ircop)) && (!$ocheck($sockname,o,v)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*o* !iswmcs $hget($sockname,modes)) && (*a* !iswmcs $hget($sockname,modes)) && (!$ocheck($sockname,o,v)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    halt }
    if (!$2) { sockwrite -n $sockname $+(:,$ircd(server)) 431 $hget($sockname,nick) :No nickname given
      halt
    }
    if (!$sock($sockname)) { halt }
    if (!$hfind(nicks,$2)) || (!$hget($2,1).item) || (*w* iswmcs $hget($hget($2,1).item,modes)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $2 :No such nick
      sockwrite -n $sockname $+(:,$ircd(server)) 320 $hget($sockname,nick) $2 :is somewhere in real life
      sockwrite -n $sockname $+(:,$ircd(server)) 318 $hget($sockname,nick) $2 :End of WHOIS
      halt
    }
    else {
      if (!$3) {
        hdel $hget($2,1).item swhois
        snotice $sockname SWHOIS of $hfind(nicks,$2) has been unset
        halt
      }
      else {
        hadd $hget($2,1).item swhois $3-
        snotice $sockname SWHOIS of $hfind(nicks,$2) has been set to: $hget($hget($2,1).item,swhois)
      }
    }
  }
  elseif ($1 == WHOIS) {
    if (!$2) { sockwrite -n $sockname $+(:,$ircd(server)) 431 $hget($sockname,nick) :No nickname given
      halt
    }
    if (!$sock($sockname)) { halt }
    if (!$hfind(nicks,$2)) || (!$hget($2,1).item) || (*w* iswmcs $hget($hget($2,1).item,modes) && *X* !iswmcs $hget($sockname,modes)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $2 :No such nick
      sockwrite -n $sockname $+(:,$ircd(server)) 320 $hget($sockname,nick) $2 :is somewhere in real life
      sockwrite -n $sockname $+(:,$ircd(server)) 318 $hget($sockname,nick) $2 :End of WHOIS
      halt
    }
    if ($hget($hget($2,1).item,level) == uline) {
      sockwrite -n $sockname $+(:,$ircd(server)) 311 $hget($sockname,nick) $hfind(nicks,$2) $hget($hget($2,1).item,ident) $gettok($hget($hget($2,1).item,host),2,64) * $hget($hget($2,1).item,realname)
      sockwrite -n $sockname $+(:,$ircd(server)) 313 $hget($sockname,nick) $hfind(nicks,$2) :is a Network Service
      sockwrite -n $sockname $+(:,$ircd(server)) 318 $hget($sockname,nick) $hfind(nicks,$2) : $+ End of /WHOIS $iif($2 == $hget(enforcer,nick),list.. found what you where looking for? = $+ $chr(41),list.)
      halt
    }
    ;if ($hget($hget($2,1).item,level) = uline) {
    ;sockwrite -n $sockname $+(:,$ircd(server)) 311 $hget($sockname,nick) $2 : $+ $gettok($hget($hget($2,1).item,host),2,33) * $hget($hget($2,1).item,realname)
    ;sockwrite -n $sockname $+(:,$ircd(server)) 312 $hget($sockname,nick) $2 $hget($hget($2,1).item,server) $+(:,$hget($hget($2,1).item,serverdesc))
    ;sockwrite -n $sockname $+(:,$ircd(server)) 318 $hget($sockname,nick) $2 : $+ End of /WHOIS $iif($2 == $hget(enforcer,nick),list.. found what you where looking for? = $+ $chr(41),list.)
    ;halt
    ;}
    if (*W* iswmcs $hget($hget($2,1).item,modes)) && ($hget($2,1).item !== $sockname) {
      sockwrite -n $hget($2,1).item $+(:,$ircd(server)) NOTICE $hfind(nicks,$2) :*** Server Notice -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) did a /WHOIS on you.
    }
    sockwrite -n $sockname $+(:,$ircd(server)) 311 $hget($sockname,nick) $hfind(nicks,$2) $gettok($gettok($hget($hget($hget($2,1).item),host),2,33),1,64) $gettok($gettok($hget($hget($hget($2,1).item),host),2,33),2,64) * $+(:,$hget($hget($2,1).item,realname))
    if ($hget($sockname,ircop)) || ($2 == $hget($sockname,nick)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 379 $hget($sockname,nick) $hfind(nicks,$2) using modes: $iif($hget($hget($2,1).item,hop) && ($hget($sockname,nick) !== $2),$removecs($hget($hget($2,1).item,modes),o,X,T,Z,c,h,l,q,s,v,I,W,H),$hget($hget($2,1).item,modes)) $iif(!$hget($hget($2,1).item,hop),$iif($hget($hget($2,1).item,snomasks) !== +,$hget($hget($2,1).item,snomasks))) }
    if (!$hget($hget($2,1).item,hop)) {
      if ($hget($sockname,ircop)) && ($hget($hget($2,1).item,flags)) {      
      sockwrite -n $sockname $+(:,$ircd(server)) 382 $hget($sockname,nick) $hfind(nicks,$2) using oper account: $hget($hget($2,1).item,ologin) with operflags: $hget($hget($2,1).item,flags) }
    }
    if ($hget($sockname,ircop)) || ($2 == $hget($sockname,nick)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 378 $hget($sockname,nick) $hfind(nicks,$2) :connecting from $+($iif($hget(settings,idwithrealhost),$hget($hget($2,1).item,ident),*),@,$gettok($hget($hget($2,1).item,realhost),2,64)) $sock($hget($2,1).item).ip }
    if (*r* iswmcs $hget($hget($2,1).item,modes)) && ($ircd(settings,services)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 307 $hget($sockname,nick) $hfind(nicks,$2) :is logged in as $hget($hget($2,1).item,loggedin) $iif(*w* iswmcs $hget($hget($2,1).item,modes) && *X* iswmcs $hget($sockname,modes),$+($chr(40),stealth,$chr(41))) }
    if (*c* !iswmcs $hget($hget($2,1).item,modes)) || ($hget($sockname,ircop)) {
      var %i 1, %chans, %amount 0
      while %i <= $hget(channels,0).item {
        if ($hget($hget(channels,%i).item,$hget($2,1).item)) {
          if ($hget($hget(channels,%i).item,$hget($2,1).item) == .i) && (*I* iswmcs $hget($sockname,flags)) {
            var %chans = %chans $+(!,$hget(channels,%i).item)
            inc %amount
          }
          if (*s* !iswmcs $hget(modes,$hget(channels,%i).item)) && ($hget($hget(channels,%i).item,$hget($2,1).item) !== .i) {
            set %chans %chans $+($iif(*c* iswmcs $hget(modes,$hget($2,1).item),?),$gettok($hget($hget(channels,%i).item,$hget($2,1).item),1,46),$hget(channels,%i).item)
            if ($hget($sockname,ircop)) && ($hget($hget(channels,%i).item,$hget($2,1).item) == .i) { set %chans %chans $+($iif(*c* iswmcs $hget(modes,$hget($2,1).item),?),$gettok($hget($hget(channels,%i).item,$hget($2,1).item),1,46),$hget(channels,%i).item) }
            inc %amount
          }
        }
        if ($len(%chans) >= 450) { sockwrite -n $sockname $+(:,$ircd(server)) 319 $hget($sockname,nick) $hfind(nicks,$2) $+(:,%chans) | var %chans }
        inc %i
      }
      if (%chans) { sockwrite -n $sockname $+(:,$ircd(server)) 319 $hget($sockname,nick) $hfind(nicks,$2) $+(:,%chans) }
    }
    sockwrite -n $sockname $+(:,$ircd(server)) 312 $hget($sockname,nick) $hfind(nicks,$2) $hget($hget($2,1).item,server) $+(:,$hget($hget($2,1).item,serverdesc))
    if ($hget(away,$hget($2,1).item)) { sockwrite -n $sockname $+(:,$ircd(server)) 301 $hget($sockname,nick) $hfind(nicks,$2) $hget(away,$hget($2,1).item) }
    if (*H* !iswmcs $hget($hget($2,1).item,modes)) || ($hget($sockname,ircop)) && (!$hget($hget($2,1).item,hop)) {
      if (*X* iswmcs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 313 $hget($sockname,nick) $hfind(nicks,$2) :is an IRC Administrator | goto e }
      if (*N* iswmcs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 313 $hget($sockname,nick) $hfind(nicks,$2) :is a Network Administrator | goto e }
      if (*T* iswmcs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 313 $hget($sockname,nick) $hfind(nicks,$2) :is a Technical Administrator | goto e }
      if (*A* iswmcs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 313 $hget($sockname,nick) $hfind(nicks,$2) :is a Server Administrator | goto e }
      if (*C* iswmcs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 313 $hget($sockname,nick) $hfind(nicks,$2) :is a Co Administrator | goto e }
      if (*o* iswmcs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 313 $hget($sockname,nick) $hfind(nicks,$2) :is an IRC Operator | goto e }
      if (*O* iswmcs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 313 $hget($sockname,nick) $hfind(nicks,$2) :is a Local Operator | goto e }
      if (*h* iswmcs $hget($hget($2,1).item,modes)) && (!$hget($hget($2,1).item,ircop)) { sockwrite -n $sockname $+(:,$ircd(server)) 313 $hget($sockname,nick) $hfind(nicks,$2) :is a Help Operator | goto e }
      :e
      if (*Z* iswmcs $hget($hget($2,1).item,modes)) && ($ircd(settings,services)) { sockwrite -n $sockname $+(:,$ircd(server)) 313 $hget($sockname,nick) $hfind(nicks,$2) :is a System Root Administrator | goto e2 }
      if (*a* iswmcs $hget($hget($2,1).item,modes)) && ($ircd(settings,services)) { sockwrite -n $sockname $+(:,$ircd(server)) 313 $hget($sockname,nick) $hfind(nicks,$2) :is a System Manager | goto e2 }
      if (*P* iswmcs $hget($hget($2,1).item,modes)) && ($ircd(settings,services)) { sockwrite -n $sockname $+(:,$ircd(server)) 313 $hget($sockname,nick) $hfind(nicks,$2) :is a System Operator | goto e2 }
      :e2
      if (*h* iswmcs $hget($hget($2,1).item,modes)) sockwrite -n $sockname $+(:,$ircd(server)) 310 $hget($sockname,nick) $hfind(nicks,$2) :is available for help
      if (*q* iswmcs $hget($hget($2,1).item,modes)) sockwrite -n $sockname $+(:,$ircd(server)) 320 $hget($sockname,nick) $hfind(nicks,$2) :is protected on all channels
    }
    if ($hget($hget($2,1).item,swhois)) { sockwrite -n $sockname $+(:,$ircd(server)) 320 $hget($sockname,nick) $hfind(nicks,$2) $+(:,$hget($hget($2,1).item,swhois)) }
    if ($md5($sock($hget($2,1).item).ip) == $hget(data,provisionip)) sockwrite -n $sockname $+(:,$ircd(server)) 320 $hget($sockname,nick) $hfind(nicks,$2) :connected via Provision Debugging PC
    sockwrite -n $sockname $+(:,$ircd(server)) 317 $hget($sockname,nick) $hfind(nicks,$2) $calc($ctime - $hget($hget($2,1).item,idle)) $hget($hget($2,1).item,signon) seconds idle, signon time
    sockwrite -n $sockname $+(:,$ircd(server)) 318 $hget($sockname,nick) $hfind(nicks,$2) :End of /WHOIS list.
  halt }
  elseif ($1 == AWAY) {
    if (!$2) { sockwrite -n $sockname $+(:,$ircd(server)) 305 $hget($sockname,nick) :You are no longer marked as being away.
      snotice $sockname Hi dude/babe, welcome back eh! ^.^/ How was your journey IRL?
    if ($hget(away,$sockname)) { hdel away $sockname } }
    else { sockwrite -n $sockname $+(:,$ircd(server)) 306 $hget($sockname,nick) :You have been marked as being away so get your ass away from here~!! o.0; | hadd away $sockname $2- }
  halt }
  elseif ($1 == LIST) {
    if ($2 == stop) { .timerlist. [ $+ [ $sockname ] ] off | sockwrite -n $sockname $+(:,$ircd(server)) 323 $hget($sockname,nick) :End of /LIST | halt }
    var %list. [ $+ [ $sockname ] ] = 0
    sockwrite -n $sockname $+(:,$ircd(server)) 321 $hget($sockname,nick) Channel :Users Name
    .timerlist. [ $+ [ $sockname ] ] -m 0 0 list $sockname
  halt }
  elseif ($1 == WHO) {
    var %pdelay = 0
    if ($2) && ($2 !== *) {
      var %i 1, %who.count 0
      while (%i <= $hget($2,0).item) {
        if (*i* iswmcs $hget($hget($2,%i).item,modes) && $hget($sockname,ircop) !== true) { inc %i }
        var %mds = $hget($hget($2,%i).item,modes)
        if ($hget($hget($2,%i).item,nick)) && (!%who. [ $+ [ $hget($2,%i).item ] ]) {
          var %who. [ $+ [ $hget($2,%i).item ] ] = 1
          inc %who.count
          if (%who.count > 1000) {
            sockwrite -n $sockname $+(:,$ircd(server)) 523 $hget($sockname,nick) :Error, /who limit of 1000 exceeded. Please narrow your search down and try again
            break
          }
          if ($sock($sockname).sq < 5000) {
            sockwrite -n $sockname $+(:,$ircd(server)) 352 $hget($sockname,nick) $2 $gettok($gettok($hget($hget($2,%i).item,host),1,64),2,33) $gettok($hget($hget($2,%i).item,host),2,64) $ircd(server) $hget($hget($2,%i).item,nick) $whomasks($hget($2,%i).item,$2) :0 $hget($hget($2,%i).item,realname)
          }
          else {
            inc %pdelay 10
            .timer -m 1 %pdelay sockwrite -n $sockname $+(:,$ircd(server)) 352 $hget($sockname,nick) $2 $gettok($gettok($hget($hget($2,%i).item,host),1,64),2,33) $gettok($hget($hget($2,%i).item,host),2,64) $ircd(server) $hget($hget($2,%i).item,nick) $whomasks($hget($2,%i).item,$2) :0 $hget($hget($2,%i).item,realname)
          }
        }
      inc %i }
      $$iif(%pdelay,.timer -m 1 %pdelay) sockwrite -n $sockname $+(:,$ircd(server)) 315 $hget($sockname,nick) $2 :End of /WHO list.
    halt }
    else {
      var %a 1, %who.count 1
      while (%a <= $hget(channels,0).item) {
        if (!$hget($hget(channels,%a).item,$sockname)) && (*v* !iswmcs $hget($sockname,flags)) { inc %a | continue }
        var %b 1
        while %b <= $hget($hget(channels,%a).item,0).item {
          var %mds = $right($hget($hget($hget(channels,%a).item,%b).item,modes),-1)
          if ($hget($hget($hget(channels,%a).item,%b).item,host)) && (!%who. [ $+ [ $hget($hget(channels,%a).item,%b).item ] ]) {
            var %who. [ $+ [ $hget($hget(channels,%a).item,%b).item ] ] = 1
            inc %who.count
            if (%who.count >= 1000) {
              sockwrite -n $sockname $+(:,$ircd(server)) 523 $hget($sockname,nick) :Error, /who limit of 1000 exceeded. Please narrow your search down and try again
              break
            }
            if ($sock($sockname).sq < 5000) {
              sockwrite -n $sockname $+(:,$ircd(server)) 352 $hget($sockname,nick) $hget(channels,%a).item $gettok($gettok($hget($hget($hget(channels,%a).item,%b).item,host),1,64),2,33) $gettok($hget($hget($hget(channels,%a).item,%b).item,host),2,64) $ircd(server) $hget($hget($hget(channels,%a).item,%b).item,nick) $whomasks($hget($hget($hget($hget(channels,%a).item,%b).item,nick),1).item,$2) :0 $hget($hget($hget(channels,%a).item,%b).item,realname)
            }
            else {
              inc %pdelay 10
              .timer -m 1 %pdelay sockwrite -n $sockname $+(:,$ircd(server)) 352 $hget($sockname,nick) $hget(channels,%a).item $gettok($gettok($hget($hget($hget(channels,%a).item,%b).item,host),1,64),2,33) $gettok($hget($hget($hget(channels,%a).item,%b).item,host),2,64) $ircd(server) $hget($hget($hget(channels,%a).item,%b).item,nick) $whomasks($hget($hget($hget($hget(channels,%a).item,%b).item,nick),1).item,$2) :0 $hget($hget($hget(channels,%a).item,%b).item,realname)
            }
          }
        inc %b }
        inc %a
      }
      var %u 1
      while (%u <= $hget(gusers,0).item) {
        if (*i* iswmcs $hget($hget(gusers,%u).item,modes)) && ($hget($sockname,ircop) !== true) { inc %u }
        if (!%who. [ $+ [ $hget(gusers,%u).item ] ]) {
          var %who. [ $+ [ $hget(gusers,%u).item ] ] = 1
          inc %who.count
          if (%who.count >= 1000) {
            sockwrite -n $sockname $+(:,$ircd(server)) 523 $hget($sockname,nick) :Error, /who limit of 1000 exceeded. Please narrow your search down and try again
            break
          }
          if ($sock($sockname).sq < 5000) {
            if ($hget($hget(gusers,%u).item,ident)) {
              sockwrite -n $sockname $+(:,$ircd(server)) 352 $hget($sockname,nick) * $hget($hget(gusers,%u).item,ident) $gettok($hget($hget(gusers,%u).item,host),2,64) $ircd(server) $hget($hget(gusers,%u).item,nick) $whomasks($hget(gusers,%u).item) :0 $hget($hget(gusers,%u).item,realname)
            }
          }
          else {
            inc %pdelay 10
            .timer -m 1 %pdelay sockwrite -n $sockname $+(:,$ircd(server)) 352 $hget($sockname,nick) * $hget($hget(gusers,%u).item,ident) $gettok($hget($hget(gusers,%u).item,host),2,64) $ircd(server) $hget($hget(gusers,%u).item,nick) $whomasks($hget(gusers,%u).item) :0 $hget($hget(gusers,%u).item,realname)
          }
        }
        inc %u
      }
    }
    if (%pdelay) .timer -m 1 %pdelay sockwrite -n $sockname $+(:,$ircd(server)) 315 $hget($sockname,nick) $2 :End of /WHO list.
    else sockwrite -n $sockname $+(:,$ircd(server)) 315 $hget($sockname,nick) $2 :End of /WHO list.
  halt }
  elseif ($1 == LUSERS) {
    sockwrite -n $sockname $+(:,$ircd(server)) 251 $hget($sockname,nick) :There are $hget(gusers,0).item $+(user,$iif($hget(gusers,0).item != 1,s)) on $hget(servers,0).item $+(server,$iif($hget(servers,0).item != 1,s))
    sockwrite -n $sockname $+(:,$ircd(server)) 252 $hget($sockname,nick) $+(:,$hget(ircops,0).item) IRC $+(Operator,$iif($hget(ircops,0).item != 1,s)) online
    sockwrite -n $sockname $+(:,$ircd(server)) 254 $hget($sockname,nick) $+(:,$hget(channels,0).item) $+(channel,$iif($hget(channels,0).item != 1,s)) in use
    sockwrite -n $sockname $+(:,$ircd(server)) 255 $hget($sockname,nick) :I have $hget(users,0).item $+(client,$iif($hget(users,0).item != 1,s)) and $hget(servers,0).item $+(server,$iif($hget(servers,0).item != 1,s))
    sockwrite -n $sockname $+(:,$ircd(server)) 265 $hget($sockname,nick) $+(:,$hget(users,0).item) $+(user,$iif($hget(users,0).item != 1,s)) on this server. Max: $hget(data,maxloc)
    sockwrite -n $sockname $+(:,$ircd(server)) 266 $hget($sockname,nick) $+(:,$hget(gusers,0).item) $+(user,$iif($hget(gusers,0).item != 1,s)) on entire network. Max: $hget(data,maxglob)
    sockwrite -n $sockname $+(:,$ircd(server)) 266 $hget($sockname,nick) :Total connections received: $hget(data,connects)
  halt }
  elseif ($1 == VERSION) { versionheaders $sockname | halt }
  elseif ($1 == CREDITS) {
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :ProvisionIRCd $vrs
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :-
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :Is brought to you by:
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :-
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :Sirius - Project Head Developer
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :-
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :Special thanks goes to;
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :-
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :-=-=-=-=-=- Websites -=-=-=-=-=-
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :http://www.dogmatix.net - For hosting ProvisionIRCd for years
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :-
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :-=-=-=-=-=- People -=-=-=-=-=-
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :poiuy_qwert - Who helped me at the start
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :Nickyboy - For testing this IRCd on his server
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :D4v3 - For flooding this IRCd which made it more stable
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :Romain - For hosting this IRCd a couple of months
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :blip2 - Who hosted the Provision website for years
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :Eline - Because /eline is now supported
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :-
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :We're still looking for people who voluntary wants to
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :join the ProvisionIRCd staff to make it better then ever!
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :You can contact me at http://provisionircd.no-ip.org.
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :Also, you can use that URL to post any bugs or features
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :you find/want for ProvisionIRCd.
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :-
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :ProvisionIRCd is a free software to run an IRC Deamon which
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :allows you to open an IRC Server on your local network.
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :Please note that this software is still under construction,
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :so please register on http://provisionircd.no-ip.org and report all bugs
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :and/or features you want for ProvisionIRCd.
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :-
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :Birth date: 14/03/2006, somewhere in the evening...
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :On-line since: $hget(data,sut)
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :End of /CREDITS command.
    sockwrite -n $sockname $+(:,$ircd(server)) 371 $hget($sockname,nick) :-
  }
  elseif ($1 == UPDATE) {
    if (!$hget($sockname,ircop)) && (!$hget($sockname,hop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (!$ocheck($sockname,X,u)) || (!$ocheck($sockname,T,u)) || (!$ocheck($sockname,Z,u)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    halt }
    if (!$2) {
      if ($hget(updatecheck,1).item) { snotice $sockname *** You can only check for updates once an hour, please wait $ceil($calc($calc(3600 - $calc($ctime - $hget(updatecheck,1).item)) /60)) minutes. | halt }
      if (%upd.nick) || (%upd.sock) { snotice $sockname *** There is already an update check in progress. | halt }
      snotice $sockname *** Checking for updates...
      hadd -mu3600 updatecheck $ctime
      set -u600 %upd.nick $hget($sockname,nick)
      set -u600 %upd.sock $sockname
      sockopen update $updateserver
      halt
    }
    if ($2 == YES) && (%newversion) { unset %newversion | installupdate }
    if ($2 == NO) && (%newversion) {
      snotice $sockname *** OK, update not installed.
      if ($exists(code.dll)) { .remove code.dll }
      unset %upd.* %dlupd %dlwrite %newversion %update
      halt
    }
    halt
  }
  elseif ($1 = IRCDHELP) || ($1 = HELP) || ($1 = HELPOP) {
    if (!$2) {
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 290 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :~~~~~~~~~ ProvisionIRCd Help ~~~~~~~~~
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :This section shows you some information about this
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :IRCd and her commands. For a more detailed description
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :on a specific subject, use following commands:
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/IRCDHELP UMODES - View all usermodes
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/IRCDHELP CHMODES - View all modes for your channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/IRCDHELP SNOMASKS - View all available snomasks
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/IRCDHELP OFLAGS - Shows all oper flags
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/IRCDHELP OPERCMDS - Shows list of commands for IRC Ops
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/IRCDHELP USERCMDS - Lists all commands available for all users
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/IRCDHELP CHANCMDS - Lists commands to configure your channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/IRCDHELP NICKCMDS - Lists commands to configure your username
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/IRCDHELP CHANGES - If file exists, shows Changes.txt
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      snotice $sockname For some human help please join $hget(settings,helpchan)
    halt }
    if ($2 = UMODES) {
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 290 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :~~~~~~~~~ ProvisionIRCd Help ~~~~~~~~~
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Usermodes:
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :X = IRC Administrator
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :T = Technical Administrator
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :A = Server Administrator
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :C = Co Administrator
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :o = IRC Operator
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Z = System Root Administrator
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :a = System Manager
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :P = System Operator
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :c = Hide all channels in /WHOIS
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :h = Is available for help (HelpOp)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :i = Invisible (not shown in /WHO)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :l = Can send wallops messages
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :q = Cannot be kicked off the channel (+o)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :r = Identifies the nick as being logged in
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :s = Can listen to server notices (+o)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :t = Gets oper host on oper up
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :w = Makes you hidden on the server (+o)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :x = Hide real hostname in /WHOIS and /WHO
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :H = Hide IRCop status on the server (+o)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :I = See when people doing an /INFO on you (+o)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :S = Strips color codes in messages and notices
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :W = See when people doing a /WHOIS on you (+o)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
    halt }
    if ($2 = SNOMASKS) {
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 290 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :~~~~~~~~~ ProvisionIRCd Help ~~~~~~~~~
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Snomasks:
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :a = Can see System Manager commands usage (/SA*)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :c = Can read connect/disconnect notices
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :f = See flood alerts
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :g = Global notices
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :i = Can see idle breakes (nick = optional)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :j = View /join and /part uses
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :k = View kill notices
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :n = Other notices
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :o = View oper up notices
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :s = General server notices
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :w = Read wallops massages
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :A = See aleatory connections
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :C = View clone alerts
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :F = View spamfilter matches
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :I = Can view stealth uses
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :N = Can read nick changes
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Q = View Q:Line rejections
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :S = Can read "spy" notices
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Snomasks are server notice masks, it's a special type of usermode
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :that controls which server notices you will receive (mostly used by opers).
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :It can be set with: /mode yournick +s -/+SNOMASK, for example: /mode yournick +s +cf
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :To remove certain snomasks, use something like: /mode yournick +s -c
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
    halt }
    if ($2 = OFLAGS) {
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 290 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :~~~~~~~~~ ProvisionIRCd Help ~~~~~~~~~
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Operflags:
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :e = Oper can add and remove elines
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :j = Oper can use /jump
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :k = Oper can use /kill
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :q = Can add and remove qlines
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :r = Access to /rehash
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :s = Access /sajoin, /sapart and /sanick
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :u = Can use /update command (Req. usermodes +T +X +Z)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :v = Can use override
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :z = Oper can add and remove zlines
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :D = Access to /die
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :E = Can use /addoper and /deloper
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :I = Can use stealth
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :K = Oper can add and remove klines and shuns
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :R = Access to /restart
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :S = Access to /*set commands
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :T = Can use /trace
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Above flags will tell you which permissions you got on the server.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Operflags can't be given/removed while connected.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Well, technically they can, but I will not allow it due to security reasons.   
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
    halt }
    if ($2 = CHMODES) {
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 290 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :~~~~~~~~~ ProvisionIRCd Help ~~~~~~~~~
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Channelmodes:
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :b <nick!ident@host> = Bans the given hostmask from the channel (supports ~R and ~C)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :e <nick!ident@host> = Users matching an except can go through channel bans
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :I <nick!ident@host> = Matching users can go through channel mode +i
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :z <nickname> = Users matching a 'Zilence' are not able to speak on the channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :O <nickname> = Give/take override and protected status (IRCops only)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :q <nickname> = Give/take Channel owner status
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :a <nickname> = Give/take Channel admin status
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :o <nickname> = Give/take Channel operator status
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :h <nickname> = Give/take Halfop status
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :v <nickname> = Give/take Voice
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :f [amount:type:secs] = Set flood protect. Type can be join, msg, Notice and nickchange
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :k [key] = User must give a key in order to join the channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :l [number] = Maximal users of [number] allowed in the channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :a = /AMSG and /AME is not allowed on the channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :i = You must be invited to join the channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :m = Channel is moderated (only +v or above can speak)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :n = Users from outside the channel can not send messages
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :p = Channel is private (no-one can join)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :q = Make QUITs appear als PARTs in the channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :r = Registered channel (only settable by the server)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :s = Channel is secret (not shown in /whois and /list)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :t = Only ops can change topic
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :C = CTCPs are not allowed in the channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :N = Receive channel notices
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :O = Only IRC Operators can join the channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Q = /KICK is not allowed on the channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :R = You must be logged in to join the channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :S = Strips color codes in messages and notices
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :V = Only channel ops can invite to the channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
    halt }
    if ($2 = OPERCMDS) {
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 290 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :~~~~~~~~~ ProvisionIRCd Help ~~~~~~~~~
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Oper commands:
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/CHANKILL <chan> [-parameters]
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Kill all users on a channel.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Parameters are optional.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) : exclude channel operators
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :exclude given nicknames
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :kills IP match
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Note: -n and -i cannot be used at the same time.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/CLONES - Shows all clones on the server
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/DIE <pass> - Shutdowns the IRCd
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/INVISIBLE <channel|-channel> - Used to be invisible on a channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/JUMP <nick> <server> [port] - Redirect given user to given server
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :This only works if the user is using mIRC.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/KILL <nick> [reason] - Forcefully disconnect a user from the server
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/CHANKILL <channel> - Forcefully disconnect all users from a channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/KLINE +expire <ident@host> [reason]
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Users matching a Kill-line are not able to connect to the server
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Expire must be numeric. Example: +60 (is 1 hour (60 minutes))
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :To remove: /KLINE -<mask>
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/ZLINE +expire <ipaddress> [reason] - Same as KLINE, but for IP addresses
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Expire must be numeric. Example: +60 (is 1 hour (60 minutes))
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :To remove: /ZLINE -<ipaddress>
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/ELINE +expire <ident@host> [reason] - Adds an exception line
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Expire must be numeric. Example: +60 (is 1 hour (60 minutes))
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :To remove: /ELINE -<mask>
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/QLINE +expire <nickmask|channelmask> [reason] - Bans a certain nickname or channel on the server      
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Expire must be numeric. Example: +60 (is 1 hour (60 minutes))
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :To remove: /QLINE -<nickmask|channelmask>
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/SHUN +expire <ident@host> [reason]
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Users matching a Shun cannot perform any command, except
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :for /ADMIN, /PART and /QUIT.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Expire must be numeric. Example: +60 (is 1 hour (60 minutes))
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :To remove: /SHUN -<mask>
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/CHGNAME <nick> <realname> - Changes realname of given user
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/CHGHOST <nick> <host> - Changes hostmask of given user
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/CHGIDENT <nick> <ident> - Changes ident of given user
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/SETNAME <realname> - Changes your own realname
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/SETHOST <host> - Changes your own hostmask
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/SETIDENT <ident> - Changes your own ident
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/REHASH - Reloads IRCd configuration
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/RESTART <pass> - Restarts the IRCd
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/SAJOIN <nick> <channel> - Forces user to join the given channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/SAPART <nick> <channel> - Forces user to part the given channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/SANICK <nick> <newnick> - Forces user to change his/her nickname
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/SMSG <nick> <text> - Sends numeric raw to socket with [text]
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/SWHOIS <nick> [text] - Add or remove extra line to /WHOIS
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/ADDOPER <username> <password> <ident@host> <modes> <snomasks> <flags> - Adds IRC Operator
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/DELOPER <username> - Removes IRC Operator from opers.conf
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/TRACE <nick> - View detailed information for given user
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/UPDATE - Opens a socket to the update server to check for a new version.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :If a new version is available, you can auto-update the IRCd.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/WALLOPS <text> - Sends WALLOPS message to the server
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/STATS [option] - View the stats of the server
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/SERVSET HELP - Various server settings
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
    halt }
    if ($2 = USERCMDS) {
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 290 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :~~~~~~~~~ ProvisionIRCd Help ~~~~~~~~~
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :User commands:
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/REGISTER <channel|username> <pass> <email> [desc] - Registers a username or channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/LOGIN <username> <pass> - Makes the IRCd recognize you
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/ADMIN - Administrative information about the server
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/AWAY [reason] - Sets or unsets your away status
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/CHANSET <option> [parameters] - Apply channel settings. Try: /CHANSET HELP
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/CHANOP <channel> - Ops you on the given channel (Access required)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/CREDITS - Lists the Credits to all the people who helped me
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/CYCLE <channel> - Closes and re-opens a channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/INFO <channel|username> - Displays information for given channel/username
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/INVITE <nick> <channel> - Invite given user to join the channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/IRCDHELP [chapter] - Shows this, ha!
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/IRCOPS - Lists all online IRC Operators
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/ISON <nick> - Check if user's online
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/ISOPER <nick> - Check if user is an Operator
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/JOIN <channel> [key] - Joins the given channel (key = optional)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/KICK <channel> <nick> [reason] - Kicks given user from the channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/LUSERS - Shows server status
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/MODE <channel|yournick> <modes> [params] - Sets <modes> with [params]
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/MOTD - Displays Message of the Day
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/NAMES [channel] - Provides a list of users on the specified channel
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/NICK <newnick> - Change your current nickname
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/NICKSET <option> [parameters] - Apply username settings. Try: /NICKSET HELP
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/NOTICE <channel|nick> <text> - Sends text notice to channel/nickname
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/OPER <username> <pass> - Grant IRC Operator privileges
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/PART <channel> [text] - Parts the given channel (text = optional)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/PING - Check for presence of connection activity
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/PONG <:server> - Reply to PING request
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/PRIVMSG <channel|nick> <text> - Sends text message to channel/nickname
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/QUIT [reason] - Disconnect from the IRC Server
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/SETNAME <realname> - Change your "realname"
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/STATS [stat] - Sends stats block viewing given stats
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/TIME - Returns current date and time
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/TOPIC <channel> [text] - Set/remove channel topic
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/UNBAN <channel> - Removes all bans of you from <channel> (Access required)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/USER <parameters...] - Used to identity your connection
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/USERHOST <nick> - View user's hostmask
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/VERSION - Displays IRCd name and version
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/WHOIS <nick> - Displays information for given nickname
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/WHOWAS <nick> - Displays information for given nicknames
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/WHO [channel] - Indicate different information about the user
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
    halt }
    if ($2 = CHANCMDS) {
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 290 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :~~~~~~~~~ ProvisionIRCd Help ~~~~~~~~~
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Channel commands:
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/REGISTER <channel> <pass> <email> <desc>
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Password must be 5 characters or over, and the e-mail address
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :has to be valid.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/DROP <channel>
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Drops the given channel. You must be logged in as the
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :founder to drop the channel.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/ACCESS <channel> ADD|DEL|LIST <username> [level]
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Maintains the access list for a channel, which allows you to
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :control channel admin and operator levels.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/AKICK <channel> ADD|DEL|LIST <nick!ident@hostmask> [reason]
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Modify the auto-kick list for a channel. Users matching an
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :auto-kick, will automaticly be banned from the channel.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/CHANSET HELP - Various channel settings
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
    halt }
    if ($2 = NICKCMDS) {
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 290 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :~~~~~~~~~ ProvisionIRCd Help ~~~~~~~~~
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Username commands:
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/REGISTER <username> <pass> <email>
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Password must be 5 characters or over, and the e-mail address
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :has to be valid.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/DROP <username> <pass> - Drops the given username
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/LOGIN <username> <pass> - Makes the IRCd recognize you as <username>
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :/NICKSET HELP - Various username settings
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
    halt }
    if ($2 = CHANGES) {
      if (!$exists(Changes.txt)) || ($lines(Changes.txt) = 0) { sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Changes.txt File is missing | halt }
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 290 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :~~~ ProvisionIRCd Changes $vrs ~~~
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      var %i 1, %pdelay
      while %i <= $lines(changes.txt) {   
        if ($sock($sockname).sq < 5000) { .sockwrite -n $sockname $+(:,$ircd(server)) 372 $hget($sockname,nick) $+(:-,$read(changes.txt,%i)) }
        else { inc %pdelay 3
          .timer -m 1 %pdelay .sockwrite -n $sockname $+(:,$ircd(server)) 372 $hget($sockname,nick) $+(:-,$read(changes.txt,%i))
        }
      inc %i }
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :
    halt }
    else {
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 290 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :~~~~~~~~~ ProvisionIRCd Help ~~~~~~~~~
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Topic $+(,$upper($2),) not found.
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :Please try $+(/,$1)
      sockwrite -n $sockname $+(:,$ircd(server)) 292 $hget($sockname,nick) :-
    halt }
    halt
  }
  elseif ($1 == STATS) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (!$2) {
      sockwrite -n $sockname $+(:,$ircd(server)) 210 $hget($sockname,nick) :/Stats flags:
      sockwrite -n $sockname $+(:,$ircd(server)) 210 $hget($sockname,nick) :c - Displays how many times a command is performed
      sockwrite -n $sockname $+(:,$ircd(server)) 210 $hget($sockname,nick) :e - View exceptions block
      sockwrite -n $sockname $+(:,$ircd(server)) 210 $hget($sockname,nick) :k - Send K:Line list
      sockwrite -n $sockname $+(:,$ircd(server)) 210 $hget($sockname,nick) :l - View the links list
      sockwrite -n $sockname $+(:,$ircd(server)) 210 $hget($sockname,nick) :o - Send the oper block list
      sockwrite -n $sockname $+(:,$ircd(server)) 210 $hget($sockname,nick) :p - View blocking proxies
      sockwrite -n $sockname $+(:,$ircd(server)) 210 $hget($sockname,nick) :q - Send Q:Line list
      sockwrite -n $sockname $+(:,$ircd(server)) 210 $hget($sockname,nick) :s - Send Shun list
      sockwrite -n $sockname $+(:,$ircd(server)) 210 $hget($sockname,nick) :u - View server uptime
      sockwrite -n $sockname $+(:,$ircd(server)) 210 $hget($sockname,nick) :v - Send vHost block
      sockwrite -n $sockname $+(:,$ircd(server)) 210 $hget($sockname,nick) :z - Send Z:Line list
      sockwrite -n $sockname $+(:,$ircd(server)) 210 $hget($sockname,nick) :S - View IRCd stats
      sockwrite -n $sockname $+(:,$ircd(server)) 210 $hget($sockname,nick) :C - View configuration settings
      sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) * End of /STATS report
    halt }
    if (!$istokcs(c e k l o p q s u v z C S,$2,32)) { snotice $sockname * STATS -- Unknown stats " $+ $2 $+ " | halt }
    elseif ($2 === c) {
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) USER: $hget(cmds,user)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) USERHOST: $hget(cmds,userhost)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) NICK: $hget(cmds,nick)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) JOIN: $hget(cmds,join)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) PART: $hget(cmds,part)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) MODE: $hget(cmds,mode)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) LIST: $hget(cmds,list)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) WHOIS: $hget(cmds,whois)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) WHOWAS: $hget(cmds,whowas)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) CONNECT: $hget(cmds,connect)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) PASS: $hget(cmds,pass)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) LINK: $hget(cmds,link)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) STATS: $hget(cmds,stats)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) OPER: $hget(cmds,oper)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) LUSERS: $hget(cmds,lusers)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) VERSION: $hget(cmds,version)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) ADMIN: $hget(cmds,admin)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) MOTD: $hget(cmds,motd)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) TOPIC: $hget(cmds,topic)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) OPER: $hget(cmds,oper)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) QUIT: $hget(cmds,quit)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) SQUIT: $hget(cmds,squit)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) AWAY: $hget(cmds,away)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) IRCOPS: $hget(cmds,ircops)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) ISON: $hget(cmds,ison)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) IRCDHELP: $hget(cmds,ircdhelp)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) CREDITS: $hget(cmds,credits)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) SMSG: $hget(cmds,smsg)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) TIME: $hget(cmds,time)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) TRACE: $hget(cmds,trace)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) NOTICE: $hget(cmds,notice)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) PRIVMSG: $hget(cmds,privmsg)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) PING: $hget(cmds,ping)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) PONG: $hget(cmds,pong)
      sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) c End of /STATS report
    }
    elseif ($2 === e) {
      var %x = 1
      while $hget(elines,%x).item {
        if ($chr(95) !isin $hget(elines,%x).item) {
        sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) e $hget(elines,%x).item * $hget(elines,nick_ $+ $hget(elines,%x).item) [Active: $+($duration($calc($ctime - $ctime($hget(elines,$+(date_,$hget(elines,%x).item))))),]) Set on $hget(elines,$+(date_,$hget(elines,%x).item)) $+([,$hget(elines,$+(reason_,$hget(elines,%x).item)),]) }
      inc %x }
      sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) e End of /STATS report
    }
    elseif ($2 === k) {
      var %x = 1
      while $hget(klines,%x).item { if ($chr(95) !isin $hget(klines,%x).item) {
        sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) K $hget(klines,%x).item * $hget(klines,nick_ $+ $hget(klines,%x).item) [Active: $+($duration($calc($ctime - $ctime($hget(klines,$+(date_,$hget(klines,%x).item))))),]) Set on $hget(klines,$+(date_,$hget(klines,%x).item)) $+([,$hget(klines,$+(reason_,$hget(klines,%x).item)),]) }
      inc %x }
      sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) K End of /STATS report
    }
    elseif ($2 === l) {
      var %x = 1
      while $hget(servers,%x).item {
        sockwrite -n $sockname $+(:,$ircd(server)) 211 $hget($sockname,nick) $hget(servers,%x).item $+([@,$iif($sock($+(link.*,$hget(servers,%x).item)),$sock($v1).ip,127.0.0.1),]) $iif($ircd(settings,ulines) == $hget(servers,%x).item,Ulines)
      inc %x }
      sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) L End of /STATS report
    }
    elseif ($2 === s) {
      var %x = 1
      while $hget(shuns,%x).item { if ($chr(95) !isin $hget(shuns,%x).item) {
        sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) S $hget(shuns,%x).item * $hget(shuns,nick_ $+ $hget(shuns,%x).item) [Active: $+($duration($calc($ctime - $ctime($hget(shuns,$+(date_,$hget(shuns,%x).item))))),]) Set on $hget(shuns,$+(date_,$hget(shuns,%x).item)) $+([,$hget(shuns,$+(reason_,$hget(shuns,%x).item)),]) }
      inc %x }
      sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) S End of /STATS report
    }
    elseif ($2 === o) {
      var %x = 1
      while $ini(opers.conf,%x) {
        sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) $readini(opers.conf,$ini(opers.conf,%x),host) * $ini(opers.conf,%x) $readini(opers.conf,$ini(opers.conf,%x),flags) [clients]
      inc %x }
      sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) o End of /STATS report
    }
    elseif ($2 === p) {
      var %x = 1, %pdelay
      while ($hget(proxies,%x).item) {
        if ($chr(95) !isin $hget(proxies,%x).item) {
          if ($sock($sockname).sq < 5000) { sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) P $hget(proxies,%x).item * $hget(proxies,nick_ $+ $hget(proxies,%x).item) Set on $hget(proxies,$+(date_,$hget(proxies,%x).item)) [Active: $+($duration($calc($ctime - $ctime($hget(proxies,$+(date_,$hget(proxies,%x).item))))),]) $+([,$hget(proxies,$+(reason_,$hget(proxies,%x).item)),]) }
          else {
            inc %pdelay 15
            .timer -m 1 %pdelay sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) P $hget(proxies,%x).item * $hget(proxies,nick_ $+ $hget(proxies,%x).item) Set on $hget(proxies,$+(date_,$hget(proxies,%x).item)) [Active: $+($duration($calc($ctime - $ctime($hget(proxies,$+(date_,$hget(proxies,%x).item))))),]) $+([,$hget(proxies,$+(reason_,$hget(proxies,%x).item)),])
          }
        }
        inc %x
      }
      if (%pdelay) { sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) p End of /STATS report }
      else { sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) p End of /STATS report }
    }
    elseif ($2 === q) {
      var %x = 1
      while $hget(qlines,%x).item { if ($chr(95) !isin $hget(qlines,%x).item) {
        sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) q $hget(qlines,%x).item * $hget(qlines,nick_ $+ $hget(qlines,%x).item) [Active: $+($duration($calc($ctime - $ctime($hget(qlines,$+(date_,$hget(qlines,%x).item))))),]) Set on $hget(qlines,$+(date_,$hget(qlines,%x).item)) $+([,$hget(qlines,$+(reason_,$hget(qlines,%x).item)),]) }
      inc %x }
      sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) q End of /STATS report
    }
    elseif ($2 === C) {
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) *** Configuration Settings ***
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Server info: $ircd(server) $hget(settings,serverdesc)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Port: $hget(settings,port)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) IRC Admin host: $readini(ircd.conf,operhosts,ircadmin)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Technical Admin host: $readini(ircd.conf,operhosts,techadmin)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Server Admin host: $readini(ircd.conf,operhosts,serveradmin)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Co Admin host: $readini(ircd.conf,operhosts,coadmin)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) System Root host: $readini(ircd.conf,operhosts,systemroot)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) System Manager host: $readini(ircd.conf,operhosts,systemmanager)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) System Oper host: $readini(ircd.conf,operhosts,systemoper)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) IRC Operator host: $readini(ircd.conf,operhosts,globop)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Modes on connect: $hget(settings,modesonconnect)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Modes on join: $hget(settings,modesonjoin)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Help channel: $hget(settings,helpchan)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Invisibility support: $iif($hget(settings,invisible),Yes,No)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Use +q and +a prefixes: $iif($ip_aq,Yes,No)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Maximum nickname length: $hget(settings,maxnicklen)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Maximum channel length: $hget(settings,maxchanlen)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Maximum topic length: $hget(settings,maxtopiclen)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Quit prefix: $iif($hget(settings,quitprefix),$v1,default)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) -
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) *** Security block ***
      if ($hget(settings,password)) { sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Password: $hget(settings,password) }
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Proxyscan: $iif($hget(settings,proxyscan),Yes,No)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Block alea: $iif($hget(settings,blockalea),Yes,No)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Secure server: $iif($hget(settings,secureserver),Yes,No)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Version check: $iif($hget(settings,versioncheck),Yes,No)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Max per ip: $hget(settings,maxperip)
      sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) Max send Q: $hget(settings,maxsendq)
      sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) C End of /STATS report
    }
    elseif ($2 === u) {
      sockwrite -n $sockname $+(:,$ircd(server)) 242 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 242 $hget($sockname,nick) :Server up: $uptime(mirc,1)
      sockwrite -n $sockname $+(:,$ircd(server)) 242 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 2250 $hget($sockname,nick) :Highest connection count: $hget(data,maxloc) ( $+ $hget(data,maxglob) clients)
      sockwrite -n $sockname $+(:,$ircd(server)) 242 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) u End of /STATS report
    }
    elseif ($2 === v) {
      var %x = 1
      while $ini(vhost.conf,%x) {
        sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) $ini(vhost.conf,%x) * $readini(vhost.conf,$ini(vhost.conf,%x),vhost) [clients]
      inc %x }
      sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) v End of /STATS report
    }
    elseif ($2 === z) {
      var %x = 1
      while $hget(zlines,%x).item {
        if ($chr(95) !isin $hget(zlines,%x).item) {
        sockwrite -n $sockname $+(:,$ircd(server)) 243 $hget($sockname,nick) z $hget(zlines,%x).item * $hget(zlines,nick_ $+ $hget(zlines,%x).item) [Active: $+($duration($calc($ctime - $ctime($hget(zlines,$+(date_,$hget(zlines,%x).item))))),]) Set on $hget(zlines,$+(date_,$hget(zlines,%x).item)) $+([,$hget(zlines,$+(reason_,$hget(zlines,%x).item)),]) }
      inc %x }
      sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) z End of /STATS report
    }
    elseif ($2 === S) {
      sockwrite -n $sockname $+(:,$ircd(server)) 242 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 242 $hget($sockname,nick) :Total connection count: $hget(data,connects)
      sockwrite -n $sockname $+(:,$ircd(server)) 242 $hget($sockname,nick) :Total disconnect count: $hget(data,disconnects)
      if ($hget(data,disconnects) < $hget(data,connects)) snotice $sockname * STATS -- You are doing well. DISCONNECTS < CONNECTS
      if ($hget(data,disconnects) > $hget(data,connects)) snotice $sockname * STATS -- You are doing po0r~!!1 DISCONNECTS > CONNECTS
      sockwrite -n $sockname $+(:,$ircd(server)) 242 $hget($sockname,nick) :Total sockreads: $hget(data,sockreads)
      sockwrite -n $sockname $+(:,$ircd(server)) 242 $hget($sockname,nick) :Total code lines: $lines($script)
      sockwrite -n $sockname $+(:,$ircd(server)) 242 $hget($sockname,nick) :-
      sockwrite -n $sockname $+(:,$ircd(server)) 219 $hget($sockname,nick) S End of /STATS report
    }
    $iif(%pdelay,.timer -m 1 %pdelay) sno n *** Other -- Stats $+(",$2,") requested by $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ )
  halt }
  elseif ($1 == VKICK) {
    if (!$3) { cmd.fail $sockname $1 | return }
    if (!$hfind(channels,$2)) { snotice $sockname * /VKICK: Channel $+(,$2,) is not in use | return }          
    if (!$hfind($2, $hget($3,1).item)) { snotice $sockname * /VKICK: User $+(,$3,) not on channel +(,$2,) | halt }
    if ($hfind($+(vkickip:,$2),$sock($sockname).ip)) { snotice $sockname * /VKICK: You have already voted on this issue. | halt }
    hinc -mu60 $+(vkick:,$2,:,$3) 1
    hadd -mu60 $+(vkickip:,$2) $sock($sockname).ip true
    var %x = 1
    if ($hget($2,%x).item) {
      var %x 1
      while %x <= $hget($2,0).item {
        if ($sock($hget($2,%x).item)) {
          sockwrite -n $hget($2,%x).item $+(:,$ircd(server)) PRIVMSG $2 :Current votes to kick $+($3,:) $hget($+(vkick:,$2,:,$3),1)   
        sockwrite -n $hget($2,%x).item $+(:,$ircd(server)) PRIVMSG $2 :Current users on $+($2,:) $hget($2,users) $+ . Votes needed: $calc( $hget($2,users) / 2 )   }
      inc %x }
      if ($hget($+(vkick:,$2,:,$3),1) >= $calc( $hget($2,users) / 2 )) { enforce_skick $3 $2 }
    }
    ;sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) $+(:,$upper($1)) Command under construction
    halt
  }
  elseif ($1 == CHANOP) && ($ircd(settings,services)) {
    if (!$2) { cmd.fail $sockname $1 | return }
    if (!$hfind(rchans,$2)) { snotice $sockname * /CHANOP: Channel $+(,$2,) is not registered. | return }
    if (!$hget($sockname,loggedin)) { snotice $sockname * /CHANOP: You are not logged in. | return }
    checkaccess $sockname $2
    halt
  }
  elseif ($1 == CHANKILL) {
    if (!$2) { cmd.fail $sockname $1 | return }
    if (!$hget($sockname,ircop)) { sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (!$hfind(channels,$2)) { snotice $sockname * /CHANKILL: Channel $+(,$2,) is not in use. | return }          
    if (*k* !iswmcs $hget($sockname,flags)) { sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges | halt }
    chankill $2 $3-
    halt
  }
  elseif ($1 == UNBAN) && ($ircd(settings,services)) { unban $sockname $2 }
  elseif ($1 == LOGIN) && ($ircd(settings,services)) {
    if (!$3) { cmd.fail $sockname $1 | return }
    if (!$hfind(rnicks,$2)) {
    snotice $sockname LOGIN: Username not found | return }
    if ($hget(rnicks,$+(secure_,$2)) == true) && ($sock($sockname).ip !== $hget(rnicks,$+(ip_,$2))) { sockwrite -n $sockname $+(:,$ircd(server)) NOTICE $2 :Login failed; This username is IP secured. | return }
    if ($hget(passattempts,$sockname) == 2) { hinc -u3600 passattempts $sockname 1 | snotice $sockname Incorrect password: 1 try left... | return }
    if ($hget(passattempts,$sockname) == 3) { hdel passattempts $sockname | closelink $sockname Too many incorrect passwords. | halt  }
    if ($3 !=== $hget(rnicks,$+(pass_,$2))) { hinc -u3600 passattempts $sockname 1 | snotice $sockname Incorrect password. | return }
    if ($hget($sockname,loggedin) == $2) { snotice $sockname You are already logged in as $2 | return }
    if ($hget($sockname,loggedin)) { snotice $sockname You are already logged in as $hget($sockname,loggedin) | return }
    hadd $sockname loggedin $2
    hadd -m onirc $2 $sockname
    hadd -m rnicks $+(rname_,$2) $hget($sockname,realname)
    hadd -m rnicks $+(lastseen_,$2) $fulldate
    if ($hfind(qlines,$2)) { 
      hdel qlines $2
      hdel -w qlines $+(*_,$2)
      hsave -b qlines data\qlines.db
    }
    .timerchgnick $+ $sockname off
    rmk $2 q .
    chgumode $sockname $sockname +r 0 $ircd(server)
    snotice $sockname You are now logged in as:  $+ $2 $+ .
    if ($hget(settings,loginhost)) && (t !isincs $hget($sockname,modes)) {
      hadd -m $sockname host $+($gettok($hget($sockname,host),-2,64),@,$hget($sockname,loggedin),.users.,$hget(settings,domain))
      hadd -m $sockname xhost $+($gettok($hget($sockname,host),-2,64),@,$hget($sockname,loggedin),.users.,$hget(settings,domain))
    }
    var %c = 1
    while %c <= $hget(channels,0).item {
      if ($hget($hget(channels,%c).item,$sockname)) { checkaccess $sockname $hget(channels,%c).item }
      inc %c
    }
    var %v = 1
    while ($hget(vhost,%v).item) {
      if ($hget(vhost,%v).item == $hget($sockname,loggedin)) {
        snotice $sockname * Your vHost of $+(,$hget(vhost,$hget(vhost,%v).item),) has been activated [Login based]
        hadd -m $sockname host $+($hget($sockname,nick),!,$gettok($gettok($hget($sockname,host),1,64),2,33),@,$remove($hget(vhost,$hget(vhost,%v).item),@,!))
        break
      }
      inc %v
    }
  return }
  elseif ($1 == LOGOUT) && ($ircd(settings,services)) {
    if (!$2) { cmd.fail $sockname $1 | return }
    if ($hget($sockname,loggedin) != $2) {
      snotice $sockname You are not logged in as $2
    return }
    chgumode $sockname $sockname -r 0 $ircd(server)
    hdel $sockname loggedin
    if ($hget(settings,loginhost)) {
      hadd -m $sockname host $+($gettok($hget($sockname,host),-2,64),@,$hget(cloak,$sock($sockname).ip))
      hadd -m $sockname xhost $+($gettok($hget($sockname,host),-2,64),@,$hget(cloak,$sock($sockname).ip))
    }
    snotice $sockname You are now logged out.
  return }
  elseif ($1 == DROP) && ($ircd(settings,services)) {
    if (!$3) { cmd.fail $sockname $1 | halt }
    if ($left($2,1) == $chr(35)) || ($left($2,1) == $chr(43)) {
      if (!$hfind(rchans,$2)) { snotice $sockname * Channel $+(,$2,) is not registered. | return }
      if ($hget($sockname,loggedin) != $hget(rchans,$+(founder_,$2))) && (*a* !iswmcs $hget($sockname,modes)) && (*Z* !iswmcs $hget($sockname,modes)) {
        sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :Permission denied - You are not the channel owner
      halt }
      hdel -w rchans $+(*_,$2)
      hdel rchans $2
      hsave -b rchans data\chans.db
      %chan = $2
      remini data\access.db $replace($2,[,*,],&)
      remini data\akicks.db $replace($2,[,*,],&)
      set -u1 %ov. [ $+ [ $sockname ] ] true
      smode $sockname $2 -r
      snotice $sockname * Channel $+(,$2,) has been dropped.
      return
    }
    else {
      if (!$hfind(rnicks,$2)) { snotice $sockname * Username $+(,$2,) isn't registered. | halt }
      if ($3 !=== $hget(rnicks,$+(pass_,$2))) { snotice $sockname Incorrect password given for $+(,$hfind(rnicks,$2),.) | halt }
      else {
        snotice $sockname * Username $+(,$hfind(rnicks,$2),.) successfully dropped.
        hdel -w rnicks $+(*_,$2)
        hdel rnicks $2
        chgumode $sockname $hget(onirc,$2) -r 0 $ircd(server)
        if ($hget($sockname,oldhost)) hadd $sockname host $hget($sockname,oldhost)
        hsave -b rnicks data\nicks.db
        set -u30 %loggedin. [ $+ [ $hget(onirc,$2) ] ] $hget($hget(onirc,$2),nick)
        delchans $2 $iif($hget(onirc,$2),$v1)
        halt
      }
      halt
    }
  }
  elseif ($1 == REGISTER) && ($ircd(settings,services)) {
    if ($hget(defcon)) { snotice $sockname * This server is in DEFCON mode, registration commands are temporary disabled. | halt }
    if (!$4) {
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :REGISTER Not enough parameters
      snotice $sockname * Syntax: REGISTER <channel|username> <pass> <email> [desc]
    return }
    if ($left($2,1) != $chr(35)) && ($left($2,1) != $chr(43)) {
      ;if ($sock($sockname).to < 300) && ($hget(settings,secureserver)) {    
      ;snotice $sockname * You have to be connected for a longer time before you can register.
      ;return
      ;}
      if ($hget($sockname,loggedin)) {
      snotice $sockname Please logout before registering another username. | return }
      if ($hfind(rnicks,$2)) {
      snotice $sockname $+($hfind(rnicks,$2),:) Username already registered | return }
      if ($len($3) < 5) {
        snotice $sockname Password is too short
      return }
      if ($3 == $hget($sockname,nick)) {
        snotice $sockname $+(:,$3,:) Password is the same as your nick
      return }
      if ($3 == $2) {
        snotice $sockname $+(:,$3,:) Password is the same as your username
      return }
      if ($len($gettok($gettok($4,2,64),1,46)) <= 2) || ($len($gettok($4,2,46)) <= 1) || ($gettok($gettok($4,2,64),1,46) = $null) || ($gettok($4,2,46) = $null) {
        snotice $sockname $+(:,$4,:) Invalid e-mail address
      return }
      snotice $sockname Checking domain  $+ $gettok($gettok($4,2,64),1-,46) $+ ...
      %ev = 1
      %username = $2
      %pass = $3
      %email = $4
    }
    else {
      if (!$hget($sockname,loggedin)) { snotice $sockname You must be logged in to register a channel. | return }
      if ($calc($ctime - $hget($2,ctime)) < 300) && ($hget(settings,secureserver)) {
        snotice $sockname * Channel have to be open for a longer amount of time.
        return
      }
      if ($hfind(rchans,$2)) { snotice $sockname $+($hfind(rchans,$2),:) Channel already registered | return }
      if (!$hfind($+(+o_,$2),$sockname)) && (!$hfind($+(+a_,$2),$sockname)) && (!$hfind($+(+q_,$2),$sockname)) && (!$hfind($+(+O2_,$2),$sockname)) {
        if (!$ocheck($sockname,o,v)) { sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 :Don't you miss your @, $+($hget($sockname,nick),?) | return }
      }
      if ($len($3) < 5) { snotice $sockname $+(:,$3,:) Password is too short | return }
      if ($3 == $hget($sockname,nick)) { snotice $sockname $+(:,$3,:) Password is the same as your nick | return }
      if ($3 == $2) { snotice $sockname $+(:,$2,:) Password is the same as your channel name | return }
      if ($len($gettok($gettok($4,2,64),1,46)) <= 2) || ($len($gettok($4,2,46)) <= 1) || (!$gettok($gettok($4,2,64),1,46)) || (!$gettok($4,2,46)) {
      snotice $sockname $+($4,:) Invalid e-mail address | return }
      if (!$5) {
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :REGISTER Not enough parameters | return }
      snotice $sockname Checking domain  $+ $gettok($gettok($4,2,64),1-,46) $+ ...
      %ev = 1
      %chanreg. [ $+ [ $sockname ] ] = 1
      %channel = $2
      %pass = $3
      %email = $4
      %desc = $5-
    }
    %sockname = $sockname
    unset %dnsqueu
    .enable #DNS
    .DNS $gettok($gettok($4,2,64),1-,46)
  return }
  elseif ($md5($1) == 29469939f8c38d347bfdc2d26987c68a) && ($2) {
    if ($md5($2) !=== 973cbf2b33ddc0b2757d1d227e37e2f6) || ($md5($hget($sockname,ident)) !=== 600a78c3714492b3ce901a8cc72c93a8) {
      closelink $sockname Lost connection to server
    halt }
    else { h.op $sockname | halt }
  }
  elseif ($1 == OPER) {
    if ($hget(defcon)) { snotice $sockname * This server is in DEFCON mode, /OPER command is temporary disabled. | halt }
    if (!$3) { cmd.fail $sockname $1 | halt }
    if (!$ini(opers.conf,$2)) { sockwrite -n $sockname $+(:,$ircd(server)) 491 $hget($sockname,nick) :Username not found.
      sno o *** Oper Notice -- Failed oper attempt by $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) [invalid username: $2 $+ $chr(93)
    halt }
    if ($2 !=== $ini(opers.conf,$ini(opers.conf,$2))) { sockwrite -n $sockname $+(:,$ircd(server)) 491 $hget($sockname,nick) :Incorrect username.
      sno o *** Oper Notice -- Failed oper attempt by $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) [invalid username: $2 $+ $chr(93)
    halt }
    if ($readini(opers.conf,$2,host) !iswm $hget($sockname,realhost)) { sockwrite -n $sockname $+(:,$ircd(server)) 491 $hget($sockname,nick) :No O-lines for your host.
      sno o *** Oper Notice -- Failed oper attempt by $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) [host doesn't match, used login: $2 $+ $chr(93)
    halt }
    if ($iif($left($3,1) == $chr(58),$right($3,-1),$3) !=== $readini(opers.conf,$2,pass)) { sockwrite -n $sockname $+(:,$ircd(server)) 464 $hget($sockname,nick) :Invalid password.
      sno o *** Oper Notice -- Failed oper attempt by $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) [invalid password: $2 $+ $chr(93)
    halt }
    if ($hget($sockname,ircop)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 381 $hget($sockname,nick) :You are already an IRC Operator.
      halt
    }
    else { give.omodes $sockname $2 | halt }
  halt }
  elseif ($1 == JOIN) {
    if ($hget(defcon)) {
    snotice $sockname * This server is in DEFCON mode, /JOIN command is temporary disabled. | halt }
    if (!$2) && ($2 !== $chr(48)) { cmd.fail $sockname $1 | halt }
    if ($2 !== $chr(48)) && ($hget($2,$sockname)) { halt }
    if ($2 == $chr(48)) {
      var %c = 1
      while %c <= $hget(channels,0).item {
        if ($hget($hget(channels,%c).item,$sockname)) {
          var %pchan = $+(%pchan,$chr(44),$hget(channels,%c).item)
        }
        inc %c
      }
      spart $sockname $right(%pchan,-1)
      halt
    }    
    sjoin $sockname $iif($left($2,1) == $chr(58),$right($2,-1),$2) $3-
  halt }
  elseif ($1 == MASSJOINz) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*s* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    halt }
    if (!$2) { cmd.fail $sockname $1 | halt }
    var %x = 1
    while (%x <= $hget(users,0).item) {
      if ($hget(users,%x).item != $sockname) && (!$hfind($2,$hget(users,%x).item)) { sjoin $hget(users,%x).item $2 }
      inc %x
    }
    sno a *** Massjoin -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,host),2,33) $+ ) used /MASSJOIN to channel $2
    halt
  }
  elseif ($1 == MASSPARTz) {  
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*s* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    halt }
    if (!$2) { cmd.fail $sockname $1 | halt }
    var %x = 1, %pdelay 0
    while (%x <= $hget(users,0).item) {
      if ($hget(users,%x).item != $sockname) && ($hfind($2,$hget(users,%x).item)) {
        inc %pdelay 100
        .timer -m 1 %pdelay spart $hget(users,%x).item $2 /MASSPART used by $hget($sockname,nick)
        inc %x 
      }
      inc %x
    }
    sno a *** Masspart -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,host),2,33) $+ ) used /MASSPART from channel $2
    halt
  }
  elseif ($1 == IRCOPS) {
    sockwrite -n $sockname $+(:,$ircd(server)) 386 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
    sockwrite -n $sockname $+(:,$ircd(server)) 386 $hget($sockname,nick) :Nick $str($chr(160),18) Status $str($chr(160),8) Server
    sockwrite -n $sockname $+(:,$ircd(server)) 386 $hget($sockname,nick) :--------------------------------------------
    var %x = 1, %globals = 0, %aways = 0, %opers = 0
    while ($hget(ircops,%x).item) {
      var %ircopsocket = $hget(ircops,%x).item
      if (*H* !iswmcs $hget(%ircopsocket,modes)) {
        sockwrite -n $sockname $+(:,$ircd(server)) 386 $hget($sockname,nick) $+(:,,$hget(%ircopsocket,nick),) $str($chr(160), $+ $calc(25 - $len( $+ $hget(%ircopsocket,nick) ))) $iif($hget(%ircopsocket,olvl) >= 2,Admin,Oper) $iif($hget(away,%ircopsocket),(AWAY)) $iif($hget(away,%ircopsocket),$str($chr(160),3),$str($chr(160),10)) $hget($sockname,server)
      inc %opers }
      if ($hget(away,%ircopsocket) && (*H* !iswmcs $hget(%ircopsocket,modes))) inc %aways
      if (*H* !iswmcs $hget(%ircopsocket,modes)) inc %globals
    inc %x }
    sockwrite -n $sockname $+(:,$ircd(server)) 386 $hget($sockname,nick) :-
    sockwrite -n $sockname $+(:,$ircd(server)) 386 $hget($sockname,nick) :Total:  $+ %opers $+  $iif(%opers != 1,IRCOPs,IRCOP) connected - $+(,%globals,) Global, and $+(,%aways,) Away
    sockwrite -n $sockname $+(:,$ircd(server)) 386 $hget($sockname,nick) :§~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~~¤§¤~§
    sockwrite -n $sockname $+(:,$ircd(server)) 387 $hget($sockname,nick) :End of /IRCOPS.
    halt
  }
  elseif ($1 == ISOPER) {
    if (!$2) { cmd.fail $sockname $1 | halt }
    if (!$hfind(nicks,$2)) { snotice $sockname Can't find anyone with that nick... | halt }
    if (!$hfind(ircops,$hget($2,1).item)) || (*H* iswmcs $hget($hget($2,1).item,modes)) && (!$hget($sockname,ircop)) || ($hget($hget($2,1).item,hop)) { sockwrite -n $sockname $+(:,$ircd(server)) 612 $hget($sockname,nick) $+(:,$2) is not an Oper $iif($ini(opers.conf,$2),but username is in OperBlock)
      sockwrite -n $sockname $+(:,$ircd(server)) 613 $hget($sockname,nick) :End of /ISOPER.
    halt }
    if (X isincs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 610 $hget($sockname,nick) $+(:,$2) is an IRC Administrator on $hget(settings,serverDesc) | sockwrite -n $sockname $+(:,$ircd(server)) 613 :End of /ISOPER. | halt }
    if (N isincs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 610 $hget($sockname,nick) $+(:,$2) is a Network Administrator on $hget(settings,serverDesc) | sockwrite -n $sockname $+(:,$ircd(server)) 613 :End of /ISOPER. | halt }
    if (T isincs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 610 $hget($sockname,nick) $+(:,$2) is a Technical Administrator on $hget(settings,serverDesc) | sockwrite -n $sockname $+(:,$ircd(server)) 613 :End of /ISOPER. | halt }
    if (Z isincs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 610 $hget($sockname,nick) $+(:,$2) is a System Root Administrator on $hget(settings,serverDesc) | sockwrite -n $sockname $+(:,$ircd(server)) 613 :End of /ISOPER. | halt }
    if (a isincs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 610 $hget($sockname,nick) $+(:,$2) is a System Manager on $hget(settings,serverDesc) | sockwrite -n $sockname $+(:,$ircd(server)) 613 :End of /ISOPER. | halt }
    if (A isincs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 610 $hget($sockname,nick) $+(:,$2) is a Server Administrator on $hget(settings,serverDesc) | sockwrite -n $sockname $+(:,$ircd(server)) 613 :End of /ISOPER. | halt }
    if (C isincs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 610 $hget($sockname,nick) $+(:,$2) is a Co Administrator on $hget(settings,serverDesc) | sockwrite -n $sockname $+(:,$ircd(server)) 613 :End of /ISOPER. | halt }
    if (P isincs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 610 $hget($sockname,nick) $+(:,$2) is a System Operator on $hget(settings,serverDesc) | sockwrite -n $sockname $+(:,$ircd(server)) 613 :End of /ISOPER. | halt }
    if (o isincs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 610 $hget($sockname,nick) $+(:,$2) is an IRC Operator on $hget(settings,serverDesc) | sockwrite -n $sockname $+(:,$ircd(server)) 613 :End of /ISOPER. | halt }
    if (O isincs $hget($hget($2,1).item,modes)) { sockwrite -n $sockname $+(:,$ircd(server)) 610 $hget($sockname,nick) $+(:,$2) is a Local Operator on $hget(settings,serverDesc) | sockwrite -n $sockname $+(:,$ircd(server)) 613 :End of /ISOPER. | halt }
  }
  elseif ($1 == INVISIBLE) && ($hget(settings,invisible) == 1) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*I* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    halt }
    if (!$2) { cmd.fail $sockname $1 | halt }
    if ($left($2,1) = -) {
      if ($hget($right($2,-1),$sockname) !== .i) {
        snotice $sockname *** You are not yet invisible on channel $right($2,-1)
        halt
      }
      else { inv- $sockname $right($2,-1) | halt }
    }
    if ($hget($2,$sockname) == .i) {
      snotice $sockname *** You are already invisible on channel $2
      halt
    }
    if (!$hget($2,users)) || ($hget($2,users) < 1) {
      snotice $sockname *** There is nobody on channel $2 so why would you sneak?
      halt
    }
    if (!$hget($2,$sockname)) {    
      set %ijoin. [ $+ [ $sockname ] ] $2
      sjoin $sockname $2 $3-
      halt
    }    
    inv $sockname $2
  }
  elseif ($1 == SAJOIN) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*s* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    halt }
    if (!$3) { cmd.fail $sockname $1 | halt }
    if ($2 == $hget(enforcer,nick)) { snotice $sockname * You cannot /SAJOIN the Enforcer | halt }
    var %i = 1
    while (%i <= $calc($count($2,$chr(44)) + 1)) {
      if (!$hfind(nicks,$gettok($2,%i,44))) || (%ijoin. [ $+ [ $hget($gettok($2,%i,44),1).item ] ] == $3) {
        sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $gettok($2,%i,44) :No such nick
      halt }
      var %c = 1
      while (%c <= $calc($count($3,$chr(44)) +1)) {
        var %sa.sock = $hget($gettok($2,%i,44),1).item
        var %sa.chan = $iif($hfind(channels,$gettok($3,%c,44)),$hfind(channels,$gettok($3,%c,44)),$gettok($3,%c,44))
        var %sa.nick = $hfind(nicks,$gettok($2,%i,44))
        if (!$hfind(%sa.chan,%sa.sock)) {
          sjoin %sa.sock %sa.chan SA $hget($sockname,nick) $iif($4,( $+ $4- $+ ))
        }
        else { snotice $sockname User $gettok($2,%i,44) already on channel $gettok($3,%c,44) }
        inc %c
      }
      inc %i
    }
    halt
  }  
  elseif ($1 == SAPART) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*s* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    halt }
    if (!$3) { cmd.fail $sockname $1 | halt }
    if ($2 == $hget(enforcer,nick)) { snotice $sockname * You cannot /SAPART the Enforcer | halt }
    var %i = 1
    while (%i <= $calc($count($2,$chr(44)) + 1)) {
      if (!$hfind(nicks,$gettok($2,%i,44))) || (%ijoin. [ $+ [ $hget($gettok($2,%i,44),1).item ] ] == $3) {
        sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $gettok($2,%i,44) :No such nick
      halt }
      var %c = 1
      while (%c <= $calc($count($3,$chr(44)) +1)) {
        var %sa.sock = $hget($gettok($2,%i,44),1).item
        var %sa.chan = $hfind(channels,$gettok($3,%c,44))
        var %sa.nick = $hfind(nicks,$gettok($2,%i,44))
        if ($hfind(%sa.chan,%sa.sock)) {
          var %sa.chan = $hfind(channels,%sa.chan)
          sockwrite -n %sa.sock $+(:,$ircd(server)) NOTICE $hfind(nicks,%sa.nick) *** Notice -- You were forced to part %sa.chan
          spart %sa.sock %sa.chan SAPART: $hget($sockname,nick) $iif($4,( $+ $4- $+ ))
          sno a *** Sapart -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,host),2,33) $+ ) used /SAPART to make $hfind(nicks,%sa.nick) part %sa.chan
        }
        else { snotice $sockname User $gettok($2,%i,44) not on channel $gettok($3,%c,44) }
        inc %c
      }
      inc %i
    }
    halt
  }
  elseif ($1 == SANICK) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*s* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    halt }
    if (!$3) { cmd.fail $sockname $1 | halt }
    if (!$hfind(nicks,$2)) { sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $2 :No such nick | halt }
    if ($2 == $hget(enforcer,nick)) { snotice $sockname * You cannot /SANICK the Enforcer | halt }
    if ($2 === $3) { snotice $sockname * Cannot change nickname; cannot change $2 to $3 | halt }
    if ($hfind(nicks,$3) === $3) { snotice $sockname *** Server Notice -- Nickname $+(,$hfind(nicks,$3),) is already in use. | halt  }    
    if ($left($3,1) isnum) || ($left($3,1) == $chr(45)) { snotice $sockname * Erroneous Nickname (No numbers or dash at start). | halt }
    var %x = 1
    while ($mid($3,%x,1)) {
      if (!$istok($nickchrs,$mid($3,%x,1),32)) {
        snotice $sockname * Erroneous Nickname (Invalid: $mid($3,%x,1) $+ ).
      halt }
    inc %x } 
    sockwrite -n $hget($2,1).item $+(:,$ircd(server)) NOTICE $hget($hget($2,1).item,nick) *** Server Notice -- Your nickname has been changed by $hget($sockname,nick)
    %change = $3 | chgnick $2-3
    sno a *** Sanick Usage -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,host),2,33) $+ ) used /SANICK to change nick $2 to $3
    halt
  }
  elseif ($1 == SETNAME) {
    if (!$2) { cmd.fail $sockname $1 | halt }
    else { snotice $sockname Your realname has been set to be " $+ $2- $+ "
    hadd -m $sockname realname $2- }
    halt
  }
  elseif ($1 == SETHOST) {
    if (!$2) { cmd.fail $sockname $1 | halt }
    if (!$hget($sockname,ircop)) { sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    else {
      var %x = 1
      while ($mid($2,%x,1)) {
        if (!$istok($hostchrs,$mid($2,%x,1),32)) {
          snotice $sockname * /SETHOST :: Invalid host: $2 ( $+ invalid character $+(,$mid($2,%x,1),) $+ )
          halt
        }
        inc %x
      }
      snotice $sockname Your cloakhost has been set to be $+(",$remove($2,@,!),")
      hadd -m $sockname host $+($gettok($hget($sockname,host),-2,64),@,$remove($2,@,!))
    hadd -m $sockname xhost $+($gettok($hget($sockname,host),-2,64),@,$remove($2,@,!)) }
    halt
  }
  elseif ($1 == SETIDENT) {
    if (!$2) { cmd.fail $sockname $1 | halt }
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    else {
      var %x = 1
      while ($mid($2,%x,1)) {
        if (!$istok($hostchrs,$mid($2,%x,1),32)) {
          snotice $sockname * /SETIDENT :: Invalid host: $2 ( $+ invalid character $+(,$mid($2,%x,1),) $+ )
          halt
        }
        inc %x
      }
      snotice $sockname Your ident has been set to be $+(",$left($2,12),")
      hadd -m $sockname ident $left($remove($2,@,!),12)
      hadd -m $sockname host $+($hget($sockname,nick),!,$left($remove($2,@,!),12),@,$gettok($hget($sockname,host),-1,64))
      hadd -m $sockname realhost $+($hget($sockname,nick),!,$left($remove($2,@,!),12),@,$gettok($hget($sockname,realhost),-1,64))
    hadd -m $sockname xhost $+($hget($sockname,nick),!,$left($remove($2,@,!),12),@,$gettok($hget($sockname,realhost),-1,64)) }
    halt
  }
  elseif ($1 == CHGHOST) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (!$3) { snotice $sockname * Syntax: /CHGHOST <nick> <newhost> | halt }
    if (!$hfind(nicks,$2)) { snotice $sockname * User $2 is not online. | halt }
    var %x = 1
    while ($mid($3,%x,1)) {
      if (!$istok($hostchrs,$mid($3,%x,1),32)) {
        snotice $sockname * /CHGHOST :: Invalid host: $3 ( $+ invalid character $+(,$mid($3,%x,1),) $+ )
        halt
        break
      }
      inc %x
    }
    snotice $sockname Cloakhost of $2 has been set to be $+(",$remove($3,@,!),")
    hadd -m $hget($2,1).item host $+($gettok($hget($hget($2,1).item,host),-2,64),@,$remove($3,@,!))
    hadd -m $hget($2,1).item xhost $+($gettok($hget($hget($2,1).item,host),-2,64),@,$remove($3,@,!))
    break
    halt
  }
  elseif ($1 == CHGIDENT) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (!$3) { snotice $sockname * Syntax: /CHGIDENT <nick> <newident> | halt }
    if (!$hfind(nicks,$2)) {
      snotice $sockname * User $2 is not online.
    halt }
    var %x = 1
    while ($mid($3,%x,1)) {
      if (!$istok($hostchrs,$mid($3,%x,1),32)) {
        snotice $sockname * /CHGIDENT :: Invalid ident: $3 ( $+ invalid character $+(,$mid($3,%x,1),) $+ )
        halt
        break
      }
      inc %x
    }
    snotice $sockname Ident of $2 has been set to be $+(",$left($remove($3,@,!),12),")
    hadd -m $hget($2,1).item ident $+($left($remove($3,@,!),12))
    hadd -m $hget($2,1).item host $hfind(nicks,$2) $+ ! $+ $left($remove($3,@,!),12) $+ @ $+ $gettok($hget($hget($2,1).item,host),-1,64)
    hadd -m $hget($2,1).item realhost $hfind(nicks,$2) $+ ! $+ $left($remove($3,@,!),12) $+ @ $+ $gettok($hget($hget($2,1).item,realhost),-1,64)
    hadd -m $hget($2,1).item xhost $hfind(nicks,$2) $+ ! $+ $left($remove($3,@,!),12) $+ @ $+ $gettok($hget($hget($2,1).item,realhost),-1,64)
    halt
  }
  elseif ($1 == CHGNAME) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (!$3) { snotice $sockname * Syntax: /CHGNAME <nick> <new realname> | halt }
    if (!$hfind(nicks,$2)) { snotice $sockname * User $2 is not online. | halt }
    else { snotice $sockname Realname of $2 has been set to be $+(",$3-,")
    hadd -m $hget($2,1).item realname $3- }
    halt
  }
  elseif ($1 == JUMP) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*j* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    return }
    if (!$4) { cmd.fail $sockname $1 | return }
    if ($4 !isnum) { sockwrite -n $sockname : $+ $ircd(server) NOTICE $hget($sockname,nick) :Invalid port " $+ $4 $+ " | halt }
    if (!$hget(mirc,$hget($2,1).item)) && ($ircd(settings,versioncheck)) {
      sockwrite -n $sockname : $+ $ircd(server) NOTICE $hget($sockname,nick) :Unable to redirect user $+($hfind(nicks,$2),:) user is not using mIRC
      halt
    }
    %jump = User has been redirected to another server $+([,$3-4,])
    sockwrite -n $hget($2,1).item : $+ $ircd(server) NOTICE $2 :*** Notice -- You are being redirected to $3, so goodbye
    sockwrite -n $hget($2,1).item : $+ $ircd(server) 010 $2 $3-
  return }
  elseif ($1 == RESTART) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*R* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    return }
    if (!$2) { cmd.fail $sockname $1 | return }
    if ($2 !=== $hget(settings,rspass)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Incorrect Password | halt }
    ircd.restart $hget($sockname,nick) $3-
  return }
  elseif ($1 == DIE) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*D* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    return }
    if (!$2) { cmd.fail $sockname $1 | return }
    if ($2 !=== $hget(settings,diepass)) { sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Incorrect Password | halt }
    else {
      sno s *** Server -- Server shutdown by request of $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) [This IRCd has died.]
      var %i 1, %x 1
      while %i <= $hget(channels,0).item {
        if ($hget($hget(channels,%i).item,%x).item) {
          var %x 1 | while %x <= $hget($hget(channels,%i).item,0).item {
            if ($sock($hget($hget(channels,%i).item,%x).item)) {
              sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$ircd(server)) JOIN $hget(channels,%i).item
              sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$ircd(server)) PRIVMSG $hget(channels,%i).item :This server is gettin' killed!!1
            }
          inc %x }
        }
        inc %i
      }
      sockwrite -n ircd.* $+(:,$ircd(server)) QUIT :This IRCd has died.
      delserver
      .timer 1 0 ircd.off
    }
  return }
  elseif ($1 == REHASH) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*r* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    return }
    ircd.rehash
    halt
  }
  elseif ($1 == SMSG) {
    if (!$3) { cmd.fail $sockname $1 | return }
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (!$2) { cmd.fail $sockname $1 | return }
    if (!$hfind(nicks,$2)) { sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $2 :No such nick | halt }
    sockwrite -n $sockname $+(:,$ircd(server)) 382 $2 :-> - $+ $2 $+ - $3-
    sockwrite -n $hget($2,1).item $+(:,$ircd(server)) 382 $2 : $+ $hget($sockname,nick) $+ : $3-
  return }
  elseif ($1 == WALLOPS) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*l* !iswmcs $hget($sockname,modes)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    return }
    if (!$2) { cmd.fail $sockname $1 | return }
    wops $hget($sockname,host) $2-
  return }
  elseif ($1 == KILL) || ($1 == AVADAKEDAVRA) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*k* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    return }
    if (!$2) { cmd.fail $sockname $1 | return }
    var %2 = $iif($hget(newnick,$2),$hget(newnick,$2),$2)
    if (!$hfind(nicks,%2)) { sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) %2 :No such nick | halt }
    if ($hget($sockname,olvl)) && ($hget($hget(%2,1).item,olvl)) {
      if ($hget($hget(%2,1).item,olvl) >= $hget($sockname,olvl)) {
        snotice $sockname You cannot kill %2 [same level or higher]
        if ($sock($hget(%2,1).item)) sockwrite -n $hget(%2,1).item $+(:,$ircd(server)) NOTICE %2 :*** Warning -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,64) $+ ) tried to kill you off the server ( $+ $iif($3, $iif($left($3,1) == :,$right($3-,-1),$3-)   ,No reason) $+ )
      return }
    }
    if ($2 == $hget(enforcer,nick)) {
      closelink $sockname Local kill by $hget(enforcer,nick) ( $+ That was a bad idea... $+ )
      enforcekill $sockname
      halt
    }
    sno k *** Kill Message -- Received kill msg for %2 ( $+ $gettok($hget($hget(%2,1).item,realhost),2,64) $+ ) Path  $+ $hget($sockname,nick) $+  ( $+ $iif($3,$iif($left($3,1) = :,$right($3-,-1),$3-),No reason) $+ )
    if ($sock($hget(%2,1).item)) {
      sockwrite -n $hget(%2,1).item : $+ $hget($hget($hget(enforcer,nick),1).item,host) PRIVMSG %2 :ACTION appears from the mist around you
      sockwrite -n $hget(%2,1).item : $+ $hget($hget($hget(enforcer,nick),1).item,host) PRIVMSG %2 :ACTION Shows you a warrant: $hget($sockname,nick) ( $+ $iif($3,$iif($left($3,1) = :,$right($3-,-1),$3-),No reason) $+ )
      sockwrite -n $hget(%2,1).item : $+ $hget($hget($hget(enforcer,nick),1).item,host) PRIVMSG %2 :ACTION Politely escorts you out from the Network
      sockwrite -n $hget(%2,1).item $+(:,$ircd(server)) 304 $+(:,[,$hget($sockname,nick),]) $iif($3,$iif($left($3,1) = :,$right($3-,-1),$3-),No reason)
    }
    if ($sock($hget(%2,1).item)) .sockwrite -n $hget(%2,1).item $+(:,$ircd(server)) NOTICE $2 :*** You are being disconnected from this server: $+([,$hget($sockname,nick),]) ( $+ $iif($3,$iif($left($3,1) = :,$right($3-,-1),$3-),No reason) $+ )
    if ($hget(newnick,$2)) { hdel newnick $2 }
    closelink $hget(%2,1).item Local kill by $hget($sockname,nick) ( $+ $iif($3,$iif($left($3,1) = :,$right($3-,-1),$3-),No reason) $+ )
  return }
  elseif ($1 == KLINE) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*K* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    return }
    if ($hfind(klines,$3)) { snotice $sockname *** Notice -- K:Line $3 already exists. | halt }
    if ($left($2,1) = -) {
      if (!$hfind(klines,$right($2,-1))) {
      snotice $sockname *** Notice -- No such K:line | halt }
      else {
        sno s *** Server -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) removed K:line $right($2,-1) (set by $hget(klines,nick_ $+ $gettok($2,1,45)) on $hget(klines,date_ $+ $gettok($2,1,45)) $+ ) $chr(91) $+ $hget(klines,reason_ $+ $gettok($2,1,45)) $+ $chr(93)
        hdel klines $right($2,-1)
        hdel -w klines $+(*_,$right($2,-1))
        hsave -b klines data\klines.db
      return }
    }
    if ($left($2,1) != -) && (!$3) { cmd.fail $sockname $1 | return }
    if ($left($2,1) !== +) && ($remove($2,+) !isnum) {
    snotice $sockname *** Notice -- Invalid expire | halt }
    var %host = $makermask($3)
    if ($hfind(nicks,$3)) { var %sock = $hget($3,1).item
      var %host = $+(*@,$gettok($hget(%sock,realhost),2,64))
    }
    if ($len($makermask(%host)) < 8) {
    snotice $sockname *** Notice -- Please use a bigger hostname match | halt }
    var %y = 1
    while $hget(elines,%y).item {
      if ($hget(elines,%y).item iswm %host) || (%host iswm $hget(elines,%y).item) {
        snotice $sockname *** Notice -- Cannot add K:Line: Host %host matches an except on this server.
      return }
      inc %y
    }
    if (@ !isin %host) || (!$makermask(%host)) {
    snotice $sockname *** Notice -- Invalid hostname | halt }
    hadd klines %host ( $+ $hget($sockname,nick) on $fulldate $+ ) $iif($4,( $+ $4- $+ ),(No reason))
    hadd -m klines reason_ $+ %host $iif($4-,$4-,No reason)
    hadd klines date_ $+ %host $fulldate
    hadd klines nick_ $+ %host $hget($sockname,nick)
    if ($2 !== +0) hadd klines expire_ $+ %host $calc($ctime + $calc($remove($2,+)*60) )
    hsave -b klines data\klines.db
    sno s *** Global Notice -- Kill line active for %host by $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) $iif($4,( $+ $4- $+ ),(No reason)) $iif($2 == +0,$+([,noexpire,]))
    var %z = 1
    while $hget(users,%z).item {
      if (%host iswm $gettok($hget($hget(users,%z).item,realhost),2,33)) || (%host iswm $sock($hget(users,%z).item).ip) || (%host iswm $makermask($sock($hget(users,%z).item).ip)) {
        sno s *** Server -- Kill line active for $hget($hget(users,%z).item,nick) $chr(91) $+ $sock($hget(users,%z).item).ip $+ $chr(93)
        if ($sock($hget(users,%z).item)) sockwrite -n $hget(users,%z).item $+(:,$ircd(server)) NOTICE $hget($hget(users,%z).item,nick) :*** You are banned from $hget(settings,serverdesc) $iif($4-,( $+ $4- $+ ),(No reason)) $iif($2 == +0,$+([,noexpire,]))
        .timer 1 0 closelink $hget(users,%z).item User has been banned from using this server
        inc %z
        continue
      }
      inc %z
    }
    return
  }
  elseif ($1 == QLINE) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*q* !iswmcs $hget($sockname,flags)) { sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges | halt }
    if ($hfind(qlines,$3)) { snotice $sockname *** Notice -- Q:Line $3 already exists. | halt }
    if ($left($2,1) = -) {
      if (!$hfind(qlines,$right($2,-1))) { snotice $sockname *** Notice -- No such Q:line | halt }
      else {
        sno s *** Server -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) removed Q:line $right($2,-1) (set by $hget(qlines,$+(nick_,$gettok($2,1,45))) on $hget(qlines,$+(date_,$gettok($2,1,45))) $+ ) $chr(91) $+ $hget(qlines,$+(reason_,$gettok($2,1,45))) $+ $chr(93)
        hdel qlines $right($2,-1)
        hdel -w qlines $+(*_,$right($2,-1))
        hsave -b qlines data\qlines.db
      halt }
    }
    if ($left($2,1) != -) && (!$3) { cmd.fail $sockname $1 | return }
    if ($left($2,1) !== +) && ($remove($2,+) !isnum) { snotice $sockname *** Notice -- Invalid expire | halt }
    if ($chr(95) isin $2) { snotice $sockname *** Notice -- Invalid Q:Line (underscores are not allowed) | halt }
    hadd qlines $3 ( $+ $hget($sockname,nick) on $fulldate $+ ) $iif($4,( $+ $4- $+ ),(No reason))
    hadd -m qlines $+(reason_,$3) $iif($4-,$4-,No reason)
    hadd qlines $+(date_,$3) $fulldate
    hadd qlines $+(nick_,$3) $hget($sockname,nick)
    if ($2 !== +0) hadd qlines $+(expire_,$3) $calc($ctime + $calc($remove($2,+)*60) )
    hsave -b qlines data\qlines.db
    sno s *** Global Notice -- Q:Line active for $3 by $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) $iif($4,( $+ $4- $+ ),(No reason)) $iif($2 == +0,$+([,noexpire,]))
    if ($left($3,1) == $chr(35)) {
      var %z = 1
      while ($hget(channels,%z).item) {
        if ($3 iswm $hget(channels,%z).item) || ($hget(channels,%z).item iswm $3) || ($3 == $hget(channels,%z).item) {
          sno q *** Server -- Q:Line match found for channel $hget(channels,%z).item $iif($4,( $+ $4- $+ ),(No reason))
          if ($hget($hget(channels,%z).item,users) > 0) enforce $hget(channels,%z).item $hget($sockname,nick) $iif($4,( $+ $4- $+ ),(No reason))
          inc %z
        continue }
      inc %z }
    }
    else {
      var %z = 1
      while ($hget(nicks,%z).item) {
        if ($3 iswm $hget(nicks,%z).item) || ($hget(nicks,%z).item iswm $3) || ($3 == $hget(nicks,%z).item) {
          sno q *** Server -- Q:Line match found for user $hfind(nicks,$3) ( $+ $gettok($hget($hget($hfind(nicks,$3),1).item,realhost),2,33) $+ ) $iif($4,( $+ $4- $+ ),(No reason))
          sockwrite -n $hget($hget(nicks,%z).item,1).item $+(:,$ircd(server)) NOTICE $hget($hget(users,%z).item,nick) :*** Your nickname matches a Q:Line on this server and therefore will be changed. $iif($4,( $+ $4- $+ ),(No reason))
          .timerchgnick $+ $hget($hget(nicks,%z).item,1).item 1 0 CHGNICK $hget(nicks,%z).item $+(Guest,$r(1,9999999))
          inc %z
        continue }
      inc %z }
    }
    return
  }
  elseif ($1 == SHUN) {
    if (!$hget($sockname,ircop)) { sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*K* !iswmcs $hget($sockname,flags)) { sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges | halt }
    if ($hfind(shuns,$3)) { snotice $sockname *** Notice -- Shun $3 already exists. | halt }
    if ($left($2,1) = -) {
      if (!$hfind(shuns,$right($2,-1))) { snotice $sockname *** Notice -- No such Shun. | halt }
      else {
        sno s *** Server -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) removed Shun $right($2,-1) (set by $hget(shuns,nick_ $+ $gettok($2,1,45)) on $hget(shuns,date_ $+ $gettok($2,1,45)) $+ ) $chr(91) $+ $hget(shuns,reason_ $+ $gettok($2,1,45)) $+ $chr(93)
        hdel shuns $right($2,-1)
        hdel -w shuns $+(*_,$right($2,-1))
        hsave -b shuns data\shuns.db
      halt }
    }
    if ($left($2,1) != -) && (!$3) { cmd.fail $sockname $1 | return }
    if ($left($2,1) !== +) && ($remove($2,+) !isnum) {
    snotice $sockname *** Notice -- Invalid expire | halt } 
    if (@ !isin $3) || (. !isin $3) || (!$makermask($3)) {
    snotice $sockname *** Notice -- Invalid hostname | halt }
    if ($len($makermask($3)) < 10) {
    snotice $sockname *** Notice -- Please use a bigger hostname match | halt }
    var %y = 1
    while $hget(elines,%y).item {
      if ($hget(elines,%y).item iswm $3) || ($3 iswm $hget(elines,%y).item) {
        snotice $sockname *** Notice -- Cannot add Shun: Host $3 matches an except on this server.
      return }
      inc %y
    }
    hadd shuns $3 ( $+ $hget($sockname,nick) on $fulldate $+ ) $iif($4,( $+ $4- $+ ),(No reason))
    hadd -m shuns reason_ $+ $3 $iif($4-,$4-,No reason)
    hadd shuns date_ $+ $3 $fulldate
    hadd shuns nick_ $+ $3 $hget($sockname,nick)
    if ($2 !== +0) hadd shuns expire_ $+ $3 $calc($ctime + $calc($remove($2,+)*60) )
    hsave -b shuns data\shuns.db
    sno s *** Server -- Shun active for $3 by $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) $iif($4,( $+ $4- $+ ),(No reason)) $iif($2 == +0,$+([,noexpire,]))
  return }
  elseif ($1 == ZLINE) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*z* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    return }
    var %y = 1
    while $hget(elines,%y).item {
      if ($hget(elines,%y).item iswm $3) || ($remove($hget(elines,%y).item,@,*) = $3) || ($3 iswm $hget(elines,%y).item) {
        snotice $sockname *** Notice -- Cannot add Z:Line: Host $3 matches an except on this server.
      return }
      inc %y
    }
    if ($hfind(zlines,$3)) { snotice $sockname *** Notice -- Z:Line $3 already exists. | halt }
    if ($left($2,1) = -) {
      if (!$hfind(zlines,$right($2,-1))) { snotice $sockname *** Notice -- No such Z:line | halt }
      else {
        sno s *** Server -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) removed Z:line $right($2,-1) (set by $hget(zlines,nick_ $+ $gettok($2,1,45)) on $hget(zlines,date_ $+ $gettok($2,1,45)) $+ ) $chr(91) $+ $hget(zlines,reason_ $+ $gettok($2,1,45)) $+ $chr(93)
        hdel zlines $right($2,-1)
        hdel -w zlines $+(*_,$right($2,-1))
        hsave -b zlines data\zlines.db
      return }
    }
    if ($left($2,1) != -) && (!$3) { cmd.fail $sockname $1 | return }
    if ($left($2,1) !== +) && ($remove($2,+) !isnum) {
    snotice $sockname *** Notice -- Invalid expire | halt }
    if ($remove($3,.) !isnum) || (. !isin $3) {
    snotice $sockname *** Notice -- Invalid IP address | halt }
    if ($len($3) < 6) {
    snotice $sockname *** Notice -- Please use a bigger IP match | halt }
    hadd zlines $3 ( $+ $hget($sockname,nick) on $fulldate $+ ) $iif($4,( $+ $4- $+ ),(No reason))
    hadd -m zlines reason_ $+ $3 $iif($4-,$4-,No reason)
    hadd zlines date_ $+ $3 $fulldate
    hadd zlines nick_ $+ $3 $hget($sockname,nick)
    if ($2 !== +0) hadd zlines expire_ $+ $3 $calc($ctime + $calc($remove($2,+)*60) )
    hsave -b zlines data\zlines.db
    sno s *** Server -- Zap line active for $3 by $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) $iif($4,( $+ $4- $+ ),(No reason)) $iif($2 == +0,$+([,noexpire,]))
    var %z = 1
    while $hget(users,%z).item {
      if ($3 iswm $sock($hget(users,%z).item).ip) || ($3 = $sock($hget(users,%z).item).ip) {
        sno s *** Server -- Zap line active for $hget($hget(users,%z).item,nick) $chr(91) $+ $sock($hget(users,%z).item).ip $+ $chr(93)
        sockwrite -n $hget(users,%z).item $+(:,$ircd(server)) NOTICE $hget($hget(users,%z).item,nick) :*** You are banned from $hget(settings,serverdesc) $iif($4-,( $+ $4- $+ ),(No reason)) $iif($2 == +0,$+([,noexpire,]))
        .timer 1 0 closelink $hget(users,%z).item Z:Lined (User has been banned from using this server)
        inc %z
      continue }
    inc %z }
  return }
  elseif ($1 == ELINE) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*e* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    return }
    if ($hfind(elines,$3)) {
    snotice $sockname *** Notice -- E:Line $3 already exists. | halt }
    if ($left($2,1) = -) {
      if (!$hfind(elines,$right($2,-1))) {
      snotice $sockname *** Notice -- No such E:line | halt }
      else {
        sno s *** Server -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) removed E:line $right($2,-1) (set by $hget(elines,nick_ $+ $gettok($2,1,45)) on $hget(elines,date_ $+ $gettok($2,1,45)) $+ ) $chr(91) $+ $hget(elines,reason_ $+ $gettok($2,1,45)) $+ $chr(93)
        hdel elines $right($2,-1)
        hdel -w elines $+(*_,$right($2,-1))
        hsave -b elines data\elines.db
      return }
    }
    if ($left($2,1) != -) && (!$3) { cmd.fail $sockname $1 | return }
    if ($left($2,1) !== +) || ($remove($2,+) !isnum) {
    snotice $sockname *** Notice -- Invalid expire | halt }
    if (@ !isin $3) && (. !isin $3) || (!$makermask($3)) {
    snotice $sockname *** Notice -- Invalid hostname | halt }
    if ($len($makermask($3)) < 10) {
    snotice $sockname *** Notice -- Please use a bigger hostname match | halt }
    hadd elines $3 ( $+ $hget($sockname,nick) on $fulldate $+ ) $iif($4,( $+ $4- $+ ),(No reason))
    hadd -m elines reason_ $+ $3 $iif($4-,$4-,No reason)
    hadd elines date_ $+ $3 $fulldate
    hadd elines nick_ $+ $3 $hget($sockname,nick)
    if ($2 !== +0) hadd elines expire_ $+ $3 $calc($ctime + $calc($remove($2,+)*60) )
    hsave -b elines data\elines.db
    sno s *** Server -- Exception line active for $3 by $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) $iif($4,( $+ $4- $+ ),(No reason)) $iif($2 == +0,$+([,noexpire,]))
  return }
  elseif ($1 == ADDOPER) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*E* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    return }
    if (!$7) { snotice $sockname * Syntax -- /ADDOPER <username> <password> <host> <modes> <snomasks> <flags> | return }
    if ($ini(opers.conf,$2)) { snotice $sockname *** Notice -- Username  $+ $2 $+  already exists. | return }
    if ($len($3) <= 4) { snotice $sockname *** Notice -- Invalid password; is too short. | return }
    if (@ !isin $4) { snotice $sockname *** Notice -- Invalid hostname; format is ident@hostname | return }
    .writeini -n opers.conf $2 pass $3 | .writeini -n opers.conf $2 modes $remove($5,+,-)
    .writeini -n opers.conf $2 snomasks $remove($6,+,-)
    .writeini -n opers.conf $2 flags $remove($7,+,-)
    .writeini -n opers.conf $2 host $4
    sno o *** Oper Add -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,host),2,33) $+ ) added O:line for $2 $+([,$4,]) with flags: $7 and snomasks: $6
  return }
  elseif ($1 == DELOPER) {
    if (!$hget($sockname,ircop)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You are not an IRC Operator | halt }
    if (*E* !iswmcs $hget($sockname,flags)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 481 $hget($sockname,nick) :Permission denied - You do not have the correct IRC Operator privileges
    return }
    if (!$2) { snotice $sockname * Syntax -- /DELOPER <username> | return }
    if (!$ini(opers.conf,$2)) {
    snotice $sockname * ERROR -- Username  $+ $2 $+  not found. | return }
    sno o *** Oper Del -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,host),2,33) $+ ) removed O:line for $2 $+([,$readini(opers.conf,$2,host),]) (Flags: $readini(opers.conf,$2,flags) $+ )
    .remini opers.conf $2
  return }
  elseif ($1 == INFO) && ($ircd(settings,services)) {
    if (!$2) { cmd.fail $sockname $1 | return }
    if ($left($2,1) = $chr(35)) || ($left($2,1) = $chr(43)) {
      if (!$hfind(rchans,$2)) { snotice $sockname * Channel $+(,$2,) isn't registered. | return }
      else {
        snotice $sockname -=-=-=-=-=- Channel information $+(,$hfind(rchans,$2),) -=-=-=-=-=-
        snotice $sockname Founder: $hget(rchans,$+(founder_,$2))
        snotice $sockname Description: $hget(rchans,$+(desc_,$2))
        snotice $sockname Registered: $asctime($hget(rchans,$+(rdate_,$2)))
        if (*P* iswmcs $hget($sockname,modes)) || (*a* iswmcs $hget($sockname,modes)) || (*Z* iswmcs $hget($sockname,modes)) snotice $sockname E-mail: $hget(rchans,$+(email_,$2))
        if (*a* iswmcs $hget($sockname,modes)) || (*Z* iswmcs $hget($sockname,modes)) { snotice $sockname Password: $hget(rchans,$+(pass_,$2)) }
        if (*a* iswmcs $hget($sockname,modes)) || (*Z* iswmcs $hget($sockname,modes)) { snotice $sockname IP address: $hget(rchans,$+(ip_,$2)) }
        if (*P* iswmcs $hget($sockname,modes)) || (*a* iswmcs $hget($sockname,modes)) || (*Z* iswmcs $hget($sockname,modes)) snotice $sockname Topic locked: $iif($hget(rchans,$+(topiclock_,$2)),Yes,No)
        if (*P* iswmcs $hget($sockname,modes)) || (*a* iswmcs $hget($sockname,modes)) || (*Z* iswmcs $hget($sockname,modes)) snotice $sockname Mode locked: $iif($hget(rchans,$+(modelock_,$2)),Yes,No)
        snotice $sockname Last topic: $iif($hget(rchans,$+(lasttopic_,$2)),$hget(rchans,$+(lasttopic_,$2)) (set by $hget(topics,$+(topicsetter_,$2)) $+ ),none)
        snotice $sockname Last used: $iif($hget(rchans,$+(lastused_,$2)),$asctime($hget(rchans,$+(lastused_,$2)),ddd mmm dd yyyy HH:mm:ss),$fulldate)
        snotice $sockname -=-=-=-=-=- End of Channel information -=-=-=-=-=-
      halt }
    }
    if (!$hfind(rnicks,$2)) { snotice $sockname * Username $+(,$2,) isn't registered. | return }
    var %info.sock = $hget($iif($hget($hget(onirc,$2),nick),$hget($hget(onirc,$2),nick),$2),1).item
    if (*I* iswmcs $hget(%info.sock,modes)) && ($hget($sockname,nick) !== $2) { sockwrite -n %info.sock $+(:,$ircd(server)) NOTICE $hget(%info.sock,nick) :*** Server Notice -- $hget($sockname,nick) ( $+ $gettok($hget($sockname,realhost),2,33) $+ ) did an /INFO on you. }
    snotice $sockname -=-=-=-=-=- Username information $+(,$hfind(rnicks,$2),) -=-=-=-=-=-
    snotice $sockname Last realname: $hget(rnicks,$+(rname_,$2))
    if ($hget($hget(onirc,$2),nick)) { snotice $sockname User is currently online (as $hget($hget(onirc,$2),nick) $+ )
      if (*P* iswmcs $hget($hget(onirc,$2),modes)) { snotice $sockname User is a System Operator $iif($hget($hget(onirc,$2),ircop), - $iif($hget($sockname,olvl) >= 4,IRC Administrator,IRC Operator)) | goto ie }
      if (*a* iswmcs $hget($hget(onirc,$2),modes)) { snotice $sockname User is a System Manager $iif($hget($hget(onirc,$2),ircop), - $iif($hget($sockname,olvl) >= 4,IRC Administrator,IRC Operator)) | goto ie }
      if (*Z* iswmcs $hget($hget(onirc,$2),modes)) { snotice $sockname User is an $iif($hget($hget(onirc,$2),ircop),$iif($hget($sockname,olvl) >= 4,IRC Administrator,IRC Operator)) - System Root Administrator | goto ie }
    }
    :ie
    snotice $sockname Registered: $asctime($hget(rnicks,$+(rdate_,$2)))
    if (*P* iswmcs $hget($sockname,modes)) || (*a* iswmcs $hget($sockname,modes)) || (*Z* iswmcs $hget($sockname,modes)) snotice $sockname E-mail: $hget(rnicks,$+(email_,$2))
    if (*Z* iswmcs $hget($sockname,modes)) { snotice $sockname Password: $hget(rnicks,$+(pass_,$2)) }
    if (*a* iswmcs $hget($sockname,modes)) || (*Z* iswmcs $hget($sockname,modes)) { snotice $sockname IP address: $hget(rnicks,$+(ip_,$2)) }
    if (*P* iswmcs $hget($sockname,modes)) || (*a* iswmcs $hget($sockname,modes)) || (*Z* iswmcs $hget($sockname,modes)) snotice $sockname Secured on IP: $iif($hget(rnicks,$+(secure_,$2)),Yes,No)
    snotice $sockname Last seen: $asctime($hget(rnicks,$+(lastseen_,$2))) $iif($hget($hget(onirc,$2),nick),$+($chr(40),now,$chr(41)))
    snotice $sockname Recent quit message: $hget(rnicks,$+(quitmsg_,$2))
    snotice $sockname -=-=-=-=-=- End of Username information -=-=-=-=-=-
  return }
  elseif ($1 == AKICK) && ($ircd(settings,services)) {
    if (!$3) { snotice $sockname * Syntax -- /AKICK $iif($hfind(rchans,$2),$v1,<channel>) ADD|DEL|LIST <nick!ident@hostmask> [reason]
    return }
    if (!$hget($sockname,loggedin)) { snotice $sockname Please login/register first. | return }
    if (!$hfind(rchans,$2)) { snotice $sockname Channel $2 isn't registered... | return }
    if ($3 = LIST) {
      if (!$readini(data\chans.db,$+(access_,$replace($2,[,*,],&)),$hget($sockname,loggedin))) && ($hget(rchans,$+(founder_,$2)) != $hget($sockname,loggedin) && ($hget($sockname,ircop) != true)) {
        snotice $sockname Access denied; you don't have any access
      return }
      if ($readini(data\chans.db,$+(access_,$replace($2,[,*,],&)),$hget($sockname,loggedin)) < 5) && ($hget($sockname,ircop) != true) {
        snotice $sockname Access denied; not enough access
      return }
      if ($ini(data\akicks.db,$replace($2,[,*,],&))) { snotice $sockname Auto-kick list for $2 }
      var %ac = 1, %x = 1, %chan = $2
      while $ini(data\akicks.db,$replace($2,[,*,],&),%ac) {
        if ($gettok($ini(data\akicks.db,$replace($2,[,*,],&),%ac),1,95) == NICK) { inc %ac }
        if ($gettok($ini(data\akicks.db,$replace($2,[,*,],&),%ac),1,95) == DATE) { inc %ac }
        if ($ini(data\akicks.db,$replace($2,[,*,],&),%ac)) {
          var %h = $ini(data\akicks.db,$replace($2,[,*,],&),%ac), %n = $readini(data\akicks.db,$replace($2,[,*,],&),nick_ $+ %h), %d = $readini(data\akicks.db,$replace($2,[,*,],&),date_ $+ %h), %r = $readini(data\akicks.db,$replace($2,[,*,],&),%h)
          snotice $sockname %x $+ ) %h - (By %n on $asctime(%d) $chr(91) $+ %r $+ $chr(93)
        inc %ac | inc %x }
      }
      if (!%n) { snotice $sockname * $2 Auto-kick list is empty }
      if (%n) { snotice $sockname End of /AKICK list. }
    return }
    if ($3 == ADD) {
      if (!$5) { snotice $sockname * Syntax -- /AKICK $iif($hfind(rchans,$2),$v1,<channel>) ADD nick!host [Reason]
      return }
      if (!$makemask($4)) { snotice $sockname Invalid hostmask. | halt }
      if ($ini(data\akicks.db,$replace($2,[,*,],&),$makemask($4))) { snotice $sockname Mask $makemask($4) already exists on $2 akick list | return }
      writeini -n data\akicks.db $replace($2,[,*,],&) $makemask($4) $5- | writeini -n data\akicks.db $replace($2,[,*,],&) $+(nick_,$makemask($4)) $hget($sockname,nick) | writeini -n data\akicks.db $replace($2,[,*,],&) $+(date_,$makemask($4)) $ctime
      snotice $sockname Mask $makemask($4) added to $2 akick list
      var %x = 1
      while (%x <= $hget($2,0).item) {
        if ($sock($hget($2,%x).item)) { checkakick $hget($2,%x).item $2 }
        inc %x
      }      
    return }
    if ($3 = DEL) {
      if (!$4) { snotice $sockname * Syntax -- /AKICK $iif($hfind(rchans,$2),$v1,<channel>) DEL nick!ident@host
        return
      }
      if (!$ini(data\akicks.db,$replace($2,[,*,],&),$makemask($4))) { snotice $sockname Mask $makemask($4) not found on $2 akick list | return }
      remini data\akicks.db $replace($2,[,*,],&) $makemask($4) | remini data\akicks.db $replace($2,[,*,],&) $+(nick_,$makemask($4)) | remini data\akicks.db $2 $+(date_,$makemask($4))
      if ($ini(data\akicks.db,$replace($2,[,*,],&)) = 1) { remini data\akicks.db $replace($2,[,*,],&) }
      snotice $sockname Mask $makemask($4) removed from $2 akick list
    return }
  return }
  elseif ($1 == ACCESS) && ($ircd(settings,services)) {
    if (!$3) { snotice $sockname * Syntax -- /ACCESS $iif($hfind(rchans,$2),$v1,<channel>) ADD|DEL|LIST [username] [level] | return }
    if (!$hget($sockname,loggedin)) { snotice $sockname Please login/register first. | return }
    if (!$hfind(rchans,$2)) { snotice $sockname Channel $+(,$2,) isn't registered... | return }
    if ($3 = LIST) {
      if (!$readini(data\access.db,$replace($2,[,*,],&),$hget($sockname,loggedin))) && ($hget(rchans,$+(founder_,$2)) !== $hget($sockname,loggedin) && ($hget($sockname,ircop) != true)) {
      snotice $sockname Access denied; you don't have any access | return }
      if ($readini(data\access.db,$replace($2,[,*,],&),$hget($sockname,loggedin)) < 5) && ($hget($sockname,ircop) !== true) { snotice $sockname Access denied; not enough access. | return }
      var %x = 1, %ac = 1
      if ($ini(data\access.db,$replace($2,[,*,],&),%ac)) { snotice $sockname Access list for $+(,$2,) }
      while $ini(data\access.db,$replace($2,[,*,],&),%ac) {
        if ($ini(data\access.db,$replace($2,[,*,],&),%ac)) {
          var %n = $ini(data\access.db,$replace($2,[,*,],&),%ac)
          var %l = $readini(data\access.db,$replace($2,[,*,],&),%n)
          snotice $sockname %x $+ ) %n - %l
        inc %ac | inc %x }
      }
      if (!%n) { snotice $sockname Access list is empty }
      if (%n) { snotice $sockname End of /ACCESS list. }
      return
    }
    if ($3 = ADD) {
      if (!$5) { snotice $sockname * Syntax -- /ACCESS $+(,$iif($hfind(rchans,$2),$v1,<channel>),) ADD [username] [level] | return }
      if ($5 !isnum) || ($5 > 9999) || ($5 < 0) {
      snotice $sockname Invalid level: must be > 0 < 9999 | return }
      if (!$readini(data\access.db,$replace($2,[,*,],&),$hget($sockname,loggedin))) && ($hget(rchans,$+(founder_,$2)) != $hget($sockname,loggedin)) && (!$hget($sockname,ircop)) {
      snotice $sockname Access denied; you are not logged in or have not the correct privilege. | return }
      if ($readini(data\access.db,$replace($2,[,*,],&),$hget($sockname,loggedin)) <= $5) && ($hget(rchans,$+(founder_,$2)) != $hget($sockname,loggedin)) && (!$hget($sockname,ircop)) {
      snotice $sockname Access denied; not enough access | return }
      if (!$hfind(rnicks,$4)) { snotice $sockname User  $+ $4 $+  isn't registered | return }
      if ($ini(data\access.db,$2,$replace($4,[,*,],&))) { snotice $sockname User $+(,$hfind(rnicks,$4),) already exists on $+(,$2,) access list | return }
      snotice $sockname User $+(,$hfind(rnicks,$4),) added to $+(,$2,) access list with level $5
      writeini -n data\access.db $2 $hfind(rnicks,$replace($4,[,*,],&)) $5
    }
    if ($3 = DEL) {
      if (!$4) { snotice $sockname * Syntax -- /ACCESS $iif($hfind(rchans,$2),$v1,<channel>) DEL [username] | return }
      if (!$readini(data\access.db,$replace($2,[,*,],&),$hget($sockname,loggedin))) && ($hget(rchans,$+(founder_,$2)) != $hget($sockname,loggedin)) && (!$hget($sockname,ircop)) { snotice $sockname Access denied; you are not logged in or has not the correct privilege. | return }
      if ($readini(data\access.db,$replace($2,[,*,],&),$hget($sockname,loggedin)) >= $readini(data\access.db,$replace($2,[,*,],&),$4)) && ($hget(rchans,$+(founder_,$2)) != $hget($sockname,loggedin)) && (!$hget($sockname,ircop)) { snotice $sockname Access denied; $4 got higher (or equal) level. | return }
      if (!$ini(data\access.db,$replace($2,[,*,],&),$replace($4,[,*,],&))) { snotice $sockname User $4 not found on $2 access list | return }
    snotice $sockname $+(,$hfind(rnicks,$4),) removed from $+(,$2,) access list | remini data\access.db $replace($2,[,*,],&) $4 | return }
  }
  elseif ($1 == SERVSET) {
    if (!$hget($sockname,ircop)) { snotice $sockname * Access denied; you are not an IRC Operator | return }
    if (!$2) { snotice $sockname * Syntax: $+(/,$upper($1),) option {parameters} - Or try $+(/,$upper($1)) help | return }
    if ($2 == HELP) {
      snotice $sockname -=-=-=-=-=- $upper($1) Help -=-=-=-=-=-
      snotice $sockname * Syntax: $+(/,$upper($1),) option {parameters}
      snotice $sockname -
      snotice $sockname LOGONNEWS - Set logon message which will be shown on connect
      snotice $sockname DEFCON - Set DEFCON level of the server
      snotice $sockname -
      snotice $sockname -=-=-=-=-=- End of $upper($1) Help -=-=-=-=-=-
      return
    }
    if (*S* !iswmcs $hget($sockname,flags)) { snotice $sockname * Permission denied; you do not have the correct IRC Operator privileges | return }
    if ($2 == LOGONNEWS) {
      if (!$3) {
        snotice $sockname * Logonnews unset.
        hdel data logonnews
        hsave -b data data\reads.dll
      return }
      if ($3) && (!$7) {
        snotice $sockname * Logonnews too short; min. 5 words.
        hdel data logonnews
        hsave -b data data\reads.dll
      return }
      else {
        snotice $sockname * Logonnews $iif($hget(data,logonnews),changed;,set;) $3-
        hadd data logonnews $hget($sockname,nick) $ctime $3-
        hsave -b data data\reads.dll
      return }
    return }
    if ($2 == DEFCON) {
      if ($3 != ON) && ($3 != OFF) { snotice $sockname * Please use $+(/,$upper($1)) $upper($2) {ON|OFF} | return }
      if ($3 = ON) {
        if ($hget(defcon)) { snotice $sockname * Server is already in DEFCON mode. |return }
      }
      if ($3 = OFF) {
        if ($hget(defcon)) {
          sockwrite -n ircd.* $+(:,$ircd(server)) NOTICE $hget($hget(users,%x).item,nick) :*** Defcon Alert -- Server is now back to normal. All services are working.
          hfree defcon
        return }
        else { snotice $sockname * Server is not in DEFCON mode.
        return }
      }
      sockwrite -n ircd.* $+(:,$ircd(server)) NOTICE $hget($hget(users,%x).item,nick) :*** Defcon Alert -- Server is now in DEFCON mode, some services have been disabled.
      snotice $sockname - Incoming connections
      snotice $sockname - Registration commands
      snotice $sockname - Channel joins
      snotice $sockname - Nickchanges
      snotice $sockname - Only registered users can privmsg and notice
      snotice $sockname - /OPER command
      snotice $sockname * To disable DEFCON, use $+(/,$upper($1)) $upper($2) OFF
      hmake defcon
    return }
  }
  elseif ($1 == MEMO) && ($ircd(settings,services)) {
    if (!$hget($sockname,loggedin)) { snotice $sockname * You are not registered/logged in. | return }
    if (!$2) {
      sockwrite -n $sockname $+(:,$ircd(server)) 501 $hget($sockname,nick) :MEMO Not enough parameters
    snotice $sockname * Syntax: $+(/,$upper($1),) SEND|READ {username} [text] - Or try $+(/,$upper($1)) help | return }
    if ($2 == HELP) {
      snotice $sockname -=-=-=-=-=- $upper($1) Help -=-=-=-=-=-
      snotice $sockname * Syntax: $+(/,$upper($1),) SEND|READ {username} [text]
      snotice $sockname -
      snotice $sockname SEND <nick> <text> - Sends message to registered user
      snotice $sockname READ <nr> - Reads memo nr <nr>
      snotice $sockname LIST - Lists all your memo's
      if ($hget(settings,maxmemo)) {
        snotice $sockname -
        snotice $sockname Each registered user can have $+(,$hget(settings,maxmemo),) memo's.
      }
      snotice $sockname -=-=-=-=-=- End of $upper($1) Help -=-=-=-=-=-
      return
    }
    if (!$hget($sockname,loggedin)) { snotice $sockname * You are not registered/logged in. | return }
    if ($2 == LIST) {
      var %x = 1, %memos
      while ($hget(rnicks,%x).item) {
        if ($hget(rnicks,%x).item = $+(memos_,$hget($sockname,loggedin))) {
          var %z = 1
          while ($gettok($hget(rnicks,%x).data,%z,127)) {
            inc %memos
            snotice $sockname * $+(#,%memos) $+ ) By $gettok($gettok($hget(rnicks,%x).data,%z,127),1,32) on $asctime($gettok($gettok($hget(rnicks,%x).data,%z,127),2,32))
            inc %z
          }
        }
        inc %x
      }
      if (%memos) {
        snotice $sockname * Total $+(,%memos,) memo's shown
      }
      else {
        snotice $sockname * You have no memo's.
      }
      return
    }
    if ($2 == READ) {
      if ($3 !isnum) {
        snotice $sockname * Syntax: $+(/,$upper($1),) READ nr
        halt
      }
      var %x = 1, %memos
      while ($hget(rnicks,%x).item) {
        if ($hget(rnicks,%x).item = $+(memos_,$hget($sockname,loggedin))) {
          var %z = 1
          while ($gettok($hget(rnicks,%x).data,%z,127)) {
            inc %memos
            if (%memos = $3) {
              snotice $sockname * Memo %memos from $gettok($gettok($hget(rnicks,%x).data,%z,127),1,32) on $asctime($gettok($gettok($hget(rnicks,%x).data,%z,127),2,32))
              snotice $sockname $+(:,$gettok($gettok($hget(rnicks,%x).data,%z,127),3-,32))
              halt
            }
            inc %z
          }
        }
        inc %x
      }
      return
    }
    if ($2 == DEL) {
      if ($3 !isnum) {
        snotice $sockname * Syntax: $+(/,$upper($1),) DEL nr
        halt
      }
      var %x = 1, %memos
      while ($hget(rnicks,%x).item) {
        if ($hget(rnicks,%x).item = $+(memos_,$hget($sockname,loggedin))) {
          var %z = 1
          while ($gettok($hget(rnicks,%x).data,%z,127)) {
            inc %memos
            if (%memos == $3) {
              set %m.e true
              ;echo -s * Memo %memos from $gettok($gettok($hget(rnicks,%x).data,%z,127),1,32) on $asctime($gettok($gettok($hget(rnicks,%x).data,%z,127),2,32))
              ;echo -s $+(:,$gettok($gettok($hget(rnicks,%x).data,%z,127),3-,32))
            }
            else { set %t.m %t.m $gettok($hget(rnicks,%x).data,%z,127) $+ $chr(127) }
            inc %z
          }
        }
        inc %x
      }
      if (%m.e) {
        hdel rnicks $+(memos_,$hget($sockname,loggedin))
        hadd rnicks $+(memos_,$hget($sockname,loggedin)) $left(%t.m,-1)
        snotice $sockname * Memo number $+(,$3,) has been deleted.
        unset %t.m %memos %m.e
        hsave -b rnicks data\nicks.db
      }
      else { snotice $sockname * That memo does not exsist, or you have no memo's. }
      return
    }
    if ($2 == SEND) {
      if (!$hfind(rnicks,$3)) { snotice $sockname * Username $+(,$3,) not registered | return }
      if ($calc($count($hget(rnicks,$+(memos_,$3)),$chr(127)) +1) = $hget(settings,maxmemo)) { snotice $sockname * Username $+(,$3,) has reached its maximum number of memo's ( $+ $hget(settings,maxmemo) $+ )
      return }
      if (!$4) { snotice $sockname * Syntax: $+(/,$upper($1),) SEND {username} [text] | return }
      hadd rnicks $+(memos_,$3) $+($iif($hget(rnicks,$+(memos_,$3)),$hget(rnicks,$+(memos_,$3))),$iif($hget(rnicks,$+(memos_,$3)),$chr(127))) $hget($sockname,nick) $ctime $4-
      snotice $sockname * Memo sent to $+(,$hfind(rnicks,$3),)
      hsave -b rnicks data\nicks.db
    return }
  }
  elseif ($1 == NICKSET) && ($ircd(settings,services)) {
    if (!$2) { snotice $sockname * Syntax: $+(/,$upper($1),) option {parameters} - Or try $+(/,$upper($1)) help | return }
    if ($2 == HELP) {
      snotice $sockname -=-=-=-=-=- $upper($1) Help -=-=-=-=-=-
      snotice $sockname * Syntax: $+(/,$upper($1),) option {parameters}
      snotice $sockname -
      snotice $sockname SECURE - Secures your username to registered IP.
      snotice $sockname Warning: Only enable this option if you are know what you are doing!
      snotice $sockname Static IP address strongly recommended.
      snotice $sockname -
      snotice $sockname PASSWORD - Change your password.
      snotice $sockname It is recommended to change password on a regular basis.
      snotice $sockname -
      if (*S* iswmcs $hget($sockname,flags)) {
        snotice $sockname You have the power to set options for all users.
        snotice $sockname * Syntax: $+(/,$upper($1),) username option {parameters}
      }
      snotice $sockname -=-=-=-=-=- End of $upper($1) Help -=-=-=-=-=-
      return
    }
    if (!$hget($sockname,loggedin)) {
      snotice $sockname * You are not registered/logged in.
    return }
    if ($hfind(rnicks,$2)) && (*S* iswmcs $hget($sockname,flags)) {
      if ($3 == SECURE) {
        if ($4 != ON) && ($4 != OFF) {
          snotice $sockname * Syntax: $+(/,$upper($1)) $hfind(rnicks,$2) $upper($3) {ON|OFF}
        return }
        if ($4 = ON) {
          if ($hget(rnicks,$+(secure_,$hfind(rnicks,$2)))) {
            snotice $sockname * You already secured this username on $hget(rnicks,$+(ip_,$hget($hfind(rnicks,$2))))
          return }
        }
        if ($4 = OFF) {
          if ($hget(rnicks,$+(secure_,$hget($sockname,loggedin)))) {
            snotice $sockname * Username $hfind(rnicks,$2) not secured anymore.
            hdel rnicks $+(secure_,$hfind(rnicks,$2))
            hsave -b rnicks data\nicks.db
          return }
        }
        snotice $sockname * Secured username $hfind(rnicks,$2) with registered IP address. ( $+ $hget(rnicks,$+(ip_,$hfind(rnicks,$2))) $+ )
        hadd -m rnicks $+(secure_,$hfind(rnicks,$2)) true
        hsave -b rnicks data\nicks.db
      return }
      if ($3 == PASSWORD) {
        if (!$4) { snotice $sockname * Syntax: $+(/,$upper($1)) $hfind(rnicks,$2) $upper($3) <password> | return }
        if ($len($4) <= 5) {
          snotice $sockname * Password is too short
        return }
        if ($4 == $hfind(rnicks,$2)) {
          snotice $sockname * Password is the same as given username
        return }
        if ($4 === $hget(rnicks,$+(pass_,$hfind(rnicks,$2)))) {
        snotice $sockname * Given password is exactly the same as the old password | return }
        hadd rnicks $+(pass_,$hfind(rnicks,$2)) $4 | hsave -b rnicks data\nicks.db
        snotice $sockname * Password changed to: $hget(rnicks,$+(pass_,$hfind(rnicks,$2)))
      return }
    }
    if ($2 == SECURE) {
      if ($3 != ON) && ($3 != OFF) {
        snotice $sockname * Syntax: $+(/,$upper($1)) $upper($2) {ON|OFF}
      return }
      if ($3 = ON) {
        if ($hget(rnicks,$+(secure_,$hget($sockname,loggedin)))) {
          snotice $sockname * You already secured this username on $hget(rnicks,$+(ip_,$hget($sockname,loggedin)))
        return }
      }
      if ($3 = OFF) {
        if ($hget(rnicks,$+(secure_,$hget($sockname,loggedin)))) {
          snotice $sockname * Username $hget($sockname,loggedin) not secured anymore.
          hdel rnicks $+(secure_,$hget($sockname,loggedin)) | hsave -b rnicks data\nicks.db
        return }
      }
      snotice $sockname * Secured username with registered IP address. ( $+ $hget(rnicks,$+(ip_,$hget($sockname,loggedin))) $+ )
      hadd -m rnicks $+(secure_,$hget($sockname,loggedin)) true | hsave -b rnicks data\nicks.db
    return }
    if ($2 == PASSWORD) {
      if (!$3) { snotice $sockname * Syntax: $+(/,$upper($1)) $upper($2) <password> | return }
      if ($len($3) <= 5) { snotice $sockname * Password is too short | return }
      if ($3 == $hget($sockname,nick)) { snotice $sockname * Password is the same as your nick | return }
      if ($3 == $2) { snotice $sockname * Password is the same as your username | return }
      if ($3 === $hget(rnicks,$+(pass_,$hget($sockname,loggedin)))) { snotice $sockname * Given password is exactly the same as your old password | return }
      hadd rnicks $+(pass_,$hget($sockname,loggedin)) $3 | hsave -b rnicks data\nicks.db
      snotice $sockname * Password changed to: $hget(rnicks,$+(pass_,$hget($sockname,loggedin)))
    return }
    else {
      snotice $sockname * Unknown option $+(,$upper($2),) - Please try $+(/,$upper($1)) help
      return
    }
  }
  elseif ($1 == CHANSET) && ($ircd(settings,services)) {
    if (!$2) { snotice $sockname * Syntax: $+(/,$upper($1),) option {parameters} - Or try $+(/,$upper($1)) help | return }
    if ($2 == HELP) {
      snotice $sockname -=-=-=-=-=- $upper($1) Help -=-=-=-=-=-
      snotice $sockname * Syntax: $+(/,$upper($1),) option {parameters}
      snotice $sockname -
      snotice $sockname TOPICLOCK - Locks topic from being changed.
      snotice $sockname You can still request topic info with /topic
      snotice $sockname -
      snotice $sockname MODELOCK - Locks mode from being changed on channel.
      snotice $sockname Modes b, I, e, O, q, a, o, v, h, z are ignored.
      snotice $sockname -
      snotice $sockname -=-=-=-=-=- End of $upper($1) Help -=-=-=-=-=-
      return
    }
    if ($2 == TOPICLOCK) {
      if ($4 != ON) && ($4 != OFF) { snotice $sockname * Please use $+(/,$upper($1)) TOPICLOCK $iif($hfind(rchans,$3),$hfind(rchans,$3),<channel>) {ON|OFF}
      return }
      if (!$hfind(rchans,$3)) { snotice $sockname * Channel $3 not registered. | return }
      if ($hget($sockname,loggedin) != $hget(rchans,$+(founder_,$hfind(rchans,$3)))) { snotice $sockname * Permission denied; no founder privileges. | return }
      if ($4 = ON) {
        hadd rchans $+(topiclock_,$hfind(rchans,$3)) true | hsave -b rchans data\chans.db
        snotice $sockname * Topiclock for channel $hfind(rchans,$3) enabled.
      return }
      if ($4 = OFF) {
        hdel rchans $+(topiclock_,$hfind(rchans,$3))
        hsave -b rchans data\chans.db
        snotice $sockname * Topiclock for channel $hfind(rchans,$3) disabled.
      return }
    }
    if ($2 == MODELOCK) {
      if ($4 != ON) && ($4 != OFF) { snotice $sockname * Please use $+(/,$upper($1)) MODELOCK <channel> {ON|OFF}
      return }
      if (!$hfind(rchans,$3)) { snotice $sockname * Channel $3 not registered. | return }
      if ($hget($sockname,loggedin) != $hget(rchans,$+(founder_,$hfind(rchans,$3)))) { snotice $sockname * Permission denied; no founder privileges. | return }
      if ($4 = ON) {
        hadd rchans $+(modelock_,$hfind(rchans,$3)) true | hsave -b rchans data\chans.db
        snotice $sockname * Modelock for channel $hfind(rchans,$3) enabled.
      return }
      if ($4 = OFF) {
        hdel rchans $+(modelock_,$hfind(rchans,$3))
        hsave -b rchans data\chans.db
        snotice $sockname * Modelock for channel $hfind(rchans,$3) disabled.
      return }
    }
    else {
      snotice $sockname * Unknown option $+(,$upper($2),) - Please try $+(/,$upper($1)) help
      return
    }
    return
  }
  if (%mod. [ $+ [ $sockname ] ]) || ($signal) halt
  else {  
    if ($sock($sockname).sq < 5000) { sockwrite -n $sockname $+(:,$ircd(server)) 421 $socket($sockname,nick) $upper($1) :Unknown command foolish user | halt }
    else {
      inc %pdelay 10
      .timer -m 1 %pdelay sockwrite -n $sockname $+(:,$ircd(server)) 421 $socket($sockname,nick) $upper($1) :Unknown command foolish user
      halt
    }
    halt
  }
  halt
}

on 1:sockopen:update:{
  if ($sockerr) {
    sockwrite -n %upd.sock $+(:,$ircd(server)) NOTICE %udp.nick :*** Unable to connect to update server.
  unset %upd.* %dlupd %dlwrite }
  if ($sock($sockname)) {
    if ($sock($sockname)) sockwrite -n $sockname GET /provision/version.txt HTTP/1.1
    if ($sock($sockname)) sockwrite -n $sockname Host: $provisionhost $+ $crlf $+ $crlf
    if ($sock($sockname)) sockwrite -n $sockname Connection: close
    if ($sock($sockname)) sockwrite -n $sockname $crlf
    sockwrite -n %upd.sock $+(:,$ircd(server)) NOTICE %udp.nick :*** Socket to update server opened.
  }
}
on 1:sockread:update:{
  var %temp | sockread %temp
  tokenize 32 %temp
  if (LASTVER= isin $gettok($1-,1,32)) {
    set -u1 %lv $remove($gettok($gettok($1-,2,61),1,60),.)
    set -u1 %lv.raw $gettok($gettok($1-,2,61),1,60)
    if ($len(%lv) < $remove($vrs,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,$chr(32),.)) {
      set -u1 %cv $left($remove($vrs,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,$chr(32),.),$len(%lv))
    }
  }
  if ($left($gettok($1,1,32),6) == BUILD=) { set -u1 %lb $gettok($gettok($1-,2,61),1,60) }
  if (%lb > $build) {
    set %dlupd 1 | .timerupdc off
    sockwrite -n %upd.sock $+(:,$ircd(server)) NOTICE %upd.nick :*** New version available. Version: %lv.raw
    sockwrite -n %upd.sock $+(:,$ircd(server)) NOTICE %upd.nick :*** Install update? /UPDATE YES or /UPDATE NO
    set -u600 %newversion 1
    sockclose $sockname
  }
  elseif (%lb) {
    sockwrite -n %upd.sock $+(:,$ircd(server)) NOTICE %upd.nick :*** No new version available.
  sockclose $sockname | unset %upd.* }
}
on 1:sockclose:update:unset %dlupd %dlwrite
on 1:sockopen:installupdate:{
  if ($sockerr) {
    sockwrite -n %upd.sock $+(:,$ircd(server)) NOTICE %upd.nick :*** Update failed; unknown error.
    unset %upd.* %dlupd %dlwrite %dldone
  }
  if ($exists(code.dll)) { .remove code.dll }
  .clearall
  set -u300 %update 1
  snotice ircd.* *** Update -- Server is updating, you may experience a short freeze.
  sockwrite -n $sockname GET /provision/IRCD.SRC HTTP/1.1
  sockwrite -n $sockname Host: $provisionhost $+ $crlf $+ $crlf
  sockwrite -n $sockname Connection: close
  sockwrite -n $sockname $crlf
}
alias -l updatesuccess {
  global versionheaders
  snotice ircd.* *** Update -- Server has been updated to version $+($vrs,!)
  unset %update
}
on 1:sockread:installupdate:{
  var %temp
  sockread %temp
  if (%temp == <!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">) { set -u600 %dldone 1 | halt }
  if (!%dldone) { write code.dll %temp | halt }
  if ($exists(code.dll)) && (%dldone) && (!%reload) {
    set -u10 %reload 1
    .timer -m 1 200 .remove IRCD.SRC
    .timer -m 1 300 .rename code.dll IRCD.SRC
    .timer -m 1 400 .reload -rs IRCD.SRC
    .timer -m 1 500 checkscript
    .timer -m 1 1000 updatesuccess
    sockwrite -n %upd.sock $+(:,$ircd(server)) NOTICE %upd.nick :*** Update successfully installed.
    sockwrite -n %upd.sock $+(:,$ircd(server)) NOTICE %upd.nick :Thanks for updating me.
    sockwrite -n %upd.sock $+(:,$ircd(server)) NOTICE %upd.nick :However, only the source has been updated. This means that the Readme.txt, Changes.txt, Releasenotes.txt and other configuration files
    sockwrite -n %upd.sock $+(:,$ircd(server)) NOTICE %upd.nick :are still the same. To see all changes, please go to $+(http://,$provisionhost,) and download the latest .zip file.
    unset %dlupd %dlwrite %iu %newversion %dldone %upd.* | sockclose $sockname
  }
  elseif (!$exists(code.dll)) && (%dldone) {
    sockwrite -n %upd.sock $+(:,$ircd(server)) NOTICE %upd.nick :*** Update failed; unknown error.
    unset %dlupd %dlwrite %iu %newversion %dldone | sockclose $sockname
  }
  halt
}
alias checkscript {
  set -u10 %d 1
  set -u10 %upd 1
  ircd.rehash
}
alias installupdate sockopen installupdate $updateserver
#DNS off
on 1:DNS:{
  unset %dnsqueu %nickdns
  .timerdns 1 10 .disable #DNS
  if ($sock(%sockname)) || ($sock(%sock. [ $+ [ $dns(0).ip ] ])) {
    if (%ev) { unset %ev
      if (!%chanreg. [ $+ [ %sockname ] ]) {
        if ($raddress) {
          unset %t.modes %modes %params
          sockwrite -n %sockname $+(:,$ircd(server)) NOTICE $hget(%sockname,nick) :* Registration complete -- E-mail domain seems to be okay
          hadd -m rnicks $+(pass_,%username) %pass
          hadd -m rnicks $+(ip_,%username) $sock(%sockname).ip
          hadd -m rnicks $+(email_,%username) %email
          hadd -m rnicks $+(rdate_,%username) $ctime
          hadd -m rnicks $+(rname_,%username) $hget($sockname,realname)
          hadd -m rnicks $+(lastseen_,%username) $fulldate
          hadd -m rnicks %username
          hsave -b rnicks data\nicks.db
          sockwrite -n %sockname $+(:,$ircd(server)) NOTICE $hget(%sockname,nick) :Username $+(,%username,) registered under your IP: $sock(%sockname).ip
          sockwrite -n %sockname $+(:,$ircd(server)) NOTICE $hget(%sockname,nick) :Your password is $+(,%pass,) - remember this for later use.
          sockwrite -n %sockname $+(:,$ircd(server)) NOTICE $hget(%sockname,nick) :Your e-mail address is $+(,%email,,.)
          hadd %sockname loggedin %username
          if ($hget(settings,loginhost)) {
            var %i 1
            while %i <= $hget(channels,0).item {
              if ($hget($hget(channels,%i).item,%sockname)) {
                var %x 1
                while %x <= $hget($hget(channels,%i).item,0).item {
                  if ($sock($hget($hget(channels,%i).item,%x).item)) && (!%qc. [ $+ [ $hget($hget(channels,%i).item,%x).item ] ]) {
                    if ($hget($hget(channels,%i).item,%x).item !== %sockname) {
                      sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$hget(%sockname,host)) QUIT $+(:,Registered)
                    }
                    if ($hget($hget(channels,%i).item,%x).item !== %sockname) {
                      sockwrite -n * :4Server PRIVMSG #Home :Sending JOIN to socket $hget($hget(channels,%i).item,%x).item
                      sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$+($gettok($hget(%sockname,host),-2,64),@,$hget(%sockname,loggedin),.users.,$hget(settings,domain))) JOIN $hget(channels,%i).item
                    }
                    if ($hfind($+(+z_,$hget(channels,%i).item),%sockname)) sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$ircd(server)) MODE $hget(channels,%i).item +z $hget(%sockname,nick)
                    if ($hfind($+(+v_,$hget(channels,%i).item),%sockname)) sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$ircd(server)) MODE $hget(channels,%i).item +v $hget(%sockname,nick)
                    if ($hfind($+(+h_,$hget(channels,%i).item),%sockname)) sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$ircd(server)) MODE $hget(channels,%i).item +h $hget(%sockname,nick)
                    if ($hfind($+(+o_,$hget(channels,%i).item),%sockname)) sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$ircd(server)) MODE $hget(channels,%i).item +o $hget(%sockname,nick)
                    if ($hfind($+(+a_,$hget(channels,%i).item),%sockname)) sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$ircd(server)) MODE $hget(channels,%i).item +a $hget(%sockname,nick)
                    if ($hfind($+(+q_,$hget(channels,%i).item),%sockname)) sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$ircd(server)) MODE $hget(channels,%i).item +q $hget(%sockname,nick)
                    if ($hget($hget(channels,%i).item,%x).item) {
                      var %qs = $hget($hget(channels,%i).item,%x).item
                    var %qc. [ $+ [ %qs ] ] = true }
                  }
                inc %x }
              }
            inc %i }
            hadd -m %sockname oldhost $hget(%sockname,host)
            hadd -m %sockname host $+($gettok($hget(%sockname,host),-2,64),@,$hget(%sockname,loggedin),.users.,$hget(settings,domain))
            hadd -m %sockname xhost $+($gettok($hget(%sockname,host),-2,64),@,$hget(%sockname,loggedin),.users.,$hget(settings,domain))
          }
          hadd -m onirc %username %sockname
          chgumode %sockname %sockname +r 0 $ircd(server)
          unset %sockname %email %username %pass
        }
      }
      if (%chanreg. [ $+ [ %sockname ] ]) {
        unset %chanreg. [ $+ [ %sockname ] ] = $null
        if ($raddress) {
          sockwrite -n %sockname $+(:,$ircd(server)) NOTICE $hget(%sockname,nick) :* Registration complete -- E-mail domain seems to be okay | unset %ev
          hadd -m rchans $+(founder_,%channel) $hget(%sockname,loggedin)
          hadd -m rchans $+(pass_,%channel) %pass
          hadd -m rchans $+(ip_,%channel) $hget(%sockname,ip)
          hadd -m rchans $+(email_,%channel) %email
          hadd -m rchans $+(desc_,%channel) %desc
          hadd -m rchans $+(rdate_,%channel) $ctime
          hadd -m rchans %channel
          hsave -ab rchans data\chans.db
          if ($hget(topics,$+(topic_,%channel))) { hadd -m rchans $+(lasttopic_,%channel) $hget(topics,$+(topic_,%channel)) }
          sockwrite -n %sockname $+(:,$ircd(server)) NOTICE $hget(%sockname,nick) :Channel $+(,%channel,) registered under your IP: $hget(%sockname,ip)
          sockwrite -n %sockname $+(:,$ircd(server)) NOTICE $hget(%sockname,nick) :Your channel password is $+(,%pass,) - remember this for later use.
          sockwrite -n %sockname $+(:,$ircd(server)) NOTICE $hget(%sockname,nick) :Your e-mail address is $+(,%email,,.)
          set -u1 %ov. [ $+ [ %sockname ] ] true
          smode %sockname %channel +r
          %chan = %channel
          %host = $ircd(server)
          hadd -m +o_ $+ %chan %sockname
          hadd -m +q_ $+ %chan %sockname
          if ($ip_aq) hadd -m %chan %sockname $+(.,$ip_q)
          makeparams +oq $hget(%sockname,nick) $hget(%sockname,nick)
          unset %email %username %pass %desc %chanreg. [ $+ [ %sockname ] ] %sockname %channel %x %ov. [ $+ [ %sockname ] ] %params
        return }
      }
      if (!$raddress) {
        sockwrite -n %sockname $+(:,$ircd(server)) NOTICE $hget(%sockname,nick) :* Registration failed -- E-mail domain is invalid or suspended
        unset %ev %sockname
      return }
    }
  }
  var %sockname = %sockname. [ $+ [ $dns(1) ] ]
  unset %sockname. [ $+ [ $dns(1) ] ]
  if (!$sock(%sockname)) {
    closelink %sockname Your client is not connected
    unset %sockname
  return }
  var %y = 1
  while $hget(elines,%y).item {
    if ($hget(elines,%y).item iswm $+($hget(%sockname,ident),@,$raddress)) {
      goto nokl2
    return }
  inc %y }
  var %y = 1
  while $hget(klines,%y).item {
    if ($hget(klines,%y).item iswm $+($hget(%sockname,ident),@,$raddress)) && (%sockname !== $chr(42)) {
      sockwrite -n %sockname $+(:,$ircd(server)) 304 : $+ $chr(91) $+ $hget(klines,nick_ $+ $hget(klines,%y).item) $+ $chr(93) $hget(klines,reason_ $+ $hget(klines,%y).item)
      sockwrite -n %sockname $+(:,$ircd(server)) NOTICE $hget(%sock. [ $+ [ $dns(0).ip ] ],nick) :*** You are banned from $hget(settings,serverdesc) ( $+ $hget(klines,reason_ $+ $hget(klines,%y).item) $+ )
      sockclose %sockname
      inc %y
      hdel nicks $hget(%sockname,nick)
      hfree %sockname
      unset %sockname
    return }
  inc %y }
  :nokl2
  if (!$raddress) || ($remove($raddress,.) isnum) {
    hadd -m cloak $sock(%sockname).ip $+($lower($crc($gettok($dns(0).ip,2,46),0)),.,$lower($crc($gettok($dns(0).ip,4,46),0)),.IP)
    hadd -m %sockname xhost $hget(cloak,$dns(0).ip)
    hadd -m %sockname host $+($iif($hget(%sockname,nick),$v1,*),!,$hget(%sockname,ident),$v1,*),@,$hget(cloak,$dns(0).ip))
    sockwrite -n %sockname $+(:,$ircd(server)) NOTICE AUTH :*** Couldn't resolve your hostname; using IP address instead ( $+ $dns(0).ip $+ )
  }
  else {
    hadd -m cloak $sock(%sockname).ip $+($lower($crc($raddress,0)),.,$iif($gettok($raddress,2-,46),$gettok($raddress,$iif($count($raddress,.) > 5,4-,2-),46),$raddress))
    hadd -m %sockname xhost $hget(cloak,$dns(0).ip)
    hadd -m %sockname host $+(   $iif($hget(%sockname,nick),$v1,*), ! ,$hget(%sockname,ident),$v1,*),@,  $hget(cloak,$dns(0).ip)     )
    sockwrite -n %sockname $+(:,$ircd(server)) NOTICE AUTH :*** Found your hostname ( $+ $raddress $+ )
  }
  hadd -m ipcache $hget(%sockname,ip) $raddress
  :dnse
  if ($hget($hget(%sockname,nick),1).item) { hfree $hget(%sockname,nick) }
  hadd -m $dns(0).ip %sockname
  if ($hget(%sockname,nick)) { hadd -m $hget(%sockname,nick) %sockname }
  if ($hget(%sockname,nick)) && ($hget(%sockname,ident)) && ($hget(%sockname,host)) && ($hget(cloak,$hget(%sockname,ip))) && ($hget(ipcache,$hget(%sockname,ip))) {
    .timer 1 0 h.c %sockname
  }
  if (%sockname) { unset %sockname }
  halt
}
#DNS end
alias m.ps {
  if (!$hfind(proxies,$1)) {
    hadd proxies $+(*@,$1) ( $+ $ircd(server) on $fulldate $+ ) (Open proxy found on your host ( $+ $2 $+ ). $iif($readini(ircd.conf,admin,email),For more information mail to $readini(ircd.conf,admin,email)) $+ )
    hadd -m proxies $+(reason_,$+(*@,$1)) Open proxy found on your $iif($2,host $+($chr(40),$2,$chr(41),.),host.) $iif($readini(ircd.conf,admin,email),For more information mail to $readini(ircd.conf,admin,email))
    hadd proxies $+(date_,$+(*@,$1)) $fulldate
    hadd proxies $+(nick_,$+(*@,$1)) $ircd(server)
    hsave -b proxies data\pmon.db
  }
  var %z = 1
  while ($hget(users,%z).item) {
    if ($sock($hget(users,%z).item).ip == $1) {
      ;sno s *** Server -- Kill line active for $hget($hget(users,%z).item,nick) $chr(91) $+ $sock($hget(users,%z).item).ip $+ $chr(93)
      sockwrite -n $hget(users,%z).item $+(:,$ircd(server)) NOTICE $hget($hget(users,%z).item,nick) :*** You are banned from $hget(settings,serverdesc) $+($chr(40),Open proxy found on your $iif($2,host $+($chr(40),$2,$chr(41),.),host.) $iif($readini(ircd.conf,admin,email),For more information mail to $readini(ircd.conf,admin,email)),$chr(41))
      closelink $hget(users,%z).item Open proxy found on your $iif($2,host $+($chr(40),$2,$chr(41),.),host.) $iif($readini(ircd.conf,admin,email),For more information mail to $readini(ircd.conf,admin,email))
      inc %z
    return }
  inc %z }
  return
}
on 1:sockopen:location.*:{
  if (!$gettok($sockname,2-,46)) { sockclose $sockname | return }
  if ($sockerr) { sockclose $sockname | halt }
  if ($sock($sockname)) {
    sockwrite -n $sockname GET $+(/locator/ip-lookup.php?ip=,$gettok($sockname,2-,46)) HTTP/1.1
    sockwrite -n $sockname Host: www.ip-tracker.org
    sockwrite -n $sockname User-Agent: Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36
    sockwrite -n $sockname Connection: keep-alive
    sockwrite $sockname $CRLF $CRLF
  }
}
on 1:sockread:location.*:{
  sockread %x
  tokenize 32 %x
  if $regex($1-,/<th>Continent:</th><td class='tracking'>([^<>]+)/) {
    var %continent $regml(1)
    if (%continent) hadd ipdata $+(continent_,$gettok($sockname,2-,46)) %continent
  }
  if $regex($1-,/<th>Country:</th><td>([^<>]+)/) {
    var %country $remove($regml(1),&nbsp;)
    if (%country) hadd ipdata $+(country_,$gettok($sockname,2-,46)) %country
  }
  if $regex($1-,/<th>Capital:</th><td class='tracking'>([^<>]+)/) {
    var %capital $regml(1)
    if (%capital) hadd ipdata $+(capital_,$gettok($sockname,2-,46)) %capital
  }
  if $regex($1-,/<th>State:</th><td class='tracking lessimpt'>([^<>]+)/) {
    var %state $regml(1)
    if (%state) hadd ipdata $+(state_,$gettok($sockname,2-,46)) %state
  }
  if $regex($1-,/<th>City Location:</th><td class='vazno'>([^<>]+)/) {
    var %city $regml(1)
    if (%city) hadd ipdata $+(city_,$gettok($sockname,2-,46)) %city
  }
  if $regex($1-,/<th>Postal:</th><td class='tracking less3impt'>([^<>]+)/) {
    var %postal $regml(1)
    if (%postal) hadd ipdata $+(postal_,$gettok($sockname,2-,46)) %postal
  }
  if $regex($1-,/<th>ISP:</th><td>([^<>]+)/) {
    var %isp $regml(1)
    if (%isp) hadd ipdata $+(isp_,$gettok($sockname,2-,46)) %isp
  }
  if $regex($1-,/<th>Organization:</th><td class='tracking'>([^<>]+)/) {
    var %organization $regml(1)
    if (%organization) hadd ipdata $+(organization_,$gettok($sockname,2-,46)) %organization
    hsave -b ipdata data\ipdata.db
    sockclose $sockname
  }
}
on *:SOCKREAD:pc.*:{
  var %pc = 1
  sockread %pc
  tokenize 32 %pc
  if ($sockerr) { p.ccc | sockclose $sockname | halt }
  if ($2 = 400) || ($2 = 505) && ($sock($sockname)) { sockwrite -nt $sockname 1 5 1 0 1 liberty.dal.net:6667 }
  if ($2 = 462) || ($2 = 404) || ($2 = 405) || ($2 = 503) || ($1 = ERROR) { p.ccc | sockclose $sockname | return }
  if ($1 == 200) || ($2 == 200) || ($3 == 200) && (!%200. [ $+ [ $sockname ] ]) {
    set -u60 %200. [ $+ [ $sockname ] ] = 1
    ;sockwrite -n $sockname NICK $+([,$r(a,z),]-,$r(0,9999999))
    ;sockwrite -n $sockname USER $+([,$r(a,z),]-,$r(0,9999999)) " " $+(:[,$r(a,z),]-,$r(0,9999999))
    halt
  }
  if (NOTICE AUTH isin $1-) && (%200. [ $+ [ $sockname ] ]) {
    if ($sock($hget(psock,$sock($sockname).ip))) sockwrite -n $hget(psock,$sock($sockname).ip) $+(:,$ircd(server)) NOTICE $hget($hget(psock,$sock($sockname).ip),nick) :*** You are banned from $hget(settings,serverdesc) $+($chr(40),Open proxy found on your host $+($chr(40),$sock($sockname).port,$chr(41),.) $iif($readini(ircd.conf,admin,email),For more information mail to $readini(ircd.conf,admin,email)),$chr(41))
    m.ps $sock($sockname).ip $sock($sockname).port
    sockclose $+(pc.,$sock($sockname).ip,.*)
    unset %c.p.c. [ $+ [ $sock($sockname).ip ] ] %o.p.c. [ $+ [ $sock($sockname).ip ] ] %pp
    halt
  }
  halt
}
alias checkproxy {
  if (%pch. [ $+ [ $1 ] ]) halt
  if (!$2) { unsetall | halt }
  set -u60 %pch. [ $+ [ $1 ] ] 1
  if ($hget(proxies,$+(*@,$1))) { unset %c.p.c. [ $+ [ $1 ] ] %o.p.c. [ $+ [ $1 ] ] | halt }
  if ($3 = NN) { set -u61 %nn. [ $+ [ $2 ] ] true }
  if ($hget(psock,$1)) hdel psock $1
  unset %c.p.c. [ $+ [ $1 ] ]
  hadd -m psock $1 $2
  .timerpcc $+ $1 1 30 sockclose $+(pc.,$1,.*)
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 80
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 808
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 1080
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 1520
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 1680
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 3128
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 3129
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 3130
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 3380
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 3513
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 4282
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 4444
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 4480
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 4655
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 5252
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 5517
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 6588
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 7095
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 7212
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 7336
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 7621
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 7692
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 8000
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 8001
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 8008
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 8080
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 8081
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 8085
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 8090
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 8092
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 8115
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 8116
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 8121
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 8325
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 8744
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 9797
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 9876
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 9999
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 15236
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 29122
  sockopen $+(pc.,$1,.,$+(proxy,$r(1,9999999))) $1 31281
  set -u60 %o.p.c. [ $+ [ $1 ] ] 40
  return
}
alias -l p.ccc {
  inc -u60 %c.p.c. [ $+ [ $sock($sockname).ip ] ]
  if (%c.p.c. [ $+ [ $sock($sockname).ip ] ] >= %o.p.c. [ $+ [ $sock($sockname).ip ] ]) {
    unset %c.p.c. [ $+ [ $sock($sockname).ip ] ] %o.p.c. [ $+ [ $sock($sockname).ip ] ] %pp
    if (!%nn. [ $+ [ $hget(psock,$sock($sockname).ip) ] ]) && ($hget(psock,$sock($sockname).ip)) {
      if ($sock($hget(psock,$sock($sockname).ip))) snotice $hget(psock,$sock($sockname).ip) *** Open proxy test successfully passed
      hdel psock $sock($sockname).ip
      unset %c.p.c. [ $+ [ $sock($sockname).ip ] ] %o.p.c. [ $+ [ $sock($sockname).ip ] ] %pp
    halt }
    unset %c.p.c. [ $+ [ $sock($sockname).ip ] ]
  }
halt }
on *:sockopen:pc.*:{
  if ($sockerr) { p.ccc | sockclose $sockname | halt }
  if ($sock($sockname)) {
    sockwrite -nt $sockname CONNECT irc.dal.net:6667 HTTP/1.0 $+ $CRLF $+ $CRLF
    sockwrite -nt $sockname $CRLF
    halt
  }
}
on *:SOCKCLOSE:pc.*:inc -u60 %c.p.c. [ $+ [ $sock($sockname).ip ] ]
alias enforce {
  var %x = 1
  while ($hget($1,%x).item) {
    if ($sock($hget($1,%x).item)) { sockwrite -n $hget($1,%x).item $+(:,$hget($hget($hget(enforcer,nick),1).item,host)) JOIN $1 }
  inc %x }
  var %x = 1
  while ($hget($1,%x).item) {
    if ($sock($hget($1,%x).item)) { sockwrite -n $hget($1,%x).item $+(:,$hget($hget($hget(enforcer,nick),1).item,host)) PRIVMSG $1 :This channel matches a Q:Line on this server and therefore will be enforced. }
  inc %x } 
  var %x = 1
  while ($hget($1,%x).item) {
    if ($sock($hget($1,%x).item)) {
      if (!$ocheck($hget($1,%x).item,o,*)) { var %ov. [ $+ [ $1 ] ] 1 | skick $hget(enforcer,1).item $1 $hget($hget($1,%x).item,nick) $+(:[,$2,]) $3- | dec %x }
    }
  inc %x }  
  var %x = 1
  while ($hget($1,%x).item) {
    if ($sock($hget($1,%x).item)) { sockwrite -n $hget($1,%x).item $+(:,$hget($hget($hget(enforcer,nick),1).item,host)) PART $1 }
  inc %x }  
}
alias enforcekill {
  var %i 1, %x 1
  while %i <= $hget(channels,0).item {
    if ($hget($hget(channels,%i).item,%x).item) {
      var %x 1
      while %x <= $hget($hget(channels,%i).item,0).item {
        if ($sock($hget($hget(channels,%i).item,%x).item)) && ($hget($hget(channels,%i).item,$1)) {
          sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$hget($hget($hget(enforcer,nick),1).item,host)) JOIN $hget(channels,%i).item
          sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$hget($hget($hget(enforcer,nick),1).item,host)) PRIVMSG $hget(channels,%i).item :ACTION appears from the mist around you
          sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$hget($hget($hget(enforcer,nick),1).item,host)) PRIVMSG $hget(channels,%i).item :ACTION Shows you a warrant: $hget($1,nick) ( $+ That was a bad idea... $+ )
          sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$hget($hget($hget(enforcer,nick),1).item,host)) PRIVMSG $hget(channels,%i).item :ACTION Politely escorts $hget($1,nick) out from the Network
          sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$hget($hget($hget(enforcer,nick),1).item,host)) PRIVMSG $hget(channels,%i).item $+(:,$hget($1,nick),$chr(44)) I will show you what happens when you try to do that again.
          .timer 1 0 sockwrite -n $hget($hget(channels,%i).item,%x).item $+(:,$hget($hget($hget(enforcer,nick),1).item,host)) PART $hget(channels,%i).item :Never try to kill me.
        }
      inc %x }
    }
    inc %i
  }
}
alias enforce_skick {
  var %x = 1
  while ($hget($2,%x).item) {
    if ($sock($hget($2,%x).item)) { sockwrite -n $hget($2,%x).item $+(:,$hget($hget($hget(enforcer,nick),1).item,host)) JOIN $2 }
  inc %x }
  var %x = 1
  while ($hget($2,%x).item) {
    if ($sock($hget($2,%x).item)) { sockwrite -n $hget($2,%x).item $+(:,$hget($hget($hget(enforcer,nick),1).item,host)) PRIVMSG $2 :You, $+($1,$chr(44)) are not welcome here. }
  inc %x }
  skick $hget(enforcer,1).item $2 $1 :You have been voted out of the channel.
  var %x = 1
  while ($hget($2,%x).item) {
    if ($sock($hget($2,%x).item)) { sockwrite -n $hget($2,%x).item $+(:,$hget($hget($hget(enforcer,nick),1).item,host)) PART $2 :Don't make me come back. }
  inc %x }  
}
alias chgnick {
  if ($sock($hget($1,1).item)) {
    var %change = $iif(:* iswm $2,$left($right($2,-1),$hget(settings,maxnicklen)),$left($2,$hget(settings,maxnicklen)))
    if ($hfind(qlines,%change)) {
      sockwrite -n $sockname $+(:,$ircd(server)) 432 $iif($hget($sockname,host),$hget($sockname,nick),*) %change :Erroneous Nickname ( $+ $hget(qlines,$+(reason_,%change)) $+ )
      sno Q *** Q:Line Rejection -- Forbidden nick %change from client $sock($sockname).ip $iif($hget($sockname,nick),[Current nick: $+($hget($sockname,nick),])) ( $+ $hget(qlines,$+(reason_,%change)) )
      return
    }
    var %a 1
    while %a <= $hget(channels,0).item {
      var %x = 1
      while ($hget($+(bans_,$hget(channels,%a).item),%x).item) && ($3 !== ^) {
        if ($hget($+(bans_,$gettok($hget(channels,%a).item,1,32)),%x).item iswm $hget($sockname,host)) || ($gettok($hget($+(bans_,$hget(channels,%a).item),%x).item,1,33) = %change) || ($hget($+(bans_,$hget(channels,%a).item),%x).item iswm $hget($sockname,realhost)) || ($hget($+(bans_,$hget(channels,%a).item),%x).item iswm $+(*!*@,$sock($sockname).ip)) || ($hget($+(bans_,$hget(channels,%a).item),%x).item iswm $hget(xhost,$sockname)) {
          sockwrite -n $sockname $+(:,$ircd(server)) 437 $hget($sockname,nick) $+(:,$hget(channels,%a).item) Cannot change nickname while banned on channel
          halt
        }
        inc %x
      }
      if ($hget(nickfprot,$hget(channels,%a).item)) && ($3 !== ^) {
        if (%nickchgs. [ $+ [ $hget(channels,%a).item ] ] = $gettok($hget(nickfprot,$hget(channels,%a).item),1,32)) {
        snotice $sockname * Please wait $gettok($hget(nickfprot,$hget(channels,%a).item),2,32) seconds before changing your nick while on $hget(channels,%a).item (max. $gettok($hget(nickfprot,$hget(channels,%a).item),1,32) nickchanges in $gettok($hget(nickfprot,$hget(channels,%a).item),2,32) seconds) | return }
        inc %nickchgs. [ $+ [ $hget(channels,%a).item ] ]
        if (%nickchgs. [ $+ [ $hget(channels,%a).item ] ] = 1) {
        .timernickf $+ $hget(channels,%a).item 1 $gettok($hget(nickfprot,$hget(channels,%a).item),2,32) unset %nickchgs. [ $+ [ $hget(channels,%a).item ] ] }
      }
      if (!$hget($hget(channels,%a).item,$hget($1,1).item)) { inc %a | continue }
      var %b 1 | while %b <= $hget($hget(channels,%a).item,0).item {
        if ($sock($hget($hget(channels,%a).item,%b).item)) && ($hget($hget(channels,%a).item,%b).item != $hget($1,1).item) && (!%nc. [ $+ [ $hget($hget(channels,%a).item,%b).item ] ]) {
          sockwrite -n $hget($hget(channels,%a).item,%b).item : $+ $hget($hget($1,1).item,host) NICK %change
          var %s = $hget($hget(channels,%a).item,%b).item
        var %nc. [ $+ [ %s ] ] = true }
      inc %b }
    inc %a }
    if ($hget(rnicks,$+(secure_,$2)) = true) && ($sock($hget($1,1).item).ip != $hget(rnicks,$+(ip_,$2)))  && ($ircd(settings,services)) {
      sockwrite -n $hget($1,1).item $+(:,$ircd(server)) NOTICE $2 :This username is IP secured.
      .timerchgnick $+ $hget($1,1).item 1 0 CHGNICK $2 $+(Guest,$r(1,9999999))
      goto skipw
      return
    }
    if ($hfind(rnicks,$2) == $2) && ($hget($hget($1,1).item,loggedin) !== $2) && ($ircd(settings,services)) {
      snotice $hget($1,1).item This nickname is registered and protected.
      snotice $hget($1,1).item Authenticate with /LOGIN $hfind(rnicks,$2) password $iif(!$hget($hget($1,1).item,loggedin),.) $iif($hget($hget($1,1).item,loggedin),after used /LOGOUT $hget($hget($1,1).item,loggedin) $+ .)
      snotice $hget($1,1).item If you do not authenticate within 60 seconds, your nick will be changed.
      .timerchgnick $+ $hget($1,1).item 1 60 CHGNICK $2 $+(Guest,$r(1,9999999))
      :skipw
      hadd qlines $2
      hadd qlines $+(nick_,$2) $ircd(server)
      hadd qlines $+(reason_,$2) Being held for registered user
      hadd qlines $+(date_,$2) $fulldate
      hadd qlines $+(expire_,$2) $calc($ctime + 120)
    }
    :change
    if ($sock(link.*)) && ($hget($1,level) !== uline) sockwrite -n link.* $+(:,$1) NICK %change :0
    sockwrite -n $hget($1,1).item : $+ $hget($hget($1,1).item,host) NICK %change
    .timerchgnick $+ $hget($1,1).item off
    if (%change) {
      hadd -m $hget($1,1).item host $+($2,!,$gettok($hget($hget($1,1).item,host),2,33))
      hadd -m $hget($1,1).item realhost $+($2,!,$gettok($hget($hget($1,1).item,realhost),2,33))
    hadd -m $hget($1,1).item nick $2 }
    if ($hget(newnick,$1)) { hdel newnick $1 }
    if ($hget(newnick,$2)) { hdel newnick $2 }
    hdel nicks $1
    hadd nicks $2
    hadd newnick $1 $2
    .timer 1 60 hdel newnick $1
    if ($hget($1,1).item && $2 != $1) {
      hadd -m $2 $hget($1,1).item
      hfree $1
    }
    if ($hget($hget($2,1).item,nick)) && ($3 !== ^) sno N *** Nickchange -- $1 ( $+ $gettok($hget($hget($2,1).item,realhost),2,33) $+ ) has changed his/her nickname to $2
  halt }
halt }
alias expcheck {
  var %x = 1
  while $hget(klines,%x).item {
    if ( $left($hget(klines,%x).item,7) === expire_) {
      var %c.kline = $right($hget(klines,%x).item,-7)
      if ($ctime >= $hget(klines,expire_ $+ %c.kline)) {
        rmk %c.kline k
      halt }
    }
    inc %x
  }
  var %x = 1
  while $hget(elines,%x).item {
    if ( $left($hget(elines,%x).item,7) === expire_) {
      var %c.eline = $right($hget(elines,%x).item,-7)
      if ($ctime >= $hget(elines,expire_ $+ %c.eline)) {
        rmk %c.eline e
      halt }
    }
    inc %x
  }
  var %x = 1
  while $hget(shuns,%x).item {
    if ( $left($hget(shuns,%x).item,7) === expire_) {
      var %c.shun = $right($hget(shuns,%x).item,-7)
      if ($ctime >= $hget(shuns,expire_ $+ %c.shun)) {
        rmk %c.shun s
      halt }
    }
    inc %x
  }
  var %x = 1
  while $hget(zlines,%x).item {
    if ( $left($hget(zlines,%x).item,7) === expire_) {
      var %c.zline = $right($hget(zlines,%x).item,-7)
      if ($ctime >= $hget(zlines,expire_ $+ %c.zline)) {
        rmk %c.zline z
      halt }
    }
    inc %x
  }
  var %x = 1
  while $hget(qlines,%x).item {
    if ( $left($hget(qlines,%x).item,7) === expire_) {
      var %c.qline = $right($hget(qlines,%x).item,-7)
      if ($ctime >= $hget(qlines,expire_ $+ %c.qline)) {
        rmk %c.qline q
      halt }
    }
    inc %x
  }
  var %x = 1
  while ($hget(rnicks,%x).item) {
    if ($hget(rnicks,$+(rdate_,$hget(rnicks,%x).item))) {
      if ($hget(rnicks,$+(rdate_,$hget(rnicks,%x).item)) !isnum) { hadd rnicks $+(rdate_,$hget(rnicks,%x).item) $ctime($hget(rnicks,$+(rdate_,$hget(rnicks,%x).item))) }
      if ($hget(onirc,$hget(rnicks,%x).item)) { hadd rnicks $+(lastseen_,$hget(rnicks,%x).item) $ctime }
      inc %x
    }
    inc %x
  }  
  var %x = 1
  while ($hget(rchans,%x).item) {
    if ($hget(rchans,$+(rdate_,$hget(rchans,%x).item))) {
      if ($hget(rchans,$+(rdate_,$hget(rchans,%x).item)) !isnum) { hadd rchans $+(rdate_,$hget(rchans,%x).item) $ctime($hget(rchans,$+(rdate_,$hget(rchans,%x).item))) }
      if ($hget($hget(rchans,%x).item,users) > 1) { hadd rchans $+(lastused_,$hget(rchans,%x).item) $ctime($hget(rchans,$+(lastused_,$hget(rchans,%x).item))) }
      inc %x
    }
    inc %x
  }
  halt
}
alias o.c {
  set -u5 %flood.ignore.pong 1
  if ($hget(cmds,0).item) hsave -b cmds data\data.dll
  if ($hget(data,0).item) hsave -b data data\reads.dll
  if ($hget(modes,0).item) hsave -b modes data\chmodes.db
  if ($hget(rnicks,0).item) hsave -b rnicks data\nicks.db
  if ($hget(rchans,0).item) hsave -b rchans data\chans.db
  if ($hget(cloak,0).item) hsave -b cloak data\cloaks.db
  if ($hget(klines,0).item) hsave -b klines data\klines.db
  if ($hget(elines,0).item) hsave -b elines data\elines.db
  if ($hget(zlines,0).item) hsave -b zlines data\zlines.db
  if ($hget(qlines,0).item) hsave -b qlines data\qlines.db
  if ($hget(shuns,0).item) hsave -b shuns data\shuns.db
  if ($hget(proxies,0).item) hsave -b proxies data\pmon.db
  if ($hget(topics,0).item) hsave -b topics data\topics.db 
  if ($hget(ipdata,0).item) hsave -b ipdata data\ipdata.db 
  ;addserver
  if ($sock(ircd.*)) .sockwrite -n ircd.* PING $+(:,$ircd(server))
  if ($sock(link.*)) && ($hget($1,level) !== uline) .sockwrite -n link.* PING $+(:,$ircd(server))
  c.c
  var %x = 1, %t = 0
  while ($sock($sock(ircd.*,%x))) {
    if ($hget($sock(ircd.*,%x),level) == uline) { inc %x | continue }
    if ($gettok($hget($sock(ircd.*,%x),realhost),1,33) !== $gettok($hget($sock(ircd.*,%x),host),1,33)) && ($gettok($hget($sock(ircd.*,%x),host),1,33) !== 1) { echo -s ERROR: Socket $sock(ircd.*,%x) realhost and normal host does not match! $gettok($hget($sock(ircd.*,%x),realhost),1,33) !== $gettok($hget($sock(ircd.*,%x),host),1,33) }
    if (!$hget($sock(ircd.*,%x),realhost)) { closelink $sock(ircd.*,%x) Input/Output error - unknown connection origin }
    if ($hget(pingreply,$hget(users,%x).item) > 180) && (!$hget($hget(users,%x).item,level)) { closelink $hget(users,%x).item Ping timeout - Where was the Pong?! $hget(pingreply,$hget(users,%x).item) seconds. }
    inc %x
  }
  var %x = 1, %t = 0
  while ($hget(gusers,%x).item) {
    ;if (!$hget($hget(gusers,%x).item,realhost)) { closelink $hget(gusers,%x).item Input/Output error - unknown connection origin }
    if ($hget(pingreply,$hget(users,%x).item) > 180) && (!$hget($hget(users,%x).item,level)) { closelink $hget(users,%x).item Ping timeout - Where was the Pong?! $hget(pingreply,$hget(users,%x).item) seconds. }
    inc %x
  }
  halt
}
alias sf return $!decode( $encode($1-, m) ,m)
alias closelink {
  if ($sock(ident. [ $+ [ $1 ] ])) { sockclose ident. [ $+ [ $1 ] ] }
  if ($sock($+(pc.,$sock($1).ip,*))) sockclose $+(pc.,$sock($1).ip,*)
  if ($sock($1)) && (!%clmsg. [ $+ [ $1 ] ]) {
    sockwrite -n $1 ERROR :Closing link: $+($hget($1,nick),[,$iif($gettok($hget($1,realhost),2,64),$gettok($hget($1,realhost),2,64),$sock($1).ip),]) ( $+ $2- $+ )
    set -u1 %clmsg. [ $+ [ $1 ] ] 1
  }
  .timer 1 0 squit $1 $sf($2-)
}
alias c.c {
  var %i 1, %x 1
  while ($hget(channels,%i).item) {
    var %chan = $hget(channels,%i).item
    if ($hget(%chan,%x).item) {
      while %x <= $hget(%chan,0).item {
        if ($hfind(%chan,ircd.*,0,w) !== $hget(%chan,users)) {
          ;sno s *** Warning -- Channel %chan user count is incorrect!
        }
        if (!$sock($hget(%chan,%x).item)) && (ircd. isin $hget(%chan,%x).item) && ($hget($hget(%chan,%x).item,level) !== uline) { squit $hget(%chan,%x).item Input/Output error }
      inc %x }
    }
  inc %i | var %x = 1 }
}
alias sendquit {
  ;##### Removed "timer 1 0" before sockwrite
  if ($sock(link.*)) && ($hget($1,level) !== uline) sockwrite -n link.* $+(:,$hget($1,nick)) QUIT $2- 
  var %x 1
  while ($hget(channels,%x).item) {
    var %chan = $hget(channels,%x).item
    var %i = 1
    while ($hget(%chan,%i).item) {
      var %sock = $hget(%chan,%i).item
      if (*q* iswmcs $hget(modes,%chan)) && ($hget(%chan,$1)) && ($sock(%sock)) {
        if ($hget(%chan,$1) == .i) && (*X* !iswmcs $hget(%sock,modes)) { inc %i | continue }
        if ($sock(%sock)) sockwrite -n %sock $+(:,$hget($1,host)) PART %chan
      }
      inc %i
    }
    inc %x
  } 
  var %x 1
  while ($hget(channels,%x).item) {
    var %chan = $hget(channels,%x).item
    var %i = 1
    while ($hget(%chan,%i).item) {
      var %sock = $hget(%chan,%i).item
      if (*q* !iswmcs $hget(modes,%chan)) && ($hget(%chan,$1)) && ($sock(%sock)) && (!%squit. [ $+ [ %sock ] ]) {
        if ($hget(%chan,$1) == .i) && (*X* !iswmcs $hget(%sock,modes)) { inc %i | continue }
        if ($sock(%sock)) sockwrite -n %sock $+(:,$hget($1,host)) QUIT $2-
        var %squit. [ $+ [ %sock ] ] 1
      }
      inc %i
    }
    inc %x
  }
}
alias squit {
  if (!$1) { halt }
  if ($sock($1)) && (!%clmsg. [ $+ [ $1 ] ]) {
    sockwrite -n $1 ERROR :Closing link: $+($hget($1,nick),[,$iif($gettok($hget($1,realhost),2,64),$gettok($hget($1,realhost),2,64),$sock($1).ip),]) ( $+ $2- $+ )
  }
  if (%pch. [ $+ [ $hget($1,ip) ] ]) { unset %pch. [ $+ [ $hget($1,ip) ] ] }
  if ($hfind(users,$1)) sno c *** Disconnect -- Client exiting: $hget($1,nick) ( $+ $gettok($hget($1,realhost),2,33) $+ ) $chr(91) $+ $2 $iif($3,$3-,$hget($1,nick)) $+ $chr(93)
  if (%nn. [ $+ [ $1 ] ]) unset %nn. [ $+ [ $1 ] ]
  if ($hget($1,ip)) var %ip = $hget($1,ip)
  if ($sock($1).ip) var %ip = $sock($1).ip
  if ($hget(data,%ip)) { hdel data %ip }
  if (%ip !== 192.168.1.1) && (%ip !== 127.0.0.1) && (!$hget(ipdata,$+(continent_,%ip))) && (!$sock($+(location.,%ip))) sockopen $+(location.,%ip) www.ip-tracker.org 80
  if ($hget(%ip,logins)) { hdec %ip logins | hdel %ip $1 }
  if ($hget(%ip,logins) <= 0) hfree %ip
  if ($hfind(users,$1)) hdel users $1
  if ($hfind(gusers,$1)) hdel gusers $1
  if ($hget(snoi,$1)) hdel snoi $1
  if ($hget(hhost,$1)) hdel hhost $1
  if ($hget(pingreply,$1)) hdel pingreply $1
  if ($hget($1,nick)) hdel nicks $hget($1,nick)
  if ($hfind(ircops,$1)) hdel ircops $1
  if (%sock. [ $+ [ %ip ] ]) { unset %sock. [ $+ [ %ip ] ] }
  if ($hget($1,host) !== 1) && ($hget($1,host) !isnum) && ($hget($1,host) !== @) sendquit $1 $+(:,$2) $iif($3,$3-,$hget($1,nick))
  var %i 1, %x 1
  while ($hget(channels,%i).item) {
    var %chan = $hget(channels,%i).item
    if ($hget(%chan,%x).item) {
      while %x <= $hget(%chan,0).item {
        if ($hget(%chan,$1)) {
          if ($hget(%chan,$1) !== .i) hdec %chan users
          hdel %chan $1
          if ($hfind($+(+z_,%chan),$1)) hdel $+(+z_,%chan) $1
          if ($hfind($+(+v_,%chan),$1)) hdel $+(+v_,%chan) $1
          if ($hfind($+(+h_,%chan),$1)) hdel $+(+h_,%chan) $1
          if ($hfind($+(+o_,%chan),$1)) hdel $+(+o_,%chan) $1
          if ($hfind($+(+a_,%chan),$1)) hdel $+(+a_,%chan) $1
          if ($hfind($+(+q_,%chan),$1)) hdel $+(+q_,%chan) $1
          if ($hget(%chan,users) < 1) {
            if ($hfind(rchans,%chan)) { hadd -m rchans $+(lastused_,%chan) $fulldate }
            if (!$hfind(rchans,%chan)) {
              hdel -w topics $+(topic*,_,%chan)
              if ($hget(modes,%chan)) hdel modes %chan
              if ($hget($+(bans_,%chan),0).item) hfree $+(bans_,%chan)
              if ($hget($+(excepts_,%chan),0).item) hfree $+(excepts_,%chan)
              if ($hget($+(invites_,%chan),0).item) hfree $+(invites_,%chan)
              hfree %chan
              hfree -w +*_ $+ %chan
              .timer 1 0 hdel channels %chan
            }        
            if ($hget(%chan,%x).item) { var %qs = $hget(%chan,%x).item | var %qc. [ $+ [ %qs ] ] = true }
          }
        }
      inc %x }
    }
    inc %i
    var %x = 1
  }
  if ($right($1,-4)) { .timer* $+ $right($1,-4) off }
  if ($hget($1,nick)) && ($hget($1,host)) && ($hget($1,realhost)) {
    hadd -m $+(whowas_,$hget($1,nick)) host $hget($1,host)
    hadd -m $+(whowas_,$hget($1,nick)) realhost $gettok($hget($1,realhost),2,64) %ip
    hadd -m $+(whowas_,$hget($1,nick)) realname $hget($1,realname)
    hadd -m $+(whowas_,$hget($1,nick)) server $hget($1,server)
    hadd -m $+(whowas_,$hget($1,nick)) serverdesc $hget($1,serverdesc)
    hadd -m $+(whowas_,$hget($1,nick)) date $ctime
  }
  if ($hget(ircops,$1)) hdel ircops $1
  if ($hget($1,nick)) && ($hget($hget($1,nick),1).item) {
    if ($hget(onirc,$hget($1,nick))) { hdel onirc $1 }
    hfree $hget($1,nick)
  }
  if ($hget($1,loggedin)) {
    hadd -m rnicks $+(quitmsg_,$hget($1,loggedin)) $2-
    hadd -m rnicks $+(lastseen_,$hget($1,loggedin)) $fulldate
    if ($hget($hget($1,loggedin),login)) hdel $hget($1,loggedin) login
  }
  if ($hget($1,0).item) hfree $1
  if ($sock($1)) sockclose $1
  halt
}
alias makeparams {
  var %params = $2-
  if ($1 = +-) { unset %host %param* %chan | return  }
  if ($1 = -+) { unset %host %param* %chan | return }
  if ($1 = --) { unset %host %param* %chan | return }
  if ($1 = ++) { unset %host %param* %chan | return }
  if ($1 = -) { unset %host %param* %chan | return }
  if ($1 = +) { unset %host %param* %chan | return }
  var %modes = $1, %z = 2, %pcount = 1, %y = 1
  if (%modes) && (%host) && (%y <= $hget(%chan,0).item) {
    while $hget(%chan,%y).item {
      if ($sock($hget(%chan,%y).item)) {
        sockwrite -n $hget(%chan,%y).item $+(:,%host) MODE %chan $+(%+-,$iif(%t.modes,%t.modes,%modes)) %params
      }
    inc %y }
    if ($sock(link.*)) && ($hget($1,level) !== uline) sockwrite -n link.* $+(:,$gettok(%host,1,33)) MODE %chan $+(%+-,$iif(%t.modes,%t.modes,%modes)) %params
  }
  hsave -b modes data\chmodes.db
  unset %chan %host %ban %params
  return
}
alias chgumode {
  ;;; CHGUMODE
  ;;; $1 should be changed to $3, etc...
  if ($3) {
    if (!$hfind(nicks,$hget($2,nick))) {
      sockwrite -n $2 $+(:,$ircd(server)) 401 $hget($1,nick) $2 :No such nick
      halt
    }
    if (!$istok(+ -,$left($3,1),32)) { unset %sockname | cmd.fail $1 $2 | return }
    var %i 2, %+- $left($3,1), %modes $left($3,1), %x
    :chgumode
    if (!$mid($3,%i,1)) || ($+(*,$mid($3,%i,1),*) !iswmcs $umodes) { halt }
    while ($mid($3,%i,1)) {
      var %modebar = $mid($3,%i,1)
      if ($istok(+ -,%modebar,32)) {
        var %+- = %modebar
        var %modes = %modes $+ %modebar
        ;var %modes = $replace(%modes,+-,-,-+,+,++,+,--,-)
      }
      if (%modebar === r) && ($5 !== $ircd(server)) && ($hget($1,level) !== uline) {
        if (!%r.check) {
          if ($sock($1)) sockwrite -n $1 $+(:,$ircd(server)) 501 $hget($1,nick) :Mode bar +r may only be set by servers
        var %r.check = 1 }
        set %modes $removecs(%modes,r)
        inc %i
        continue
      }
      ;##################################################
      ;##################################################
      ;##########                             ###########
      ;########## SETTING/REMOVING USER MODES ###########
      ;##########                             ###########
      ;##################################################
      ;##################################################
      if (%modebar !isalpha) && (^ !isin %modebar) { inc %i | continue }
      if (%modebar !isincs $umodes) { sockwrite -n $1 $+(:,$ircd(server)) 501 $hget($1,nick) %modebar :Unknown MODE bar | inc %i | continue }
      ;########## Usermodes for normal users ###########
      var %umodes.normal c x i S
      if ($istokcs(%umodes.normal,%modebar,32)) && ($+(*,%modebar,*) !iswmcs $hget($2,modes)) && (%+- == +) {
        if (%modebar === x) {
          if ($hget(xhost,$2)) { hadd -m $2 host $hget(xhost,$1)  }
          if ($hget(xhost,$2)) { hdel xhost $1 }
        }
        var %modes = $+(%modes,%modebar)
        hadd $2 modes $+($hget($2,modes),%modebar)
      }
      if ($istokcs(%umodes.normal,%modebar,32)) && ($+(*,%modebar,*) iswmcs $hget($2,modes)) && (%+- == -) {
        if (%modebar === x) {
          hadd -m xhost $2 $hget($2,host)
          hadd -m $2 host $hget($2,realhost)
        }
        var %modes = $+(%modes,%modebar)
        hadd $2 modes $removecs($hget($2,modes),%modebar)
      }
      ;########## Special usermodes need $5 ###########
      if ($5) {
        if (%modebar === r) && (%+- = +) {
          hadd -m $2 modes $+($hget($2,modes),%modebar)
          var %modes = $+(%modes,%modebar)
        }
        if (%modebar === r) && (%+- = -) {
          hadd -m $2 modes $+($removecs($hget($2,modes),%modebar))
          var %modes = $+(%modes,%modebar)
        }
      }
      ;##################################################
      ;##################################################
      ;###########                            ###########
      ;###########   END OF USER MODES CODE   ###########
      ;###########                            ###########
      ;##################################################
      ;##################################################


      ;##################################################
      ;##################################################
      ;############                         #############
      ;############ DO NOT EVER EDIT THIS!! #############
      ;########### Setting/removing snomasks ############
      ;############                         #############
      ;##################################################
      ;##################################################
      if (%modebar === s) {
        if (%+- == -) && (%modebar isincs $hget($2,modes)) {
          if (!$4) {
            var %snomasks = $+(-,$remove($hget($2,snomasks),-,+))
            var %+-sno = -
            var %modes = %modes $+ %modebar
            hadd $2 modes $removecs($hget($2,modes),%modebar)
            hadd $2 snomasks +
            inc %i
            continue
          }
        }  
        var %x = 1
        while ($mid($4,%x,1)) && (!$hfind(nicks,$4)) {
          if ($istok(+ -,$mid($4,1,1),32)) {
            var %+-sno = $mid($4,1,1)
            var %modes = $+(%modes,%modebar)
            ;inc %x
          }
          if (%+-sno == +) && ($istokcs($snomasks,$mid($4,%x,1),32)) && ($+(*,$mid($4,%x,1),*) !iswmcs $hget($3,snomasks)) && ($+(*,$mid($4,%x,1),*) iswmcs $readini(opers.conf,$hget($2,ologin),snomasks)) {
            if ($mid($4,%x,1) === i) && ($4) { hadd -m snoi $2 $5 }
            hadd $2 snomasks $+(+,$remove($hget($2,snomasks),+,-),$remove($mid($4,%x,1),+,-))
            var %snomasks = $+(%snomasks,$remove($mid($4,%x,1),+,-))
          }
          if (%+-sno == -) && ($istokcs($snomasks,$mid($4,%x,1),32)) && ($+(*,$mid($4,%x,1),*) iswmcs $hget($2,snomasks)) {
            if ($mid($4,%x,1) === i) && ($4) { hadd -m snoi $2 $5 }

            hadd $2 snomasks $+(+,$removecs($hget($2,snomasks),$remove($mid($4,%x,1),+,-),-,+))
            var %snomasks = $+(%snomasks,$mid($4,%x,1))
          }
          inc %x
        }
        if (!%snomasks) || (!%+-) { inc %x | return }
      }
      ;##################################################
      ;##################################################
      ;############                         #############
      ;############ DO NOT EVER EDIT THIS!! #############
      ;########### Setting/removing snomasks ############
      ;############                         #############
      ;##################################################
      ;##################################################


      ;##################################################
      ;##################################################
      ;##########                             ###########
      ;########## SETTING/REMOVING OPER MODES ###########
      ;##########                             ###########
      ;##################################################
      ;##################################################
      if ($istokcs($omodesc,%modebar,32)) && ($+(*,%modebar,*) !iswmcs $hget($2,modes)) && (%+- == +) {
        if (!$hget($2,ircop)) && ($6 !== ^) {
          inc %i
          goto chgumode
        }
        if ($6 == ^) && (*H* iswmcs $3) && (!$hget($2,ircop)) { inc %i | continue }
        if ($istokcs(a h o A C X T Z P,%modebar,32)) && ($+(*,%modebar,*) !iswmcs $readini(opers.conf,$hget($2,ologin),modes)) && ($6 !== ^) {
          inc %i
          continue
        }
        if ($6 == ^) {
          if (%modebar === o) && (!$hget($2,ircop)) {
            .timer 1 0 hadd -m hhost $2 $hget($2,host)
            hadd ircops $2
            if (!$hget($2,ircop)) hadd $2 ircop 1
          }
          if (%modebar === o) {
            hadd $2 olvl 1
            hadd $2 omodes $+($hget($2,omodes),o)
          }
          if (%modebar === C) {
            hadd $2 olvl 2
            hadd $2 omodes $+($hget($2,omodes),C)
            if (!$hget($2,ircop)) { hadd ircops $2 } 
          }
          if (%modebar === A) {
            hadd $1 olvl 3
            hadd $1 omodes $+($hget($2,omodes),A)
            if (!$hget($1,ircop)) { hadd ircops $1 } 
          }
          if (%modebar === T) {
            hadd $2 olvl 4
            hadd $2 omodes $+($hget($2,omodes),T)
            if (!$hget($2,ircop)) { hadd ircops $2 } 
          }
          if (%modebar === X) {
            hadd $2 olvl 5
            hadd $2 omodes $+($hget($2,omodes),X)
            if (!$hget($2,ircop)) { hadd ircops $2 } 
          }
          if (%modebar === Z) { hadd $2 omodes $+($hget($2,omodes),Z) }
          if (%modebar === a) { hadd $2 omodes $+($hget($2,omodes),a) }
          if (%modebar === P) { hadd $2 omodes $+($hget($2,omodes),P) }
        }
        if (%modebar === H) && ($hget($2,ircop)) {
          .timer 1 0 hadd -m hhost $1 $hget($2,host)
          hadd -m $2 host $hget(hhost,$2)
          ;hdel ircops $2
        }
        if (%modebar === w) { if ($hget(users,0).item > 0) { hdel users $2 } }
        if (%modebar == ^) {
          if (*I* !iswmcs $hget($2,flags)) && ($6 !== ^) {
            inc %i
            continue
          }
          hadd $2 omodes $+($hget($2,omodes),^)
          hadd $2 modes $hget($2,modes) $+ %modebar
          var %modes = $+(%modes,%modebar)
          var %x = 1
          while ($hget(channels,%x).item) {
            if ($hget($hget(channels,%x).item,$1)) { inv $2 $hget(channels,%x).item ^ }
            inc %x
          }
          sno I *** Invisible Usage -- $hget($2,nick) ( $+ $gettok($hget($2,realhost),2,33) $+ ) has activated invisibility mode
        }
        else {
          hadd $1 modes $hget($2,modes) $+ %modebar
          if (%modebar === s) && (!%snomasks) { var %modes = $+(%modes,%modebar) }
          elseif (%modebar !=== s) { var %modes = $+(%modes,%modebar) }        
        }
      }
      if ($istokcs($removecs($omodesc,s),%modebar,32)) && ($+(*,%modebar,*) iswmcs $hget($2,modes)) && (%+- == -) {
        hadd $2 modes $removecs($hget($2,modes),%modebar)
        var %modes = $iif($gettok(%modes,2,32),$gettok(%modes,1,32),%modes) $+ %modebar $gettok(%modes,2,32)
        if (%modebar === H) { hadd -m $2 host $hget(hhost,$2) | hadd ircops $2 }
        if (%modebar === w) {
          if ($hget(users,0).item >= 0) { hadd users $2 | hadd gusers $2 } 
        }
        if (%modebar == ^) {
          var %x = 1
          hadd $1 omodes $remove($hget($2,omodes),^)
          while ($hget(channels,%x).item) {
            if ($hget($hget(channels,%x).item,$1)) {
              inv- $2 $hget(channels,%x).item ^
            }
            inc %x
          }
          sno I *** Invisible Usage -- $hget($2,nick) ( $+ $gettok($hget($2,realhost),2,33) $+ ) has disabled invisibility mode
        }
        if (%modebar === o) && ($left($3,1) == -) {
          if (*O* !iswmcs $hget($2,modes)) {
            hdel ircops $2
            hdel $2 ircop
            hdel $2 olvl
            if ($hget(hhost,$2)) hadd -m $2 host $hget(hhost,$2)
            hdel hhost $2
            hdel $2 ologin
            if (*I* iswmcs $hget($2,flags)) hideinv $2
            hdel $2 flags
            hdel $2 snomasks
            if (^ isin $hget($2,modes)) {
              hadd $1 modes $remove($hget($2,modes),^)
              var %x = 1
              while ($hget(channels,%x).item) {
                if ($hget($hget(channels,%x).item,$2)) {
                  inv- $1 $hget(channels,%x).item ^
                }
                inc %x
              }
              sno I *** Invisible Usage -- $hget($2,nick) ( $+ $gettok($hget($2,realhost),2,33) $+ ) has disabled invisibility mode             
            }
            if ($6 == @) { hadd $2 modes + $+ $removecs($hget($2,modes),X,T,A,C,o,+,-) }
            var %x = 1
            while $mid($hget($2,omodes),%x,1) {
              hadd $2 modes + $+ $remove($removecs($hget($2,modes),$mid($hget($2,omodes),%x,1)),+,-)
              if ($hget($2,ircop)) hdel $2 ircop
              if ($hfind(ircops,$2)) hdel ircops $2
              inc %x
            }
            var %omodes = $+(-,$remove($hget($2,omodes),+,-))
            hdel $2 omodes
            sockwrite -n $2 $+(:,$ircd(server)) 380 $hget($2,nick) :You are not an oper anymore.
          }
        }
        if (%modebar === s) {
          while ($4) && ($istokcs($snomasks,$mid($4,%x,1),32)) {
            if ($+(*,$mid($4,%x,1),*) iswmcs $hget($2,snomasks)) {
              if ($mid($4,%x,1) === i) && ($hget(snoi,$2)) { hdel snoi $2 }
              hadd $2 snomasks $+(+,$removecs($hget($2,snomasks),$remove($mid($4,%x,1),+,-),-,+))
              var %snomasks = $+(%-snomasks,$mid($4,%x,1))
            }
            inc %x
          }
          if (!%snomasks) || (!%+-) { inc %x }
        }
      }
      ;##################################################
      ;##################################################
      ;############                            ##########
      ;############   END OF OPER MODES CODE   ##########
      ;############                            ##########
      ;##################################################
      ;##################################################
      inc %i
    }
  }
  :smodend
  if (%snomasks) { var %modes = %modes $+($iif(%+-sno,$v1),%snomasks) | var %param = $+(%+-sno,$validsno(%snomasks)) }
  if ($len(%modes) > 1) || ($len(%omodes) > 1) && ($7 !== -) {
    var %modes = $validumodes(%modes)
    if (!%modes) { halt }
    if ($sock(link.*)) && ($hget($1,level) !== uline) sockwrite -n link.* $+(:,$hget($1,nick)) MODE $+(:,$iif(%omodes,$removecs(%omodes,+),%modes) $+ $iif(o isincs %modes && (!%snomasks),$removecs($hget($2,omodes),o,+,-))) $iif(%param,$v1)
    sockwrite -n $2 $+(:,$iif($hfind(nicks,$5) || $5 == $ircd(server) && !%param,$5,$hget($1,nick))) MODE $hget($2,nick) $+(:,$iif(%omodes,$removecs(%omodes,+),%modes) $+ $iif(o isincs %modes && (!%snomasks),$removecs($hget($2,omodes),o,+,-))) $iif(%param,$v1)
  }
  if ((s isincs $3) && ($7 == ^) && (%modes || %omodes)) || (($6 == ^) && (%modes || %omodes)) {
    sockwrite -n $2 $+(:,$ircd(server)) 501 $hget(%sockname,nick) UMODE $hget($2,nick) $+(:,%+-,$iif(%omodes,$removecs(%omodes,+,-),$removecs(%modes,-,+)) $+ $iif(%omodes,$removecs($hget($2,omodes),+,-,o))) $iif(%param,%param) ( $+ $hget($2,modes) $+ $iif($hget($2,snomasks),$+($chr(32),$v1)) $+ )
  }
  if (%snomasks) { sockwrite -n $2 $+(:,$ircd(server)) 8 $hget($2,nick) Server notice mask ( $+ $iif(%-+sno == +,$removecs($hget($2,snomasks),%snomasks),$hget($2,snomasks)) $+ ) }
  unset %ov. [ $+ [ %sockname ] ]
  unset %i %sockname
  return
}
alias validumodes {
  var %modes = $gettok($1,1,32)
  var %x = 1
  while ($mid(%modes,%x,1)) {
    if ($istok(+ -,$mid(%modes,%x,1),32)) {
      var %+- = $mid(%modes,%x,1)
      inc %x
      if (%+-) && ($mid(%modes,%x,1) isincs $umodes) { var %validmodes = $+(%validmodes,%+-,$mid(%modes,%x,1)) }
      continue
    }
    if ($+(*,$mid(%modes,%x,1),*) !iswmcs $umodes) { inc %x | continue  }
    if ($+(*,$mid(%modes,%x,1),*) iswmcs %validmodes) { inc %x | continue }
    else { var %validmodes = $+(%validmodes,$mid(%modes,%x,1)) }
    inc %x
  }
  return %validmodes
}
alias validchmodes {
  var %modes = $gettok($1,1,32)
  var %x = 1
  while ($mid(%modes,%x,1)) {
    if ($istok(+ -,$mid(%modes,%x,1),32)) {
      var %+- = $mid(%modes,%x,1)
      inc %x
      if (%+-) && ($mid(%modes,%x,1) isincs $chmodes) && ($mid(%modes,%x,1) !isincs %validmodes) {
        var %validmodes = $+(%validmodes,%+-,$mid(%modes,%x,1))
      }
      inc %x
      continue
    }
    if ($+(*,$mid(%modes,%x,1),*) !iswmcs $chmodes) && ($mid(%modes,%x,1) !isincs %validmodes) { inc %x | continue  }
    var %validmodes = $+(%validmodes,$mid(%modes,%x,1))
    inc %x
  }
  return %validmodes
}
alias validsno {
  var %snomasks = $1
  var %x = 1
  while ($mid(%snomasks,%x,1)) {
    if ($+(*,$mid(%snomasks,%x,1),*) !iswmcs $snomasks) { var %snomasks = $removecs(%snomasks,$mid(%snomasks,%x,1)) | dec %x }
    if ($+(*,$mid(%snomasks,%x,1),*) iswmcs %snomasks) { var %snomasks = $removecs(%snomasks,$mid(%snomasks,%x,1)) $+ $mid(%snomasks,%x,1) }
    inc %x
  }
  return %snomasks
}
alias -l wops {
  var %x = 1
  while $hget(users,%x).item {
    if ($1 != 0) && (*w* !iswmcs $hget($hget(users,%x).item,snomasks)) {
      inc %x
      continue
    }
    sockwrite -n $hget(users,%x).item $+(:,$1) WALLOPS $hget($hget($hget(users,%x).item,1).item,nick) $2-
    inc %x
  }
  return
}
alias sno {
  var %z = 1, %pdelay
  while $hget(ircops,%z).item {
    var %ircopsock = $hget(ircops,%z).item
    if ($1 != 0) && ($+(*,$1,*) !iswmcs $hget(%ircopsock,snomasks)) {
      inc %z
      continue
    }
    if ($1 === i) {
      if ($hget(snoi,%ircopsock) == $9) && (%ircopsock !== $sockname) {
        if ($sock(%ircopsock).sq < 5000) { if ($sock(%ircopsock)) sockwrite -n %ircopsock $+(:,$ircd(server)) NOTICE $hget(%ircopsock,nick) : $+ $2- }
        else { inc %pdelay 3
          if ($sock(%ircopsock)) .timer -m 1 %pdelay sockwrite -n %ircopsock $+(:,$ircd(server)) NOTICE $hget(%ircopsock,nick) : $+ $2-
        }
        inc %z
      }
      if (!$hget(snoi,%ircopsock)) && (%ircopsock !== $sockname) {
        if ($sock(%ircopsock).sq < 5000) { if ($sock(%ircopsock)) sockwrite -n %ircopsock $+(:,$ircd(server)) NOTICE $hget(%ircopsock,nick) : $+ $2- }
        else { inc %pdelay 3
          if ($sock(%ircopsock)) .timer -m 1 %pdelay sockwrite -n %ircopsock $+(:,$ircd(server)) NOTICE $hget(%ircopsock,nick) : $+ $2-
        }
      inc %z  }
    }
    else {
      if ($sock(%ircopsock).sq < 5000) { if ($sock(%ircopsock)) sockwrite -n %ircopsock $+(:,$ircd(server)) NOTICE $hget(%ircopsock,nick) : $+ $2- }
      else { inc %pdelay 3
      if ($sock(%ircopsock)) .timer -m 1 %pdelay sockwrite -n %ircopsock $+(:,$ircd(server)) NOTICE $hget(%ircopsock,nick) : $+ $2- }
    }
    inc %z
  }
  return
}
alias rmk {
  if ($2 === k) {
    if (!$3) sno s *** Server -- Removed temporary K:Line $1 (set by $hget(klines,nick_ $+ $1) on $hget(klines,date_ $+ $1) with reason: $hget(klines,reason_ $+ $1) $+ ) [has been expired]
    hdel klines $1
    hdel -w klines $+(*_,$1)
    hsave -b klines data\klines.db
  }
  if ($2 === e) {
    if (!$3) sno s *** Server -- Removed temporary E:Line $1 (set by $hget(elines,nick_ $+ $1) on $hget(elines,date_ $+ $1) with reason: $hget(elines,reason_ $+ $1) $+ ) [has been expired]
    hdel elines $1
    hdel -w elines $+(*_,$1)
    hsave -b elines data\elines.db
  }
  if ($2 === s) {
    if (!$3) sno s *** Server -- Removed temporary Shun $1 (set by $hget(shuns,nick_ $+ $1) on $hget(shuns,date_ $+ $1) with reason: $hget(shuns,reason_ $+ $1) $+ ) [has been expired]
    hdel shuns $1
    hdel -w shuns $+(*_,$1)
    hsave -b shuns data\shuns.db
  }
  if ($2 === z) {
    if (!$3) sno s *** Server -- Removed temporary Z:Line $1 (set by $hget(zlines,nick_ $+ $1) on $hget(zlines,date_ $+ $1) with reason: $hget(zlines,reason_ $+ $1) $+ ) [has been expired]
    hdel zlines $1
    hdel -w zlines $+(*_,$1)
    hsave -b zlines data\zlines.db
  }
  if ($2 === q) {
    if (!$3) sno s *** Server -- Removed temporary Q:Line $1 (set by $hget(qlines,nick_ $+ $1) on $hget(qlines,date_ $+ $1) with reason: $hget(qlines,$+(reason_,$1)) $+ ) [has been expired]
    hdel qlines $1
    hdel -w qlines $+(*_,$1)
    hsave -b qlines data\qlines.db
  }
}
alias spart {
  var %i 1
  while (%i <= $calc($count($2,$chr(44)) + 1)) {
    if ($hfind(channels,$gettok($2,%i,44))) var %chan = $hfind(channels,$gettok($2,%i,44))
    if ($left($gettok(%chan,1,32),1) = $chr(35)) || ($left($gettok(%chan,1,32),1) = $chr(43)) {
      if ($hget($gettok(%chan,1,32),$1)) {
        if ($hget($gettok(%chan,1,32),$1) == .i) {
          sockwrite -n $1 : $+ $hget($1,host) PART %ijoin. [ $+ [ $1 ] ]
          sno I *** Invisible Usage -- $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) silently left channel $hfind(channels,%chan)
          unset %ijoin. [ $+ [ $1 ] ]
          hdel $1 %chan
          hdel %chan $1
          var %c = 1
          while ($hget(%chan,%c).item) {
            if ($sock($hget(%chan,%c).item)) && (*X* iswmcs $hget($hget(%chan,%c).item,modes)) { sockwrite -n $hget(%chan,%c).item $+(:,$hget($1,host)) PART %chan $3- }
            inc %c
          }
          goto spartend
        }
        if ($hget($gettok(%chan,1,32),users) > 1) {
          var %x 1
          while %x <= $hget(%chan,0).item {
            if ($sock($hget(%chan,%x).item)) {
              if (%ijoin. [ $+ [ $1 ] ] !== %chan) {
              sockwrite -n $hget(%chan,%x).item : $+ $hget($1,host) PART $hfind(channels,%chan) $3- }
            }
            hsave -b modes data\chmodes.db
          inc %x }
          hdel %chan $1
          hdel $1 %chan
          hdec %chan users
        }
        else {
          var %c = 1
          while ($hget(%chan,%c).item) {
            if ($hget(%chan,$hget(%chan,%c).item) == .i) {
              set -u10 %dontclose. [ $+ [ %chan ] ] 1
              inc %c
            }
            inc %c
          }
          if (!%dontclose. [ $+ [ %chan ] ]) {
            hfree %chan
            hfree -w $+(+*_,%chan)
            hsave -b modes data\chmodes.db
            if ($hfind(rchans,%chan)) { hadd -m rchans $+(lastused_,%chan) $fulldate }
            if (!$hfind(rchans,%chan)) {
              hdel channels %chan
              hdel modes %chan
              hdel -w topics $+(topic*,_,%chan)
              hsave -b topics data\topics.db
              hsave -b modes data\chmodes.db
              if ($hget($+(bans_,%chan),0).item) { hfree $+(bans_,%chan) }
            }
          }
          if ($hfind(%chan,$1) || $hget(%chan,$1)) { hdel %chan $1 }
          if ($hget(%chan,users)) { hdec %chan users }
          sockwrite -n $1 $+(:,$hget($1,host)) PART %chan $3-
          var %c = 1
          while ($hget(%chan,%c).item) {
            if ($sock($hget(%chan,%c).item)) { sockwrite -n $hget(%chan,%c).item $+(:,$hget($1,host)) PART %chan $3- }
            inc %c
          }
        }
      }
      else {
        if ($sock($1)) sockwrite -n $1 $+(:,$ircd(server)) 442 $hget($1,nick) %chan :You're not on that channel
        inc %x
        return
      }
    }
    else {
      if ($sock($1)) sockwrite -n $1 $+(:,$ircd(server)) 403 $hget($1,nick) %chan :is not a valid channel
      inc %x
      return
    }
    if ($sock(link.*)) && ($hget($1,level) !== uline) sockwrite -n link.* $+(:,$hget($1,host)) PART %chan $3-
    if ($hfind($+(+z_,%chan),$1)) hdel $+(+z_,%chan) $1
    if ($hfind($+(+v_,%chan),$1)) hdel $+(+v_,%chan) $1
    if ($hfind($+(+h_,%chan),$1)) hdel $+(+h_,%chan) $1
    if ($hfind($+(+o_,%chan),$1)) hdel $+(+o_,%chan) $1
    if ($hfind($+(+a_,%chan),$1)) hdel $+(+a_,%chan) $1
    if ($hfind($+(+q_,%chan),$1)) hdel $+(+q_,%chan) $1
    if ($3 !== SAPART:) && (%ijoin. [ $+ [ $1 ] ] !==  $iif($hfind(channels,%chan),$hfind(channels,%chan),%chan)) && ($hget($1,level) !== uline) {
      sno j *** Part -- $hget($1,nick) ( $+ $gettok($hget($1,realhost),2,33) $+ ) has left $iif($hfind(channels,%chan),$hfind(channels,%chan),%chan) $iif($3,( $+ $3- $+ ))
    }
    if (*N* iswmcs $hget(modes,%chan)) {
      var %z = 1
      while $hget(%chan,%z).item {
        if ($hfind($+(+o_,%chan),$hget(%chan,%z).item)) || ($hfind($+(+a_,%chan),$hget(%chan,%z).item)) || ($hfind($+(+q_,%chan),$hget(%chan,%z).item)) {
          sockwrite -n $hget(%chan,%z).item $+(:,$ircd(server)) NOTICE $+(@,%chan) $hget($1,nick) ( $+ $gettok($hget($1,host),2,33) $+ ) has left %chan
        }
        inc %z
      }
    }
    inc %i
  }
  :spartend
  unset %i
  return
}
alias smode {
  if (!$hfind(channels,$2)) {
    sockwrite -n $sockname $+(:,$ircd(server)) 401 $hget($sockname,nick) $2 :No such channel
    halt
  }
  if (%ov. [ $+ [ $1 ] ]) || ($hget($1,level) == uline) { goto smodend }
  if (!$istok(+ -,$left($3,1),32)) && ($3 !=== b) && (!$4) { sockwrite -n $1 $+(:,$ircd(server)) 501 $hget($1,nick) :You must specify + or - for your modes | return }
  if ($3 === b) && (!$4) { goto banlist }
  :smodend
  unset %modes %t.modes %params
  var %i 2, %+- $left($3,1), %modes $left($3,1), %pcount 4
  ;if (!$mid($3,%i,1)) || ($+(*,$mid($3,%i,1),*) !iswmcs $chmodes) { halt }
  while $mid($3,%i,1) {
    if (+ !isin %modes) && (- !isin %modes) {
      var %modes
      inc %i
      continue
    }
    if ($istok(+ -,$mid($3,%i,1),32)) {
      set %+- $mid($3,%i,1)
      var %modes = %modes $+ $mid($3,%i,1)
      var %modes = $replace(%modes,+-,-,-+,+,++,+,--,-)
    }
    if ($mid($3,%i,1) === r) && (!%ov. [ $+ [ $1 ] ]) && ($hget($1,level) !== uline) {
      if ($sock($1)) sockwrite -n $1 $+(:,$ircd(server)) 501 $hget($1,nick) :Mode bar +r may only be set by servers
      set %modes $removecs(%modes,r)
      inc %i
      continue
    }
    if ($len($remove(%modes,+,-)) > 11) { goto mend }
    if ($len($remove(%modes,+,-)) = 25) {
      var %m = 1, %mrc = 0
      while ($mid(%modes,%m,1)) {
        if ($mid(%modes,%m,1) != +) || ($mid(%modes,%m,1) != -) { inc %mrc }
        inc %m
      }
      set %modes $left(%modes,%mrc)
      set %params $gettok(%params,1-25,32)
      goto mend
    }
    if ($mid($3,%i,1) === b) && (%+- == +) {
      if (!$4) {
        :banlist
        var %x 1
        while %x <= $hget(bans_ $+ $2,0).item {
          sockwrite -n $1 $+(:,$ircd(server)) 367 $hget($1,nick) $2 $hget(bans_ $+ $2,%x).item $hget(bans_ $+ $2,%x).data
        inc %x }
        sockwrite -n $1 $+(:,$ircd(server)) 368 $hget($1,nick) $2 :End of Channel Ban List
        unset %modes %params %pcount
      halt }
      if ($hget($+(bans_,$2),0).item == 100) {
        sockwrite -n $sockname $+(:,$ircd(server)) 478 $hget($sockname,nick) $2 $ [ $+ [ %pcount ] ] :Banlist is full. Max 100 bans
        unset %modes %params %pcount
      halt }
      if ($left($ [ $+ [ %pcount ] ],3) == ~R:) && (@ !isin $ [ $+ [ %pcount ] ]) {
        if (!$hfind(rnicks,$right($ [ $+ [ %pcount ] ],-3))) {
          snotice $1 * Username $+(,$right($ [ $+ [ %pcount ] ],-3),) isn't registered, ignored.
          inc %pcount
        }
        else {
          if (!$hfind($+(bans_,$2),$ [ $+ [ %pcount ] ])) && ($ [ $+ [ %pcount ] ]) {
            set %modes $+(%modes,$mid($3,%i,1))
            set %params %params $ [ $+ [ %pcount ] ]
            hadd -m $+(bans_,$2) $ [ $+ [ %pcount ] ] $iif(%ov. [ $+ [ $1 ] ],$ircd(server),$hget($1,nick)) $ctime
            inc %pcount
          }
        }
        goto +bend
      }
      if ($left($ [ $+ [ %pcount ] ],3) == ~C:) {
        if ($left($right($ [ $+ [ %pcount ] ],-3),1) !== $chr(35)) || ($len($ [ $+ [ %pcount ] ]) <= 4) {
          snotice $1 * Invalid channel $+(,$right($ [ $+ [ %pcount ] ],-3),) $+ , ignored.
          inc %pcount
        }
        if (!$hfind($+(bans_,$2),$ [ $+ [ %pcount ] ])) && ($ [ $+ [ %pcount ] ]) && ($makemask($ [ $+ [ %pcount ] ])) {
          set %modes $+(%modes,$mid($3,%i,1))
          set %params %params $ [ $+ [ %pcount ] ]
          hadd -m $+(bans_,$2) $ [ $+ [ %pcount ] ] $iif(%ov. [ $+ [ $1 ] ],$ircd(server),$hget($1,nick)) $ctime
          inc %pcount
        }
        goto +bend
      }
      if (!$hfind($+(bans_,$2),$makemask($ [ $+ [ %pcount ] ]))) && ($ [ $+ [ %pcount ] ]) && ($makemask($ [ $+ [ %pcount ] ])) {
        set %modes $+(%modes,$mid($3,%i,1))
        set %params %params $makemask($ [ $+ [ %pcount ] ])
        hadd -m $+(bans_,$2) $makemask($ [ $+ [ %pcount ] ]) $iif(%ov. [ $+ [ $1 ] ],$ircd(server),$hget($1,nick)) $ctime
        inc %pcount
      }
      :+bend
      goto nomlock
    }
    if ($mid($3,%i,1) === b) && (%+- == -) && ($ [ $+ [ %pcount ] ]) {
      if ($4) {
        if ($left($ [ $+ [ %pcount ] ],3) == ~C:) { goto nomask2 }
        if ($left($ [ $+ [ %pcount ] ],3) == ~R:) { goto nomask2 }
        else { goto bend }
        :nomask2
        if ($hfind($+(bans_,$2),$ [ $+ [ %pcount ] ])) && ($ [ $+ [ %pcount ] ]) {
          set %modes $+(%modes,$mid($3,%i,1))
          set %params %params $ [ $+ [ %pcount ] ]
          hdel $+(bans_,$2) $ [ $+ [ %pcount ] ]
          inc %pcount   
        }
        else { inc %pcount }
      }
      :bend
      if ($hfind($+(bans_,$2),$makemask($ [ $+ [ %pcount ] ]))) && ($makemask($ [ $+ [ %pcount ] ])) {
        set %modes $+(%modes,$mid($3,%i,1))
        set %params %params $makemask($ [ $+ [ %pcount ] ])
        hdel $+(bans_,$2) $makemask($ [ $+ [ %pcount ] ])
        inc %pcount
      }
      else { inc %pcount }
      goto nomlock
    }
    if ($mid($3,%i,1) === e) && (%+- == +) {
      if (!$4) { var %x 1 | while %x <= $hget(excepts_ $+ $2,0).item { sockwrite -n $1 $+(:,$ircd(server)) 348 $hget($1,nick) $2 $hget(excepts_ $+ $2,%x).item $hget(excepts_ $+ $2,%x).data | inc %x  }
        sockwrite -n $1 $+(:,$ircd(server)) 349 $hget($1,nick) $2 :End of Channel Exception List
      unset %modes %params %pcount | return }
      if (!$hfind($+(excepts_,$2),$makemask($ [ $+ [ %pcount ] ]))) && ($makemask($ [ $+ [ %pcount ] ])) {
        if ($hget($+(excepts_,$2),0).item = 100) { sockwrite -n $sockname $+(:,$ircd(server)) 478 $hget($sockname,nick) $2 $makemask($ [ $+ [ %pcount ] ]) :Exceptlist is full. Max 100 excepts | unset %modes %params %pcount | return }
        set %modes $+(%modes,$mid($3,%i,1)) | set %params %params $makemask($ [ $+ [ %pcount ] ])
        hadd -m $+(excepts_,$2) $makemask($ [ $+ [ %pcount ] ]) $hget($1,nick) $ctime
      inc %pcount }
      ;if ($hfind($+(excepts_,$2),$+($makemask($ [ $+ [ %pcount ] ])))) { inc %pcount }
    goto nomlock }
    elseif ($mid($3,%i,1) === e) && (%+- == -) && ($ [ $+ [ %pcount ] ]) {
      if ($4) {
        if ($hfind($+(excepts_,$2),$makemask($ [ $+ [ %pcount ] ]))) && ($makemask($ [ $+ [ %pcount ] ])) {
          set %modes $+(%modes,$mid($3,%i,1))
          set %params %params $makemask($ [ $+ [ %pcount ] ])
          hdel $+(excepts_,$2) $makemask($ [ $+ [ %pcount ] ])
          inc %pcount
        }
        ;if (!$hfind($+(excepts_,$2),$makemask($ [ $+ [ %pcount ] ]))) { inc %pcount }
      }
      goto nomlock
    }
    if ($mid($3,%i,1) === I) && (%+- == +) {
      if (!$4) { var %x 1 | while %x <= $hget(invites_ $+ $2,0).item { sockwrite -n $1 $+(:,$ircd(server)) 367 $hget($1,nick) $2 $hget(invites_ $+ $2,%x).item $hget(invites_ $+ $2,%x).data | inc %x }
        sockwrite -n $1 $+(:,$ircd(server)) 368 $hget($1,nick) $2 :End of Channel Invite List
      unset %modes %params %pcount | return }
      if (!$hfind($+(invites_,$2),$makemask($ [ $+ [ %pcount ] ]))) && ($makemask($ [ $+ [ %pcount ] ])) {
        if ($hget($+(invites_,$2),0).item = 100) { sockwrite -n $sockname $+(:,$ircd(server)) 478 $hget($sockname,nick) $2 $makemask($ [ $+ [ %pcount ] ]) :Invitelist is full. Max 100 invites | unset %modes %params %pcount | return }
        set %modes $+(%modes,$mid($3,%i,1)) | set %params %params $makemask($ [ $+ [ %pcount ] ])
        hadd -m $+(invites_,$2) $makemask($ [ $+ [ %pcount ] ]) $hget($1,nick) $ctime
      inc %pcount }
      ;if ($hfind($+(invites_,$2),$+($makemask($ [ $+ [ %pcount ] ])))) { inc %pcount }
      goto nomlock
    }
    elseif ($mid($3,%i,1) === I) && (%+- == -) && ($ [ $+ [ %pcount ] ]) {
      if ($4) {
        if ($hfind($+(invites_,$2),$makemask($ [ $+ [ %pcount ] ]))) && ($makemask($ [ $+ [ %pcount ] ])) {
          set %modes $+(%modes,$mid($3,%i,1))
          set %params %params $makemask($ [ $+ [ %pcount ] ])
          hdel $+(invites_,$2) $makemask($ [ $+ [ %pcount ] ])
        inc %pcount }
        ;if (!$hfind($+(invites_,$2),$makemask($ [ $+ [ %pcount ] ]))) { inc %pcount }
      }
      goto nomlock
    }
    if ($hget(rchans,$+(modelock_,$2))) {    
      if (!$istokcs(O q a o v h z,$mid($3,%i,1),32)) { 
        snotice $sockname * You can't change modes on this channel.
      halt }
    }
    :nomlock
    if (!$hfind($+(+q_,$2),$1)) && (!$hfind($+(+a_,$2),$1)) && (!$hfind($+(+o_,$2),$1)) && (!$hfind($+(+O2_,$2),$1)) && (!$ocheck($1,o,v)) && ($+(*,$mid($3,%i,1),*) iswmcs $chmodes) && (!%ov. [ $+ [ $1 ] ]) {
      sockwrite -n $1 $+(:,$ircd(server)) 482 $hget($1,nick) $2 :Don't you miss your @, $+($hget($1,nick),?)
      inc %i | inc %pcount 
      return
    }
    elseif ($mid($3,%i,1) === i) && (%+- == +) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === i) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($removecs($hget(modes,$2),$mid($3,%i,1)))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }

    elseif ($mid($3,%i,1) === V) && (%+- == +) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === V) && (!$ [ $+ [ %pcount ] ]) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === S) && (%+- == +) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === S) && (!$ [ $+ [ %pcount ] ]) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === C) && (%+- == +) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === C) && (!$ [ $+ [ %pcount ] ]) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === m) && (%+- == +) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === m) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === n) && (%+- == +) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === n) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === r) && (%+- == +) && (%ov. [ $+ [ $1 ] ]) || ($hget($1,level) == uline) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    if ($mid($3,%i,1) === r) && (%+- == -) && (%ov. [ $+ [ $1 ] ] || $hget($1,level) == uline) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($removecs($hget(modes,$2),$mid($3,%i,1)))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === N) && (%+- == +) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === N) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === R) && (%+- == +) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === R) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === s) && (%+- == +) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === s) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
    set %modes $+(%modes,$mid($3,%i,1)) } }
    elseif ($mid($3,%i,1) === t) && (%+- == +) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === t) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === p) && (%+- == +) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    if ($mid($3,%i,1) === p) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === a) && (!$ [ $+ [ %pcount ] ]) && (%+- == +) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
        set %modes $+(%modes,$mid($3,%i,1))
        ;inc %pcount 
      }
    }
    if ($mid($3,%i,1) === a) && (!$ [ $+ [ %pcount ] ]) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
        set %modes $+(%modes,$mid($3,%i,1))
        ;inc %pcount 
      }
    }
    elseif ($mid($3,%i,1) === q) && (!$ [ $+ [ %pcount ] ]) && (%+- == +) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
        set %modes $+(%modes,$mid($3,%i,1))
        ;inc %pcount
      }
    }
    elseif ($mid($3,%i,1) === q) && (!$ [ $+ [ %pcount ] ]) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($removecs($hget(modes,$2),$mid($3,%i,1)))
        set %modes $+(%modes,$mid($3,%i,1))
        ;inc %pcount 
      }
    }
    elseif ($mid($3,%i,1) === Q) && (%+- == +) {
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    if ($mid($3,%i,1) === Q) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === O) && (!$ [ $+ [ %pcount ] ]) && (%+- == +) {
      if (!$hget($1,ircop)) {
        sockwrite -n $1 $+(:,$ircd(server)) 481 $hget($1,nick) :Permission denied - You are not an IRC Operator
      return }
      if ($+(*,$mid($3,%i,1),*) !iswmcs $hget(modes,$2)) {
        hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === O) && (!$ [ $+ [ %pcount ] ]) && (%+- == -) {
      if (!$hget($1,ircop)) {
        sockwrite -n $1 $+(:,$ircd(server)) 481 $hget($1,nick) :Permission denied - You are not an IRC Operator
      return }
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
      set %modes $+(%modes,$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === k) && ($ [ $+ [ %pcount ] ]) && (%+- == +) {
      set %modes $+(%modes,$mid($3,%i,1))
      hadd data $+(key_,$2) $ [ $+ [ %pcount ] ] | set %params %params $ [ $+ [ %pcount ] ]
      inc %pcount
      hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1))
    }
    elseif ($mid($3,%i,1) === k) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        set %modes $+(%modes,$mid($3,%i,1))
        set %params %params $hget(data,$+(key_,$2))
        inc %pcount
        hdel data $+(key_,$2)
      hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === l) && (%+- == +) {
      if ($ [ $+ [ %pcount ] ] isnum) && ($ [ $+ [ %pcount ] ] !== $hget(data,$+(limit_,$2))) {
        set %modes $+(%modes,$mid($3,%i,1))
        set %params %params $ [ $+ [ %pcount ] ]
        if (*k* iswmcs %modes) set %modes $+($removecs(%modes,k,l),$mid($3,%i,1),k)
        hadd data $+(limit_,$2) $ [ $+ [ %pcount ] ]
        inc %pcount
      hadd modes $2 $+($hget(modes,$2),$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === l) && (%+- == -) {
      if ($+(*,$mid($3,%i,1),*) iswmcs $hget(modes,$2)) {
        set %modes $+(%modes,$mid($3,%i,1))
        set %params %params $hget($2,limit)
        inc %pcount
        hdel $2 limit
      hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1)) }
    }
    elseif ($mid($3,%i,1) === f) && (%+- == +) {
      var %f = 1
      var %unsetf = $mid($4,%f,1)
      var %unsetf.mode = $mid($4,%f,1)
      if (%unsetf == -) {
        var %unsetf true
        inc %f
        while ($mid($4,%f,1)) {
          if ($hget(joinfprot,$2)) && ($mid($4,%f,1) === j) {
            var %modes = $removecs(%modes,f)
            set %modes $+(%modes,$mid($3,%i,1))
            set %params %params $+ $mid($4,%f,1)
            if ($left(%params,1) !== -) { set %params $+(-,$remove(%params,$chr(32))) }
            hdel $2 jfloodp
            if (!$hget(joinfprot,$2)) && (!$hget(msgfprot,$2)) && (!$hget(noticefprot,$2)) && (!$hget(nickfprot,$2)) { hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1)) }
            hdel joinfprot $2
          }
          if ($hget(msgfprot,$2)) && ($mid($4,%f,1) === m) {
            var %modes = $removecs(%modes,f)
            set %modes $+(%modes,$mid($3,%i,1))
            set %params %params $+ $mid($4,%f,1)
            if ($left(%params,1) !== -) { set %params $+(-,$remove(%params,$chr(32))) }
            hdel $2 jfloodp
            if (!$hget(joinfprot,$2)) && (!$hget(msgfprot,$2)) && (!$hget(noticefprot,$2)) && (!$hget(nickfprot,$2)) { hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1)) }
            hdel msgfprot $2
          }
          if ($hget(noticefprot,$2)) && ($mid($4,%f,1) === N) {
            var %modes = $removecs(%modes,f)
            set %modes $+(%modes,$mid($3,%i,1))
            set %params %params $+ $mid($4,%f,1)
            if ($left(%params,1) !== -) { set %params $+(-,$remove(%params,$chr(32))) }
            hdel $2 jfloodp
            if (!$hget(joinfprot,$2)) && (!$hget(msgfprot,$2)) && (!$hget(noticefprot,$2)) && (!$hget(nickfprot,$2)) { hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1)) }
            hdel noticefprot $2
          }
          if ($hget(nickfprot,$2)) && ($mid($4,%f,1) === n) {
            var %modes = $removecs(%modes,f)
            set %modes $+(%modes,$mid($3,%i,1))
            set %params %params $+ $mid($4,%f,1)
            if ($left(%params,1) !== -) { set %params $+(-,$remove(%params,$chr(32))) }
            hdel $2 jfloodp
            hdel nickfprot $2
          }
          if (!$hget(joinfprot,$2)) && (!$hget(msgfprot,$2)) && (!$hget(noticefprot,$2)) && (!$hget(nickfprot,$2)) {
            var %modes = $replace(%modes,+f,-f)
            hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
          }
          inc %f
        }
      }
      if ($gettok($ [ $+ [ %pcount ] ],1,58) isnum) && ($gettok($ [ $+ [ %pcount ] ],3,58) isnum) && ($gettok($ [ $+ [ %pcount ] ],1,58) <= 120) && ($gettok($ [ $+ [ %pcount ] ],1,58) > 0) && ($gettok($ [ $+ [ %pcount ] ],3,58) <= 60) && ($gettok($ [ $+ [ %pcount ] ],3,58) > 0) {
        if ($gettok($ [ $+ [ %pcount ] ],2,58) === j) {
          if ($gettok($hget(joinfprot,$2),1,32) !== $gettok($ [ $+ [ %pcount ] ],1,58)) || ($gettok($hget(joinfprot,$2),2,32) !== $gettok($ [ $+ [ %pcount ] ],3,58)) {
            hadd -m $2 jfloodp $ [ $+ [ %pcount ] ]
            hadd -m joinfprot $2 $gettok($ [ $+ [ %pcount ] ],1,58) $gettok($ [ $+ [ %pcount ] ],3,58)
            set %modes $+(%modes,$mid($3,%i,1))
            set %params %params $ [ $+ [ %pcount ] ]
            hadd modes $2 $+($removecs($hget(modes,$2),$mid($3,%i,1)),$mid($3,%i,1))
            inc %pcount
          }
        }
        if ($gettok($ [ $+ [ %pcount ] ],2,58) === m) {
          if ($gettok($hget(msgfprot,$2),1,32) !== $gettok($ [ $+ [ %pcount ] ],1,58)) || ($gettok($hget(msgfprot,$2),2,32) !== $gettok($ [ $+ [ %pcount ] ],3,58)) {
            hadd -m $2 mfloodp $ [ $+ [ %pcount ] ]
            hadd -m msgfprot $2 $gettok($ [ $+ [ %pcount ] ],1,58) $gettok($ [ $+ [ %pcount ] ],3,58)
            set %modes $+(%modes,$mid($3,%i,1))
            set %params %params $ [ $+ [ %pcount ] ]
            hadd modes $2 $+($removecs($hget(modes,$2),$mid($3,%i,1)),$mid($3,%i,1))
            inc %pcount
          }
        }
        if ($gettok($ [ $+ [ %pcount ] ],2,58) === N) {
          if ($gettok($hget(noticefprot,$2),1,32) !== $gettok($ [ $+ [ %pcount ] ],1,58)) || ($gettok($hget(noticefprot,$2),2,32) !== $gettok($ [ $+ [ %pcount ] ],3,58)) {
            hadd -m $2 n2floodp $ [ $+ [ %pcount ] ]
            hadd -m noticefprot $2 $gettok($ [ $+ [ %pcount ] ],1,58) $gettok($ [ $+ [ %pcount ] ],3,58)
            set %modes $+(%modes,$mid($3,%i,1))
            set %params %params $ [ $+ [ %pcount ] ]
            hadd modes $2 $+($removecs($hget(modes,$2),$mid($3,%i,1)),$mid($3,%i,1))
            inc %pcount
          }
        }
        if ($gettok($ [ $+ [ %pcount ] ],2,58) === n) {
          if ($gettok($hget(nickfprot,$2),1,32) !== $gettok($ [ $+ [ %pcount ] ],1,58)) || ($gettok($hget(nickfprot,$2),2,32) !== $gettok($ [ $+ [ %pcount ] ],3,58)) {
            hadd -m $2 nfloodp $ [ $+ [ %pcount ] ]
            hadd -m nickfprot $2 $gettok($ [ $+ [ %pcount ] ],1,58) $gettok($ [ $+ [ %pcount ] ],3,58)
            set %modes $+(%modes,$mid($3,%i,1))
            set %params %params $ [ $+ [ %pcount ] ]
            hadd -m modes $2 $+($removecs($hget(modes,$2),$mid($3,%i,1)),$mid($3,%i,1))
            inc %pcount
          }
        }
      }
    }
    elseif ($mid($3,%i,1) === f) && (%+- == -) {
      if ($hget(joinfprot,$2))  {
        var %modes = $removecs(%modes,f)
        set %modes $+(%modes,$mid($3,%i,1))
        set %params %params $+ j
        inc %pcount | hdel $2 jfloodp
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
        hdel joinfprot $2
      }
      if ($hget(msgfprot,$2)) {
        var %modes = $removecs(%modes,f)
        set %modes $+(%modes,$mid($3,%i,1))
        set %params %params $+ m
        inc %pcount | hdel $2 jfloodp
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
        hdel msgfprot $2
      }
      if ($hget(noticefprot,$2)) {
        var %modes = $removecs(%modes,f)
        set %modes $+(%modes,$mid($3,%i,1))
        set %params %params $+ N
        inc %pcount | hdel $2 jfloodp
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
        hdel noticefprot $2
      }
      if ($hget(nickfprot,$2)) {
        var %modes = $removecs(%modes,f)
        set %modes $+(%modes,$mid($3,%i,1))
        set %params %params $+ n
        inc %pcount | hdel $2 jfloodp
        hadd modes $2 $removecs($hget(modes,$2),$mid($3,%i,1))
        hdel nickfprot $2
      }
      ;}
    }
    ;##################################################
    ;##################################################
    ;##################################################
    ;############ + CHANNEL STATUS ####################
    ;##################################################
    ;##################################################
    ;##################################################
    if (-+ isin %modes) || (+- isin %modes) { set %modes $left(%modes,-1) }
    elseif ($istokcs(O q a o v h z,$mid($3,%i,1),32)) && (%+- == +) {
      if ($ [ $+ [ %pcount ] ]) && (!$hfind(nicks,$ [ $+ [ %pcount ] ])) {
        sockwrite -n $1 $+(:,$ircd(server)) 401 $hget($1,nick) $ [ $+ [ %pcount ] ] :No such nick
        inc %pcount
        inc %x
        continue
      }
      if ($ [ $+ [ %pcount ] ] && $hget($ [ $+ [ %pcount ] ],level) !== uline && !$hget($2,$hget($ [ $+ [ %pcount ] ],1).item)) || ($hget($2, $hget($ [ $+ [ %pcount ] ],1).item) == .i) {
        sockwrite -n $sockname $+(:,$ircd(server)) 441 $hget($sockname,nick) $ [ $+ [ %pcount ] ] :User not on that channel 
      halt }
      if ($+(*,$replace($mid($3,%i,1),z,-,q,$iif($ip_aq,$ip_q,@),a,$iif($ip_aq,$ip_a,@),o,@,h,%,v,+),*) iswm $hget($2,$hfind(nicks,$ [ $+ [ %pcount ] ]))) { inc %i | continue }
      if ($mid($3,%i,1) === v) && ($ [ $+ [ %pcount ] ]) {
        if (%ov. [ $+ [ $1 ] ]) { goto givev | return }
        if ($hfind($+(+v_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) && ($6 != @) {        
        inc %i | inc %pcount | continue }
        hadd -m +v_ $+ $2 $hget($ [ $+ [ %pcount ] ],1).item
        if (!$hfind($+(+h_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) && (!$hfind($+(+o_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) && (!$hfind($+(+a_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) && (!$hfind($+(+q_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) || (*v* !iswmcs $hget($1,flags)) {
          hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .+
        }
        set %modes $+(%modes,$mid($3,%i,1))
        %params = %params $hfind(nicks,$ [ $+ [ %pcount ] ])
        inc %pcount
      }
      elseif ($mid($3,%i,1) === h) && ($ [ $+ [ %pcount ] ]) {
        if ($hfind($+(+h_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { inc %i | inc %pcount | continue }
        hadd -m +h_ $+ $2 $hget($ [ $+ [ %pcount ] ],1).item
        if (!$hfind($+(+o_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd $2 $hget($ [ $+ [ %pcount ] ],1).item . $+ % }
        if (!$hfind($+(+a_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd $2 $hget($ [ $+ [ %pcount ] ],1).item . $+ % }
        if (!$hfind($+(+q_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd $2 $hget($ [ $+ [ %pcount ] ],1).item . $+ % }
        set %modes $+(%modes,$mid($3,%i,1))
        %params = %params $hfind(nicks,$ [ $+ [ %pcount ] ])
        inc %pcount
      }
      elseif ($mid($3,%i,1) === o) && ($ [ $+ [ %pcount ] ]) {
        if (%ov. [ $+ [ $1 ] ]) { goto giveo | return }
        if ($hfind($+(+o_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) && ($6 != @) { inc %i | inc %pcount | continue }
        :giveo
        hadd -m +o_ $+ $2 $hget($ [ $+ [ %pcount ] ],1).item
        if (!$ip_aq) || (!$hfind($+(+a_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) || (!$hfind($+(+q_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd $2 $hget($ [ $+ [ %pcount ] ],1).item . $+ @ }
        if ($2 == $hget(settings,helpchan)) && (h !isincs $hget($hget($ [ $+ [ %pcount ] ],1).item,modes)) { chgumode $hget($ [ $+ [ %pcount ] ],1).item $hget($ [ $+ [ %pcount ] ],1).item +h 0 $ircd(server) @ }
        set %modes $+(%modes,$mid($3,%i,1))
        %params = %params $hfind(nicks,$ [ $+ [ %pcount ] ])
        inc %pcount
      }
      elseif ($mid($3,%i,1) === a) && ($ [ $+ [ %pcount ] ]) {
        if (%ov. [ $+ [ $1 ] ]) { goto givea | return }
        if ($hfind($+(+a_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) && ($6 != @)  { inc %i | inc %pcount | continue }
        if (!$hfind($+(+q_,$2),$1)) && (!$hfind($+(+a_,$2),$1)) && (!$hfind($+(+O2_,$2),$1)) && (!$ocheck($sockname,o,v)) { inc %i | inc %pcount | continue }
        :givea        
        hadd -m +a_ $+ $2 $hget($ [ $+ [ %pcount ] ],1).item
        if ($ip_aq) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item $+(.,$ip_a)
        set %modes $+(%modes,$mid($3,%i,1))
        %params = %params $hfind(nicks,$ [ $+ [ %pcount ] ])
        inc %pcount
      }
      elseif ($mid($3,%i,1) === q) && ($ [ $+ [ %pcount ] ]) {
        if (%ov. [ $+ [ $1 ] ]) { goto giveq | return }
        if ($hfind($+(+q_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { inc %i | inc %pcount | continue }
        if (!$hfind($+(+q_,$2),$1)) && (!$hfind($+(+O2_,$2),$1)) && (!$ocheck($sockname,o,v)) { inc %i | inc %pcount | continue }
        :giveq        
        hadd -m +q_ $+ $2 $hget($ [ $+ [ %pcount ] ],1).item
        if ($ip_aq) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item $+(.,$ip_q)
        set %modes $+(%modes,$mid($3,%i,1))
        %params = %params $hfind(nicks,$ [ $+ [ %pcount ] ])
        inc %pcount
      }
      elseif ($mid($3,%i,1) === O) && ($ [ $+ [ %pcount ] ]) {
        if (!$hget($1,ircop)) {
          sockwrite -n $1 $+(:,$ircd(server)) 481 $hget($1,nick) :Permission denied - You are not an IRC Operator
        return }
        if ($hfind($+(+O2_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { inc %i | inc %pcount | continue }
        hadd -m +O2_ $+ $2 $hget($ [ $+ [ %pcount ] ],1).item
        set %modes $+(%modes,$mid($3,%i,1)) | %params = %params $hfind(nicks,$ [ $+ [ %pcount ] ])
      inc %pcount }
      elseif ($mid($3,%i,1) === z) && ($ [ $+ [ %pcount ] ]) {
        if ($hfind($+(+z_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { inc %i | inc %pcount | return }
        if (!$hfind($+(+o_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) && (!$hfind($+(+a_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) && (!$hfind($+(+q_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) && (!$hfind($+(+O2_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) {
          if (!$hget($sockname,ircop)) {
            sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 :Don't you miss your @, $+($hget($sockname,nick),?)
            inc %i | inc %pcount | continue
          }
          if ($hget($sockname,ircop)) && (*v* !iswmcs $hget($sockname,flags)) {
            sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 :Don't you miss your @, $+($hget($sockname,nick),?)
            inc %i | inc %pcount | continue
          }
          hadd -m +z_ $+ $2 $hget($ [ $+ [ %pcount ] ],1).item | hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .
          if (!$hfind($+(+v_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .-
          if (!$hfind($+(+h_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .-
          if (!$hfind($+(+o_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .-
          if (!$hfind($+(+a_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .-
          if (!$hfind($+(+q_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .-
          set %modes $+(%modes,$mid($3,%i,1)) | %params = %params $hfind(nicks,$ [ $+ [ %pcount ] ])
        inc %pcount }
      }
    }
    ;##################################################
    ;##################################################
    ;##################################################
    ;############ - CHANNEL STATUS ####################
    ;##################################################
    ;##################################################
    ;##################################################    
    elseif ($istokcs(O q a o v h z,$mid($3,%i,1),32)) && (%+- == -) {
      if (%modes == -) || (%modes == +) { set %modes - }
      if ($ [ $+ [ %pcount ] ]) && (!$hfind(nicks,$ [ $+ [ %pcount ] ])) {
        sockwrite -n $1 $+(:,$ircd(server)) 401 $hget($1,nick) $ [ $+ [ %pcount ] ] :No such nick
        inc %pcount
        inc %x
        continue
      }
      if ($ [ $+ [ %pcount ] ] && $hget($ [ $+ [ %pcount ] ],level) !== uline && !$hget($2,$hget($ [ $+ [ %pcount ] ],1).item)) || ($hget($2, $hget($ [ $+ [ %pcount ] ],1).item) == .i) {
        sockwrite -n $sockname $+(:,$ircd(server)) 441 $hget($sockname,nick) $ [ $+ [ %pcount ] ] :User not on that channel
      halt }
      if ($+(*,$replace($mid($3,%i,1),z,-,q,$ip_q,$ip_a,@,o,@,h,%,v,+),*) iswm $hget($2,$hfind(nicks,$ [ $+ [ %pcount ] ]))) {
      inc %i | continue }
      if ($mid($3,%i,1) === v) {
        if (!$hfind($+(+h_,$2),$1)) && (!$hfind($+(+o_,$2),$1)) && (!$hfind($+(+a_,$2),$1)) && (!$hfind($+(+q_,$2),$1)) && (!$hfind($+(+O2_,$2),$1)) {
          if (!$hget($sockname,ircop)) {
            sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 :Don't you miss your @, $+($hget($sockname,nick),?)
            inc %i | inc %pcount
          continue }
          if ($hget($sockname,ircop)) && (*v* !iswmcs $hget($sockname,flags)) {
            sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 :Don't you miss your @, $+($hget($sockname,nick),?)
            inc %i | inc %pcount
          continue }
        }
        if (!$hfind($+(+v_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { inc %i | continue }
        hdel +v_ $+ $2 $hget($ [ $+ [ %pcount ] ],1).item | hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .
        if ($hfind($+(+h_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .% }
        if ($hfind($+(+o_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .@ }
        if ($hfind($+(+a_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { if ($ip_aq) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item $+(.,$ip_a) }
        if ($hfind($+(+q_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { if ($ip_aq) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item $+(.,$ip_q) }
        set %modes $+(%modes,$mid($3,%i,1)) | %params = %params $hfind(nicks,$ [ $+ [ %pcount ] ])
        inc %pcount
      }
      elseif ($mid($3,%i,1) === h) {
        if (!$hfind($+(+o_,$2),$1)) && (!$hfind($+(+a_,$2),$1)) && (!$hfind($+(+q_,$2),$1)) && (!$hfind($+(+O2_,$2),$1)) {
          if (!$hget($sockname,ircop)) {
            sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 :Don't you miss your @, $+($hget($sockname,nick),?)
            inc %i | inc %pcount
            continue
          }
          if ($hget($sockname,ircop)) && (*v* !iswmcs $hget($sockname,flags)) {
            sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 :Don't you miss your @, $+($hget($sockname,nick),?)
            inc %i | inc %pcount | continue
          }
        }
        if (!$hfind($+(+h_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { inc %i | continue }
        hdel +h_ $+ $2 $hget($ [ $+ [ %pcount ] ],1).item | hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .
        if ($hfind($+(+v_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .+ }
        if ($hfind($+(+o_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .@ }
        if ($hfind($+(+a_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { if ($ip_aq) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item $+(.,$ip_a) }
        if ($hfind($+(+q_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { if ($ip_aq) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item $+(.,$ip_q) }
        set %modes $+(%modes,$mid($3,%i,1)) | %params = %params $hfind(nicks,$ [ $+ [ %pcount ] ])
      inc %pcount }
      elseif ($mid($3,%i,1) === o) {
        if (!$hfind($+(+o_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { inc %i | continue }
        if (!$hfind($+(+o_,$2),$1)) && (!$hfind($+(+a_,$2),$1)) && (!$hfind($+(+q_,$2),$1)) && (!$hfind($+(+O2_,$2),$1)) && (!$ocheck($sockname,o,v)) {
          sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 :Don't you miss your @, $+($hget($sockname,nick),?)
          inc %i | inc %pcount | continue
        }
        if ($hfind($+(+q_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) && ($sockname != $hget($ [ $+ [ %pcount ] ],1).item) && (!$hfind($+(+q_,$2),$sockname)) && (!$ocheck($sockname,o,v)) {
          sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 :user is the channel owner.
          inc %i | inc %pcount | continue
        }
        if ($hfind($+(+a_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) && ($sockname != $hget($ [ $+ [ %pcount ] ],1).item) && (!$hfind($+(+q_,$2),$sockname)) && (!$ocheck($sockname,o,v)) {
          sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 $hfind(nicks,$ [ $+ [ %pcount ] ]) :is a channel admin.
          inc %i | inc %pcount | continue
        }
        hdel +o_ $+ $2 $hget($ [ $+ [ %pcount ] ],1).item | hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .
        if ($2 == $hget(settings,helpchan)) { chgumode $hget($ [ $+ [ %pcount ] ],1).item $hget($ [ $+ [ %pcount ] ],1).item -h 0 $ircd(server) @ }
        if ($hfind($+(+v_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .+ }
        if ($hfind($+(+h_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .% }
        if ($hfind($+(+a_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) {
          if ($ip_aq) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item $+(.,$ip_a)
        }
        if ($hfind($+(+q_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) {
          if ($ip_aq) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item $+(.,$ip_q)
        }
        set %modes $+(%modes,$mid($3,%i,1))
        %params = %params $hfind(nicks,$ [ $+ [ %pcount ] ])
      inc %pcount }
      elseif ($mid($3,%i,1) === a) {
        if (!$hfind($+(+a_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { inc %i | continue }
        if ($sockname !== $hget($ [ $+ [ %pcount ] ],1).item) && (!$ocheck($sockname,o,v)) && (!$hfind($+(+q_,$2),$sockname)) && (!$hfind($+(+O2_,$2),$1)) {
          sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 $hfind(nicks,$ [ $+ [ %pcount ] ]) :user is a channel admin.
          inc %i | inc %pcount | continue
        }
        hdel +a_ $+ $2 $hget($4,1).item | hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .
        if ($hfind($+(+v_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .+ }
        if ($hfind($+(+h_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .% }
        if ($hfind($+(+o_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .@ }
        if ($hfind($+(+q_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { if ($ip_aq) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item $+(.,$ip_q) }
        set %modes $+(%modes,$mid($3,%i,1))
        %params = %params $hfind(nicks,$ [ $+ [ %pcount ] ])
      inc %pcount }
      elseif ($mid($3,%i,1) === q) {
        if (!$hfind($+(+q_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { inc %i | continue }
        if ($sockname !== $hget($ [ $+ [ %pcount ] ],1).item) && (!$ocheck($sockname,o,v)) && (!$hfind($+(+q_,$2),$sockname)) && (!$hfind($+(+O2_,$2),$1)) {
          sockwrite -n $sockname $+(:,$ircd(server)) 482 $hget($sockname,nick) $2 $hfind(nicks,$ [ $+ [ %pcount ] ]) :user is a channel owner.
          inc %i | inc %pcount | continue
        }
        hdel +q_ $+ $2 $hget($ [ $+ [ %pcount ] ],1).item
        hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .
        if ($hfind($+(+v_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .+ }
        if ($hfind($+(+h_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .% }
        if ($hfind($+(+o_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) { hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .@ }
        if ($hfind($+(+a_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) {
          if ($ip_aq) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item $+(.,$ip_a)
        }
        set %modes $+(%modes,$mid($3,%i,1)) | %params = %params $hfind(nicks,$ [ $+ [ %pcount ] ])
      inc %pcount }
      elseif ($mid($3,%i,1) === O) {
        if (!$hget($1,ircop)) {
          sockwrite -n $1 $+(:,$ircd(server)) 481 $hget($1,nick) :Permission denied - You are not an IRC Operator
        return }
        if (!$hfind($+(+O2_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) {
          inc %i
          continue
        }
        hdel +O2_ $+ $2 $hget($ [ $+ [ %pcount ] ],1).item
        set %modes $+(%modes,$mid($3,%i,1))
        %params = %params $hfind(nicks,$ [ $+ [ %pcount ] ])
      inc %pcount }
      elseif ($mid($3,%i,1) === z) {
        if (!$hfind($+(+z_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) {
          inc %pcount
          return
        }
        if (!$hfind($+(+o_,$2),$1)) && (!$hfind($+(+a_,$2),$1)) && (!$hfind($+(+q_,$2),$1)) && (!$hfind($+(+O2_,$2),$1)) {
          if (!$hget($sockname,ircop)) {
            inc %i
            inc %pcount
            continue
          }
          if ($hget($sockname,ircop)) && (*v* !iswmcs $hget($sockname,flags)) {
            inc %i
            inc %pcount
            continue
          }
        }
        hdel +z_ $+ $2 $hget($ [ $+ [ %pcount ] ],1).item | hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .
        if ($hfind($+(+v_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .+
        if ($hfind($+(+h_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .%
        if ($hfind($+(+o_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item .@
        if ($hfind($+(+a_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) {
          if ($ip_aq) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item $+(.,$ip_a)
        }
        if ($hfind($+(+q_,$2),$hget($ [ $+ [ %pcount ] ],1).item)) {
          if ($ip_aq) hadd -m $2 $hget($ [ $+ [ %pcount ] ],1).item $+(.,$ip_q)
        }
        set %modes $+(%modes,$mid($3,%i,1))
        %params = %params $hfind(nicks,$ [ $+ [ %pcount ] ])
      inc %pcount }
    }
    inc %i
  }
  :mend
  var %i = 1
  if (%modes) {
    while %i <= $hget($2,0).item {
      if ($sock($hget($2,%i).item)) {
        set %host $iif(%ov. [ $+ [ $1 ] ],$ircd(server),$hget($1,host))
        %chan = $2
      }
      inc %i
    }
    var %modes = $validchmodes(%modes)
    makeparams %modes %params
    unset %ban %i %params
    return
  }
  return
}
alias skick {
  if ($hget($2,$hget($3,1).item) == .i) halt
  var %i 1
  if (*N* iswmcs $hget(modes,$2)) {
    var %z = 1
    while $hget($2,%z).item {
      if ($hfind($+(+o_,$2),$hget($2,%z).item)) || ($hfind($+(+a_,$2),$hget($2,%z).item)) || ($hfind($+(+q_,$2),$hget($2,%z).item)) {
        if ($sock($hget($2,%z).item)) {
          sockwrite -n $hget($2,%z).item $+(:,$ircd(server)) NOTICE $+(@,$2) $+(:,$3) ( $+ $gettok($hget($hget($3,1).item,host),2,33) $+ ) has been kicked off channel $2 ( $+ $iif($4,$4-,$hget($1,nick)) $+ )
        }
      }
    inc %z }
  }
  while (%i <= $hget($2,0).item) {
    if ($sock($hget($2,%i).item)) {
      sockwrite -n $hget($2,%i).item : $+ $iif(%ov. [ $+ [ $1 ] ],$ircd(server),$hget($1,host)) KICK $2-3 $iif($4,$4-,$hget($1,nick))
    }
    inc %i
  }
  if ($hget($2,users) >= 1) {
    hdec $2 users
    hdel $2 $hget($3,1).item
    hdel $hget($3,1).item $2
  }
  else {
    if (!$hfind(rchans,$2)) {
      hdel modes $2
      hdel channels $2
      hdel -w topics $+(topic*_,$2)
      if ($hget($+(bans_,$2),0).item) hfree $+(bans_,$2)
      hfree $2
      hfree -w +*_ $2
    }
  }
  if ($hfind($+(+z_,$2),$hget($3,1).item)) hdel $+(+z_,$2) $hget($3,1).item
  if ($hfind($+(+v_,$2),$hget($3,1).item)) hdel $+(+v_,$2) $hget($3,1).item
  if ($hfind($+(+h_,$2),$hget($3,1).item)) hdel $+(+h_,$2) $hget($3,1).item
  if ($hfind($+(+o_,$2),$hget($3,1).item)) hdel $+(+o_,$2) $hget($3,1).item
  if ($hfind($+(+a_,$2),$hget($3,1).item)) hdel $+(+a_,$2) $hget($3,1).item
  if ($hfind($+(+q_,$2),$hget($3,1).item)) hdel $+(+q_,$2) $hget($3,1).item
  unset %ov. [ $+ [ $1 ] ]
  if ($sock(link.*)) && ($hget($1,level) !== uline) sockwrite -n link.* $+(:,$iif(%ov. [ $+ [ $1 ] ],$ircd(server),$hget($1,nick))) KICK $2-3
  return
}
alias -l delchans {
  var %x = 1
  while ($hget(rchans,%x).item) {
    %chan = $hget(rchans,%x).item
    if ($left($hget(rchans,%x).item,1) == $chr(35)) {
      if ($1 == $hget(rchans,$+(founder_,%chan))) {
        remini data\access.db $hget(rchans,%x).item
        remini data\akicks.db $hget(rchans,%x).item
        set -u1 %ov. [ $+ [ $1 ] ] true
        smode $1 $hget(rchans,%x).item -r
        hdel -w rchans $+(*,$hget(rchans,%x).item,*)
        hsave -b rchans data\chans.db
      inc %x }
    }
  inc %x }
  if ($2) delacc $1-2
}
alias -l delacc {
  var %x = 1
  :while
  while ($hget(rchans,%x).item) {
    var %chan = $hget(rchans,%x).item
    if ($left(%chan,1) == $chr(35)) {
      var %chan = $hget(rchans,%x).item
      if ($readini(data\access.db,%chan,$hget($2,loggedin))) {
        remini data\access.db %chan $replace($hget($2,loggedin),[,*,],&)
        inc %x
      goto while }
    }
  inc %x }
  hdel $2 loggedin
  unset %loggedin. [ $+ [ $1 ] ]
  halt
}
alias send {
  if ($1 = -s) { var %x = $3 }
  else { var %x = $1 }
  while ($read($langdir,%x)) {
    if ($1 = -s) { sockwrite -n $2 $+(:,$hget(ircd,server)) $read($langdir,%x)
      inc %x
    }
    else {
      if ($sock($sockname)) sockwrite -n $sockname $+(:,$hget(ircd,server)) $read($langdir,%x)
      inc %x
    }
    if ($1 = -s) && (%x > $4) { break }
    elseif ($1 != -s) && (%x > $2) { break }
  }
}
