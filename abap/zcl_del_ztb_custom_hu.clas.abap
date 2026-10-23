CLASS zcl_del_ztb_custom_hu DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_DEL_ZTB_CUSTOM_HU IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    " Xóa dữ liệu test để activate được các thay đổi không tương thích của bảng
    " (đổi key ZTB_CUSTOM_HU, đổi kiểu Quantity và bỏ BaseUnit ở các bảng upload)
    DELETE FROM ztb_custom_hu.
    out->write( |ZTB_CUSTOM_HU: đã xóa { sy-dbcnt } dòng| ).

    DELETE FROM ztb_d_thung.
    out->write( |ZTB_D_THUNG: đã xóa { sy-dbcnt } dòng| ).

    DELETE FROM ztb_d_thungd.
    out->write( |ZTB_D_THUNGD: đã xóa { sy-dbcnt } dòng| ).

    " File upload không còn dòng dữ liệu nên xóa luôn header
    DELETE FROM ztb_m_thung.
    out->write( |ZTB_M_THUNG: đã xóa { sy-dbcnt } dòng| ).

    DELETE FROM ztb_m_thungd.
    out->write( |ZTB_M_THUNGD: đã xóa { sy-dbcnt } dòng| ).
  ENDMETHOD.
ENDCLASS.
