CLASS zcl_ce_mapim_implement DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_keys,
             pono                          TYPE i_purchaseorderhistoryapi01-purchaseorder,
             poitem                        TYPE i_purchaseorderhistoryapi01-purchaseorderitem,
             matdoc                        TYPE i_purchaseorderhistoryapi01-purchasinghistorydocument,
             matdocitem                    TYPE i_purchaseorderhistoryapi01-purchasinghistorydocumentitem,
             inv                           TYPE i_purchaseorderhistoryapi01-purchasinghistorydocument,
             invitem                       TYPE i_purchaseorderhistoryapi01-purchasinghistorydocumentitem,
             fiscalyear                    TYPE i_purchaseorderhistoryapi01-purchasinghistorydocumentyear,
             grfiscalyear                  TYPE i_purchaseorderhistoryapi01-purchasinghistorydocumentyear,
             invfiscalyear                 TYPE i_purchaseorderhistoryapi01-purchasinghistorydocumentyear,

             grcategory                    TYPE i_purchaseorderhistoryapi01-purchasinghistorycategory,
             ivcategory                    TYPE i_purchaseorderhistoryapi01-purchasinghistorycategory,

             " Key join
             accountassignmentnumber       TYPE i_purchaseorderhistoryapi01-accountassignmentnumber,
             purchasinghistorydocumenttype TYPE i_purchaseorderhistoryapi01-purchasinghistorydocumenttype,
             purchasinghistorydocument     TYPE i_purchaseorderhistoryapi01-purchasinghistorydocument,
             purchasinghistorydocumentitem TYPE i_purchaseorderhistoryapi01-purchasinghistorydocumentitem,
             purchasinghistorycategory     TYPE i_purchaseorderhistoryapi01-purchasinghistorycategory,

             " Quantity fields
             totalqty                      TYPE i_purchaseorderhistoryapi01-quantity,
             grqty                         TYPE i_purchaseorderhistoryapi01-quantity,
             invoiceqty                    TYPE i_purchaseorderhistoryapi01-quantity,
             allocatedqty                  TYPE i_purchaseorderhistoryapi01-quantity,
             gropenqty                     TYPE i_purchaseorderhistoryapi01-quantity,
             invopenqty                    TYPE i_purchaseorderhistoryapi01-quantity,

             referencedocument             TYPE i_purchaseorderhistoryapi01-referencedocument,
             referencedocumentitem         TYPE i_purchaseorderhistoryapi01-referencedocumentitem,

             "<<< POTYPE: carry NetAmount + PO Type theo từng dòng
             netamount                     TYPE i_purchaseorderitemapi01-netamount,
             purchaseordertype             TYPE i_purchaseorderapi01-purchaseordertype,
           END OF ty_keys,
           tt_keys TYPE STANDARD TABLE OF ty_keys WITH EMPTY KEY.

    TYPES: tt_result TYPE STANDARD TABLE OF zce_mapim,
           ry_string TYPE RANGE OF string.



    CLASS-METHODS requested
      IMPORTING
        io_request TYPE REF TO if_rap_query_request
      EXPORTING
        et_filters TYPE if_rap_query_filter=>tt_name_range_pairs.

    CLASS-METHODS response
      IMPORTING
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response
      CHANGING
        ct_result   TYPE tt_result.

    CLASS-METHODS select
      IMPORTING
        it_filters TYPE if_rap_query_filter=>tt_name_range_pairs
      EXPORTING
        et_result  TYPE tt_result.
  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS format_number
      IMPORTING iv_value         TYPE any
      RETURNING VALUE(rv_result) TYPE string.
ENDCLASS.



CLASS ZCL_CE_MAPIM_IMPLEMENT IMPLEMENTATION.


  METHOD select.
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Get Params
    LOOP AT it_filters INTO DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'COMPANYCODE'.
          DATA(lr_COMPANYCODE) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'POSUPPLIER'.
          DATA(lr_POSUPPLIER) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'PONO'.
          DATA(lr_PONO) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'POITEM'.
          DATA(lr_POITEM) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'MATERIALCODE'.
          DATA(lr_MATERIALCODE) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'MATDOC'.
          DATA(lr_MATDOC) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'MATDOCITEM'.
          DATA(lr_MATDOCITEM) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'FISCALYEAR'.
          DATA(lr_FISCALYEAR) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'GRPOSTINGDATE'.
          DATA(lr_GRPOSTINGDATE) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'JE'.
          DATA(lr_JE) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'INV'.
          DATA(lr_INV) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'INVITEM'.
          DATA(lr_INVITEM) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'INVOICEPOSTINGDATE'.
          DATA(lr_INVOICEPOSTINGDATE) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'PLANT'.
          DATA(lr_PLANT) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'GRFULLYINVOICED'.
          DATA(lr_GRFULLYINVOICED) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'GRBASEDINV'.
          DATA(lr_GRBASEDINV) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'IVFULLYINVOICED'.
          DATA(lr_IVFULLYINVOICED) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'POFULLYINVOICED'.
          DATA(lr_POIVFULLYINVOICED) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'INVOICENO'.
          DATA(lr_INVOICENO) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'INVOICINGPARTY'.
          DATA(lr_INVOICINGPARTY) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'POTYPE'.
          DATA(lr_POTYPE) = CORRESPONDING ry_string( ls_filter-range ).
        WHEN 'STORAGELOCATION'.
          DATA(lr_STORAGELOCATION) = CORRESPONDING ry_string( ls_filter-range ).
      ENDCASE.
    ENDLOOP.

    "Modify param filter
    "Filter keys:
    "   lr_PONO
    "   lr_POITEM
    "   lr_COMPANYCODE
    "   lr_FISCALYEAR
    "Logic:
    "   Từ số MatDoc (và các field liên quan) mà user điền trên param
    "   --> tìm ngược lại để lấy được PO và PO Item
    "   --> Dùng số PO và PO Item này trong filter của câu select keys raw
    DATA: lr_pono_get_filter   TYPE RANGE OF ebeln.

    IF lr_matdoc IS NOT INITIAL OR lr_matdocitem IS NOT INITIAL OR lr_grpostingdate IS NOT INITIAL
    OR lr_inv IS NOT INITIAL OR lr_invitem IS NOT INITIAL OR lr_invoicepostingdate IS NOT INITIAL
    OR lr_fiscalyear IS NOT INITIAL. "<<< FY-FIX 1: year cũng dùng để tìm PO
      "Step 1: Get PO Filter
      "  - FiscalYear filter ở đây bắt mọi record (GR hoặc Inv) phát sinh trong năm đó
      "    --> từ đó suy ra PO --> raw lấy lại all chứng từ của PO (kể cả năm khác)
      "PERF - 05.11.2026: chỉ lấy DISTINCT PO (CompanyCode/FiscalYear không dùng) --> giảm data trả về
      SELECT FROM i_purchaseorderhistoryapi01 AS a
      LEFT JOIN I_PurchaseOrderAPI01 AS b
        ON b~PurchaseOrder = a~PurchaseOrder
      FIELDS DISTINCT
          a~PurchaseOrder AS pono
      WHERE
        a~PurchaseOrder IN @lr_pono
        AND a~PurchaseOrderItem IN @lr_poitem
        AND b~CompanyCode IN @lr_companycode
        AND a~PurchasingHistoryDocumentYear IN @lr_fiscalyear

        AND a~PurchasingHistoryDocument IN @lr_matdoc
        AND a~PurchasingHistoryDocumentItem IN @lr_matdocitem
        AND a~PostingDate IN @lr_grpostingdate

        AND a~PurchasingHistoryDocument IN @lr_inv
        AND a~PurchasingHistoryDocumentItem IN @lr_invitem
        AND a~PostingDate IN @lr_invoicepostingdate
      INTO TABLE @DATA(lt_po_get_filter).

      "Step 2: Append lt into lr PO --> tìm được PO và POItem cho filter của select keys raw
      lr_pono_get_filter = VALUE #( FOR ls_po_get_filter IN lt_po_get_filter
                                    ( sign = 'I' option = 'EQ' low = ls_po_get_filter-pono ) ).
    ENDIF.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Select
    DATA: lt_keys TYPE tt_keys.

    "1. Get keys raw
    SELECT FROM i_purchaseorderhistoryapi01 AS a
    LEFT JOIN I_PurchaseOrderAPI01 AS b
        ON b~PurchaseOrder = a~PurchaseOrder
    LEFT JOIN I_PurchaseOrderItemAPI01 AS c          "<<< POTYPE
        ON c~PurchaseOrder = a~PurchaseOrder
        AND c~PurchaseOrderItem = a~PurchaseOrderItem
    FIELDS
        a~purchaseorder AS PONo,
        a~PurchaseOrderItem AS POItem,
        CASE
            WHEN ( a~purchasinghistorycategory = 'E'
                    AND a~goodsmovementtype IN ('101','161','122') ) OR
                 a~purchasinghistorycategory = 'K'              THEN a~PurchasingHistoryDocument
            WHEN a~purchasinghistorycategory IN ('Q','N')       THEN a~ReferenceDocument
            END AS MatDoc,
        CASE
            WHEN ( a~purchasinghistorycategory = 'E'
                    AND a~goodsmovementtype IN ('101', '161','122') ) OR
                 a~purchasinghistorycategory = 'K'                  THEN a~PurchasingHistoryDocumentItem
            WHEN a~purchasinghistorycategory IN ('Q','N')           THEN a~ReferenceDocumentItem
            END AS MatDocItem,
        CASE
            WHEN a~purchasinghistorycategory IN ('Q','N')   THEN a~PurchasingHistoryDocument
            END AS Inv,
        CASE
            WHEN a~purchasinghistorycategory IN ('Q','N')   THEN a~PurchasingHistoryDocumentItem
            END AS InvItem,

        a~PurchasingHistoryDocumentYear AS FiscalYear,
        "<<< FY-FIX 2: GRFiscalYear cho Q/N có ref = năm chứng từ GR được tham chiếu
        CASE
            WHEN ( a~purchasinghistorycategory = 'E'
                    AND a~goodsmovementtype IN ('101', '161','122') ) OR
                 a~purchasinghistorycategory = 'K'                  THEN a~PurchasingHistoryDocumentYear
            WHEN a~purchasinghistorycategory IN ('Q','N')
                    AND a~ReferenceDocument IS NOT INITIAL          THEN a~ReferenceDocumentFiscalYear
            END AS GRFiscalYear,
        CASE
            WHEN a~purchasinghistorycategory IN ('Q','N')   THEN a~PurchasingHistoryDocumentYear
            END AS InvFiscalYear,

        CASE
            WHEN ( a~purchasinghistorycategory = 'E'
                    AND a~goodsmovementtype IN ('101', '161','122') ) OR
                 a~purchasinghistorycategory = 'K' THEN purchasinghistorycategory
            END AS GRCategory,

        CASE
            WHEN a~purchasinghistorycategory IN ('Q','N')   THEN a~purchasinghistorycategory
            END AS IVCategory,

        "Key join
        a~AccountAssignmentNumber,
        a~PurchasingHistoryDocumentType,
        a~PurchasingHistoryDocument,
        a~PurchasingHistoryDocumentItem,

        a~ReferenceDocument,
        a~ReferenceDocumentItem,
        a~PostingDate,
        a~PurchasingHistoryCategory,

        CASE
            WHEN ( a~DebitCreditCode = 'H' AND a~PurchasingHistoryCategory = 'Q' ) OR
                ( a~purchasinghistorycategory = 'E' AND a~DebitCreditCode = 'H' )
            THEN -1 * a~Quantity
            ELSE a~Quantity
            END AS TotalQty,

        ( a~Quantity - a~Quantity ) AS AllocatedQty,
        ( a~Quantity - a~Quantity ) AS GROpenQty,
        ( a~Quantity - a~Quantity ) AS InvOpenQty,

        b~PurchaseOrderType,    "<<< POTYPE
        c~NetAmount,            "<<< POTYPE

        a~DebitCreditCode
    WHERE
        a~PurchaseOrder IN @lr_pono_get_filter

        AND b~CompanyCode IN @lr_companycode
        AND a~PurchaseOrder IN @lr_pono
        AND a~PurchaseOrderItem IN @lr_poitem

        "<<< POTYPE: filter PO Type (param bắt buộc) + loại ZPO4 có NetAmount item = 0 ngay từ gốc
        AND b~PurchaseOrderType IN @lr_potype
        AND NOT ( b~PurchaseOrderType = 'ZPO4' AND c~NetAmount = 0 )

        "<<< FY-FIX 3: bỏ filter year trực tiếp (year giờ chỉ dùng để tìm PO ở block trên)
