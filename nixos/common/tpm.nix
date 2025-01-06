{
  security.tpm2.enable = true;
  security.tpm2.pkcs11.enable = true; # expose /run/current-system/sw/lib/libtpm2_pkcs11.so
  security.tpm2.tctiEnvironment.enable = true; # TPM2TOOLS_TCTI and TPM2_PKCS11_TCTI env variables
  #users.users.YOUR_USER.extraGroups = [ "tss" ]; # tss group has access to TPM devices

  services.udev.extraRules = ''
    KERNEL=="uhid", SUBSYSTEM=="misc", GROUP="uhid", MODE="0660"
  '';
  #users.users.YOUR_USER.extraGroups = [ "uhid" ]; # uhid group has access to UHID device
}
