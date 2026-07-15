**free

ctl-opt nomain;

exec sql set option commit = *none;
exec sql set option closqlcsr = *endmod;

/copy custr_pr.rpgle

dcl-proc cust_get export;
  dcl-pi *n varchar(80);
    custno like(cust_rec.custno) const;
    customer likeds(cust_rec);
    found ind;
  end-pi;

  found = *off;
  exec sql
    select
      *
    into
      :customer
    from
      custp
    where
      custno = :custno;
  exsr checkError;
  found = sqlcode <> 100;
  return '';

  begsr checkError;
    if sqlcode < 0;
      return 'Error retrieving customer. SQLCODE = ' + %char(sqlcode) + ', SQLSTATE = ' + sqlstate;
    endif;
  endsr;

end-proc;

dcl-proc cust_list export;
  dcl-pi *n varchar(80);
    customers like(cust_rec) dim(9999);
    limit int(10) const;
    returned int(10);
    p_filter varchar(50) const options(*omit : *nopass);
  end-pi;

  dcl-ds customer likeds(cust_rec);
  dcl-s filter like(p_filter);
  
  if %parms() >= 4 and %addr(p_filter) <> *null;
    filter = %upper(p_filter);
  endif;

  returned = 0;

  exec sql declare c1 cursor for
  select
    *
  from
    custp
  where
    :filter = '' or (
      ucase(cname) like '%' concat :filter concat '%' or
      ucase(cemail) like '%' concat :filter concat '%' or
      cphone like :filter concat '%'
    )
  order by
    custno;
  exec sql open c1;
  exsr checkError;

  exec sql fetch c1 into :customer;
  exsr checkError;
  dow returned < limit and sqlcode <> 100;
    returned += 1;
    customers(returned) = customer;
    exec sql fetch c1 into :customer;
    exsr checkError;
  enddo;
  exec sql close c1;
  return '';

  begsr checkError;
    if sqlcode < 0;
      return 'Error retrieving customer list. SQLCODE = ' + %char(sqlcode) + ', SQLSTATE = ' + sqlstate;
    endif;
  endsr;

end-proc;
