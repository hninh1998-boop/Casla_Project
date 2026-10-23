@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Int. View - Line count per File'
@Metadata.ignorePropagatedAnnotations: true
define view entity zi_m_od_h_data_cnt as select from ztb_m_od_h_data
{
  key uuid_file                                             as UuidFile,

      count( * )                                            as LineCount,

      sum( case when message_type = 'S' then 1 else 0 end ) as SuccessCount,
      sum( case when message_type = 'E' then 1 else 0 end ) as ErrorCount,
      sum( case when message_type = 'J' then 1 else 0 end ) as WarningCount,
      sum( case when message_type = ''  then 1 else 0 end ) as PendingCount
}
group by
  uuid_file
