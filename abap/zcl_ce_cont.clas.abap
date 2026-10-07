CLASS zcl_ce_cont DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_rap_query_provider .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_CE_CONT IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    "1. Request
    zcl_ce_cont_f01=>requested(
      EXPORTING
        io_request = io_request
      IMPORTING
        et_filters = DATA(lt_filters)
    ).

    "2. Main Processing
    zcl_ce_cont_f01=>main(
      EXPORTING
        it_filters = lt_filters
      IMPORTING
        et_result  = DATA(lt_result)
    ).

    "3. Response
    zcl_ce_cont_f01=>response(
      EXPORTING
        io_request  = io_request
        io_response = io_response
      CHANGING
        ct_result   = lt_result
    ).

  ENDMETHOD.
ENDCLASS.
