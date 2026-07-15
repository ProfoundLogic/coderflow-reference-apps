# Display files
hellod.file: qddssrc/hellod.dspf
menu.file: qddssrc/menu.dspf
wrkcustd.file: qddssrc/wrkcustd.dspf
wrkcust1d.file: qddssrc/wrkcust1d.dspf
inq01d.file: qddssrc/inq01d.dspf

# Rich Display Files
wrkcustdo.file: qddssrc/wrkcustdo.json
wrkcust1do.file: qddssrc/wrkcust1do.json

# Physical files
custp.file: qddssrc/custp.pf
ordhdrp.file: qddssrc/ordhdrp.pf
orddtlp.file: qddssrc/orddtlp.pf
prodp.file: qddssrc/prodp.pf
productsp.file: qddssrc/productsp.pf
categp.file: qddssrc/categp.pf
prodfeatp.file: qddssrc/prodfeatp.pf
featuresp.file: qddssrc/featuresp.pf

# Logical files
products1l.file: qddssrc/products1l.lf | productsp.file
products2l.file: qddssrc/products2l.lf | productsp.file

# Message file and menu
menu.msgf: menu.msgf
menu.menu: menu.msgf | menu.file

# Simple program
hellor.pgm: qrpglesrc/hellor.rpgle qddssrc/hellod.dspf | hellod.file

# Simple COBOL program
tn510l.pgm: qcbllesrc/tn510l.cblle

# COBOL inquiry program
inq01l.pgm: qcbllesrc/inq01l.cblle qddssrc/inq01d.dspf qddssrc/productsp.pf qddssrc/products1l.lf qddssrc/products2l.lf qddssrc/categp.pf qddssrc/prodfeatp.pf qddssrc/featuresp.pf | inq01d.file productsp.file products1l.file products2l.file categp.file prodfeatp.file featuresp.file

# Module and service program
custr.module: qrpglesrc/custr.sqlrpgle qrpglesrc/custr_pr.rpgle qddssrc/custp.pf | custp.file
custr.srvpgm: custr.module qsrvsrc/custr.bnd

# Binding directory
cust.bnddir: cust.bnddir

# Programs with service program and copy member dependencies
wrkcustr.pgm: qrpglesrc/wrkcustr.rpgle qddssrc/wrkcustd.dspf qrpglesrc/custr_pr.rpgle custr.srvpgm | wrkcustd.file cust.bnddir
wrkcust1r.pgm: qrpglesrc/wrkcust1r.rpgle qddssrc/wrkcust1d.dspf qrpglesrc/custr_pr.rpgle custr.srvpgm | wrkcust1d.file cust.bnddir

# RPGOA Programs
wrkcustro.pgm: qrpglesrc/wrkcustro.rpgle qddssrc/wrkcustdo.json qrpglesrc/custr_pr.rpgle custr.srvpgm | wrkcustdo.file cust.bnddir
wrkcust1ro.pgm: qrpglesrc//wrkcust1ro.rpgle qddssrc/wrkcust1do.json qrpglesrc/custr_pr.rpgle custr.srvpgm | wrkcust1do.file cust.bnddir

# EJS Rich Display Files
wrkcusteo.file: qddssrc/wrkcusteo.json
wrkcust1eo.file: qddssrc/wrkcust1eo.json

# EJS RPGOA Programs
wrkcusteo.pgm: qrpglesrc/wrkcusteo.rpgle qddssrc/wrkcusteo.json qrpglesrc/custr_pr.rpgle custr.srvpgm | wrkcusteo.file cust.bnddir
wrkcust1eo.pgm: qrpglesrc/wrkcust1eo.rpgle qddssrc/wrkcust1eo.json qrpglesrc/custr_pr.rpgle custr.srvpgm | wrkcust1eo.file cust.bnddir
