CLASS zcl_ce_mapim DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_rap_query_provider .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_CE_MAPIM IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    "1. REQUEST
    zcl_ce_mapim_implement=>requested(
      EXPORTING
        io_request      = io_request
      IMPORTING
        et_filters      = DATA(lt_filters)
    ).
    "2. SELECT
    zcl_ce_mapim_implement=>select(
      EXPORTING
        it_filters      = lt_filters
      IMPORTING
        et_result       = DATA(lt_result)
    ).
    "3. RESPONSE
    zcl_ce_mapim_implement=>response(
      EXPORTING
        io_request  = io_request
        io_response = io_response
      CHANGING
        ct_result   = lt_result
    ).
  ENDMETHOD.
ENDCLASS.
