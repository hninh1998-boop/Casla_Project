CLASS zcl_cont_chk DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_CONT_CHK IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
*    SELECT FROM I_OutboundDeliveryTextTP WITH PRIVILEGED ACCESS
*    FIELDS *
*    WHERE OutboundDelivery = '0080000005'
*    INTO TABLE @DATA(lt_chk).

    DATA: lv_outbounddelivery TYPE vbeln VALUE '0080001916'.


    READ ENTITIES OF I_OutboundDeliveryTP FORWARDING PRIVILEGED
      ENTITY OutboundDelivery
      BY \_Text
      ALL FIELDS WITH VALUE #( ( OutboundDelivery = lv_outbounddelivery ) )
      RESULT DATA(lt_text)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    out->write( lt_text ).

    IF ls_failed IS NOT INITIAL.
      out->write( 'FAILED:' ).
      out->write( ls_failed ).
    ENDIF.

    IF ls_reported IS NOT INITIAL.
      out->write( 'REPORTED:' ).
      out->write( ls_reported ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
