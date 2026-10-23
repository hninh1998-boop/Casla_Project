@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Int. View - Mass Upload OD Header File'
@Metadata.ignorePropagatedAnnotations: true
define root view entity zi_m_od_h_file
  as select from ztb_m_od_h_file
  association [0..1] to zvh_req_sta_od_h   as _OverallStatus on $projection.Status = _OverallStatus.Status
  composition [0..*] of zi_m_od_h_data     as _DataFile
  association [0..1] to zi_m_od_h_data_cnt as _Count         on $projection.Uuid = _Count.UuidFile
{
  key uuid                       as Uuid,

      file_name                  as FileName,
      @Semantics.mimeType: true
      file_mime_type             as FileMimeType,
      @Semantics.largeObject: {
      mimeType: 'FileMimeType',
      fileName: 'FileName',
      contentDispositionPreference: #ATTACHMENT
      }
      attachment                 as Attachment,
      @ObjectModel.text.element: ['OverallStatusText']
      status                     as Status,
      case status
        when 'E' then 1
        when 'X' then 1
        when 'J' then 2
        when 'P' then 2
        when 'D' then 3
        when 'S' then 3
        else 0
      end                        as Criticality,
      @EndUserText.label: 'Status'
      @Semantics.text: true
      _OverallStatus.description as OverallStatusText,
      message                    as Message,
      @Semantics.user.createdBy: true
      created_by                 as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at                 as CreatedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at            as LastChangedAt,
      _Count.LineCount           as LineCount,
      _Count.SuccessCount        as SuccessCount,
      _DataFile,
      _OverallStatus,
      _Count
}