*        AND a~PurchasingHistoryDocumentYear IN @lr_fiscalyear

        "Filter MatDoc reversed: I_MaterialDocumentItem_2.ReversedMaterialDocument IS NOT INITIAL
        "Chiều 1: Bản thân là chứng từ hủy
        AND NOT EXISTS (
            SELECT FROM I_MaterialDocumentItem_2 AS mr
            FIELDS mr~MaterialDocument
            WHERE mr~MaterialDocument         = a~PurchasingHistoryDocument
              AND mr~MaterialDocumentItem     = a~PurchasingHistoryDocumentItem
              AND mr~MaterialDocumentYear     = a~PurchasingHistoryDocumentYear
              AND mr~ReversedMaterialDocument IS NOT INITIAL
        )

        "Filter MatDoc reversed: I_MaterialDocumentItem_2.ReversedMaterialDocument IS NOT INITIAL
        "chiều 2: đã bị hủy bởi doc khác
        AND NOT EXISTS (
            SELECT FROM I_MaterialDocumentItem_2 AS mr2
            FIELDS mr2~ReversedMaterialDocument
            WHERE mr2~ReversedMaterialDocument         = a~PurchasingHistoryDocument
              AND mr2~ReversedMaterialDocumentItem     = a~PurchasingHistoryDocumentItem
              AND mr2~ReversedMaterialDocumentYear     = a~PurchasingHistoryDocumentYear
              AND mr2~ReversedMaterialDocument IS NOT INITIAL
        )

        "Filter InvDoc - chiều 1: bản thân là chứng từ hủy (ReverseDocument <> '')
        AND NOT EXISTS (
            SELECT FROM C_SupplierInvoiceItemDEX AS sr1
            FIELDS sr1~SupplierInvoice
            WHERE sr1~SupplierInvoice  = a~PurchasingHistoryDocument
              AND sr1~FiscalYear       = a~PurchasingHistoryDocumentYear
              AND sr1~ReverseDocument <> @space
        )

        "Filter InvDoc - chiều 2: đã bị hủy bởi doc khác (xuất hiện trong cột ReverseDocument)
        AND NOT EXISTS (
            SELECT FROM C_SupplierInvoiceItemDEX AS sr2
            FIELDS sr2~ReverseDocument
            WHERE sr2~ReverseDocument = a~PurchasingHistoryDocument
              AND sr2~FiscalYear      = a~PurchasingHistoryDocumentYear
              AND sr2~ReverseDocument <> @space
        )

*        "Filter dedupe: Ưu tiên Q/N; chỉ giữ E/K khi KHÔNG có Q/N tham chiếu tới
*        AND ( a~purchasinghistorycategory IN ( 'Q', 'N' )
*                OR ( ( ( a~purchasinghistorycategory = 'E'
*                    AND a~goodsmovementtype IN ( '101', '161' ) )
*            OR a~purchasinghistorycategory = 'K' )
*        AND NOT EXISTS (
*            SELECT FROM i_purchaseorderhistoryapi01 AS x
*            FIELDS x~PurchaseOrder
*            WHERE x~PurchaseOrder              = a~PurchaseOrder
*                AND x~PurchaseOrderItem          = a~PurchaseOrderItem
*                AND x~purchasinghistorycategory  IN ( 'Q', 'N' )
*                AND x~ReferenceDocument          = a~PurchasingHistoryDocument
*                AND x~ReferenceDocumentItem      = a~PurchasingHistoryDocumentItem
*                AND x~PurchasingHistoryDocumentYear = a~PurchasingHistoryDocumentYear
*                    )
*                )
*            )

        AND CASE
            WHEN ( a~purchasinghistorycategory = 'E'
                    AND a~goodsmovementtype IN ('101','161','122') ) OR
                a~purchasinghistorycategory = 'K'                  THEN a~PurchasingHistoryDocument
            WHEN a~purchasinghistorycategory IN ('Q','N')           THEN a~ReferenceDocument
            END IN @lr_matdoc
        AND CASE
            WHEN ( a~purchasinghistorycategory = 'E'
                    AND a~goodsmovementtype IN ('101','161','122') ) OR
                a~purchasinghistorycategory = 'K'                  THEN a~PurchasingHistoryDocumentItem
            WHEN a~purchasinghistorycategory IN ('Q','N')           THEN a~ReferenceDocumentItem
            END IN @lr_matdocitem

        AND a~purchasinghistorycategory IN ('E','K','Q','N')
    ORDER BY
        pono,
        poitem
    INTO TABLE @DATA(lt_keys_raw).

    "PERF - 05.11.2026: không có history --> không có kết quả, bỏ qua các bước join/select phía sau
    IF lt_keys_raw IS INITIAL.
      RETURN.
    ENDIF.

    IF lt_keys_raw IS NOT INITIAL.

      " Gom các MatDoc của dòng Q/N để query ngược
      DATA: BEGIN OF ls_grkey,
              matdoc     TYPE i_purchaseorderhistoryapi01-purchasinghistorydocument,
              matdocitem TYPE i_purchaseorderhistoryapi01-purchasinghistorydocumentitem,
              fiscalyear TYPE i_purchaseorderhistoryapi01-purchasinghistorydocumentyear,
            END OF ls_grkey,
            lt_grkeys LIKE TABLE OF ls_grkey.

      LOOP AT lt_keys_raw INTO DATA(ls_row)
        WHERE ( purchasinghistorycategory = 'Q' OR purchasinghistorycategory = 'N' )
        AND matdoc IS NOT INITIAL.
        ls_grkey-matdoc     = ls_row-matdoc.
        ls_grkey-matdocitem = ls_row-matdocitem.
        ls_grkey-fiscalyear = ls_row-grfiscalyear.   "<<< FY-FIX 4: dùng GR year thật (năm GR được ref), không phải năm Inv
        APPEND ls_grkey TO lt_grkeys.
      ENDLOOP.

      SORT lt_grkeys BY matdoc matdocitem fiscalyear.
      DELETE ADJACENT DUPLICATES FROM lt_grkeys COMPARING ALL FIELDS.

      IF lt_grkeys IS NOT INITIAL.

        " Lookup ngược: tìm dòng GR (E 101/161/122 hoặc K) có
        " PurchasingHistoryDocument/Item/Year khớp với MatDoc của Q/N
        SELECT FROM i_purchaseorderhistoryapi01
          FIELDS purchasinghistorydocument     AS matdoc,
                 purchasinghistorydocumentitem AS matdocitem,
                 purchasinghistorydocumentyear AS fiscalyear,
                 purchasinghistorycategory     AS grcategory
          FOR ALL ENTRIES IN @lt_grkeys
          WHERE purchasinghistorydocument     = @lt_grkeys-matdoc
            AND purchasinghistorydocumentitem = @lt_grkeys-matdocitem
            AND purchasinghistorydocumentyear = @lt_grkeys-fiscalyear
            AND ( ( purchasinghistorycategory = 'E'
                    AND goodsmovementtype IN ( '101', '161', '122' ) )
               OR purchasinghistorycategory = 'K' )
          INTO TABLE @DATA(lt_grcat).

        SORT lt_grcat BY matdoc matdocitem fiscalyear.

        " Merge GRCategory vào dòng Q/N của lt_keys_raw
        LOOP AT lt_keys_raw ASSIGNING FIELD-SYMBOL(<fs_row>)
          WHERE ( purchasinghistorycategory = 'Q' OR purchasinghistorycategory = 'N' )
          AND matdoc IS NOT INITIAL.
          READ TABLE lt_grcat
            WITH KEY matdoc     = <fs_row>-matdoc
                     matdocitem = <fs_row>-matdocitem
                     fiscalyear = <fs_row>-grfiscalyear   "<<< FY-FIX 4: match theo GR year thật
            INTO DATA(ls_grcat)
            BINARY SEARCH.
          IF sy-subrc = 0.
            <fs_row>-grcategory = ls_grcat-grcategory.
          ENDIF.
        ENDLOOP.

      ENDIF.

    ENDIF.

    "1.2. Get lt_keys + where những param liên quan MatDoc + Inv Doc (case có RefDoc)
    SELECT FROM @lt_keys_raw AS a
    LEFT JOIN i_purchaseorderhistoryapi01 AS dMatDoc
        ON dMatDoc~PurchaseOrder = a~pono
        AND dMatDoc~PurchaseOrderItem = a~poitem
        AND dMatDoc~PurchasingHistoryDocumentYear = a~GRFiscalYear "NinhNH Udt - add 2 fiscal year - 18.06.2026
        AND dMatDoc~PurchasingHistoryDocument = a~matdoc
        AND dMatDoc~PurchasingHistoryDocumentItem = a~matdocitem
        AND dMatDoc~PurchasingHistoryCategory = a~GRCategory   "← THÊM (E hoặc K theo dòng)
    LEFT JOIN I_PurchaseOrderHistoryAPI01 AS dInv
        ON dInv~PurchaseOrder = a~PONo
        AND dInv~PurchaseOrderItem = a~POItem
        AND dInv~PurchasingHistoryDocumentYear = a~Invfiscalyear "NinhNH Udt - add 2 fiscal year - 18.06.2026
        AND dInv~PurchasingHistoryDocument = a~inv
        AND dInv~PurchasingHistoryDocumentItem = a~invitem
        AND dInv~PurchasingHistoryCategory = a~IVCategory      "← THÊM (Q hoặc N theo dòng)
    FIELDS
        a~PONo,
        a~POItem,
        a~matdoc,
        a~matdocitem,
        a~inv,
        a~invitem,
        a~fiscalyear,
        a~grfiscalyear,
        a~invfiscalyear,

        a~grcategory,
        a~ivcategory,

        "Key join
        a~AccountAssignmentNumber,
        a~PurchasingHistoryDocumentType,
        a~PurchasingHistoryDocument,
        a~PurchasingHistoryDocumentItem,
        a~PurchasingHistoryCategory,

        "Quantity fields
        a~TotalQty,
        CASE
            WHEN a~grcategory = 'K' AND a~DebitCreditCode = 'S'
            THEN -1 * dmatdoc~Quantity
            ELSE dmatdoc~Quantity END AS GRQty,

        CASE
            WHEN ( a~ivcategory = 'N' OR a~ivcategory = 'Q' )
                AND a~DebitCreditCode = 'H'
            THEN -1 * dInv~Quantity
            ELSE dInv~Quantity END AS InvoiceQty,
        "Với những line có reference --> allocated qty = invoice qty
        CASE
            WHEN a~ReferenceDocument IS NOT INITIAL
            THEN (
                CASE
                    WHEN ( a~ivcategory = 'N' OR a~ivcategory = 'Q' )
                        AND a~DebitCreditCode = 'H'
                    THEN -1 * dInv~Quantity
                    ELSE dInv~Quantity END )
            ELSE a~allocatedqty END AS allocatedqty,

        a~gropenqty,
        a~invopenqty,

        a~ReferenceDocument,
        a~ReferenceDocumentItem,

        a~netamount,            "<<< POTYPE
        a~purchaseordertype    "<<< POTYPE
    WHERE
        a~ReferenceDocument IS NOT INITIAL
        AND a~PurchasingHistoryCategory = 'Q'   "← Chỉ Q-có-ref, bỏ E
    INTO TABLE @lt_keys.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Tính toán qty cho case có ref doc
    "Phát sinh các case:
    "   1 GR - 1 IV
    "   1 GR - n IV
    "Logic: lấy GR quantity - tổng allocated quantity
    DATA: lv_invoiceqty       TYPE menge_d,
          lv_index_matdoc_ref TYPE i.

    SORT lt_keys BY pono poitem matdoc matdocitem.

    LOOP AT lt_keys INTO DATA(ls_keys_grp_ref)
        GROUP BY ( pono = ls_keys_grp_ref-pono
                   poitem = ls_keys_grp_ref-poitem
                   matdoc = ls_keys_grp_ref-matdoc
                   matdocitem = ls_keys_grp_ref-matdocitem )
        INTO DATA(lgr_group_key_ref).

      CLEAR: lv_invoiceqty.

      LOOP AT GROUP lgr_group_key_ref INTO DATA(ls_key_ref).
        lv_invoiceqty += ls_key_ref-allocatedqty.
        lv_index_matdoc_ref += 1.
      ENDLOOP.

      READ TABLE lt_keys ASSIGNING FIELD-SYMBOL(<lfs_keys_ref>) INDEX lv_index_matdoc_ref.
      IF sy-subrc = 0.
        <lfs_keys_ref>-gropenqty = <lfs_keys_ref>-grqty - lv_invoiceqty.
      ENDIF.
    ENDLOOP.

    "1.3. Add quantity cho case No GR Based Inv - Invoice không có MatDoc Ref
    "=== FIFO matching: two-pointer ===
    DATA(lt_noref) = lt_keys_raw.
