CLASS zcl_zbom_rp_editmasschange DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: tt_keys     TYPE TABLE FOR ACTION IMPORT zi_zbom_rp\\zbommasschange~editmasschange,
           tt_mapped   TYPE RESPONSE FOR MAPPED EARLY zi_zbom_rp,
           tt_failed   TYPE RESPONSE FOR FAILED EARLY zi_zbom_rp,
           tt_reported TYPE RESPONSE FOR REPORTED EARLY zi_zbom_rp.

    CLASS-METHODS: main
      IMPORTING
        keys     TYPE tt_keys
      CHANGING
        mapped   TYPE tt_mapped
        failed   TYPE tt_failed
        reported TYPE tt_reported.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_ZBOM_RP_EDITMASSCHANGE IMPLEMENTATION.


  METHOD main.

  ENDMETHOD.
ENDCLASS.
