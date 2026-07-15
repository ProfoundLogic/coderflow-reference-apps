#include <errno.h>
#include <except.h>
#include <iostream>
#include <qcmdexc.h>
#include <string>

using namespace std;

void except(_INTRPT_Hndlr_Parms_T * __ptr128 info);

int main(int argc, char * argv[]) {

  #pragma exception_handler(except, 0, 0, _C2_MH_ESCAPE, _CTLA_INVOKE)

  if (argc < 6) {
    cerr << "Usage: resave.pgm ORIG_LIB SAVE_LIB SAVE_FILE TGTRLS OWNER" << endl;
    return 1;
  }
  string origLib(argv[1]);
  string saveLib(argv[2]);
  string saveFile(argv[3]);
  string tgtRls(argv[4]);
  string owner(argv[5]);

  // Clear QTEMP.
  string cmd("clrlib lib(qtemp)");
  QCMDEXC((char *) cmd.data(), cmd.length());

  // Restore objects to QTEMP.
  cmd = "rstobj obj(*all) dev(*savf) rstlib(qtemp) savlib(";
  cmd += origLib;
  cmd += ") ";
  cmd += "savf(";
  cmd += saveLib;
  cmd += "/";
  cmd += saveFile;
  cmd += ") ";
  QCMDEXC((char *) cmd.data(), cmd.length());

  // Change ownership of all QTEMP objects.
  cmd = "chgown obj('/qsys.lib/qtemp.lib/*') newown(";
  cmd += owner;
  cmd += ") rvkoldaut(*yes)";
  QCMDEXC((char *) cmd.data(), cmd.length());

  // Resave objects from QTEMP.
  cmd = "clrsavf file(";
  cmd += saveLib;
  cmd += "/";
  cmd += saveFile;
  cmd += ")";
  QCMDEXC((char *) cmd.data(), cmd.length());

  cmd = "savobj obj(*all) lib(qtemp) dev(*savf) objtype(*all) dtacpr(*high) savf(";
  cmd += saveLib;
  cmd += "/";
  cmd += saveFile;
  cmd += ") ";
  cmd += "tgtrls(";
  cmd += tgtRls;
  cmd += ") ";
  QCMDEXC((char *) cmd.data(), cmd.length());

  return 0;

  #pragma disable_handler

}

void except(_INTRPT_Hndlr_Parms_T * __ptr128 info) {

  #pragma exception_handler(except, 0, 0, _C2_MH_ESCAPE, _CTLA_IGNORE_NO_MSG)
  string cmd("dspjoblog job(*) output(*print)");
  QCMDEXC((char *) cmd.data(), cmd.length());
  cerr << "Resave failed" << endl;
  #pragma disable_handler

  exit(1);

}
