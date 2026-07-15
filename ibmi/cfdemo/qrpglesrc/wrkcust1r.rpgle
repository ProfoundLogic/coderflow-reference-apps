**free

/////////////////////
// Work with Customers: Customer Detail
/////////////////////

ctl-opt dftactgrp(*no) actgrp(*new);
ctl-opt bnddir('CUST');

dcl-f wrkcust1d workstn;

/copy custr_pr.rpgle

dcl-pi *n;
  custno like(cust_rec.custno) const;
end-pi;

dcl-ds customer likeds(cust_rec);
dcl-s customerFound ind;
dcl-s error varchar(210);

dow not *in03;
  exsr showScreen;
enddo;

*inlr = *on;

// Loads customer record and displays screen.
begsr showScreen;

  error = cust_get(custno : customer : customerFound);
  if customerFound;
    scustno = customer.custno;
    sname = customer.cname;
    stype = customer.ctype;
    sstatus = customer.cstatus;
    slimit = customer.climit;
    sbalance = customer.cbalance;
    slastord = %char(%date(customer.clastord) : *usa);
    screated = %char(%date(customer.ccreated) : *usa);

    saddr1 = customer.caddr1;
    saddr2 = customer.caddr2;
    scity = customer.ccity;
    sstate = customer.cstate;
    szip = customer.czip;
    semail = customer.cemail;
    sphone = customer.cphone;

    *in30 = *off; // Protect fields from editing.
    sfkeys = 'F3=Exit';
    exfmt custdetail;
  else;
    if error = '';
      error = 'Customer ' + %char(custno) + ' not found.';
    endif;
    exsr endError;
  endif;

endsr;

// Displays error window and ends the program.
begsr endError;
  serrattr = x'A0';
  serrwinmsg = error;
  exfmt errorwin;
  *inlr = *on;
  return;
endsr;
