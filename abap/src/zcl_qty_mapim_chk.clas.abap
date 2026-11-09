CLASS zcl_qty_mapim_chk DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_QTY_MAPIM_CHK IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    TYPES: BEGIN OF lty_doc,
             doc      TYPE c LENGTH 10,
             quantity TYPE p LENGTH 9 DECIMALS 3,
           END OF lty_doc.

    TYPES: BEGIN OF lty_merged,
             doc1 TYPE c LENGTH 10,
             qty1 TYPE p LENGTH 9 DECIMALS 3,   "Original qty của doc1
             doc2 TYPE c LENGTH 10,
             qty2 TYPE p LENGTH 9 DECIMALS 3,   "Allocated qty cho cặp này
           END OF lty_merged.

    DATA: lt_itab1  TYPE STANDARD TABLE OF lty_doc WITH EMPTY KEY,
          lt_itab2  TYPE STANDARD TABLE OF lty_doc WITH EMPTY KEY,
          lt_merged TYPE STANDARD TABLE OF lty_merged WITH EMPTY KEY.

    "--- Sample data Case 1 ---
    lt_itab1 = VALUE #( ( doc = 'Doc1' quantity = 500 )
                        ( doc = 'Doc2' quantity = 400 ) ).
    lt_itab2 = VALUE #( ( doc = 'DocA' quantity = 600 )
                        ( doc = 'DocB' quantity = 100 )
                        ( doc = 'DocC' quantity = 50  ) ).
*    lt_itab2 = VALUE #( ( doc = 'DocA' quantity = 300 )
*                        ( doc = 'DocB' quantity = 100 )
*                        ( doc = 'DocC' quantity = 200  ) ).


    "=== FIFO matching: two-pointer ===
    DATA: lv_i    TYPE i VALUE 1,
          lv_j    TYPE i VALUE 1,
          lv_rem1 TYPE p LENGTH 9 DECIMALS 3,
          lv_rem2 TYPE p LENGTH 9 DECIMALS 3,
          lv_qty  TYPE p LENGTH 9 DECIMALS 3.

    FIELD-SYMBOLS: <lfs1> TYPE lty_doc,
                   <lfs2> TYPE lty_doc.

    READ TABLE lt_itab1 INDEX lv_i ASSIGNING <lfs1>.
    IF sy-subrc = 0. lv_rem1 = <lfs1>-quantity. ENDIF.

    READ TABLE lt_itab2 INDEX lv_j ASSIGNING <lfs2>.
    IF sy-subrc = 0. lv_rem2 = <lfs2>-quantity. ENDIF.

    WHILE lv_i <= lines( lt_itab1 ) AND lv_j <= lines( lt_itab2 ).

      "Allocated qty = min(remaining1, remaining2)
      lv_qty = COND #( WHEN lv_rem1 < lv_rem2 THEN lv_rem1 ELSE lv_rem2 ).

      APPEND VALUE #( doc1 = <lfs1>-doc
                      qty1 = <lfs1>-quantity
                      doc2 = <lfs2>-doc
                      qty2 = lv_qty ) TO lt_merged.

      lv_rem1 = lv_rem1 - lv_qty.
      lv_rem2 = lv_rem2 - lv_qty.

      "Doc1 hết --> chuyển sang doc1 kế tiếp
      IF lv_rem1 = 0.
        lv_i = lv_i + 1.
        READ TABLE lt_itab1 INDEX lv_i ASSIGNING <lfs1>.
        IF sy-subrc = 0. lv_rem1 = <lfs1>-quantity. ENDIF.
      ENDIF.

      "Doc2 hết --> chuyển sang doc2 kế tiếp
      IF lv_rem2 = 0.
        lv_j = lv_j + 1.
        READ TABLE lt_itab2 INDEX lv_j ASSIGNING <lfs2>.
        IF sy-subrc = 0. lv_rem2 = <lfs2>-quantity. ENDIF.
      ENDIF.

    ENDWHILE.

    CHECK 1 = 1.
  ENDMETHOD.
ENDCLASS.
