**free

/////////////////////
// Work with Customers (EJS Screen Mode)
/////////////////////

ctl-opt dftactgrp(*no) actgrp(*new);
ctl-opt bnddir('CUST');

dcl-f wrkcusteo workstn sfile(custsfl : rrn) handler('PROFOUNDUI(HANDLER)');

/copy custr_pr.rpgle

dcl-pr wrkcust1eo extpgm;
  custno like(cust_rec.custno) const;
end-pr;

dcl-s numCustomers int(10);
dcl-ds customers likeds(cust_rec) dim(9999);
dcl-s custerror varchar(80);

dcl-s rrn int(10);
dcl-s i int(10);
dcl-s selrrn int(10);
dcl-s findCust like(sfndcustno);
dcl-s filter like(sfilter);
dcl-s foundCustomer ind;

dow action <> 'EXIT';

  // Get customer list.
  exsr getCustomers;

  // Set subfile options description.
  if numCustomers = 0;
    soptdesc = '';
    msg = 'No customers found.';
  else;
    soptdesc = '5=Display';
    msg = '';
  endif;

  // Load subfile.
  if numCustomers > 0;
    exsr loadSFL;
  else;
    exsr clearSFL;
  endif;

  // Display the screen.
  sfndcustno = findCust;
  sfilter = filter;
  action = '';
  exfmt custctl;

  // Process action.
  select;
    when action = 'EXIT';
      leave;
  endsl;

  // Process find/filter.
  if sfndcustno <> findCust or sfilter <> filter;
    if sfndcustno <> findCust;
      findCust = sfndcustno;
      filter = '';
    elseif sfilter <> filter;
      filter = sfilter;
      findCust = 0;
    endif;
    iter;
  endif;

  // Process selection.
  if numCustomers > 0;
    selrrn = 0;
    sopt = '';
    readc custsfl;
    dow not %eof(wrkcusteo);
      if sopt <> '' and selrrn = 0;
        selrrn = rrn;
      endif;
      update custsfl;
      readc custsfl;
    enddo;
    if selrrn <> 0;
      chain selrrn custsfl;
      select;
        when %trim(sopt) = '5';
          wrkcust1eo(scustno);
      endsl;
    endif;
  endif;

enddo;

*inlr = *on;

begsr getCustomers;
  if findCust <> 0;
    numCustomers = 0;
    custError = cust_get(findCust : customers(1) : foundCustomer);
    if foundCustomer;
      numCustomers = 1;
    endif;
  else;
    custError = cust_list(customers : %elem(customers) : numCustomers : %trim(filter));
  endif;
  if custError <> '';
    msg = custError;
  endif;
endsr;

begsr clearSFL;
  rrn = 0;
  sflclear = '1';
  write custctl;
  sflclear = '0';
endsr;

begsr loadSFL;
  exsr clearSFL;
  for i = 1 to numCustomers;
    sopt = '';
    scustno = customers(i).custno;
    sname = customers(i).cname;
    saddr = %trim(customers(i).caddr1) + ' ' + %trim(customers(i).caddr2) + ' ' +
            %trim(customers(i).ccity) + ', ' + customers(i).cstate + ' ' + customers(i).czip;
    semail = customers(i).cemail;
    sphone = customers(i).cphone;
    rrn += 1;
    write custsfl;
  endfor;
endsr;
