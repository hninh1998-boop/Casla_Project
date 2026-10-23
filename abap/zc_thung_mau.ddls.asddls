@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cons.View - Quản lý thùng mẫu'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity zc_thung_mau
  provider contract transactional_query
  as projection on zi_thung_mau
{
      @Consumption.valueHelpDefinition: [{ entity: { name: 'zvh_thung_sothung', element: 'SoThung' } }]
  key SoThung,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_ProductStdVH', element: 'Product' } }]
  key Material,
  key Batch,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'zvh_thung_sokhsx', element: 'SoKhsx' } }]
      SoKhsx,

      @EndUserText.label: 'Tên hàng'
      @Semantics.text: true
      _ProductText.ProductName as ProductName,

      Quantity,
      QuantityText,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_StorageLocationStdVH', element: 'StorageLocation' },
                                               additionalBinding: [{ element: 'Plant', localConstant: '6731', usage: #FILTER }] }]
      StorageLocation,
      Customer,
      NgayNhapKho,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'zi_thung_tem_vh', element: 'Tem' } }]
      @ObjectModel.text.element: ['TemText']
      Tem,
      @EndUserText.label: 'Tem'
      @Semantics.text: true
      _Tem.description         as TemText,

      KhoiLuong,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'zi_thung_sta_vh', element: 'Status' } }]
      @ObjectModel.text.element: ['TrangThaiText']
      TrangThai,
      @EndUserText.label: 'Trạng thái'
      @Semantics.text: true
      _Status.description      as TrangThaiText,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'zi_thung_del_vh', element: 'DelFlag' } }]
      @ObjectModel.text.element: ['DelFlagText']
      DelFlag,
      @EndUserText.label: 'Đánh dấu xóa'
      @Semantics.text: true
      _DelFlag.description     as DelFlagText,

      // Filter dạng dropdown chọn nhiều; giá trị mặc định "Đang sử dụng" đặt ở annotation.xml của app
      // (đặt @Consumption.filter.defaultValue ở đây thì service ép filter về chỉ chọn 1 giá trị)
      @Consumption.valueHelpDefinition: [{ entity: { name: 'zvh_thung_hienthi', element: 'DelStatus' } }]
      DelStatus,

      Criticality,
      DelCriticality,

      // Đặc tính theo mã hàng (1)
      _Charc.MaHang2           as MaHang2,
      _Charc.CheDoMai          as CheDoMai,
      _Charc.ChieuDai          as ChieuDai,
      _Charc.ChieuRong         as ChieuRong,
      _Charc.DoDay             as DoDay,

      Uuidfile,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* Associations */
      _ProductText,
      _Charc,
      _Status,
      _DelFlag,
      _Tem
}
