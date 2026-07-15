**free

/////////////////////
// Work with Customers
/////////////////////

ctl-opt dftactgrp(*no) actgrp(*new);
ctl-opt bnddir('CUST');

dcl-f wrkcustd workstn sfile(custsfl : rrn) sfile(custmsgsfl : msgrrn);

/copy custr_pr.rpgle

dcl-ds statusDS psds qualified;
  programName char(10) pos(334);
end-ds;

dcl-pr wrkcust1r extpgm;
  custno like(cust_rec.custno) const;
end-pr;

dcl-s numCustomers int(10);
dcl-ds customers likeds(cust_rec) dim(9999);
dcl-s custerror varchar(80);

dcl-s msgrrn int(10);
dcl-s rrn int(10);
dcl-s i int(10);
dcl-s selrrn int(10);
dcl-s validOpt ind;
dcl-s findCust like(sfndcustno);
dcl-s filter like(sfilter);
dcl-s foundCustomer ind;

dow not *in03;

  // Clear error messages.
  exsr clearMSGSFL;

  // Get customer list.
  exsr getCustomers;

  // Write function key label footer.
  sfkeys = 'F3=Exit';
  if numCustomers <> 0;
    sfkeys = %trim(sfkeys) + '  F11=Fold/Unfold';
  endif;
  write custfoot;

  // If no customers, set subfile display indicator off and write "no customers" screen.
  // Otherwise load subfile set subfile display indicator on.
  if numCustomers = 0;
    *in30 = *off;
    write custnone;
  else;
    exsr loadSFL;
    *in30 = *on;
  endif;

  // Set error message subfile display, if necessary.
  if msgrrn = 0;
    *in40 = *off;
  else;
    *in40 = *on;
    write custmsgctl;
  endif;

  // Set subfile options.
  if numCustomers = 0;
    soptdesc = '';
  else;
    soptdesc = '5=Display';
  endif;

  // Display the screen.
  sfndcustno = findCust;
  sfilter = filter;
  exfmt custctl;

  // Process function keys.
  exsr processFKeys;

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

  // Process selection if subfile is displayed.
  if *in30;
    dou sopt = '' or isValidOption(sopt);
      selrrn = 0;
      sopt = '';
      readc custsfl;
      dow not %eof(wrkcustd);
        if sopt <> '';
          if selrrn = 0;
            selrrn = rrn;
          else;
            sopt = '';
          endif;
        endif;
        *in50 = *off;
        *in51 = *off;
        update custsfl;
        readc custsfl;
      enddo;
      if selrrn <> 0;
        chain selrrn custsfl;
        if not isValidOption(sopt);
          exsr clearMSGSFL;
          writeMSGSFL('Invalid option: ' + %trim(sopt));
          *in40 = *on;
          write custmsgctl;
          *in50 = *on;
          *in51 = *on;
          update custsfl;
          *in50 = *off;
          *in51 = *off;
          exfmt custctl;
          exsr processFKeys;
        endif;
      endif;
    enddo;
    select;
      when %trim(sopt) = '5';
        wrkcust1r(scustno);
    endsl;
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
    writeMSGSFL(custError);
  endif;
endsr;

begsr clearSFL;
  rrn = 0;
  *in31 = *on;
  write custctl;
  *in31 = *off;
endsr;

begsr loadSFL;
  exsr clearSFL;
  for i = 1 to numCustomers;
    *in50 = *off;
    *in51 = *off;
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

begsr clearMSGSFL;
  msgrrn = 0;
  *in41 = *on;
  write custmsgctl;
  *in41 = *off;
endsr;

begsr processFKeys;
  if *in03; // Exit
    *inlr = *on;
    return;
  endif;
endsr;

dcl-proc writeMSGSFL;
  dcl-pi *n;
    msgData varchar(80) const options(*varsize);
  end-pi;

  dcl-pr QMHSNDPM extpgm;
    msgId char(7) const;
    msgF char(20) const;
    msgData char(80) const;
    msgDataLen int(10) const;
    msgType char(10) const;
    stackEntry char(10) const;
    stackCounter int(10) const;
    msgKey char(4);
    errorCode char(8) const;
  end-pr;

  dcl-s data char(80);

  data = msgData;
  QMHSNDPM(
    'CPF9897' : 
    'QCPFMSG   QSYS      ' :
    data :
    %len(msgData) :
    '*INFO     ' :
    '*         ' :
    1 :
    smsgkey :
    x'0000000000000000'
  );
  msgrrn += 1;
  spgmq = statusDS.programName;
  write custmsgsfl;

end-proc;

dcl-proc isValidOption;
  dcl-pi *n ind;
    option char(2) const;
  end-pi;

  select;
    when %trim(option) = '5';
      return *on;
    other;
      return *off;
  endsl;

end-proc;
