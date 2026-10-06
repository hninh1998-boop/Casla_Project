DATA(iso_week) = NEW zcl_iso_week( ).
DATA i_date TYPE zde_date.

MOVE-CORRESPONDING manufacturingorder TO manufacturingorder_changed.

zcl_cobadicfl_mfgorder=>get_data_order(
EXPORTING
  i_product        = manufacturingorder-material
IMPORTING
  sew              = DATA(lv_sew)
  producthierachy1 = DATA(lv_prdhie1)
  producthierachy2 = DATA(lv_prdhie2)
  producthierachy3 = DATA(lv_prdhie3)
  producthierachy4 = DATA(lv_prdhie4)
  producthierachy5 = DATA(lv_prdhie5)
  producthierachy6 = DATA(lv_prdhie6)
  quantity         = DATA(lv_quantity)
  quantityngc      = DATA(lv_quantityngc)
).

manufacturingorder_changed-yy1_producthierachy1od_ord = lv_prdhie1.
manufacturingorder_changed-yy1_producthierachy2od_ord = lv_prdhie2.
manufacturingorder_changed-yy1_producthierachy3od_ord = lv_prdhie3.
manufacturingorder_changed-yy1_producthierachy4od_ord = lv_prdhie4.
manufacturingorder_changed-yy1_producthierachy5od_ord = lv_prdhie5.
manufacturingorder_changed-yy1_producthierachy6od_ord = lv_prdhie6.

SELECT SINGLE
product,
salesorderitemtext
FROM i_salesorderitem WITH PRIVILEGED ACCESS
WHERE salesorder = @manufacturingorder-salesorder
AND salesorderitem = @manufacturingorder-salesorderitem
INTO @DATA(ls_salesorderitem).
IF sy-subrc EQ 0.
  manufacturingorder_changed-yy1_material_ord = ls_salesorderitem-product.
  manufacturingorder_changed-yy1_materialname_ord = ls_salesorderitem-salesorderitemtext.
ENDIF.

SELECT
salesdocument,
salesdocumentitem,
scheduleline,
deliverydate
FROM i_salesdocumentscheduleline WITH PRIVILEGED ACCESS
WHERE salesdocument = @manufacturingorder-salesorder
AND salesdocumentitem = @manufacturingorder-salesorderitem
INTO TABLE @DATA(lt_salesdocumentscheduleline).
IF sy-subrc EQ 0.
  SORT lt_salesdocumentscheduleline BY scheduleline ASCENDING.
  READ TABLE lt_salesdocumentscheduleline INTO DATA(ls_salesdocumentscheduleline) INDEX 1.

  manufacturingorder_changed-yy1_deliverydate_ord = ls_salesdocumentscheduleline-deliverydate.

  IF ls_salesdocumentscheduleline-deliverydate IS NOT INITIAL.
    i_date = ls_salesdocumentscheduleline-deliverydate.
    iso_week->get_iso_week(
    EXPORTING
      i_date = i_date
    IMPORTING
      e_week   = DATA(lv_week)
  ).

    manufacturingorder_changed-yy1_deliveryweek_ord = lv_week+4(2) && `/` && lv_week+0(4).
  ENDIF.
ENDIF.

CLEAR: lv_week.
IF manufacturingorder-mfgorderscheduledstartdate IS NOT INITIAL.
  i_date = manufacturingorder-mfgorderscheduledstartdate.
  iso_week->get_iso_week(
    EXPORTING
      i_date = i_date
    IMPORTING
      e_week   = lv_week
  ).
  manufacturingorder_changed-yy1_weekstart_ord = lv_week+4(2) && `/` && lv_week+0(4).
  CONDENSE manufacturingorder_changed-yy1_weekstart_ord NO-GAPS .
ENDIF.

CLEAR: lv_week.

IF manufacturingorder-mfgorderscheduledenddate IS NOT INITIAL.
  i_date = manufacturingorder-mfgorderscheduledenddate.
  iso_week->get_iso_week(
    EXPORTING
      i_date = i_date
    IMPORTING
      e_week   = lv_week
  ).
  manufacturingorder_changed-yy1_weekfinish_ord = lv_week+4(2) && `/` && lv_week+0(4).
  CONDENSE manufacturingorder_changed-yy1_weekfinish_ord NO-GAPS .
ENDIF.

"Khổ nguyên vật liệu
DATA: lr_mgroup TYPE RANGE OF i_mfgorderoperationcomponent-materialgroup.

CASE manufacturingorder-manufacturingordertype.
  WHEN '1009' OR '2007'.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '110301' ) TO lr_mgroup.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '110302' ) TO lr_mgroup.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '110303' ) TO lr_mgroup.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '110304' ) TO lr_mgroup.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '110305' ) TO lr_mgroup.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '210005' ) TO lr_mgroup.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '210006' ) TO lr_mgroup.
  WHEN '1008' OR '2006'.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '110301' ) TO lr_mgroup.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '210006' ) TO lr_mgroup.
  WHEN '1010' OR '2008'.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '110301' ) TO lr_mgroup.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '210006' ) TO lr_mgroup.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '210008' ) TO lr_mgroup.
  WHEN '1015' OR '2015'.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '210018' ) TO lr_mgroup.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '210019' ) TO lr_mgroup.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '210010' ) TO lr_mgroup.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '210011' ) TO lr_mgroup.
  WHEN '1014' OR '2014'.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '210011' ) TO lr_mgroup.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '210010' ) TO lr_mgroup.
  WHEN OTHERS.
ENDCASE.

SELECT SINGLE material FROM i_mfgorderoperationcomponent WITH PRIVILEGED ACCESS
WHERE manufacturingorder = @manufacturingorder-manufacturingorder
  AND manufacturingordertype = @manufacturingorder-manufacturingordertype
  AND manufacturingordercategory = @manufacturingorder-manufacturingordercategory
  AND materialgroup IN @lr_mgroup
  AND NOT matlcompismarkedfordeletion = 'X'
INTO @DATA(lv_product).
IF sy-subrc EQ 0.
  SELECT SINGLE productname FROM i_producttext WITH PRIVILEGED ACCESS
  WHERE product = @lv_product
  INTO @manufacturingorder_changed-yy1_kho_nvl_ord.
ENDIF.
