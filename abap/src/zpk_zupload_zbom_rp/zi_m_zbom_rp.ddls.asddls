@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Int.View - Manage File Upload'
@Metadata.ignorePropagatedAnnotations: true
define root view entity zi_m_zbom_rp
  as select from ztb_m_zbom_rp
  association [0..1] to zi_req_sta_zbom_rp_vh as _OverallStatus on $projection.Status = _OverallStatus.Status
  composition [0..*] of zi_d_zbom_rp          as _DataFile
{
  key uuid          as Uuid,
      zcount        as Zcount,
      status        as Status,

      case status
      when '' then 0
      when 'P' then 2
      when 'D' then 3
      else 0
      end           as Criticality,

      @Semantics.largeObject: { mimeType: 'Mimetype',
                      fileName: 'Filename',
                      contentDispositionPreference: #ATTACHMENT }
      attachment    as Attachment,

      @Semantics.mimeType: true
      mimetype      as Mimetype,

      filename      as Filename,

      countline     as Countline,
      @Semantics.user.createdBy: true
      createdbyuser as Createdbyuser,
      @Semantics.systemDateTime.createdAt: true
      createddate   as Createddate,
      @Semantics.user.lastChangedBy: true
      changedbyuser as Changedbyuser,
      @Semantics.systemDateTime.lastChangedAt: true
      changeddate   as Changeddate,

      // Association
      _OverallStatus,
      _DataFile
}
