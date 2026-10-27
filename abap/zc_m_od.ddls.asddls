@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cons.View - Manage File lệnh xuất hàng'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity zc_m_od
  provider contract transactional_query
  as projection on zi_m_od
{
  key Uuid,
      Zcount,

      @ObjectModel.text.element: ['OverallStatusText']
      Status,

      Criticality,

      @EndUserText.label: 'Status'
      @Semantics.text: true
      _OverallStatus.description as OverallStatusText,

      @Semantics.largeObject: {
        mimeType: 'Mimetype',
        fileName: 'Filename',
        contentDispositionPreference: #ATTACHMENT
      }
      Attachment,
      @Semantics.mimeType: true
      Mimetype,
      Filename,
      Countline,
      Createdbyuser,
      Createddate,
      Changedbyuser,
      Changeddate,

      /* Associations */
      _DataFile : redirected to composition child zc_d_od,
      _OverallStatus
}
