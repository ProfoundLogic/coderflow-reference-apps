**free

/////////////////////
// Work with Customers: Customer Detail (EJS Screen Mode)
/////////////////////

ctl-opt dftactgrp(*no) actgrp(*new);
ctl-opt bnddir('CUST');

dcl-f wrkcust1eo workstn handler('PROFOUNDUI(HANDLER)');

/copy custr_pr.rpgle

dcl-pi *n;
  custno like(cust_rec.custno) const;
end-pi;

dcl-ds customer likeds(cust_rec);
dcl-s customerFound ind;
dcl-s error varchar(210);

dow action <> 'EXIT';
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

    msg = '';
    action = '';
    exfmt custdetail;
  else;
    if error = '';
      error = 'Customer ' + %char(custno) + ' not found.';
    endif;
    msg = error;
    action = 'EXIT';
    exfmt custdetail;
  endif;

endsr;
