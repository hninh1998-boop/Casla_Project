@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cons. View - Mass Upload OD Header File'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity zc_m_od_h_file
  provider contract transactional_query
  as projection on zi_m_od_h_file
{
  key Uuid,
      FileName,
      @Semantics.mimeType: true
      FileMimeType,
      @Semantics.largeObject: {
        mimeType: 'FileMimeType',
        fileName: 'FileName',
        contentDispositionPreference: #ATTACHMENT
      }
      Attachment,
      @ObjectModel.text.element: ['OverallStatusText']
      Status,
      Criticality,
      @Semantics.text: true
      OverallStatusText,
      Message,
      CreatedBy,
      CreatedAt,
      LastChangedAt,
      LineCount,
      SuccessCount,
      _DataFile : redirected to composition child zc_m_od_h_data
}
