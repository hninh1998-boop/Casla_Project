CLASS zcl_add_data_zbom_sp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_add_data_zbom_sp IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    DATA lt_data TYPE STANDARD TABLE OF ztb_zbom_spplant WITH EMPTY KEY.
    DATA lv_ts   TYPE timestampl.

    GET TIME STAMP FIELD lv_ts.

    lt_data = VALUE #(
      procurement_type      = 'F'
      special_procurement   = '7'
      local_last_changed_at = lv_ts
      last_changed_at       = lv_ts
      ( plant = '6711' sp_type = '21' issuing_plant = '6713' description = 'Lấy hàng từ CASLA 3 (Mành dệt)' )
      ( plant = '6711' sp_type = '25' issuing_plant = '6712' description = 'Lấy hàng từ CASLA 2 (In tráng)' )
      ( plant = '6712' sp_type = '21' issuing_plant = '6713' description = 'Lấy hàng từ CASLA 3 (Mành dệt)' )
      ( plant = '6712' sp_type = '27' issuing_plant = '6711' description = 'Hàng lấy từ NMCL1' )
      ( plant = '6713' sp_type = '20' issuing_plant = '6711' description = 'External procurement' )
      ( plant = '6721' sp_type = '21' issuing_plant = '6713' description = 'Lấy hàng từ CASLA 3' )
      ( plant = '6721' sp_type = '23' issuing_plant = '6722' description = 'Hàng lấy từ NMTT (mành PPKD + Quai dệt)' )
      ( plant = '6722' sp_type = '21' issuing_plant = '6713' description = 'Lấy hàng từ CASLA 3' )
      ( plant = '6722' sp_type = '26' issuing_plant = '6721' description = 'Lấy hàng từ Tân Dĩnh - 6721' )
    ).

    DELETE FROM ztb_zbom_spplant.          " xóa dữ liệu mẫu cũ (1000/1100/1200) trước khi insert

    MODIFY ztb_zbom_spplant FROM TABLE @lt_data.

    IF sy-subrc = 0.
      COMMIT WORK.
      out->write( |Đã insert { lines( lt_data ) } dòng vào ZTB_ZBOM_SPPLANT| ).
    ELSE.
      ROLLBACK WORK.
      out->write( 'Lỗi khi ghi dữ liệu' ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.