*    DELETE lt_noref WHERE ReferenceDocument IS NOT INITIAL.
*    DELETE lt_noref WHERE PurchasingHistoryCategory = 'K' OR PurchasingHistoryCategory = 'N'.

    "Xóa Q-có-ref (đã xử lý ở Step 1.2, không lặp ở đây)
    DELETE lt_noref WHERE PurchasingHistoryCategory = 'Q' AND ReferenceDocument IS NOT INITIAL.
    DELETE lt_noref WHERE PurchasingHistoryCategory = 'K' OR PurchasingHistoryCategory = 'N'.

    "Xóa các E đã được Q-có-ref tham chiếu (tránh duplicate vì Q-có-ref đã set matdoc ở Step 1.2)
    "→ giữ lại: Q-no-ref + E orphan + E sẽ FIFO với Q-no-ref
    "PERF - 05.11.2026: thay DELETE WHERE lồng trong LOOP (O(n²)) bằng hashed lookup (O(n))
    TYPES: BEGIN OF lty_qref,
             doc  TYPE ty_keys-purchasinghistorydocument,
             item TYPE ty_keys-purchasinghistorydocumentitem,
             year TYPE ty_keys-grfiscalyear,
           END OF lty_qref.
    DATA: lt_qref TYPE HASHED TABLE OF lty_qref WITH UNIQUE KEY doc item year.

    LOOP AT lt_keys_raw ASSIGNING FIELD-SYMBOL(<lfs_q_ref_del>)
      WHERE PurchasingHistoryCategory = 'Q'
        AND ReferenceDocument IS NOT INITIAL.
      INSERT VALUE #( doc  = <lfs_q_ref_del>-ReferenceDocument
                      item = <lfs_q_ref_del>-ReferenceDocumentItem
                      year = <lfs_q_ref_del>-grfiscalyear )   "<<< FY-FIX 5: so khớp E theo năm GR thật (không phải năm Inv)
        INTO TABLE lt_qref.
    ENDLOOP.

    IF lt_qref IS NOT INITIAL.
      LOOP AT lt_noref ASSIGNING FIELD-SYMBOL(<lfs_noref_e>)
        WHERE PurchasingHistoryCategory = 'E'.
        READ TABLE lt_qref TRANSPORTING NO FIELDS
          WITH TABLE KEY doc  = <lfs_noref_e>-PurchasingHistoryDocument
                         item = <lfs_noref_e>-PurchasingHistoryDocumentItem
                         year = <lfs_noref_e>-grfiscalyear.
        IF sy-subrc = 0.
          DELETE lt_noref.
        ENDIF.
      ENDLOOP.
    ENDIF.

    SORT lt_noref BY pono
                     poitem
                     PurchasingHistoryCategory DESCENDING
                     PostingDate
                     PurchasingHistoryDocument
                     PurchasingHistoryDocumentItem
                     PurchasingHistoryCategory.

    "Loop at Group By Logic
    DATA: lt_keys_raw2 LIKE lt_keys.

    DATA: lv_index_q      TYPE i VALUE 1,
          lv_index_e      TYPE i VALUE 1,
          lv_qty_q        TYPE zce_mapim-InvoiceQty,
          lv_qty_e        TYPE zce_mapim-InvoiceQty,
          lv_allocatedqty TYPE zce_mapim-InvoiceQty,
          lt_q            LIKE lt_noref,
          lt_e            LIKE lt_noref,
          lv_total_qty_q  TYPE zce_mapim-InvoiceQty,
          lv_total_qty_e  TYPE zce_mapim-GRQty.

    LOOP AT lt_noref ASSIGNING FIELD-SYMBOL(<lfs_grp_key>)
         GROUP BY ( pono   = <lfs_grp_key>-pono
                    poitem = <lfs_grp_key>-poitem )
         ASSIGNING FIELD-SYMBOL(<lfs_group>).

      CLEAR: lt_q,
             lt_e,
             lv_total_qty_q,
             lv_total_qty_e.

      lv_index_q = 1.
      lv_index_e = 1.

      LOOP AT GROUP <lfs_group> ASSIGNING FIELD-SYMBOL(<lfs_member>).
        CASE <lfs_member>-PurchasingHistoryCategory.
          WHEN 'Q'.
            APPEND <lfs_member> TO lt_q.
            lv_total_qty_q += <lfs_member>-totalqty.
          WHEN 'E'.
            APPEND <lfs_member> TO lt_e.
            lv_total_qty_e += <lfs_member>-totalqty.
        ENDCASE.
      ENDLOOP.

      READ TABLE lt_q INDEX lv_index_q ASSIGNING FIELD-SYMBOL(<lfs_q>).
      IF sy-subrc = 0.
        lv_qty_q = <lfs_q>-TotalQty.
      ENDIF.

      READ TABLE lt_e INDEX lv_index_e ASSIGNING FIELD-SYMBOL(<lfs_e>).
      IF sy-subrc = 0.
        lv_qty_e = <lfs_e>-TotalQty.
      ENDIF.

      "Case 1: Chỉ có Invoice (Q), không có GR (E) → invoice là "open" hoàn toàn
      IF lines( lt_e ) = 0 AND lines( lt_q ) > 0.
        LOOP AT lt_q ASSIGNING <lfs_q>.
          APPEND INITIAL LINE TO lt_keys_raw2 ASSIGNING FIELD-SYMBOL(<lfs_keys_raw2>).
          <lfs_keys_raw2>             = CORRESPONDING #( <lfs_q> ).
          <lfs_keys_raw2>-matdoc      = ''.
          <lfs_keys_raw2>-matdocitem  = ''.
          <lfs_keys_raw2>-inv         = <lfs_q>-inv.
          <lfs_keys_raw2>-invitem     = <lfs_q>-invitem.
          <lfs_keys_raw2>-allocatedqty = 0.
          <lfs_keys_raw2>-grcategory  = ''.
          <lfs_keys_raw2>-ivcategory  = 'Q'.
          <lfs_keys_raw2>-invopenqty  = <lfs_q>-totalqty.
          "grfiscalyear = NULL (chỉ có Inv), invfiscalyear giữ từ CORRESPONDING <lfs_q>
        ENDLOOP.

        "Case 2: Chỉ có GR (E), không có Invoice (Q) → GR là "open" hoàn toàn
      ELSEIF lines( lt_q ) = 0 AND lines( lt_e ) > 0.
        LOOP AT lt_e ASSIGNING <lfs_e>.
          APPEND INITIAL LINE TO lt_keys_raw2 ASSIGNING <lfs_keys_raw2>.
          <lfs_keys_raw2>             = CORRESPONDING #( <lfs_e> ).
          <lfs_keys_raw2>-matdoc      = <lfs_e>-matdoc.
          <lfs_keys_raw2>-matdocitem  = <lfs_e>-matdocitem.
          <lfs_keys_raw2>-inv         = ''.
          <lfs_keys_raw2>-invitem     = ''.
          <lfs_keys_raw2>-allocatedqty = 0.
          <lfs_keys_raw2>-grcategory  = 'E'.
          <lfs_keys_raw2>-ivcategory  = ''.
          <lfs_keys_raw2>-gropenqty  = <lfs_e>-totalqty.
          "grfiscalyear giữ từ CORRESPONDING <lfs_e>, invfiscalyear = NULL
        ENDLOOP.

        "Case 3: Cả 2 đều có → matching FIFO như cũ
      ELSEIF lines( lt_q ) > 0 AND lines( lt_e ) > 0.
        WHILE ( lv_index_q <= lines( lt_q ) AND lv_index_e <= lines( lt_e ) ).

          "Allocated qty = min(remaining1, remaining2)
          lv_allocatedqty = COND #( WHEN lv_qty_q < lv_qty_e
                                    THEN lv_qty_q ELSE lv_qty_e ).

          APPEND INITIAL LINE TO lt_keys_raw2 ASSIGNING <lfs_keys_raw2>.
          <lfs_keys_raw2> = CORRESPONDING #( <lfs_q> ).
          <lfs_keys_raw2>-matdoc = <lfs_e>-matdoc.
          <lfs_keys_raw2>-matdocitem = <lfs_e>-matdocitem.
          <lfs_keys_raw2>-inv = <lfs_q>-inv.
          <lfs_keys_raw2>-invitem = <lfs_q>-invitem.
          <lfs_keys_raw2>-allocatedqty = lv_allocatedqty.

          <lfs_keys_raw2>-grfiscalyear  = <lfs_e>-grfiscalyear.   "<<< FY-FIX 6: GR year lấy từ dòng E (GR), không phải Q
          <lfs_keys_raw2>-invfiscalyear = <lfs_q>-invfiscalyear.  "IV year lấy từ dòng Q

          <lfs_keys_raw2>-grcategory = 'E'.
          <lfs_keys_raw2>-ivcategory = 'Q'.

          lv_qty_q = lv_qty_q - lv_allocatedqty.
          lv_qty_e = lv_qty_e - lv_allocatedqty.

          "Doc1 hết --> chuyển sang doc1 kế tiếp
          IF lv_qty_q = 0.
            lv_index_q = lv_index_q + 1.
            READ TABLE lt_q INDEX lv_index_q ASSIGNING <lfs_q>.
            IF sy-subrc = 0.
              lv_qty_q = <lfs_q>-TotalQty.
            ENDIF.
          ENDIF.

          "Doc2 hết --> chuyển sang doc2 kế tiếp
          IF lv_qty_e = 0.
            lv_index_e = lv_index_e + 1.
            READ TABLE lt_e INDEX lv_index_e ASSIGNING <lfs_e>.
            IF sy-subrc = 0.
              lv_qty_e = <lfs_e>-TotalQty.
            ENDIF.
          ENDIF.
        ENDWHILE.

        "Get Open Quantity
        READ TABLE lt_keys_raw2 ASSIGNING <lfs_keys_raw2> INDEX lines( lt_keys_raw2 ).
        IF sy-subrc = 0.
          IF lv_total_qty_q >= lv_total_qty_e.
            <lfs_keys_raw2>-invopenqty = lv_qty_q.
            LOOP AT lt_q INTO DATA(ls_q) FROM lv_index_q + 1.
              APPEND INITIAL LINE TO lt_keys_raw2 ASSIGNING <lfs_keys_raw2>.
              <lfs_keys_raw2> = CORRESPONDING #( ls_q ).
              <lfs_keys_raw2>-invopenqty = ls_q-totalqty.
            ENDLOOP.
            IF sy-subrc <> 0.
              <lfs_keys_raw2>-gropenqty = lv_qty_e.
              LOOP AT lt_e INTO DATA(ls_e) FROM lv_index_e + 1.
                APPEND INITIAL LINE TO lt_keys_raw2 ASSIGNING <lfs_keys_raw2>.
                <lfs_keys_raw2> = CORRESPONDING #( ls_e ).
                <lfs_keys_raw2>-gropenqty = ls_e-totalqty.
              ENDLOOP.
            ENDIF.
          ELSE.
            <lfs_keys_raw2>-gropenqty = lv_qty_e.
            LOOP AT lt_e INTO ls_e FROM lv_index_e + 1.
              APPEND INITIAL LINE TO lt_keys_raw2 ASSIGNING <lfs_keys_raw2>.
              <lfs_keys_raw2> = CORRESPONDING #( ls_e ).
              <lfs_keys_raw2>-gropenqty = ls_e-totalqty.
            ENDLOOP.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.

    "1.4. Append Raws to Main Keys (4 types: E, Q, K, N)
    "lt_keys_raw2 --> chỉ có E, Q (case No Ref)
    "lt_keys --> hiện tại chỉ có E, Q (case có Ref)
    APPEND LINES OF lt_keys_raw2 TO lt_keys.

    "2.1. Phân biệt K, N
    "lt_key hiện tại chỉ đang có E, Q
    DATA: lt_kn LIKE lt_keys.
    lt_kn = CORRESPONDING #( lt_keys_raw ).
    DELETE lt_kn WHERE PurchasingHistoryCategory = 'E' OR PurchasingHistoryCategory = 'Q'.

    DATA(lt_keys_full) = lt_keys.
    APPEND LINES OF lt_kn TO lt_keys_full.

    SELECT FROM @lt_keys_full AS a
    LEFT JOIN I_PurchaseOrderAPI01 AS b
        ON b~PurchaseOrder = a~pono
    LEFT JOIN I_PurchaseOrderItemAPI01 AS c
        ON c~PurchaseOrder = a~PONo
        AND c~PurchaseOrderItem = a~POItem

    LEFT JOIN i_purchaseorderhistoryapi01 AS d
        ON d~PurchaseOrder = a~pono
        AND d~PurchaseOrderItem = a~poitem
        AND d~AccountAssignmentNumber = a~AccountAssignmentNumber
        AND d~PurchasingHistoryDocumentType = a~PurchasingHistoryDocumentType
        AND d~PurchasingHistoryDocumentYear = a~FiscalYear
        AND d~PurchasingHistoryDocument = a~PurchasingHistoryDocument
        AND d~PurchasingHistoryDocumentItem = a~PurchasingHistoryDocumentItem
    LEFT JOIN i_purchaseorderhistoryapi01 AS dMatDoc
        ON dMatDoc~PurchaseOrder = a~pono
        AND dMatDoc~PurchaseOrderItem = a~poitem
        AND dMatDoc~PurchasingHistoryDocumentYear = a~GRFiscalYear "NinhNH Udt - add 2 fiscal year - 18.06.2026
        AND dMatDoc~PurchasingHistoryDocument = a~matdoc
        AND dMatDoc~PurchasingHistoryDocumentItem = a~matdocitem
        AND dMatDoc~PurchasingHistoryCategory = a~GRCategory   "← THÊM (E hoặc K theo dòng)
    LEFT JOIN i_purchaseorderhistoryapi01 AS dInv
        ON dInv~PurchaseOrder = a~pono
        AND dInv~PurchaseOrderItem = a~poitem
        AND dInv~PurchasingHistoryDocumentYear = a~InvFiscalYear "NinhNH Udt - add 2 fiscal year - 18.06.2026
        AND dInv~PurchasingHistoryDocument = a~Inv
        AND dInv~PurchasingHistoryDocumentItem = a~InvItem
        AND dInv~PurchasingHistoryCategory = a~IVCategory      "← THÊM (Q hoặc N theo dòng)

    LEFT JOIN I_JournalEntry AS e
        ON e~FiscalYear = a~fiscalyear
        AND e~AccountingDocumentType = 'RE'
        AND substring( e~OriginalReferenceDocument, 1, 10 ) = a~inv
        AND e~CompanyCode = c~CompanyCode
    LEFT JOIN C_SupplierInvoiceDEX AS f
        ON f~SupplierInvoice = a~PurchasingHistoryDocument
        AND f~FiscalYear = a~fiscalyear
        AND f~companycode = b~CompanyCode
    LEFT JOIN i_materialdocumentitem_2 AS g
        ON g~MaterialDocumentYear = a~grfiscalyear "Dev/NinhNH/ZMapIM - FS v2 - 04.11.2026: join đủ key Mat doc
        AND g~MaterialDocument = a~matdoc
        AND g~MaterialDocumentItem = a~matdocitem
    FIELDS
        a~*
    WHERE
        b~Supplier IN @lr_posupplier
        AND d~Material IN @lr_materialcode
        AND dMatDoc~PurchasingHistoryDocument IN @lr_matdoc
        AND dMatDoc~PurchasingHistoryDocumentItem IN @lr_matdocitem
        AND dmatdoc~PostingDate IN @lr_grpostingdate
        AND e~AccountingDocument IN @lr_je
        AND dInv~PurchasingHistoryDocument IN @lr_inv
        AND dInv~PurchasingHistoryDocumentItem IN @lr_invitem
        AND dInv~PostingDate IN @lr_invoicepostingdate
        AND d~Plant IN @lr_plant
        AND f~SupplierInvoiceIDByInvcgParty IN @lr_invoiceno
        AND f~invoicingparty IN @lr_INVOICINGPARTY
        AND g~StorageLocation IN @lr_storagelocation

        AND ( a~grfiscalyear IN @lr_fiscalyear OR a~invfiscalyear IN @lr_fiscalyear )
    INTO TABLE @lt_keys_full.

    "PERF - 05.11.2026: filter loại hết --> dừng
    "(tránh FOR ALL ENTRIES với bảng rỗng ở bước Ghi chú = đọc toàn bộ note PO)
    IF lt_keys_full IS INITIAL.
      RETURN.
    ENDIF.

    "2.2. Get bases - E, Q, K, N
    SELECT FROM @lt_keys_full AS a
    LEFT JOIN I_PurchaseOrderAPI01 AS b
        ON b~PurchaseOrder = a~PONo
    LEFT JOIN I_PurchaseOrderItemAPI01 AS c
        ON c~PurchaseOrder = a~PONo
        AND c~PurchaseOrderItem = a~POItem

    LEFT JOIN i_purchaseorderhistoryapi01 AS d
        ON d~PurchaseOrder = a~pono
        AND d~PurchaseOrderItem = a~poitem
        AND d~AccountAssignmentNumber = a~AccountAssignmentNumber
        AND d~PurchasingHistoryDocumentType = a~PurchasingHistoryDocumentType
        AND d~PurchasingHistoryDocumentYear = a~FiscalYear
        AND d~PurchasingHistoryDocument = a~PurchasingHistoryDocument
        AND d~PurchasingHistoryDocumentItem = a~PurchasingHistoryDocumentItem
    LEFT JOIN i_purchaseorderhistoryapi01 AS dMatDoc
        ON dMatDoc~PurchaseOrder = a~pono
        AND dMatDoc~PurchaseOrderItem = a~poitem
        AND dMatDoc~PurchasingHistoryDocumentYear = a~GRFiscalYear   "<<< FY-FIX 7: year theo GRFiscalYear
        AND dMatDoc~PurchasingHistoryDocument = a~matdoc
        AND dMatDoc~PurchasingHistoryDocumentItem = a~matdocitem
        AND dMatDoc~PurchasingHistoryCategory = a~GRCategory   "← THÊM (E hoặc K theo dòng)
    LEFT JOIN I_PurchaseOrderHistoryAPI01 AS dInv
        ON dInv~PurchaseOrder = a~PONo
        AND dInv~PurchaseOrderItem = a~POItem
        AND dInv~PurchasingHistoryDocumentYear = a~InvFiscalYear     "<<< FY-FIX 7: year theo InvFiscalYear
        AND dInv~PurchasingHistoryDocument = a~inv
        AND dInv~PurchasingHistoryDocumentItem = a~invitem
        AND dInv~PurchasingHistoryCategory = a~IVCategory      "← THÊM (Q hoặc N theo dòng)

    LEFT JOIN I_JournalEntry AS e
        ON e~FiscalYear = a~fiscalyear
        AND e~AccountingDocumentType = 'RE'
        AND substring( e~OriginalReferenceDocument, 1, 10 ) = a~inv
        AND e~CompanyCode = b~CompanyCode
    LEFT JOIN C_SupplierInvoiceDEX AS f
        ON f~SupplierInvoice = a~PurchasingHistoryDocument
        AND f~FiscalYear = a~fiscalyear
        AND f~companycode = b~CompanyCode
    LEFT JOIN i_materialdocumentitem_2 AS g
        ON g~MaterialDocumentYear = a~grfiscalyear "Dev/NinhNH/ZMapIM - FS v2 - 04.11.2026: join đủ key Mat doc
        AND g~MaterialDocument = a~matdoc
        AND g~MaterialDocumentItem = a~matdocitem

    LEFT JOIN I_MaterialDocumentHeader_2 AS h
        ON h~MaterialDocumentYear = a~grfiscalyear
        AND h~MaterialDocument = a~MatDoc

    FIELDS
        "Key fields
        a~PONo,
        a~POItem,
        a~matdoc,
        a~matdocitem,
        a~inv,
        a~invitem,
        a~fiscalyear,

        "NinhNH Udt - add 2 fiscal year - 18.06.2026
        a~grfiscalyear,
        a~invfiscalyear,
        "End of NinhNH Udt - add 2 fiscal year - 18.06.2026

        a~grcategory,
        a~ivcategory,

        "Base fields
        b~CompanyCode,
        b~Supplier AS POSupplier,
        c~invoiceisgoodsreceiptbased,
        d~Material AS MaterialCode,
        c~PurchaseOrderItemText AS MaterialDescription,
        d~OrderPriceUnit,
        d~DeliveryDocument AS DeliveryDoc,
        d~DeliveryDocumentItem AS DeliveryItem,
        dmatdoc~PostingDate AS GRPostingDate,
        CASE
            WHEN ( a~grcategory = 'K' AND d~DebitCreditCode = 'S' ) OR
                ( a~grcategory = 'E' AND d~DebitCreditCode = 'H' )
            THEN -1 * dmatdoc~Quantity
            ELSE dmatdoc~Quantity END AS GRQty,

        CASE
            WHEN ( a~ivcategory = 'N' OR a~ivcategory = 'Q' )
                AND d~DebitCreditCode = 'H'
            THEN -1 * dInv~Quantity
            ELSE dInv~Quantity END AS InvoiceQty,

        a~allocatedqty,
        d~Currency AS TransCur,

        CASE
            WHEN ( a~grcategory = 'K' AND d~DebitCreditCode = 'S' ) OR
                ( a~grcategory = 'E' AND d~DebitCreditCode = 'H' )
            THEN -1 * dmatdoc~purordamountincompanycodecrcy
            ELSE dmatdoc~purordamountincompanycodecrcy END AS GRAmountComCode,

        CASE
            WHEN ( a~grcategory = 'K' AND d~DebitCreditCode = 'S' ) OR
                ( a~grcategory = 'E' AND d~DebitCreditCode = 'H' )
            THEN -1 * dmatdoc~purchaseorderamount
            ELSE dmatdoc~purchaseorderamount END AS GRAmountTransCode,

        e~AccountingDocument AS je,
        f~SupplierInvoiceIDByInvcgParty AS InvoiceNo,
        dInv~PostingDate AS InvoicePostingDate,

        CASE
            WHEN ( a~ivcategory = 'N' OR a~ivcategory = 'Q' )
                AND d~DebitCreditCode = 'H'
            THEN -1 * dInv~purordamountincompanycodecrcy
            ELSE dInv~purordamountincompanycodecrcy END AS InvoiceAmountComCode,

        CASE
            WHEN ( a~ivcategory = 'N' OR a~ivcategory = 'Q' )
                AND d~DebitCreditCode = 'H'
            THEN -1 * dInv~purchaseorderamount
            ELSE dInv~purchaseorderamount END AS InvoiceAmountTrans,

        dInv~Currency AS Currency,
        f~invoicingparty,

        d~ReferenceDocument,
        d~ReferenceDocumentItem,
        d~ReferenceDocumentFiscalYear,

        d~DebitCreditCode,
        d~Plant,

        "Dev/NinhNH/ZMapIM/Add 3 fields PO + INV Net Price + Sloc - v6
        CASE WHEN c~NetPriceQuantity <> 0
             THEN division( c~NetPriceAmount, c~NetPriceQuantity, 2 )
             ELSE 0
        END AS PONetprice,
        c~DocumentCurrency AS POCurrency,
        g~StorageLocation,
        g~\_StorageLocation-StorageLocationName,

        g~MaterialDocumentItemText AS ItemText,
        h~MaterialDocumentHeaderText AS HeaderText,

        "Dev/NinhNH/ZMapIM/Add Batch + Valuation type - FS v2 - 04.11.2026
        "GR fiscal year (13) + Mat doc (11) + Mat doc item (11.1) -> I_MaterialDocumentItem_2
        g~Batch,
        g~InventoryValuationType AS ValuationType
    INTO TABLE @DATA(lt_bases).

    "3.1 + 3.2. Get BP Text (PO Supplier + Invoicing Party)
    "PERF - 05.11.2026: trước đây select 2 lần, mỗi lần 1 dòng / 1 dòng lt_bases (trùng BP rất nhiều)
    "--> gom BP distinct, select 1 lần, tính sẵn tên vào bảng hashed
    TYPES: BEGIN OF lty_bp_name,
             bp   TYPE i_businesspartner-businesspartner,
             name TYPE string,
           END OF lty_bp_name.
    DATA: lt_bp      TYPE SORTED TABLE OF i_businesspartner-businesspartner WITH UNIQUE KEY table_line,
          lt_bp_name TYPE HASHED TABLE OF lty_bp_name WITH UNIQUE KEY bp.

    LOOP AT lt_bases ASSIGNING FIELD-SYMBOL(<lfs_base_bp>).
      IF <lfs_base_bp>-POSupplier IS NOT INITIAL.
        INSERT CONV #( <lfs_base_bp>-POSupplier ) INTO TABLE lt_bp.
      ENDIF.
      IF <lfs_base_bp>-InvoicingParty IS NOT INITIAL.
        INSERT CONV #( <lfs_base_bp>-InvoicingParty ) INTO TABLE lt_bp.
      ENDIF.
    ENDLOOP.

    IF lt_bp IS NOT INITIAL.
      SELECT FROM I_BusinessPartner
      FIELDS
          BusinessPartner,
          OrganizationBPName1,
          OrganizationBPName2,
          OrganizationBPName3,
          OrganizationBPName4,
          LastName
      FOR ALL ENTRIES IN @lt_bp
      WHERE BusinessPartner = @lt_bp-table_line
      INTO TABLE @DATA(lt_bp_text).

      LOOP AT lt_bp_text ASSIGNING FIELD-SYMBOL(<lfs_bp_text>).
        INSERT VALUE #(
          bp   = <lfs_bp_text>-BusinessPartner
          name = COND #(
                   WHEN <lfs_bp_text>-OrganizationBPName2 IS NOT INITIAL OR
                        <lfs_bp_text>-OrganizationBPName3 IS NOT INITIAL OR
                        <lfs_bp_text>-OrganizationBPName4 IS NOT INITIAL
                   THEN |{ <lfs_bp_text>-OrganizationBPName2 }|
                     && |{ <lfs_bp_text>-OrganizationBPName3 }|
                     && |{ <lfs_bp_text>-OrganizationBPName4 }|
                   WHEN <lfs_bp_text>-OrganizationBPName1 IS NOT INITIAL
                   THEN <lfs_bp_text>-OrganizationBPName1
                   ELSE <lfs_bp_text>-LastName ) )
          INTO TABLE lt_bp_name.
      ENDLOOP.
    ENDIF.

    "4. Pre-compute tính tổng PO Fully Invoiced
    "--> total_gr: tính theo MatDoc Category = E
    "--> total_iv: tính theo Inv Category    = Q
    TYPES: BEGIN OF lty_po_fullyqty,
             pono        TYPE zce_mapim-pono,
             poitem      TYPE zce_mapim-poitem,
             total_gr    TYPE zce_mapim-allocatedqty,
             total_iv    TYPE zce_mapim-allocatedqty,
             total_count TYPE i,
           END OF lty_po_fullyqty.
    "PERF - 05.11.2026: hashed theo PO/PO item (trước là standard + READ tuyến tính)
    DATA: lt_po_fullyqty TYPE HASHED TABLE OF lty_po_fullyqty WITH UNIQUE KEY pono poitem.
    DATA: lv_total_gr    TYPE zce_mapim-allocatedqty.
    DATA: lv_total_iv    TYPE zce_mapim-allocatedqty.

    "Get GR for PO Fully - lấy E à K (lấy hết, trừ những line trống)
    DATA(lt_po_gr) = lt_bases.
    DELETE lt_po_gr WHERE grcategory IS INITIAL.
    SORT lt_po_gr BY pono poitem matdoc matdocitem.
    DELETE ADJACENT DUPLICATES FROM lt_po_gr COMPARING pono poitem matdoc matdocitem.

    LOOP AT lt_po_gr ASSIGNING FIELD-SYMBOL(<lfs_base_gr_grp>)
         GROUP BY ( pono   = <lfs_base_gr_grp>-pono
                    poitem = <lfs_base_gr_grp>-poitem )
         ASSIGNING FIELD-SYMBOL(<lfs_group_base_gr>).

      CLEAR lv_total_gr.
      LOOP AT GROUP <lfs_group_base_gr> ASSIGNING FIELD-SYMBOL(<lfs_mem_gr>).
        lv_total_gr += <lfs_mem_gr>-grqty.
      ENDLOOP.

      INSERT VALUE #( pono     = <lfs_group_base_gr>-pono
                      poitem   = <lfs_group_base_gr>-poitem
                      total_gr = lv_total_gr ) INTO TABLE lt_po_fullyqty.
    ENDLOOP.

    "Get IV for PO Fully - chỉ lấy Q
    DATA(lt_po_iv) = lt_bases.
    DELETE lt_po_iv WHERE ivcategory <> 'Q'.
    SORT lt_po_iv BY pono poitem inv invitem.
    DELETE ADJACENT DUPLICATES FROM lt_po_iv COMPARING pono poitem inv invitem.

    LOOP AT lt_po_iv ASSIGNING FIELD-SYMBOL(<lfs_base_iv_grp>)
         GROUP BY ( pono   = <lfs_base_iv_grp>-pono
                    poitem = <lfs_base_iv_grp>-poitem )
         ASSIGNING FIELD-SYMBOL(<lfs_group_base_iv>).

      CLEAR lv_total_iv.
      LOOP AT GROUP <lfs_group_base_iv> ASSIGNING FIELD-SYMBOL(<lfs_mem_iv>).
        lv_total_iv += <lfs_mem_iv>-invoiceqty.
      ENDLOOP.

      READ TABLE lt_po_fullyqty ASSIGNING FIELD-SYMBOL(<lfs_po_fullyqty>)
        WITH TABLE KEY pono   = <lfs_group_base_iv>-pono
                       poitem = <lfs_group_base_iv>-poitem.
      IF sy-subrc = 0.
        <lfs_po_fullyqty>-total_iv = lv_total_iv.
      ELSE.
        INSERT VALUE #( pono     = <lfs_group_base_iv>-pono
                        poitem   = <lfs_group_base_iv>-poitem
                        total_iv = lv_total_iv ) INTO TABLE lt_po_fullyqty.
      ENDIF.
    ENDLOOP.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "5.3. Tìm IV Fully Invoice của group by pono poitem inv invitem
    TYPES: BEGIN OF lty_ivfully,
             pono      TYPE zce_mapim-pono,
             poitem    TYPE zce_mapim-poitem,
             inv       TYPE zce_mapim-inv,
             invitem   TYPE zce_mapim-invitem,
             isopeninv TYPE abap_boolean,
           END OF lty_ivfully.
    DATA: lt_ivfully TYPE HASHED TABLE OF lty_ivfully WITH UNIQUE KEY pono poitem inv invitem. "PERF - 05.11.2026

    LOOP AT lt_keys_full INTO DATA(ls_grp_keys_iv)
        GROUP BY ( pono = ls_grp_keys_iv-pono
                   poitem = ls_grp_keys_iv-poitem
                   inv = ls_grp_keys_iv-inv
                   invitem = ls_grp_keys_iv-invitem )
       INTO DATA(lgr_keys_iv).

      INSERT VALUE #( pono    = lgr_keys_iv-pono
                      poitem  = lgr_keys_iv-poitem
                      inv     = lgr_keys_iv-inv
                      invitem = lgr_keys_iv-invitem )
        INTO TABLE lt_ivfully ASSIGNING FIELD-SYMBOL(<lfs_ivfully>).

      LOOP AT GROUP lgr_keys_iv ASSIGNING FIELD-SYMBOL(<ls_keys_iv>).
        IF <ls_keys_iv>-invopenqty <> 0.
          <lfs_ivfully>-isopeninv = 'X'.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    "5.4. Tìm GR Fully Invoice của group by pono poitem matdoc matdocitem
    TYPES: BEGIN OF lty_grfully,
             pono       TYPE zce_mapim-pono,
             poitem     TYPE zce_mapim-poitem,
             matdoc     TYPE zce_mapim-matdoc,
             matdocitem TYPE zce_mapim-matdocitem,
             isopengr   TYPE abap_boolean,
           END OF lty_grfully.
    DATA: lt_grfully TYPE HASHED TABLE OF lty_grfully WITH UNIQUE KEY pono poitem matdoc matdocitem. "PERF - 05.11.2026

    LOOP AT lt_keys_full INTO DATA(ls_grp_keys_gr)
        GROUP BY ( pono = ls_grp_keys_gr-pono
                   poitem = ls_grp_keys_gr-poitem
                   matdoc = ls_grp_keys_gr-matdoc
                   matdocitem = ls_grp_keys_gr-matdocitem )
       INTO DATA(lgr_keys_gr).

      INSERT VALUE #( pono       = lgr_keys_gr-pono
                      poitem     = lgr_keys_gr-poitem
                      matdoc     = lgr_keys_gr-matdoc
                      matdocitem = lgr_keys_gr-matdocitem )
        INTO TABLE lt_grfully ASSIGNING FIELD-SYMBOL(<lfs_grfully>).

      LOOP AT GROUP lgr_keys_gr ASSIGNING FIELD-SYMBOL(<ls_keys_gr>).
        IF <ls_keys_gr>-gropenqty <> 0.
          <lfs_grfully>-isopengr = 'X'.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Get ghi chú
    "PERF - 05.11.2026: FAE theo PO/PO item distinct (lt_keys_full trùng PO rất nhiều)
    TYPES: BEGIN OF lty_po_item,
             pono   TYPE ty_keys-pono,
             poitem TYPE ty_keys-poitem,
           END OF lty_po_item.
    DATA: lt_po_item TYPE SORTED TABLE OF lty_po_item WITH UNIQUE KEY pono poitem.

    LOOP AT lt_keys_full ASSIGNING FIELD-SYMBOL(<lfs_key_po>).
      INSERT VALUE #( pono = <lfs_key_po>-pono poitem = <lfs_key_po>-poitem ) INTO TABLE lt_po_item.
    ENDLOOP.

    "lt_keys_full chắc chắn có dòng (đã RETURN ở trên) --> lt_po_item không rỗng
    SELECT FROM i_purchaseorderitemnotetp_2 AS a
    FIELDS
        a~PurchaseOrder,
        a~PurchaseOrderItem,
        a~TextObjectType,
        a~Language,
        a~PlainLongText
    FOR ALL ENTRIES IN @lt_po_item
    WHERE
        a~PurchaseOrder = @lt_po_item-pono
        AND a~PurchaseOrderItem = @lt_po_item-poitem
        AND a~Language = @sy-langu
        AND a~TextObjectType = 'F04'
    INTO TABLE @DATA(lt_ghichu).
    SORT lt_ghichu STABLE BY PurchaseOrder PurchaseOrderItem.

    "PERF - 05.11.2026: sort để READ bằng BINARY SEARCH trong vòng lặp kết quả
    "STABLE: giữ thứ tự gốc giữa các dòng trùng key --> READ vẫn ra đúng dòng đầu tiên như trước
    SORT lt_bases STABLE BY pono poitem matdoc matdocitem inv invitem fiscalyear grcategory ivcategory.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Get result
    DATA: lv_index_result TYPE i,
          lv_index_gr     TYPE i,
          lv_index_iv     TYPE i.

    "PERF - 05.11.2026: ASSIGNING thay vì copy dòng; mọi READ trong vòng lặp dùng BINARY SEARCH / hashed key
    LOOP AT lt_keys_full ASSIGNING FIELD-SYMBOL(<lfs_key>).

      APPEND INITIAL LINE TO et_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      "Key fields
      <lfs_result>-PONo = <lfs_key>-pono.
      <lfs_result>-POItem = <lfs_key>-POItem.
      <lfs_result>-MatDoc = <lfs_key>-MatDoc.
      <lfs_result>-MatDocItem = <lfs_key>-MatDocItem.
      <lfs_result>-Inv = <lfs_key>-Inv.
      <lfs_result>-InvItem = <lfs_key>-InvItem.
      <lfs_result>-FiscalYear = <lfs_key>-FiscalYear.

      <lfs_result>-GRCategory = <lfs_key>-GRCategory.
      <lfs_result>-ivcategory = <lfs_key>-ivcategory.

      <lfs_result>-GROpenQty = <lfs_key>-GROpenQty.
      <lfs_result>-InvOpenQty = <lfs_key>-InvOpenQty.
      <lfs_result>-AllocatedQty = <lfs_key>-AllocatedQty.

      "NinhNH Udt - add 2 fiscal year - 18.06.2026
      <lfs_result>-GRFiscalYear = <lfs_key>-GRFiscalYear.
      <lfs_result>-InvFiscalYear = <lfs_key>-InvFiscalYear.
      <lfs_result>-POType = <lfs_key>-purchaseordertype.
      "End of NinhNH Udt - add 2 fiscal year - 18.06.2026

      "Local Currency
      <lfs_result>-LocaCurrencyKey = 'VND'.

      "Base fields
      READ TABLE lt_bases ASSIGNING FIELD-SYMBOL(<lfs_base>) WITH KEY
        PONo       = <lfs_key>-PONo
        POItem     = <lfs_key>-POItem
        MatDoc     = <lfs_key>-MatDoc
        MatDocItem = <lfs_key>-MatDocItem
        Inv        = <lfs_key>-Inv
        InvItem    = <lfs_key>-InvItem
        FiscalYear = <lfs_key>-FiscalYear
        grcategory = <lfs_key>-grcategory
        ivcategory = <lfs_key>-ivcategory
        BINARY SEARCH.
      IF sy-subrc = 0.
        "Dev/NinhNH/ZMapIM/Add field item + header text - v8
        <lfs_result>-ItemText = <lfs_base>-ItemText.
        <lfs_result>-HeaderText = <lfs_base>-HeaderText.

        "Dev/NinhNH/ZMapIM/Add Batch + Valuation type - FS v2 - 04.11.2026
        <lfs_result>-Batch = <lfs_base>-Batch.
        <lfs_result>-ValuationType = <lfs_base>-ValuationType.

        "Dev/NinhNH/ZMapIM/Add 3 fields PO+INV Net Price+Sloc - v6
        <lfs_result>-PONetprice = <lfs_base>-ponetprice.
        <lfs_result>-POCurrency = <lfs_base>-POCurrency.
        <lfs_result>-StorageLocation = <lfs_base>-StorageLocation.
        <lfs_result>-StorageLocationName = <lfs_base>-StorageLocationName.

        <lfs_result>-CompanyCode = <lfs_base>-CompanyCode.
        <lfs_result>-POSupplier = <lfs_base>-POSupplier.
        <lfs_result>-MaterialCode = <lfs_base>-MaterialCode.
        <lfs_result>-MaterialDescription = <lfs_base>-MaterialDescription.
        <lfs_result>-OrderPriceUnit = <lfs_base>-OrderPriceUnit.
        <lfs_result>-DeliveryDoc = <lfs_base>-DeliveryDoc.
        <lfs_result>-DeliveryItem = <lfs_base>-DeliveryItem.
        <lfs_result>-GRPostingDate = <lfs_base>-GRPostingDate.
        <lfs_result>-TransCur = <lfs_base>-TransCur.
        <lfs_result>-GRAmountComCode = <lfs_base>-GRAmountComCode.
        <lfs_result>-GRAmountTransCode = <lfs_base>-GRAmountTransCode.
        <lfs_result>-je = <lfs_base>-je.
        <lfs_result>-InvoiceNo = <lfs_base>-InvoiceNo.
        <lfs_result>-InvoicePostingDate = <lfs_base>-InvoicePostingDate.
        <lfs_result>-InvoiceAmountComCode = <lfs_base>-InvoiceAmountComCode.
        <lfs_result>-Currency = <lfs_base>-Currency.
        <lfs_result>-InvoiceAmountTrans = <lfs_base>-InvoiceAmountTrans.
        <lfs_result>-invoicingparty = <lfs_base>-invoicingparty.
        <lfs_result>-plant = <lfs_base>-plant.

        "GR Quantity + Invoice Quantity
        <lfs_result>-grqty = <lfs_base>-grqty.
        <lfs_result>-InvoiceQty = <lfs_base>-InvoiceQty.

        "BP Text Fields
        "(tên đã tính sẵn ở bước 3.1 + 3.2)
        IF <lfs_base>-POSupplier IS NOT INITIAL.
          READ TABLE lt_bp_name ASSIGNING FIELD-SYMBOL(<lfs_bp_name>)
            WITH TABLE KEY bp = <lfs_base>-POSupplier.
          IF sy-subrc = 0.
            <lfs_result>-POSupplierName = <lfs_bp_name>-name.
          ENDIF.
        ENDIF.

        "Invoicing Party Name Fields
        IF <lfs_base>-InvoicingParty IS NOT INITIAL.
          READ TABLE lt_bp_name ASSIGNING <lfs_bp_name>
            WITH TABLE KEY bp = <lfs_base>-InvoicingParty.
          IF sy-subrc = 0.
            <lfs_result>-InvoicingPartyName = <lfs_bp_name>-name.
          ENDIF.
        ENDIF.

        "Yes/No Fields
        "GRBasedInv Field
        <lfs_result>-GRBasedInv = COND #( WHEN <lfs_base>-InvoiceIsGoodsReceiptBased IS NOT INITIAL
                                          THEN 'Yes' ELSE 'No' ).

        "GR Fully Invoiced field
        READ TABLE lt_grfully ASSIGNING FIELD-SYMBOL(<lfs_grfully_rd>) WITH TABLE KEY
            pono = <lfs_base>-pono
            poitem = <lfs_base>-poitem
            matdoc = <lfs_base>-matdoc
            matdocitem = <lfs_base>-matdocitem.
        IF sy-subrc = 0.
          <lfs_result>-GRFullyInvoiced = COND #( WHEN <lfs_grfully_rd>-isopengr IS INITIAL
                                                 THEN 'Yes' ELSE 'No' ).
        ENDIF.

        "IV Fully Invoiced field
        READ TABLE lt_ivfully ASSIGNING FIELD-SYMBOL(<lfs_ivfully_rd>) WITH TABLE KEY
            pono = <lfs_base>-pono
            poitem = <lfs_base>-poitem
            inv = <lfs_base>-inv
            invitem = <lfs_base>-invitem.
        IF sy-subrc = 0.
          <lfs_result>-IVFullyInvoiced = COND #( WHEN <lfs_ivfully_rd>-isopeninv IS INITIAL
                                                 THEN 'Yes' ELSE 'No' ).
        ENDIF.

        "PO fully invoiced Field
        READ TABLE lt_po_fullyqty ASSIGNING FIELD-SYMBOL(<lfs_po_fullyqty_rd>) WITH TABLE KEY
              pono = <lfs_base>-pono
              poitem = <lfs_base>-poitem.
        IF sy-subrc = 0.
          <lfs_result>-POFullyInvoiced = COND #( WHEN <lfs_po_fullyqty_rd>-total_gr = <lfs_po_fullyqty_rd>-total_iv
                                                 THEN 'Yes' ELSE 'No' ).
        ENDIF.

        IF <lfs_result>-POFullyInvoiced = 'Yes'.
          "Nếu PO fully invoiced = Yes --> chuyển tất cả các fully invoiced còn lại thành yes
          "Nếu PO fully invoiced =  Yes => GR Open Qty = 0
          "Nếu PO fully invoiced =  Yes => INV Open Qty = 0
          "Nếu PO fully invoiced =  Yes => GR Fully Invoiced = Yes
          "Nếu PO fully invoiced =  Yes => IV Fully Invoiced = Yes
          <lfs_result>-GROpenQty = 0.
          <lfs_result>-InvOpenQty = 0.
          <lfs_result>-GRFullyInvoiced = 'Yes'.
          <lfs_result>-IVFullyInvoiced = 'Yes'.
        ELSE.
          "Nếu PO fully invoiced =  No; Nếu dòng chỉ có INV không có GR  => GR Fully Invoiced = No
          IF <lfs_result>-MatDoc IS INITIAL AND <lfs_result>-Inv IS NOT INITIAL.
            <lfs_result>-GRFullyInvoiced = 'No'.
          ENDIF.
          "Nếu PO fully invoiced =  No, Nếu dòng chỉ có GR không có INV  => INV Fully Invoiced = No
          IF <lfs_result>-MatDoc IS NOT INITIAL AND <lfs_result>-Inv IS INITIAL.
            <lfs_result>-IVFullyInvoiced = 'No'.
          ENDIF.
        ENDIF.

        IF <lfs_result>-IVCategory = 'N' OR <lfs_result>-GRCategory = 'K'.
          <lfs_result>-GRFullyInvoiced = ''.
          <lfs_result>-IVFullyInvoiced = ''.
        ENDIF.
      ENDIF.

      "<<< POTYPE: PO Type ≠ ZPO4 và NetAmount item = 0 → xử lý như type K
      "(các field quantity/amount khác giữ nguyên theo yêu cầu)
      IF <lfs_key>-purchaseordertype <> 'ZPO4' AND <lfs_key>-netamount = 0.
        <lfs_result>-AllocatedQty    = 0.
        <lfs_result>-GROpenQty       = 0.
        <lfs_result>-InvOpenQty      = 0.
        <lfs_result>-GRFullyInvoiced = ''.
        <lfs_result>-IVFullyInvoiced = ''.
        <lfs_result>-POFullyInvoiced = 'Yes'.
      ENDIF.

      "Get SortOrder
      <lfs_result>-SortOrder = COND #(
      WHEN <lfs_result>-GRCategory = 'E' AND <lfs_result>-IVCategory = 'Q' THEN 1
      WHEN <lfs_result>-GRCategory IS INITIAL AND <lfs_result>-IVCategory = 'Q' THEN 2
      WHEN <lfs_result>-GRCategory = 'E' AND <lfs_result>-IVCategory IS INITIAL THEN 3
      WHEN <lfs_result>-GRCategory IS INITIAL AND <lfs_result>-IVCategory = 'N' THEN 4
      WHEN <lfs_result>-GRCategory = 'K' AND <lfs_result>-IVCategory IS INITIAL THEN 5
      ELSE 6
      ).

      "Dev/NinhNH/ZMapIM/Add 3 fields PO+INV Net Price+Sloc - v6
      <lfs_result>-INVNetPriceTransCur = <lfs_result>-InvoiceAmountTrans / <lfs_result>-InvoiceQty.
