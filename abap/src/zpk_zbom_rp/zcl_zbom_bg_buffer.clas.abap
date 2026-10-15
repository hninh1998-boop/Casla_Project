CLASS zcl_zbom_bg_buffer DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_bg_item,
             hdrid                        TYPE sysuuid_x16,
             itmid                        TYPE sysuuid_x16,
             material                     TYPE matnr,
             plant                        TYPE werks_d,
             billofmaterialvariantusage   TYPE c LENGTH 1,
             billofmaterialvariant        TYPE c LENGTH 2,
             salesorder                   TYPE vbeln,
             salesorderitem               TYPE posnr,
             billofmaterialitemnumber     TYPE c LENGTH 4,
             billofmaterialitemnodenumber TYPE stlkn,
             bomiteminternalchangecount   TYPE cim_count,
             billofmaterial               TYPE c LENGTH 8,
             billofmaterialcategory       TYPE stlty,
             lineitem                     TYPE int4,

             component                    TYPE zabs_edit_massChange-Component,
             componentquantity            TYPE zabs_edit_massChange-ComponentQuantity,
             componentscrap               TYPE zabs_edit_massChange-ComponentScrap,
             specialprocurementtype(2),
             bomitemiscostingrelevant(1),
             componentuom(3),
             ProdOrderIssueLocation(4),

             jobtext                      TYPE zabs_edit_massChange-JobText,
             editcomponent                TYPE abap_boolean,
             editcomponentquantity        TYPE abap_boolean,
             editcomponentscrap           TYPE abap_boolean,
             editspecialprocurementtype   TYPE abap_boolean,
             editbomitemiscostingrelevant TYPE abap_boolean,
             editcomponentuom             TYPE abap_boolean,
             editProdOrderIssueLocation   TYPE abap_boolean,
           END OF ty_bg_item.

    TYPES tt_bg_items TYPE TABLE OF ty_bg_item WITH DEFAULT KEY.

    " ← CLASS-DATA PUBLIC → cả lhc_ và lsc_ đều truy cập được
    CLASS-DATA gt_bg_jobs TYPE tt_bg_items.

ENDCLASS.



CLASS ZCL_ZBOM_BG_BUFFER IMPLEMENTATION.
ENDCLASS.
