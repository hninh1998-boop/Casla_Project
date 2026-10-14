@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Int.View - Đặc tính mã hàng thùng mẫu'
@Metadata.ignorePropagatedAnnotations: true
define view entity zi_thung_charc
  as select from I_ClfnObjectCharcValue as a
    inner join   I_ClfnCharacteristic   as b on  b.CharcInternalID    = a.CharcInternalID
                                             and b.TimeIntervalNumber = a.TimeIntervalNumber
{
  key left( a.ClfnObjectID, 40 )                                                   as Product,
      max( case when b.Characteristic = 'Z_MA_HANG_2'  then a.CharcValue end )     as MaHang2,
      max( case when b.Characteristic = 'Z_CHE_DO_MAI' then a.CharcValue end )     as CheDoMai,
      max( case when b.Characteristic = 'Z_CHIEU_DAI'  then a.CharcValue end )     as ChieuDai,
      max( case when b.Characteristic = 'Z_CHIEU_RONG' then a.CharcValue end )     as ChieuRong,
      max( case when b.Characteristic = 'Z_DO_DAY_2'   then a.CharcValue end )     as DoDay
}
where
       a.ClassType       = '001'
  and  a.ClfnObjectTable = 'MARA'
  and(
       b.Characteristic  = 'Z_MA_HANG_2'
    or b.Characteristic  = 'Z_CHE_DO_MAI'
    or b.Characteristic  = 'Z_CHIEU_DAI'
    or b.Characteristic  = 'Z_CHIEU_RONG'
    or b.Characteristic  = 'Z_DO_DAY_2'
  )
group by
  a.ClfnObjectID
