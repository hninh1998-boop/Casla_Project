CLASS zcx_sales_v3 DEFINITION
  PUBLIC
  INHERITING FROM cx_rap_query_provider
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    " Message class ZSALES_V3
    " 001: Bạn không có quyền xem dữ liệu Company Code &1
    CONSTANTS:
      BEGIN OF no_auth_company_code,
        msgid TYPE symsgid VALUE 'ZSALES_V3',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE 'COMPANYCODE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_auth_company_code.

    DATA companycode TYPE bukrs READ-ONLY.

    METHODS constructor
      IMPORTING
        textid      LIKE if_t100_message=>t100key OPTIONAL
        previous    LIKE previous OPTIONAL
        companycode TYPE bukrs OPTIONAL.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcx_sales_v3 IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.

    super->constructor( textid   = textid
                        previous = previous ).

    me->companycode = companycode.

  ENDMETHOD.
ENDCLASS.