*      <lfs_result>-INVNetPriceTransCurF = format_number( <lfs_result>-INVNetPriceTransCur ). " string đẹp
*      <lfs_result>-InvoiceAmountTransF = format_number( <lfs_result>-InvoiceAmountTrans ). " string đẹp
*      <lfs_result>-InvoiceAmountComCodeF = format_number( <lfs_result>-InvoiceAmountComCode ). " string đẹp


      "Ghi chú
      READ TABLE lt_ghichu ASSIGNING FIELD-SYMBOL(<lfs_ghichu>)
        WITH KEY PurchaseOrder     = <lfs_key>-pono
                 PurchaseOrderItem = <lfs_key>-poitem
        BINARY SEARCH.
      IF sy-subrc = 0.
        <lfs_result>-GhiChu = <lfs_ghichu>-PlainLongText.
      ENDIF.

      "Dev/NinhNH/ZMapIM/Add 4 field tính toán - v10.01
      IF <lfs_result>-AllocatedQty IS INITIAL.
        <lfs_result>-AllocatedGRAmountComCode      = <lfs_result>-GRAmountComCode.
        <lfs_result>-AllocatedGRAmountTransCode    = <lfs_result>-GRAmountTransCode.
        <lfs_result>-AllocatedInvoiceAmountComCode = <lfs_result>-InvoiceAmountComCode.
        <lfs_result>-AllocatedInvoiceAmountTrans   = <lfs_result>-InvoiceAmountTrans.
      ELSE.
        IF <lfs_result>-GRQty IS NOT INITIAL.
          <lfs_result>-AllocatedGRAmountComCode   = <lfs_result>-GRAmountComCode * <lfs_result>-AllocatedQty / <lfs_result>-GRQty.
          <lfs_result>-AllocatedGRAmountTransCode = <lfs_result>-GRAmountTransCode * <lfs_result>-AllocatedQty / <lfs_result>-GRQty.
        ENDIF.
        IF <lfs_result>-InvoiceQty IS NOT INITIAL.
          <lfs_result>-AllocatedInvoiceAmountComCode = <lfs_result>-InvoiceAmountComCode * <lfs_result>-AllocatedQty / <lfs_result>-InvoiceQty.
          <lfs_result>-AllocatedInvoiceAmountTrans   = <lfs_result>-InvoiceAmountTrans * <lfs_result>-AllocatedQty / <lfs_result>-InvoiceQty.
        ENDIF.
      ENDIF.
    ENDLOOP.

    "Dev/NinhNH/ZMapIM/Fix rounding allocated amount - v11.01
    "Logic: nếu 1 chứng từ (IV hoặc GR) đã phân bổ hết qty cho nhiều dòng
    "       --> phần lệch do làm tròn = Tổng amount chứng từ - Σ allocated amount
    "       --> cộng phần lệch vào dòng có |allocated amount| lớn nhất
    DATA: lv_rnd_sum_qty  TYPE menge_d,
          lv_rnd_doc_qty  TYPE menge_d,
          lv_rnd_sum_cc   TYPE wrbtr_cs,
          lv_rnd_sum_tr   TYPE wrbtr_cs,
          lv_rnd_total_cc TYPE wrbtr_cs,
          lv_rnd_total_tr TYPE wrbtr_cs,
          lref_rnd_max_iv TYPE REF TO zce_mapim,
          lref_rnd_max_gr TYPE REF TO zce_mapim.

    "1. Chiều IV: 1 Invoice item --> n GR
    LOOP AT et_result REFERENCE INTO DATA(lref_rnd_iv)
         WHERE inv          IS NOT INITIAL
           AND allocatedqty IS NOT INITIAL
           AND invoiceqty   IS NOT INITIAL
         GROUP BY ( pono          = lref_rnd_iv->pono
                    poitem        = lref_rnd_iv->poitem
                    inv           = lref_rnd_iv->inv
                    invitem       = lref_rnd_iv->invitem
                    invfiscalyear = lref_rnd_iv->invfiscalyear
                    ivcategory    = lref_rnd_iv->ivcategory )
         REFERENCE INTO DATA(lref_rnd_grp_iv).

      CLEAR: lv_rnd_sum_qty, lv_rnd_doc_qty,
             lv_rnd_sum_cc, lv_rnd_sum_tr,
             lv_rnd_total_cc, lv_rnd_total_tr,
             lref_rnd_max_iv.

      LOOP AT GROUP lref_rnd_grp_iv REFERENCE INTO DATA(lref_rnd_mem_iv).
        lv_rnd_sum_qty  += lref_rnd_mem_iv->allocatedqty.
        lv_rnd_sum_cc   += lref_rnd_mem_iv->allocatedinvoiceamountcomcode.
        lv_rnd_sum_tr   += lref_rnd_mem_iv->allocatedinvoiceamounttrans.
        lv_rnd_doc_qty   = lref_rnd_mem_iv->invoiceqty.
        lv_rnd_total_cc  = lref_rnd_mem_iv->invoiceamountcomcode.
        lv_rnd_total_tr  = lref_rnd_mem_iv->invoiceamounttrans.

        IF lref_rnd_max_iv IS NOT BOUND
        OR abs( lref_rnd_mem_iv->allocatedinvoiceamounttrans ) > abs( lref_rnd_max_iv->allocatedinvoiceamounttrans ).
          lref_rnd_max_iv = lref_rnd_mem_iv.
        ENDIF.
      ENDLOOP.

      "Chỉ bù khi IV đã phân bổ hết (không còn phần open)
      IF lref_rnd_max_iv IS BOUND AND lv_rnd_sum_qty = lv_rnd_doc_qty.
        lref_rnd_max_iv->allocatedinvoiceamountcomcode += lv_rnd_total_cc - lv_rnd_sum_cc.
        lref_rnd_max_iv->allocatedinvoiceamounttrans   += lv_rnd_total_tr - lv_rnd_sum_tr.
      ENDIF.
    ENDLOOP.

    "2. Chiều GR: 1 GR item --> n IV
    LOOP AT et_result REFERENCE INTO DATA(lref_rnd_gr)
         WHERE matdoc       IS NOT INITIAL
           AND allocatedqty IS NOT INITIAL
           AND grqty        IS NOT INITIAL
         GROUP BY ( pono         = lref_rnd_gr->pono
                    poitem       = lref_rnd_gr->poitem
                    matdoc       = lref_rnd_gr->matdoc
                    matdocitem   = lref_rnd_gr->matdocitem
                    grfiscalyear = lref_rnd_gr->grfiscalyear
                    grcategory   = lref_rnd_gr->grcategory )
         REFERENCE INTO DATA(lref_rnd_grp_gr).

      CLEAR: lv_rnd_sum_qty, lv_rnd_doc_qty,
             lv_rnd_sum_cc, lv_rnd_sum_tr,
             lv_rnd_total_cc, lv_rnd_total_tr,
             lref_rnd_max_gr.

      LOOP AT GROUP lref_rnd_grp_gr REFERENCE INTO DATA(lref_rnd_mem_gr).
        lv_rnd_sum_qty  += lref_rnd_mem_gr->allocatedqty.
        lv_rnd_sum_cc   += lref_rnd_mem_gr->allocatedgramountcomcode.
        lv_rnd_sum_tr   += lref_rnd_mem_gr->allocatedgramounttranscode.
        lv_rnd_doc_qty   = lref_rnd_mem_gr->grqty.
        lv_rnd_total_cc  = lref_rnd_mem_gr->gramountcomcode.
        lv_rnd_total_tr  = lref_rnd_mem_gr->gramounttranscode.

        IF lref_rnd_max_gr IS NOT BOUND
        OR abs( lref_rnd_mem_gr->allocatedgramounttranscode ) > abs( lref_rnd_max_gr->allocatedgramounttranscode ).
          lref_rnd_max_gr = lref_rnd_mem_gr.
        ENDIF.
      ENDLOOP.

      "Chỉ bù khi GR đã phân bổ hết (không còn phần open)
      IF lref_rnd_max_gr IS BOUND AND lv_rnd_sum_qty = lv_rnd_doc_qty.
        lref_rnd_max_gr->allocatedgramountcomcode   += lv_rnd_total_cc - lv_rnd_sum_cc.
        lref_rnd_max_gr->allocatedgramounttranscode += lv_rnd_total_tr - lv_rnd_sum_tr.
      ENDIF.
    ENDLOOP.
    "End Dev/NinhNH/ZMapIM/Fix rounding allocated amount - v11.01

    IF lr_grfullyinvoiced IS NOT INITIAL.
      DELETE et_result WHERE GRFullyInvoiced NOT IN lr_grfullyinvoiced.
    ENDIF.
    IF lr_GRBASEDINV IS NOT INITIAL.
      DELETE et_result WHERE grbasedinv NOT IN lr_GRBASEDINV.
    ENDIF.
    IF lr_IVFULLYINVOICED IS NOT INITIAL.
      DELETE et_result WHERE ivfullyinvoiced NOT IN lr_IVFULLYINVOICED.
    ENDIF.
    IF lr_POIVFULLYINVOICED IS NOT INITIAL.
      DELETE et_result WHERE pofullyinvoiced NOT IN lr_POIVFULLYINVOICED.
    ENDIF.

  ENDMETHOD.


  METHOD requested.
    TRY.
        et_filters = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        "handle exception
    ENDTRY.
  ENDMETHOD.


  METHOD response.
    " ── a. AGGREGATION ──
    DATA: lt_aggregated TYPE STANDARD TABLE OF zce_zmb52.

    TRY.
        DATA(lo_aggregation) = io_request->get_aggregation( ).
      CATCH cx_rap_query_provider.
    ENDTRY.

    " ── b. RESPONSE ────────────────────────────────
    DATA(lv_total) = lines( ct_result ).

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( CONV int8( lv_total ) ).
    ENDIF.
    " ── c. HANDLE SORT ─────────────────────────────────────
    DATA(lt_sort) = io_request->get_sort_elements( ).
    IF lt_sort IS NOT INITIAL.
      DATA lt_sort_order TYPE abap_sortorder_tab.
      LOOP AT lt_sort INTO DATA(ls_sort).
        APPEND VALUE #(
            name       = ls_sort-element_name
            descending = ls_sort-descending
        ) TO lt_sort_order.
      ENDLOOP.
      SORT ct_result BY (lt_sort_order).
    ELSE.
      " Default sort
      SORT ct_result BY PONo
                        POItem
                        SortOrder
                        GRPostingDate
                        MatDoc
                        MatDocItem
                        InvoicePostingDate
                        Inv
                        InvItem.

    ENDIF.
    " ── d. PAGING ──────────────────────────────────────────
    DATA(lv_skip) = io_request->get_paging( )->get_offset( ).
    DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).

    IF lv_top = if_rap_query_paging=>page_size_unlimited.
      lv_top = lv_total.
    ENDIF.

    IF lv_skip > 0.
      DELETE ct_result TO lv_skip.
    ENDIF.

    IF lv_top < lines( ct_result ).
      DELETE ct_result FROM lv_top + 1.
    ENDIF.

    io_response->set_data( ct_result ).
  ENDMETHOD.


  METHOD format_number.
    " Đưa về string
    DATA lv_str TYPE string.
    lv_str = |{ iv_value }|.   " convert mặc định, ra dạng "0.350" / "1.000"

    " Bỏ số 0 cuối phần thập phân
    IF lv_str CS '.'.
      " xóa các '0' ở cuối
      WHILE strlen( lv_str ) > 0
        AND substring( val = lv_str off = strlen( lv_str ) - 1 len = 1 ) = '0'.
        lv_str = substring( val = lv_str len = strlen( lv_str ) - 1 ).
      ENDWHILE.
      " nếu kết thúc bằng '.' thì bỏ luôn dấu chấm
      IF strlen( lv_str ) > 0
        AND substring( val = lv_str off = strlen( lv_str ) - 1 len = 1 ) = '.'.
        lv_str = substring( val = lv_str len = strlen( lv_str ) - 1 ).
      ENDIF.
    ENDIF.

    rv_result = lv_str.
  ENDMETHOD.
ENDCLASS.
