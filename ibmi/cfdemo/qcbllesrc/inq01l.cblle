       Identification division.
       Program-ID.    INQ01L.
       Author.        Ted Holt.
       Date-written.  August 2018.
      *  This is a direct translation of RPG program INQ01R.

      *  This is the original green-screen version & can run
      *  from a green-screen or Genie session.

       Environment division.
       Configuration section.
       Input-output section.
       File-control.
           Select Display-file
               assign to workstation-INQ01D-si
               organization is transaction
               access mode is dynamic
               relative key is Subfile-record-number.

           Select Products-file
               assign to database-PRODUCTSP
               organization is indexed
               access mode is dynamic
               record key is externally-described-key.

           Select Products-by-ID
               assign to database-PRODUCTS1L
               organization is indexed
               access mode is dynamic
               record key is externally-described-key.

           Select Products-by-name
               assign to database-PRODUCTS2L
               organization is indexed
               access mode is dynamic
               record key is externally-described-key.

           Select Category-file
               assign to database-CATEGP
               organization is indexed
               access mode is dynamic
               record key is externally-described-key.

           Select Product-features
               assign to database-PRODFEATP
               organization is indexed
               access mode is dynamic
               record key is externally-described-key.

           Select Features-file
               assign to database-FEATURESP
               organization is indexed
               access mode is dynamic
               record key is externally-described-key.

       Data division.
       File section.
       FD  Display-file.
       01  Display-record.
           copy dds-all-formats of INQ01D    prefix by "ignore-".

       FD  Products-file.
       01  Products-record.
           copy dds-all-formats of PRODUCTSP.

       FD  Products-by-ID.
       01  Products-record-1.
           copy dds-all-formats of PRODUCTS1L.

       FD  Products-by-name.
       01  Products-record-2.
           copy dds-all-formats of PRODUCTS2L.

       FD  Category-file.
       01  Category-record.
           copy dds-all-formats of CATEGP.

       FD  Product-features.
       01  Product-features-record.
           copy dds-all-formats of PRODFEATP.

       FD  Features-file.
       01  Features-record.
           copy dds-all-formats of FEATURESP.

       Working-storage section.

       01 PRODSFL-record.          copy dds-PRODSFL     of INQ01D.
       01 PRODCTL-record-in.       copy dds-PRODCTL-I   of INQ01D.
       01 PRODCTL-record-out.      copy dds-PRODCTL-O   of INQ01D.
       01 PRODDETL-record-out.     copy dds-PRODDETL-O  of INQ01D.
       01 FEATSFL-record.          copy dds-FEATSFL     of INQ01D.

       01  ws-Products-record.
           copy dds-all-formats of PRODUCTSP prefix by "ws-prod-".

       01  Current-product-id          like PRID of Products-record.

       01  Flags.
           03  End-of-read-flag        pic 1.
               88  More-data                   value b"0".
               88  No-more-data                value b"1".
           03  SFL-change-flag         pic 1.
               88  Changed-sfl-record          value b"0".
               88  No-change-to-SFL            value b"1".

       01  Subfile-record-number       pic 9(4).

       01  Indicator-structure.
           03  Display-indicator occurs 99 times pic 1
                                 indicator 1.
       01  redefines Indicator-structure.
           03                                    pic x(2).
           03  Exit-flag                         pic 1.
               88  Exit-requested              value b"1".

       Procedure division.
       000-Main-logic.
           open input Products-file, Products-by-ID, Products-by-name
                      Category-file, Product-features, Features-file
                I-O   Display-file

           initialize PRODSFL-record
           initialize PRODCTL-record-in
           initialize PRODCTL-record-out
           initialize PRODDETL-record-out
           initialize FEATSFL-record

           perform 010-Get-first-category
           perform until Exit-requested
               perform 020-Load-subfile
               perform 040-Display-subfile
               if not Exit-requested
                   read subfile Display-file next modified record
                       into           PRODSFL-record
                       format     is  "PRODSFL"
                       indicators are Indicator-structure
                       at end
                           set No-change-to-SFL   to true
                       not at end
                           move PrID of PRODSFL-record
                                            to Current-product-ID
                           set Changed-sfl-record to true
                   end-read
                   if Changed-sfl-record
                   and Opt of PRODSFL-record = "1"
                       perform 050-Show-product-details
                   end-if
               end-if
           end-perform
           close Products-file, Products-by-ID, Products-by-name,
                 Category-file, Display-file, Product-features,
                 Features-file
           goback.

       010-Get-first-category.
           read Category-file first record
               at end  initialize Category-record
           end-read
           move CatID   of Category-record to S1CatID of PRODCTL-O
           move CatName of Category-record to CatName of PRODCTL-O
           continue.

       020-Load-subfile.

      * clear the subfile
           move b"1" to Display-indicator (70)
           write Display-record
               from           PRODCTL-record-out
               format     is  "PRODCTL"
               indicators are Indicator-structure
           end-write
           move b"0" to Display-indicator (70)
           move zero to Subfile-record-number

           if s1PrName of PRODCTL-record-out = spaces
     ******   start PRODUCTS1
              move s1CatID of PRODCTL-record-out
                                    to PRCatID of Products-record-1
              move s1PrID  of PRODCTL-record-out
                                    to PrID    of Products-record-1
              start  Products-by-ID
                  key is not less than externally-described-key
              end-start
           else
     *******  start PRODUCTS2
              move s1CatID of PRODCTL-record-out
                                    to PRCatID of Products-record-2
              move s1PrName of PRODCTL-record-out
                                    to PrName  of Products-record-2
              move s1PrID   of PRODCTL-record-out
                                    to PrID    of Products-record-2
              start  Products-by-Name
                  key is not less than externally-described-key
              end-start
           end-if

           set More-data  to true
           perform 030-Read-product
           perform until No-more-data
               initialize PRODSFL of PRODSFL-record
               move ws-prod-PrID    to PrID    of PRODSFL-record
               move ws-prod-PrName  to PrName  of PRODSFL-record
               move ws-prod-PrPrice to PrPrice of PRODSFL-record
               move ws-prod-PrQty   to PrQty   of PRODSFL-record
               add  1               to Subfile-record-number
               write subfile Display-record
                   from           PRODSFL-record
                   format     is  "PRODSFL"
                   indicators are Indicator-structure
               end-write
               perform 030-Read-product
           end-perform

           continue.

       030-Read-product.
           if s1PrName of PRODCTL-record-out = spaces
               read Products-by-ID next record into ws-Products-record
                   at end set No-more-data to true
               end-read
           else
               read Products-by-name next record into ws-Products-record
                   at end set No-more-data to true
               end-read
           end-if
           continue.

       040-Display-subfile.
           write Display-record
               format is "PRODBOTTOM"
               indicators are Indicator-structure
           end-write
           write Display-record
               from           PRODCTL-record-out
               format     is  "PRODCTL"
               indicators are Indicator-structure
           end-write
           read Display-file
               into           PRODCTL-record-in
               format     is  "PRODCTL"
               indicators are Indicator-structure
           end-read
           move corresponding PRODCTL-I  of PRODCTL-record-in
                           to PRODCTL-O  of PRODCTL-record-out
           continue.

       050-Show-product-details.
           move Current-product-ID to PrID of Products-record
           read Products-file
               into ws-Products-record
               invalid key
                   initialize ws-Products-record
           end-read

           move ws-prod-PrID    to PrID    of PRODDETL-record-out
           move ws-prod-PrName  to PrName  of PRODDETL-record-out
           move ws-prod-PrDesc  to PrDesc  of PRODDETL-record-out
           move ws-prod-PrPrice to PrPrice of PRODDETL-record-out
           move ws-prod-PrQty   to PrQty   of PRODDETL-record-out
           move ws-prod-PrCatID to PrCatID of PRODDETL-record-out

           move ws-prod-PrCatID to CatID   of Category-record
           read Category-file
               invalid key
                   move spaces  to CatName of PRODDETL-record-out
               not invalid key
                   move CatName of Category-record
                                to CatName of PRODDETL-record-out
           end-read

           move b"1" TO Display-indicator(6)
           perform until Display-indicator (6) = b"0"
               write Display-record
                   from           PRODDETL-record-out
                   format     is  "PRODDETL"
                   indicators are Indicator-structure
               end-write
               read Display-file
                   format     is  "PRODDETL"
                   indicators are Indicator-structure
               end-read
               if Display-indicator (06) = b"1"
                   perform 060-Show-features
               end-if
           end-perform

           continue.

       060-Show-features.

      * clear the subfile
           move b"1" to Display-indicator (60)
           write Display-record
               format     is  "FEATWIN"
               indicators are Indicator-structure
           end-write
           move b"0" to Display-indicator (60)
           move zero to Subfile-record-number

      * load the subfile
           move Current-product-ID to xPrID of Product-features-record
           move zero               to xFeID of Product-features-record
           start Product-features
               key is not less than externally-described-key
           end-start

           set More-data to true
           perform 070-Read-product-feature
           perform until No-more-data
               move xFeID of Product-features-record
                                    to FEID   of FEATSFL-record

               move xFeID of Product-features-record
                                    to FEID   of Features-record
               read Features-file
                   invalid key
                       move spaces     to FeName of FEATSFL-record
                   not invalid key
                       move FeName of Features-record
                                       to FeName of FEATSFL-record
               end-read

               add  1               to Subfile-record-number
               write subfile Display-record
                   from           FEATSFL-Record
                   format     is  "FEATSFL"
                   indicators are Indicator-structure
               end-write
               perform 070-Read-product-feature
           end-perform

           write Display-record
               format     is  "FEATWIN"
               indicators are Indicator-structure
           end-write
           read Display-file
               format     is  "FEATWIN"
               indicators are Indicator-structure
           end-read
           continue.

       070-Read-product-feature.
           read Product-features next record
               at end set No-more-data to true
           end-read
           if More-data
           and xPrID not = Current-product-ID
               set No-more-data to true
           end-if
           continue.
