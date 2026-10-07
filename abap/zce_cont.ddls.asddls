@EndUserText.label: 'Custom Entity - Cont'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CE_CONT'
@Metadata.allowExtensions: true
define root custom entity zce_cont
{
  key SO                         : vbelv; // I_SalesOrderItem-SalesOrder
  key SOItem                     : posnv; // I_SalesOrderItem-SalesOrderItem
  key SoLenhXuatHang             : vbeln; // I_OutboundDeliveryItem-OutboundDelivery
  key SoLenhXuatHangItem         : posnr; // I_OutboundDeliveryItem-OutboundDeliveryItem
      SoKH                       : abap.char(16); // SO/SOItem

      // I_SalesOrderItem
      NgayGiaoHangDuKien         : abap.dats(8); // RequestedDeliveryDate
      MaHang                     : matnr; // Product
      TenHang                    : arktx; // SalesOrderItemText

      // I_ClfnObjectCharcValue
      KichThhuocTui              : atwrt; // CharcValue

      // I_OutboundDelivery --> I_OverallGoodsMovementStatusT (_Text)
      TrangThaiOD                : abap.char(20);

      // I_OutboundDeliveryItem
      @ObjectModel.text.element  : [ 'DiaDiemDongHangContName' ]
      DiaDiemDongHang            : werks_d; // Plant
      DiaDiemDongHangContName    : abap.char(30); // Plant
      @ObjectModel.text.element  : [ 'PlantName' ]
      Plant                      : werks_d; // Plant
      PlantName                  : abap.char(30);   // \_Plant-PlantName
      @Semantics.quantity.unitOfMeasure: 'DeliveryQuantityUnit'
      SoLuongTrenLenhXuatHang    : abap.quan(13,3); // ActualDeliveryQuantity
      DeliveryQuantityUnit       : vrkme;           // DeliveryQuantityUnit

      // I_SalesOrderScheduleLine
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      SoLuongTheoKHSX            : abap.quan(13,3); // ScheduleLineOrderQuantity
      BaseUnit                   : meins;           // BaseUnit

      // I_DeliveryDocument
      Ngay                       : abap.dats(8); // PlannedGoodsIssueDate

      // I_SalesOrderPartner
      NguoiPhuTrachCont          : abap.char(80);

      // Get by Abstract Entity
      DongDauThung               : abap.string(0);
      Cont                       : abap.string(0); // Z034
      KeHoachDongCont            : abap.string(0);
      GhiChuKhac                 : abap.string(0);
      SortOrder                  : abap.dec(15,3); // thêm mới

      // EML LongText I_OutboundDeliveryTP - LongTextID
      GioGoiContVeNM             : abap.string(0); // Z007
      SoCont                     : abap.string(0); // Uu tien: Z006 --> Neu khong co Z006 --> Lay Z005
      SoChi                      : abap.string(0); // Z029
      NgayTauChay                : abap.string(0); // Z010
      GhiChuGiaoHang             : abap.string(0); // Z009
      ThoiGianCatMang            : abap.string(0); // Z008
      TareWeight                 : abap.string(0); // Z045
      Booking                    : abap.string(0); // Z047

      // Others
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      SoLuongChuaLenLenhXuatHang : abap.quan(13,3); // SoLuongTheoKHSX - SoLuongTrenLenhXuatHang

      // Excel
      CompanyCodeName            : butxt;
      
      // I_ClfnCharacteristic --> I_ClfnObjectCharcValue
      LoaiMang: atwrt; // Characteristic = Z_LOAIMANG --> CharcValue
      LoaiManh: atwrt; // Characteristic = Z_LOAIMANH --> CharcValue
}
