       
       dcl-ds cust_rec extname('CUSTP') qualified template end-ds;

       dcl-pr cust_get varchar(80);
         custno like(cust_rec.custno) const;
         customer likeds(cust_rec);
         found ind;
       end-pr;

       dcl-pr cust_list varchar(80);
         customers like(cust_rec) dim(9999);
         limit int(10) const;
         returned int(10);
         filter varchar(50) const options(*omit : *nopass);
       end-pr;
